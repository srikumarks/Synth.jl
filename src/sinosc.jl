mutable struct SinOsc{Mod<:Signal,Freq<:Signal} <: Signal
    modulator::Mod
    freq::Freq
    phase::Float32
end

function done(s::SinOsc, t, dt)
    done(s.modulator, t, dt) || done(s.freq, t, dt)
end

function value(osc::SinOsc, t, dt)
    m = value(osc.modulator, t, dt)
    f = value(osc.freq, t, dt)
    @fastmath v = sin(2π * osc.phase)
    @fastmath osc.phase = mod(osc.phase + f * dt, 1.0f0)

    m * v
end

"""
    sinosc(m :: Union{Real,Signal}, f :: Union{Real,Signal}; phase = 0.0)

A "sinosc" is a sinusoidal oscillator whose frequency and amplitude can be
varied ("modulated") over time. The `f` argument is expected to be a frequency
in Hz units. `m` determines the amplitude and `f` the frequency in Hz.
The `phase` named argument is a number in the range `[0.0,1.0]` determining
the starting phase within the cycle.

!!! note "Design"
    An earlier approach was to have the second argument be a phasor. However,
    the phasor argument always ended up being passed as `phasor(freq)` and so
    it made sense to fold the frequency into `sinosc` as the main control. 
    This made for a simpler use of `sinosc`, though a tad less general.
    So essentially `sinosc(m, f)` is equivalent to `sinosc_v1(m, phasor(f))`
    where `sinosc_v1` was the previous version.
"""
sinosc(m::Real, f::Real; phase = 0.0) = SinOsc(konst(m), konst(f), Float32(2π*phase))
sinosc(m::Real, f::Signal; phase = 0.0) = SinOsc(konst(m), f, Float32(2π*phase))
sinosc(m::Signal, f::Real; phase = 0.0) = SinOsc(m, konst(f), Float32(2π*phase))
sinosc(m::Signal, f::Signal; phase = 0.0) = SinOsc(m, f, Float32(2π*phase))
