
using PortMidi

struct MIDIOutput
    deviceId :: Int
    name :: String
    interface :: String
    stream :: Ref{Ptr{PortMidi.PortMidiStream}}
    closed :: Ref{Bool}
end

struct MIDIOutputDeviceNotFoundError
    name::String
end

function midioutput(name::AbstractString = "")
    for id in 0:Pm_CountDevices()-1
        info = unsafe_load(Pm_GetDeviceInfo(id))
        devicename = String(unsafe_string(info.name))
        if info.output > 0 && occursin(name, devicename)
            stream = Ref{Ptr{PortMidi.PortMidiStream}}(C_NULL)
            Pm_OpenOutput(stream, id, C_NULL, 0, C_NULL, C_NULL, 0)
            return MIDIOutput(id,
                              devicename,
                              String(unsafe_string(info.interf)),
                              stream,
                              Ref(false))
        end
    end
    @assert false "MIDI output device not found with name '$name'"
    throw(MIDIOutputDeviceNotFoundError(name))
end

function Base.close(d::MIDIOutput)
    Pm_Close(d.stream[])
    d.closed[] = true
end

struct MIDIMsg
    msg :: Int32
end

function send(dev::MIDIOutput, msg::MIDIMsg)
    Pm_WriteShort(dev.stream[], 0, msg.msg)
end

function noteon(chan::Int, note::Int, vel::Int)
    @assert chan >= 0 && chan <= 15 "Invalid MIDI channel $chan"
    @assert note >= 0 && note <= 127 "Invalid MIDI note $note"
    @assert vel >= 0 && vel <= 127 "Invalid MIDI note velocity $vel"
    MIDIMsg(Pm_Message(0x90 + chan, note, vel))
end

function noteon(chan::Int, note::Int, vel::AbstractFloat)
    noteon(chan, note, round(Int, vel * 127))
end

function noteoff(chan::Int, note::Int, vel::Int = 0)
    @assert chan >= 0 && chan <= 15 "Invalid MIDI channel $chan"
    @assert note >= 0 && note <= 127 "Invalid MIDI note $note"
    @assert vel >= 0 && vel <= 127 "Invalid MIDI note velocity $vel"
    MIDIMsg(Pm_Message(0x80 + chan, note, vel))
end

function keypressure(chan::Int, note::Int, pressure::Int)
    @assert chan >= 0 && chan <= 15 "Invalid MIDI channel $chan"
    @assert note >= 0 && note <= 127 "Invalid MIDI note $note"
    @assert pressure >= 0 && pressure <= 127 "Invalid MIDI key pressure $pressure"
    MIDIMsg(Pm_Message(0xa0 + chan, note, pressure))
end
function keypressure(chan::Int, note::Int, pressure::AbstractFloat)
    aftertouch(chan, note, round(Int, pressure * 127))
end

function ctrlchange(chan::Int, control::Int, val::Int)
    @assert chan >= 0 && chan <= 15 "Invalid MIDI channel $chan"
    @assert control >= 0 && control <= 127 "Invalid MIDI note $note"
    @assert val >= 0 && val <= 127 "Invalid MIDI aftertouch pressure $pressure"
    MIDIMsg(Pm_Message(0xb0 + chan, control, val))
end
function ctrlchange(chan::Int, control::Int, val::AbstractFloat)
    ctrlchange(chan, control, round(Int, val * 127))
end

function progchange(chan::Int, pgm::Int)
    @assert chan >= 0 && chan <= 15 "Invalid MIDI channel $chan"
    @assert pgm >= 0 && pgm <= 127 "Invalid MIDI program number $pgm"
    MIDIMsg(Pm_Message(0xc0 + chan, pgm, 0))
end

function aftertouch(chan::Int, note::Int, pressure::Int)
    @assert chan >= 0 && chan <= 15 "Invalid MIDI channel $chan"
    @assert note >= 0 && note <= 127 "Invalid MIDI note $note"
    @assert pressure >= 0 && pressure <= 127 "Invalid MIDI aftertouch pressure $pressure"
    MIDIMsg(Pm_Message(0xd0 + chan, note, pressure))
end
function aftertouch(chan::Int, note::Int, pressure::AbstractFloat)
    aftertouch(chan, note, round(Int, pressure * 127))
end

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


