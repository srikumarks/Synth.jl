using Random

const Time = Float64
const SampleVal = Float32

"""
    abstract type Signal end

A `Signal` represents a process that can be asked for a value for every tick of
a clock. We use it here to represent processes that produce audio and control
signals to participate in a "signal flow graph". While mathematically signals
can be treated as though they were infinite in duration, signals are in practice
finite in duration for both semantic and efficiency reasons (ex: managing voices
as a constrained resource).

To construct signals and to wire them up in a graph, use the constructor
functions provided rather than the structure constructors directly.

The protocol for a signal is given by two functions with the following
signatures --

- `done(s :: Signal, t, dt) :: Bool`
- `value(s :: Signal, t, dt) :: Float32`

As long as you implement these two methods, you can define your own subtype of
Signal and use it with the library.

The renderer will call `done` to check whether a signal has completed and if
not, will call `value` to retrieve the next value. The contract with each
signal type is that even if `value` is called for a time after the signal is
complete, it should return sample value 0.0f0 or a value appropriate for the
type of signal. This is so that `done` can be called per audio frame rather
than per sample.

Addition, subtraction and multiplication operations are available to combine
signals and numbers. Currently signals are single channel only.

## Choice of representation

A number of approaches are used in computer music synth systems -

- **Blocks and wires paradigm**: ... where blocks represent signal processing
  modules and wires represent connections and signal flow between these modules.
  Even within this paradigm there are different semantics to how the signal flow
  is handled, from asynchronous/non-deterministic, to fully deterministic flow,
  to buffer-wise computation versus sample-wise computation. The WebAudioAPI,
  for example, takes this approach and performs buffer-wise computation in blocks
  of 128 samples. It is rare to find a synth library that works sample-wise in
  this mode.

- **Functional**: ... where signals are mathematical constructs that can be
  combined using operators to construct new signals. Usually this paradigm
  manifests as a textual programming language, like SuperCollider and Chuck
  (which has elements of the above approach too).

The approach taken **in this library** is to combine the notion of a signal
with the computation that produces the signal - a rough analog of "constructive
real numbers". In other words, a "signal" -- i.e. a stream of values regularly
spaced in time -- is identified with a computation that produces the stream.

This permits manipulating signals like mathematical objects that can be combined,
while modelling "signal flow" via ordinary functions in programming that call other
functions recursively. Without further thought, this approach will only permit
"signal flow trees", where the output of a processing step can only be fed into
a single input due to the nature of function composition being used to construct
the signal flow pattern. However, with the `fanout` operator, it becomes possible
to reuse a signal as input for more than one processing block, extending the
scope to include "signal flow DAGs". The `feedback` operator further extends this
possibility through late binding of signal connections to permit loops in the
graph, truly getting us "signal flow graphs" that can support feedback loops,
albeit with a single sample delay.

The library exploits Julia's "optimizing just-ahead-of-time compilation" to
describe each signal computation function in a per-sample fashion so that
sample frames can be computed efficiently by the renderer. In other languages
including AoT compiled languages like C, this combination of simplicity of API
with high performance will be very hard to get. In dynamic languages, the
function call overhead is even worse and not easily eliminated due to weak type
systems. You'll notice how the rich type information about how a signal was
constructed is maintained in the final result so that the renderer can compile
it down to efficient code, often eliminating intermediate function calls.

Realtime usage necessitates some amount of dynamic dispatch, but it is still
possible to mark boundaries whether the type knowledge can help create efficient
code.

The end result of all this is that you can combine signals like ordinary math
and expect complex signal flow graphs to work efficiently, even in realtime.
"""
abstract type Signal end

"""
    dBscale(::Real)
    dBscale(::Signal)

Converts a dB value to a scaling factor
"""
dBscale(v::Real) = 10.0 ^ (v/10.0)
dBscale(s::Signal) = map(dBscale, s)

"""
    midi2hz(midi::Real)
    midi2hz(::Signal)

Converts a MIDI note number into a frequency using the equal tempered tuning.
"""
midi2hz(m::Real) = 440.0 * (2 ^ ((m - 69.0)/12.0))
midi2hz(s::Signal) = map(midi2hz, s)

"""
    hz2midi(hz::Real)
    hz2midi(::Signal)

Converts a frequency in Hz to its MIDI note number in the equal tempered tuning.
"""
hz2midi(hz::Real) = 69.0 + 12.0*log2(hz/440.0)
hz2midi(sig::Signal) = map(hz2midi, sig)

"We define done and value for Nothing type as a signal trivially."
done(s::Nothing, t, dt) = true
value(s::Nothing, t, dt) = 0.0f0

"""
A simple wrapper struct for cyclic access to vectors.
These don't have the concept of "length" and the index
can range from -inf to +inf (i.e. over all integers).
Note that the circular range is restricted to what
was at creation time. This means you can use views
as well.
"""
struct Circular{T,V<:AbstractArray{T}}
    vec::V
    N::Int
end

function Base.getindex(c::Circular{T,V}, i) where {T,V<:AbstractArray{T}}
    return c.vec[mod1(i, c.N)]
end

