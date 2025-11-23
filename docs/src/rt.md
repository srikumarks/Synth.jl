# Realtime playback

Methods that provide support for realtime playback as opposed to static file
based rendering. The commonly used method is [`play`](@ref "Synth.play"). To work at a
higher level with sample accurate scheduling of sound events, see
[`Synth.Gen`](@ref) and the associated gens [`track`](@ref "Synth.track"),
[`loop`](@ref "Synth.loop") and the example [`ping`](@ref "Synth.ping"). For interactivity,
see [`control`](@ref "Synth.control") (for UI to signal) and [`probe`](@ref "Synth.probe") (for
signal to UI).

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
Synth.after
```
