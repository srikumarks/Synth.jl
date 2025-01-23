
mutable struct Filter1{S <: Signal, G <: Signal} <: Signal
    sig :: S
    gain :: G
    xn_1 :: Float32
    xn :: Float32
end

"""
    filter1(s :: Signal, gain :: Signal)

A first order filter where the gain factor that controls the
bandwidth of the filter can be live controlled.
"""
function filter1(s :: Signal, gain :: Signal)
    Filter1(s, gain, 0.0f0, 0.0f0)
end

function filter1(s :: Signal, gain :: Real)
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

"""
    filter2(s :: Signal, f :: Signal, g :: Signal)
    filter2(s :: Signal, f :: Signal, g :: Real)
    filter2(s :: Signal, f :: Real, g :: Real)

Constructs a second order filter where the frequency and the gamma can be
controlled live.
"""
function filter2(s :: Signal, f :: Signal, g :: Signal)
    Filter2(s, f, g, 0.0f0, 0.0f0)
end
function filter2(s :: Signal, f :: Signal, g :: Real)
    filter2(s, f, konst(g))
end
function filter2(s :: Signal, f :: Real, g :: Real)
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

"""
    fir(filt :: Vector{Float32}, dilation :: Signal, sig :: Signal)

Constructs a "finite impulse response" (FIR) filter with the given `filt` as
the impulse response. The `dilation` factor can be used to stretch short vectors using
linear interpolation.
"""
function fir(filt :: Vector{Float32}, dilation :: Signal, sig :: Signal)
    N = length(filt)
    FIR(sig, filt, N, dilation, 2N, zeros(Float32, 2N), 1)
end

done(s :: FIR, t, dt) = done(s.filt, t, dt) || done(s.dilation, t, dt)

function dilatedfilt(s :: FIR, i, dilation)
    di = 1 + (i-1) * dilation
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
    dilation = value(s.dilation, t, dt)
    f = sum(dilatedfilt(s,i,dilation) * s.history[1+mod(s.offset-i, s.N2)] for i in 1:N)
    s.offset += 1
    if s.offset > s.N2
        s.offset = 1
    end
    return f
end

abstract type BiquadType end
struct LowPassFilter <: BiquadType end
struct HighPassFilter <: BiquadType end
struct BandPassFilter <: BiquadType end
struct BandPassFilter0 <: BiquadType end

mutable struct BiquadCoeffs{Ty <: BiquadType}
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

function BiquadCoeffs()
    BiquadCoeffs(0.0f0, 0.0f0, 0.0f0, 0.0f0, 0.0f0, 0.0f0, 0.0f0, 0.0f0, 0.0f0, 0.0f0)
end

mutable struct Biquad{Ty, S <: Signal, F <: Signal, Q <: Signal} <: Signal
    sig :: S
    freq :: F
    q :: Q
    xn_1 :: Float32
    xn_2 :: Float32
    yn_1 :: Float32
    yn_2 :: Float32
    c :: BiquadCoeffs{Ty}
end


function biquad(::Type{T}, sig :: Signal, freq :: Konst, q :: Konst, dt) where {T <: BiquadType}
    b = Biquad{T,S,Konst,Konst}(sig, freq, q, 0.0f0, 0.0f0, 0.0f0, 0.0f0, BiquadCoeffs{T}())
    computebiquadcoeffs(b.c, value(freq, 0.0, 0.0), value(q, 0.0, 0.0), dt)
    return b
end

function biquad(::Type{T}, sig :: Signal, freq :: Konst, q :: Real, dt) where {T <: BiquadType}
    biquad{T}(sig, freq, konst(q), dt)
end

function biquad(::Type{T}, sig :: Signal, freq :: Real, q :: Konst, dt) where {T <: BiquadType}
    biquad{T}(sig, konst(freq), q, dt)
end

function biquad(::Type{T}, sig :: Signal, freq :: Real, q :: Real, dt) where {T <: BiquadType}
    biquad{T}(sig, konst(freq), konst(q), dt)
end

function biquad(::Type{T}, sig :: Signal, freq :: Signal, q :: Signal, dt) where {T <: BiquadType}
    Biquad{T,S,F,Q}(sig, freq, q, 0.0f0, 0.0f0, 0.0f0, 0.0f0, BiquadCoeffs{T}())
end

function computebiquadcoeffs(c :: BiquadCoeffs{LowPassFilter}, f, q, dt)
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

function computebiquadcoeffs(c :: BiquadCoeffs{HighPassFilter}, f, q, dt)
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

function computebiquadcoeffs(c :: BiquadCoeffs{BandPassFilter}, f, q, dt)
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

function computebiquadcoeffs(c :: BiquadCoeffs{BandPassFilter0}, f, q, dt)
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

function value(s :: Biquad{T,S,Konst,Konst}, t, dt) where {T <: BiquadType, S <: Signal}
    # We can avoid repeated coefficient computation for the case where the frequency
    # and Q factor are both constant.
    computenextvalue(s, t, dt)
end

function value(s :: Biquad, t, dt)
    computebiquadcoeffs(s.c, value(s.freq, t, dt), value(s.q, t, dt))
    computenextvalue(s, t, dt)
end

function computenextvalue(s :: Biquad, t, dt)
    xn = value(s.sig, t, dt)
    yn = (s.b0 * xn + s.b1 * s.xn_1 + s.b2 * s.xn_2 - s.a1 * s.yn_1 - s.a2 * s.yn_2) / s.a0
    s.xn_2 = s.xn_1
    s.xn_1 = xn
    s.yn_2 = s.yn_1
    s.yn_1 = yn
    return yn
end

"""
    lpf(sig :: Signal, freq, q; samplingrate=48000)

Standard second order LPF with frequency and Q factor.
"""
function lpf(sig :: Signal, freq, q; samplingrate=48000)
    biquad(LowPassFilter, sig, freq, q, 1/samplingrate)
end

"""
    bpf(sig :: Signal, freq, q; samplingrate=48000)

Standard second order bandpass filter with given centre frequency
and Q factor. 
"""
function bpf(sig :: Signal, freq, q; samplingrate=48000)
    biquad(BandPassFilter, sig, freq, q, 1/samplingrate)
end

"""
    bpf0(sig :: Signal, freq, q; samplingrate=48000)

Standard second order bandpass filter with given centre frequency
and Q factor. This variant of `bpf` gives constant 0dB peak gain
instead of the peak gain being determined by Q.
"""
function bpf0(sig :: Signal, freq, q; samplingrate=48000)
    biquad(BandPassFilter0, sig, freq, q, 1/samplingrate)
end

"""
    hpf(sig :: Signal, freq, q; samplingrate=48000)

Standard second order high pass filter with given cut off frequency and Q.
"""
function hpf(sig :: Signal, freq, q; samplingrate=48000)
    biquad(HighPassFilter, sig, freq, q, 1/samplingrate)
end


