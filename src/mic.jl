import PortAudio
using SampledSignals: SampleBuf

mutable struct Mic <: SignalWithFanout
    const inq :: Channel{Matrix{Float32}}
    const outq :: Channel{Matrix{Float32}}
    buf :: Matrix{Float32} # The currently playing buffer.
    i :: Int # The index into the currently playing buffer for the next sample.
    t :: Float64 # The last time for which value was taken.
    v :: Float32
    ϵ :: Float32
    done :: Bool
end

done(m :: Mic, t, dt) = m.done || (m.done = !isopen(m.inq))

function value(m :: Mic, t, dt)
    if t > m.t
        if m.i > size(m.buf,1)
            if isopen(m.outq)
                put!(m.outq, m.buf)
            end
            if isopen(m.inq)
                m.buf = take!(m.inq)
                m.i = 1
            end
        end
        m.t = t
        m.v = Float32(m.buf[m.i,1])
        m.i += 1
    end
    if m.done
        if m.v < m.ϵ
            m.v = 0.0f0
        else
            m.v *= 0.95f0
        end
    end
    m.v
end

"""
    mic(; blocksize :: Int = 128, samplingrate :: Float64 = 48000.0)

Opens input from the default mono mic source. You shouldn't need to fiddle with
the blocksize and samplingrate, but they're available for configuration.

A `Mic` supports intrinsic fanout and therefore you shouldn't need to create
multiple mic instances on the same audio interface.

**Todo:** At some point, support selecting named audio sources and also stereo
sources.
"""
function mic(; blocksize :: Int = 128, samplingrate :: Float64 = 48000.0)
    inq = Channel{Matrix{Float32}}(2)
    outq = Channel{Matrix{Float32}}(2)
    buf1 = zeros(Float32, blocksize, 1)
    buf2 = zeros(Float32, blocksize, 1)
    # We start off the mic past the end of the buffer
    # so that it is immediately fed to the stream thread.
    m = Mic(inq, outq, buf1, blocksize+1, 0.0, 0.0f0, 1.0f0/32768.0f0, false)
    put!(outq, buf2)

    Threads.@spawn begin
        try 
            stream = PortAudio.PortAudioStream(1,0; samplerate = samplingrate, warn_xruns = false)
            while isopen(stream) && isopen(inq)
                buf = take!(outq)
                read!(stream, buf)
                put!(inq, buf)
            end
        catch e
            @warn "Audio input task error" exception=(e, catch_backtrace())
        finally
            close(stream)
            close(inq)
            close(outq)
        end
    end

    return m
end

"""
    close(m :: Mic)

Stops the mic signal, which will eventually result in the associated audio
stream resources being released. It will mark the signal as "done" so that
further value computations don't occur.
"""
close(m :: Mic) = close(m.inq)


