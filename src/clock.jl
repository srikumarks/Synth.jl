"""
    mutable struct Clock{S <: Signal} <: Signal

Very similar to Phasor except that phasor does a modulus
to the range [0.0,1.0] while Clock doesn't. So you can use
Clock as a time keeper for a scheduler, for example, so
scheduling can happen on a different timeline than real time.

## Constructors

- `clock(speed :: S, t_end; sampling_rate_Hz) where {S <: Signal}`
- `clock_bpm(tempo_bpm, t_end; sampling_rate_Hz)`
"""
mutable struct Clock{S <: Signal} <: Signal
    speed :: S
    t :: Float64
    t_end :: Float64
    dt :: Float64
end

"""
    clock(speed :: Real, t_end :: Real = Inf; sampling_rate_Hz = 48000)
    clock_bpm(tempo_bpm=60.0, t_end :: Real = Inf; sampling_rate_Hz = 48000)
    clock_bpm(tempo_bpm :: S, t_end :: Real = Inf; sampling_rate_Hz = 48000) where {S <: Signal}
    clock(speed :: S, t_end :: Real = Inf; sampling_rate_Hz = 48000) where {S <: Signal}

Constructs different kinds of clocks. Clocks can be speed controlled.
Clocks used for audio signals should be made using the `clock` constructor
and those for scheduling purposes using `clock_bpm`.
"""
clock(speed :: Real, t_end :: Real = Inf; sampling_rate_Hz = 48000) = Clock(konst(speed), 0.0, t_end, 1.0/sampling_rate_Hz)
clock_bpm(tempo_bpm=60.0, t_end :: Real = Inf; sampling_rate_Hz = 48000) = Clock(konst(tempo_bpm/60.0), 0.0, t_end, 1.0/sampling_rate_Hz)
clock_bpm(tempo_bpm :: S, t_end :: Real = Inf; sampling_rate_Hz = 48000) where {S <: Signal} = Clock((1.0/60.0) * tempo_bpm, 0.0, t_end, 1.0/sampling_rate_Hz)
clock(speed :: S, t_end :: Real = Inf; sampling_rate_Hz = 48000) where {S <: Signal} = Clock(speed, 0.0, t_end, 1.0/sampling_rate_Hz)

done(c :: Clock, t, dt) = t > c.t_end || done(c.speed, t, dt)
function value(c :: Clock, t, dt)
    v = c.t
    c.t += value(c.speed, t, dt) * dt
    return v
end


