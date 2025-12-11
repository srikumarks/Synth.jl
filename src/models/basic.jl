using ..Synth
using ..Synth: adsr, Signal, konst, Konst, SignalWithFanout

"""
    tone(amp, freq, duration; attack_factor = 2.0, attack_secs = 0.005, decay_secs = 0.05, release_secs = 0.2)

A simple sine tone modulator by an ADSR envelope. `amp` is the amplitude of the
sustain portion, `freq` is the Hz value of the frequency of the tone and `duration`
is the duration in seconds of the sustain portion.

# Envelope characteristics
- `attack_factor` - the factor (usually > 1.0) that multiplies the amplitude value to 
  determine the peak of the attack portion of the envelope.
- `attack_secs` - the duration of the attack portion. This should be kept short in general.
- `decay_secs` - the duration of the portion of the envelope where it decays from the
  peak attack value down to the sustain level.
- `release_secs` - the "half life" of the release portion of the envelope. Over this time,
  the amplitude of the signal will decay by a factor of 2.
"""
function tone(
    amp,
    freq,
    duration;
    attack_factor = 2.0,
    attack_secs = 0.005,
    decay_secs = 0.05,
    release_secs = 0.2,
)
    env = adsr(amp * attack_factor, attack_secs, decay_secs, amp, duration, release_secs)
    oscil(env, freq)
end

heterodyne(sig, fc, bw; q = 5.0) = lpf(oscil(sig, fc), bw, q)

"""
    basicvocoder(sig, f0, N, fnew; bwfactor = 0.2, bwfloor = 20.0)

A simple vocoder for demo purposes. Takes ``N`` evenly spaced frequencies ``k f_0`` and moves
them over to a new set of frequencies ``k f_{\\text{new}}`` using a heterodyne filter. 
The `bwfactor` setting gives the fraction of the inter-frequency bandwidth to filter in.
The bandwidth has a floor given by `bwfloor` in Hz.
"""
function basicvocoder(sig, f0, N, fnew; bwfactor = 0.2, bwfloor = 20.0)
    asig = fanout(sig)
    bw = max(bwfloor, f0 * bwfactor)
    reduce(+, oscil(heterodyne(asig, f0 * k, bw * k), fnew * k) for k = 1:N)
end

"""
    additive(f0,
             amps :: AbstractVector{Union{Real,Signal}},
             detune_factor :: Signal = konst(1.0f0))

Simple additive synthesis. `amps` is a vector of Float32 or a vector of signals.
`f0` is a frequency value or a signal that evaluates to the frequency.
The function constructs a signal with harmonic series based on `f0` as the
fundamental frequency and amplitudes determined by the array `amps`.
"""
function additive(f0, amps::AbstractVector, detune_factor = konst(1.0f0))
    sum(oscil(amps[k], k * detune_factor * f0) for k in eachindex(amps))
end

"""
    chirp(amp, startfreq, endfreq, dur;
          shapename::Union{Val{:line},Val{:expon}} = Val(:line))

A "chirp" is a signal whose frequency varies from a start value to 
a final value over a period of time. The shape of the change can be
controlled using the `shapename` keyword argument.
"""
function chirp(
    amp,
    startfreq,
    dur,
    endfreq;
    shapename::Union{Val{:line},Val{:expon}} = Val(:line),
)
    oscil(amp, clip(dur, shape(shapename, startfreq, dur, endfreq)))
end

"""
    snare(dur::Real; rng = MersenneTwister(1234))

Very simple snare hit where the `dur` is the "half life" of the snare's decay.
Just amplitude modulates some white noise.
"""
function snare(dur::Real; rng = MersenneTwister(1234))
    noise(rng, decay(1.0f0/dur))
end


"""
    fm(carrier, modulator, index, amp = konst(1.0f0))

Basic FM synth module. `carrier` is the carrier frequency
that can itself be a signal. `modulator` is the modulation
frequency and `index` is the extent of modulation. `amp`,
if given decides the final amplitude. All of them can vary
over time.

## Example

```julia
play(fm(220.0f0, 550.0f0, 100.0f0), 5.0)
```
"""
function fm(carrier, modulator, index, amp = Synth.konst(1.0f0))
    oscil(amp, carrier + oscil(index, modulator))
end

"""
    siginv(s::Signal)

Constructs 1/x. This is sometimes needed, for example when
building up a limiter. The signal is assumed to be well behaved
enough to be inverted like this and no checks are done. So 
you're on your own there. `siginv` is adequately polymorphic.
"""
siginv(sig::Signal) = map((a) -> Float32(1.0f0/a), sig)
siginv(sig::Konst) = konst(1/sig.k)
siginv(x::Real) = konst(1/x)

"""
    comb(filter, sig, freq, gain = 0.6)

Applies a comb filter to the given signal `sig` where the `freq` 
dictates the length of the delay line and `gain` gives the gain
of the output of the delay line. The given `filter` is a function
that is called with the delay tap signal in case it needs to be
filtered in some way. If you omit the `filter` argument, it is
equivalent to providing the `identity` function. This is a 
feedback based comb filter.

- The minimum value of `freq` supported is 1.0. To permit lower
  values, set the `minfreq` keyword argument appropriately.

**WARNING**: Be careful with the `gain` argument as higher values
can result in runaway positive feedback. To help mitigate such
runaway effects, a hpf and limiter are in the loop.
"""
function comb(filter::Function, sig::Signal, freq, gain = 0.6; minfreq = 1.0, postfeedback=(s) -> limiter(hpf(s,20)))
    f = feedback()
    d = delay(f, 1/minfreq)
    g = gain * filter(tap(d, siginv(freq)))
    out = fanout(limiter(hpf(g + sig, 20)))
    connect(out, f)
end
comb(sig::Signal, freq, gain = 0.6; minfreq = 1.0) = comb(identity, sig, freq, gain; minfreq)

"""
    limiter(sig::SignalWithFanout, level::Real = 0.5f0)

A simple limiter based on an approximate peak follower. Should help prevent
uncontrolled growth disasters. Smooths the level measurement and uses it
to adjust the gain. Has about a 10 millisecond delay.

**Todo**: Wondering about the difference between this and smoothing the gain
instead. Also, the lpf will introduce a small delay that could be problematic.
Need to test.
"""
function limiter(sig::SignalWithFanout, level::Real = 0.5f0)
    sa = map(abs, sig)
    saf = lpf(sa, 100.0, 1.0)
    gain = map((x) -> if x < level 1.0f0 else Float32(level/x) end, saf)
    # The tanh exists to limit any transients that can still cause damage.
    map(tanh, gain * sig)
end


