struct Panel
    app::GtkApplication
    window::GtkWindow
    widgetof::Dict{ControlUI,GtkWidget}
    keyops::Vector{KeyOp}
    active_keyops::Set{Int}
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
    scroll_controller = Gtk4.GtkEventControllerScroll(Gtk4.EventControllerScrollFlags_VERTICAL, panel.window)
    
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

"""
    makepanel(app::GtkApplication) :: Panel

Makes a "panel" structure used by the GUI to keep relevant objects and
state for its operation. Constructs the panel and sets it up at one shot.

To show a panel, you need to do the following.

- Call `makepanel` to make a `Panel` structure for the application.
- Create `ControlUI` you want to place into the panel.
- Call `widget = render(ui, panel)` to render the `ControlUI` to a widget.
- Make the widget the only child of the panel's window using `panel.window.child = widget`
- Show the panel using `show(panel.window)`

The above steps are encapsulated in [`Synth.UI.show!`](@ref).
"""
function makepanel(app::GtkApplication)
    window = GtkApplicationWindow(app)
    window.title = "Control Panel"
    p = Panel(app, window, Dict(), [], Set([]))
    setup!(p)
    return p
end

"""
    show!(panel :: Panel, spec :: ControlUI)

Use to display the given `ControlUI` spec on the given panel.
"""
function show!(panel :: Panel, spec :: ControlUI)
    widget = render(spec, panel)
    panel.window.child = widget
    show(panel.window)
end

function harnessed(testfn, app::GtkApplication)
    panel = makepanel(app)
    show!(panel, testfn())
end


