"""
    HGroup(label :: String, children :: Vector{ControlUI})

Makes a UI element that's a horizontal group of other UI elements.
The group can itself be given a text label.
"""
struct HGroup <: ControlUI
    label::String
    children::Vector{ControlUI}
end

"""
    VGroup(label :: String, children :: Vector{ControlUI})

Makes a UI element that's a vertical group of other UI elements.
The group can itself be given a text label.
"""
struct VGroup <: ControlUI
    label::String
    children::Vector{ControlUI}
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


