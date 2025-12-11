
"""
    module OSC

export Blob, Colour, Color, TimeTag, Message
export pack!, pack, unpack

For sending and receiving OSC message packets.
Intended to be used with the module prefix like
this -

```julia
import Synth.OSC as OSC
OSC.pack(...)
```
"""
module OSC

export Blob, Colour, Color, TimeTag, Message
export pack!, pack, unpack
export start

using ColorTypes:RGBA
using FixedPointNumbers:N0f8
using Sockets

const Bytes = AbstractVector{UInt8}

"""
`Blob` is a vector of unsigned bytes that can be interpreted
in an application dependent manner.
"""
const Blob = Vector{UInt8}

"""
`Colour` or `Color` is an RGBA colour that makes up 4 bytes.
The parsed colour is scaled to [0.0,1.0] range treating the
colour as a fixed point value.
"""
const Colour = RGBA{N0f8}

"""
Color == Colour
"""
const Color = Colour

"""
An Int64 "timetag" as specified in the OSC spec.
"""
struct TimeTag
    timetag::Int64
end

"""
    struct Message

Encapsulates an OSC message which is a piece of typed data
(`.data` field) associated with an address (`.address` field).
"""
struct Message{T <: Union{Tuple, NamedTuple}}
    address::String
    data::T
end

function wordboundarylength(n::Int)
    m = n % 4
    if m > 0
        return n - m + 4
    else
        return n
    end
end

"""
    osctag(::<SupportedType>)

Gives the OSC type code character that will be used for the given value.
"""
osctag(::Int32) = 'i'
osctag(::UInt32) = 'i'
osctag(::Int64) = 'h'
osctag(::UInt64) = 'h'
osctag(::Float32) = 'f'
osctag(::Float64) = 'd'
osctag(::Symbol) = 'S'
osctag(::String) = 's'
osctag(::Char) = 'c'
osctag(::Nothing) = 'N'
osctag(b::Bool) = if b 'T' else 'F' end
osctag(::Bytes) = 'b'
osctag(::TimeTag) = 't'
osctag(::Colour) = 'r' 

"""
    osctypetag(::Type{<SupportedType>})

Gives the OSC type character corresponding to the given Julia type.
This uses the strict interpretation of the type.
"""
osctypetag(::Type{Int32}) = 'i'
osctypetag(::Type{UInt32}) = 'i'
osctypetag(::Type{Int64}) = 'h'
osctypetag(::Type{UInt64}) = 'h'
osctypetag(::Type{Float32}) = 'f'
osctypetag(::Type{Float64}) = 'd'
osctypetag(::Type{Char}) = 'c'
osctypetag(::Type{Symbol}) = 'S'
osctypetag(::Type{String}) = 's'
osctypetag(::Type{Nothing}) = 'N'
osctypetag(::Type{<:Bytes}) = 'b'
osctypetag(::Type{TimeTag}) = 't'
osctypetag(::Type{Colour}) = 'r'
osctypetag(::Type{Bool}) = 'T' # Note that this is pseudo as the actual value needs to be known.

"""
    osctagtype(::Val{<Char>})

Gives the Julia type corresponding to the given OSC type character
given as a `Val{Char}` - e.g. `osctagtype(Val('i')) == Int32`.
"""
osctagtype(::Val{'i'}) = Int32
osctagtype(::Val{'h'}) = Int64
osctagtype(::Val{'f'}) = Float32
osctagtype(::Val{'d'}) = Float64
osctagtype(::Val{'S'}) = Symbol
osctagtype(::Val{'s'}) = String
osctagtype(::Val{'b'}) = Blob
osctagtype(::Val{'t'}) = TimeTag
osctagtype(::Val{'T'}) = Bool
osctagtype(::Val{'F'}) = Bool
osctagtype(::Val{'N'}) = Nothing
osctagtype(::Val{'r'}) = Colour
osctagtype(::Val{'c'}) = Char

