"""
An internal structure used to keep track of a single
granular "voice".

- `rt` is the time within the grain. 0.0 is the start of the grain.
- `gt` is the grain start time within the larger sample array.
- `dur` is the grain duration in seconds
- `overlap` is also a duration in seconds. The total duration of the grain
   is dependent on both dur and overlap.
"""
mutable struct Grain
    delay::Float64
    rt::Float64
    gt::Float64
    dur::Float32
    overlap::Float32
    speedfactor::Float32
end

"""
Represents a granulation of a sample array.

The grain durations, overlaps and playback speed can be varied
with time as signals. Additionally, the `grainplayphasor` is 
expected to be a phasor that will trigger a new grain voice
upon its negative edge.
"""
mutable struct Granulation{Speed<:Signal,GTime<:Signal,GPlay<:Signal} <: Signal
    samples::Vector{Float32}
    samplingrate::Float32
    granulator::Any
    speed::Speed
    graintime::GTime
    grainplayphasor::GPlay
    lastgrainplayphasor::Float32
    grains::Vector{Grain}
end

"""
    simplegrains(dur :: Real, overlap :: Real, speedfactor :: Real)

Result is a function(time) which when called will produce a vector
of a single grain. This kind of a function is what we call a "granulator"
(see [`granulate`](@ref)).
"""
function simplegrains(dur::Real, overlap::Real, speedfactor::Real)
    function granulator(time)
        [Grain(0.0, 0.0, time, dur, overlap, speedfactor)]
    end
    return granulator
end

"""
    chorusgrains(rng, delayspread=0.0, N=1, spread=5.0f0)

Result is a function(time) which when called will produce a
vector of N grains spread in time. Since the chorus spread
has some randomness to it, you need to pass an RNG. This kind
of function is called a "granulator" (see [`granulate`](@ref)).
"""
function chorusgrains(rng, delayspread = 0.0, N = 1, spread = 5.0f0)
    function grain(rng, time, speedfactor)
        Grain(delayspread * rand(rng), 0.0, time, 0.1, 0.03, speedfactor)
    end

    function granulator(time)
        [grain(rng, time, 2.0 ^ (- spread * (i-1) / 12)) for i = 1:N]
    end
    return granulator
end


"""
    granulate(samples, dur :: Real, overlap :: Real, speed :: Real, graintime,
              player = phasor(1.0 * speed / (dur * (1.0 - overlap)))
              ; samplingrate=48000.0f0)
    granulate(samples::Vector{Float32}, granulator, speed::Signal, graintime::Signal, player::Signal; samplingrate=48000.0f0)

Granular synthesis - simple version.

The `granulator` is a function of time that returns a vector of grains. Two
built-in granulators are available -- `simplegrains` and `chorusgrains`.
The `player` is expected to be a `phasor` which will trigger grains
on the negative edge.

## Example

```julia
    snd = read_rawaudio("/tmp/somefile.raw")
    stop = play(0.5 * granulate(snd, 
                             chorusgrains(rng,0.0,3,4.0),
                             konst(0.5),
                             line(0.0, 10.0, 3.2),
                             phasor(20.0)),
             10.0)
```
"""
function granulate(samples, granulator, speed, graintime, player; samplingrate = 48000.0f0)
    return Granulation(
        samples,
        samplingrate,
        granulator,
        speed,
        graintime,
        player,
        0.0f0,
        Vector{Grain}(),
    )
end
function granulate(
    samples,
    dur::Real,
    overlap::Real,
    speed::Real,
    graintime,
    player = phasor(1.0 * speed / (dur * (1.0 - overlap)));
    samplingrate = 48000.0f0,
)
    Granulation(
        samples,
        samplingrate,
        simplegrains(dur, overlap, 1.0f0),
        konst(speed),
        graintime,
        player,
        0.0f0,
        Vector{Grain}(),
    )
end

function isgrainplaying(gr::Grain)
    gr.delay > 0.0 || (abs(gr.rt) < gr.dur + gr.overlap * 2)
end

function done(g::Granulation, t, dt)
    cleanupdeadvoices!(g.grains)
    false
end

function cleanupdeadvoices!(voices)
    lastdeadvoice = 0
    for voice in voices
        if !isgrainplaying(voice)
            lastdeadvoice += 1
        else
            break
        end
    end
    deleteat!(voices, 1:lastdeadvoice)
end

function value(g::Granulation, t, dt)
    cleanupdeadvoices!(g.grains)

    # Calculate input signal values
    gt = value(g.graintime, t, dt)
    speed = value(g.speed, t, dt)

    # Check whether we need to start a new voice.
    lastgpt = g.lastgrainplayphasor
    gpt = value(g.grainplayphasor, t, dt)
    g.lastgrainplayphasor = gpt
    if gpt - lastgpt < -0.5
        # Trigger new voice for grain
        append!(g.grains, g.granulator(gt))
    end

    # Sum all playing grains
    s = 0.0f0
    tstep = speed / g.samplingrate
    for gr in g.grains
        s += playgrain(g.samples, g.samplingrate, gr, t, dt)
        # Update the grain's clock.
        if gr.delay < 0.0
            gr.rt += tstep * gr.speedfactor
        end
        gr.delay -= dt
    end

    return s
end

"""
Computes the sample value of the given grain at the given time and speed.
The speed of playback of all the grains is a single shared signal to ensure
coherency. 
"""
function playgrain(s::Vector{Float32}, samplingrate, gr::Grain, t, dt)
    if gr.delay > 0.0
        return 0.0f0
    end
    rt, gt, dur, overlap = (gr.rt, gr.gt, gr.dur, gr.overlap)
    fulldur = dur + 2*overlap

    # Account for forward as well as reverse playback. `rt` could become negative
    # if a negative value of speed was given.
    st = mod(rt, fulldur) + gt

    # `sti` is "sample time index". Limit it to a usable range.
    # `i` is its integer part and `f` its fractional part.
    sti = max(1, min(st * samplingrate, length(s)-3))
    i = floor(Int, sti)
    f = sti - i

    # Compute the amplitude envelope. The raisedcos is symmetric,
    # so we can just use abs(rt) without worrying about wrap around.
    a = raisedcos(abs(rt), overlap, fulldur)

    # Do four point interpolation. Useful when going very slow.
    result = a * interp4(f, s[i], s[i+1], s[i+2], s[i+3])

    return result
end
