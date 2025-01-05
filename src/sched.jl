struct Sched{Clk <: Signal} <: Signal
    clock :: Clk
    t :: Float64
    chan :: Channel{Tuple{Float64,Signal}}
    voices :: Vector{Tuple{Float64, Signal}}
    realtime :: Vector{Float64}
end

"""
    sched(clk :: Clk) :: Sched{Clk} where {Clk <: Signal}

Creates a "scheduler" which is itself a signal that can be composed
with other signals and processors. The scheduler runs on its own 
clock and sending `Tuple{Float64,Signal}` values on the `.chan`
property will trigger those signals at the given times according
to the clock. The scheduling is sample accurate.
"""
function sched(clk :: Clk) :: Sched{Clk} where {Clk <: Signal}
    Sched(clk, 0.0, Channel{Tuple{Float64,Signal}}(), [], [])
end

function done(s :: Sched{Clk}, t, dt) where {Clk <: Signal}
    inactive = findall(tv -> done(tv[2],t,dt), s.voices)
    deleteat!(s.voices, inactive)
    deleteat!(s.realtime, inactive)
    done(s.clock, t, dt)
end

function value(s :: Sched{Clk}, t, dt) where {Clk <: Signal}
    while isready(s.chan)
        push!(s.voices, take!(s.chan))
        push!(s.realtime, 0.0)
    end
    s = 0.0f0

    ct = s.t = value(s.clock, t, dt)

    for (i,(tv,v)) in enumerate(voices)
        if ct < tv
            continue
        end
        if s.realtime[i] < dt
            s.realtime[i] = t
        end
        # The dispatch here for v will be dynamic since
        # we don't know at this point what type of signal
        # was received on the channel. Not sure of perf
        # consequences at the moment.
        s += value(v, t - s.realtime[i], dt)
    end

    return s
end


