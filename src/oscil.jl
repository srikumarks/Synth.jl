mutable struct Oscil{Mod<:Signal,Freq<:Signal,Phase<:Signal} <: Signal
    modulator::Mod
    freq::Freq
    phase::Phase
    ϕ::Float32
end

function done(s::Oscil, t, dt)
    done(s.modulator, t, dt) || (done(s.freq, t, dt) && done(s.phase, t, dt))
end

function value(osc::Oscil, t, dt)
    m = value(osc.modulator, t, dt)
    f = value(osc.freq, t, dt)
    p = value(osc.phase, t, dt)
    @fastmath v = sin(2π * osc.ϕ)
    @fastmath osc.ϕ = mod(osc.ϕ + f * dt + p, 1.0f0)
    m * v
end

"""
    oscil(m :: Union{Real,Signal}, f :: Union{Real,Signal}, p :: Union{Real,Signal}; phase = 0.0)

A "oscil" is a sinusoidal oscillator whose frequency and amplitude can be
varied ("modulated") over time. The `f` argument is expected to be a frequency
in Hz units. `m` determines the amplitude and `p` the phase in unit range. The
`phase` named argument is a number in the range `[0.0,1.0]` determining the
starting phase within the cycle. It is added to the overall phase evolution as
a constant so that `oscil` can be used for a sine wave with 0.0 as the `phase`
and as a cosine wave with 0.5 as the `phase`. This lets us do both FM and PM
using the same unit. 

!!! note "Design"
    An earlier approach was to have the second argument be a phasor. However,
    the phasor argument always ended up being passed as `phasor(freq)` and so
    it made sense to fold the frequency into `oscil` as the main control. 
    This made for a simpler use of `oscil`, though a tad less general.
    So essentially `oscil(m, f)` is equivalent to `oscil_v1(m, phasor(f))`
    where `oscil_v1` was the previous version.
"""
oscil(m::Signal, f::Signal, p::Signal; phase::Real = 0.0) = Oscil(m, f, p, Float32(phase))
oscil(m::Real, f::Real, p::Real = 0.0; phase::Real = 0.0) =
    oscil(konst(m), konst(f), konst(p); phase)
oscil(m::Real, f::Real, p::Signal; phase::Real = 0.0) = oscil(konst(m), konst(f), p; phase)
oscil(m::Real, f::Signal, p::Real = 0.0; phase::Real = 0.0) =
    oscil(konst(m), f, konst(p); phase)
oscil(m::Real, f::Signal, p::Signal; phase::Real = 0.0) = oscil(konst(m), f, p; phase)
oscil(m::Signal, f::Real, p::Real = 0.0; phase::Real = 0.0) =
    oscil(m, konst(f), konst(p); phase)
oscil(m::Signal, f::Real, p::Signal; phase::Real = 0.0) = oscil(m, konst(f), p; phase)
oscil(m::Signal, f::Signal, p::Real = 0.0; phase::Real = 0.0) = oscil(m, f, konst(p); phase)
