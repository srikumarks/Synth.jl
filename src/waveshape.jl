mutable struct WaveShape{S <: Signal} <: Signal
    f :: Function
    sig :: S
end

"Maps a function over the signal. The result is a signal."
waveshape(f, sig :: S) where {S <: Signal} = WaveShape(f, sig)
done(s :: WaveShape, t, dt) = done(s.sig, t, dt)
value(s :: WaveShape, t, dt) = Float32(s.f(value(s.sig, t, dt)))

function linearmap(a1 :: Real, a2 :: Real, b1 :: Real, b2 :: Real, s :: S) where {S <: Signal}
    rate = (b2 - b1) / (a2 - a1)
    waveshape(x -> b1 + rate * (x - a1), s)
end



