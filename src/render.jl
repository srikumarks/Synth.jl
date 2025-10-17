
using SampledSignals: SampleBuf

"""
    render(s :: Signal, dur_secs; samplingrate=48000, normalize=false, maxamp=0.5)
    render(s :: Stereo{L,R}, dur_secs; samplingrate=48000) where {L <: Signal, R <: Signal}

Renders the given signal to a flat `Vector{Float32}`, over the given
`dur_secs`. If the signal terminates before the duration is up, the result is
truncated accordingly. These functions return `SampleBuf` from `SampledSignals`
package.
"""
function render(s::Signal, dur_secs; samplingrate = 48000, normalize = false, maxamp = 0.5)
    dt = 1.0 / samplingrate
    N = floor(Int, dur_secs * samplingrate)
    tspan = dt .* (0:(N-1))
    result = Vector{Float32}()
    for t in tspan
        if !done(s, t, dt)
            push!(result, Float32(value(s, t, dt)))
        else
            break
        end
    end
    return SampleBuf(if normalize
        rescale(maxamp, result)
    else
        result
    end, samplingrate)
end

function render(s::Stereo, dur_secs; samplingrate = 48000)
    dt = 1.0 / samplingrate
    N = floor(Int, dur_secs * samplingrate)
    tspan = dt .* (0:(N-1))
    result = SampleBuf(Float32, samplingrate, N, 2)
    actualN = N
    for i = 1:N
        t = (i-1) * dt
        if !done(s, t, dt)
            result[i, 1] = value(s, -1, t, dt)
            result[i, 2] = value(s, 1, t, dt)
        else
            actualN = i-1
            break
        end
    end
    return result[1:actualN, :]
end
