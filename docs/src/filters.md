# Filters

Linear time invariant first and second filters, with controllable filter
parameters. Main ones are [`lpf`](@ref), [`hpf`](@ref) and [`bpf`](@ref)
second order filters. Also, [`delay`](@ref) and [`tap`](@ref) make a
delay line that can be tapped at multiple points.

```@docs
Synth.filter1
Synth.filter2
Synth.fir
Synth.lpf
Synth.bpf
Synth.bpf0
Synth.hpf
Synth.delay
Synth.tap
Synth.maxdelay
```


