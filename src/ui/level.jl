struct Level
    label::String
    angle::Int
    length::Int
    breadth::Int
    minval::Float32
    maxval::Float32
    breakpts::Vector{Tuple{Float32,Float32}}
    colours::Vector{Tuple{RGBA,RGBA}}
end


