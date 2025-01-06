mutable struct SinOsc{Mod <: Signal, Ph <: Signal} <: Signal
    modulator :: Mod
    phasor :: Ph
end

function done(s :: SinOsc, t, dt)
    done(s.modulator, t, dt) || done(s.phasor, t, dt)
end

function value(s :: SinOsc, t, dt)
    m = value(s.modulator, t, dt)
    p = value(s.phasor, t, dt)
    m * sin(Float32(2.0f0 * π * p))
end

"""
    sinosc(m :: Real, f :: Real)
    sinosc(m :: Real, p :: P) where {P <: Signal}
    sinosc(m :: M, p :: P) where {M <: Signal, P <: Signal}

A "sinosc" is a sinusoidal oscillator that can be controlled using a
phasor or a clock to determine a time varying frequency.
"""
sinosc(m :: Real, f :: Real) = SinOsc(konst(m), phasor(f))
sinosc(m :: Real, p :: P) where {P <: Signal} = SinOsc(konst(m), p)
sinosc(m :: M, p :: P) where {M <: Signal, P <: Signal} = SinOsc(m, p)