"""
    oscsize(::<SupportedType>)

The number of bytes the given type will take in the OSC packet.
ALso supports getting the type of tuples and named tuples, but
does not include the format string size.
"""
oscsize(::Int32) = 4
oscsize(::UInt32) = 4
oscsize(::Int64) = 8
oscsize(::UInt64) = 8
oscsize(::Float32) = 4
oscsize(::Float64) = 8
oscsize(::Char) = 4
oscsize(::Bool) = 0
oscsize(::Nothing) = 0
oscsize(s::String) = wordboundarylength(length(codeunits(s)) + 1)
oscsize(s::Symbol) = oscsize(String(s))
oscsize(b::Bytes) = 4 + length(b)
oscsize(b::Colour) = 4
oscsize(t::Tuple) = sum(oscsize(v) for v in t)
oscsize(t::NamedTuple) = oscsize(values(t))

"""
    osctagsize(::Union{Tuple,NamedTuple})

Number of bytes taken up by the format code string for the given tuple or named
tuple. Note that format strings start with a ',' character and therefore will
have one more character than the length of the tuple. The encoded format string
is also null-terminated, which adds one more byte.
"""
osctagsize(t::Tuple) = wordboundarylength(2+length(t)) # The tag has an extra leading "," character.
osctagsize(t::NamedTuple) = wordboundarylength(2+length(t))

"""
    pack!(packet::Bytes, address::AbstractString, t::Union{Tuple,NamedTuple})
    pack!(packet::Bytes, msg::Message)

Packs the given tuple of data to be sent to the given address
into the given bytes array and returns a view into the array
containing the actual bytes to be sent. This means that `packet`
must have sufficient size to store all the information.

Use [`packosc`](@ref "Synth.OSC.packosc") if you want the packet
to be allocated automatically.
"""
function pack!(packet::Bytes, address::AbstractString, t::Union{Tuple,NamedTuple})
    @assert !isnothing(match(r"^([/][a-zA-Z0-9]+)+$", address))

    tv = values(t)
    typetag = "," * join(osctag.(tv))
    N = length(packet)
    n = 0
    n += packoscval(view(packet, n+1:N), address)
    n += packoscval(view(packet, n+1:N), typetag)
    for val in t
        n += packoscval(view(packet, n+1:N), val)
    end
    return view(packet, 1:n)
end
pack!(packet::Bytes, msg::Message) = pack!(packet, msg.address, msg.data)

"""
    pack(address::AbstractString, t::Tuple)
    pack(msg::Message)

Convenience function to allocate and return a constructed
OSC packet with the given data. See also [`pack!`](@ref "Synth.OSC.pack!")
for a non-allocating version.
"""
function pack(address::AbstractString, t::Tuple)
    packet = zeros(UInt8, oscsize(address) + osctagsize(t) + oscsize(t))
    pack!(packet, address, t)
    return packet
end
function pack(address::AbstractString, t::NamedTuple)
    tv = values(t)
    packet = zeros(UInt8, oscsize(address) + osctagsize(tv) + oscsize(tv))
    pack!(packet, address, t)
    return packet
end
pack(msg::Message) = pack(msg.address, msg.data)

function packoscval(packet::Bytes, c::Colour)
    @assert length(packet) >= 4
    packet[1] = round(Int, c.r * 255)
    packet[2] = round(Int, c.g * 255)
    packet[3] = round(Int, c.b * 255)
    packet[4] = round(Int, c.alpha * 255)
    return 4
end

function packoscval(packet::Bytes, str::AbstractString)
    bytes = codeunits(str)
    N = length(bytes)
    N2 = wordboundarylength(N+1)
    @assert N2 <= length(packet)
    packet[1:N] = bytes
    packet[N+1:N2] .= UInt8(0x0)
    N2
end

function packoscval(packet::Bytes, val::UInt32)
    @assert length(packet) >= 4
    @assert val <= typemax(Int32)
    packet[1] = (val >> 24) & 0xFF
    packet[2] = (val >> 16) & 0xFF
    packet[3] = (val >> 8) & 0xFF
    packet[4] = val & 0xFF
    return 4
end