function Base.setindex!(c::Circular{T,V}, i, val::T) where {T,V<:AbstractArray{T}}
    c.vec[mod1(i, c.N)] = val
end

"""
    circular(v::AbstractArray{T}) :: Circular{T,AbstractArray{T}}

Makes a circular array that handles the modulo calculations.
"""
circular(v::AbstractArray) = begin
    @assert length(v) > 0
    Circular(v, length(v))
end

# Turns a normal function of time into a signal.
struct SigFun <: Signal
    f::Function
end

done(f::SigFun, t, dt) = false
value(f::SigFun, t, dt) = f.f(t)

"""
    sigfun(f::Function) :: SigFun

Treats a simple function of time (in seconds) as a signal.
"""
sigfun(f) = SigFun(f)

abstract type SignalWithFanout <: Signal end


mutable struct Fanout{S<:Signal} <: SignalWithFanout
    sig::S
    t::Float64
    v::Float32
end


"""
    fanout(s :: Signal)

A signal, once constructed, can only be used by one "consumer" via structure
composition. In some situations, we want a signal to be plugged into multiple
consumers (to make a signal flow DAG). For these occasions, make the signal
fanout by calling `fanout` on it and use the aliasble signal everywhere
you need it instead. Note that `fanout` is an idempotent operator (i.e.
if `s = fanout(sig)`, then `fanout(s) = s`).

!!! note "Constraint"
    It only makes sense to make a single fanout version of a signal.
    Repeated evaluation of a signal is avoided by `fanout` by storing the
    recently computed value for a given time. So it assumes that time
    progresses linearly.

!!! note "Terminology"
    The word "alias" has two meanings - one in the context of signals where
    frequency shifting it can cause wrap around effects in the spectrum due
    to sampling, and in the context of a programming language where a value
    referenced in multiple data structures is said to be "aliased". It is in
    the latter sense that we use the word `fanout` in this case. 
"""
fanout(sig::SignalWithFanout) = sig
fanout(sig::Signal) = Fanout(sig, -1.0, 0.0f0)
done(s::Fanout, t, dt) = done(s.sig, t, dt)
function value(s::Fanout, t, dt)
    if t > s.t
        s.t = t
        s.v = Float32(value(s.sig, t, dt))
    end
    return s.v
end

struct Stereo{L<:SignalWithFanout,R<:SignalWithFanout} <: SignalWithFanout
    left::L
    right::R
    t::Float64
    leftchan::Float32
    rightchan::Float32
    mixed::Float32
end

function done(s::Stereo{L,R}, t, dt) where {L<:SignalWithFanout,R<:SignalWithFanout}
    done(s.left, t, dt) && done(s.right, t, dt)
end

value(s::Stereo{L,R}, t, dt) where {L<:SignalWithFanout,R<:SignalWithFanout} =
    value(s, 0, t, dt)

function value(
    s::Stereo{L,R},
    chan::Int,
    t,
    dt,
) where {L<:SignalWithFanout,R<:SignalWithFanout}
    if t > s.t
        s.t = t
        s.leftchan = value(s.left, t, dt)
        s.rightchan = value(s.right, t, dt)
        s.mixed = sqrt(0.5f0) * (s.leftchan + s.rightchan)
    end
    if c == 0
        s.mixed
    elseif c == -1
        s.leftchan
    elseif c == 1
        s.rightchan
    else
        0.0f0
    end
end


"""
    stereo(left :: SignalWithFanout, right :: SignalWithFanout)
    stereo(left :: Signal, right :: Signal)

Makes a "stereo signal" with the given left and right channel signals.
The stereo signal is itself considered a signal which produces the
mixed output of the left and right channels. However, you can pick out
the left and right channels separately using [`left`](@ref) and [`right`](@ref)
which produce fanout versions of the two components.

!!! note "Aliasability"
    Stereo signals are fanout without calling [`fanout`](@ref) on
    them. The first method assumes that you're passing in fanout signals
    (recommended). The second will make them fanout, before storing a
    reference, so you should subsequently access the individual channels
    **only** via the [`left`](@ref) and [`right`](@ref) methods.

There is a new `value` method that works on stereo signals --

```
value(s::Stereo{L,R}, chan::Int, t, dt)
```

where `chan` can be -1 for left, 0 for mixed middle and 1 for right channels.
Note that calling `value` for different channels at the same time won't
compute multiple times because `Stereo` is fanout directly.

The mixer and modulator operators (+/-/*) treat stereo signals as stereo and
work accordingly. The other operators all (unless noted) are not cognizant of
stereo signals and so you must be explicit with them if you're applying them on
stereo signals.

$(see_also("left,right,mono"))
"""
function stereo(left::SignalWithFanout, right::SignalWithFanout)
    Stereo(left, right, 0.0, 0.0f0, 0.0f0, 0.0f0)
end
function stereo(left::Signal, right::Signal)
    Stereo(fanout(left), fanout(right), 0.0, 0.0f0, 0.0f0, 0.0f0)
end

"""
    left(s :: Stereo)
    left(s :: Signal)

Picks the left channel of a stereo signal. Evaluates to the signal
itself if passed a non-stereo signal (which is considered mono).

$(see_also("right,mono,stereo"))
"""
left(s::Stereo) = s.left
left(s::Signal) = s

