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
    dϕ = 2 * π * f * dt
    s, c = osc.s, osc.c
    s1 = s + dϕ * (c - (1/2) * dϕ * (s + (1/3) * dϕ * (c - (1/4) * dϕ * s)))
    c1 = c - dϕ * (s + (1/2) * dϕ * (c - (1/3) * dϕ * (s + (1/4) * dϕ * c)))
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


