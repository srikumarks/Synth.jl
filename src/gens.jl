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

function proc(g :: Seq, s :: AbstractBus, t)
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

function proc(g :: Track, s :: AbstractBus, t)
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

function proc(g :: Durn{G}, s :: AbstractBus, t) where {G <: Gen}
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

function proc(g :: Chord, s :: AbstractBus, t)
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

function proc(g :: Loop{G}, s :: AbstractBus, t) where {G <: Gen}
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

function proc(g :: Pause, s :: AbstractBus, t)
    (t + g.dur, Cont())
end

struct Dyn <: Gen
    fn :: Function
    n :: Int
    i :: Int
end

"""
    dyn(fn :: Function, n :: Int, i :: Int) :: Gen

A "dyn" gen calls the function with each i to determine the gen
that should be performed. The function will be called with
two arguments `i` and `n` where `i` will range from 1 to `n`.
"""
function dyn(fn :: Function, n :: Int, i :: Int)
    Dyn(fn, n, i)
end

function proc(g :: Dyn, s :: AbstractBus, t)
    g2 = g.fn(g.n, g.i)
    if iscont(g2)
        # Returning Cont will abort the sequence
        # and move on to anything that follows.
        if g.i < g.n
            (t, dyn(fn, g.n, g.i+1))
        else
            (t, g2)
        end
    elseif isstop(g2)
        (Inf, g2)
    else
        (t3,g3) = proc(g2, s, t)
        (t3, g.i < g.n ? seq(g3, dyn(fn, g.n, g.i+1)) : g3)
    end
end

struct Rec{C,S} <: Gen
    fn :: Function
    conf :: C # The conf part does not change from call to call.
    state :: S # The state may change from call to call.
end


"""
    rec(fn :: Function, c :: C, s :: S) :: Gen where {C,S}

Constructs a recursive process using the given function.
The function takes the current state and is expected to
return a tuple of a Gen and the next state. If the
returned gen is `Cont`, then the gen is considered
finished and will move on to the next gen in whatever
context it was invoked.

## Iterating an octave

For example, if you want a gen which iterates through the
pitches of an octave you can do it this way (though you
can accomplish it using track as well).

```
function octave(p :: Real, i :: Int)
    if i <= 12
        (tone(p + i, 0.25), i+1)
    else
        (Cont(), i+1)
    end
end
b = bus()
sched(b, rec(octave, 60, 0::Int))
play(b, 4.0)
```

`rec` is therefore a general mechanism to implement stateful
recursive time evolution at a level higher than signals.
Note that the function called by `rec` can itself return
another recursive process as a part of its evolution.
"""
function rec(fn :: Function, c :: C s :: S) where {C,S}
    Rec{C,S}(fn, c, s)
end

function proc(g :: Rec{S}, s :: AbstractBus, t) where {S}
    (g2, state2) = g.fn(g.conf, g.state)
    if iscont(g2)
        (t, g2)
    elseif isstop(g2)
        (Inf, g2)
    else
        (t3, g3) = proc(g2, s, t)
        (t3, seq(g3, rec(g.fn, g.conf, state2)))
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

function proc(g :: Ping, s :: AbstractBus, t)
    amp = adsr(g.vel, 0.0;
               release_secs=g.dur,
               release_factor=1.1,
               attack_secs=0.1,
               decay_secs=0.1)
    sched(s, t, sinosc(amp, midi2hz(g.pitch)))
    return (t + g.dur, Cont())
end

struct Tone <: Gen
    pitch :: Float32
    vel :: Float32
    dur :: Float64
    release_secs :: Float32
end


"""
    tone(pitch :: Real, dur :: Real, vel :: Real = 0.5f0; release_secs :: Real = 0.05) :: Gen
    tone(pitch :: AbstractVector{R}, dur :: Real, vel :: Real = 0.5f0; release_secs :: Real = 0.05) :: Gen where {R <: Real}
    tone(pitch :: AbstractVector{R}, dur :: AbstractVector{RD}, vel :: Real = 0.5f0; release_secs :: Real = 0.05) :: Gen where {R <: Real, RD <: Real}
    tone(pch :: PitchChord, dur :: Real, vel :: Real = 0.5f0, release_secs :: Real = 0.05) :: Gen

`tone` is related to [`ping`](@ref) in that it will sustain a tone for the given duration
as opposed to `ping` which will immediately start releasing the tone. In other
words, a `ping` is a `note` with zero duration. However, the note is configured
with a default short release time where the default release of a ping is determined
by its duration.

Note that you can force the duration of a gen to be whatever you want using [`durn`](@ref).
"""
function tone(pitch :: Real, dur :: Real, vel :: Real = 0.5f0; release_secs :: Real = 0.05)
    Tone(Float32(pitch), Float32(vel), Float64(dur), Float32(release_secs))
