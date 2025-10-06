
module Synth

using FileIO: load
export load
export konst, clip, sigfun, fanout, feedback, connect, clock, clock_bpm, clamp, convolve
export sinosc, phasor, noise, sample
export line, expon, adsr, decay, Gen, follow
export render, write, read_rawaudio
export startaudio,
    synthesizer, synthchan, play!, play, control, probe, scheduler, sched, now, seq
export filter1, filter2, fir, lpf, bpf, bpf0, hpf
export waveshape, linearmap, delay, tap
export wavetable, maketable
export granulate, simplegrains, chorusgrains, Grain
export beats
export dBscale, interp4, raisedcos, midi2hz, hz2midi, easeinout, curve, Seg, circular
export compress
export stereo, left, right, pan
export simplegrains, chorusgrains, write, rescale, expmap

see_also(meths) =
    "**See also**: " * join(["[`$m`](@ref)" for m in split(meths, ",")], ", ", " and ")

include("signal.jl")
include("basics.jl")

include("phasor.jl")
include("sinosc.jl")
include("mixer.jl")
include("decay.jl")
include("interp.jl")
include("adsr.jl")
include("follow.jl")
include("sample.jl")
include("wavetable.jl")
include("waveshape.jl")

include("clock.jl")
include("sched.jl")
include("seq.jl")
include("curve.jl")
include("delay.jl")
include("filters.jl")
include("noise.jl")
include("gen.jl") # Include in signal.jl
include("feedback.jl")
include("granular.jl")

include("beats.jl")

include("probe.jl")
include("control.jl")
include("level.jl")

include("render.jl")
include("io.jl")
include("player.jl")

include("fx.jl")

include("models/models.jl")
#include("ui/ui.jl")

end # module Synth
