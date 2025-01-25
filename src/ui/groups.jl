struct HGroup
    label::String
    children::Vector{Any}
end

struct VGroup
    label::String
    children::Vector{Any}
end

function render(g::HGroup, panel::Panel)
    frame = GtkFrame(g.label)
    box = GtkBox(:h)
    box.margin_top = 10
    box.margin_bottom = 10
    box.margin_start = 10
    box.margin_end = 10
    
    for child in g.children
        widget = render(child, panel)
        push!(box, widget)
    end
    
    frame.child = box
    panel.widgetof[box] = frame
    return frame
end

function render(g::VGroup, panel::Panel)
    frame = GtkFrame(g.label)
    box = GtkBox(:v)
    box.margin_top = 10
    box.margin_bottom = 10
    box.margin_start = 10
    box.margin_end = 10
    
    for child in g.children
        widget = render(child, panel)
        push!(box, widget)
    end
    
    frame.child = box
    panel.widgetof[box] = frame
    return frame
end


