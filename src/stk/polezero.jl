using ..Synth: Signal, Konst

struct PoleZero{S<:Signal} <: Signal
    sig::S
    b0::Float32
    b1::Float32
    a1::Float32
    x1::Float32
    y1::Float32
end

Synth.done(s::PoleZero, t, dt) = Synth.done(s.sig, t, dt)

function Synth.value(s::PoleZero, t, dt)
    x0 = value(s.sig, t, dt)
    y0 = s.b0 * x0 + s.b1 * s.x1 - s.a1 * s.y1
    s.y1 = y0
    s.x1 = x0
    y0
end

function polezero(sig::Signal, b0::Real, b1::Real, a1::Real)
    PoleZero(sig, Float32(b0), Float32(b1), Float32(a1), 0.0f0, 0.0f0)
end

function dcblock(sig::Signal, thePole::Real = 0.99f0)
    polezero(sig, 1.0f0, -1.0f0, -thePole)
end

function allpass(sig::Signal, coeff::Real)
    polezero(sig, coeff, 1.0f0, coeff)
end
