using FileIO: load, save
using LibSndFile

"""
    write(filename :: AbstractString, model::Sig, duration_secs :: AbstractFloat; sr=48000, maxamp=0.5) where {Sig <: Signal}

Renders and writes raw `Float32` values to the given file.
"""
function write(filename :: AbstractString, model::Sig, duration_secs :: AbstractFloat; sr=48000, maxamp=0.5) where {Sig <: Signal}
    s = render(model, duration_secs; sr, maxamp)
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


