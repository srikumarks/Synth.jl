import SampledSignals
using SampledSignals: SampleBuf
import DSP

"""
    mutable struct Sample{SV <: AbstractVector{Float32}} <: Signal

Wraps a "sample" in the sense of a "snippet of sound intended for
playing back directly".
"""
mutable struct Sample{SV<:AbstractVector{Float32}} <: Signal
    const samples::SV
    const N::Int
    i::Int
    const looping::Bool
    const loop_i::Int
    const samplingrate::Float64
end

struct AudioSample
    data::Vector{Float32}
    samplingrate::Float64
end

# We keep a cache of samples loaded from files based on the file paths
# so that we can slice into these files without having to reload them.
# For now we only do mono sounds though.
const sample_cache::Dict{String,AudioSample} = Dict{String,AudioSample}()

"""
    sample(samples :: Vector{Float32}; looping = false, loopto = 1.0) 
    sample(filename :: AbstractString; looping = false, loopto = 1.0, samplingrate=48000.0, selstart=0.0, selend=Inf)

Produces a sampled signal which samples from the given array as a source.
It starts from the beginning and goes on until the end of the array,
but can be asked to loop back to a specified point after that.

- The `loopto` argument is specified relative (i.e. scaled) to the length
  of the samples vector. So if you want to jump back to the middle, you give
  `0.5` as the `loopto` value.
- The `selstart` and `selend` keyword arguments can be used to slice
  into the sound sample, with the default covering the entire file.

If the sample rate of the file is different from the selected `samplingrate`,
the loaded samples will be converted to the given rate (uses [`DSP.resample`](@ref)).

To make slicing into large files efficient, files are loaded once and cached.
This cache is looked up (based on the file name) every time a slice is needed.
"""
function sample(
    samples::SV;
    looping::Bool = false,
    loopto::Real = 1.0,
    samplingrate::Float64 = 48000.0,
) where {SV<:AbstractVector{Float32}}
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
    looping::Bool = false,
    loopto::Real = 1.0,
    samplingrate::Float64 = SampledSignals.samplerate(samples),
)
    sample(Float32.(samples[:, 1].data); looping, loopto, samplingrate)
end

function resample(buffer::Vector{Float32}, fromSR::Float64, toSR::Float64)
    if abs(fromSR - toSR) < 0.5
        return buffer
    end

    @info "Converting from sample rate $(fromSR)Hz to $(toSR)Hz"
    return DSP.resample(buffer, toSR/fromSR)
end

function sample(
    filename::AbstractString;
    looping::Bool = false,
    loopto::Float64 = 1.0,
    samplingrate::Float64 = 48000.0,
    selstart::Real = 0.0,
    selend::Real = Inf,
    usecache::Bool = true,
)
    # Avoid reloading file from disk if it was already loaded and cached.
    if haskey(sample_cache, filename)
        buf = sample_cache[filename]
    else
        sb = load(filename)
        sampledata =
            resample(Float32.(sb.data[:, 1]), SampledSignals.samplerate(sb), samplingrate)
        buf = AudioSample(sampledata, samplingrate)
        sample_cache[filename] = buf
    end
    N = length(buf.data)
    startIx = max(1, floor(Int, selstart * samplingrate))
    endIx = floor(Int, min(N / samplingrate, selend) * samplingrate)
    sample(view(buf.data, startIx:endIx); looping, loopto, samplingrate)
end

const named_samples = Dict{Symbol,Sample}()

"""
    sample(name :: Symbol) :: Sample

Retrieve named sample. The retrieved sample will have the
same looping settings as the stored sample, but not its
running state.
"""
function sample(name::Symbol)
    s = named_samples[name]
    Sample(s.samples, s.N, 1, s.looping, s.loop_i, s.samplingrate)
end

"""
    register(name :: Symbol, s :: Sample)

Associates the given name with the given sample so it can be retrieved
using `sample(::String)`.
"""
function register(name::Symbol, s::Sample)
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
