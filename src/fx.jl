
mutable struct Compressor{S<:Signal,K<:Signal} <: Signal
    sig::S
    k::K
    τ::Float32
    x²::Float32
    wx::Float32
    ws::Float32
end

done(s::Compressor{S}, t, dt) where {S} = done(s.sig, t, dt)

function value(s::Compressor{S}, t, dt) where {S}
    sv = value(s.sig, t, dt)
    k = value(s.k, t, dt)
    amp = 2 ^ (-k * s.x²)
    s.x² = s.wx * s.x² + s.ws * sv * sv
    return amp * sv
end

"""
    compress(s :: Signal, k :: Signal; τ :: AbstractFloat = 0.03f0, samplingrate=48000)

Compresses the signal using a dynamic compression algorithm.

- `s` is the signal to compress
- `k` is the amount of compression to apply. Must be positive. If k == 1, then 
  the compression applied can go up to a factor of half. The more the k, the
  more the compression that's applied for louder sounds.
- `τ` is the time constant (half life) over which the signal strength is
  measured to determine the adaptive compression.
"""
function compress(s::Signal, k::Signal; τ::AbstractFloat = 0.03f0, samplingrate = 48000)
    N = max(1, τ * samplingrate)
    wx = Float32(2^(-1/N))
    ws = 1.0f0 - wx
    Compressor(s, k, Float32(τ), 0.0f0, wx, ws)
end
