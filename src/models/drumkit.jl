using ..Synth: Gen, Bus, sched, Cont

struct DrumHit <: Gen
    samplefile::String
    vel::Float32
end

function Synth.proc(g::DrumHit, b::Bus, t)
    sched(b, t, g.vel * sample(g.samplefile))
    (t, Cont())
end

function hit(samplefile::AbstractString, vel::Float32 = 1.0f0)
    @assert isfile(samplefile) "Sample file '$samplefile' not found"
    sample(samplefile)
    DrumHit(samplefile, vel)
end

function hit(drum::DrumHit, vel::Float32 = 1.0f0)
    DrumHit(drum.samplefile, vel)
end

struct DrumKit
    kick::DrumHit
    hihat::DrumHit
    snare::DrumHit
    tom1::DrumHit
    tom2::DrumHit
    tom3::DrumHit
end

function drumkit(kit::AbstractString; dir::Union{Nothing,AbstractString} = nothing)
    modelsdir = @__DIR__
    kitspath = if isnothing(dir) "$modelsdir/drumkits" else dir end

    DrumKit(
            hit("$kitspath/$kit/kick.wav"),
            hit("$kitspath/$kit/snare.wav"),
            hit("$kitspath/$kit/hihat.wav"),
            hit("$kitspath/$kit/tom1.wav"),
            hit("$kitspath/$kit/tom2.wav"),
            hit("$kitspath/$kit/tom3.wav")
           )
end

function drumkits()
    modelsdir = @__DIR__
    [d for d in readdir("$modelsdir/drumkits/") if isdir("$modelsdir/drumkits/$d")]
end