function packoscval(packet::Bytes, val::UInt64)
    @assert length(packet) >= 8
    @assert val <= typemax(Int64)
    packet[1] = (val >> 56) & 0xFF
    packet[2] = (val >> 48) & 0xFF
    packet[3] = (val >> 40) & 0xFF
    packet[4] = (val >> 32) & 0xFF
    packet[5] = (val >> 24) & 0xFF
    packet[6] = (val >> 16) & 0xFF
    packet[7] = (val >> 8) & 0xFF
    packet[8] = val & 0xFF
    return 8
end


function packoscval(packet::Bytes, val::Int32)
    @assert length(packet) >= 4
    packet[1] = (val >> 24) & 0xFF
    packet[2] = (val >> 16) & 0xFF
    packet[3] = (val >> 8) & 0xFF
    packet[4] = val & 0xFF
    return 4
end

function packoscval(packet::Bytes, val::Int64)
    @assert length(packet) >= 8
    packet[1] = (val >> 56) & 0xFF
    packet[2] = (val >> 48) & 0xFF
    packet[3] = (val >> 40) & 0xFF
    packet[4] = (val >> 32) & 0xFF
    packet[5] = (val >> 24) & 0xFF
    packet[6] = (val >> 16) & 0xFF
    packet[7] = (val >> 8) & 0xFF
    packet[8] = val & 0xFF
    return 8
end

function packoscval(packet::Bytes, val::Float32)
    packoscval(packet, only(reinterpret(Int32, val)))
end

function packoscval(packet::Bytes, val::Float64)
    packoscval(packet, only(reinterpret(Int64, val)))
end

function packoscval(packet::Bytes, val::Char)
    packoscval(packet, codepoint(val))
end

function packoscval(packet::Bytes, val::Symbol)
    packoscval(packet, string(val))
end

function packoscval(packet::Bytes, val::TimeTag)
    packoscval(packet, val.timetag)
end

function packoscval(packet::Bytes, val::Bytes)
    packoscval(packet, Int32(length(val)))
    packet[5:4+length(val)] = val
    4 + length(val)
end

"""
    unpack(t::Type{Message{T}}, packet::Bytes) :: Message{T}
    unpack(t::Type{T<:Tuple}, packet::Bytes) :: Message{T}
    unpack(t::Type{T<:NamedTuple}, packet::Bytes) :: Message{T}

Give an OSC packet and a `Tuple` or `NamedTuple` type, parses the packet
according to the types of the given tuple and returns an appropriate `Message`.
It is convenient to define aliases for the types of messages you want to 
handle then use these aliases with `unpack` like below --

```julia
const FloatMsg = OSC.Message{Tuple{Float32}}
msg = unpack(FloatMsg, packetBytes)
@assert typeof(msg) <: FloatMsg
"""
@generated function unpack(t::Type{<:Tuple}, packet::Bytes)
    steps = []
    vars = []
    TheTuple = t.parameters[1]
    types = TheTuple.types
    for i in eachindex(types)
        ty = types[i]
        v = Symbol("v$i")
        pprev = Symbol("p$i")
        pnext = Symbol("p$(i+1)")
        push!(steps, :(($v, $pnext) = osctaggedval($ty, Val(typetags[$i]), $pprev)))
        push!(vars, :($v))
    end
    e = quote
        (address, p0) = oscstring(packet)
        (typetags, p1) = osctypetag(p0)
        @assert !isnothing(match(r"^[ifsbhtdcSTFNr]+$", typetags))
        $(steps...)
        Message(address, ($(vars...),))
    end
    println(e)
    return e
end

@generated function unpack(t::Type{<:NamedTuple}, packet::Bytes)
    steps = []
    vars = []
    TheTuple = t.parameters[1]
    types = TheTuple.types
    fieldNames = TheTuple.parameters[1]
    for i in eachindex(types)
        ty = types[i]
        v = Symbol("v$i")
        pprev = Symbol("p$i")
        pnext = Symbol("p$(i+1)")
        fn = fieldNames[i]
        push!(steps, :(($v, $pnext) = osctaggedval($ty, Val(typetags[$i]), $pprev)))
        push!(vars, :($fn = $v))
    end
    quote
        (address, p0) = oscstring(packet)
        (typetags, p1) = osctypetag(p0)
        @assert !isnothing(match(r"^[ifsbhtdcSTFNr]+$", typetags))
        $(steps...)
        Message(address, ($(vars...),))
    end
