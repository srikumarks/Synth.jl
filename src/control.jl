
mutable struct Control <: Signal
    chan :: Channel{Float32}
    wv :: Float64
    ws :: Float64
    v :: Float32
    lastv :: Float32
end

done(c :: Control, t, dt) = false

function value(c :: Control, t, dt)
    while isready(c.chan)
        c.lastv = take!(c.chan)
    end

    # Dezipper the control signal.
    v = c.v * c.wv + c.lastv * c.ws
    c.v = v
    return v
end

"""
    control(chan :: Channel{Float32}, dezipper_interval = 0.04; initial = 0.0f0, samplingrate=48000) :: Control
    control(dezipper_interval = 0.04; initial = 0.0f0, samplingrate = 48000) :: Control

A "control" is a signal that is driven by values received on a given or
created channel. The control will dezipper the value using a first order LPF
and send it out as its value. The intention is to be able to bind a UI element
that produces a numerical value as a signal that can be patched into the graph.
"""
function control(chan :: Channel{Float32}, dezipper_interval = 0.04; initial = 0.0f0, samplingrate=48000) :: Control
    wv = 2 ^ (- 1.0 / (dezipper_interval * samplingrate))
    Control(chan, wv, 1.0 - wv, initial, initial)
end
function control(dezipper_interval = 0.04; bufferlength = 2, initial = 0.0f0, samplingrate = 48000) :: Control
    control(Channel{Float32}(bufferlength), dezipper_interval; initial, samplingrate)
end
