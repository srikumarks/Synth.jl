using Random
import PortAudio

const Time = Float64
const SampleVal = Float32

"""
    abstract type Signal end

A `Signal` represents a process that can be asked for a value for every tick of
a clock. We use it here to represent processes that produce audio and control
signals to participate in a "signal flow graph".

To construct signals and to wire them up in a graph, use the constructor
functions provided rather than the structure constructors directly.

The protocol for a signal is given by two functions with the following
signatures --

- `done(s :: S, t, dt) where {S <: Signal} :: Bool`
- `value(s :: S, t, dt) where {S <: Signal} :: Float32`

The renderer will call `done` to check whether a signal has completed and if
not, will call `value` to retrieve the next value. The contract with each
signal type is that even if `value` is called for a time after the signal is
complete, it should return sample value 0.0f0 or a value appropriate for the
type of signal. This is so that `done` can be called per audio frame rather
than per sample.

Addition, subtraction and multiplication operations are available to combine
signals and numbers.

"""
abstract type Signal end

"Converts a dB value to a scaling factor"
dBscale(v) = 10.0 ^ (v/10.0)

"Converts a MIDI note number into a frequency using the equal tempered tuning."
midi2hz(m) = 440.0 * (2 ^ ((m - 69.0)/12.0))

"Converts a frequency in Hz to its MIDI note number in the equal tempered tuning."
hz2midi(hz) = 69.0 + 12.0*log2(hz/440.0)

"We define done and value for Nothing type as a signal trivially."
done(s :: Nothing, t, dt) = true
value(s :: Nothing, t, dt) = 0.0f0

"""
A simple wrapper struct for cyclic access to vectors.
These don't have the concept of "length" and the index
can range from -inf to +inf (i.e. over all integers).
Note that the circular range is restricted to what
was at creation time. This means you can use views
as well.
"""
struct Circular{T, V <: AbstractArray{T}}
    vec :: V
    N :: Int
end

function Base.getindex(c :: Circular{T,V}, i) where {T, V <: AbstractArray{T}}
    return c.vec[mod1(i, c.N)]
end

function Base.setindex!(c :: Circular{T,V}, i, val :: T) where {T, V <: AbstractArray{T}}
    c.vec[mod1(i, c.N)] = val
end

circular(v :: AbstractArray) = Circular(v, length(v))

# Turns a normal function of time into a signal.
struct Fn <: Signal
    f :: Function
end

done(f :: Fn, t, dt) = false
value(f :: Fn, t, dt) = f.f(t)
fn(f) = Fn(f)

struct Clip{S <: Signal} <: Signal
    dur :: Float64
    s :: S
end

"""
    clip(dur :: Float64, s :: S) where {S <: Signal}

Clips the give signal to the given duration. Usually you'd use a "soft" version
of this like a raised cosine or ADSR, but clip could be useful 
"""
function clip(dur :: Float64, s :: S) where {S <: Signal}
    Clip(s, dur)
end

done(c :: Clip{S}, t, dt) where {S <: Signal} = t > c.dur || done(c.s, t, dt)
value(c :: Clip{S}, t, dt) where {S <: Signal} = if t > c.dur 0.0f0 else value(c.s, t, dt) end

