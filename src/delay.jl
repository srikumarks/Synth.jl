mutable struct Delay{S <: Signal, Tap <: Signal} <: Signal
    sig :: S
    tap :: Tap
    maxdelay :: Float64
    line :: Vector{Float32}
    N :: Int
    write_i :: Int
end

function delay(sig :: S, tap :: Tap, maxdelay :: Real; sr=48000) where {S <: Signal, Tap <: Signal}
    N = round(Int, maxdelay * sr)
    @assert N > 0
    Delay(
          sig,
          tap,
          Float64(N / sr),
          zeros(Float32, N),
          N,
          0
         )
end

done(s :: Delay, t, dt) = done(sig, t, dt) || done(tap, t, dt)

function value(sig :: Delay, t, dt)
    v = value(sig, t, dt)
    sig.line[1+sig.write_i] = v
    out = tap(sig, value(sig.tap, t, dt), t, dt)
    sig.write_i = mod(sig.write_i + 1, sig.N)
    return out
end

maxdelay(sig :: Delay) = sig.maxdelay

function tap(sig :: Delay, at, t, dt)
    ix = mod(at, 1.0) / dt
    ixf = sig.write_i - ix
    read_i = floor(Int, ixf)
    frac = ixf - read_i
    mread_i = mod(read_i, N)
    out1 = sig.line[1+read_i]
    out2 = sig.line[1+mod(read_i+1,sig.N)]
    out1 + frac * (out2 - out1)
end


