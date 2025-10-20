# Realtime playback

Methods that provide support for realtime playback as opposed to static file
based rendering. The commonly used method is [`play`](@ref). To work at a higher
level with sample accurate scheduling of sound events, see [`Gen`](@ref) and the
associated gens [`track`](@ref), [`loop`](@ref) and the example [`ping`](@ref).
For interactivity,
see [`control`](@ref) (for UI to signal) and [`probe`](@ref) (for signal to UI).

```@docs
Synth.startaudio
Synth.play
Synth.mic
Synth.control
Synth.stop
Synth.probe
Synth.waveprobe
Synth.level
Synth.bus
Synth.sched
Synth.now
Synth.later
```

## Gens

A "Gen" has a method to implement which has the signature - 

`proc(::Gen, ::Bus, t::Float64) -> Tuple{Float64,Gen}`

The `proc` method is expected to schedule any signals to the bus
using `sched(::Bus,t,::Signal)` and return info about the next
gen to trigger later. The `t` argument to `proc` is "clock time" and
not real time - i.e. it is determined by the clock which the bus
runs.

```@docs
Synth.Gen
Synth.seq
Synth.track
Synth.durn
Synth.chord
Synth.par
Synth.loop
Synth.dyn
Synth.rec
Synth.ping
Synth.tone
Synth.ch
Synth.wavetone
Synth.snippet
```


