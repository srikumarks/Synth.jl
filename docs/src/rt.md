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
