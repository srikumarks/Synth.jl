
using Observables

mutable struct Control{R} <: SignalWithFanout
    label::String
    obs::Observable{Float32}
    range::R
    wv::Float64
    ws::Float64
    v::Float32
    vout::Float32
    @atomic latestval::Float32
    last_t::Float64 # Automatically support fanning out controls.
end

done(c::Control, t, dt) = false

function Observables.on(f::Function, c::Control)
    on(c.obs) do v
        f(c.v)
    end
end

function control_update(c::Control, t, dt)
    # Dezipper the control signal.
    v = c.v * c.wv + (@atomic c.latestval) * c.ws
    c.v = v
    v
end

function value(c::Control{R}, t, dt) where {R <: Tuple{Real,Real}}
    if t > c.last_t
        c.last_t = t
        c.vout = max(Float32(c.range[1]), min(Float32(c.range[2]), control_update(c, t, dt)))
    end
    c.vout
end

function value(c::Control{R}, t, dt) where {R <: StepRangeLen}
    if t > c.last_t
        c.last_t = t
        v = max(Float32(c.range[1]), min(Float32(c.range[end]), control_update(c, t, dt)))
        vi = round((v - c.range[1]) / c.range.step)
        c.vout = Float32(c.range[1] + vi * c.range.step)
    end
    c.vout
end


function Base.setindex!(c::Control, val::Real)
    c.obs[] = Float32(val)
    val
end

# Note that this can differ from the observable's value.
Base.getindex(c::Control) = @atomic c.latestval

const ControlRange = Union{Tuple{Real,Real}, StepRangeLen}

"""
    control(obs::Observable{Float32}, range::Tuple{Real,Real}; ...) :: Control
    control(obs::Observable{Float32}, range::StepRangeLen; ...) :: Control
    control(range::ControlRange; ...) :: Control

Named parameters for all variants - 

- `dezipper_interval::Real` with a default value of `0.0075` in seconds,
- `initial::Real` with a default value of `0.0f0`,
- `samplingrate::Real` with a default value of `48000` in Hz,
- `label::AbstractString` with a default value of empty string. 
  Optional label that may be shown when visualizing the control.

A "control" is a signal that is driven by values received on a given or
created channel. The control will dezipper the value using a first order LPF
and send it out as its value. The intention is to be able to bind a UI element
that produces a numerical value as a signal that can be patched into the graph.

If you use a tuple as range, then the value may be any value within that range
and the range is taken to be continuous. If you use a `StepRangeLen` like 
`0.5f0:0.1f0:1.5f0` then the range is taken to be discrete and reading the
control value will produce only discrete (quantized) values.

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
    obs::Observable{Float32},
    range::Tuple{Real,Real};
    dezipper_interval = 0.0075,
    initial = range[1],
    samplingrate = 48000,
    label::AbstractString = ""
)
    @assert range[1] < range[2] "Invalid control range $range"
    wv = 2 ^ (- 1.0 / (dezipper_interval * samplingrate))
    c = Control(string(label),obs, range, wv, 1.0 - wv, Float32(initial), Float32(range[1]), Float32(initial), 0.0)
    on(obs) do v
        v = max(c.range[1], min(c.range[2], v))
        @atomic :monotonic c.latestval = v
    end
    return c
end
function control(
    obs::Observable{Float32},
    range::StepRangeLen;
    dezipper_interval = 0.0075,
    initial = range[1],
    samplingrate = 48000,
    label::AbstractString = ""
)
    wv = 2 ^ (- 1.0 / (dezipper_interval * samplingrate))
    c = Control(string(label), obs, range, wv, 1.0 - wv, Float32(initial), Float32(range[1]), Float32(initial), 0.0)
    on(obs) do v
        v = max(c.range[1], min(c.range[end], v))
        @atomic :monotonic c.latestval = v
    end
    return c
end
function control(range::ControlRange;
    dezipper_interval = 0.0075,
    bufferlength = 2,
    initial = range[1],
    samplingrate = 48000,
    label::AbstractString = ""
)
    control(Observable{Float32}(initial), range; dezipper_interval, initial, samplingrate, label)
end

