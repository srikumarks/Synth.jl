
module Synth

include("signal.jl")
include("basics.jl")

include("phasor.jl")
include("sinosc.jl")
include("modulator.jl")
include("mixer.jl")
include("expdecay.jl")
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
