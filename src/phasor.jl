mutable struct Phasor{F <: Signal} <: Signal
    freq :: F
    phi :: Float64
end

function value(s :: Phasor{F}, t, dt) where {F <: Signal}
    val = s.phi
    s.phi += value(s.freq, t, dt) * dt
    return Float32(mod(val,1.0f0))
end

function done(s :: Phasor{F}, t, dt) where {F <: Signal}
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
phasor(f :: Real, phi0 :: Float64 = 0.0) = Phasor(konst(f), phi0)
phasor(f :: Signal, phi0 :: Float64 = 0.0) = Phasor(f, phi0)


