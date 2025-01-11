
"""
    abstract type BeatGen end

Make a subtype of this type and define the [`genbeat`](@ref) method on it to
use your own custom beat generation algorithm via [`beats`](@ref).
"""
abstract type BeatGen end

"""
    genbeat(bg :: BeatGen,
            phase :: AbstractFloat,
            count :: Integer,
            trigger :: Bool,
            dphase :: AbstractFloat,
            dt :: AbstractFloat) :: Union{Val{:end},Nothing,Signal}

Abstract method to be implemented for `BeatGen` types for use
with [`beats`](@ref).

- `phase` is (usually) a number in the range [0.0,1.0] that indicates
  the phase within a beat.
- `count` is the current beat count starting at 0 for the first beat.
- `trigger` is `true` for the first call of every beat interval.
- `dphase` is the change in phase from previous value. The difference in phase
  values between this call and the previous.
- `dt` is the usual sampling interval.

This method is called for every sample, letting you add signals
during any point within a beat cycle. The return value is expected
`nothing` to indicate nothing to do but continue, `Val(:end)` to
indicate the end of the sequence after which no `genbeat` call will
be made, or a `Signal` to start playing at the time.
"""
function genbeat(
        bg :: BeatGen,
        phase :: AbstractFloat,
        count :: Integer,
        trigger :: Bool,
        dphase :: AbstractFloat,
        dt :: AbstractFloat) :: Tuple{Bool,Union{Nothing,Signal}}
    error("Unimplemented genbeat for $(typeof(bg))")
end

mutable struct Beats{T <: Signal, BG <: BeatGen} <: Signal
    tempo :: T
    gen :: BG
    phase :: Float64
    count :: Int
    voices :: Vector{Tuple{Float64,Signal}}
    ended :: Bool
end

function trimvoices!(v::AbstractVector{Tuple{Float64,Signal}}, t, dt)
    filter!(v) do (vt,v)
        !done(v, t-vt, dt)
    end
end

function done(s :: Beats{P}, t, dt) where {P <: Signal} 
    done(s.tempo, t, dt) || (s.ended && all(done(v,t-vt,dt) for (vt,v) in s.voices))
end

function value(s :: Beats{P}, t, dt) where {P <: Signal}
    dp = value(s.tempo, t, dt) * dt
    p = s.phase + dp
    pm = mod(p, 1.0)
    count = s.count
    if pm - p < -0.5
        s.count += 1
        trimvoices!(s.voices, t, dt)
    end
    s.phase = pm
 
    if !s.ended
        # If the generation has ended, don't do any
        # further generation calculations and only
        # continue the pending voices till they finish.
        voice = genbeat(s.gen, pm, s.count, s.count > count, dp, dt)
        if voice == Val(:end)
            s.ended = true
        elseif !isnothing(voice)
            # At this point, `voice` is guaranteed to be a Signal
            push!(s.voices, (t, voice::Signal))
        end
    end

    # Play out the voices
    val = 0.0f0
    for (vt,v) in s.voices
        val += value(v, t-vt, dt)
    end
    return val
end
    
"""
    beats(tempo :: T, gen :: BG; phase = 1.0f0, count = -1) :: Beats{T, BG} where {T <: Signal, BG <: BeatGen}

Generates beats using [`genbeat`](@ref) starting with the given phase.
The default values are such that the very first sample produced is considered
to be the start of a beat. If you need to start it a little later, supply a
corresponding value of phase that's < 1.0.
"""
function beats(tempo :: T, gen :: BG; phase=1.0, count=-1) :: Beats{T, BG} where {T <: Signal, BG <: BeatGen}
    Beats(tempo, gen, phase, count, Vector{Tuple{Float64,Signal}}(), false)
end
function beats(tempo :: Real, gen :: BG; phase=1.0, count=-1) :: Beats{Konst, BG} where {BG <: BeatGen}
    beats(konst(tempo), gen; phase, count)
end
