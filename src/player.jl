import ThreadPools
using SampledSignals

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
function startaudio(callback; numchannels=1, blocksize=64)
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
        close(wq)
        close(rq)
        #println("Audio thread done!")
    end

    stream = PortAudio.PortAudioStream(0, numchannels)
    rq = Channel{Union{Val{:done}, SampleBuf{Float32,numchannels}}}(2)
    wq = Channel{Union{Val{:done}, SampleBuf{Float32,numchannels}}}(2)
    #println("Writing empty buffers...")
    put!(wq, SampleBuf(Float32, stream.sample_rate, blocksize, numchannels))
    put!(wq, SampleBuf(Float32, stream.sample_rate, blocksize, numchannels))

    
    #println("Starting threads...")
    ThreadPools.@tspawnat 1 callback(stream.sample_rate, wq, rq)
    while rq.n_avail_items < rq.sz_max
        sleep(0.05)
    end
    ThreadPools.@tspawnat 2 audiothread(stream, rq, wq)
    return () -> put!(wq, Val(:done))
end

const SynthCommands = Channel{Tuple{Float64, Signal}}

"""
    synthchan() :: Channel{Tuple{Float64, Signal}}

Makes a channel suitable for use with [`synthesizer`](@ref).
You can then send signals to this channel using [`play!`](@ref)
or in special cases directly using it like `put!(time(), sig)`
where the time can be noted several steps earlier for a sense
of immediacy.
"""
function synthchan() :: SynthCommands
    SynthCommands(2)
end

"""
    play!(commands :: Channel{Tuple{Float64, Signal}}, sig :: Signal)
    play!(commands :: Channel{Tuple{Float64, Signal}}, sig :: Signal, t :: Float64)

Plays the signal by adding it to the command queue of a synthesizer.
When the `t` argument is omitted, it is taken to mean the "current time"
in the absolute sense of `time()`.
"""
function play!(commands :: SynthCommands, sig :: Signal)
    put!(commands, (time(), sig))
end
function play!(commands :: SynthCommands, sig :: Signal, t :: Float64)
    put!(commands, (t, sig))
end

"""
    synthesizer(commands::Channel{Tuple{Float64,Signal}}; blocksize=64)

Wraps `startaudio` such that you can send signals at arbitrary times
to the given channel and the synthesizer will immediately start playing
the signal. The first part of the tuple is expected to be a time stamp
of arrival of event that triggers the signal. So in the event receiver,
capture this time stamp upon entry by calling the `time()` function
before doing anything else and use that value for the tuple.

Returns a stop function which when called with no arguments will
stop the synth.

You can use [`synthchan`](@ref) to make a channel.
"""
function synthesizer(commands::SynthCommands; numchannels = 1, blocksize=64)
    function callback(sample_rate, rq, wq)
        #println("In callback $sample_rate, $rq, $wq")
        dt = 1.0 / sample_rate
        t = 0.0
        t0 = -1.0
        rt0 = -1.0
        endmarker = Val(:done)
        voices = Vector{Tuple{Float64,Signal}}()
        while true
            buf = take!(rq)
            if buf == endmarker break end
            while isready(commands)
                (rt,sig) = take!(commands)
                if rt0 < 0.0
                    # Note down the start time, since all other time stamps
                    # will be considered relative to this.
                    rt0 = rt
                    t0 = t
                end
                push!(voices, (t0 + rt - rt0, sig))
            end
            buf .= 0.0f0
            N = size(buf, 1)
            for i in 1:N
                tmp = sampleframe(buf)
                for (vt,v) in voices
                    if t > vt
                        addsampleframe!(tmp, value(v, t-vt, dt))
                    end
                end
                buf[i,:] .= tmp
                t += dt
            end
            put!(wq, buf)
            filter!(voices) do (vt,v)
                t <= vt || !done(v, t-vt, dt)
            end
        end
        put!(wq, endmarker)
        #println("Audio generator done!")
    end
    startaudio(callback; numchannels, blocksize)
end

function sampleframe(s::SampleBuf{Float32,1})
    MVector{1,Float32}(0.0f0)
end

function sampleframe(s::SampleBuf{Float32,2})
    MVector{2,Float32}(0.0f0,0.0f0)
end

function addsampleframe!(f::MVector{1,Float32}, v::Float32)
    f[1] += v[1]
end

function addsampleframe!(f::MVector{1,Float32}, v::SVector{2,Float32})
    f[1] += v[1] + v[2]
end

function addsampleframe!(f::MVector{2,Float32}, v::Float32)
    f[1] += v[1]
    f[2] += v[1]
end

function addsampleframe!(f::MVector{2,Float32}, v::SVector{2,Float32})
    f[1] += v[1]
    f[2] += v[2]
end


"""
    play(signal, duration_secs; blocksize=64)

Plays the given signal on the default audio output in realtime
for the given duration or till the signal ends, whichever
happens earlier. Be careful about the signal level since
in this case the signal can't be globally normalized.
"""
function play(signal :: S, duration_secs=Inf; blocksize=64) where {S <: Signal}
    function callback(sample_rate, rq, wq)
        #println("In callback $sample_rate, $rq, $wq")
        dt = 1.0 / sample_rate
        t = 0.0
        endmarker = Val(:done)
        while t < duration_secs && !done(signal, t, dt)
            buf = take!(rq)
            if buf != endmarker
                buf .= 0.0f0
                N = size(buf, 1)
                for i in 1:N
                    val = value(signal, t, dt)
                    buf[i,:] .= val
                    t += dt
                end
                put!(wq, buf)
            else
                break
            end
        end
        put!(wq, Val(:done))
        #println("Audio generator done!")
    end
    startaudio(callback; blocksize)
end

