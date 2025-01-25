# Rest of type definitions unchanged...
struct Key <: ControlUI
    onclicked::Function
    label::String
    key::String
end

"""
    Key(onclicked::Function, label::String, k::String) :: ControlUI

Produces a button with the given `label` that will also respond to the
given key press denoted by `k`. When the button is clicked or its
corresponding key is pressed, the `onclicked` callback is called with
one argument like this -- `onclicked(::ControlUI)`.
"""
function Key(onclicked::Function, label::String, k::String)
    Key(onclicked, label, k)
end

function render(k::Key, panel::Panel)
    btn = GtkButton(k.label * " (" * k.key * ")")
    
    action = Gtk4.GtkShortcut(
        Gtk4.ShortcutTrigger(k.key),
        Gtk4.ShortcutAction() do
            k.onclicked(k)
            nothing
        end
    )
    
    shortcut_controller = Gtk4.ShortcutController(parent.window)
    shortcut_controller.scope = Gtk4.ShortcutController.GLOBAL
    push!(shortcut_controller.shortcuts, action)
    
    signal_connect(btn, "clicked") do widget
        k.onclicked(k)
    end
    
    panel.widgetof[k] = btn
    return btn
end


