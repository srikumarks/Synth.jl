
using Observables
using ..Synth: Probe, source

struct LED
    label::String
    angle::Int
    length::Int
    breadth::Int
    numsteps::Int
    colours::Vector{RGBA}  # Using just RGBA instead of Gtk4.RGBA
    fillratio::Float32
    gamma::Float32
    canvas::Ref{Union{Nothing,GtkCanvas}}
    valdisp::Ref{Union{Nothing,GtkLabel}}
    value::Observable{Float32}
    conn::Ref{Union{Nothing,ObserverFunction}}
end

"""
    connectui(w::LED, p::Probe{Float32})

Connects the probe that sends Float32 values to the LED UI element.
Only one such probe can be connected at a time. See [`probe`](@ref)
"""
function connectui(w::LED, p::Probe{Float32})
    if !isnothing(w.conn[])
        off(w.conn[])
        w.conn[] = nothing
    end
    obs = source(p)
    w.conn[] = on(obs) do v
        w.value[] = v
    end
end

function render(led::LED, panel::Panel)
    horizontal = led.angle == 0
    vertical = led.angle == 90
    led_width = horizontal ? led.length : led.breadth
    led_height = vertical ? led.length : led.breadth
    box = GtkBox(vertical ? :v : :h)
    label = GtkLabel(led.label)
    valdisp = GtkLabel("")
    canvas = GtkCanvas(led_width, led_height)
    push!(box, vertical ? valdisp : label)
    push!(box, canvas)
    push!(box, vertical ? label : valdisp)
    led.canvas[] = canvas
    led.valdisp[] = valdisp

    @guarded draw(canvas) do widget
        ctx = Gtk4.getgc(widget)
        w = Gtk4.width(widget)
        h = Gtk4.height(widget)
        #println("In LED draw")
        Cairo.rectangle(ctx, 0, 0, w, h)
        Cairo.set_source_rgb(ctx, 0, 0, 0)
        Cairo.fill(ctx)
        v = led.value[]
        #println("Draw LED value ", v)
        ledw = w / led.numsteps
        ledh = h / led.numsteps
        ledfillw = led.fillratio * ledw
        ledfillh = led.fillratio * ledh
        for i = 1:led.numsteps
            x0 =
                vertical ? (1.0 - led.fillratio) * w/2 :
                (i-1) * ledw + (1.0 - led.fillratio) * ledw / 2
            y0 =
                vertical ? (led.numsteps - i) * ledh + (1.0 - led.fillratio) * ledh / 2 :
                (1.0 - led.fillratio) * h/2
            x1 = vertical ? w - x0 : x0 + ledfillw
            y1 = vertical ? y0 + ledfillh : h - y0
            c = led.colours[i]
            Cairo.rectangle(ctx, x0, y0, x1-x0, y1-y0)
            vmin = (i-1)/led.numsteps
            vmax = i/led.numsteps
            alpha = (max(vmin, min(vmax, v)) - vmin) / (vmax - vmin)
            gamma = 0.5
            Cairo.set_source_rgba(ctx, c.r, c.g, c.b, (alpha ^ gamma) * c.alpha)
            Cairo.fill(ctx)
        end
    end

    panel.widgetof[led] = box
    return box
end

function LED(
    label::String,
    angle::Int,
    length_::Int,
    breadth::Int,
    colours::Vector{RGBA};
    fillratio::Real = 0.5,
    gamma::Real = 0.5,
)
    @assert angle == 0 || angle == 90
    N = length(colours)
    val = Observable{Float32}(0.0f0)
    w = LED(
        label,
        angle,
        length_,
        breadth,
        N,
        colours,
        Float32(fillratio),
        Float32(gamma),
        nothing,
        nothing,
        val,
        nothing
    )
    on(val) do v
        if !isnothing(w.valdisp[])
            w.valdisp[].label = @sprintf("%0.2f", v)
        end
        if !isnothing(w.canvas[])
            draw(w.canvas[])
        end
    end
    return w
end

LED(label::String, angle::Int, length_::Int; fillratio::Real = 0.5, gamma::Real = 0.5) =
    LED(label, angle, length_, div(length_, 5), stdleds(); fillratio, gamma)

function stdleds(ny::Integer, y::RGBA, no::Integer, o::RGBA, nr::Integer, r::RGBA)
    vcat(repeat([y], ny), repeat([o], no), repeat([r], nr))
end

stdleds(y::RGBA, o::RGBA, r::RGBA) = stdleds(9, y, 3, o, 2, r)
stdleds() = begin
    y = RGBA(1.0f0, 1.0f0, 0.0f0, 1.0f0)
    o = RGBA(1.0f0, 0.65f0, 0.0f0, 1.0f0)
    r = RGBA(1.0f0, 0.0f0, 0.0f0, 1.0f0)
    stdleds(y, o, r)
end


