import ThreadPools
using SampledSignals: SampleBuf

function drain(ch)
    while isready(ch)
        take!(ch)
    end
end

function audiothread(stream, rq, wq)
    #println("In audiothread $stream, $rq, $wq")
    endmarker = Val(:done)
    buf = take!(rq)
    while buf != endmarker
        Base.write(stream, buf)
        put!(wq, buf)
        buf = take!(rq)
    end
    close(stream)
    drain(rq)
    drain(wq)
    close(wq)
    close(rq)
    #println("Audio thread done!")
end


"""
    startaudio(callback)

`callback` is a function that will be called like `callback(sample_rate,
readqueue, writequeue)`. `sample_rate` indicates the output sampling rate.
`readqueue` and `writequeue` are `Channel`s that accept either an audio buffer
as a `Vector{Float32}` or `Val(:done)` to indicate completion of the audio
process. The callback is expected to `take!` a buffer from the `readqueue`,
fill it up and submit it to the `writequeue` using `put!`.

When the audio generation is done, `callback` should `put!(writequeue,
Val(:done))` and break out of its generation loop and return.

It returns a function that can be called (without any arguments)
to stop the audio processing thread. Make sure to start julia with
a sufficient number of threads for this to work.
"""
function startaudio(callback; chans::Int = 1, blocksize::Int = 64)
    stream = PortAudio.PortAudioStream(0, chans)
    rq = Channel{Union{Val{:done},SampleBuf{Float32,2}}}(2)
    wq = Channel{Union{Val{:done},SampleBuf{Float32,2}}}(2)
    #println("Writing empty buffers...")
    b1 = SampleBuf(Float32, stream.sample_rate, blocksize, chans)
    b2 = SampleBuf(Float32, stream.sample_rate, blocksize, chans)
    b1 .= 0.0f0
    b2 .= 0.0f0
    put!(wq, b1)
    put!(wq, b2)


    #println("Starting threads...")
    Threads.@spawn begin
        callback(stream.sample_rate, wq, rq)
    end
    Threads.@spawn begin
        audiothread(stream, rq, wq)
    end

    return () -> put!(wq, Val(:done))
end

function mixin!(buf::SampleBuf{Float32,2}, i::Integer, sig::Signal, t, dt)
    v = value(sig, t, dt)
    buf[i, :] .+= v
end

function mixin!(
    buf::SampleBuf{Float32,2},
    i::Integer,
    sig::Stereo{L,R},
    t,
    dt,
) where {L<:Signal,R<:Signal}
    chans = size(buf, 2)
    if chans == 1
        buf[i, 1] += value(sig, 0, t, dt)
    elseif chans == 2
        buf[i, 1] += value(sig, -1, t, dt)
        buf[i, 2] += value(sig, 1, t, dt)
    else
        buf[i, :] .= 0.0f0
    end
end

"""
    play(signal, duration_secs=Inf; blocksize=64)

Plays the given signal on the default audio output in realtime for the given
duration or till the signal ends, whichever happens earlier. Be careful about
the signal level since in this case the signal can't be globally normalized.

Returns a stop function (like with [`startaudio`](@ref) and
[`synthesizer`](@ref)) which when called with no arguments will stop playback.
"""
function play(signal::Signal, duration_secs = Inf; chans = 1, blocksize = 64)
    function callback(sample_rate, rq, wq)
        #println("In callback $sample_rate, $rq, $wq")
        dt = 1.0 / sample_rate
        t = 0.0
        endmarker = Val(:done)
        while t < duration_secs && !done(signal, t, dt)
            buf = take!(rq)
            if buf != endmarker
                fill!(buf, 0.0f0)
                for i = 1:size(buf, 1)
                    mixin!(buf, i, signal, t, dt)
                    t += dt
                end
                put!(wq, buf)
            else
                break
            end
        end
        put!(wq, endmarker)
        #println("Audio generator done!")
    end
    startaudio(callback; chans, blocksize)
end
