mutable struct SinOsc{Mod <: Signal, Freq <: Signal} <: Signal
    modulator :: Mod
    freq :: Freq
    s :: Float32 # The sine component of the phase vector
    c :: Float32 # The cosine component of the phase vector
end

function done(s :: SinOsc, t, dt)
    done(s.modulator, t, dt) || done(s.freq, t, dt)
end

function value(osc :: SinOsc, t, dt)
    m = value(osc.modulator, t, dt)
    f = value(osc.freq, t, dt)

    # The next step of the phase vector is computed using the
    # Taylor expansion of sin and cos and therefore uses only
    # multiplication and addition/subtraction operators at the
    # level of precision required for audio synthesis. This
    # expansion should be adequate to frequencies of about 2KHz.
    # The way the code below is structured is based on -
    # sin(θ+dϕ) = sin(θ)cos(dϕ) + cos(θ)sin(dϕ)
    # cos(θ+dϕ) = cos(θ)cos(dϕ) - sin(θ)sin(dϕ)
    # and then expanding cos(dϕ) and sin(dϕ) using Taylor series.
    dϕ = 2 * π * f * dt
    s, c = osc.s, osc.c
    dϕ² = dϕ * dϕ
    dϕ⁴ = dϕ² * dϕ²
    cosdϕ = 1 - (1/2)dϕ² + (1/24)dϕ⁴
    sindϕ = dϕ * (1 - (1/6)dϕ² + (1/120)dϕ⁴)
    s1 = cosdϕ * s + sindϕ * c
    c1 = cosdϕ * c - sindϕ * s
    osc.s, osc.c = s1, c1

    m * s1
end

"""
    sinosc(m :: Real, f :: Real; phase = 0.0)
    sinosc(m :: Real, f :: Signal; phase = 0.0)
    sinosc(m :: Signal, f :: Real; phase = 0.0)
    sinosc(m :: Signal, f :: Signal; phase = 0.0)

A "sinosc" is a sinusoidal oscillator that can be controlled using a phasor or
a clock to determine a time varying frequency. The `f` argument is expected to
be a frequency in Hz units. Both the frequency and the amplitude are modulatable.
"""
sinosc(m :: Real, f :: Real; phase = 0.0) = SinOsc(konst(m), konst(f), Float32(sin(phase)), Float32(cos(phase)))
sinosc(m :: Real, f :: Signal; phase = 0.0) = SinOsc(konst(m), f, Float32(sin(phase)), Float32(cos(phase)))
sinosc(m :: Signal, f :: Real; phase = 0.0) = SinOsc(m, konst(f), Float32(sin(phase)), Float32(cos(phase)))
sinosc(m :: Signal, f :: Signal; phase = 0.0) = SinOsc(m, f, Float32(sin(phase)), Float32(cos(phase)))


