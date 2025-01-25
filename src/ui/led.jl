struct LED <: ControlUI
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
    value::Ref{Float32}
end

"""
    LED(label::String,
        angle::Int,
        length::Int,
        breadth::Int,
        colours::Vector{RGBA},
        source::Channel{Float32};
        fillratio=0.5,
        gamma=0.5
        ) :: ControlUI

An LED display mimics the level meters on physical devices like mixers. It
takes a source of values and reflects those values in the UI element.

## Positional parameters

- `label` is a `String` to display to identify the meter. Keep this short.
- `angle` either 0 or 90 to indicate whether the meter is horizontal or vertical.
- `length` is the length of the meter in pixels, along the direction indicated by `angle`.
- `breadth` is the breadth of the meter in pixels, along the direction
  perpendicular to that indicated by `angle`.
- `colours` gives the colours to use for the individual LEDs. The value received in
  is mapped to an element of this colour sequence for display purposes. The number of
  LEDs is therefore the length of this colour array.
- `source` is a channel on which `Float32` values received are reflected on the
  LED display.

## Named parameters

- `fillratio` indicates what fraction of the space for the meter is occupied by
  each LED. Along the breadth, a fill ratio of of 0.5 means half the width will
  be occupid. Along the length, it will mean ``0.5*length/N`` pixels, where
  ``N`` is the number of LEDs.
- `gamma` applies a logarithmic compressing curve on the transparency of the
  interpolated colour before applying the supplied colour's alpha. Usually just
  leave it at the default.
"""
function LED(label::String, angle::Int, length_::Int, breadth::Int, colours::Vector{RGBA}, source::Channel{Float32}; fillratio=0.5, gamma=0.5)
    @assert angle == 0 || angle == 90
    N = length(colours)
    val = Ref(0.0f0)
    w = LED(label, angle, length_, breadth, N, colours, Float32(fillratio), Float32(gamma), nothing, nothing, val)
    @async begin
        try
            while true
                v = take!(source)
                val[] = v
                #println("LED[$label] value ", v)
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


function render(led :: LED, panel :: Panel)
    horizontal = led.angle == 0
    vertical = led.angle == 90
    led_width = horizontal ? led.length : led.breadth
    led_height = vertical ? led.length : led.breadth
    box = GtkBox(vertical ? :v : h)
    label = GtkLabel(led.label)
    valdisp = GtkLabel("")
    canvas = GtkCanvas(led_width, led_height)
    push!(box, vertical ? valdisp : label)
    push!(box, canvas)
    push!(box, vertical ? label : valdisp)
    led.canvas[] = canvas
    led.valdisp[] = valdisp
    gamma = led.gamma
    
    @guarded draw(canvas) do widget
        #println("In LED draw")
        ctx = getgc(canvas)
        h = height(canvas)
        w = width(canvas)
        rectangle(ctx, 0, 0, w, h)
        set_source_rgb(ctx, 0, 0, 0)
        fill(ctx)
        v = led.value[]
        #println("Draw LED value ", v)
        ledw = w / led.numsteps
        ledh = h / led.numsteps
        ledfillw = led.fillratio * ledw
        ledfillh = led.fillratio * ledh
        for i in 1:led.numsteps
            x0 = vertical ? (1.0 - led.fillratio) * w/2 : (i-1) * ledw + (1.0 - led.fillratio) * ledw / 2
            y0 = vertical ? (led.numsteps - i) * ledh + (1.0 - led.fillratio) * ledh / 2 : (1.0 - led.fillratio) * h/2 
            x1 = vertical ? w - x0 : x0 + ledfillw
            y1 = vertical ? y0 + ledfillh : h - y0
            c = led.colours[i]
            rectangle(ctx, x0, y0, x1-x0, y1-y0)
            vmin = (i-1)/led.numsteps
            vmax = i/led.numsteps
            alpha = (max(vmin, min(vmax, v)) - vmin) / (vmax - vmin)
            set_source_rgba(ctx, c.r, c.g, c.b, (alpha ^ gamma) * c.alpha)
            fill(ctx)
        end
    end

    panel.widgetof[led] = box
    return box
end

