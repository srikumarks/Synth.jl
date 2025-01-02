
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
to stop the audio processing.
"""
function startaudio(callback; blocksize=64)
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

    stream = Au.PortAudioStream(0, 1)
    rq = Channel{Union{Val{:done}, Vector{Float32}}}(2)
    wq = Channel{Union{Val{:done}, Vector{Float32}}}(2)
    #println("Writing empty buffers...")
    put!(wq, zeros(Float32, blocksize))
    put!(wq, zeros(Float32, blocksize))
    
    #println("Starting threads...")
    Threads.@spawn audiothread(stream, rq, wq)
    Threads.@spawn callback(stream.sample_rate, wq, rq)
    return () -> put!(wq, Val(:done))
end

function synthesizer(commands::Channel{Signal}; blocksize=64)
    function callback(sample_rate, rq, wq)
        #println("In callback $sample_rate, $rq, $wq")
        dt = 1.0 / sample_rate
        t = 0.0
        endmarker = Val(:done)
        voices = Vector{Tuple{Float64,Signal}}()
        while true
            buf = take!(rq)
            if buf == endmarker
                break
            end
            while isready(commands)
                sig = take!(commands)
                push!(voices, (t,sig))
            end
            fill!(buf, 0.0f0)
            for i in eachindex(buf)
                for (vt,v) in voices
                    buf[i] += value(v, t-vt, dt)
                end
                t += dt
            end
            put!(wq, buf)
            filter!(voices) do (vt,v)
                !done(v, t-vt, dt)
            end
        end
        put!(wq, endmarker)
        #println("Audio generator done!")
    end
    startaudio(callback; blocksize)
end

function play(signal, duration_secs; blocksize=64)
    function callback(sample_rate, rq, wq)
        #println("In callback $sample_rate, $rq, $wq")
        dt = 1.0 / sample_rate
        t = 0.0
        endmarker = Val(:done)
        while t < duration_secs && !done(signal, t, dt)
            buf = take!(rq)
            if buf != endmarker
                fill!(buf, 0.0f0)
                for i in eachindex(buf)
                    buf[i] = value(signal, t, dt)
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


