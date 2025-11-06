# Signal Processes

Here we look at how to code up your own "signal processes". Note that we're not
using the phrase "signal processors" but "signal processes" instead, to suggest
processes that produce a sequence of sample values that vary over time while
possibly updating internal state along the way. So each sample output is
dependent on the previous state.

Some processes may be explicitly dependent on the time value, but we're in
general interested in "time invariant processes" -- i.e. where the evolution of
a process does not depend on when in time it is played. While this seems like
a restriction, it is a very meaningful restriction when it comes to music and
sound processing where "linear time invariant filters" are a common way to
alter the spectrum of sound.

## The delay line

To get an intro to how signals work in `Synth.jl`, it is instructive to look
at how the delay line is designed. It is common in synthesizers to model a delay
line with a fixed number of tap points which may vary over time. By contrast,
in `Synth.jl`, the number of tap points of the delay line is not fixed and the
tap points themselves can vary at audio rate. Here is how you'd use a delay line
in `Synth.jl`.

```julia
s = #... some signal
maxdelay = 1.0 # in seconds
d = delay(s, maxdelay)
tapsig = oscil(0.25, 100.0)
tap1 = tap(d, tapsig + 0.25)
tap2 = tap(d, tapsig + 0.3)
play(tap1 * tap2, 2.0)
```

As you see, you create a [`delay`](@ref), which is itself a pass-through
signal which supports fanout. If you play the delayed signal directly, you
won't notice any delay because that's how it is configured. To tap into the
delay line, you create [`tap`](@ref) signals with a possibly time-varying
tap point. These tap signals can then be used like ordinary signals in
any further compositions.

This works because while the delay-line continuously updates based on the
signal it is getting fed, the tap point's job is to simply look into the
delay line and pick an interpolated value. In doing that, the tap points will
trigger the delay line's processing function, but multiple tap points won't
trigger it multiple times because the delay line supports intrinsic fanout.

## Creating your own signal process

To do this for your own signal, you need to do the following --

1. Create a concrete mutable subtype (say `MySig`) of `Signal` or `SignalWithFanout`.
2. Implement `done(::MySig, t, dt) :: Bool`
3. Implement `value(::MySig, t, dt) :: Float32`.
4. Make an easy to use constructor function for your signal process.

The `done` method is expected to return `true` when the signal process is
considered "finished". The `done` method is generally expected to be called
once per audio frame (like 64 samples), but in some cases may be called more
often. 

The `value` method is expected to compute the next sample value and return it.
It is expected to return a valid value (typically `0.0f0` by convention) even
if the signal is considered "finished" when the value method is called. i.e.,
the design of the implementation of the `value` method should be such that it
is permissible for it to be called for a short while after the signal is
considered "finished". The `value` method will in general update the state
along the way as well.

As an example, here is a four-sample FIR filter.

```julia
using Synth : Signal

mutable struct P4Filter{S <: Signal} <: Signal
    sig :: S
    a0 :: Float32
    a1 :: Float32
    a2 :: Float32
    a3 :: Float32
    x0 :: Float32
    x1 :: Float32
    x2 :: Float32
    x3 :: Float32
end

done(s:: P4Filter, t, dt) = done(s.sig, t, dt)

function value(s::P4Filter{S}, t, dt) where {S <: Signal}
    # Compute the next input sample value.
    # If `s` happens to be a `SignalWithFanout`, then the
    # main body of the value call will only get evaluated
    # once for a given time `t`. Here, `dt` is generally
    # 1/SR. So for the default sample rate, this will be 1/48000.
    v = value(s.sig, t, dt)
    
    # Shift the sample memory by one sample.
    s.x3 = s.x2
    s.x2 = s.x1
    s.x1 = s.x0
    s.x0 = v

    # Compute the output as a linear sum of the input sample values
    # delayed by a few samples.
    s.a0 * s.x0 + s.a1 * s.x1 + s.a2 * s.x2 + s.a3 * s.x3
end

# Make a convenient constructor. Note that any time-evolving state
# in the structure should, if possible, not be exposed as constructor arguments.
# Doing that will ensure that the signal process always starts in a known state.
# In some situations, you might wish to expose the starting state, but they
# are likely exceptions as usually they end up cluttering the interface.
function p4filter(s :: S, a0 :: Real, a1 :: Real, a2 :: Real, a3 :: Real) where {S <: Signal}
    MySig(s, Float32(a0), Float32(a1), Float32(a2), Float32(a3), 0.0f0, 0.0f0, 0.0f0, 0.0f0)
end
```

With that much, you can already use your signal process on an equal footing with all
the other operators in the package.

```julia
s = phasor(300)
sf = p4filter(s, 0.2, 0.3, 0.3, 0.2) # Simple low pass
play(sf, 2.0)
```

If you want to support fanout intrinsically (as opposed to via [`fanout`](@ref)), 
you should use `SignalWithFanout` as the abstract type and ensure that the computation
done within value isn't repeated if asked repeatedly for the same time. You may
assume that time increases monotonically. 

## Performance and the type system

The way we defined `P4Filter` above, we introduced a signal type parameter that
is made concrete at instantiation time. This means we aren't storing a dynamic
signal value when constructing a `P4Filter`, but we know exactly what signal we're
filtering using `P4Filter`. This is excellent for performance because the types
are all know when compiling the `value` call on the `P4Filter` value and can be 
optimized by Julia's just-ahead-of-time type specializing compiler.

Most signals defined in this package are designed similarly, so when you
construct compound signals, you'll often find the types that get printed out
for them to be very lengthy in printed form. i.e. The type of the signal carries
all the information about the structure of the signal flow graph that is 
necessary to optimize the computation of its values. 

Of course, for certain kinds of signals, this isn't possible. In particular,
for the [`bus`](@ref), to which signals that are not known ahead of time
can be scheduled. In this case, the first call to `value(::Bus,t,dt)` will 
do a dynamic dispatch (which is also reasonably fast in Julia), but often that
dispatched function itself will have the entire call tree statically determined
and will likely have a precompiled version available for use, thus speeding
up the compilation.

In all this, it is *possible* that occasionally the compilation step takes a wee
bit of time that may cause an audio stutter, but that has been somewhat rare
in experience and can be mitigated through appropriate precompiled functions.

In the design of the constructor function, we generally make the arguments be
as general as possible and do the necessary type conversions to concrete types
within the function when building up the `struct`. That way, the constructor
functions end up being easy to use without being to strict about `Float32` 
versus `Float64` versus `Int`, for example.

