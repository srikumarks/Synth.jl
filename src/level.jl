
mutable struct Monitor{S<:Signal} <: Signal
    const s::S
    const obs::Observable{Float32}
    const label::String
    v::Float32
    x²::Float32
    l::Float32
    const wx::Float32
    const ws::Float32
    const refmin::Float32
    last_t::Float64
    update_interval::Float64
    t_remaining::Float64
end

dispval(m::Monitor) = m.l
Observables.on(f, m::Monitor) = on(f, m.obs)

done(s::Monitor{S}, t, dt) where {S<:Signal} = done(s.s, t, dt)
function value(s::Monitor{S}, t, dt) where {S<:Signal}
    if t > s.last_t
        v = value(s.s, t, dt)
        v² = v * v
        s.v = v
        s.x² = s.wx * s.x² + s.ws * v²
        if s.t_remaining <= 0.0
            s.l = 10.0f0*log10(s.x² + s.refmin)
            s.obs[] = s.l
            s.t_remaining += s.update_interval
        end
        s.t_remaining -= dt
        s.last_t = t
    end
    s.v
end

"""
    monitor(s::Signal)

Computes the smoothed dB level of a signal. The range is from 0 to about 90dB. 
This is intended for visualization and not for use as a signal itself.
Use `monitor` if you want an observable to link to a UI.

For the default value, the max ends up around ``20\\log_{10}(8000) \\approx 78\\text{dB}``.
A factor of two change in amplitude is a change in level of around 6.021 dB.

Named arguments -

- `interval::Real=0.015`
  The smoothing and update interval - i.e. the time constant of the
  first order filter that's applied on the square of the signal.
  This is also the interval at which the observable will be updated.
- `refmin=1/8000` The minimum logical signal value that is not zero.
  It is the tiniest sliver of sound intensity that can be registered.
  The default is set to a value appropriate for 14-bit sampled sound.
- `samplingrate=48000`
- `label::AbstractString=""` for use with user interface elements if provided.

"""
function monitor(s::Signal; interval = 0.015, refmin = 1/8000, samplingrate = 48000, label::AbstractString="")
    wx = Float32(2^(-1/(interval*samplingrate)))
    ws = 1.0f0 - wx
    obs = Observable(0.0f0)
    Monitor(
          s,
          obs,
          string(label),
          0.0f0,
          0.0f0,
          0.0f0,
          wx,
          ws,
          Float32(refmin^2),
          -0.001,
          Float64(interval),
          0.0
         )
end

"""
     level(s::Signal)

Essentially performs the same computation as [`monitor`](@ref "Synth.monitor"),
but gives the value as a signal, while `monitor` passes through the signal while
observing it.
"""
function level(s::Signal)
    refmin = Float32(1/(8000^2))
    square(x::Float32) = x*x
    tolevel(x::Float32) = Float32(10.0 * log10(x+refmin))
    map(tolevel, lpf(map(square, s), 30.0, 10.0))
end
