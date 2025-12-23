using PortMidi
import VST3Host
abstract type MIDIDest end

"""
    struct PortMidiDest

Encapsulates basic information about a MIDI output device
and an open stream to which MIDI data can be sent.
"""
struct PortMidiDest <: MIDIDest
    deviceId::Int
    name::String
    interface::String
    stream::Ref{Ptr{PortMidi.PortMidiStream}}
    closed::Ref{Bool}
    sync::Ref{Tuple{Int,Float64}}
    outputDelay_ms::Int
end

struct PortMidiDestDeviceNotFoundError
    name::String
end

struct PortMidiDestOpenError
    name::String
end

"""
    const MidiDeviceInfo = @NamedTuple{id::Int,name::String,interf::String,input::Bool,output::Bool}

Represents info about a particular MIDI device.
"""
const MidiDeviceInfo =
    @NamedTuple{id::Int, name::String, interf::String, input::Bool, output::Bool}

"""
    mididevices() :: Vector{MidiDeviceInfo}

Fetches the list of available MIDI devices as a pair of 
"""
function mididevices()::Vector{MidiDeviceInfo}
    devs::Vector{MidiDeviceInfo} = []
    for id = 0:(Pm_CountDevices()-1)
        info = unsafe_load(Pm_GetDeviceInfo(id))
        name = String(unsafe_string(info.name))
        interf = String(unsafe_string(info.interf))
        input = info.input > 0
        output = info.output > 0
        push!(devs, (; id, name, interf, input, output))
    end
    devs
end

"""
    midioutput(name::AbstractString = "") :: PortMidiDest

Identifies a MIDI output device with the given name as a substring
and opens a stream to write data to it. You can call `Base.close`
on the resultant `PortMidiDest` to close the stream.

Throws `PortMidiDestDeviceNotFoundError` if such a device does not exist.
"""
function midioutput(name::AbstractString = ""; outputDelay_ms::Int = 0)
    for dev in mididevices()
        @info "MIDI devices" devices=dev
        if dev.output && occursin(name, dev.name)
            stream = Ref{Ptr{PortMidi.PortMidiStream}}(C_NULL)
            if PortMidi.Pt_Started() == 0
                pterr = PortMidi.Pt_Start(1, C_NULL, C_NULL)
                sleep(0.01)
                PortMidi.Pt_Time()
                if pterr != PortMidi.ptNoError
                    throw(PortMidiDestOpenError("PortTime start error $pterr"))
                end
            end
            pmerr = PortMidi.Pm_OpenOutput(stream, dev.id, C_NULL, 0, C_NULL, C_NULL, 1)
            if pmerr != PortMidi.pmNoError
                throw(PortMidiDestOpenError(String(unsafe_string(Pm_GetErrorText(pmerr)))))
            end
            return PortMidiDest(
                dev.id,
                dev.name,
                dev.interf,
                stream,
                Ref(false),
                Ref((0, 0.0)),
                outputDelay_ms,
            )
        end
    end
    @assert false "MIDI output device not found with name '$name'"
    throw(PortMidiDestDeviceNotFoundError(name))
end

function Base.close(d::PortMidiDest)
    PortMidi.Pm_Close(d.stream[])
    d.closed[] = true
    PortMidi.Pt_Stop()
end

"""
    struct MIDIMsg

Encapsulates a "MIDI short message"
"""
struct MIDIMsg
    port::Symbol
    msg::Int32
end

port(m::MIDIMsg) = m.port
status(m::MIDIMsg) = (msg >> 16) & 0xF0
channel(m::MIDIMsg) = ((msg >> 16) & 0x0F) + 1
data1(m::MIDIMsg) = (msg >> 8) & 0xFF
data2(m::MIDIMsg) = (msg & 0xFF)


"""
    midinop :: MIDIMsg

A constant `MIDIMsg` that represents a "no-op" or
"nothing to be sent out".
"""
const midinop = MIDIMsg(Int32(0), :any)

"""
    ismidinop(m::MIDIMsg) :: Bool

Returns true if the given message is a [`midinop`](@ref "Synth.midinop").
"""
ismidinop(m::MIDIMsg) = m.msg == 0

"""
    send(dev::MIDIDest, msg::MIDIMsg)

Sends the `MIDIMsg` to the device immediately.
"""
function send(dev::PortMidiDest, msg::MIDIMsg)
    @assert !dev.closed[] "MIDI device already closed"
    Pm_WriteShort(dev.stream[], 0, msg.msg)
