struct Panel
    app::GtkApplication
    window::GtkWindow
    widgetof::Dict{Any,GtkWidget}
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

function makepanel(app::GtkApplication)
    window = GtkApplicationWindow(app)
    window.title = "Control Panel"
    p = Panel(app, window, Dict(), [], Set([]))
    setup!(p)
    return p
end

function harnessed(testfn, app::GtkApplication)
    panel = makepanel(app)
    spec = testfn()
    widget = render(spec, panel)
    panel.window.child = widget
    show(panel.window)
end


