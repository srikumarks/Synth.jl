using PortMidi

"""
    struct MIDIOutput

Encapsulates basic information about a MIDI output device
and an open stream to which MIDI data can be sent.
"""
struct MIDIOutput
    deviceId :: Int
    name :: String
    interface :: String
    stream :: Ref{Ptr{PortMidi.PortMidiStream}}
    closed :: Ref{Bool}
    sync::Ref{Tuple{Int,Float64}}
end

struct MIDIOutputDeviceNotFoundError
    name::String
end

struct MIDIOutputOpenError
    name::String
end

"""
    midioutput(name::AbstractString = "") :: MIDIOutput

Identifies a MIDI output device with the given name as a substring
and opens a stream to write data to it. You can call [`Base.close`](@ref)
on the resultant `MIDIOutput` to close the stream.

Throws `MIDIOutputDeviceNotFoundError` if such a device does not exist.
"""
function midioutput(name::AbstractString = "")
    for id in 0:Pm_CountDevices()-1
        info = unsafe_load(Pm_GetDeviceInfo(id))
        devicename = String(unsafe_string(info.name))
        if info.output > 0 && occursin(name, devicename)
            stream = Ref{Ptr{PortMidi.PortMidiStream}}(C_NULL)
            if PortMidi.Pt_Started() == 0
                pterr = PortMidi.Pt_Start(1, C_NULL, C_NULL)
                if pterr != PortMidi.ptNoError
                    throw(MIDIOutputOpenError("PortTime start error $pterr"))
                end
            end
            pmerr = PortMidi.Pm_OpenOutput(stream, id, C_NULL, 0, C_NULL, C_NULL, 2)
            if pmerr != PortMidi.pmNoError
                throw(MIDIOutputOpenError(String(unsafe_string(Pm_GetErrorText(pmerr)))))
            end
            return MIDIOutput(id,
                              devicename,
                              String(unsafe_string(info.interf)),
                              stream,
                              Ref(false),
                              Ref((0,0.0)))
        end
    end
    @assert false "MIDI output device not found with name '$name'"
    throw(MIDIOutputDeviceNotFoundError(name))
end

function Base.close(d::MIDIOutput)
    PortMidi.Pm_Close(d.stream[])
    d.closed[] = true
    PortMidi.Pt_Stop()
end

"""
    struct MIDIMsg

Encapsulates a "MIDI short message"
"""
struct MIDIMsg
    msg :: Int32
end

"""
    send(dev::MIDIOutput, msg::MIDIMsg)

Sends the `MIDIMsg` to the device immediately.
"""
function send(dev::MIDIOutput, msg::MIDIMsg)
    @assert !dev.closed[] "MIDI device already closed"
    Pm_WriteShort(dev.stream[], 0, msg.msg)
end

"""
    noteon(chan::Int, note::Int, vel::Int) :: MIDIMsg
    noteon(chan::Int, note::Int, vel::AbstractFloat) :: MIDIMsg

Constructs a NoteOn message. The `AbstractFloat` version will take
a velocity value in the range 0.0 to 1.0 and convert it to the MIDI
range. Note that for sustained instruments like violin, you'll have
to also send a [`Synth.noteoff`](@ref) at an appropriate time or else
the voices will accumulate and result in your system being unable to
keep up.

See also [`Synth.noteoff`](@ref)
"""
function noteon(chan::Int, note::Int, vel::Int)
    @assert chan >= 0 && chan <= 15 "Invalid MIDI channel $chan"
    @assert note >= 0 && note <= 127 "Invalid MIDI note $note"
    @assert vel >= 0 && vel <= 127 "Invalid MIDI note velocity $vel"
    MIDIMsg(Pm_Message(0x90 + chan, note, vel))
end

function noteon(chan::Int, note::Int, vel::AbstractFloat)
    noteon(chan, note, round(Int, vel * 127))
end

"""
    noteoff(chan::Int, note::Int, vel::Int) :: MIDIMsg

Constructs a NoteOff message. See also [`Synth.noteon`](@ref)
"""

function noteoff(chan::Int, note::Int, vel::Int = 0)
    @assert chan >= 0 && chan <= 15 "Invalid MIDI channel $chan"
    @assert note >= 0 && note <= 127 "Invalid MIDI note $note"
    @assert vel >= 0 && vel <= 127 "Invalid MIDI note velocity $vel"
    MIDIMsg(Pm_Message(0x80 + chan, note, vel))
end

"""
    keypressure(chan::Int, note::Int, pressure::Int) :: MIDIMsg
    keypressure(chan::Int, note::Int, pressure::AbstractFloat) :: MIDIMsg

The key pressure control after a note is turned on, before the
note has conceptually ended. See also [`Synth.aftertouch`](@ref).
The `AbstractFloat` version will rescale the pressure value from
the 0.0-1.0 range to the MIDI range of 0-127.
"""
function keypressure(chan::Int, note::Int, pressure::Int)
    @assert chan >= 0 && chan <= 15 "Invalid MIDI channel $chan"
    @assert note >= 0 && note <= 127 "Invalid MIDI note $note"
    @assert pressure >= 0 && pressure <= 127 "Invalid MIDI key pressure $pressure"
    MIDIMsg(Pm_Message(0xa0 + chan, note, pressure))
