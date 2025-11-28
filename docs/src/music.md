# For music

A "Gen" has a method to implement which has the signature - 

`genproc(::Gen, ::Bus, t::Float64, rt::Float64) -> Tuple{Float64,Gen}`

The `genproc` method is expected to schedule any signals to the bus
using `sched(::Bus,t,::Signal)` and return info about the next
gen to trigger later. The `t` argument to `genproc` is "clock time" and
not real time - i.e. it is determined by the clock which the bus
runs. The `rt` argument is the real time.

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
Synth.snippet
```

## MIDI specific

Note that MIDI sequencing is unfinished. Particularly
it requires accurate scheduling.

```@docs
Synth.midimsg
Synth.midinote
Synth.miditrigger
Synth.midiseq
```

