
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
