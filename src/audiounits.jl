# NOTE: THIS DOESN"T QUITE WORK YET AND WILL NEED TO BE MIGRATED TO AUv3 API.

import AudioUnits as AU
using SampledSignals

mutable struct BufIx
    i::Int
    o::Int
    t::Int
end

struct AUFx{S<:Signal} <: Signal
    sig::S
    plugin::AU.AudioUnit
    processor::AU.AudioProcessor
    paraminfo::Dict{UInt32,AU.AudioUnitParameterInfo}
    sparaminfo::Dict{String,AU.AudioUnitParameterInfo}
    inbuffer::SampleBuf{Float32}
    outbuffer::SampleBuf{Float32}
    ix::BufIx
    last_t::Float64
    last_leftval::Float32
    last_rightval::Float32
    samplerate::Float64
end

"""
    aufx(sig::Signal, p::AU.AudioUnit) <: Signal

Construct a short pipeline that processes the given signal through
the given AudioUnit. The processing will have one buffer length's
worth of delay.
"""
function aufx(sig::Signal, p::AU.AudioUnit; samplerate::Float64=48000.0)
    @assert AU.issupported()
    inbuffer = SampleBuf(zeros(Float32, 2, 64), samplerate)
    outbuffer = SampleBuf(zeros(Float32, 2, 64), samplerate)
    processor = AU.AudioProcessor(p, max_channels=2, max_frames=64, sample_rate=samplerate)
    paraminfo = Dict{UInt32,AU.AudioUnitParameterInfo}()
    sparaminfo = Dict{String,AU.AudioUnitParameterInfo}()
    params = AU.parameters(p)
    for param in params
        paraminfo[param.id] = param.info
        sparaminfo[param.info.name] = param.info
    end
    AUFx(sig, p, processor, paraminfo, sparaminfo, inbuffer, outbuffer, BufIx(1,1,0), 0.0, 0.0f0, 0.0f0, samplerate)
end

function done(m::AUFx, t, dt)
    if m.ix.o == 0
        true
    elseif done(m.sig, t, dt)
        AU.dispose(m.processor)
        AU.uninitialize(m.plugin)
        m.ix.o = 0
        true
    else
        false
    end
end

function value(m::AUFx, t, dt)
    if t > m.last_t
        ixi = m.ix.i
        ixo = m.ix.o
        v = value(m.sig, t, dt)
        N = size(m.inbuffer, 2)
        if ixi > N
            # Process the input buffer using AudioProcessor
            AU.process!(m.processor, m.inbuffer, m.outbuffer)
            ixo = 1
            ixi = 2
            m.inbuffer[:, 1] .= v
            m.ix.t += N
        else
            m.inbuffer[:, ixi] .= v
            ixi += 1
        end

        m.last_leftval = m.outbuffer[1, ixo]
        m.last_rightval = m.outbuffer[2, ixo]
        outval = 0.5f0 * (m.last_leftval + m.last_rightval)
        m.ix.o = ixo + 1
        m.ix.i = ixi
        m.last_t = t
        outval
    else
        0.5f0 * (m.last_leftval + m.last_rightval)
    end
end

function Base.setindex!(m::AUFx, value::AbstractFloat, name::AbstractString)
    @assert name in m.sparaminfo "No such parameter with name = $name"
    param_id = m.sparaminfo[name].id
    AU.setparametervalue!(m.plugin, param_id, Float64(value))
end


function Base.setindex!(m::AUFx, value::AbstractFloat, id::Integer)
    @assert UInt32(id) in keys(m.paraminfo) "No such parameter with id = $id"
    pinf = m.paraminfo[UInt32(id)]
    val = max(pinf.min_value, min(pinf.max_value, Float32(value)))
    AU.setparametervalue!(m.plugin, UInt32(id), Float64(val))
end

function Base.getindex(m::AUFx, name::AbstractString)
    @assert name in m.sparaminfo "No such parameter with name = $name"
    param_id = m.sparaminfo[name].id
    AU.parametervalue(m.plugin, param_id)
end

function Base.getindex(m::AUFx, id::Integer)
    @assert UInt32(id) in keys(m.paraminfo) "No such parameter with id = $id"
    AU.parametervalue(m.plugin, UInt32(id))
end

plugin(m::AUFx) = m.plugin

