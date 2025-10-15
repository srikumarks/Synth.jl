struct Seq{GA<:Gen, GB<:Gen} <: Gen
    ga :: GA
    gb :: GB
end

"""
    seq(ga :: GA, gb :: GB) :: Gen where {GA <: Gen, GB <: Gen} 

Sequences the given two gens to occur one after the other.
When the first gen `ga` results in a `Cont`, it will switch
to `gb` and after that will continue onwards.
"""
function seq(ga :: GA, gb :: GB) where {GA <: Gen, GB <: Gen}
    Seq(ga, gb)
end

function proc(g :: Seq, s :: Bus, t)
    (t2, g2) = proc(g.ga, s, t)
    if iscont(g2)
        (t2, g.gb)
    elseif isstop(g2)
        (Inf, g2)
    else
        (t2, seq(g2, g.gb))
    end
end

struct Track{VT <: AbstractVector} <: Gen
    gens :: VT
    i :: Int
    g :: Gen
end

"""
    track(gs :: AbstractVector) :: Gen

A "track" is a heterogeneous sequence of Gens. When each gen finishes,
its `proc` call will produce a `Cont` which indicates it is
time to switch to the next Gen in the track. This is like a generalization
of `seq` except that `seq` has types known at construction time.
"""
function track(gs :: AbstractVector)
    Track(gs, 1, gs[1])
end

function proc(g :: Track, s :: Bus, t)
    (t2,g2) = proc(g.g, s, t)
    if iscont(g2)
        if g.i < length(g.gens)
            return (t2, Track(g.gens, g.i+1, g.gens[g.i+1]))
        else
            return (t2, g2)
        end
    else
        return (t2, Track(g.gens, g.i, g2))
    end
end

struct Durn{G <: Gen} <: Gen
    dur :: Float64
    gen :: G
end

"""
    durn(d :: Real, gen :: Gen) :: Gen

Forces the duration of the given `gen` to be the given `d`,
even if it was something else. Possibly useful with [`chord`](@ref).
"""
function durn(d :: Real, gen :: Gen)
    return Durn(Float64(d), gen)
end

function proc(g :: Durn{G}, s :: Bus, t) where {G <: Gen}
    (t2, g2) = proc(g.gen, s, t)
    (t + g.dur, Dur(g.dur, g2))
end

struct Chord{V <: AbstractVector} <: Gen
    gens :: V
end

"""
    chord(gens :: AbstractVector) :: Gen

A `Gen` which runs all the given heterogeneous `gens` in lock step. The
duration of the chord is given by the maximum of the durations of all the gens
every time they run. Whenever a gen produces a `Cont` or `Stop`, it is taken
out of the set of gens and the other continue on.
"""
function chord(gens :: AbstractVector) 
    Chord(gens)
end

function proc(g :: Chord, s :: Bus, t)
    gens = []
    tmax = t
    conts = 0
    for gi in g.gens
        (t2,g2) = proc(gi, s, t)
        tmax = max(tmax, t2)
        if iscont(g2)
            conts += 1
        elseif !isstop(g2)
            push!(gens, g2)
        end
    end
    if length(gens) == 0
        if conts > 0
            (tmax, Cont())
        else
            (Inf, Stop())
        end
    else
        (tmax, Chord(gens))
    end
end

struct Loop{G <: Gen} <: Gen
    n :: Int
    gen :: G
end

"""
    loop(n :: Int, g :: Gen) :: Gen

Will loop the given gen `n` times before ending.
"""
function loop(n :: Int, g :: G) where {G <: Gen}
    n <= 0 ? Cont() : Loop(n, g)
end

function proc(g :: Loop{G}, s :: Bus, t) where {G <: Gen}
    if g.n <= 0
        return (t, Cont())
    end

    (t2,g2) = proc(g.gen, s, t)
    (t2, seq(g2, loop(g.n-1, g.gen)))
end

struct Pause <: Gen
    dur :: Float64
end

