
mutable struct Line <: Signal
    v1 :: Float32
    duration_secs :: Float32
    v2 :: Float32
end

done(s :: Line, t, dt) = t > s.duration_secs
function value(s :: Line, t, dt)
    if t <= 0.0f0 
        s.v1
    elseif t <= s.duration_secs
        (s.v1 + (s.v2 - s.v1) * t / s.duration_secs)
    else 
        s.v2
    end
end

"""
    line(v1 :: Real, duration_secs :: Real, v2 :: Real)

Makes a signal that produces `v1` for `t < 0.0` and `v2` for `t > duration_secs`.
In between the two times, it produces a linearly varying value between
`v1` and `v2`. This signal is finite in extent.
"""
line(v1 :: Real, duration_secs :: Real, v2 :: Real) = Line(Float32(v1), Float32(duration_secs), Float32(v2))

mutable struct Expon <: Signal
    v1 :: Float32
    duration_secs :: Float32
    v2 :: Float32
    lv1 :: Float32
    lv2 :: Float32
    dlv :: Float32
end

"""
    expon(v1 :: Real, duration_secs :: Real, v2 :: Real)

Similar to line, but does exponential interpolation from `v1` to `v2`
over `duration_secs`. Note that both values must be `> 0.0` for this
to be valid.
"""
function expon(v1 :: Real, duration_secs :: Real, v2 :: Real)
    @assert v1 > 0.0
    @assert v2 > 0.0
    @assert duration_secs > 0.0
    Expon(Float32(v1), Float32(duration_secs), Float32(v2), log(Float32(v1)), log(Float32(v2)), log(Float32(v2/v1)))
end

done(s :: Expon, t, dt) = t > s.duration_secs
function value(s :: Expon, t, dt)
    if t <= 0.0f0
        s.v1
    elseif t <= s.duration_secs
        exp(s.lv1 + s.dlv * t / duration_secs)
    else
        s.v2
    end
end

shape(::Val{:line}, startval, dur, endval) = line(startval, dur, endval)
shape(::Val{:expon}, startval, dur, endval) = expon(startval, dur, endval)

"""
    interp4(x, x1, x2, x3, x4)

Four point interpolation.

- `x` is expected to be in the range `[0,1]`.

This is a cubic function of `x` such that -

- f(-1) = x1
- f(0) = x2
- f(1) = x3
- f(2) = x4
"""
function interp4(x, x1, x2, x3, x4)
    a = x2
    b = (x3 - 3x2 + 2x1)/6
    c = (x1 - x2)/2
    d = - (b + c)
    return a + x * (b + x * (c + d * x))
end


"""
    raisedcos(x, overlap, scale=1.0f0)

A "raised cosine" curve has a rising part that is shaped like cos(x-π/2)+1
and a symmetrically shaped falling part. If the `overlap` is 0.5, then
there is no intervening portion between the rising and falling parts
(`x` is in the range `[0,1]`). For `overlap` values less than 0.5,
the portion between the rising and falling parts will be clamped to 1.0.

For example, `raisedcos(x, 0.25)` will give you a curve that will smoothly
rise from 0.0 at x=0.0 to 1.0 at x=0.25, stay fixed at 1.0 until x = 0.75
and smoothly decrease to 0.0 at x=1.0.
"""
function raisedcos(x, overlap, scale=1.0f0)
    if x < overlap
        return 0.5f0 * (cos(Float32(π * (x/overlap - 1.0))) + 1.0f0)
    elseif x > scale - overlap
        return 0.5f0 * (cos(Float32(π * ((scale - x)/overlap - 1.0))) + 1.0f0)
    else
        return 1.0f0
    end
end


