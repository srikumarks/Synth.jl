mutable struct Delay{S <: Signal} <: Signal
    sig :: S
    maxdelay :: Float64
    line :: Vector{Float32}
    N :: Int
    write_i :: Int
    t :: Float64
    v :: Float32
end

"""
    delay(sig :: S, maxdelay :: Real; samplingrate=48000) where {S <: Signal, Tap <: Signal}

Sets up a delay ring buffer through which the given signal is passed. 
A delay is pretty much a pass through and is useful only in conjunction
with [`tap`](@ref). A delay is aliasable on its own, which means you can
make multiple tap points on the same delay based on time varying tap
locations.
- `sig` is the signal that is delayed.
- `tap` is the signal that determines how much delay is applied.
- `maxdelay` is the maximum amount of delay possible.
- `samplingrate` is the sampling rate in Hz. (This is needed to compute buffer size.)
"""
function delay(sig :: S, maxdelay :: Real; samplingrate=48000) where {S <: Signal}
    N = round(Int, maxdelay * samplingrate)
    @assert N > 0
    Delay(
          sig,
          Float64(N / samplingrate),
          zeros(Float32, N),
          N,
          0,
          0.0,
          0.0f0
         )
end

done(s :: Delay, t, dt) = done(sig, t, dt)

function value(sig :: Delay, t, dt)
    if t > sig.t
        sig.t = t
        v = value(sig, t, dt)
        sig.v = v
        sig.line[1+sig.write_i] = v
        sig.write_i = mod(sig.write_i + 1, sig.N)
    end
    sig.v
end

"""
    maxdelay(sig :: Delay)

Returns the maximum delay (in seconds) supported by the given delay unit.
"""
maxdelay(sig :: Delay) = sig.maxdelay

function tapat(sig :: Delay, at, t, dt)
    ix = at / dt # The number of samples into the past to read.
    ixf = sig.write_i - ix - 1 # The index of the sample in the
                               # circular buffer corresponding to the delay.
    read_i = floor(Int, ixf)   # The integer index.
    frac = ixf - read_i        # The fractional part for interpolation.
    mread_i = mod(read_i, N)   # Wrapped around index. 0-based.
    out1 = sig.line[1+mread_i] # First value.
    out2 = sig.line[1+mod(1+mread_i,sig.N)] # Second value
    out1 + frac * (out2 - out1) # Interpolated value.
end


struct Tap{S <: Signal, T <: Signal}
    delay :: Delay{S}
    tap :: T
end

done(s :: Tap{S,T}, t, dt) where {S <: Signal, T <: Signal} = done(s.delay, t, dt) || done(s.tap, t, dt)

function value(s :: Tap{S,T}, t, dt) where {S <: Signal, T <: Signal}
    d = value(s.delay, t, dt)
    at = value(s.tap, t, dt)
    tapat(s, at, t, dt)
end

"""
    tap(d :: Delay, t :: T) where {T <: Signal}
    tap(d :: Delay, t :: Real)

You can setup multiple time varying tap points on a delay line
by calling `tap` multiple times and using it elsewhere. Since
a delay is intrinsically aliasable, this is possible without
further ado.
"""
function tap(d :: Delay, t :: T) where {T <: Signal}
    Tap(d, t)
end

function tap(d :: Delay, t :: Real)
    Tap(d, konst(t))
end
