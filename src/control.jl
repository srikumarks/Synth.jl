using Observables

mutable struct Control <: SignalWithFanout
    chan::Observable{Float32}
    wv::Float64
    ws::Float64
    v::Float32
    latestval::Float32
    last_t::Float64 # Automatically support fanning out controls.
end

done(c::Control, t, dt) = false

function value(c::Control, t, dt)
    if t > c.last_t
        # Dezipper the control signal.
        v = c.v * c.wv + c.latestval * c.ws
        c.v = v
        c.last_t = t
        return v
    end
    return c.v
end

function Base.setindex!(c::Control, val::Real)
    fv = Float32(val)
    c.chan[] = fv
    fv
end

"""
    control(chan :: Observable{Float32}, dezipper_interval = 0.04; initial = 0.0f0, samplingrate=48000) :: Control
    control(dezipper_interval = 0.04; initial = 0.0f0, samplingrate = 48000) :: Control

A "control" is a signal that is driven by values received on a given or
created channel. The control will dezipper the value using a first order LPF
and send it out as its value. The intention is to be able to bind a UI element
that produces a numerical value as a signal that can be patched into the graph.

If `c` is a `Control` struct, you can set the value of the control using `c[] = 0.5f0`.
"""
function control(
    chan::Observable{Float32},
    dezipper_interval = 0.0075;
    initial = 0.0f0,
    samplingrate = 48000,
)::Control
    wv = 2 ^ (- 1.0 / (dezipper_interval * samplingrate))
    on(chan) do v
        c.latestval = v
    end
    Control(chan, wv, 1.0 - wv, initial, initial, 0.0, 0.01, 0.01)
end
function control(
    dezipper_interval = 0.0075;
    initial = 0.0f0,
    samplingrate = 48000,
)::Control
    control(Observable{Float32}(0.0f0), dezipper_interval; initial, samplingrate)
end

