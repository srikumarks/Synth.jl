
using ..Synth
using DSP

const raw_cache :: Dict{String,SampleBuf{Float32}} = Dict()

function raw(filename::AbstractString; samplingrate :: Float64 = 48000.0)
    @assert filename[end-3:end] == ".raw" "Raw file names must end in .raw. Given $filename ."
    if haskey(raw_cache, filename)
        return raw_cache[filename]
    end

    path = (@__DIR__) * "/rawwaves/" * filename
    NBytes = filesize(path) 
    @assert NBytes % 2 == 0 "Invalid raw file format. Expected even number of bytes for Int16 format"
    N = div(NBytes, 2)
    s16 = zeros(Int16, N)
    read!(path, s16)
    v = Float32.(s16) / 32767.0f0
    vr = resample(v, samplingrate/22050.0)
    buf = SampleBuf(vr, samplingrate)
    raw_cache[filename] = buf
    return buf
end
