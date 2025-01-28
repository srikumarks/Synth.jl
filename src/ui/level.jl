
const ColorBrk = @NamedTuple{x::Float32, c::RGBA}

struct Level{T <: AbstractVector{ColorBrk}}
    label::String
    angle::Int
    length::Int
    breadth::Int
    minval::Float32
    maxval::Float32
    colours::T
    source::Channel{Float32}
    canvas::Ref{Union{Nothing,GtkCanvas}}
    valdisp::Ref{Union{Nothing,GtkLabel}}
    value::Ref{Float32}
    gamma::Float32

    function Level{T}(
            label::String,
            angle::Integer,
            length_::Integer,
            breadth::Integer,
            minvalr::Real,
            maxvalr::Real,
            colours::T,
            source::Channel{Float32};
            gamma::Float32 = 0.5f0
           ) where {T <: AbstractVector{ColorBrk}}
        @assert angle == 0 || angle == 90 "Only two angle values -- 0 and 90 -- are permitted."
        @assert length_ > 0 "Can't be a zero-sized display element"
        @assert breadth > 0 "Can't be a zero-sized display element"
        minval = Float32(minvalr)
        maxval = Float32(maxvalr)
        @assert minval < maxval
        @assert length(colours) >= 2 "Colours must span the whole interval"
        @assert colours[1].x == minval  "Colours must span the whole interval"
        @assert colours[end].x == maxval  "Colours must span the whole interval"
        for i in 2:length(colours)
            @assert colours[i].x >= colours[i-1].x "Colour break points must be in ascending order"
        end
        w = new{T}(label, angle, length_, breadth, minval, maxval, colours, source, nothing, nothing, minval, gamma)
        @async begin
            try
                while true
                    v = take!(source)
                    val[] = v
                    if !isnothing(w.valdisp[])
                        w.valdisp[].label = @sprintf("%0.2f", v)
                    end
                    if !isnothing(w.canvas[])
                        draw(w.canvas[])
                    end
                end
            catch e
                # Channel closed
                nothing
            end
        end
        w
    end
end

function render(level :: Level, panel :: Panel)
    horizontal = level.angle == 0
    vertical = level.angle == 90
    level_width = horizontal ? level.length : level.breadth
    level_height = vertical ? level.length : level.breadth
    box = GtkBox(vertical ? :v : h)
    label = GtkLabel(level.label)
    valdisp = GtkLabel("")
    canvas = GtkCanvas(level_width, level_height)
    push!(box, vertical ? valdisp : label)
    push!(box, canvas)
    push!(box, vertical ? label : valdisp)
    level.canvas[] = canvas
    level.valdisp[] = valdisp
    gamma = level.gamma

    locate_value(val, i) = if level.colours[i].x <= val && level.colours[i+1].x >= val
        i
    elseif val > level.colours[i+1].x
        locate_value(val, div(i+1 + length(level.colours), 2))
    else
        locate_value(val, div(1 + i, 2))
    end

    
    @guarded draw(canvas) do widget
        ctx = getgc(canvas)
        h = height(canvas)
        w = width(canvas)
        rectangle(ctx, 0, 0, w, h)
        set_source_rgb(ctx, 0, 0, 0)
        fill(ctx)
        v = max(level.minval, min(level.maxval, level.value[]))
        vfrac(v) = (v - level.minval) / (level.maxval - level.minval)
        ci = min(length(level.colours)-1, locate_value(v, div(1 + length(level.colours), 2)))
        for i in 1:ci
            x0 = vertical ? 0 : 0
            y0 = vertical ? h - h * vfrac(level.colours[i].x) : 0
            x1 = vertical ? w : w * vfrac(level.colours[i].x)
            y1 = vertical ? h - h * vfrac(level.colours[i+1].x) : h
            c = level.colours[i].c
            rectangle(ctx, x1, y0, x1-x0, y1-y0)
            alpha = min(1.0f0, (v - level.colours[i].x) / (level.colours[i+1].x - level.colours[i].x))
            # TODO: Make colour gradient instead of using the alpha.
            set_source_rgba(ctx, c.r, c.g, c.b, (alpha ^ gamma) * c.alpha)
            fill(ctx)
        end
    end

    panel.widgetof[level] = box
    return box
end

