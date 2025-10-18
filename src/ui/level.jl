struct Level
    label::String
    angle::Int
    length::Int
    breadth::Int
    minval::Float32
    maxval::Float32
    colours::Vector{Tuple{Float32,RGBA}}
    canvas::Ref{Union{Nothing,GtkCanvas}}
    valdisp::Ref{Union{Nothing,GtkLabel}}
    value::Ref{Float32}
end

function render(level::Level, panel::Panel)
    horizontal = level.angle == 0
    vertical = level.angle == 90
    level_width = horizontal ? level.length : level.breadth
    level_height = vertical ? level.length : level.breadth
    box = GtkBox(vertical ? :v : :h)
    label = GtkLabel(level.label)
    valdisp = GtkLabel("")
    canvas = GtkCanvas(level_width, level_height)
    push!(box, vertical ? valdisp : label)
    push!(box, canvas)
    push!(box, vertical ? label : valdisp)
    level.canvas[] = canvas
    level.valdisp[] = valdisp

    @guarded draw(canvas) do widget
        ctx = Gtk4.getgc(widget)
        w = Gtk4.width(widget)
        h = Gtk4.height(widget)
        Cairo.rectangle(ctx, 0, 0, w, h)
        Cairo.set_source_rgb(ctx, 0, 0, 0)
        fill(ctx)
        v = level.value[]
        gradient = if horizontal
            Cairo.pattern_create_linear(0, 0, w, 0)
        else
            Cairo.pattern_create_linear(0, h, 0, 0)
        end

        for (stop, c) in level.colours
            Cairo.pattern_add_color_stop_rgba(gradient, stop, c.r, c.g, c.b, c.alpha)
        end

        Cairo.set_source(ctx, gradient)
        if horizontal
            Cairo.rectangle(ctx, 0, 0, w * v, 0)
        else
            Cairo.rectangle(ctx, 0, (1.0f0-v) * h, w, h)
        end
        Cairo.fill(ctx)
        Cairo.destroy(gradient)
    end

    panel.widgetof[level] = box
    return box
end

stdlevelcolours() = begin
    g = RGBA(0.0f0, 1.0f0, 0.0f0, 1.0f0)
    [(0.0f0, g), (1.0f0, g)]
end

function Level(
    label::String,
    angle::Int,
    length_::Int,
    breadth::Int,
    colours::Vector{Tuple{Float32,RGBA}},
    source::Channel{Float32},
)
    @assert angle == 0 || angle == 90
    N = length(colours)
    val = Ref(0.0f0)
    w = Level(label, angle, length_, breadth, 0.0f0, 1.0f0, colours, nothing, nothing, val)
    @async begin
        try
            while true
                v = take!(source)
                val[] = v
                #println("Level[$label] value ", v)
                if !isnothing(w.valdisp[])
                    #println("\t setting label")
                    w.valdisp[].label = @sprintf("%0.2f", v)
                end
                if !isnothing(w.canvas[])
                    #println("\t drawing canvas")
                    draw(w.canvas[])
                end
            end
        catch e
            # Channel closed
            nothing
        end
    end
    return w
end

Level(label::String, angle::Int, length_::Int, source::Channel{Float32}) =
    Level(label, angle, length_, div(length_, 5), stdlevelcolours(), source)


