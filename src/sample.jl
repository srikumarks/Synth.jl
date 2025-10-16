import SampledSignals
using SampledSignals: SampleBuf

mutable struct Sample <: Signal
    const samples::Vector{Float32}
    const N::Int
    i::Int
    const looping::Bool
    const loop_i::Int
    const samplingrate::Float64
end

"""
    sample(samples :: Vector{Float32}; looping = false, loopto = 1.0) 
    sample(filename :: AbstractString; looping = false, loopto = 1.0, samplingrate=48000.0)

Produces a sampled signal which samples from the given array as a source.
It starts from the beginning and goes on until the end of the array,
but can be asked to loop back to a specified point after that.

- The `loopto` argument is specified relative (i.e. scaled) to the length
  of the samples vector. So if you want to jump back to the middle, you give
  `0.5` as the `loopto` value.

Currently sample rate conversion is not supported, though that is a feature
that must be added at some point.
"""
function sample(
    samples::Vector{Float32};
    looping = false,
    loopto = 1.0,
    samplingrate = 48000.0,
)
    Sample(
        samples,
        length(samples),
        1,
        looping,
        floor(Int, loopto * length(samples)),
        samplingrate,
    )
end
function sample(
    samples::SampleBuf;
    looping = false,
    loopto = 1.0,
    samplingrate = SampledSignals.samplerate(samples),
)
    sample(Float32.(samples[:, 1].data); looping, loopto, samplingrate)
end
function sample(
    filename::AbstractString;
    looping = false,
    loopto = 1.0,
    samplingrate = 48000.0,
)
    buf = load(filename)
    @assert abs(samplingrate - SampledSignals.samplerate(buf)) < 0.5 / samplingrate
    sample(Float32.(buf[:, 1].data); looping, loopto, samplingrate)
end

const named_samples = Dict{Symbol,Sample}()

"""
    sample(name :: Symbol) :: Sample

Retrieve named sample. The retrieved sample will have the
same looping settings as the stored sample, but not its
running state.
"""
function sample(name :: Symbol)
    s = named_samples[name]
    Sample(s.samples, s.N, 1, s.looping, s.loop_i, s.samplingrate)
end

"""
    register!(name :: Symbol, s :: Sample)

Associates the given name with the given sample so it can be retrieved
using `sample(::String)`.
"""
function register!(name :: Symbol, s :: Sample)
    named_samples[name] = s
    return s
end

function done(s::Sample, t, dt)
    if s.looping
        false
    else
        s.i > s.N
    end
end

function value(s::Sample, t, dt)
    if s.i > s.N
        return 0.0f0
    end
    v = s.samples[s.i]
    s.i = s.i + 1
    if s.i > s.N
        if s.looping
            s.i = s.loop_i
        end
    end
    return v
end

function convolve(s1::Sample, s2::Sample)::Sample
    sample(rescale(0.5f0, convolve(s1.samples, s2.samples)))
end
