using Synth
using StaticArrays

mutable struct Ising2{F,Z1,Z2,X1,X2,W12} <: Signal
    const f :: F
    const b1 :: Z1
    const b2 :: Z2
    const x1 :: X1
    const x2 :: X2
    const w12 :: W12
    const psi :: MVector{4, ComplexF32}
    const sz1 :: SMatrix{4, 4, ComplexF32}
    const sz2 :: SMatrix{4, 4, ComplexF32}
    const sz12 :: SMatrix{4, 4, ComplexF32}
    const sx1 :: SMatrix{4, 4, ComplexF32}
    const sx2 :: SMatrix{4, 4, ComplexF32}
    t :: Float64
end


done(m::Ising2, t, dt) = done(m.w12, t, dt)

function value(m::Ising2, t, dt)
    if t <= m.t
        return real(m.psi[1])
    end

    f = value(m.f, t, dt)
    b1 = value(m.b1, t, dt)
    b2 = value(m.b2, t, dt)
    x1 = value(m.x1, t, dt)
    x2 = value(m.x2, t, dt)
    w12 = value(m.w12, t, dt)
    dph = 2 * pi * im * f * dt * (b1 * m.sz1 + b2 * m.sz2 + x1 * m.sx1 + x2 * m.sx2 + w12 * m.sz12)
    t1 = m.psi
    t2 = dph * t1
    t3 = 0.5f0 * dph * t2
    m.psi .= t1 + t2 + t3
    m.psi ./= sum(abs2, m.psi)
    m.t = t
    real(m.psi[1])
end

struct Ising2Tap{I <: Ising2} <: Signal
    s :: I
    i :: Int
end

done(s :: Ising2Tap, t, dt) = done(s.s, t, dt)

function value(m :: Ising2Tap, t, dt)
    value(m.s, t, dt)
    real(m.s.psi[m.i])
end

"""
    ising2(f :: Signal, b1 :: Signal, b2 :: Signal, x1 :: Signal, x2 :: Signal, w12 :: Signal)

Experimental 2-qubit "Ising" model with controllable weights.
Not very interesting at this point, but perhaps with more qubits
it might get interesting as the number of frequencies that get
mixed in will increase, producing a richer sound.
"""
function ising2(f :: Signal, b1 :: Signal, b2 :: Signal, x1 :: Signal, x2 :: Signal, w12 :: Signal)
    z = ComplexF32(0.0f0)
    p1 = ComplexF32(1.0f0)
    m1 = ComplexF32(-1.0f0)
    psi = MVector{4,ComplexF32}(p1, z, z, z)
    sz2 = SMatrix{4,4,ComplexF32}(p1, z, z, z,
                                  z, m1, z, z,
                                  z, z, p1, z,
                                  z, z, z, m1)
    sz1 = SMatrix{4,4,ComplexF32}(p1, z, z, z,
                                  z, p1, z, z,
                                  z, z, m1, z,
                                  z, z, z, m1)
 
    sz12 = sz1 * sz2
    sx1 = SMatrix{4,4,ComplexF32}(z,p1,z,z,
                                  p1,z,z,z,
                                  z,z,z,p1,
                                  z,z,p1,z)
    sx2 = SMatrix{4,4,ComplexF32}(z,z,p1,z,
                                  z,z,z,p1,
                                  p1,z,z,z,
                                  z,p1,z,z)
    Ising2(f, b1, b2, x1, x2, w12, psi, sz1, sz2, sz12, sx1, sx2, 0.0)
end

function ising2(f :: Real, b1 :: Real, b2 :: Real, x1 :: Real, x2 :: Real, w12 :: Real)
    ising2(konst(f), konst(b1), konst(b2), konst(x1), konst(x2), konst(w12))
end

function tap(s :: Ising2, i :: Int)
    Ising2Tap(s,i)
end





