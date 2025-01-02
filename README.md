# Synth.jl

Provides abstract type `Signal`, commonly useful signal
constructors and operations, and ways to play and read/write
signals to audio files.

## Signal constructors

- `aliasable(signal)`
- `konst(number)`
- `phasor(frequency, initial_phase)`
- `sinosc(amplitude, phasor)`
- `+`, `-`, `*`
- `line(v1, duration_secs, v2)`
- `expinterp(v1, duration_secs, v2)`
- `expdecay(rate)`
- `adsr(alevel, asecs, dsecs, suslevel, sussecs, relsecs)`
- `sample(samples; looping, loopto)`
- `wavetable(table, amp, phasor)`
- `waveshape(f, signal)`
- `linearmap(a1, a2, b1, b2, signal)`
- `clock(speed, t_end; sampling_rate_Hz)`
- `clock_bpm(tempo_bpm, t_end; sampling_rate_Hz)`
- `seq(clock, dur_signal_pair_vector)`
- `curve(segments :: Vector{Seg}; stop=false)`
- `delay(sig :: S, tap :: Tap, maxdelay :: Real; sr=48000)` 
- `filter1(sig :: S, gain :: G)`
- `filter2(sig :: S, freq :: F, damping :: G)`
- `fir(filt :: Vector{Float32}, sig :: S)`
- `noise(rng :: RNG, amp :: Union{A,Real}) where {A <: Signal}` 


## Utilities

- `render(signal, dur_secs; sr, maxamp)`
- `write(filename, signal, duration_secs; sr, axamp)`
- `read_rawaudio(filename)`
- `rescale(maxamp, samples)`
- `Seg(v1, v2, dur, interp::Union{:linear,:exp,:harmonic})`
   is a structure that captures a segment of a curve.
   Each segment can have its own interpolation method.
