# Synth.jl Documentation

`Synth.jl` provides a library of signal generators and transformers in a highly
compositional form suitable for musical applications. The [`Signal`](@ref
"Synth.Signal") type is intended to model processes that evolve in time and
which could be finite in extent. 

For example `oscil(0.5, 250.0)` is a sine wave oscillator that oscillates at
250Hz with an amplitude of 0.5, forever, and `oscil(0.5, 250.0 + oscil(100.0,
250.0))` gives you a frequency modulated sine oscillation and you can impose an
envelope on it like this -- `oscil(adsr(0.5, 1.0), 250.0 + oscil(100.0,
250.0))` -- which makes it finite in duration. Most operators can be composed
in this manner, usually resulting in fairly efficient code as well.
See the [Models](@ref "Models") section for some other simple signal
combinations such as [`basicvocoder`](@ref "Synth.Models.basicvocoder").

The above constructed finite extent signal can be rendered to a
`SampledSignals.SampleBuf` using [`render`](@ref "Synth.render") like this --

```julia
v = render(oscil(adsr(0.5, 1.0), 250.0 + oscil(100.0, 250.0)))
```

(Pass an explicit duration if it's an infinite extent signal or use
[`play`](@ref "Synth.play").)

Signals can be rendered to `SampleBuf` buffers, to raw `Float32` files or in
real time to the computer's sound output using [`play`](@ref "Synth.play"). There is also
some minimal support for [`stereo`](@ref "Synth.stereo") signals.

Combined with the [`bus`](@ref "Synth.bus") mechanism, the notion of a process for
producing both sound and audio events can be expressed quite nicely using
this API. An example below - 

```julia
using Synth

b = bus(60.0)
play(0.3 * b, 20.0)
nonsense_tests = [
         tone(ch([60,64,67]), 1.0),
         tone(ch(12 .+ [60,62,65,69]), 1.0),
         ping(72, 1.0),
         rest(0.5),
         loop(3, ping([67,72], 0.2)),
         tone(12 .+ [60, 62, 64, 65, 67, 69, 71, 72, 71, 69, 67, 65, 64, 62, 60], 1/16)
        ]
sched(b, track(nonsense_tests))
sleep(10.0)
```

## The Signal type

```@docs
Synth.Signal
```

The definition of `Signal` treats signal generators and transformers
like "values" which can be operated on using ordinary arithmetic
`+`, `-` and `*`.

## Index

```@index
```
