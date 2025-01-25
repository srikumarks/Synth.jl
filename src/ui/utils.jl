function keymods(mod1::Symbol, mods...)
    b = BitSet([])
    for m in vcat(mods,[mod1])
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


