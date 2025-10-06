struct Scheduler{Clk<:Signal} <: Signal
    clock::Clk
    t::Ref{Float64}
    chan::Channel{Tuple{Float64,Signal}}
    voices::Vector{Tuple{Float64,Signal}}
    realtime::Vector{Float64}
end

function now(s::Scheduler{Clk})::Float64 where {Clk<:Signal}
    return s.t[]
end

"""
    scheduler(clk :: Signal) :: Scheduler

Creates a "scheduler" which is itself a signal that can be composed
with other signals and processors. The scheduler runs on its own 
clock and sending `Tuple{Float64,Signal}` values on the `.chan`
property will trigger those signals at the given times according
to the clock. The scheduling is sample accurate.
"""
function scheduler(clk::Signal)
    Scheduler(
        clk,
        Ref(0.0),
        Channel{Tuple{Float64,Signal}}(),
        Vector{Tuple{Float64,Signal}}(),
        Vector{Float64}(),
    )
end

"""
    sched(sch :: Scheduler{Clk}, t::Float64, s::Signal) where {Clk <: Signal}

Schedules a signal to start at time `t` according to the clock of the
given scheduler.
"""
function sched(sch::Scheduler{Clk}, t::Float64, s::Signal) where {Clk<:Signal}
    put!(sch.chan, (t, s))
end

function done(s::Scheduler{Clk}, t, dt) where {Clk<:Signal}
    inactive = findall(tv -> done(tv[2], t, dt), s.voices)
    deleteat!(s.voices, inactive)
    deleteat!(s.realtime, inactive)
    done(s.clock, t, dt)
end

function value(s::Scheduler{Clk}, t, dt) where {Clk<:Signal}
    while isready(s.chan)
        push!(s.voices, take!(s.chan))
        push!(s.realtime, 0.0)
    end
    sv = 0.0f0

    ct = value(s.clock, t, dt)
    s.t[] = ct

    for (i, (tv, v)) in enumerate(s.voices)
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
        sv += value(v, t - s.realtime[i], dt)
    end

    return sv
end
