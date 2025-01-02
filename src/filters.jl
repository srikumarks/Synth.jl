
mutable struct Filter1{S <: Signal, G <: Signal} <: Signal
    sig :: S
    gain :: G
    xn_1 :: Float32
    xn :: Float32
end

function filter1(s :: S, gain :: G) where {S <: Signal, G <: Signal}
    Filter1(s, gain, 0.0f0, 0.0f0)
end

function filter1(s :: S, gain :: Real) where {S <: Signal}
    Filter1(s, konst(gain), 0.0f0, 0.0f0)
end
done(s :: Filter1, t, dt) = done(s.sig, t, dt)

const twoln2 = 2.0 * log(2)

function value(s :: Filter1, t, dt)
    v = value(s.sig, t, dt)
    g = value(s.gain, t, dt)
    dg = twoln2 * g * dt
    xnp1 = s.xn_1 - dg * (s.xn - v)
    s.xn_1 = s.xn
    s.xn = xnp1
    return s.xn_1
end

# Unit step function. 
struct U <: Signal end

done(u :: U, t, dt) = false
value(u :: U, t, dt) = if t > 0.0 1.0 else 0.0 end

mutable struct Filter2{S <: Signal, F <: Signal, G <: Signal} <: Signal
    sig :: S
    f :: F
    g :: G
    xn_1 :: Float32 # x[n-1]
    xn :: Float32   # x[n]
end

function filter2(s :: S, f :: F, g :: G) where {S <: Signal, F <: Signal, G <: Signal}
    Filter2(s, f, g, 0.0f0, 0.0f0)
end

function filter2(s :: S, f :: F, g :: Real) where {S <: Signal, F <: Signal}
    filter2(s, f, konst(g))
end

function filter2(s :: S, f :: Real, g :: Real) where {S <: Signal}
    filter2(s, konst(f), konst(g))
end

done(s :: Filter2, t, dt) = done(s.sig, t, dt) || done(s.f, t, dt) || done(s.g, t, dt)

function value(s :: Filter2, t, dt)
    v = value(s.sig, t, dt)
    f = value(s.f, t, dt)
    w = 2 * π * f
    g = value(s.g, t, dt)
    dϕ = w * dt
    gdϕ = g * dϕ
    dϕ² = dϕ * dϕ
    xnp1 = (dϕ² * v + (2.0 - dϕ²) * s.xn + (gdϕ - 1.0) * s.xn_1) / (1.0 + gdϕ)
    s.xn_1 = s.xn
    s.xn = xnp1
    return s.xn_1
end

mutable struct FIR{S <: Signal, D <: Signal} <: Signal
    sig :: S
    filt :: Vector{Float32}
    N :: Int
    dilation :: D
    N2 :: Int
    history :: Vector{Float32}
    offset :: Int
end

function fir(filt :: Vector{Float32}, dilation :: D, sig :: S) where {S <: Signal, D <: Signal}
    N = length(filt)
    FIR(sig, filt, N, dilation, 2N, zeros(Float32, 2N), 1)
end

done(s :: FIR, t, dt) = done(s.filt, t, dt) || done(s.dilation, t, dt)

function dilatedfilt(s :: FIR, i)
    di = 1 + (i-1) * s.dilation
    dii = floor(Int, di)
    difrac = di - dii
    if dii < s.N
        s.filt[dii] + difrac * (s.filt[dii+1] - s.filt[dii])
    else
        s.filt[dii]
    end
end

function value(s :: FIR{S}, t, dt) where {S <: Signal}
    v = value(s.sig, t, dt)
    s.history[s.offset] = v
    f = sum(dilatedfilt(s,i) * s.history[1+mod(s.offset-i, s.N2)] for i in 1:N)
    s.offset += 1
    if s.offset > s.N2
        s.offset = 1
    end
    return f
end

mutable struct Biquad{Ty, S <: Signal, F <: Signal, Q <: Signal} <: Signal
    ty :: Ty
    sig :: S
    freq :: F
    q :: Q
    xn_1 :: Float32
    xn_2 :: Float32
    yn_1 :: Float32
    yn_2 :: Float32
    w0 :: Float32
    cw0 :: Float32
    sw0 :: Float32
    alpha :: Float32
    b0 :: Float32
    b1 :: Float32
    b2 :: Float32
    a0 :: Float32
    a1 :: Float32
    a2 :: Float32
end

function Biquad(ty::Val, sig :: S, freq :: Konst, q :: Konst, dt) where {S <: Signal}
    computebiquadcoeffs(ty,
        Biquad(ty, sig, freq, q, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0),
        value(freq, 0.0, 0.0),
        value(q, 0.0, 0.0),
        dt)
end

