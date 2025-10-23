
import DSP

mutable struct Konst <: Signal
    k::Float32
end

value(s::Konst, t, dt) = s.k
done(s::Konst, t, dt) = false

"""
    konst(v::Real)

Makes a constant valued signal. Useful with functions that accept
signals but we only want to use a constant value for it.
"""
function konst(v::Real)
    Konst(Float32(v))
end

"""
    rescale(maxamp :: Real, samples :: AbstractArray) :: Vector{Float32}

Rescales the samples so that the maximum extent fits within the given `maxamp`
(which must be positive). The renderer automatically rescales to avoid
clamping.
"""
function rescale(maxamp::Real, samples::AbstractArray)
    @assert maxamp > 0.0 "The maximum allowed amplitude must be a positive number."
    sadj = samples .- (sum(samples) / length(samples))
    amp = maximum(abs.(samples))
    if amp < 1e-5
        return zeros(Float32, length(samples))
    else
        return Float32.(sadj .* (maxamp / amp))
    end
end


struct Clamp{S<:Signal}
    sig::S
    minval::Float32
    maxval::Float32
end

done(s::Clamp{S}, t, dt) where {S<:Signal} = done(s.sig, t, dt)
value(s::Clamp{S}, t, dt) where {S<:Signal} =
    max(s.minval, min(s.maxval, value(s.sig, t, dt)))

"""
    clamp(sig::Signal, minval::Real, maxval::Real)
    clamp(sig::Stereo{L,R}, minval::Real, maxval::Real) where {L <: Signal, R <: Signal}

Clamps the given signal to the give minimum and maximum values. 
Supports stereo signals and clamps the individual channels.
"""
function Base.clamp(sig::Signal, minval::Real, maxval::Real)
    @assert minval <= maxval
    Clamp(sig, Float32(minval), Float32(maxval))
end

function Base.clamp(sig::Stereo{L,R}, minval::Real, maxval::Real) where {L<:Signal,R<:Signal}
    stereo(clamp(sig.left, minval, maxval), clamp(sig.right, minval, maxval))
end

"""
    convolve(s1::AbstractVector{Float32}, s2::AbstractVector{Float32})

Convolves two sample arrays to produce another of length N1+N2+1.
Note that convolving large arrays will be more expensive. Generally
expected it to be ``O(N \\log(N))``.
"""
function convolve(s1::AbstractVector{Float32}, s2::AbstractVector{Float32})
    DSP.conv(s1, s2)
end
