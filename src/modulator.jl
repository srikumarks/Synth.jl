mutable struct Mod{M <: Signal, S <: Signal} <: Signal
    mod :: M
    signal :: S
end

function done(s :: Mod, t, dt)
    done(s.mod, t, dt) || done(s.signal, t, dt)
end

function value(s :: Mod, t, dt)
    value(s.mod, t, dt) * value(s.signal, t, dt)    
end

(Base.:*)(m :: Real, s :: S) where {S <: Signal} = Mod(konst(m),s)
(Base.:*)(m :: M, s :: Real) where {M <: Signal} = Mod(m,konst(s))
(Base.:*)(m :: M, s :: S) where {M <: Signal, S <: Signal} = Mod(m,s)

(Base.:*)(m :: M, s :: Stereo{L,R}) where {M <: Signal, L,R} = stereo(m * s.left, m * s.right)
(Base.:*)(m :: Stereo{LM,RM}, s :: Stereo{L,R}) where {LM,RM, L,R} = stereo(m.left * s.left, m.right * s.right)


