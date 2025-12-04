import ThreadPools
using SampledSignals: SampleBuf, nframes, samplerate

function drain(ch)
    while isready(ch)
        take!(ch)
    end
end

function selectdevice(chans::Int=1, name::AbstractString="")
    devs = PortAudio.devices()
    nameparts = split(strip(lowercase(name)), r"\s+")
    @debug "Available audio devices" devices=devs
    for d in devs
        devname = lowercase(d.name)
        if d.output_bounds.max_channels >= chans && all(occursin(part, devname) for part in nameparts)
            return d
        end
    end
    @error "Desired device with name '$name' and $chans channels not found."
    for d in PortAudio.devices()
        if d.output_bounds.max_channels >= chans
            @warn "Picked device '$(d.name)'"
            return d
        end
    end
    throw(SystemError("Audio output device unavailable"))
end

function audiothread(chans, samplingrate, rq, wq, reportLatency_ms, devicechoice="")
    recommended_latency = if Sys.isapple()
        0.015
    else
        nothing
    end
    dev = selectdevice(chans, devicechoice)
    stream = PortAudio.PortAudioStream(
        dev,
        0,
        chans;
        samplerate = samplingrate,
        latency = recommended_latency,
    )
    @debug "Stream created" stream=stream info=dev.output_bounds
    streaminfo = unsafe_load(PortAudio.LibPortAudio.Pa_GetStreamInfo(stream.pointer_to))
    latency_secs = streaminfo.outputLatency
    latency_ms = ceil(Int, latency_secs * 1000)
    put!(reportLatency_ms, latency_ms)
    @info "Audio output info" samplingrate=samplingrate latency_ms=latency_ms
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
    @info "Audio player thread finished"
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
function startaudio(
    callback;
    samplingrate::Float64 = 48000.0,
    chans::Int = 1,
    blocksize::Int = 64,
    mididevice::AbstractString = "",
    audiodevice::AbstractString = ""
)
    rq = Channel{Union{Val{:done},SampleBuf{Float32,2}}}(2)
    wq = Channel{Union{Val{:done},SampleBuf{Float32,2}}}(2)
    #println("Writing empty buffers...")
    b1 = SampleBuf(Float32, samplingrate, blocksize, chans)
    b2 = SampleBuf(Float32, samplingrate, blocksize, chans)
    b1 .= 0.0f0
    b2 .= 0.0f0
    put!(wq, b1)
    put!(wq, b2)

    latency_ms = Channel{Int}(1)

    #println("Starting threads...")
    Threads.@spawn :interactive begin
        midiout = midioutput(mididevice; outputDelay_ms = take!(latency_ms))
        try
            with(current_midi_output => midiout) do
                callback(samplingrate, wq, rq)
            end
        catch e
            @error "Audio generator thread error" error=(e, catch_backtrace())
        finally
            close(midiout)
        end
    end
    Threads.@spawn :interactive begin
        try
            audiothread(chans, samplingrate, rq, wq, latency_ms, audiodevice)
        catch e
            @error "Audio thread error" error=(e, catch_backtrace())
        end
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
    play(signal::Signal, duration_secs=Inf; blocksize=64)
    play(soundfile::AbstractString)

Other named arguments - 

- `mididevice::AbstractString=""` a name pattern to match against the
  MIDI output device to select. Leave as default to pick a suitable one.

- `audiodevice::AbstractString=""` a case insensitive name pattern to
  match against the set of available audio output devices. If you leave
  as default, then only the availability of sufficient output channels
  will be considered as a criterion for selecting a device. For example,
  if you pass "speaker", it will match against "MacBook Air Speakers".

Plays the given signal on the default audio output in realtime for the given
duration or till the signal ends, whichever happens earlier. Be careful about
the signal level since in this case the signal can't be globally normalized.

The version that takes a string is a short hand for loading the file and
playing it. The file is cached in memory, so it won't load it again if you call
it again.

Returns a stop function (like with [`startaudio`](@ref) which when called with
no arguments will stop playback.
"""
function play(
    signal::Signal,
    duration_secs = Inf;
    chans = 1,
    blocksize = 64,
    mididevice::AbstractString = "",
    audiodevice::AbstractString = ""
)
    function callback(sample_rate, rq, wq)
        #println("In callback $sample_rate, $rq, $wq")
        dt = 1.0 / sample_rate
        t = 0.0
        endmarker = Val(:done)
        try
            for i = 1:100
                buf = take!(rq)
                fill!(buf, 0.0f0)
                sync!(current_midi_output[], 0.0)
                put!(wq, buf)
            end
            synced = false
            @info "Starting player"
            while t < duration_secs && !done(signal, t, dt)
                buf = take!(rq)
                if buf != endmarker
                    fill!(buf, 0.0f0)
                    for i = 1:size(buf, 1)
                        mixin!(buf, i, signal, t, dt)
                        t += dt
                    end
                    put!(wq, buf)
                    if !synced
                        sync!(current_midi_output[], 0.0)
                        synced = true
                    end
                else
                    break
                end
            end
        catch e
            cb = stacktrace(catch_backtrace())
            @error "Player error" error=e backtrack=cb
        end
        put!(wq, endmarker)
        @info "Audio generator done!"
    end
    startaudio(callback; chans, blocksize, mididevice, audiodevice)
end

function play(soundfile::AbstractString)
    play(sample(soundfile))
end
