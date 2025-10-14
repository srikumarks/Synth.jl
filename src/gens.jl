struct Ping <: Gen
    pitch :: Float32
    vel :: Float32
    decay :: Float32
    dur :: Float64
end

"""
    ping(pitch :: Real, vel :: Real, decay :: Real, dur :: Real) :: Gen

A "ping" is a simple decaying sine tone for illustrating how to create a `Gen`.
"""
function ping(pitch :: Real, vel :: Real, decay :: Real, dur :: Real)
    Ping(Float32(pitch), Float32(vel), Float32(decay), Float64(dur))
end

function proc(g :: Ping, s :: Scheduler, t)
    sched(s, t, sinosc(adsr(g.vel, 0.0; release_secs=g.dur), midi2hz(g.pitch)))
    return (t + g.dur, Cont())
end


struct Track{VT} <: Gen
    gens :: VT
    i :: Int
    g :: Gen
end

"""
    track(gs :: AbstractVector{Gen})

A "track" is a sequence of Gens. When each gen finishes,
its `proc` call will produce a `Cont` which indicates it is
time to switch to the next Gen in the track.
"""
function track(gs :: AbstractVector{G}) where {G <: Gen}
    Track(gs, 1, gs[1])
end

function proc(g :: Track, s :: Scheduler, t)
    (t2,g2) = proc(g.g, s, t)
    if iscont(g2)
        if g.i < length(g.gens)
            return (t2, Track(g.gens, g.i+1, g.gens[g.i+1]))
        else
            (t2, g2)
        end
    else
        return (t2, Track(g.gens, g.i, g2))
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

function proc(g :: Loop{G}, s :: Scheduler, t) where {G <: Gen}
    if g.n <= 0
        return (t, Cont())
    end

    (t2,g2) = proc(g.gen, s, t)
    (t2, track([g2, loop(g.n-1, g.gen)]))
end

struct Pause <: Gen
    dur :: Float64
end

"""
    pause(dur :: Real)

Schedules no signals but just waits for the given duration
before proceeding.
"""
function pause(dur :: Real)
    Pause(Float64(dur))
end

function proc(g :: Pause, s :: Scheduler, t)
    (t + g.dur, Cont())
end


