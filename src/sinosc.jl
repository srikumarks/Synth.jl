mutable struct SinOsc{Mod <: Signal, Freq <: Signal} <: Signal
    modulator :: Mod
    freq :: Freq
    phase :: Float32
end

function done(s :: SinOsc, t, dt)
    done(s.modulator, t, dt) || done(s.freq, t, dt)
end

function value(osc :: SinOsc, t, dt)
    m = value(osc.modulator, t, dt)
    f = value(osc.freq, t, dt)
    @fastmath v = sin(2π * osc.phase)
    @fastmath osc.phase = mod(osc.phase + f * dt, 1.0f0)

    m * v
end

"""
    sinosc(m :: Real, f :: Real; phase = 0.0)
    sinosc(m :: Real, f :: Signal; phase = 0.0)
    sinosc(m :: Signal, f :: Real; phase = 0.0)
    sinosc(m :: Signal, f :: Signal; phase = 0.0)

A "sinosc" is a sinusoidal oscillator whose frequency and amplitude can be
varied ("modulated") over time. The `f` argument is expected to be a frequency
in Hz units. `m` determines the amplitude and `f` the frequency in Hz.
"""
sinosc(m :: Real, f :: Real; phase = 0.0) = SinOsc(konst(m), konst(f), Float32(2π*phase))
sinosc(m :: Real, f :: Signal; phase = 0.0) = SinOsc(konst(m), f, Float32(2π*phase))
sinosc(m :: Signal, f :: Real; phase = 0.0) = SinOsc(m, konst(f), Float32(2π*phase))
sinosc(m :: Signal, f :: Signal; phase = 0.0) = SinOsc(m, f, Float32(2π*phase))


