using FileIO: load, save
using LibSndFile

"""
    write(filename :: AbstractString, model::Signal, duration_secs :: AbstractFloat; samplingrate=48000, maxamp=0.5)

Renders and writes raw `Float32` values to the given file.
"""
function write(filename :: AbstractString, model::Signal, duration_secs :: AbstractFloat; samplingrate=48000, maxamp=0.5)
    s = render(model, duration_secs; samplingrate, maxamp)
    s = rescale(maxamp, s)
    save(filename, s)
end

"""
    read_rawaudio(filename :: AbstractString)

Reads raw `Float32` values from the given file into a `Vector{Float32}`
that can then be used with `sample` or `wavetable`.
"""
function read_rawaudio(filename :: AbstractString)
    o = Vector{Float32}(undef, filesize(filename) ÷ 4)
    read!(filename, o)
    return o
end


