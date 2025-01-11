using Synth

mutable struct AdiTala <: Synth.BeatGen
    a0 :: Float32
    f0 :: Float32
    a1 :: Float32
    f1 :: Float32
end

function Synth.genbeat(
        tala :: AdiTala,
        phase :: AbstractFloat,
        count :: Integer,
        trigger :: Bool,
        dphase :: AbstractFloat,
        dt :: AbstractFloat) :: Union{Val{:end},Nothing,Synth.Signal}
    if trigger
        p = mod(count, 8)
        if p == 0 || p == 4 || p == 6
            sinosc(adsr(tala.a0, 0.0; release_secs = 0.4 * dt / dphase), tala.f0)
        else
            sinosc(adsr(tala.a1, 0.0; release_secs = 0.4 * dt / dphase), tala.f1)
        end
    else
        nothing
    end
end

function aditala(tempo,a0,n0,a1,n1)
    beats(tempo*(1.0/60.0), AdiTala(Float32(a0),Float32(midi2hz(n0)),Float32(a1),Float32(midi2hz(n1))))
end
