# Getting started

## Installation

Assuming you have Julia 1.11.0 or later installed, you can
add the package directly from the GitHub URL.

```julia
> ]
pkg> add https://github.com/srikumarks/Synth.jl
```

## Playing a tone

```
# julia -t 4,1
> using Synth
> play(oscil(0.25, 440.0), 2.0)
```

The above plays a 440Hz tone with an amplitude of 0.25 for 2.0 seconds.
Here, `oscil` computes a "process" that, over time, will produce
samples that constitute a sine tone. The argument `0.25` and `440.0` are
also to be interpreted as such processes. This means they can also
potentially vary over time, for example, like this - 

```julia
> play(oscil(0.25, 440.0 + oscil(100.0, 10.0)), 2.0)
```

... which will give you an FM siren. The usual `*`, `+`, `-`
operators are supported for such "signal processes". The rest of
this "getting started" applies to all such processes, called
`Signal`s in this package.

## Rendering audio to a buffer

To render the same 440Hz sine tone to a `Float32` buffer,

```julia
> v = render(oscil(0.25, 440.0), 2.0)
96000-frame, 1-channel SampleBuf{Float32, 1}
2.0s sampled at 48000.0Hz
▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆
```

## Saving audio to a raw float32 file

```julia
> write("rawfile.float32", oscil(0.25, 440.0), 2.0)
```

The written data will be rescaled according to the passed rescaling
settings. In this case, the default scale of 0.5 is used.

## Reading audio from a raw float32 file

```julia
> v = read_rawaudio("rawfile.float32")
```

`v` will be a `Vector{Float32}`.

You can also use the `load` function from `FileIO` / `LibSndFile` which will
return a `SampleBuf` from supported audio file formats. To get support for
audio file formats via `LibSndFile` and `MP3`, import those packages
separately. This is done so that if you don't need those, then there are fewer
dependencies to deal with.
