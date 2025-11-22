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
oscil(m::Real, f::Real, p::Real = 0.0; phase::Real = 0.0) = oscil(konst(m), konst(f), konst(p); phase)
oscil(m::Real, f::Real, p::Signal; phase::Real = 0.0) = oscil(konst(m), konst(f), p; phase)
oscil(m::Real, f::Signal, p::Real = 0.0; phase::Real = 0.0) = oscil(konst(m), f, konst(p); phase)
oscil(m::Real, f::Signal, p::Signal; phase::Real = 0.0) = oscil(konst(m), f, p; phase)
oscil(m::Signal, f::Real, p::Real = 0.0; phase::Real = 0.0) = oscil(m, konst(f), konst(p); phase)
oscil(m::Signal, f::Real, p::Signal; phase::Real = 0.0) = oscil(m, konst(f), p; phase)
oscil(m::Signal, f::Signal, p::Real = 0.0; phase::Real = 0.0) = oscil(m, f, konst(p); phase)

mutable struct Rotor{Freq<:Signal} <: SignalWithFanout
    freq::Freq
    cos::Float32
    sin::Float32
    cdϕ::Float32
    sdϕ::Float32
    t::Float64
end

done(s::Rotor, t, dt) = done(s.freq, t, dt)

function value(s::Rotor{Konst}, t, dt)
    if t > s.t
        c = s.cos * s.cdϕ - s.sin * s.sdϕ
        s = s.cos * s.sdϕ + s.sin * s.cdϕ
        @fastmath r = 1.0f0 / sqrt(c*c+s*s)
        s.cos = c*r
        s.sin = s*r
        s.t = t
    end
    s.cos
end

function value(s::Rotor, t, dt)
    if t > s.t
        dϕ = 2 * pi * value(s.freq, t, dt) * dt
        dϕ2 = dϕ * dϕ
        dϕ3 = dϕ2 * dϕ
        dϕ4 = dϕ2 * dϕ2

        cdϕ = 1-dϕ2/2+dϕ4/24
        sdϕ = dϕ-dϕ3/6
        c = s.cos * cdϕ - s.sin * sdϕ
        s = s.cos * sdϕ + s.sin * cdϕ
        @fastmath r = 1.0f0/sqrt(c*c+s*s)
        s.cos = c*r
        s.sin = s*r
        s.cdϕ = cdϕ
        s.sdϕ = sdϕ
        s.t = t
    end
    s.cos
end

struct RotorQ{S <: Signal} <: Signal
    rotor::Rotor{S}
end

done(r::RotorQ, t, dt) = done(r.rotor, t, dt)
value(r::RotorQ, t, dt) = begin
    value(r.rotor, t, dt)
    r.rotor.sin
end

"""
    rotor(f::Freq; phase::Real=0.0f0) where {Freq <: Signal}
    rotor(f::Konst; phase::Real=0.0f0, samplingrate::Real=48000)
    rotor(f::Real; phase::Real=0.0f0, samplingrate::Real=48000)
    rotorq(r::Rotor)
    rotorq(r::RotorQ)
    rotorq(f::Freq; phase::Real=0.0f0)
    rotorq(f::Konst; phase::Real=0.0f0, samplingrate::Real=48000)
    rotorq(f::Real; phase::Real=0.0f0, samplingrate::Real=48000)

A "rotor" oscillates by rotating a complex phase using a controllable
frequency (expressed in Hz). It does this in a numerically stable way
by continuously normalizing the complex phase without having to invoke
cos and sin in the constant frequency case.

The rotor is included as an example of constructing such oscillators
without running into the phase explosion issue. The current [`oscil`](@ref)
implementation is already stable on that front and is more flexible.

The `rotorq` variants construct a rotor that is phase shifted by
90 degrees.
"""
function rotor(f::Freq; phase::Real=0.0f0) where {Freq <: Signal}
    Rotor{Freq}(f, cos(phase), sin(phase), 1.0f0, 0.0f0) 
end

function rotor(f::Konst; phase::Real=0.0f0, samplingrate::Real=48000)
    dphi = 2 * pi * value(f, 0.0, 1/samplingrate) / samplingrate * 
    @assert dphi < 0.3
    Rotor{Konst}(f, cos(phase), sin(phase), 1.0f0, 0.0f0, cos(dphi), sin(dphi))
end

rotor(f::Real; phase::Real=0.0f0, samplingrate::Real=48000) = rotor(konst(f); phase, samplingrate)

rotorq(r::Rotor) = RotorQ(r)
rotorq(r::RotorQ) = 0.0f0 - r.rotor
rotorq(f::Freq; phase::Real=0.0f0) where {Freq <: Signal} = RotorQ(rotor(f;phase))
rotorq(f::Konst; phase::Real=0.0f0, samplingrate::Real=48000) = RotorQ(rotor(f;phase,samplingrate))
rotorq(f::Real; phase::Real=0.0f0, samplingrate::Real=48000) = RotorQ(rotor(f;phase,samplingrate))



