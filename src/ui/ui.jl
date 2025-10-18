module UI

import Synth
using Gtk4
import Cairo
using Printf

RGBA = Gtk4.RGBA{Float32}

abstract type KeyOperated end

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

include("slider.jl")
include("led.jl")
include("level.jl")

end
