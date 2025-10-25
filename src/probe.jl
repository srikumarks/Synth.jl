
using Observables

"""
    abstract type Probe{T} <: Signal end

Needs to support the method `source(probe::Probe{T}) :: Observable{T}`
To connect a probe to an appropriate UI element, use [`connectui`](@ref)
(`connectui(::Union{LED,Level,Waveform},::Probe{T})`).
"""
abstract type Probe{T} <: Signal end

mutable struct ValProbe{S<:Signal} <: Probe{Float32}
    const s::S
    const obs::Observable{Float32}
    const interval::Float64
    t::Float64
    wv::Float64
    ws::Float64
    v::Float32
end

source(p::ValProbe{S}) where {S <: Signal} = p.obs

done(p::ValProbe{S}, t, dt) where {S<:Signal} = done(p.s, t, dt)

function value(p::ValProbe{S}, t, dt) where {S<:Signal}
    sv = value(p.s, t, dt)
    p.v = p.wv * p.v + p.ws * sv
    p.t -= dt
    if p.t < 0.0
        # TODO: There is perhaps room for some improvement here
        # to keep the probe value fresh in case it is taking
        # time to draw out already probed values.
        p.obs[] = p.v
        p.t += p.interval
    end
    return sv
end

"""
    probe(s :: Signal, interval :: Float64 = 0.04; samplingrate = 48000) :: Probe

A probe is a "pass through" signal transformer which periodically reports a
reading of the signal to a channel. The channel may either be given or a new
one can be created by the second variant. Since it is a pass-through, you can
insert a probe at any signal point. A probe low-pass-filters the signal before
sending it out the channel, so it won't be useful for signals that vary very
fast. The default value has it sampling the signal every 40ms.

The channel can then be connected to a UI display widget that shows values
as they come in on the channel.
"""
function probe(
    s::Signal,
    interval::Float64 = 0.04;
    samplingrate = 48000,
)
    wv = 2 ^ (- 1.0 / (interval * samplingrate))
    ValProbe(s, Observable{Float32}(0.0f0), interval, 0.0, wv, 1.0 - wv, 0.0f0)
end
function probe(s::Fanout{S}, interval::Float64 = 0.04; samplingrate = 48000) where {S <: Signal}
    fanout(probe(s,interval;samplingrate))
end


const TimeSpan = StepRangeLen{Float64}
struct TimedSamples
    span::TimeSpan
    samples::Vector{Float32}

    TimedSamples() = new(0.0:1.0:1.0, [0.0f0, 0.0f0])
    TimedSamples(span::TimeSpan, samples::Vector{Float32}) = begin
        @assert length(span) == length(samples)
        new(span, samples)
    end
    TimedSamples(span::TimeSpan, samples::AbstractVector{<:Real}) = begin
        @assert length(span) == length(samples)
        new(span, Float32.(samples))
    end
end

mutable struct WaveProbe{S<:Signal} <: Probe{TimedSamples}
    const s::S
    const obs::Observable{TimedSamples}
    const interval::Float64
    const Ninterval::Int
    const duration::Float64
    const Nduration::Int
    const samples::Vector{Float32}
    t::Float64
    i_from::Int
    i_to::Int
end

source(p::WaveProbe{S}) where {S <: Signal} = s.obs
done(p::WaveProbe{S}, t, dt) where {S<:Signal} = done(p.s, t, dt)


function value(p::WaveProbe{S}, t, dt) where {S<:Signal}
    sv = value(p.s, t, dt)
    p.samples[p.i_to] = sv
    p.i_to += 1
    if p.i_to - p.i_from >= p.Ninterval
        if p.i_to <= p.Nduration
            p.i_from += p.Ninterval
        else
            p.i_to -= Ninterval
        end
        span = (t - dt * (p.i_to-1)):dt:t
        @assert length(p.samples) == p.Nduration
        @assert p.Nduration >= p.Ninterval
        @assert length(span) <= p.Nduration
        if !isfull(p.chan)
            # If can't put now, just skip it.
            ts = TimedSamples(span, p.samples[1:length(span)])
            @debug "Sending probe wave" span=length(ts.span) samples=length(ts.samples) min=minimum(ts.samples) max=maximum(ts.samples)
            p.obs[] = ts
        end
        if p.i_from + p.Ninterval > p.Nduration
            @assert p.i_from + p.Ninterval == p.Nduration + 1
            p.samples[1:p.i_from-1] = view(p.samples, p.Ninterval+1:p.Nduration)
        end
    end
    return sv
end

"""
    waveprobe(s :: Signal, duration :: Float64 = 0.25, interval :: Float64 = 0.04; samplingrate = 48000) :: Probe

A waveprobe, like [`probe`](@ref) is a "pass through" signal transformer which
periodically reports a reading of the signal to an `Observable`. Since it is a
pass-through, you can insert a probe at any signal point. The default value has
it sampling the signal every 40ms.

[`connectui`](@ref) can be used to connect a `Probe{TimedSamples}` to a `WaveProbe`.
"""
function waveprobe(
    s::Signal,
    duration::Real = 0.25;
    interval::Real = 0.04,
    samplingrate = 48000,
)
    wv = 2 ^ (- 1.0 / (interval * samplingrate))
    Nduration = floor(Int, duration * samplingrate)
    Ninterval = floor(Int, interval * samplingrate)
    WaveProbe(s, 
              Observable{TimedSamples}(),
              Float64(duration), Nduration,
              Float64(interval), Ninterval,
              zeros(Float32, Nduration),
              0.0,
              1,
              1)
end