time(m::AUFx) = m.ix.t / m.samplerate 


function parameterinfo(m::AUFx, name::AbstractString)
    @assert name in m.sparaminfo "No such parameter with name = $name"
    m.sparaminfo[string(name)]
end

function parameterinfo(m::AUFx, id::Integer)
    @assert UInt32(id) in keys(m.paraminfo) "No such parameter with id = $id"
    m.paraminfo[UInt32(id)]
end

parameterids(m::AUFx) = keys(m.paraminfo)
parameternames(m::AUFx) = keys(m.sparaminfo)
parameterid(m::AUFx, n::AbstractString) = parameterinfo(m,n).id
numparameters(m::AUFx) = length(m.paraminfo)

struct AUParam
    plugin::AU.AudioUnit
    id::UInt32
end

parameter(m::AUFx, id::Integer) = AUParam(m.plugin, UInt32(id))
parameter(m::AUFx, name::AbstractString) = AUParam(m.plugin, m.sparaminfo[string(name)].id)

function connect(c::Control, p::AUParam)
    on(c) do v
        AU.setparametervalue!(p.plugin, p.id, Float64(v))
    end
end

"""
    struct AuMIDI <: Signal

The AuMIDI signal is intended to be scheduled on a bus much like
any other signal, and also bound to a port name using
[`binddevice!`](@ref "Synth.binddevice!") so that MIDI messages
can target this device.
"""
struct AuMIDI <: Signal
    plugin::AU.AudioUnit
    processor::AU.AudioProcessor
    samplingrate::Float64
    blocksize::Int32
    midi::Vector{Tuple{Int,MIDIMsg}}
    inbuffer::SampleBuf{Float32}
    outbuffer::SampleBuf{Float32}
    ix::BufIx
    sync::Ref{Tuple{Int,Float64}}
    last_t::Float64
    left_val::Float32
    right_val::Float32
end

const AuMidiDest = PluginMidiDest{AuMIDI}

done(m::AuMIDI, t, dt) = false

function value(m::AuMIDI, t, dt)
    if t <= m.last_t
        return 0.5f0 * (m.left_val + m.right_val)
    end

    ixo = m.ix.o
    if ixo <= m.blocksize
        m.left_val = m.outbuffer[1, ixo]
        m.right_val = m.outbuffer[2, ixo]
        v = 0.5f0 * (m.left_val + m.right_val)
        m.ix.o = ixo + 1
        return v
    end

    ixt = m.ix.t
    ixtend = ixt + m.blocksize
    for (mt, msg) in m.midi
        if ixt <= mt < ixtend
            send(m, msg, mt - ixt)
        end
    end
    filter!(e -> e[1] >= ixtend, m.midi)

    # Process the input buffer through the AudioUnit using AudioProcessor
    AU.process!(m.processor, m.inbuffer, m.outbuffer)
    m.ix.o = 2
    m.ix.i = 1
    m.ix.t += m.blocksize
    sync!(m, t)
    m.left_val = m.outbuffer[1, 1]
    m.right_val = m.outbuffer[2, 1]
    m.last_t = t
    0.5f0 * (m.left_val + m.right_val)
end

"""
    aumidi(auname::AbstractString;samplingrate::Float64=48000.0, blocksize::Int=128)

If you want to target MIDI messages at an AudioUnit, load it using `aumidi`
as a MIDI destination and use it in place of the PortMidiDest.

The AuMIDI is actually a signal -- i.e. a generator. So if you want to use it
as a generator, you'll have to schedule it on to a bus and set it as a named MIDI port
on the bus. This is made convenient using [`aumidibus`](@ref "Synth.aumidibus")
method which makes a new bus and binds the plugin to the port named `:midi` and
schedules the signal to run on the bus. It returns the bus itself as the result.
"""
function aumidi(auname::AbstractString;samplingrate::Float64=48000.0, blocksize::Int=128)
    @assert AU.issupported()
    plugin = AU.load(auname)
    AU.initialize(plugin)
    aumidi(plugin;samplingrate,blocksize)
end

