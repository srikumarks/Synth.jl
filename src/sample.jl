mutable struct Sample <: Signal
    samples :: Vector{Float32}
    N :: Int
    i :: Int
    looping :: Bool
    loop_i :: Int
    samplingrate :: Float32
end

"""
    sample(samples :: Vector{Float32}; looping = false, loopto = 1.0) 
    sample(filename :: AbstractString; looping = false, loopto = 1.0, samplingrate=48000.0f0)

Produces a sampled signal which samples from the given array as a source.
It starts from the beginning and goes on until the end of the array,
but can be asked to loop back to a specified point after that.

- The `loopto` argument is specified relative (i.e. scaled) to the length
  of the samples vector. So if you want to jump back to the middle, you give
  `0.5` as the `loopto` value.
"""
function sample(samples :: Vector{Float32}; looping = false, loopto = 1.0, samplingrate=48000.0f0) 
    Sample(samples, length(samples), 0, looping, 1 + floor(Int, loopto * length(samples)), samplingrate)
end
function sample(filename :: AbstractString; looping = false, loopto = 1.0, samplingrate=48000.0f0)
    buf = load(filename)
    Sample(Float32.(buf[:,1].data); looping, loopto, samplingrate)
end

function done(s :: Sample, t, dt)
    if s.looping
        false
    else
        i > s.N
    end
end

function value(s :: Sample, t, dt)
    if s.i > s.N return 0.0f0 end
    v = s.samples[s.i]
    s.i = s.i + 1
    if s.i > s.N
        if s.looping
            s.i = s.loop_i
        end
    end
    return v
end


