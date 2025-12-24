
import VST3Host as V3

mutable struct BufIx
    i::Int
    o::Int
    t::Int
end

struct VST3Fx{S<:Signal} <: Signal
    sig::S
    plugin::V3.VST3Plugin
    info::V3.PluginInfo
    paraminfo::Dict{Int,V3.ParameterInfo}
    sparaminfo::Dict{String,V3.ParameterInfo}
    inbuffer::SampleBuf{Float32}
    outbuffer::SampleBuf{Float32}
    ix::BufIx
    last_t::Float64
    last_leftval::Float32
    last_rightval::Float32
end

"""
    vst3fx(sig::Signal, p::V3.VST3Plugin) <: Signal

Construct a short pipeline that processes the given signal through
the given VST3 Plugin. The processing will have one buffer length's
worth of delay.
"""
function vst3fx(sig::Signal, p::V3.VST3Plugin)
    inbuffer = SampleBuffer{Float32}(64,2)
    outbuffer = SampleBuffer{Float32}(64,2)
    pinfo = info(p)
    paraminfo = Dict{Int,V3.ParameterInfo}()
    sparaminfo = Dict{String,V3.ParameterInfo}()
    for i in 1:pinfo.num_parameters
        pinf = parameterinfo(p, i-1)
        paraminfo[pinf.id] = pinf
        sparaminfo[pinf.short_title] = pinf
    end
    VST3Fx(sig, p, pinfo, paraminfo, sparaminfo, inbuffer, outbuffer, BufIx(1,1,0), 0.0, 0.0f0, 0.0f0)
end

function done(m::VST3Fx, t, dt)
    if m.ix.o == 0
        true
    elseif done(m.sig, t, dt)
        deactivate!(m.plugin)
        m.ixout = 0
        true
    else
        false
    end
end

function value(m::VST3Fx, t, dt)
    if t > m.last_t
        ixi = m.ix.i
        ixo = m.ix.o
        v = value(m.sig, t, dt)
        N = length(m.inbuffer)
        if ixi > N
            V3.process!(m.plugin, m.inbuffer, m.outbuffer)
            ixo = 1
            ixi = 2
            m.inbuffer[:,1] .= v
            m.ix.t += N
        else
            m.inbuffer[:,m.ixin] .= v
            ixi += 1
        end

        m.last_leftval = outbuffer[1,ixo]
        m.last_rightval = outbuffer[2,ixo]
        outval = 0.5f0 * (m.last_leftval + m.last_rightval)
        m.ix.o = ixo + 1
        m.ix.i = ixi
        m.last_t = t
        outval
    else
        0.5f0 * (m.last_leftval + m.last_rightval)
    end
end

function Base.setindex!(m::VST3Fx, value::AbstractFloat, name::AbstractString)
    @assert name in m.sparaminfo "No such parameter with id = $id"
    V3.setparameter!(m.plugin, m.sparaminfo[string(name)].id, Float64(value))
end


function Base.setindex!(m::VST3Fx, value::AbstractFloat, id::Integer)
    @assert Int(id) in m.paraminfo "No such parameter with id = $id"
    pinf = m.paraminfo[Int(id)]
    val = max(pinf.min_value, min(pinf.max_value, value))
    V3.setparameter!(m.plugin, Int(id), Float64(val))
end

function Base.getindex(m::VST3Fx, name::AbstractString)
    @assert name in m.sparaminfo "No such parameter with id = $id"
    V3.parameter(m.plugin, m.sparaminfo[string(name)].id)
end

function Base.getindex(m::VST3Fx, id::Integer)
    @assert id in m.paraminfo "No such parameter with id = $id"
    V3.parameter(m.plugin, Int(id))
end

plugin(m::VST3Fx) = m.plugin

time(m::VST3Fx) = m.ix.t / m.info.sample_rate 


function parameterinfo(m::VST3Fx, name::AbstractString)
    @assert name in m.sparaminfo
    m.sparaminfo[string(name)]
end

function parameterinfo(m::VST3Fx, id::Integer) 
    @assert id in m.paraminfo
    m.paraminfo[Int(id)]
end

parameterids(m::VST3Fx) = keys(m.paraminfo)
parameternames(m::VST3Fx) = keys(m.sparaminfo)
parameterid(m::VST3Fx, n::AbstractString) = parameterinfo(m,n).id
numparameters(m::VST3Fx) = m.info.num_parameters

struct VST3Param
    plugin::VST3Plugin
    id::Int
end

parameter(m::VST3Fx, id::Integer) = VST3Param(m.plugin, Int(id))
parameter(m::VST3Fx, name::AbstractString) = parameter(m.plugin, m.sparaminfo[string(name)].id)

function connect(c::Control, p::VST3Param)
    on(c) do v
        setparameter!(p.plugin, p.id, Float64(v))
    end
end

"""
    struct VST3MIDI <: Signal

The VST3MIDI signal is intended to be scheduled on a bus much like
any other signal, and also bound to a port name using 
[`binddevice!`](@ref "Synth.binddevice!") so that MIDI messages
can target this device.
"""
struct VST3MIDI <: Signal
    plugin::V3.VST3Plugin
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

const VST3MidiDest = PluginMidiDest{VST3MIDI}

done(m::VST3MIDI, t, dt) = false

