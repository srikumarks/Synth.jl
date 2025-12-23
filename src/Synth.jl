
module Synth

using FileIO: load
export OSC
export load
export konst, krate, clip, sigfun, fanout, feedback, connect, clock, clock_bpm, convolve
export oscil, phasor, saw, tri, sq, noise, sample
export line, expon, adsr, decay, follow
export render, write, read_rawaudio
export startaudio, play, mic, control, monitor, level, probe, waveprobe, Bus, bus, sched, now
export PortMidiDest,
    mididevices,
    midioutput,
    MIDIMsg,
    midinop,
    ismidinop,
    send,
    noteon,
    noteoff,
    keypressure,
    ctrlchange,
    progchange,
    aftertouch,
    pitchbend
export Gen,
    ping,
    tone,
    ch,
    seq,
    track,
    chord,
    par,
    dyn,
    rec,
    durn,
    loop,
    rest,
    isstop,
    iscont,
    Stop,
    Cont
export midinote, miditrigger, midimsg, midiseq
export filter1, filter2, fir, lpf, bpf, bpf0, hpf, protect
export waveshape, linearmap, delay, tap
export wavetable, maketable, register!
export granulate, simplegrains, chorusgrains, Grain
export dBscale, interp4, raisedcos, midi2hz, hz2midi, circular
export easeinout, curve, seg, LinSeg, ExpSeg, HarSeg, EaseSeg, stretch, concat
export compress
export stereo, left, right, pan
export simplegrains, chorusgrains, write, rescale, expmap

see_also(meths) =
    "**See also**: " * join(["[`$m`](@ref)" for m in split(meths, ",")], ", ", " and ")

include("signal.jl")
include("basics.jl")

include("phasor.jl")
include("oscil.jl")
include("mixer.jl")
include("decay.jl")
include("interp.jl")
include("adsr.jl")
include("follow.jl")
include("sample.jl")
include("wavetable.jl")
include("waveshape.jl")

include("clock.jl")
include("bus.jl")
include("curve.jl")
include("delay.jl")
include("filters.jl")
include("noise.jl")
include("feedback.jl")
include("granular.jl")

include("probe.jl")
include("control.jl")
include("level.jl")

include("render.jl")
include("io.jl")
include("player.jl")
include("midi.jl")
include("mic.jl")

include("fx.jl")

include("models/models.jl")
include("gens.jl")
include("osc.jl")
include("ui.jl")
#include("ui/ui.jl")

end # module Synth
