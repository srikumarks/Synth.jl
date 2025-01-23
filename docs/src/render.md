# Rendering

Rendering a signal to samples, saving to a file and reading
raw float32 from a file. For more support, use `FileIO`,
`WAV` and such modules.

[`render`](@ref) renders to a buffer in memory, [`Synth.write`](@ref)
writes to a raw audio file and [`read_rawaudio`](@ref) reads in a raw
float32 sample file into a buffer for playback.

```@docs
Synth.render
Synth.write
Synth.read_rawaudio
```


