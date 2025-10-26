struct LinSeg
    v1::Float32
    dur::Float64
    v2::Float32
    dvdt::Float32
end

struct ExpSeg
    v1::Float32
    logv1::Float32
    dur::Float64
    v2::Float32
    logv2::Float32
    dlogvdt::Float32
end

struct EaseSeg
    v1::Float32
    dur::Float64
    v2::Float32
end

struct HarSeg
    v1::Float32
    v1inv::Float32
    dur::Float64
    v2::Float32
    v2inv::Float32
    dvinvdt::Float32
end

const Seg = Union{LinSeg, ExpSeg, EaseSeg, HarSeg}

function interp(seg::LinSeg, t::Float64)
    seg.v1 + t * seg.dvdt
end

function interp(seg::ExpSeg, t::Float64)
    exp(seg.logv1 + t * seg.dlogvdt)
end

function interp(seg::EaseSeg, t::Float64)
    seg.v1 + (seg.v2 - seg.v1) * easeinout(t / seg.dur)
end

function interp(seg::HarSeg, t::Float64)
    1.0f0 / (seg.v1inv + t * seg.dvinvdt)
end

"""
    easeinout(t::Float64)

For values of t in range [0.0,1.0], this curve rises
smoothly from 0.0 and settles smoothly into 1.0.
We're not usually interested in its values outside
the [0.0,1.0] range.
"""
easeinout(t::Float64) = 0.5*(1.0+cos(π*(t - 1.0)))

"""
    seg(v::Real, dur::Real)
    seg(v1::Real, dur::Real, v2::Real)
    seg(::Type{LinSeg}, v1::Real, dur::Real, v2::Real)
    seg(::Type{ExpSeg}, v1::Real, dur::Real, v2::Real)
    seg(::Type{EaseSeg}, v1::Real, dur::Real, v2::Real)
    seg(::Type{HarSeg}, v1::Real, dur::Real, v2::Real)

Makes a single interpolated segment for use with [`curve`](@ref).
"""
seg(v::Real, dur::Real) = 
    LinSeg(Float32(v), Float64(dur), Float32(v), 0.0f0)
seg(v1::Real, dur::Real, v2::Real) = 
    LinSeg(Float32(v2), Float64(dur), Float32(v2), Float32((v2 - v1) / dur))
seg(::Type{LinSeg}, v1::Real, dur::Real, v2::Real) = seg(v1, dur, v2)
seg(::Type{ExpSeg}, v1::Real, dur::Real, v2::Real) = begin
    logv1 = log(v1)
    logv2 = log(v2)
    dlogvdt = (logv2 - logv1) / dur
    ExpSeg(Float32(v1), Float32(logv1), Float64(dur), Float32(v2), Float32(logv2), Float32(dlogvdt))
end
seg(::Type{EaseSeg}, v1::Real, dur::Real, v2::Real) =
    EaseSeg(Float32(v1), Float64(dur), Float32(v2))
seg(::Type{HarSeg}, v1::Real, dur::Real, v2::Real) = begin
    v1inv = 1.0f0 / Float32(v1)
    v2inv = 1.0f0 / Float32(v2)
    dvinvdt = (v2inv - v1inv) / dur
    HarSeg(Float32(v1), v1inv, Float64(dur), Float32(v2), v2inv, Float32(dvinvdt))
end

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
    curve(ty::Type, v::AbstractVector{<:Tuple{Real,Real}}; stop = false)
    curve(v::AbstractVector{<:Tuple{Real,Real}}; stop = false)

Makes a piece-wise curve given a vector of segment specifications.
Each `Seg` captures the start value, end value, duration of the
segment, and the interpolation method to use in between.

If you pass `true` for `stop`, it means the curve will be `done`
once all the segments are done. Otherwise the curve will yield
the last value forever.

The "tuple" variants take a vector of (t,v) pairs and construct
a curve out of it using a common interpolation mechanism. The `Vector{Seg}`
is the most general since it can accommodate a combination of linear,
exponential, etc., but these are convenient for use when a common
interpolation type is required.

