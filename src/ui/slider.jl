struct Slider <: KeyOperated
    onchanged::Function
    label::String
    angle::Int
    length::Int
    minval::Float32
    maxval::Float32
    step::Float32
end

function Slider(ctrl::Synth.Control, label, angle, length, minval, maxval, step)
    onchanged(s::Slider, v) = begin
        ctrl[] = v
    end
    Slider(onchanged, label, angle, length, minval, maxval, step)
end

function adjust_control!(panel::Panel, k::KeyOp{Slider}, dx, dy)
    s = panel.widgetof[k.slider]
    v = s.adjustment.value
    new_value = min(k.slider.maxval, max(k.slider.minval, v + 0.01 * dy * k.speed))
    s.adjustment.value = new_value
end

function render(s::Slider, panel::Panel)
    box = s.angle == 0 ? GtkBox(:h) : GtkBox(:v)
    box.spacing = 5
    
    label = GtkLabel(s.label)
    
    adjustment = GtkAdjustment(
        s.minval,       # value
        s.minval,       # lower
        s.maxval,       # upper
        s.step,         # step_increment
        s.step,         # page_increment
        0.0             # page_size
    )
    
    scale = GtkScale(:h, adjustment)
    if s.angle == 90
        # For vertical orientation, we need to set the orientation
        # and flip the widget
        scale = GtkScale(:v, adjustment)
        scale.inverted = true
    end
    
    scale.digits = 2
    scale.width_request = s.angle == 0 ? s.length : -1
    scale.height_request = s.angle == 90 ? s.length : -1
    
    value_label = GtkLabel(@sprintf("%.2f", s.minval))
    
    signal_connect(scale, "value-changed") do widget
        current_value = widget.adjustment.value
        value_label.label = @sprintf("%.2f", current_value)
        s.onchanged(s, current_value)
    end
    
    if s.angle == 0
        push!(box, label)
        push!(box, scale)
        push!(box, value_label)
    else
        push!(box, value_label)
        push!(box, scale)
        push!(box, label)
    end
    
    panel.widgetof[s] = scale
    return box
end

function sink(::Type{Slider}, c :: Synth.Control)
    (s::Slider,v) -> c[] = v
end

function sink(::Type{Slider}, chan::Channel{Float32})
    (s::Slider, v) -> put!(chan, v)
end

function render(k::KeyOp{Slider}, panel::Panel)
    w = render(k.slider, panel)
    push!(panel.keyops, k)
    return w
end


