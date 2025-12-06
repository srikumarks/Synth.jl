# OSC

Basic support for Open Sound Control protocol 
is available via the `Synth.OSC` module.

## Design

The basic idea is to model the type of an OSC
message packet as a Julia `Tuple`. The following
types are supported - `Int32`, `UInt32`, `Int64`,
`UInt64`, `Float32`, `Float64`,`String`, `Symbol`,
`Char`, `RGBA{N0f8}`, `OSC.Blob`, `OSC.TimeTag`.

While you can read an `Int32` value as an `Int64`,
while writing they're written with their respective
OSC type tags. Similarly `Symbol` and `String` can
parse each others type tags but when writing they use
their own tags. The unsigned types use the same type
code as the signed ones and so must have the same 
but positive range.

The methods and type names are chosen so that they 
can be used comfortably with the module prefix, so 
`OSC` is not expected to be imported with `using`.

```julia
import Synth.OSC as OSC
msg = OSC.unpack(Tuple{Int32,Float32}, packetBytes)
println("address = ", msg.address)
println("data = ", msg.data) # Should print the tuple.
```

For packing OSC messages, use `pack!` or `pack`.
You can use `NamedTuple` as well with `unpack`.

## Methods

```@docs
pack!
pack
unpack
start
```

## Types

```@docs
Blob
Colour
Color
TimeTag
Message
```