end

"""
    noteon(chan::Int, note::Int, vel::Int; port=:midi) :: MIDIMsg
    noteon(chan::Int, note::Int, vel::AbstractFloat; port=:midi) :: MIDIMsg

Constructs a NoteOn message. The `AbstractFloat` version will take
a velocity value in the range 0.0 to 1.0 and convert it to the MIDI
range. Note that for sustained instruments like violin, you'll have
to also send a [`noteoff`](@ref "Synth.noteoff") at an appropriate time or else
the voices will accumulate and result in your system being unable to
keep up.

See also [`noteoff`](@ref "Synth.noteoff")
"""
function noteon(chan::Int, note::Int, vel::Int; port=:midi)
    @assert chan >= 1 && chan <= 16 "Invalid MIDI channel $chan"
    @assert note >= 0 && note <= 127 "Invalid MIDI note $note"
    @assert vel >= 0 && vel <= 127 "Invalid MIDI note velocity $vel"
    MIDIMsg(Pm_Message(0x90 + (chan-1), note, vel), port)
end

function noteon(chan::Int, note::Int, vel::AbstractFloat; port=:midi)
    noteon(chan, note, round(Int, vel * 127); port)
end

"""
    noteoff(chan::Int, note::Int, vel::Int = 0; port=:midi) :: MIDIMsg

Constructs a NoteOff message. See also [`noteon`](@ref "Synth.noteon")
"""
function noteoff(chan::Int, note::Int, vel::Int = 0; port=:midi)
    @assert 1 <= chan <= 16 "Invalid MIDI channel $chan"
    @assert 0 <= note <= 127 "Invalid MIDI note $note"
    @assert 0 <= vel <= 127 "Invalid MIDI note velocity $vel"
    MIDIMsg(Pm_Message(0x80 + (chan-1), note, vel), port)
end

"""
    keypressure(chan::Int, note::Int, pressure::Int; port=:midi) :: MIDIMsg
    keypressure(chan::Int, note::Int, pressure::AbstractFloat; port=:midi) :: MIDIMsg

The key pressure control after a note is turned on, before the
note has conceptually ended. See also [`aftertouch`](@ref "Synth.aftertouch").
The `AbstractFloat` version will rescale the pressure value from
the 0.0-1.0 range to the MIDI range of 0-127.
"""
function keypressure(chan::Int, note::Int, pressure::Int; port=:midi)
    @assert 1 <= chan <= 16 "Invalid MIDI channel $chan"
    @assert 0 <= note <= 127 "Invalid MIDI note $note"
    @assert 0 <= pressure <= 127 "Invalid MIDI key pressure $pressure"
    MIDIMsg(Pm_Message(0xa0 + (chan-1), note, pressure); port)
end
function keypressure(chan::Int, note::Int, pressure::AbstractFloat; port=:midi)
    aftertouch(chan, note, round(Int, pressure * 127); port)
end

"""
    ctrlchange(chan::Int, control::Int, val::Intl; port=:midi) :: MIDIMsg
    ctrlchange(chan::Int, control::Int, val::AbstractFloat; port=:midi) :: MIDIMsg

Changes the value associated with the given control number.
The `AbstractFloat` value is in the range 0.0-1.0 and will be
rescaled to the MIDI range 0-127.
"""
function ctrlchange(chan::Int, control::Int, val::Int; port=:midi)
    @assert 1 <= chan <= 16 "Invalid MIDI channel $chan"
    @assert 0 <= control <= 127 "Invalid MIDI note $note"
    @assert 0 <= val <= 127 "Invalid MIDI aftertouch pressure $pressure"
    MIDIMsg(Pm_Message(0xb0 + (chan-1), control, val), port)
end
function ctrlchange(chan::Int, control::Int, val::AbstractFloat; port=:midi)
    ctrlchange(chan, control, round(Int, val * 127); port)
end

"""
    progchange(chan::Int, pgm::Int; port=:midi)

Send a "program change" for the given channel. See [General
MIDI](https://en.wikipedia.org/wiki/General_MIDI) if you're using a GM
compatible synthesizer.
"""
function progchange(chan::Int, pgm::Int; port=:midi)
    @assert chan >= 1 && chan <= 16 "Invalid MIDI channel $chan"
    @assert pgm >= 0 && pgm <= 127 "Invalid MIDI program number $pgm"
    MIDIMsg(Pm_Message(0xc0 + (chan-1), pgm, 0), port)
