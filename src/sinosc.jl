mutable struct SinOsc{Mod<:Signal,Freq<:Signal,Phase<:Signal} <: Signal
    modulator::Mod
    freq::Freq
    phase::Phase
    ϕ::Float32
end

function done(s::SinOsc, t, dt)
    done(s.modulator, t, dt) || (done(s.freq, t, dt) && done(s.phase, t, dt))
end

function value(osc::SinOsc, t, dt)
    m = value(osc.modulator, t, dt)
    f = value(osc.freq, t, dt)
    p = value(osc.phase, t, dt)
    @fastmath v = sin(2π * osc.ϕ)
    @fastmath osc.ϕ = mod(osc.ϕ + f * dt + p, 1.0f0)
    m * v
end

"""
    sinosc(m :: Union{Real,Signal}, f :: Union{Real,Signal}, p :: Union{Real,Signal}; phase = 0.0)

A "sinosc" is a sinusoidal oscillator whose frequency and amplitude can be
varied ("modulated") over time. The `f` argument is expected to be a frequency
in Hz units. `m` determines the amplitude and `f` the frequency in Hz. The
`phase` named argument is a number in the range `[0.0,1.0]` determining the
starting phase within the cycle.

Both a frequency and phase are supported as signals and the keyword argument
`phase` is the initial phase offset. This lets us do both FM and PM using the
same unit. The frequency is in Hz and the `p` phase signal is expected to be
in the unit range as well, but is not limited to that.

!!! note "Design"
    An earlier approach was to have the second argument be a phasor. However,
    the phasor argument always ended up being passed as `phasor(freq)` and so
    it made sense to fold the frequency into `sinosc` as the main control. 
    This made for a simpler use of `sinosc`, though a tad less general.
    So essentially `sinosc(m, f)` is equivalent to `sinosc_v1(m, phasor(f))`
    where `sinosc_v1` was the previous version.
"""
sinosc(m::Signal, f::Signal, p::Signal; phase::Real = 0.0) = SinOsc(m, f, p, Float32(phase))
sinosc(m::Real, f::Real, p::Real = 0.0; phase::Real = 0.0) = sinosc(konst(m), konst(f), konst(p); phase)
sinosc(m::Real, f::Real, p::Signal; phase::Real = 0.0) = sinosc(konst(m), konst(f), p; phase)
sinosc(m::Real, f::Signal, p::Real = 0.0; phase::Real = 0.0) = sinosc(konst(m), f, konst(p); phase)
sinosc(m::Real, f::Signal, p::Signal; phase::Real = 0.0) = sinosc(konst(m), f, p; phase)
sinosc(m::Signal, f::Real, p::Real = 0.0; phase::Real = 0.0) = sinosc(m, konst(f), konst(p); phase)
sinosc(m::Signal, f::Real, p::Signal; phase::Real = 0.0) = sinosc(m, konst(f), p; phase)
sinosc(m::Signal, f::Signal, p::Real = 0.0; phase::Real = 0.0) = sinosc(m, f, konst(p); phase)
