using ..Synth: Signal, Konst, done, value

struct OneZero{Z<:Signal,S<:Signal} <: Signal
    theZero::Z
    sig::S
    z::Float32
    b0::Float32
    b1::Float32
    x1::Float32
end

Synth.done(s::OneZero, t, dt) = done(s.sig, t, dt) || done(s.theZero, t, dt)

function Synth.value(s::OneZero, t, dt)
    z = value(s.theZero, t, dt)
    if z != s.z
        s.z = z
        s.b0 = 1.0f0 / (1.0f0 + abs(z))
        s.b1 = -z * s.b0
    end
    x0 = value(s.sig, t, dt)
    v = s.x1 * s.b1 + x0 * s.b0
    s.x1 = x0
    v
end

function Synth.value(s::OneZero{Konst,S}, t, dt) where {S<:Signal}
    x0 = value(s.sig, t, dt)
    v = s.x1 * s.b1 + x0 * s.b0
    s.x1 = x0
    v
end


function onezero(z::Konst, s::S) where {S<:Signal}
    zv = value(z, 0.0, 1/48000)
    b0 = 1.0f0 / (1.0f0 + abs(zv))
    b1 = -zv * b0
    OneZero(z, s, b0, b1, 0.0f0)
end


function onezero(z::Z, s::S) where {S<:Signal,Z<:Signal}
    OneZero(z, s, 1.0f0, 0.0f0, 0.0f0)
end

function onezero(z::Real, s::S) where {S<:Signal}
    onezero(konst(z), s)
end
