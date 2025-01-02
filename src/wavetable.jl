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


