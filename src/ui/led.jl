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
    value::Ref{Float32}
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
            gamma = 0.5
            set_source_rgba(ctx, c.r, c.g, c.b, (alpha ^ gamma) * c.alpha)
            fill(ctx)
        end
    end

    panel.widgetof[led] = box
    return box
end

function led(label::String, angle::Int, length_::Int, breadth::Int, colours::Vector{RGBA}, source::Channel{Float32}; fillratio=0.5, gamma=0.5)
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


