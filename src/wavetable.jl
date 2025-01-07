mutable struct Wavetable{Amp <: Signal, Ph <: Signal} <: Signal
    table :: Vector{Float32}
    N :: Int
    amp :: Amp
    phase :: Ph
end

done(s :: Wavetable, t, dt) = done(s.amp, t, dt) || done(s.phase, t, dt)

function value(s :: Wavetable, t, dt)
    p = value(s.phase, t, dt)
    pos = 1 + p * s.N
    i = floor(Int, pos)
    frac = pos - i
    interp4(frac, 
            s.table[mod1(i,s.N)],
            s.table[mod1(i+1,s.N)],
            s.table[mod1(i+2,s.N)],
            s.table[mod1(i+3,s.N)])
end

"""
    wavetable(table :: Vector{Float32}, amp :: Amp, phase :: Ph) where {Amp <: Signal, Ph <: Signal}

A simple wavetable synth that samples the given table using the given phasor
and scales the table by the given amplitude modulator.

The wavetable is a simple array of samples, often in the same sampling rate as
the output audio end point, but not necessarily so. The `phase` signal, which
can be generated using [`phasor`](@ref), has values in the range ``[0,1]`` with
``0`` mapping to the start of the wave table and ``1`` to the end. To be
precise, if the wave table has ``N`` samples, then the phase values in the
range ``[0,1/N)`` will map to the first sample at index ``1`` and the sample at
index ``k`` will be chosen by phase value in the range ``[(k-1)/N, k/N)``.

The wavetable processor does 4-point interpolation. This means you can take a
small sample table and stretch it out using the interpolation by using a slowly
varying phasor. This is how the "pitch" of the sample gets changed during
synthesis.

The amplitude modulation is just as with [`sinosc`](@ref).

The samples wave table is deemed to be completed when the phasor signal or the
amplitude modulator signal are completed.
"""
function wavetable(table :: Vector{Float32}, amp :: Amp, phase :: Ph) where {Amp <: Signal, Ph <: Signal}
    @assert length(table) >= 4
    Wavetable(table, length(table), amp, phase)
end

"""
    maketable(L :: Int, f)

Utility function to construct a table for use with `wavetable`.
`f` is passed values in the range [0.0,1.0] to construct the
table of the given length `L`.
"""
maketable(f, L :: Int) = [f(Float32(i/L)) for i in 0:(L-1)]


