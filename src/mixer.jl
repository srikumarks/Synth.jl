mutable struct Mix{S1<:Signal,S2<:Signal} <: Signal
    w1::Float32
    s1::S1
    w2::Float32
    s2::S2
end

mutable struct Mod{M<:Signal,S<:Signal} <: Signal
    mod::M
    signal::S
end


function done(s::Mix, t, dt)
    done(s.s1, t, dt) && done(s.s2, t, dt)
end

function value(s::Mix, t, dt)
    s.w1 * value(s.s1, t, dt) + s.w2 * value(s.s2, t, dt)
end

"""
    mix(w1 :: Real, s1 :: Signal, w2 :: Real, s2 :: Signal)

Creates a mixed signal from the two given signals, using the two 
constant weights. This is the basis of the support for `+`
and `-` between signals. This and [`modulate`](@ref) remove
some unnecessary combinations and reduce them down to simpler
forms where possible.
"""
function mix(w1::Real, s1::Signal, w2::Real, s2::Signal)
    Mix(Float32(w1), s1, Float32(w2), s2)
end

function mix(w1::Real, s1::Mod{Konst,S1}, w2::Real, s2::Signal) where {S1}
    mix(w1 * s1.mod.k, s1.signal, w2, s2)
end

function mix(w1::Real, s1::Signal, w2::Real, s2::Mod{Konst,S2}) where {S2}
    mix(w1, s1, w2 * s2.mod.k, s2.signal)
end

function mix(w1::Real, s1::Stereo{L,R}, w2::Real, s2::Signal) where {L,R}
    stereo(mix(w1, left(s1), w2, s2), mix(w1, right(s1), w2, s2))
end

function mix(w1::Real, s1::Signal, w2::Real, s2::Stereo{L,R}) where {L,R}
    stereo(mix(w1, s1, w2, left(s2)), mix(w1, s1, w2, right(s2)))
end

function mix(w1::Real, s1::Mod{Konst,S1}, w2::Real, s2::Mod{Konst,S2}) where {S1,S2}
    # Supports a common case of mixing two signals using constant
    # factors, but expressed using * and so ended up inserting an additional
    # Mod operator in between. This looks like it is infinitely recursive,
    # but isn't, since it'll turn around and call the method above
    # when the type pattern isn't met.
    mix(w1 * s1.mod.k, s1.signal, w2 * s2.mod.k, s2.signal)
end

(Base.:+)(s1::Real, s2::Signal) = mix(1.0f0, konst(s1), 1.0f0, s2)
(Base.:+)(s1::Signal, s2::Real) = mix(1.0f0, s1, 1.0f0, konst(s2))
(Base.:+)(s1::Signal, s2::Signal) = mix(1.0f0, s1, 1.0f0, s2)
(Base.:-)(s1::Real, s2::Signal) = mix(1.0f0, konst(s1), -1.0f0, s2)
(Base.:-)(s1::Signal, s2::Real) = mix(1.0f0, s1, -1.0f0, konst(s2))
(Base.:-)(s1::Signal, s2::Signal) = mix(1.0f0, s1, -1.0f0, s2)

(Base.:+)(s1::Stereo{L1,R1}, s2::Stereo{L2,R2}) where {L1,R1,L2,R2} =
    stereo(s1.left + s2.left, s1.right + s2.right)
(Base.:+)(s1::Stereo{L,R}, s2::Signal) where {L,R} = stereo(s1.left + s2, s1.right + s2)
(Base.:+)(s1::Signal, s2::Stereo{L,R}) where {L,R} = stereo(s1 + s2.left, s1 + s2.right)
(Base.:-)(s1::Stereo{L1,R1}, s2::Stereo{L2,R2}) where {L1,R1,L2,R2} =
    stereo(s1.left - s2.left, s1.right - s2.right)
(Base.:-)(s1::Stereo{L,R}, s2::Signal) where {L,R} = stereo(s1.left - s2, s1.right - s2)
(Base.:-)(s1::Signal, s2::Stereo{L,R}) where {L,R} = stereo(s1 - s2.left, s1 - s2.right)

function done(s::Mod, t, dt)
    done(s.mod, t, dt) || done(s.signal, t, dt)
end

function value(s::Mod, t, dt)
    value(s.mod, t, dt) * value(s.signal, t, dt)
end

"""
    modulate(m :: Signal, s :: Signal)

Basically performs multiplication between two signals and is the basis of `*`
operator support. This and [`mix`](@ref) together implement some expression
simplifications that remove unnecessary combinations.
"""
function modulate(m::Signal, s::Signal)
    Mod(m, s)
end

function modulate(m::Konst, s::Mix{S1,S2}) where {S1,S2}
    mix(m.k * s.w1, s.s1, m.k * s.w2, s.s2)
end

function modulate(m::Konst, s::Mod{Konst,S}) where {S}
    modulate(m.k * s.mod.k, s.signal)
end

function modulate(m::Stereo{L,R}, s::Signal) where {L,R}
    stereo(modulate(left(m), s), modulate(right(m), s))
end

function modulate(m::Signal, s::Stereo{L,R}) where {L,R}
    stereo(modulate(m, left(s)), modulate(m, right(s)))
end

(Base.:*)(m::Real, s::S) where {S<:Signal} = modulate(konst(m), s)
(Base.:*)(m::M, s::Real) where {M<:Signal} = modulate(m, konst(s))
(Base.:*)(m::M, s::S) where {M<:Signal,S<:Signal} = modulate(m, s)

(Base.:*)(m::M, s::Stereo{L,R}) where {M<:Signal,L,R} = stereo(m * left(s), m * right(s))
(Base.:*)(m::Stereo{LM,RM}, s::Stereo{L,R}) where {LM,RM,L,R} =
    stereo(left(m) * left(s), right(m) * right(s))
