
import Base: Tuple

"""
A "Gen" is a process for producing signals.
The `proc(::Gen,::Bus,t)` which returns
`Tuple{Float64,Gen}` needs to be defined for a
gen to be usable by the `Bus`.

The `Gen` returned by the `proc` call semantically
replaces the gen that produced it. That way, we
get recursive generation.
"""
abstract type Gen end

"""
`Stop` is a `Gen` that will stop any further 
signals from being generated.
"""
struct Stop <: Gen end
struct Cont <: Gen end

isstop(g::Gen) = false
isstop(g::Stop) = true
iscont(g::Gen) = false
iscont(g::Cont) = true

mutable struct Bus{Clk<:Signal} <: Signal
    const clock::Clk
    t::Float64
    next_t::Float64
    dt::Float64
    const gchan::Channel{Tuple{Float64,Gen}}
    const gens::Vector{Tuple{Float64,Gen}}
    const vchan::Channel{Tuple{Float64,Signal}}
    const voices::Vector{Tuple{Float64,Signal}}
    const realtime::Vector{Float64}
end

function proc(g :: Gen, s :: Bus, t)
    @assert false "Unimplemented proc for $(typeof(g))"
    return (Inf,Stop())
end

function proc(g :: Stop, s :: Bus, t)
    (Inf, g)
end

function proc(g :: Cont, s :: Bus, t)
    (t, g)
end


function now(s::Bus{Clk})::Float64 where {Clk<:Signal}
    return s.t
end

"""
    bus(clk :: Signal) :: Bus

Creates a "bus" which is itself a signal that can be composed
with other signals and processors. The bus runs on its own 
clock and sending `Tuple{Float64,Signal}` values on the `.gchan`
property will trigger those signals at the given times according
to the clock. The scheduling is sample accurate.
"""
function bus(clk::Signal)
    Bus(
        clk,
        0.0,
        0.0,
        1/60,
        Channel{Tuple{Float64,Gen}}(16),
        Vector{Tuple{Float64,Gen}}(),
        Channel{Tuple{Float64,Signal}}(16),
        Vector{Tuple{Float64,Signal}}(),
        Vector{Float64}(),
    )
end

"""
    bus(tempo_bpm::Real)

Simpler constructor for a fixed tempo bus.
"""
function bus(tempo_bpm::Real = 60.0)
    bus(clock_bpm(tempo_bpm))
end

"""
    sched(sch :: Bus{Clk}, t::Float64, s::Signal) where {Clk <: Signal}

Schedules a signal to start at time `t` according to the clock of the
given bus.
"""
function sched(sch::Bus{Clk}, t::Float64, s::Signal) where {Clk<:Signal}
    put!(sch.vchan, (t, s))
end
function sched(sch::Bus{Clk}, t::Float64, g::Gen) where {Clk<:Signal}
    put!(sch.gchan, (t,g))
end

function done(s::Bus{Clk}, t, dt) where {Clk<:Signal}
    inactive = findall(tv -> done(tv[2], t, dt), s.voices)
    deleteat!(s.voices, inactive)
    deleteat!(s.realtime, inactive)
    done(s.clock, t, dt)
end

function value(s::Bus{Clk}, t, dt) where {Clk<:Signal}
    ct = value(s.clock, t, dt)
    s.t = ct
    if ct >= s.next_t
        count = 0
        while isready(s.gchan)
            push!(s.gens, take!(s.gchan))
            count += 1
        end
        if count > 0
            sort!(s.gens; by=(tg) -> tg[1]) 
        end
        for i in eachindex(s.gens)
            (gt,gg) = s.gens[i]
            if gt < ct + dt
                s.gens[i] = proc(gg, s, gt)
            else
                break
            end
        end
        while isready(s.vchan)
            push!(s.voices, take!(s.vchan))
            push!(s.realtime, 0.0)
        end
        infs = findall((e) -> isinf(e[1]) || isstop(e[2]) || iscont(e[2]), s.gens)
        deleteat!(s.gens, infs)
        s.next_t = ct + s.dt
    end

    sv = 0.0f0

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