end

"""
    aftertouch(chan::Int, note::Int, pressure::Int; port=:midi) :: MIDIMsg
    aftertouch(chan::Int, note::Int, pressure::AbstractFloat; port=:midi) :: MIDIMsg

The key pressure control after a note has conceptually ended. See also
[`aftertouch`](@ref "Synth.aftertouch"). The `AbstractFloat` version will rescale the
pressure value from the 0.0-1.0 range to the MIDI range of 0-127.
"""
function aftertouch(chan::Int, note::Int, pressure::Int; port=:midi)
    @assert 1 <= chan <= 16 "Invalid MIDI channel $chan"
    @assert 0 <= note <= 127 "Invalid MIDI note $note"
    @assert 0 <= pressure <= 127 "Invalid MIDI aftertouch pressure $pressure"
    MIDIMsg(Pm_Message(0xd0 + (chan-1), note, pressure), port)
end
function aftertouch(chan::Int, note::Int, pressure::AbstractFloat; port=:midi)
    aftertouch(chan, note, round(Int, pressure * 127); port)
end

"""
    pitchbend(chan::Int, signedPB::Int; port=:midi)
    pitchbend(chan::Int, signedPB::AbstractFloat; port=:midi)

Sends a 14-bit pitch bend value on the given channel. The sensitivity of
this value will depend on the instrument. The `AbstractFloat` version
will rescale (i.e. multiply) by 127 to construct a signed 14-bit value.
So values < 1.0 will correspond to microtonal pitch bends.
"""
function pitchbend(chan::Int, signedPB::Int; port=:midi)
    @assert 1 <= chan <= 16 "Invalid MIDI channel $chan"
    @assert -2^13 <= signedPB < 2^13 "Invalid pitch bend value $signedPB"
    pb = signedPB + 2^13
    @assert pb >= 0 && pb < 2^14
    lsb = pb & 127
    msb = (pb >> 7) & 127
    MIDIMsg(Pm_Message(0xe0 + (chan-1), lsb, msb), port)
end
function pitchbend(chan::Int, signedPB::AbstractFloat; port=:midi)
    pitchbend(chan, round(Int, signedPB * 128); port)
end

syncinfo(dev::PortMidiDest) = dev.sync[]

function maptime(dev, t_secs::Real)
    (st_ms, st_secs) = syncinfo(dev)
    round(Int, st_ms + (t_secs - st_secs) * 1000)
end

function sync!(dev::PortMidiDest, t::Float64)
    t_ms = PortMidi.Pt_Time()
    (pt_ms, pt_secs) = syncinfo(dev)
    dt_ms = maptime(dev, t) - t_ms
    if abs(dt_ms) > 1
        dev.sync[] = (t_ms, t)
    end
end

function sync!(dev::Nothing, t::Float64)
    # Do nothing.
end

"""
    sched(dev::MIDIDest, t::Real, msg::MIDIMsg)
    sched(t::Real, msg::MIDIMsg)
    sched(dev::MIDIDest, msg::MIDIMsg)
    sched(msg::MIDIMsg)

The first two schedule a MIDI message to be sent at the designated
time. The last two will send it out immediately. If the MIDI output
device is omitted, then the current midi output device active will
be used.
"""
sched(b::Bus, dev::PortMidiDest, t::Real, msg::MIDIMsg) = sched(dev, t, msg)
function sched(dev::PortMidiDest, t::Real, msg::MIDIMsg)
    rt = Int32(maptime(dev, t))
    #println("$(round(Int, t * 1000)) \t $(PortMidi.Pt_Time() - rt) \t $rt \t $(msg.msg)")
    pmt = PortMidi.Pt_Time()
    Pm_WriteShort(dev.stream[], rt + dev.outputDelay_ms, msg.msg)
end
function sched(dev::PortMidiDest, msg::MIDIMsg)
    Pm_WriteShort(dev.stream[], 0, msg.msg)
end

function sched(rt::Real, msg::MIDIMsg)
    dev = current_midi_output[]
    sched(dev, rt + 0.001 * dev.outputDelay_ms, msg)
end

function sched(msg::MIDIMsg)
    dev = current_midi_output[]
    sched(dev, msg)
end


using Base.ScopedValues
const OptMidiOut = Union{Nothing,MIDIDest}
const current_midi_output::ScopedValue{OptMidiOut} = ScopedValue{OptMidiOut}(nothing)