function aumidi(plugin::AU.AudioUnit;samplingrate::Float64=48000.0, blocksize::Int=128)
    @assert AU.issupported()
    inbuffer = SampleBuf(zeros(Float32, 2, blocksize), samplingrate)
    outbuffer = SampleBuf(zeros(Float32, 2, blocksize), samplingrate)
    processor = AU.AudioProcessor(plugin, max_channels=2, max_frames=blocksize, sample_rate=samplingrate)
    AuMIDI(plugin, processor, samplingrate, Int32(blocksize), Vector{Tuple{Int,MIDIMsg}}(), inbuffer, outbuffer, BufIx(1,1,0), Ref((0, 0.0)), 0.0, 0.0f0, 0.0f0)
end

"""
    aumidibus(auname::AbstractString; samplingrate::Float64=48000.0, blocksize::Int=128)
    aumidibus(plugin::AU.AudioUnit;samplingrate::Float64=48000.0, blocksize::Int=128)

Creates a new bus, make a `AuMIDI` signal, binds it as the `:midi` device on the bus
and returns it. The `:midi` port is the default when constructing MIDI messages
and so this can be convenient.
"""
function aumidibus(auname::AbstractString; samplingrate::Float64=48000.0, blocksize::Int=128)
    @assert AU.issupported()
    plugin = AU.load(auname)
    AU.initialize(plugin)
    aumidibus(plugin; samplingrate, blocksize)
end

function aumidibus(plugin::AU.AudioUnit; samplingrate::Float64=48000.0, blocksize::Int=128)
    d = aumidi(plugin; samplingrate, blocksize)
    bus(d)
end

function bus(d::AuMIDI; tempo_bpm::Real=60.0, clk::Signal=clock_bpm(tempo_bpm))
    b = bus(clk)
    binddevice!(b, :midi, d)
    sched(b, d)
    return b
end

done(m::StereoChan{1,AuMIDI}, t, dt) = done(m.sig, t, dt)
function value(m::StereoChan{1,AuMIDI}, t, dt)
    value(m.sig, t, dt)
    m.sig.left_val
end
function value(m::StereoChan{2,AuMIDI}, t, dt)
    value(m.sig, t, dt)
    m.sig.right_val
end

function Base.close(d::AuMidiDest)
    close(d.vst)
end

function Base.close(d::AuMIDI)
    AU.dispose(d.processor)
    AU.uninitialize(d.plugin)
    AU.dispose(d.plugin)
end

function send(dev::AuMIDI, m::MIDIMsg, offset::Int=0)
    s = status(m)
    if s == 0x90
        AU.noteon(dev.plugin, channel(m)-1, data1(m), data2(m), offset=UInt32(offset))
    elseif s == 0x80
        AU.noteoff(dev.plugin, channel(m)-1, data1(m), offset=UInt32(offset))
    elseif s == 0xc0
        AU.programchange(dev.plugin, channel(m)-1, data1(m), offset=UInt32(offset))
    elseif s == 0xb0
        AU.controlchange(dev.plugin, channel(m)-1, data1(m), data2(m), offset=UInt32(offset))
    else
        @debug "Dropped unsupported MIDI message" msg=m status=s
    end
end

function sync!(dev::AuMIDI, t::Float64)
    dev.sync[] = (dev.ix.t, t)
end

function sync!(dest::AuMidiDest, t::Float64)
    sync!(dest.vst, t)
end

function syncinfo(dev::AuMIDI)
    (round(Int, dev.sync[][1] * 1000 / dev.samplingrate), dev.sync[][2])
end

function syncinfo(dest::AuMidiDest)
    syncinfo(dest.vst)
end

function sched(bus::AudioGenBus{Clk}, dest::AuMidiDest, rt::Real, msg::MIDIMsg) where {Clk<:Signal}
    sched(bus, dest.vst, rt, msg)
end

function sched(bus::AudioGenBus{Clk}, dev::AuMIDI, rt::Real, msg::MIDIMsg) where {Clk<:Signal}
    s = dev.sync[]
    bt = round(Int, s[1] + dev.samplingrate * (rt - s[2]))
    if dev.ix.t <= bt < dev.ix.t + dev.blocksize
        send(dev, msg, bt - dev.ix.t)
    else
        push!(dev.midi, (bt, msg))
    end
end

function sched(dest::AuMidiDest, msg::MIDIMsg)
    sched(dest.vst, msg)
end

function sched(dev::AuMIDI, msg::MIDIMsg)
    send(dev, msg)
end