function value(m::VST3MIDI, t, dt)
    if t <= m.last_t
        return 0.5f0 * (m.left_val + m.right_val)
    end

    ixo = m.ix.o
    if ixo <= m.blocksize
        m.left_val = m.outbuffer[1,ixo]
        m.right_val = m.outbuffer[2,ixo]
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

    V3.process!(m.plugin, m.inbuffer, m.outbuffer)
    m.ix.o = 2
    m.ix.i = 1
    m.ix.t += m.blocksize
    sync!(m, t)
    m.last_t = t
    m.left_val = m.outbuffer[1,1]
    m.right_val = m.outbuffer[2,1]
    0.5f0 * (m.left_val + m.right_val)
end

done(m::StereoChan{1,VST3MIDI}, t, dt) = done(m.sig, t, dt)
function value(m::StereoChan{1,VST3MIDI}, t, dt)
    value(m.sig, t, dt)
    m.left_val
end
function value(m::StereoChan{2,VST3MIDI}, t, dt)
    value(m.sig, t, dt)
    m.right_val
end

"""
    vst3midi(pluginpath::AbstractString;samplingrate::Float64=48000.0, blocksize::Int=128)

If you want to target MIDI messages at a VST plugin, load it using `vst3midi`
as a MIDI destination and use it in place of the PortMidiDest.

The VST3MIDI is actually a signal -- i.e. a generator. So if you want to use it
as a generator, you'll have to schedule it on to a bus and set it as a named MIDI port
on the bus. This is made convenient using [`vst3midibus`](@ref "Synth.vst3midibus")
method which makes a new bus and binds the plugin to the port named `:midi` and 
schedules the signal to run on the bus. It returns the bus itself as the result.
"""
function vst3midi(pluginpath::AbstractString;samplingrate::Float64=48000.0, blocksize::Int=128)
    plugin = V3.VST3Plugin(pluginpath, samplingrate, blocksize)
    vst3midi(plugin;samplingrate,blocksize)
end

function vst3midi(plugin::V3.VST3Plugin;samplingrate::Float64=48000.0, blocksize::Int=128)
    inbuffer = SampleBuf{Float32}(samplingrate, blocksize, 2)
    outbuffer = SampleBuf{Float32}(samplingrate, blocksize, 2)
    VST3MIDI(plugin, samplingrate, blocksize, inbuffer, outbuffer, BufIx(1,1,0), Ref((0, 0.0)))
end

"""
    vst3midibus(pluginpath::AbstractString; samplingrate::Float64=48000.0, blocksize::Int=128)
    vst3midibus(plugin::V3.VST3Plugin;samplingrate::Float64=48000.0, blocksize::Int=128)

Creates a new bus, make a `VST3MIDI` signal, binds it as the `:midi` device on the bus
and returns it. The `:midi` port is the default when constructing MIDI messages 
and so this can be convenient.
"""
function vst3midibus(pluginpath::AbstractString; samplingrate::Float64=48000.0, blocksize::Int=128)
    plugin = V3.VST3Plugin(pluginpath, samplingrate, blocksize)
    vst3midibus(plugin; samplingrate, blocksize)
end

function vst3midibus(plugin::V3.VST3Plugin; samplingrate::Float64=48000.0, blocksize::Int=128)
    d = vst3midi(plugin; samplingrate, blocksize)
    vst3midibus(d)
end

function bus(d::VST3MIDI; tempo_bpm::Real=60.0, clk::Signal=clock_bpm(tempo_bpm))
    b = bus(clk)
    binddevice!(b, :midi, d)
    sched(b, d)
    return b
end

function Base.close(d::VST3MidiDest)
    close(d.vst)
end

function Base.close(d::VST3MIDI)
    close(d.plugin)
end

function send(dev::VST3MIDI, m::MIDIMsg, offset::Int=0)
    s = status(m)
    if s == 0x90
        V3.noteon(dev.plugin, channel(m)-1, data1(m), data2(m), offset)
    elseif s == 0x80
        V3.noteoff(dev.plugin, channel(m)-1, data1(m), data2(m), offset)
    elseif s == 0xc0
        V3.programchange(dev.plugin, channel(m)-1, data1(m), offset)
    elseif s == 0xb0
        V3.controlchange(dev.plugin, channel(m)-1, data1(m), data2(m), offset)
    else
        @debug "Dropped unsupported MIDI message" msg=m status=s
    end
end

function sync!(dev::VST3MIDI, t::Float64)
    dev.sync[] = (dev.ix.t, t)
end

function sync!(dest::VST3MidiDest, t::Float64)
    sync!(dest.vst, t)
end

function syncinfo(dev::VST3MIDI)
    (round(Int, dev.sync[][1] * 1000 / dev.samplingrate), dev.sync[][2])
end

function syncinfo(dest::VST3MidiDest)
    syncinfo(dest.vst)
end

function sched(bus::AudioGenBus{Clk}, dest::VST3MidiDest, rt::Real, msg::MIDIMsg) where {Clk<:Signal}
    sched(bus, dest.vst, rt, msg)
end

function sched(bus::AudioGenBus{Clk}, dev::VST3MIDI, rt::Real, msg::MIDIMsg) where {Clk<:Signal}
    s = dev.sync[]
    bt = round(Int, s[1] + dev.samplingrate * (rt - s[2]))
    if dev.ix.t <= bt < dev.ix.t + dev.blocksize
        send(dev, msg, bt - dev.ix.t)
    else
        push!(dev.midi, (bt, msg))
    end
end

function sched(dest::VST3MidiDest, msg::MIDIMsg)
    sched(dest.vst, msg)
end

function sched(dev::VST3MIDI, msg::MIDIMsg)
    send(dev, msg)
end



