# Synth.jl

** WORK IN PROGRESS **

**Note**: This package is not finished yet and much work remains to make it
useful. It is made public as an invitation to feedback on the design/API and to
get input on what would be useful to potential users.

`Synth.jl` provides a `Signal` type and operators to construct and compose
audio signals towards making music. This library was started for teaching
purposes and so the code is expected to stay simple with not too many
"optimizations" that make it hard to read and understand. That said, so far,
it's been pleasantly surprising how well Julia is able to compile the code for
realtime usage, perhaps even making it suitable for live coding performances.

The package also includes a (work-in-progress) UI module to help control
realtime audio synthesis processes.

For documentation, see https://srikumarks.github.io/Synth.jl