end

function tone(pitch :: AbstractVector{R}, dur :: Real, vel :: Real = 0.5f0; release_secs :: Real = 0.05) where {R <: Real}
    track([tone(p,dur,vel; release_secs) for p in pitch])
end

function tone(pitch :: AbstractVector{R}, dur :: AbstractVector{RD}, vel :: Real = 0.5f0; release_secs :: Real = 0.05) where {R <: Real, RD <: Real}
    track([tone(pitch[i],dur[mod1(i,length(dur))],vel;release_secs) for i in eachindex(pitch)])
end

function tone(pch :: PitchChord, dur :: Real, vel :: Real = 0.5f0, release_secs :: Real = 0.05)
    chord([tone(p,dur,vel;release_secs) for p in pch.pitches])
end

function proc(g :: Tone, s :: AbstractBus, t)
    amp = adsr(g.vel, g.dur;
               release_secs=g.release_secs,
               release_factor=1.0,
               attack_secs=0.05,
               attack_factor=1.0,
               decay_secs=0.05)
    sched(s, t, sinosc(amp, midi2hz(g.pitch)))
    return (t + g.dur, Cont())
end

struct WaveTone <: Gen
    wave_table :: Vector{Float32}
    pitch :: Float32
    vel :: Float32
    dur :: Float64
    release_secs :: Float32
end

function proc(g :: WaveTone, s :: AbstractBus, t)
    amp = adsr(g.vel, g.dur;
               release_secs=g.release_secs,
               release_factor=1.0,
               attack_secs=0.05,
               decay_secs=0.05)
    sched(s, t, wavetable(g.wave_table, amp, phasor(midi2hz(g.pitch))))
    return (t + g.dur, Cont())
end

"""
    tone(wt :: Vector{Float32}, pitch, dur, vel = 0.5f0; release_secs = 0.05) :: Gen
    tone(wt :: Wavetable, pitch, dur, vel = 0.5f0; release_secs = 0.05) :: Gen where {R <: Real}
    tone(wt :: Symbol, pitch, dur, vel = 0.5f0; release_secs = 0.05) :: Gen where {R <: Real, RD <: Real}
"""


function tone(wt :: Vector{Float32}, pitch :: Real, dur :: Real, vel :: Real = 0.5f0; release_secs :: Real = 0.05)
    WaveTone(wt, Float32(pitch), Float32(vel), Float32(dur))
end

function tone(wt :: Vector{Float32}, pitch :: AbstractVector{R}, dur :: Real, vel :: Real = 0.5f0; release_secs :: Real = 0.05) where {R <: Real}
    track([tone(wt, p,dur,vel; release_secs) for p in pitch])
end

function tone(wt :: Vector{Float32}, pitch :: AbstractVector{R}, dur :: AbstractVector{RD}, vel :: Real = 0.5f0; release_secs :: Real = 0.05) where {R <: Real, RD <: Real}
    track([tone(wt, pitch[i],dur[mod1(i,length(dur))],vel;release_secs) for i in eachindex(pitch)])
end

function tone(wt :: Vector{Float32}, pch :: PitchChord, dur :: Real, vel :: Real = 0.5f0, release_secs :: Real = 0.05)
    chord([tone(wt, p,dur,vel;release_secs) for p in pch.pitches])
end

function tone(wt :: Wavetable, pitch, dur, vel = 0.5f0; release_secs = 0.05)
    # We can't just pass wt.samples because the table stored inside Wavetable has 4 extra samples
    # stored at the end for interpolation purposes.
    tone(wt.samples[1:wt.N], pitch, dur, vel; release_secs)
end

function tone(wt :: Symbol, pitch, dur, vel = 0.5f0; release_secs = 0.05)
    tone(named_wavetables[wt], pitch, dur, vel; release_secs)
end

"""
    tone(wt :: WaveTone, pitch, dur, vel = 0.5f0; release_secs = 0.05)

With this, you can take an existing configured wavetable tone and assign a
different pitch/dur/vel characteristic to it.
"""
function tone(wt :: WaveTone, pitch, dur, vel = 0.5f0; release_secs = 0.05)
    tone(wt.wave_table, pitch, dur, vel; release_secs)
end

struct Sound <: Gen
    samples :: Vector{Float32}
end




