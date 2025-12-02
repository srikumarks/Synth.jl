# User Interface

Provides quick construction of user interfaces for the
express purpose of controlling audio synthesis within
Jupyter notebooks using `WebIO` and `JSExpr`

Currently UI is available only for [`control`](@ref "Synth.control")
objects. When a cell's value evaluates to a control, it gets displayed
automatically as a slider that you can then twiddle to set its value.
So no additional work for the user there.

## Known problems

1. A control slider may not respond when it is first created within
   a jupyter notebook or lab setup. In such a case, refresh the page
   (Ctrl-R) and re-evaluate the cell that produces the control.
   Subsequent to the reload, any new controls created work fine.
   https://github.com/JuliaGizmos/WebIO.jl/issues/348