function Biquad(ty::Val, sig :: S, freq :: F, q :: Q) where {S <: Signal, F <: Real, Q <: Real}
    Biquad(ty, sig, konst(freq), konst(q), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
end

function Biquad(ty::Val, sig :: S, freq :: F, q :: Q) where {S <: Signal, F <: Signal, Q <: Real}
    Biquad(ty, sig, freq, konst(q), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
end

function Biquad(ty::Val, sig :: S, freq :: F, q :: Q) where {S <: Signal, F <: Real, Q <: Signal}
    Biquad(ty, sig, konst(freq), q, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
end

function Biquad(ty::Val, sig :: S, freq :: F, q :: Q) where {S <: Signal, F <: Signal, Q <: Signal}
    Biquad(ty, sig, freq, q, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
end

function computebiquadcoeffs(::Val{:lpf}, c :: Biquad, f, q, dt)
    w0 = 2 * pi * f * dt
    sw0, cw0 = sincos(w0)
    c.w0 = w0
    c.sw0 = sw0
    c.cw0 = cw0
    c.alpha = sw0 / (2 * q)
    c.b1 = 1 - cw0
    c.b0 = c.b2 = c.b1/2
    c.a0 = 1 + c.alpha
    c.a1 = -2 * cw0
    c.a2 = 1 - c.alpha
    c
end

function computebiquadcoeffs(::Val{:hpf}, c :: Biquad, f, q, dt)
    w0 = 2 * pi * f * dt
    sw0, cw0 = sincos(w0)
    c.w0 = w0
    c.sw0 = sw0
    c.cw0 = cw0
    c.alpha = sw0 / (2 * q)
    c.b0 = (1+cw0) / 2
    c.b1 = -2.0 * c.b0
    c.b2 = c.b0
    c.a0 = 1 + c.alpha
    c.a1 = -2 * cw0
    c.a2 = 1 - c.alpha
    c
end

function computebiquadcoeffs(::Val{:bpf}, c :: Biquad, f, q, dt)
    w0 = 2 * pi * f * dt
    sw0, cw0 = sincos(w0)
    c.w0 = w0
    c.sw0 = sw0
    c.cw0 = cw0
    c.alpha = sw0 / (2 * q)
    c.b0 = sw0 / 2
    c.b1 = 0.0
    c.b2 = -c.b0
    c.a0 = 1 + c.alpha
    c.a1 = -2 * cw0
    c.a2 = 1 - c.alpha
    c
end

function computebiquadcoeffs(::Val{:bpf0}, c :: Biquad, f, q, dt)
    w0 = 2 * pi * f * dt
    sw0, cw0 = sincos(w0)
    c.w0 = w0
    c.sw0 = sw0
    c.cw0 = cw0
    c.alpha = sw0 / (2 * q)
    c.b0 = c.alpha
    c.b1 = 0.0
    c.b2 = -c.b0
    c.a0 = 1 + c.alpha
    c.a1 = -2 * cw0
    c.a2 = 1 - c.alpha
    c
end


done(s :: Biquad, t, dt) = done(s.sig, t, dt) || done(s.freq, t, dt) || done(s.q, t, dt)

function value(s :: Biquad{Ty,S,Konst,Konst}, t, dt) where {Ty, S <: Signal}
    xn = value(s.sig, t, dt)
    yn = (s.b0 * xn + s.b1 * s.xn_1 + s.b2 * s.xn_2 - s.a1 * s.yn_1 - s.a2 * s.yn_2) / s.a0
    s.xn_2 = s.xn_1
    s.xn_1 = xn
    s.yn_2 = s.yn_1
    s.yn_1 = yn
    return yn
end

function value(s :: Biquad, t, dt)
    xn = value(s.sig, t, dt)
    f = value(s.freq, t, dt)
    q = value(s.q, t, dt)
    computebiquadcoeffs(s.ty, s, f, q)
    yn = (s.b0 * xn + s.b1 * s.xn_1 + s.b2 * s.xn_2 - s.a1 * s.yn_1 - s.a2 * s.yn_2) / s.a0
    s.xn_2 = s.xn_1
    s.xn_1 = xn
    s.yn_2 = s.yn_1
    s.yn_1 = yn
    return yn
end

function lpf(sig :: S, freq, q, dt = 1/48000) where {S <: Signal}
    Biquad(Val(:lpf), sig, freq, q, dt)
end

function bpf(sig :: S, freq, q, dt = 1/48000) where {S <: Signal}
    Biquad(Val(:bpf), sig, freq, q, dt)
end

function bpf0(sig :: S, freq, q, dt = 1/48000) where {S <: Signal}
    Biquad(Val(:bpf0), sig, freq, q, dt)
end

function hpf(sig :: S, freq, q, dt = 1/48000) where {S <: Signal}
    Biquad(Val(:hpf), sig, freq, q, dt)
end


