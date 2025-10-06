module UI

import Synth
using Gtk4
import Cairo
using Printf

RGBA = Gtk4.RGBA{Float32}

abstract type KeyOperated end

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
Slider(ctrl::Synth.Control, label, angle, length) =
    Slider(ctrl, label, angle, length, 0.0f0, 1.0f0, 0.01f0)

struct KeyOp{W<:KeyOperated,S<:AbstractSet{Int}}
    keycode::Int
    modifiers::S
    speed::Float32
    slider::W
end

# Rest of type definitions unchanged...
struct Key
    onclicked::Function
    label::String
    key::String
end

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

struct HGroup
    label::String
    children::Vector{Any}
end

struct VGroup
    label::String
    children::Vector{Any}
end

struct Panel
    app::GtkApplication
    window::GtkWindow
    widgetof::Dict{Any,GtkWidget}
    keyops::Vector{KeyOp}
    active_keyops::Set{Int}
end

function keymods(mod1::Symbol, mods...)
    b = BitSet([])
    for m in vcat(mods, [mod1])
        if m == :shift
            push!(b, 1)
        elseif m == :control
            push!(b, 2)
        elseif m == :alt
            push!(b, 3)
        end
    end
    return b
end

function keymods(state::UInt)  # Using Int for modifier state
    b = BitSet([])
    if (ModifierType(state & Gtk4.MODIFIER_MASK) & Gtk4.ModifierType_SHIFT_MASK) != 0
        push!(b, 1)
    end
    if (ModifierType(state & Gtk4.MODIFIER_MASK) & Gtk4.ModifierType_CONTROL_MASK) != 0
        push!(b, 2)
    end
    if (ModifierType(state & Gtk4.MODIFIER_MASK) & Gtk4.ModifierType_ALT_MASK) != 0
        push!(b, 3)
    end
    return b
end

function adjust_control!(panel::Panel, k::KeyOp{Slider}, dx, dy)
    s = panel.widgetof[k.slider]
    v = s.adjustment.value
    dmouse = if k.slider.angle == 0
        dx
    else
        dy
    end
    new_value = min(k.slider.maxval, max(k.slider.minval, v + 0.01 * dmouse * k.speed))
    s.adjustment.value = new_value
end

function setup!(panel::Panel)
    # Key controller
    key_controller = Gtk4.GtkEventControllerKey(panel.window)
    signal_connect(key_controller, "key-pressed") do controller, keyval, keycode, state
        for (i, kc) in enumerate(panel.keyops)
            if kc.keycode == keyval
                if keymods(UInt(state)) == kc.modifiers
                    push!(panel.active_keyops, i)
                end
            end
        end
        nothing
    end

    signal_connect(key_controller, "key-released") do controller, keyval, keycode, state
        for (i, kc) in enumerate(panel.keyops)
            if kc.keycode == keyval && i ∈ panel.active_keyops
                delete!(panel.active_keyops, i)
            end
        end
        nothing
    end

    # Scroll controller
    scroll_controller = Gtk4.GtkEventControllerScroll(
        Gtk4.EventControllerScrollFlags_VERTICAL,
        panel.window,
    )

    signal_connect(scroll_controller, "scroll") do controller, dx, dy
        #println("dx = ", dx, " dy = ", dy)
        for op in panel.active_keyops
            k = panel.keyops[op]
            adjust_control!(panel, k, dx, dy)
        end
        nothing
    end

    return panel
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

function LED(
    label::String,
    angle::Int,
    length_::Int,
    breadth::Int,
    colours::Vector{RGBA},
    source::Channel{Float32};
    fillratio = 0.5,
    gamma = 0.5,
)
    @assert angle == 0 || angle == 90
    N = length(colours)
    val = Ref(0.0f0)
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
    )
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

LED(label::String, angle::Int, length_::Int, source::Channel{Float32}) =
    LED(label, angle, length_, div(length_, 5), stdleds(), source)

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
    LED(label, angle, length_, div(length_, 5), stdlevelcolours(), source)


function render(k::Key, panel::Panel)
    btn = GtkButton(k.label * " (" * k.key * ")")

    action = Gtk4.GtkShortcut(Gtk4.ShortcutTrigger(k.key), Gtk4.ShortcutAction() do
        k.onclicked(k)
        nothing
    end)

    shortcut_controller = Gtk4.ShortcutController(parent.window)
    shortcut_controller.scope = Gtk4.ShortcutController.GLOBAL
    push!(shortcut_controller.shortcuts, action)

    signal_connect(btn, "clicked") do widget
        k.onclicked(k)
    end

    panel.widgetof[k] = btn
    return btn
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
        0.0,             # page_size
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

function sink(::Type{Slider}, c::Synth.Control)
    (s::Slider, v) -> c[] = v
end

function sink(::Type{Slider}, chan::Channel{Float32})
    (s::Slider, v) -> put!(chan, v)
end

function render(k::KeyOp{Slider}, panel::Panel)
    w = render(k.slider, panel)
    push!(panel.keyops, k)
    return w
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

function makepanel(app::GtkApplication)
    window = GtkApplicationWindow(app)
    window.title = "Control Panel"
    p = Panel(app, window, Dict(), [], Set([]))
    setup!(p)
    return p
end

end