"""
    right(s :: Stereo)
    right(s :: Signal)

Picks the right channel of a stereo signal. Evaluates to the signal
itself if passed a non-stereo signal (which is considered mono).

$(see_also("left,mono,stereo"))
"""
right(s::Stereo) = s.right
right(s::Signal) = s

"""
    mono(s :: Stereo)
    mono(s :: Stereo, panval :: Union{Real,Signal})
    mono(s :: Signal)

Converts a stereo signal into a mono signal by mixing the left and right
channels. Evaluates to the signal itself if passed a non-stereo signal (which
is considered mono).

In the version that takes a pan value, passing `1.0f0` will result in only
the right channel being selected. Passing `-1.0f0` will result in only the
left channel being selected and intermediate values will linearly mix the
two channels. You can think of the `panval` argument as where your ear is 
being directed. If you direct it to the right, you hear the right channel,
and if you direct it to the left, you hear the left channel sound.

$(see_also("left,right,stereo"))
"""
mono(s::Stereo) = konst(sqrt(0.5f0)) * (s.left + s.right)
mono(s::Signal) = s
mono(s::Stereo, panval::Real) = mono(s, konst(panval))
mono(s::Stereo, panval::Signal) =
    0.5f0 * ((panval + 1.0f0) * right(s) + (1.0f0 - panval) * left(s))

"""
    pan(s :: Signal, lr :: Real)
    pan(s :: Signal, lr :: Signal)
    pan(s :: Stereo{L,R}, lr :: Real) where {L,R}

Pans a mono signal left or right to produce a stereo signal. `lr` is a signal
that takes values in the range [-1.0,1.0] where negative values indicate left
and positive values indicate right. So giving 0.0 will centre pan the signal
with left and right components receiving equal contributions of the signal.

When applied to a stereo signal, a "left pan" (`lr` in range `[-1,0]`) will
result in the right signal being moved left  and a "right pan" (`lr` in range
`[0,1]`) will result in the left signal being moved right.
"""
function pan(s::Signal, lr::Signal)
    stereo(0.5f0 * (1.0f0 - lr) * s, 0.5f0 * (1.0f0 + lr) * s)
end

function pan(s::Signal, lr::Real)
    pan(s, konst(lr))
end

function pan(s::Stereo, lr::Real)
    pan(s, konst(lr))
end

function pan(s::Stereo, lr::Signal)
    if lr < 0.0
        stereo(s.left - lr * s.right, (1.0f0 + lr) * s.right)
    else
        stereo(s.left * (1.0f0 - lr), s.right + lr * s.left)
    end
end

mutable struct Clip{S<:Signal} <: Signal
    dur::Float64
    const s::S
end

"""
    clip(dur :: Float64, s :: Signal)

Clips the given signal to the given duration. Usually you'd use a "soft"
version of this like a raised cosine or ADSR, but clip could be useful on
its own. The semantics of clip is such that if the signal `s` ends before
the duration is up, it will continue to be called and expect to produce
0.0f0 value until the duration ends.
"""
function clip(dur::Float64, s::Signal)
    Clip(dur, s)
end
function clip(dur::Float64, s::Stereo{L,R}) where {L<:Signal,R<:Signal}
    stereo(clip(dur, s.left), clip(dur, s.right))
end

done(c::Clip, t, dt) = c.dur <= 0.0

value(c::Clip, t, dt) =
    if c.dur <= 0.0
        0.0f0
    else
        c.dur -= dt
        value(c.s, t, dt)
    end

mutable struct KRate{S<:Signal} <: Signal
    const sig::S
    const interval_secs::Float64
    t::Float64
    v::Float32
    dv::Float32
    done::Bool
end

"""
    krate(rate_hz :: Float64, s :: Signal)

Short for "control-rate limited" signal. Useful with signals that vary slowly
but are computationally expensive to do at audio rates. Same idea as in the
original CSound and in many audio synthesis kits.

Produces a signal that will evaluate the given signal at a much lower sampling
interval and linearly interpolate between the values to reduce computation.
The given signal will effectively be "sampled" at the lower given interval.
For example, `krate(100.0, oscil(0.5f0, 10.0f0))` will construct a 10Hz sine
that is sampled only 100 times a second and interpolated, instead of having to 
calculate sines 48000 times a second.
"""
function krate(rate_hz::Real, s::Signal)
    return KRate(s, Float64(1.0/rate_hz), 0.0, 0.0f0, 0.0f0, false)
end

function done(s::KRate{S}, t, dt) where {S<:Signal}
    if t - s.t < s.interval_secs || s.done
        s.done
    else
        s.t = t
        s.done = done(s.sig, t, s.interval_secs)
    end
end

function value(s::KRate{S}, t, dt) where {S<:Signal}
    if t - s.t > s.interval_secs
        v = value(s.sig, t, s.interval_secs)
        s.dv = (v - s.v) / (s.t < dt ? s.interval_secs : (t - s.t))
        s.t = t
        s.v = v
    end
    Float32(s.v + s.dv * (t - s.t))
end
