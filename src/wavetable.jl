struct Wavetable{Amp<:Signal,Ph<:Signal} <: Signal
    table::Vector{Float32}
    N::Int
    amp::Amp
    phase::Ph
end

done(s::Wavetable, t, dt) = done(s.amp, t, dt) || done(s.phase, t, dt)

function value(s::Wavetable, t, dt)
    @fastmath p = mod(value(s.phase, t, dt), 1.0f0)
    pos = 1 + p * s.N
    i = floor(Int, pos)
    frac = pos - i
    # We don't need to wrap around the i since length(s.table) == N + 4.
    interp4(frac, s.table[i], s.table[i+1], s.table[i+2], s.table[i+3])
end

"""
    fundamental(::Wavetable, samplingrate::Real = 48000) :: Float32

Gives the fundamental frequency if the wavetable is looped at the given sampling
rate without any stretching ... which defaults to 48KHz.
"""
fundamental(w::Wavetable, samplingrate::Real = 48000) = Float32(samplingrate / w.N)

"""
    wavetable(table :: AbstractVector{Float32}, amp :: Signal, phase :: Signal)
    wavetable(s :: Sample, amp :: Signal, phase :: Signal)
    wavetable(s :: Sample, amp :: Signal, freq :: Real)
    wavetable(s :: Sample, amp :: Real, freq :: Real)

A simple wavetable synth that samples the given table using the given phasor
and scales the table by the given amplitude modulator. A copy of the given
table is stored. If you already have a [`Synth.Sample`](@ref), you can use its
samples by passing it in directly. The sample's loop settings are not used
in this case.

The wavetable is a simple array of samples, often in the same sampling rate as
the output audio end point, but not necessarily so. The `phase` signal, which
can be generated using [`phasor`](@ref "Synth.phasor"), has values in the range ``[0,1]`` with
``0`` mapping to the start of the wave table and ``1`` to the end. To be
precise, if the wave table has ``N`` samples, then the phase values in the
range ``[0,1/N)`` will map to the first sample at index ``1`` and the sample at
index ``k`` will be chosen by phase value in the range ``[(k-1)/N, k/N)``.

The wavetable processor does 4-point interpolation. This means you can take a
small sample table and stretch it out using the interpolation by using a slowly
varying phasor. This is how the "pitch" of the sample gets changed during
synthesis.

The amplitude modulation is just as with [`oscil`](@ref "Synth.oscil").

The samples wave table is deemed to be completed when the phasor signal or the
amplitude modulator signal are completed.

!!! note "Envelopes"
    It is common for the output of such a wavetable "voice" to be modulated
    using an envelope like [`adsr`](@ref "Synth.adsr"). You can therefore pass such an ADSR
    signal as the `amp` argument. If the phase signal is infinite in extent, then
    the lifetime of the wavetable voice will become determined by the lifetime
    of the ADRS envelope.

!!! note "Attack and release"
    A complete voice implementation using a wavetable synth will need some
    extra niceties like a leading fragment of sound used during the "attack"
    phase of the voice until the voice begins to systain, and perhaps switching
    to a different voice during the release phase with a bit of cross fade.
    The current implementation provides a primitive that can be composed with
    other units in order to make such a more complete voice. The complexity
    of computing this voice will then be a bit more than the basic wavetable
    voice, but not much more than if you'd hand coded it yourself, thanks to
    Julia.

!!! note "Sustain loop"
    The phasor determines the section of the wavetable that is looped. To loop
    without a glitch (which can result in many undesirable harmonics), the
    value and slope at the start and end of the looping section will usually
    have to be matched. For some kinds of samples, this can be accomplished by
    putting the wavtable output through an appropriate low pass filter (using
    [`lpf`](@ref "Synth.lpf")), but it is even better to do the alignment *and* filter the
    result.
"""
function wavetable(table::AbstractVector{Float32}, amp::Signal, phase::Signal)
    N = length(table)
    @assert N >= 4
    table2 = zeros(Float32, N+4)
    table2[1:N] .= table
    table2[(N+1):end] = table[1:4]
    Wavetable(table2, N, amp, phase)
end

function wavetable(s::Sample, amp::Signal, phase::Signal)
    wavetable(s.samples, amp, phase)
end

function wavetable(s::Sample, amp::Signal, freq::Real)
    wavetable(s.samples, amp, phasor(freq))
end

function wavetable(s::Sample, amp::Real, freq::Real)
    wavetable(s.samples, konst(amp), phasor(freq))
end

const named_wavetables = Dict{Symbol,Vector{Float32}}()

"""
    wavetable(name :: Symbol, amp, freq)

Uses the named table. See [`Synth.register`](@ref).
"""
function wavetable(name::Symbol, amp, freq)
    wavetable(named_wavetables[name], amp, freq)
end

"""
    register(name :: Symbol, wt :: Vector{Float32})
    register(name :: Symbol, wt :: Wavetable)

Associates the given wave table with the given name so it can
be retrieved using `wavetable(::String)`.
"""
function register(name::Symbol, wt::Vector{Float32})
    named_wavetables[name] = wt
end

function register(name::Symbol, wt::Wavetable)
    named_wavetables[name] = wt.table[1:wt.N]
end
"""
    maketable(L :: Int, f)

Utility function to construct a table for use with `wavetable`.
`f` is passed values in the range [0.0,1.0] to construct the
table of the given length `L`.
"""
maketable(f, L::Int) = [f(Float32(i/L)) for i = 0:(L-1)]
