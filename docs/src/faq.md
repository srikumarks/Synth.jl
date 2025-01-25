# FAQ

## How to make a signal processor/generator that has multiple outputs?

The type [`Synth.Signal`](@ref) and its methods `done` and `value` imply that a
signal is a single value at a point in time. So how do we represent
multi-output signal processors using this approach?

If the outputs of a process are all to be computed synchronously in the same
time step, then we can split the computation and access into two separate
signals. While the main processing step computes all the outputs in its `value`
implementation, it can output one chosen value, keeping the others as state in
its structure.

We can have secondary access signals which then pick out any of the many
computed outputs so it can be composed with other parts of the signal flow
graph.

When using this approach, it is important that the main (multi-output) signal
processing module is aliasable - so that a `value` call will do the computation
only once for a given time `t`. 

For an example of this approach, see the implementation of the [`delay`](@ref)
and [`tap`](@ref) signals. The delay line is modeled as a pass-through signal
that keeps some history, and the `tap` is modeled as referencing a point within
the history stored by an underlying delay line. This permits the creation of as
many taps on a single delay line with their own individual controls as needed,
even dynamically if necessary. In other systems, the number of tap points is
usually specified up front for delay lines.

## How to time limit an infinite extent signal like [`sinosc`](@ref)?

Several signals like [`sinosc`](@ref) are in principle infinitely extended
in time. So when they're put to musical applications, various envelopes are
applied to them to give the impression of musical "events" happening (such
as "a note").

A plain way to limit the duration of a `sinosc` is to use [`clip`](@ref) like
this - `clip(0.4, sinosc(0.5f0, 330.0))`. This will sharply delimit the
waveform (whatever it happens to be and not just `sinosc`) to a duration of
(in our example) 0.4 seconds.

A sharp delineation like `clip` is useful in some circumstances as a guard, but
with specific notes. However, it can produce a "click" -- i.e. a sudden change
in signal level -- at the start and end and such clicks are quite unmusical, to
say the least. Therefore you usually apply an "envelope" like a raised cosine
or an [`adsr`](@ref) to the amplitude like this -- `sinosc(adsr(1.0f0, 0.4),
330.0)`. Now, the lifetime of the signal will be determined by the duration of
the ADSR envelope since there are no other facets that determine the duration.

Most signals and signal transformers use their dependent signals to determine
their duration and an "in principle infinite" signal like `sinosc` is one of
them. So you could clip the time extent of the frequency component as well,
like this -- `sinosc(0.5f0, clip(0.4, konst(330.0)))`. This will get rid of
"first order clicks" in the output due to phase continuity, since the phase is
determined by integrating the frequency. However, you'll hear a second order
click since the rate at which the signal is changing suddenly changes and our
ears pick that up.

## How to mix two signals with weights?

Mixing signals is a common operation needed and `Synth` makes it easy by
supporting ordinary mathematical operations `+`, `-` and `*` on the `Signal`
type entities. This means that if you have two signals `a` and `b` that
you want 25%/75% mix of, you can do this -- `s = 0.25f0 * a + 0.75f0 * b`.

If you wish to, you can also use the [`mix`](@ref) and [`modulate`])(@ref)
methods directly. They underpin the arithmetic operators which are
mere convenience wrappers for them.

## How do I play a stereo composition?

The `Synth` package primarily deals with monophonic signals since they're
easy to compose. The composition properties of multi-channel signals are
ambiguous at best. So this package makes stereo signals somewhat second
class citizens, though there is some support. See [`stereo`](@ref)
for info about how to construct and work with stereo signals.

The approach taken in this package is that if there is an obvious way to
compose stereo signals, it is usually supported. If there is some choice
to be made, it is left to the user to effect that choice since sufficient
lower level operations are available.

- [`stereo`](@ref) turns a pair of monophonic signals into a stereo signal.
- [`left`](@ref) and [`right`](@ref) fetch the L and R components of a stereo signal.
  They don't bomb on mono signals and produce those as is for compatibility.
- Operators which support being applied on stereo signals will usually "lift"
  the stereo composition out and push the operation into the components of
  the signal. So it is somewhat unusual to have a stereo signal embedded
  deep into a composition tree that produces a mono signal in the end.
- [`render`](@ref) and [`play`](@ref) support steroo signals directly.

## How do I use microphone input?

TODO: As of this writing, there is no support for audio input. Will
be added soon enough.