end

unpack(t::Type{<:Message}, packet::Bytes) = unpack(t.parameters[1], packet)

function oscstring(packet::Bytes)
    N = length(packet)
    for i in eachindex(packet)
        if packet[i] == UInt8(0x0)
            str = String(view(packet, 1:i-1))
            N2 = wordboundarylength(length(codeunits(str))+1)
            while i <= N2
                @assert packet[i] == UInt8(0x0)
                i += 1
            end
            return (str, view(packet, i:N))
        end
    end
    throw(ArgumentError("Invalid OSC string: No null terminator."))
end

function osctypetag(packet::Bytes)
    (s,p) = oscstring(packet)
    @assert s[1] == ','
    (s[2:end], p)
end

function osctaggedval(::Type{Float32}, ::Val{'f'}, packet::Bytes)
    (ntoh(only(reinterpret(Float32, view(packet, 1:4)))), view(packet, 5:length(packet)))
end

function osctaggedval(::Type{Int32}, ::Val{'i'}, packet::Bytes)
    (ntoh(only(reinterpret(Int32, view(packet, 1:4)))), view(packet, 5:length(packet)))
end

function osctaggedval(::Type{UInt32}, ::Val{'i'}, packet::Bytes)
    (ntoh(only(reinterpret(UInt32, view(packet, 1:4)))), view(packet, 5:length(packet)))
end

function osctaggedval(::Type{Int64}, ::Val{'h'}, packet::Bytes)
    (ntoh(only(reinterpret(Int64, view(packet, 1:8)))), view(packet, 9:length(packet)))
end

function osctaggedval(::Type{UInt64}, ::Val{'h'}, packet::Bytes)
    (ntoh(only(reinterpret(UInt64, view(packet, 1:8)))), view(packet, 9:length(packet)))
end

function osctaggedval(::Type{Char}, ::Val{'c'}, packet::Bytes)
    (v,p) = osctaggedval(Int32, Val('i'), packet)
    (Char(v), p)
end

# A 32-bit int value can be read into a 64-bit position but not vice versa.
function osctaggedval(::Type{Int64}, ::Val{'i'}, packet::Bytes)
    (Int64(ntoh(only(reinterpret(Int32, view(packet, 1:4))))), view(packet, 5:length(packet)))
end

function osctaggedval(::Type{UInt64}, ::Val{'i'}, packet::Bytes)
    (Int64(ntoh(only(reinterpret(Int32, view(packet, 1:4))))), view(packet, 5:length(packet)))
end


# Strings and symbols are interchangeable.
function osctaggedval(::Type{String}, ::Union{Val{'s'},Val{'S'}}, packet::Bytes)
    oscstring(packet)
end

function osctaggedval(::Type{Blob}, ::Val{'b'}, packet::Bytes)
    (N, p) = osctaggedval(Val(:i), packet)
    N2 = wordboundarylength(N)
    (p[1:N], view(packet, 5+N2:length(packet)))
end

function osctaggedval(::Type{TimeTag}, ::Val{'t'}, packet::Bytes)
    (TimeTag(ntoh(only(reinterpret(Int64, view(packet, 1:8))))), view(packet, 9:length(packet)))
end

function osctaggedval(::Type{Float64}, ::Val{'d'}, packet::Bytes)
    (ntoh(only(reinterpret(Float64, view(packet, 1:8)))), view(packet, 9:length(packet)))
end

# Float64 can be used to match a Float32 but not vice versa due to 
# potential precision issues.
function osctaggedval(::Type{Float64}, ::Val{'f'}, packet::Bytes)
    (Float64(ntoh(only(reinterpret(Float32, view(packet, 1:4))))), view(packet, 5:length(packet)))
end

function osctaggedval(::Type{Symbol}, ::Union{Val{'s'},Val{'S'}}, packet::Bytes)
    (s,p) = oscstring(packet)
    (Symbol(s), p)
end

