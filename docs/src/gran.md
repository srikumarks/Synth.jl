# Granular synthesis

A popular cool synthesis technique that can use sampling to produce
a wide variety of rich and complex sounds. A phasor is used to trigger
grains on the negative edge.

[`granulate`](@ref) is the main synthesis routine that takes a
"granulator" function like [`simplegrains`](@ref) or [`chorusgrains`](@ref).

```@docs
Synth.granulate
Synth.simplegrains
Synth.chorusgrains
Synth.Granulation
Synth.Grain
```


