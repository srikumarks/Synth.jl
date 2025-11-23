# Design

In `Synth`, you describe audio signals using signal constructors
and combinators and finally pass them on to a renderer - either one
that renders to a file or one that plays it back in real time.

A "signal" (represented by the abstract type [`Synth.Signal`](@ref))
therefore identifies the computation that produces the samples
with the mathematical notion of a time-varying value that's sampled
at a regular rate, known as the "sampling rate". 

!!! note "Sampling rate"
    This is the number of audio samples per second. CDs uses 44.1KHz as the
    sampling rate. This package chooses 48KHz as the sampling rate by default
    wherever necessary.

A "signal" in this package is defined by its support for two methods --

```julia
done(s :: S, t, dt) :: Bool where {S <: Signal}
value(S :: S, t, dt) :: Float32 where {S <: Signal}
```

The `done` method indicates whether a signal is finished at a given time or not.
It is expected to obey the following constraints --

1. `done(s, t, dt) == true` implies `done(s, t', dt) == true` for all ``t' > t``.
2. `done(s, t, dt) == false` implies `done(s, t', dt) == false` for all ``t' < t``.

The `value` method computes the value of the signal ``s`` at the given time
``t``. It too has a constraint, albeit a soft one -- `value(s, t, dt) == 0.0f0`
for all ``t`` for which `done(s, t, dt) == true`. In some cases, `value` may
choose to return a constant other than `0.0f0`, but the idea is that the value
calculation must not assume that only values of ``t`` for which `done` will
produce `false` will be supplied. This soft constraint is so that `done` does
not need to be called per sample by any render. It only needs to be called per
"frame" - which is like 64 samples or 128 samples depending on the buffer
length.

Additionally, `value` is expected to be called with a monotonic `t` argument in
time steps of `dt` -- i.e. `t` can either be the same as that of the previous
call, or can advance by the given `dt`. Most signals do not need to account for
repeated calls with same `t` since that can be handled by wrapping a concrete
type as an [`fanout`](@ref). 

The `value` method on a signal computes a single sample value. Having a
function call to compute a single sample sounds like a significant overhead,
but the way the types are organized and how Julia does a deep type specializing
optimizing compilation pass on the entire call graph of a function implies that
most of these calls get optimized away. When you compose signals and look at
their type signature, you'll see how all the composition information is
reflected in the resultant signal type and this is the information that's
needed to optimize the `value` call on the composite signal. The `value` method
implementation on a type also provides a boundary at which to perform such
optimizations. Mostly, you as a user don't need to think about these
optimizations.

!!! note "Compilation cost"
    What this package relies on is Julia's type specializing just-ahead-of-time
    compiler. This compilation pass can take a noticeable amount of time for
    modest sized functions. This means that a freshly composed signal that
    Julia has not seen at all will likely cause a stutter the first time it is
    run. For this reason, it is good to mark all the combinations under a test
    function that gets called once before you do any realtime performance. This
    compilation delay will not make a difference if you're just rendering to a
    file though.

