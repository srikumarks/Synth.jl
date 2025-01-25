module UI

import Synth
using Gtk4
using Printf

RGBA = Gtk4.RGBA{Float32}

abstract type ControlUI end
abstract type KeyOperated <: ControlUI end

struct KeyOp{W <: KeyOperated, S <: AbstractSet{Int}}
    keycode:: Int
    modifiers::S
    speed::Float32
    Slider::W
end


include("panel.jl")
include("key.jl")
include("utils.jl")
include("slider.jl")
include("led.jl")
include("level.jl")
include("groups.jl")

# Test functions remain largely the same
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
    s1 = Slider("one", 90, 150, 0.0f0, 1.0f0, 0.01f0) do s::Slider, v
        println("one's value is now ", v) 
    end
    s2 = Slider("two", 90, 150, 0.0f0, 1.0f0, 0.01f0) do s::Slider, v
        println("two's value is now ", v) 
    end
    HGroup("Sliders", [s1,s2])
end

function test3()
    s1 = Slider("one", 90, 150, 0.0f0, 1.0f0, 0.01f0) do s::Slider, v
        println("one's value is now ", v) 
    end
    s2 = Slider("two", 90, 150, 0.0f0, 1.0f0, 0.01f0) do s::Slider, v
        println("two's value is now ", v) 
    end
    HGroup("Sliders", [
                       KeyOp(Gtk4.KEY_c, BitSet(), 1f0, s1),
                       KeyOp(Gtk4.KEY_v, BitSet(), 1f0, s2)
                      ])
end

src = Channel{Float32}(2)

function test4()
    y = RGBA(1.0f0, 1.0f0, 0.0f0, 1.0f0)
    o = RGBA(1.0f0, 0.65f0, 0.0f0, 1.0f0)
    r = RGBA(1.0f0, 0.0f0, 0.0f0, 1.0f0)
    led("blinker", 90, 200, 40, vcat(repeat([y], 9), repeat([o],3), repeat([r], 2)), src)
end

function test_main()
    app = GtkApplication("com.example.app", 0)
    signal_connect(app, :activate) do app
        harnessed(test4, app)
    end
    @async begin
        for i in 1:1000
            sleep(0.002)
            put!(src, 0.5*(1.0+sin((i-1) * 0.001 * 48.0)))
        end
    end
    run(app)
end

end
