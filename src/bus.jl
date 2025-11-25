
import Base: Tuple

"""
A "Gen" is a process for producing signals.
The `proc(::Gen,::AbstractBus,t,rt)` which returns
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
isactive(g::Gen) = true
isactive(g::Stop) = false
isactive(g::Cont) = false

"""
An `AbstractBus` is expected to only support the two
`sched` methods - 

 - `sched(sch::AbstractBus, t::Real, s::Signal)`
 - `sched(sch::AbstractBus, t::Real, g::Gen)`
 - `sched(sch::AbstractBus, s::Signal)`
 - `sched(sch::AbstractBus, g::Gen)`

All buses are expected to support fanout without having
to use the [`fanout`](@ref) operator.
"""
abstract type AbstractBus <: SignalWithFanout end

mutable struct Bus{Clk<:Signal} <: AbstractBus
    # The clock drives the pace at which time passes when rendering events on
    # the bus. You can consider integer valued time to be "beats" and the
    # clock's tempo is given in "beats per minute".
    const clock::Clk 

    # The last time step for checking for events. Events (Gens) are checked for
    # roughly 60 times a second - i.e. are considered "near real time".
    t::Float64

    # The next time step at which Gens will get a hearing.
    next_t::Float64

    # The time step between two checks for Gens.
    const dt::Float64

    # The bus receives time stamped Gens on this channel and calls proc on
    # them to determine signals to mix into the bus. The time stamp is taken
    # to be in clock time. Therefore if the clock is running at 120bpm, then
    # a time stamp of 2.0 will happen in 1.0 seconds.
    const gchan::Channel{Tuple{Float64,Gen}}

    # A time sorted list of gens yet to be processed. Gens return the
    # next gen to be processed and these can be scheduled for later.
    const gens::Vector{Tuple{Float64,Gen}}

    # Gens can schedule signals on this channel.
    const vchan::Channel{Tuple{Float64,Signal}}

    # Voices scheduled by gens will accumulate (time sorted) into this
    # vector and will be rendered by the bus as time progresses.
    const voices::Vector{Tuple{Float64,Signal}}

    # The actual time at which a signal starts, so its t argument to the
    # value can be determined relative to this.
    const realtime::Vector{Float64}

    # The last time step that was run (for a sample), and the last
    # value generated.
    last_t::Float64
    last_val::Float32
end


function genproc(g :: Gen, s :: AbstractBus, t, rt)
    @assert false "Unimplemented proc for $(typeof(g))"
    return (Inf,Stop())
end

function genproc(g :: Stop, s :: AbstractBus, t, rt)
    (Inf, g)
end

function genproc(g :: Cont, s :: AbstractBus, t, rt)
    (t, g)
end


"""
    now(s::Bus{<:Signal})::Float64
    now(s::Bus{<:Signal}, b::Type{<:Integer})::Float64
    now(s::Bus{<:Signal}, b::Rational)::Float64
    now(s::Bus{<:Signal}, b::Integer)::Float64

Returns the bus' "current time". If a beat is passed or asked for,
the time is quantized to beats according to the clock's tempo.
"""
function now(s::Bus{Clk})::Float64 where {Clk<:Signal}
    return s.next_t
end

function now(s::Bus{Clk}, b::Type{T})::Float64 where {Clk<:Signal,T<:Integer}
    return ceil(s.next_t)
end

function now(s::Bus{Clk}, b::Rational)::Float64 where {Clk<:Signal}
    return ceil(s.next_t) + Float64(b)
end

function now(s::Bus{Clk}, b::Integer)::Float64 where {Clk<:Signal}
    return ceil(s.next_t) + Float64(b)
end

"""
    bus(clk :: Signal) :: Bus

Creates a "bus" which is itself a signal that can be composed
with other signals and processors. The bus runs on its own 
clock and sending `Tuple{Float64,Signal}` values on the `.gchan`
property will trigger those signals at the given times according
to the clock. The scheduling is sample accurate.

