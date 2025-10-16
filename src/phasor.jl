mutable struct Phasor{F<:Signal} <: Signal
    freq::F
    phi::Float64
end

function value(s::Phasor{F}, t, dt) where {F<:Signal}
    val = s.phi
    s.phi += value(s.freq, t, dt) * dt
    return Float32(mod(val, 1.0f0))
end

function done(s::Phasor{F}, t, dt) where {F<:Signal}
    done(s.freq, t, dt)
end

"""
    phasor(f :: Real, phi0 = 0.0)
    phasor(f :: Signal, phi0 = 0.0)

A "phasor" is a signal that goes from 0.0 to 1.0 linearly and then
loops back to 0.0. This is useful in a number of contexts including
wavetable synthesis where the phasor can be used to lookup the
wavetable.
"""
phasor(f::Real, phi0::Float64 = 0.0) = Phasor(konst(f), phi0)
phasor(f::Signal, phi0::Float64 = 0.0) = Phasor(f, phi0)

"""
    saw(f :: Union{Real,Signal}, phi0::Float64 = 0.0)

A protected sawtooth wave (See [`protect`](@ref))
"""
saw(f, phi0::Float64 = 0.0) = protect(2.0f0 * phasor(f, phi0) - 1.0f0)

"""
    tri(f :: Union{Real,Signal}, phi0::Float64 = 0.0)

A protected triangular wave (See [`protect`](@ref))
"""
tri(f, phi0::Float64 = 0.0) = protect(map(x -> x > 1.0f0 ? 2.0f0 - x : x, 2.0f0 * phasor(f, phi0)))

"""
    sq(f :: Union{Real,Signal}, phi0::Float64 = 0.0)

A protected square wave (See [`protect`](@ref)).
This is perhaps the harshest of them with a small possibility
of aliasing, so the q factor for this is twice the usual.
"""
sq(f, phi0::Float64 = 0.0; threshold :: Float32=0.5f0) = 
    protect(map(x -> x > threshold ? 1.0f0 : -1.0f0, phasor(f, phi0)); q = 20.0f0)


