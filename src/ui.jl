using Mousetrap, Printf


struct Slider
    onchanged :: Function
    label :: String
    angle :: Int
    length :: Int
    minval :: Float32
    maxval :: Float32
    step :: Float32
end

struct KeyOp
    keycode :: KeyCode
    modifiers :: BitSet
    speed :: Float32
    slider :: Slider
end


struct Key
    onclicked :: Function
    label :: String
    key :: String
end

struct LED
    label :: String
    angle :: Int
    length :: Int
    breadth :: Int
    numsteps :: Int
    breakpts :: Vector{Int}
    colours :: Vector{Mousetrap.RGBA}
    fillratio :: Float32
end

struct Level
    label :: String
    angle :: Int
    length :: Int
    breadth :: Int
    minval :: Float32
    maxval :: Float32
    breakpts :: Vector{Float32}
    colours :: Vector{Mousetrap.RGBA}
end
    
struct HGroup
    label :: String
    children :: Vector{Any}
end

struct VGroup
    label :: String
    children :: Vector{Any}
end

struct Panel
    app :: Application
    window :: Window
    widgetof :: Dict{Any,Widget}
    keyops :: Vector{KeyOp}
    active_keyops :: Set{Int}
end

function keymods(mod1::Symbol,mods...)
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

function keymods(mods::ModifierState)
    b = BitSet([])
    if shift_pressed(mods) push!(b, 1) end
    if control_pressed(mods) push!(b, 2) end
    if alt_pressed(mods) push!(b, 3) end
    return b

function setup!(panel :: Panel)
    kc = KeyEventController()
    function on_key_pressed(self::KeyEventController, code::KeyCode, modkeys::ModifierState) ::Nothing
        for (i,kc) in enumerate(panel.keyops)
            if kc.keycode == code
                if keymods(modkeys) == kc.modifiers
                    push!(panel.active_keyops, i)
                end
            end
        end
        nothing
    end
    function on_key_released(self::KeyEventController, code::KeyCode, modkeys::ModifierState) ::Nothing
        for (i,kc) in enumerate(panel.keyops)
            if kc.keycode == code && i ∈ panel.active_keyops
                pop!(panel.active_keyops, i)
            end
        end
        nothing
    end
    connect_signal_key_pressed!(on_key_pressed, kc)
    connect_signal_key_released!(on_key_released, kc)
    add_controller!(panel.window, kc)

    function on_scroll(self::ScrollEventController, x_delta::AbstractFloat, y_delta::AbstractFloat) ::Nothing
        for op in panel.active_keyops
            k = panel.keyops[op]
            s = panel.widgetof[k.slider]
            v = get_value(s)
            set_value!(s, min(k.slider.maxval, max(k.slider.minval, v + y_delta * 0.01 * k.speed)))
        end
        nothing
    end

    scroll_controller = ScrollEventController()
    connect_signal_scroll!(on_scroll, scroll_controller)
    add_controller!(panel.window, scroll_controller)
    panel
end

function render(k :: Key, panel :: Panel) :: Widget
    b = Button()
    set_child!(b, Label("$(k.label) ($(k.key))"))
    action = Action(k.label * ".clicked", panel.app)
    set_function!(action) do x::Action
        k.onclicked(k)
        nothing
    end
    add_shortcut!(action, k.key)
    set_action!(b, action)
    set_listens_for_shortcut_action!(panel.window, action)
    panel.widgetof[k] = b
    return b
end

function render(s :: Slider, panel :: Panel) :: Widget
    @assert s.angle == 0 || s.angle == 90
    orientation = if s.angle == 0 ORIENTATION_HORIZONTAL else ORIENTATION_VERTICAL end
    sc = Scale(s.minval, s.maxval, s.step, orientation)
    set_value!(sc, s.minval)
    label = Label(s.label)
    value = Label(@sprintf("%0.2f", s.minval))
    box = Box(orientation)
    if orientation == ORIENTATION_HORIZONTAL
        push_back!(box, label)
        push_back!(box, sc)
        push_back!(box, value)
        set_size_request!(sc, Vector2f(s.length, 0))
    else
        tx = TransformBin()
        set_child!(tx, sc)
        Mousetrap.rotate!(tx, degrees(180))
        push_back!(box, value)
        push_back!(box, tx)
        push_back!(box, label)
        set_size_request!(sc, Vector2f(0, s.length))
    end
    connect_signal_value_changed!(sc) do sc::Scale
        v = get_value(sc)
        set_text!(value, @sprintf("%0.2f", v))
        s.onchanged(s, v)
        nothing
    end
    panel.widgetof[s] = sc
    return box
end

function render(k :: KeyOp, panel :: Panel) :: Widget
    w = render(k.slider, panel)
    push!(panel.keyops, k)
    return w
end

function renderbox(labelstr :: String, children :: Vector, box :: FlowBox, panel :: Panel) :: Widget
    label = Label(labelstr)
    set_margin!(label, 10)
    expander = Expander(box, label)
    for c in children
        widget = render(c, panel)
        push_back!(box, widget)
    end
    set_is_expanded!(expander, true)
    f = Frame(expander)
    set_margin!(f, 10)
    panel.widgetof[box] = f
    return f
end

function render(g :: HGroup, panel :: Panel) :: Widget
    box = FlowBox(ORIENTATION_HORIZONTAL)
    renderbox(g.label, g.children, box, panel)
end

function render(g :: VGroup, panel :: Panel) :: Widget
    box = FlowBox(ORIENTATION_VERTICAL)
    renderbox(g.label, g.children, box, panel)
end

function makepanel(app::Application, theme = THEME_DEFAULT_DARK)
    set_current_theme!(app, theme)
    p = Panel(app, Window(app), Dict(), [], Set([]))
    setup!(p)
end

function harnessed(testfn, app::Application)
    panel = makepanel(app)
    spec = testfn()
    widget = render(spec, panel)
    set_child!(panel.window, widget)
    present!(panel.window)
end

function test1()
    key1 = Key("meow", "m") do k::Key
        println(k.label)
    end
    key2 = Key("bow", "b") do k::Key
        println(k.label)
    end
    HGroup("animals", [key1,key2])
end

function test2()
    s1 = Slider("one", 90, 150, 0.0f0, 1.0f0, 0.01f0) do s::Slider, v::Float32
        println("one's value is now ", v) 
    end
    s2 = Slider("two", 90, 150, 0.0f0, 1.0f0, 0.01f0) do s::Slider, v::Float32
        println("two's value is now ", v) 
    end
    HGroup("Sliders", [s1,s2])
end

function test3()
    s1 = Slider("one", 90, 150, 0.0f0, 1.0f0, 0.01f0) do s::Slider, v::Float32
        println("one's value is now ", v) 
    end
    s2 = Slider("two", 90, 150, 0.0f0, 1.0f0, 0.01f0) do s::Slider, v::Float32
        println("two's value is now ", v) 
    end
    HGroup("Sliders", [
                       KeyOp(KEY_c, Set([]), 1f0, s1),
                       KeyOp(KEY_v, Set([]), 1f0, s2)
                      ])
end

main() do app::Application
    harnessed(test3, app)
end

