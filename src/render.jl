
using SampledSignals: SampleBuf

"""
    render(s :: S, dur_secs; maxamp=0.5) where {S <: Signal}

Renders the given signal to a flat `Vector{Float32}`,
over the given `dur_secs`. If the signal terminates before
the duration is up, the result is truncated accordingly.
"""
function render(s :: S, dur_secs; samplingrate=48000, normalize=false, maxamp=0.5) where {S <: Signal}
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
    return SampleBuf(if normalize rescale(maxamp, result) else result end, samplingrate)
end