Curves support `map` and basic arithmetic combinations with real numbers.
See also [`stretch`](@ref) and [`concat`](@ref)
"""
function curve(segments::Vector{Seg}; stop = false)
    times = vcat(0.0, accumulate(+, [v.dur for v in segments]))
    Curve(segments, 1, 0.0, times, times[end], stop)
end

function curve(ty::Type, v::AbstractVector{<:Tuple{Real,Real}}; stop = false)
    segs = [seg(ty, v[i][2], v[i+1][1] - v[i][1], v[i+1][2]) for i in 1:length(v)-1]
    curve(segs; stop)
end

function curve(v::AbstractVector{<:Tuple{Real,Real}}; stop = false)
    segs = [seg(v[i][2], v[i+1][1] - v[i][1], v[i+1][2]) for i in 1:length(v)-1]
    curve(segs; stop)
end

done(s::Curve, t, dt) = s.stop_at_end ? s.ti >= s.tend : false

function value(s::Curve, t, dt)
    t = s.ti
    s.ti += dt
    while true
        if t >= s.tend || s.i > length(s.segments)
            return interp(s.segments[end], s.tend - s.times[end-1])
        elseif t < s.times[s.i+1]
            return interp(s.segments[s.i], t - s.times[s.i])
        else
            s.i += 1
        end
    end
end

function Base.map(fn::Function, seg::LinSeg)
    fv1 = Float32(fn(seg.v1))
    fv2 = Float32(fn(seg.v2))
    LinSeg(fv1, seg.dur, fv2, Float32((fv2 - fv1)/seg.dur))
end

function Base.map(fn::Function, seg::ExpSeg)
    fv1 = Float32(fn(seg.v1))
    fv2 = Float32(fn(seg.v2))
    logfv1 = log(fv1)
    logfv2 = log(fv2)
    ExpSeg(fv1, logfv1, seg.dur, fv2, logfv2, Float32((logfv2 - logfv1)/seg.dur))
end

function Base.map(fn::Function, seg::EaseSeg)
    v1 = Float32(fn(seg.v1))
    v2 = Float32(fn(seg.v2))
    EaseSeg(v1, seg.dur, v1)
end

function Base.map(fn::Function, seg::HarSeg)
    v1 = Float32(fn(seg.v1))
    v2 = Float32(fn(seg.v2))
    v1inv = 1.0f0/v1
    v2inv = 1.0f0/v2
    dvinvdt = (v2inv - v1inv) / seg.dur
    HarSeg(v1, v1inv, seg.dur, v2, v2inv, dvinvdt)
end

function Base.map(fn::Function, c::Curve)
    Curve(map(fn, c.segments), 0, 0.0, c.times, c.tend, c.stop_at_end)
end

stretch(factor::Real, seg::LinSeg) = 
    LinSeg(seg.v1, Float64(factor * seg.dur), seg.v2, Float32(seg.dvdt / factor))
stretch(factor::Real, seg::ExpSeg) = 
    ExpSeg(seg.v1, seg.logv1, Float64(factor * seg.dur), seg.v2, seg.logv2, Float32(seg.dlogvdt / factor))
stretch(factor::Real, seg::EaseSeg) = 
    EaseSeg(seg.v1, Float64(factor * seg.dur), seg.v2)
stretch(factor::Real, seg::HarSeg) = 
    HarSeg(seg.v1, seg.v1inv, Float64(factor * seg.dur), seg.v2, seg.v2inv, Float32(seg.dvinvdt / factor))


"""
    stretch(factor::Real, c::Curve) :: Curve

Stretches the times of the curve segments by the given factor.
"""
function stretch(factor::Real, c::Curve)
    f = Float64(factor)
    Curve(
          map(seg -> stretch(f, seg), c.segments), 
          0,
          0.0,
          map(t -> f * t, c.times),
          c.tend * f,
          c.stop_at_end
         )
end

"""
    concat(c1::Curve, c2::Curve; stop::Bool=c2.stop_at_end) :: Curve

Concatenates the two curves in time.
"""
function concat(c1::Curve, c2::Curve; stop::Bool=c2.stop_at_end)
    Curve(
          vcat(c1.segments, c2.segments),
          0,
          0.0,
          vcat(c1.times, map(t -> t + c1.tend, c2.times)),
          c1.tend + c2.tend,
          stop
         )
end

(Base.:+)(dv::Real, c::Curve) = map(v -> v + dv, c)
(Base.:+)(c::Curve, dv::Real) = map(v -> v + dv, c)
(Base.:-)(dv::Real, c::Curve) = map(v -> dv - v, c)
(Base.:-)(c::Curve, dv::Real) = map(v -> v - dv, c)
(Base.:*)(f::Real, c::Curve) = map(v -> f * v, c)
(Base.:*)(c::Curve, f::Real) = map(v -> f * v, c)
(Base.:/)(f::Real, c::Curve) = map(v -> f / v, c)
(Base.:/)(c::Curve, f::Real) = map(v -> v / f, c)