"""
    pause(dur :: Real) :: Gen

Schedules no signals but just waits for the given duration
before proceeding.
"""
function pause(dur :: Real)
    Pause(Float64(dur))
end

function proc(g :: Pause, s :: Bus, t)
    (t + g.dur, Cont())
end

struct Dyn <: Gen
    fn :: Function
    i :: Int
    n :: Int
end

"""
    dyn(fn :: Function, i :: Int, n :: Int) :: Gen

A "dyn" gen calls the function with each i to determine the gen
that should be performed. The function will be called with
two arguments `i` and `n` where `i` will range from 1 to `n`.
"""
function dyn(fn :: Function, i :: Int, n :: Int)
    Dyn(fn, i, n)
end

function proc(g :: Dyn, s :: Bus, t)
    g2 = g.fn(g.i, g.n)
    if iscont(g2)
        # Returning Cont will abort the sequence
        # and move on to anything that follows.
        if g.i < g.n
            (t, dyn(fn, g.i+1, g.n))
        else
            (t, g2)
        end
    elseif isstop(g2)
        (Inf, g2)
    else
        (t3,g3) = proc(g2, s, t)
        (t3, g.i < g.n ? seq(g3, dyn(fn, g.i+1, g.n)) : g3)
    end
end

struct Ping <: Gen
    pitch :: Float32
    vel :: Float32
    decay :: Float32
    dur :: Float64
end

struct PitchChord{R <: Real, T <: AbstractVector{R}}
    pitches :: T
end

"""
    ch(pitches :: AbstractVector{R}) :: PitchChord where {R <: Real}

Represents a set of chorded pitch values. Usable with [`ping`](@ref).
"""
function ch(pitches :: AbstractVector{R}) where {R <: Real}
    PitchChord(pitches)
end

"""
    ping(pitch :: Real, dur :: Real, vel :: Real = 0.5f0, decay :: Real = dur) :: Gen
    ping(pitch :: AbstractVector{R}, dur :: Real, vel :: Real = 0.5f0, decay :: Real = dur) :: Gen where {R <: Real}
    ping(pitch :: AbstractVector{R}, dur :: AbstractVector{RD}, vel :: Real = 0.5f0, decay :: Real = dur) :: Gen where {R <: Real, RD <: Real}
    ping(pch :: PitchChord, dur :: Real, vel :: Real = 0.5f0, decay :: Real = dur) :: Gen

A "ping" is a simple decaying sine tone for illustrating how to create a `Gen`.
If you use the array versions, they're made into corresponding tracks for ease of use.
So `ping([60,67,72], 0.5)` would be a three-note track. If the duration is also an array,
it will be cycled through for each of the pitch values. So the number of pings is
determined only by the number of pitches given.
"""
function ping(pitch :: Real, dur :: Real, vel :: Real = 0.5f0, decay :: Real = dur)
    Ping(Float32(pitch), Float32(vel), Float32(decay), Float64(dur))
end

function ping(pitch :: AbstractVector{R}, dur :: Real, vel :: Real = 0.5f0, decay :: Real = dur) where {R <: Real}
    track([ping(p,dur,vel,decay) for p in pitch])
end

function ping(pitch :: AbstractVector{R}, dur :: AbstractVector{RD}, vel :: Real = 0.5f0, decay :: Real = minimum(dur)) where {R <: Real, RD <: Real}
    track([ping(pitch[i],dur[mod1(i,length(dur))],vel,decay) for i in eachindex(pitch)])
end

function ping(pch :: PitchChord, dur :: Real, vel :: Real = 0.5f0, decay :: Real = dur)
    chord([ping(p,dur,vel,decay) for p in pch.pitches])
end

function proc(g :: Ping, s :: Bus, t)
    amp = adsr(g.vel, 0.0;
               release_secs=g.dur,
               release_factor=1.1,
               attack_secs=0.1,
               decay_secs=0.1)
    sched(s, t, sinosc(amp, midi2hz(g.pitch)))
    return (t + g.dur, Cont())
end



