
mutable struct Konst <: Signal
    k :: Float32
end

value(s :: Konst, t, dt) = s.k
done(s :: Konst, t, dt) = false

"""
    konst(v::Real)

Makes a constant valued signal. Useful with functions that accept
signals but we only want to use a constant value for it.
"""
function konst(v::T) where {T <: Real}
    Konst(Float32(v))
end

"""
    rescale(maxamp :: Real, samples :: AbstractArray) :: Vector{Float32}

Rescales the samples so that the maximum extent fits within the given `maxamp`
(which must be positive). The renderer automatically rescales to avoid
clamping.
"""
function rescale(maxamp :: Real, samples :: AbstractArray)
    @assert maxamp > 0.0 "The maximum allowed amplitude must be a positive number."
    sadj = samples .- (sum(samples) / length(samples))
    amp = maximum(abs.(samples))
    if amp < 1e-5
        return zeros(Float32, length(samples))
    else
        return Float32.(sadj .* (maxamp / amp))
    end
end


struct Clamp{S <: Signal}
    sig :: S
    minval :: Float32
    maxval :: Float32
end

done(s :: Clamp{S}, t, dt) where {S <: Signal} = done(s.sig, t, dt)
value(s :: Clamp{S}, t, dt) where {S <: Signal} = max(s.minval, min(s.maxval, value(s.sig, t, dt)))

"""
    clamp(minval::Real, maxval::Real, sig::Signal)
    clamp(minval::Real, maxval::Real, sig::Stereo{L,R}) where {L <: Signal, R <: Signal}

Clamps the given signal to the give minimum and maximum values. 
Supports stereo signals and clamps the individual channels.
"""
function clamp(minval::Real, maxval::Real, sig::Signal)
    @assert minval <= maxval
    Clamp(sig, Float32(minval), Float32(maxval))
end

function clamp(minval::Real, maxval::Real, sig::Stereo{L,R}) where {L <: Signal, R <: Signal}
    stereo(clamp(minval, maxval, sig.left), clamp(minval, maxval, sig.right))
end

