abstract type MIDIDest end

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

struct PluginMidiDest{P} <: MIDIDest
    plugin::P
end


