
mutable struct Konst <: Signal
    k :: Float32
end

value(s :: Konst, t, dt) = s.k
done(s :: Konst, t, dt) = false

"""
    konst(v::Real)

Makes a constant valued signal.
"""
function konst(v::T) where {T <: Real}
    Konst(Float32(v))
end

"""
    mutable struct Aliasable{S <: Signal} <: Signal

A signal, once constructed, can only be used by one "consumer".
In some situations, we want a signal to be plugged into multiple
consumers. For these occasions, make the signal aliasable by calling
`aliasable` on it and use the alisable signal everywhere you need it
instead. 

**Note**: It only makes sense to make a single aliasable version of a signal.
Repeated evaluation of a signal is avoided by `Aliasable` by storing the
recently computed value for a given time. So it assumes that time progresses
linearly.
"""
mutable struct Aliasable{S <: Signal} <: Signal
    sig :: S
    t :: Float64
    v :: Float32
end

aliasable(sig :: S) where {S <: Signal} = Aliasable(sig, -1.0, 0.0f0)
done(s :: Aliasable, t, dt) = done(s.sig, t, dt)
function value(s :: Aliasable, t, dt)
    if t > s.t
        s.t = t
        s.v = Float32(value(s.sig, t, dt))
    end
    return s.v
end

"""
    rescale(maxamp :: Float32, samples :: Vector{Float32}) :: Vector{Float32}

Rescales the samples so that the maximum extent fits within the given
`maxamp`. The renderer automatically rescales to avoid clamping.
"""
function rescale(maxamp, samples)
    sadj = samples .- (sum(samples) / length(samples))
    amp = maximum(abs.(samples))
    if amp < 1e-5
        return zeros(Float32, length(samples))
    else
        return Float32.(sadj .* (maxamp / amp))
    end
end


