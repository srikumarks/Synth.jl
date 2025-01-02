mutable struct Mix{S1 <: Signal, S2 <: Signal} <: Signal
    w1 :: Float32
    s1 :: S1
    w2 :: Float32
    s2 :: S2
end

function done(s :: Mix, t, dt)
    done(s.s1, t, dt) && done(s.s2, t, dt)
end

function value(s :: Mix, t, dt)
    s.w1 * value(s.s1, t, dt) + s.w2 * value(s.s2, t, dt)
end

function mix(w1 :: Real, s1 :: S1, w2 :: Real, s2 :: S2) where {S1 <: Signal, S2 <: Signal}
    Mix(Float32(w1), s1, Float32(w2), s2)
end

(Base.:+)(s1 :: Real, s2 :: S2) where {S2 <: Signal} = Mix(1.0f0, konst(s1), 1.0f0, s2)
(Base.:+)(s1 :: S1, s2 :: Real) where {S1 <: Signal} = Mix(1.0f0, s1, 1.0f0, konst(s2))
(Base.:+)(s1 :: S1, s2 :: S2) where {S1 <: Signal, S2 <: Signal} = Mix(1.0f0, s1, 1.0f0, s2)
(Base.:-)(s1 :: Real, s2 :: S2) where {S2 <: Signal} = Mix(1.0f0, konst(s1), -1.0f0, s2)
(Base.:-)(s1 :: S1, s2 :: Real) where {S1 <: Signal} = Mix(1.0f0, s1, -1.0f0, konst(s2))
(Base.:-)(s1 :: S1, s2 :: S2) where {S1 <: Signal, S2 <: Signal} = Mix(1.0f0, s1, -1.0f0, s2)