function osctaggedval(::Type{Bool}, ::Val{'T'}, packet::Bytes)
    (true, packet)
end

function osctaggedval(::Type{Bool}, ::Val{'F'}, packet::Bytes)
    (false, packet)
end

function osctaggedval(::Type{Nothing}, ::Val{'N'}, packet::Bytes)
    (nothing, packet)
end

function osctaggedval(::Type{Colour}, ::Val{'c'}, packet::Bytes)
    r = packet[1]/255
    g = packet[2]/255
    g = packet[3]/255
    alpha = packet[4]/255
    (Colour(r,g,b,alpha), view(packet,5:length(packet)))
end

abstract type Instr end
struct Stop <: Instr end
struct Route{T<:Type{<:Message},D} <: Instr
    address::String
    msgtype::T
    data::D
end
struct ClearRoute <: Instr
    address::String
end
struct MultiInstr <: Instr
    instrs::Vector{Instr}
end

"""
    start(ipaddr::IPAddr, port::Int) :: Closure

Starts a thread for receiving and processing OSC messages and returns
a control procedure for it. Here is example usage -

```julia
osc = OSC.start(ip"127.0.0.1", 7000)
# Route an OSC float32 message to a Synth.Control
osc(:control, "/multisense/orientation/pitch", c, (x) -> 0.5+x/360)
# Clear a previously setup route.
osc("/multisense/orientation/pitch", nothing)
# General routing of message
b = bus()
play(b)
const Buttons = Message{Tuple{Int32}}
osc("/touch/button", Buttons, b) do address, msg, b
    btn = msg.data[1]
    sched(b, midinote(1, btn, 120, 0.5))
end
# Stop all OSC processing
osc(:stop)
"""
function start(ipaddr::IPAddr, port::Int)
    instr = Channel{Instr}(8)
    function drain(instr, routes)
        while isready(instr)
            msg = take!(instr)
            if !process_instruction(msg, routes)
                @debug "Stopping OSC processing"
                return false
            end
        end
        return true
    end

    Threads.@spawn :interactive begin
        try
            socket = UDPSocket()
            bind(socket, ipaddr, port)
            EmptyType = Message{Tuple{}}
            function donothing(x...)
                @debug "Default OSC route" args=x
            end
            routes = Dict{String,Route}("/default" => Route("/default", EmptyType, nothing, donothing))
            while true
                if !drain(instr, routes)
                    break
                end
                packet = recv(socket)
                if !drain(instr, routes)
                    break
                end
                (address, packet2) = oscstring(packet)
                r = get(routes, address, get(routes, "/default"))
                msg = unpack(r.msgtype, packet)
                try
                    r.fn(r.address, msg, r.data)
                catch e
                    @error "OSC handler error" address=r.address error=(e,catch_backtrace())
                end
            end
        catch e
            @error "OSC thread error" error=(e, catch_backtrace())
        finally
            close(socket)
            close(instr)
            @info "OSC thread done"
        end
    end

    function route(sym::Symbol, address::AbstractString, c, transform=identity)
        @assert sym == :control
        # Here c is anything like Ref, Observable or Synth.Control
        function fwd(address, msg, c)
            c[] = Float32(transform(msg.data[1]))
        end
        # Float64 type supports both 'f' and 'd' type message data.
        put!(instr, Route(string(address), Message{Tuple{Float64}}, c, fwd))
    end

    function route(sym::Symbol)
        @assert sym == :stop
        put!(instr, Stop())
    end

    function route(address::AbstractString, n::Nothing)
        put!(instr, ClearRoute(string(address)))
    end

    function route(fn::Function, address::AbstractString, msgtype::Type{<:Message}, data)
        put!(instr, Route(string(address), msgtype, data, fn))
    end

    return route
end

function process_instruction(::Stop, routes)
    return false
end

function process_instruction(r::Route, routes)
    routes[r.address] = r
end

function process_instruction(r::ClearRoute, routes)
    delete!(routes, r.address)
end

function process_instruction(r::MultiInstr, routes)
    for ri in r.instrs
        if !process_instruction(ri, routes)
            return false
        end
    end
    return true
end

end
