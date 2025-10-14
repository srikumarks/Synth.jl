
mutable struct Control <: Signal
    chan::Channel{Float32}
    wv::Float64
    ws::Float64
    v::Float32
    latestval::Float32
    last_t::Float64 # Automatically support fanning out controls.
end

done(c::Control, t, dt) = (c.state == :closed)

function value(c::Control, t, dt)
    if t > c.last_t
        # `isready` won't error out even if the channel is closed. Doing this
        # conforms to the expectation that value may end up being called for a few
        # samples after the signal has actually ended and it must continue on for a
        # little longer until done gets called to check the state.
        while isready(c.chan)
            c.latestval = take!(c.chan)
        end

        # Dezipper the control signal.
        v = c.v * c.wv + c.latestval * c.ws
        c.v = v
        c.last_t = t
        return v
    end
    return c.v
end

function Base.setindex!(c::Control, val::Real)
    put!(c.chan, Float32(val))
    val
end

"""
A `Control` automatically supports fanout without needing to be
wrapped.
"""
fanout(sig::Control) = sig

"""
    control(chan :: Channel{Float32}, dezipper_interval = 0.04; initial = 0.0f0, samplingrate=48000) :: Control
    control(dezipper_interval = 0.04; initial = 0.0f0, samplingrate = 48000) :: Control

A "control" is a signal that is driven by values received on a given or
created channel. The control will dezipper the value using a first order LPF
and send it out as its value. The intention is to be able to bind a UI element
that produces a numerical value as a signal that can be patched into the graph.

If `c` is a `Control` struct, you can set the value of the control using `c[] = 0.5f0`.

Close the channel to mark the control signal as "done".

!!! note "Channels and memory"
    A control signal uses a channel to receive its values. This raises a
    question about the amount of memory that'll be consumed by using what looks
    like a system resource. Julia's channels cost about 416 bytes each, meaning
    a 1000 channels, which would be a pretty complex scenario to put it mildly,
    will be well under 1MB. Even if you have 1000 voices with 10 channels controlling
    each voice, the memory won't be significant (under 5MB) by 2025 standards.
"""
function control(
    chan::Channel{Float32},
    dezipper_interval = 0.04;
    initial = 0.0f0,
    samplingrate = 48000,
)::Control
    wv = 2 ^ (- 1.0 / (dezipper_interval * samplingrate))
    Control(chan, wv, 1.0 - wv, initial, initial)
end
function control(
    dezipper_interval = 0.04;
    bufferlength = 2,
    initial = 0.0f0,
    samplingrate = 48000,
)::Control
    control(Channel{Float32}(bufferlength), dezipper_interval; initial, samplingrate)
end

"""
    stop(c :: Control)

Stops the control signal. From the renderer's perspective, the
control signal will switch to the "done" state. The control
channel will close, causing any further `put!` calls to raise
an exception. If you control the sustain of an [`adsr`](@ref)
using a control signal, then stopping the control will basically
end the ADSR envelope by switching it into "release" phase.
"""
function stop(c::Control)
    close(c.chan)
end
