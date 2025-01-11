
mutable struct Probe{S <: Signal} <: Signal
    s :: S
    chan :: Channel{Float32}
    interval :: Float64
    t :: Float64
    wv :: Float64
    ws :: Float64
    v :: Float32
end

done(p :: Probe{S}, t, dt) where {S <: Signal} = done(p.s, t, dt)

function value(p :: Probe{S}, t, dt) where {S <: Signal}
    sv = value(p.s, t, dt)
    p.v = p.wv * p.v + p.ws * sv
    p.t -= dt
    if p.t < 0.0 
        # TODO: There is perhaps room for some improvement here
        # to keep the probe value fresh in case it is taking
        # time to draw out already probed values.
        if c.n_avail_items < c.sz_max
            put!(p.chan, p.v)
        end
        p.t = p.interval
    end
    return sv
end

"""
    probe(s :: S, chan :: Channel{Float32}, interval :: Float64 = 0.1; samplingrate = 48000) :: Probe{S} where {S <: Signal}
    probe(s :: S, interval :: Float64 = 0.1; samplingrate = 48000) :: Probe{S} where {S <: Signal}

A probe is a "pass through" signal transformer which periodically reports a
reading of the signal to a channel. The channel may either be given or a new
one can be created by the second variant. Since it is a pass-through, you can
insert a probe at any signal point. A probe low-pass-filters the signal before
sending it out the channel, so it won't be useful for signals that vary very
fast. The default value has it sampling the signal every 40ms.

The channel can then be connected to a UI display widget that shows values
as they come in on the channel.
"""
function probe(s :: S, chan :: Channel{Float32}, interval :: Float64 = 0.04; samplingrate = 48000) :: Probe{S} where {S <: Signal}
    wv = 2 ^ (- 1.0 / (interval * samplingrate))
    Probe(s, chan, interval, 0.0, wv, 1.0 - wv, 0.0f0)
end
function probe(s :: S, interval :: Float64 = 0.04; samplingrate = 48000) :: Probe{S} where {S <: Signal}
    probe(s, Channel{Float32}(2), interval; samplingrate)
end

