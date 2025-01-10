
module Synth

export konst, clip, sigfun, aliasable, feedback, connect, clock, clock_bpm
export sinosc, phasor, noise, sample
export line, expon, adsr, decay, Gen
export render, write, read_rawaudio
export startaudio, synthesizer, synthchan, play!, play, control, probe, scheduler, schedule, seq
export filter1, filter2, fir, lpf, bpf, bpf0, hpf
export waveshape, linearmap, delay, tap
export wavetable, maketable
export granulate, simplegrains, chorusgrains, Grain
export dBscale, interp4, raisedcos, midi2hz, hz2midi, easeinout, curve, Seg, circular

include("signal.jl")
include("basics.jl")

include("phasor.jl")
include("sinosc.jl")
include("modulator.jl")
include("mixer.jl")
include("decay.jl")
include("interp.jl")
include("adsr.jl")
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

include("probe.jl")
include("control.jl")

include("render.jl")
include("io.jl")
include("player.jl")

include("models/models.jl")

end # module Synth
