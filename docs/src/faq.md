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