A "bus" supports fanout.
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
        0.0,
        0.0f0,
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
    sched(sch :: Bus{Clk}, t::Real, s::Signal) where {Clk <: Signal}
    sched(sch::Bus{Clk}, s::Signal) where {Clk<:Signal}
    sched(sch::Bus{Clk}, t::Real, g::Gen) where {Clk<:Signal}
    sched(sch::Bus{Clk}, g::Gen) where {Clk<:Signal}

Schedules a signal to start at time `t` according to the clock of the given
bus. In the third variant without a `t`, the scheduling happens at an
ill-specified "now" - which basically means "asap". 

**Note:** When scheduling signals and gens within a proc() call, a maximum of
16 is supported. You usually won't need so many since any co-scheduled gens and
signals usually have a temporal relationship that is better captured using
available composition operators.
"""
function sched(sch::Bus{Clk}, t::Real, s::Signal) where {Clk<:Signal}
    @assert !isfull(sch.vchan) "Too many signals scheduled to bus too quickly. Max 16."
    put!(sch.vchan, (Float64(t), s))
    nothing
end
function sched(sch::Bus{Clk}, s::Signal) where {Clk<:Signal}
    sched(sch, now(sch), s)
end
function sched(sch::Bus{Clk}, t::Real, g::Gen) where {Clk<:Signal}
    @assert !isfull(sch.gchan) "Too many gens scheduled to bus too quickly. Max 16."
    put!(sch.gchan, (Float64(t),g))
    nothing
end
function sched(sch::Bus{Clk}, g::Gen) where {Clk<:Signal}
    sched(sch, now(sch), g)
end

function done(s::Bus{Clk}, t, dt) where {Clk<:Signal}
    inactive = findall(tv -> done(tv[2], t, dt), s.voices)
    deleteat!(s.voices, inactive)
    deleteat!(s.realtime, inactive)
    done(s.clock, t, dt) || !isopen(s.gchan) || !isopen(s.vchan)
end

function value(s::Bus{Clk}, t, dt) where {Clk<:Signal}
    if t <= s.last_t
        return s.last_val
    end
    s.last_t = t

    ct = value(s.clock, t, dt)
    s.t = ct
    if ct >= s.next_t
        count = 0
        try
            clockspeed = s.clock.speedval
            while isready(s.gchan)
                push!(s.gens, take!(s.gchan))
                count += 1
            end
            if count > 0
                sort!(s.gens; by=first)
            end
            for (i, (gt, gg)) in enumerate(s.gens)
                while isactive(gg) && gt < ct + s.dt
                    ng = invokelatest(genproc, gg, s, gt, t + (gt - ct) / clockspeed)
                    gt = ng[1]
                    gg = ng[2]
                    s.gens[i] = ng
                end
            end
            sort!(s.gens; by=first) 
            while isready(s.vchan)
                push!(s.voices, take!(s.vchan))
                push!(s.realtime, 0.0)
            end
            sort!(s.voices; by=first)
            if length(s.gens) == 1 && isstop(s.gens[1][2])
                close(s.gchan)
                close(s.vchan)
            else
                infs = findall((e) -> isinf(e[1]) || !isactive(e[2]), s.gens)
                deleteat!(s.gens, infs)
                s.next_t = ct + s.dt
            end
        catch e
            @error "Bus error" error=(e, catch_backtrace())
        end
    end

    sv = 0.0f0
    active = length(s.voices)

    for (i, (tv, v)) in enumerate(s.voices)
        if ct < tv
            active -= 1
            continue
        end
        if s.realtime[i] < dt
            s.realtime[i] = t
        end
        # The dispatch here for v will be dynamic since
        # we don't know at this point what type of signal
        # was received on the channel.
        sv += value(v, t - s.realtime[i], dt)
    end

    if active > 0
        s.last_val = sv
    else
        # Hold the last value on the bus if the voices have stopped.
        sv = s.last_val
    end
    return sv
end
