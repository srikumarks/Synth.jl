

struct Seg
    dur::Float64
    interp::Function
end

function interpolator(::Val{:linear}, v1::Float32, v2::Float32, dur::Float64)
    delta = (v2 - v1)
    return (t::Float64) -> v1 + delta * t
end

"""
    easeinout(t::Float64)

For values of t in range [0.0,1.0], this curve rises
smoothly from 0.0 and settles smoothly into 1.0.
We're not usually interested in its values outside
the [0.0,1.0] range.
"""
easeinout(t::Float64) = 0.5*(1.0+cos(π*(t - 1.0)))

function interpolator(::Val{:ease}, v1::Float32, v2::Float32, dur::Float64)
    delta = v2 - v1
    return (t::Float64) -> v1 + delta * easeinout(t)
end

function interpolator(::Val{:exp}, v1::Float32, v2::Float32, dur::Float64)
    v1 = log(v1)
    v2 = log(v2)
    delta = (v2 - v1)
    return (t::Float64) -> exp(v1 + delta * t)
end

function interpolator(::Val{:harmonic}, v1::Float32, v2::Float32, dur::Float64)
    v1 = 1.0/v1
    v2 = 1.0/v2
    delta = (v2 - v1)
    return (t::Float64) -> 1.0/(v1 + delta * t)
end

"""
    Seg(v :: Real, dur :: Float64)

A segment that holds the value `v` for the duration `dur`.
"""
function Seg(v::Real, dur::Float64)
    vf = Float32(v)
    Seg(dur, (t::Float64) -> vf)
end


"""
    Seg(v1 :: Real, v2 :: Real, dur :: Float64, interp::Symbol = :linear)

Constructs a general segment that takes value from `v1` to `v2`
over `dur` using the specified interpolator `interp`.

`interp` can take on one of `[:linear, :exp, :cos, :harmonic]`.
The default interpolation is `:linear`.
"""
function Seg(v1::Real, v2::Real, dur::Float64, interp::Symbol = :linear)
    v1f = Float32(v1)
    v2f = Float32(v2)
    Seg(dur, interpolator(Val(interp), v1f, v2f, dur))
end

seg(v, dur) = Seg(v, dur)
seg(v1, v2, dur, interp) = Seg(v1, v2, dur, interp)

mutable struct Curve <: Signal
    segments::Vector{Seg}
    i::Int
    ti::Float64
    times::Vector{Float64}
    tend::Float64
    stop_at_end::Bool
end

"""
    curve(segments :: Vector{Seg}; stop=false)

Makes a piece-wise curve given a vector of segment specifications.
Each `Seg` captures the start value, end value, duration of the
segment, and the interpolation method to use in between.

If you pass `true` for `stop`, it means the curve will be `done`
once all the segments are done. Otherwise the curve will yield
the last value forever.
"""
function curve(segments::Vector{Seg}; stop = false)
    times = vcat(0.0, accumulate(+, [v.dur for v in segments]))
    Curve(segments, 1, 0.0, times, times[end], stop)
end

done(s::Curve, t, dt) = s.stop_at_end ? t >= s.tend : false
function value(s::Curve, t, dt)
    if t >= s.tend || s.i > length(s.segments)
        return s.segments[end].interp(1.0)
    end
    if t < s.times[s.i+1]
        seg = s.segments[s.i]
        trel = (t - s.times[s.i]) / seg.dur
        return seg.interp(trel)
    else
        s.i += 1
        return value(s, t, dt)
    end
end
