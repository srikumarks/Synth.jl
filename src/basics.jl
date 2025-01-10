
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

mutable struct Aliasable{S <: Signal} <: Signal
    sig :: S
    t :: Float64
    v :: Float32
end


"""
    aliasable(s :: S) where {S <: Signal}

A signal, once constructed, can only be used by one "consumer" via function
composition. In some situations, we want a signal to be plugged into multiple
consumers (to make a signal flow DAG). For these occasions, make the signal
aliasable by calling `aliasable` on it and use the alisable signal everywhere
you need it instead. 

!!! note "Constraint"
    It only makes sense to make a single aliasable version of a signal.
    Repeated evaluation of a signal is avoided by `Aliasable` by storing the
    recently computed value for a given time. So it assumes that time
    progresses linearly.

!!! note "Terminology"
    The word "alias" has two meanings - one in the context of signals where
    frequency shifting it can cause wrap around effects in the spectrum due
    to sampling, and in the context of a programming language where a value
    referenced in multiple data structures is said to be "aliased". It is in
    the latter sense that we use the word `aliasable` in this case. 
"""
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

Rescales the samples so that the maximum extent fits within the given `maxamp`
(which must be positive). The renderer automatically rescales to avoid
clamping.
"""
function rescale(maxamp, samples)
    @assert maxamp > 0.0 "The maximum allowed amplitude must be a positive number."
    sadj = samples .- (sum(samples) / length(samples))
    amp = maximum(abs.(samples))
    if amp < 1e-5
        return zeros(Float32, length(samples))
    else
        return Float32.(sadj .* (maxamp / amp))
    end
end

"""
    nchannels(sig :: S) :: Int where {S <: Signal}

Returns the number of output channels of the signal. By default,
all signals are mono-channel only. This protocol exists to help support
multiple channels as a vector of signals.
"""
function nchannels(sig :: S) :: Int where {S <: Signal}
    1
end

struct Stereo{L <: Signal, R <: Signal}
    left :: L
    right :: R
end

done(s :: Stereo, t, dt) = done(s.left, t, dt) && done(s.right, t, dt)
value(s :: Stereo, t, dt) = SA_F32[value(s.left, t, dt), value(s.right, t, dt)]

nchannels(::Stereo) = 2
    
"""
    stereo(left :: L, right :: R) :: Stereo{L,R} where {L <: Signal, R <: Signal}
    stereo(lr :: Aliasable{S}) :: Stereo{Aliasable{S},Aliasable{S}} where {S <: Signal}
    stereo(lr :: S) :: Stereo{Aliasable{S}, Aliasable{S}} where {S <: Signal}

Constructs a "stereo signal" from two mono signals. A "stereo signal" has basically
the same protocol as a mono signal, except that the `value` method returns 
a 2-element static vector - i.e. `SVector{2,Float32}` type value.
"""
function stereo(left :: L, right :: R) where {L <: Signal, R <: Signal}
    Stereo(left, right)
end

function stereo(lr :: Aliasable{S}) where {S <: Signal}
    Stereo(lr,lr)
end

function stereo(lr :: S) where {S <: Signal}
    stereo(aliasable(lr))
end

function pan(sig :: Aliasable{S}, lr :: Real) where {S <: Signal}
    lr = max(-1, min(1, lr))
    lvol = 1.0 - 0.5 * (lr + 1)
    rvol = 1.0 - lvol
    stereo(lvol * sig, rvol * sig)
end

function pan(sig :: Aliasable{S}, lr :: P) where {S <: Signal, P <: Signal}
    lvol = aliasable(1.0 - 0.5 * (lr + 1))
    rvol = 1.0f0 - lvol
    stereo(lvol * sig, rvol * sig)
end
