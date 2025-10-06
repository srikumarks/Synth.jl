mutable struct WaveShape{S<:Signal} <: Signal
    f::Function
    sig::S
end

"""
    waveshape(f, sig :: Signal)
    map(f, sig :: Signal)

Maps a function over the signal. The result is a signal.
`map` and `waveshape` are aliases for signals.
"""
waveshape(f, sig::Signal) = WaveShape(f, sig)
Base.map(f::Function, sig::Signal) = WaveShape(f, sig)

done(s::WaveShape, t, dt) = done(s.sig, t, dt)
value(s::WaveShape, t, dt) = Float32(s.f(value(s.sig, t, dt)))

"""
    linearmap(a1 :: Real, a2 :: Real, b1 :: Real, b2 :: Real, s :: Signal)

Maps the input signal from its range to a new range.
"""
function linearmap(a1::Real, a2::Real, b1::Real, b2::Real, s::Signal)
    @assert abs(a2 - a1) > 0.0
    rate = (b2 - b1) / (a2 - a1)
    waveshape(x -> b1 + rate * (x - a1), s)
end


"""
    expmap(a1 :: Real, a2 :: Real, b1 :: Real, b2 :: Real, s :: Signal)

Similar to the job of [`linearmap`](@ref) but does exponential interpolated mapping.
This implies all four values and the signal value **must** be positive.
"""
function expmap(a1::Real, a2::Real, b1::Real, b2::Real, s::Signal)
    @assert a1 > 0.0
    @assert a2 > 0.0
    @assert b1 > 0.0
    @assert b2 > 0.0
    la1 = log(a1)
    la2 = log(a2)
    lb1 = log(b1)
    lb2 = log(b2)
    rate = (lb2 - lb1) / (la2 - la1)
    waveshape(x -> exp(lb1 + rate * (log(x) - la1)), s)
end
