# Stereo signals

The primary entities this package deals with are mono signals. However, some
basic support for stereo signals is included as well using the
[`Synth.stereo`](@ref) operator that clubs two mono signals to make a stereo
signal. Such a "stereo" signal behaves like the mixed version when used as an
ordinary `Signal`. However there are other methods that support various
operations, including rendering to stereo.

```@docs
Synth.stereo
Synth.left
Synth.right
Synth.mono
Synth.pan
```


