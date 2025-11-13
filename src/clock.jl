"""
    mutable struct Clock{S <: Signal} <: Signal

Very similar to [`phasor`](@ref) except that phasor does a modulus
to the range [0.0,1.0] while Clock doesn't. So you can use
Clock as a time keeper for a scheduler, for example, so
scheduling can happen on a different timeline than real time.

## Constructors

- `clock(speed :: Signal, t_end)`
- `clock_bpm(tempo_bpm, t_end)`
"""
mutable struct Clock{S<:Signal} <: Signal
    speed::S
    t::Float64
    t_end::Float64
    dt::Float64 # You can read off the last delta time from this.
end

"""
    clock(speed :: Real, t_end :: Real = Inf)
    clock(speed :: Signal, t_end :: Real = Inf)

Constructs different kinds of clocks. Clocks can be speed controlled.
Clocks used for audio signals should be made using the `clock` constructor
and those for scheduling purposes using [`clock_bpm`](@ref).
"""
function clock(speed::Real, t_end::Real = Inf)
    Clock(konst(speed), 0.0, t_end, 0.0)
end
function clock(speed::Signal, t_end::Real = Inf)
    Clock(speed, 0.0, t_end, 0.0)
end

"""
    clock_bpm(tempo_bpm=60.0, t_end :: Real = Inf) :: Signal
    clock_bpm(tempo_bpm :: Signal, t_end :: Real = Inf) :: Signal

Constructs different kinds of clocks. Clocks can be speed controlled.
Clocks used for audio signals should be made using the [`clock`](@ref) constructor
and those for scheduling purposes using `clock_bpm`.
"""
function clock_bpm(tempo_bpm::Real = 60.0, t_end::Real = Inf)
    Clock(konst(tempo_bpm/60.0), 0.0, t_end, 0.0)
end
function clock_bpm(tempo_bpm::Signal, t_end::Real = Inf)
    Clock((1.0/60.0) * tempo_bpm, 0.0, t_end, 0.0)
end

done(c::Clock, t, dt) = t > c.t_end || done(c.speed, t, dt)

function value(c::Clock, t, dt)
    v = c.t
    step = value(c.speed, t, dt) * dt
    c.t += step
    c.dt = step
    return v
end
