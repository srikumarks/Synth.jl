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

(Base.:+)(s1 :: Stereo{L1,R1}, s2 :: Stereo{L2,R2}) where {L1,R1,L2,R2} = stereo(s1.left + s2.left, s1.right + s2.right)
(Base.:+)(s1 :: Stereo{L,R}, s2 :: S) where {L,R,S <: Signal} = stereo(s1.left + s2, s1.right + s2)
(Base.:+)(s1 :: S, s2 :: Stereo{L,R}) where {L,R,S <: Signal} = stereo(s1 + s2.left, s1 + s2.right)
(Base.:-)(s1 :: Stereo{L1,R1}, s2 :: Stereo{L2,R2}) where {L1,R1,L2,R2} = stereo(s1.left - s2.left, s1.right - s2.right)
(Base.:-)(s1 :: Stereo{L,R}, s2 :: S) where {L,R,S <: Signal} = stereo(s1.left - s2, s1.right - s2)
(Base.:-)(s1 :: S, s2 :: Stereo{L,R}) where {L,R,S <: Signal} = stereo(s1 - s2.left, s1 - s2.right)

