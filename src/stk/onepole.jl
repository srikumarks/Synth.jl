using ..Synth: Signal, Konst, done, value

struct OnePole{S<:Signal,P<:Signal} <: Signal
    sig::S
    thePole::P
    last_p::Float32
    b0::Float32
    a1::Float32
    y1::Float32
end

Synth.done(s::OnePole, t, dt) = done(s.sig, t, dt) || done(s.thePole, t, dt)

function Synth.value(s::OnePole, t, dt)
    p = value(s.thePole, t, dt)
    if p != s.last_p
        s.b0 = 1.0f0 - abs(p)
        s.a1 = -p
        s.last_p = p
    end

    x0 = value(s.sig, t, dt)
    y0 = x0 * s.b0 - s.y1 * s.a1
    s.y1 = y0
    y0
end

function onepole(pole::P, sig::S) where {P<:Signal,S<:Signal}
    OnePole(sig, pole, 0.0f0, 1.0f0, -1.0f0, 0.0f0)
end

function onepole(pole::Real, sig::S) where {S<:Signal}
    onepole(konst(pole), sig)
end
