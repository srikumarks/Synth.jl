# For music

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
Synth.midimsg
Synth.midinote
Synth.miditrigger
```

