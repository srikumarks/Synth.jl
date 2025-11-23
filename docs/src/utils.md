# Utilities

Misc functions needed in many applications. [`rescale`](@ref "Synth.rescale") scales an
entire buffer, [`Synth.dBscale`](@ref) converts dB to amplitude, [`interp4`](@ref "Synth.interp4")
does 4-point interpolation, [`raisedcos`](@ref "Synth.raisedcos") is a masking waveform,
[`midi2hz`](@ref "Synth.midi2hz")/[`hz2midi`](@ref "Synth.hz2midi") convert MIDI note numbers <-> Hz.

```@docs
Synth.rescale
Synth.dBscale
Synth.interp4
Synth.raisedcos
Synth.midi2hz
Synth.hz2midi
Synth.easeinout
Synth.curve
Synth.Seg
Synth.circular
```


