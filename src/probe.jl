
mutable struct Probe{S<:Signal} <: Signal
    s::S
    chan::Channel{Float32}
    interval::Float64
    t::Float64
    wv::Float64
    ws::Float64
    v::Float32
end

done(p::Probe{S}, t, dt) where {S<:Signal} = done(p.s, t, dt)

function value(p::Probe{S}, t, dt) where {S<:Signal}
    sv = value(p.s, t, dt)
    p.v = p.wv * p.v + p.ws * sv
    p.t -= dt
    if p.t < 0.0
        # TODO: There is perhaps room for some improvement here
        # to keep the probe value fresh in case it is taking
        # time to draw out already probed values.
        if canput(p.chan)
            put!(p.chan, p.v)
        end
        p.t += p.interval
    end
    return sv
end

"""
    probe(s :: Signal, chan :: Channel{Float32}, interval :: Float64 = 0.04; samplingrate = 48000) :: Probe
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
    chan::Channel{Float32},
    interval::Float64 = 0.04;
    samplingrate = 48000,
)
    wv = 2 ^ (- 1.0 / (interval * samplingrate))
    Probe(s, chan, interval, 0.0, wv, 1.0 - wv, 0.0f0)
end
function probe(s::Signal, interval::Float64 = 0.04; samplingrate = 48000)
    probe(s, Channel{Float32}(2), interval; samplingrate)
end
function probe(s::Fanout{S}, interval::Float64 = 0.04; samplingrate = 48000) where {S <: Signal}
    fanout(probe(s,interval;samplingrate))
end


const TimeSpan = StepRangeLen{Float64, Base.TwicePrecision{Float64}, Base.TwicePrecision{Float64}, Int64}
const TimedSamples = @NamedTuple{span :: TimeSpan, samples :: Vector{Float32}}

mutable struct WaveProbe{S<:Signal} <: Signal
    const s::S
    const chan::Channel{TimedSamples}
    const interval::Float64
    const Ninterval::Int
    const duration::Float64
    const Nduration::Int
    const samples::Vector{Float32}
    t::Float64
    i_from::Int
    i_to::Int
end

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
        if canput(p.chan)
            # If can't put now, just skip it.
            put!(p.chan, TimedSamples(span, copy(p.samples[1:length(span)])))
        end
        if p.i_from + p.Ninterval > p.Nduration
            @assert p.i_from + p.Ninterval == p.Nduration + 1
            p.samples[1:p.i_from-1] = p.samples[p.i_from:end]
        end
    end
    return sv
end

"""
    waveprobe(s :: Signal, chan :: Channel{TimedSamples}, duration :: Float64 = 0.25, interval :: Float64 = 0.04; samplingrate = 48000) :: Probe
    waveprobe(s :: Signal, duration :: Float64 = 0.25, interval :: Float64 = 0.04; samplingrate = 48000) :: Probe

A probe is a "pass through" signal transformer which periodically reports a
reading of the signal to a channel. The channel may either be given or a new
one can be created by the second variant. Since it is a pass-through, you can
insert a probe at any signal point. A probe low-pass-filters the signal before
sending it out the channel, so it won't be useful for signals that vary very
fast. The default value has it sampling the signal every 40ms.

The channel can then be connected to a UI display widget that shows values
as they come in on the channel.

*STATUS*: Needs testing. Also needs a corresponding UI element to test its utility.
"""
function waveprobe(
    s::Signal,
    chan::Channel{TimedSamples},
    duration::Real = 0.25;
    interval::Real = 0.04,
    samplingrate = 48000,
)
    wv = 2 ^ (- 1.0 / (interval * samplingrate))
    Nduration = floor(Int, duration * samplingrate)
    Ninterval = floor(Int, interval * samplingrate)
    WaveProbe(s, chan,
              Float64(duration), Nduration,
              Float64(interval), Ninterval,
              zeros(Float32, Nduration),
              0.0,
              1,
              1)
end
function waveprobe(s::Signal, duration::Real = 0.25, interval::Real = 0.04; samplingrate = 48000)
    waveprobe(s, Channel{TimedSamples}(2), duration, interval; samplingrate)
end