end
function keypressure(chan::Int, note::Int, pressure::AbstractFloat)
    aftertouch(chan, note, round(Int, pressure * 127))
end

"""
    ctrlchange(chan::Int, control::Int, val::Int) :: MIDIMsg
    ctrlchange(chan::Int, control::Int, val::AbstractFloat) :: MIDIMsg

Changes the value associated with the given control number.
The `AbstractFloat` value is in the range 0.0-1.0 and will be
rescaled to the MIDI range 0-127.
"""
function ctrlchange(chan::Int, control::Int, val::Int)
    @assert chan >= 0 && chan <= 15 "Invalid MIDI channel $chan"
    @assert control >= 0 && control <= 127 "Invalid MIDI note $note"
    @assert val >= 0 && val <= 127 "Invalid MIDI aftertouch pressure $pressure"
    MIDIMsg(Pm_Message(0xb0 + chan, control, val))
end
function ctrlchange(chan::Int, control::Int, val::AbstractFloat)
    ctrlchange(chan, control, round(Int, val * 127))
end

"""
    progchange(chan::Int, pgm::Int)

Send a "program change" for the given channel. See [General
MIDI](https://en.wikipedia.org/wiki/General_MIDI) if you're using a GM
compatible synthesizer.
"""
function progchange(chan::Int, pgm::Int)
    @assert chan >= 0 && chan <= 15 "Invalid MIDI channel $chan"
    @assert pgm >= 0 && pgm <= 127 "Invalid MIDI program number $pgm"
    MIDIMsg(Pm_Message(0xc0 + chan, pgm, 0))
end

"""
    aftertouch(chan::Int, note::Int, pressure::Int) :: MIDIMsg
    aftertouch(chan::Int, note::Int, pressure::AbstractFloat) :: MIDIMsg

The key pressure control after a note has conceptually ended. See also
[`Synth.aftertouch`](@ref). The `AbstractFloat` version will rescale the
pressure value from the 0.0-1.0 range to the MIDI range of 0-127.
"""
function aftertouch(chan::Int, note::Int, pressure::Int)
    @assert chan >= 0 && chan <= 15 "Invalid MIDI channel $chan"
    @assert note >= 0 && note <= 127 "Invalid MIDI note $note"
    @assert pressure >= 0 && pressure <= 127 "Invalid MIDI aftertouch pressure $pressure"
    MIDIMsg(Pm_Message(0xd0 + chan, note, pressure))
end
function aftertouch(chan::Int, note::Int, pressure::AbstractFloat)
    aftertouch(chan, note, round(Int, pressure * 127))
end

"""
    pitchbend(chan::Int, signedPB::Int)
    pitchbend(chan::Int, signedPB::AbstractFloat)

Sends a 14-bit pitch bend value on the given channel. The sensitivity of
this value will depend on the instrument. The `AbstractFloat` version
will rescale (i.e. multiply) by 127 to construct a signed 14-bit value.
So values < 1.0 will correspond to microtonal pitch bends.
"""
function pitchbend(chan::Int, signedPB::Int)
    @assert chan >= 0 && chan <= 15 "Invalid MIDI channel $chan"
    @assert signedPB >= -2^13 && signedPB < 2^13 "Invalid pitch bend value $signedPB"
    pb = signedPB + 2^13
    @assert pb >= 0 && pb < 2^14
    lsb = pb & 127
    msb = (pb >> 7) & 127
    MIDIMsg(Pm_Message(0xe0 + chan, lsb, msb))
end
function pitchbend(chan::Int, signedPB::AbstractFloat)
    pitchbend(chan, round(Int, signedPB * 128))
end

function maptime(dev::MIDIOutput, t_secs::Real)
    (st_ms, st_secs) = dev.sync[]
    round(Int, st_ms + (t_secs - st_secs) * 1000)
end

function sync!(dev::MIDIOutput, t::Float64, force::Bool = false)
    t_ms = PortMidi.Pt_Time()
    (pt_ms, pt_secs) = dev.sync[]
    if force || pt_ms == 0
        dev.sync[] = (t_ms, t)
    end
end

function sched(dev::MIDIOutput, t::Real, msg::MIDIMsg)
    rt = Int32(maptime(dev, t))
    #println("$(round(Int, t * 1000)) \t $(PortMidi.Pt_Time() - rt) \t $rt \t $(msg.msg)")
    Pm_WriteShort(dev.stream[], rt, msg.msg)
end
function sched(t::Real, msg::MIDIMsg)
    sched(current_midi_output[], t, msg)
end


using Base.ScopedValues
const OptMidiOut = Union{Nothing, MIDIOutput}
const current_midi_output :: ScopedValue{OptMidiOut} = ScopedValue{OptMidiOut}(nothing)

