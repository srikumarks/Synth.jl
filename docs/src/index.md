# Synth.jl Documentation

`Synth.jl` provides a library of signal generators and transformers in a highly
compositional form suitable for musical applications. The [`Signal`](@ref
"Synth.Signal") type is intended to model processes that evolve in time and
which could be finite in extent. 

For example `sinosc(0.5, 250.0)` is a sine wave oscillator that oscillates at
250Hz with an amplitude of 0.5, forever, and `sinosc(0.5, 250.0 + sinosc(100.0,
250.0))` gives you a frequency modulated sine oscillation and you can impose an
envelope on it like this -- `sinosc(adsr(0.5, 1.0), 250.0 + sinosc(100.0,
250.0))` -- which makes it finite in duration. Most operators can be composed
in this manner, usually resulting in fairly efficient code as well.
See the [Models](@ref "Models") section for some other simple signal
combinations such as [`Synth.Models.basicvocoder`](@ref).

The above constructed finite extent signal can be rendered to a
`SampledSignals.SampleBuf` using [`render`](@ref) like this --

```julia
v = render(sinosc(adsr(0.5, 1.0), 250.0 + sinosc(100.0, 250.0)))
```

(Pass an explicit duration if it's an infinite extent signal or use
[`Synth.play`](@ref).)

Signals can be rendered to `SampleBuf` buffers, to raw `Float32` files or in
real time to the computer's sound output using [`play`](@ref). There is also
some minimal support for [`stereo`](@ref) signals.

## The Signal type

```@docs
Synth.Signal
```

The definition of `Signal` treats signal generators and transformers
like "values" which can be operated on using ordinary arithmetic
`+`, `-` and `*`.

## Models

```@autodocs
Modules = [Synth.Models]
Order   = [:function, :type]
```

## Index

```@index
```
