
using WebIO
using JSExpr
using Observables
using UUIDs

function twodec(n::Real)
    round(Int, n * 100) / 100
end

const ConfigDict = Dict{String,String}

"""
    struct UI{Renderable}

Implement `renderui(::T,::ConfigDict)` for any particular renderable you wish
to make available in Jupyter Lab/Notebook.
"""
struct UI{Renderable}
    renderable::Renderable
    config::ConfigDict
end

@WebIO.register_renderable UI

renderui(m, config::ConfigDict) = @error "Unimplemented render for $(typeof(m))"

function WebIO.render(u::UI)
    renderui(u.renderable, u.config)
end


"""
    ui(::T, config::Dict{String,String})
    ui(::T; kvpairs...)

constructs a renderable suitable for use with WebIO.
If T is itself a `UI`, then it is just returns that.
"""
ui(x, config::ConfigDict=ConfigDict()) = UI(x, config)
#ui(x; kvpairs...) = begin
#    config = ConfigDict(string(p[1]) => p[2] for p in kvpairs)
#    UI(x, config)
#end
ui(x::UI) = x

const stdmargin = Dict("margin-left" => "5px")
const valstyle = Dict("border" => "1px solid black",
                      "padding" => "5px",
                      "display" => "inline-block",
                      stdmargin...)


function twodecspan(n::Real)
    dom"span"(string(twodec(n)); style=stdmargin)
end

function labelspan(label)
    if length(label) > 0
        dom"span"(label * ":"; style=Dict("margin-right" => "5px"))
    else
        label
    end
end

"""
    renderui(c::Control{<:Tuple{Real,Real}}, config::ConfigDict)

Implements a continuous control slider for the control signal, so its value can
be set using the UI. You don't need to call this function explicitly, but
Jupyter notebook and lab will automatically displayed when a cell's value is a
`Control`.

Supports the `"label"` configuration to change the label of the control
(see [`uiconf`](@ref "Synth.uiconf")).
"""
function renderui(c::Control{<:Tuple{Real,Real}}, config::ConfigDict)
    label = get(config, "label", c.label)
    scope = Scope()
    obs = Observable(scope, "control", c.latestval)
    on(obs) do v
        c[] = v
    end
    scope(
          dom"div"(
                   labelspan(label),
                   twodecspan(c.range[1]),
                   dom"input"(
                              events = Dict(
                                            "input" => @js (event) -> begin
                                                # We want to update the value immediately
                                                # instead of waiting for the user to be sure
                                                # of the value.
                                                $obs[] = parseFloat(event.target.value);
                                            end
                                           ),
                              attributes = Dict(
                                                :type => "range",
                                                :min => c.range[1],
                                                :max => c.range[2],
                                                :step => "any",
                                                :value => c.latestval
                                               ),
                              style = stdmargin
                             ),
                   twodecspan(c.range[2]),
                   dom"span"(map(twodec, obs); style=valstyle)
                  )
         )
end
    
"""
    renderui(c::Control{<:StepRangeLen}, config::ConfigDict)

For this control value that can be set only in steps, the corresponding UI will
also present a stepped slider. You don't need to call this function explicitly,
but Jupyter notebook and lab will automatically displayed when a cell's value
is a `Control`.

Supports the `"label"` configuration to change the label of the control
(see [`uiconf`](@ref "Synth.uiconf")).
"""
function renderui(c::Control{<:StepRangeLen}, config::ConfigDict)
    label = get(config, "label", c.label)
    scope = Scope()
    obs = Observable(scope, "control", c.latestval)
    on(obs) do v
        c[] = v
    end
    scope(
          dom"div"(
                   labelspan(label),
                   twodecspan(c.range[1]),
                   dom"input"(
                              events = Dict(
                                            "input" => @js (event) -> begin
                                                # We want to update the value immediately
                                                # instead of waiting for the user to be sure
                                                # of the value.
                                                $obs[] = parseFloat(event.target.value);
                                            end
                                           ),
                              attributes = Dict(
                                                :type => "range",
                                                :min => c.range[1],
                                                :max => c.range[end],
                                                :step => c.range.step,
                                                :value => c.latestval
                                               ),
                              style = stdmargin
                             ),
                   twodecspan(c.range[end]),
                   dom"span"(map(twodec, obs); style=valstyle)
                  )
         )
end


function renderui(items::AbstractVector, config::ConfigDict)
    nodes = WebIO.render.(ui.(items))
    style = get(config, "style", Dict())
    attributes = get(config, "attributes", Dict())
    dom"div"(nodes...; style, attributes)
end


function mkid(base::AbstractString)
    base * "_" * replace(string(uuid7()), "-" => "_")
end

"""
Supports the `"label"` configuration to change the label of the control
(see [`uiconf`](@ref "Synth.uiconf")).
"""
function renderui(m::Monitor, config::ConfigDict)
    label = get(config, "label", m.label)
    scope = Scope()
    obs = Observable(scope, "monitor", dispval(m))
    on(m) do v
        obs[] = v
    end
    id = mkid("mon_")
    idval = id * "_val"
    onjs(obs,
         @js function (newvalue)
             @var canvas = document.getElementById($id)
             @var ctx = canvas.getContext("2d")
             @var w = 0
             @var h = 0
             @var dx = 3
             @var dy = 3
             @var dw = 0
             @var dh = 0
             @var y = 0
             @var o = 0
             @var r = 0
             @var scaledval = 0
             @var val

             console.log("newvalue = ", newvalue, newvalue <= 0 ? "<=0" : ">0")
             w = canvas.width
             h = canvas.height
             dw = w - 2dx
             dh = h - 2dy
             ctx.fillStyle = "black"
             ctx.fillRect(0, 0, w, h)
             scaledval = (newvalue + 80) / 80
             y = Math.min(scaledval, 0.75)
             ctx.fillStyle = "yellow"
             ctx.fillRect(dx, dy, y * dw, dh)
             if scaledval > 0.75
                 o = Math.min(scaledval, 0.9)
                 ctx.fillStyle = "orange"
                 ctx.fillRect(dx + 0.75 * dw, dy, (o-0.75) * dw, dh)
                 if scaledval > 0.9
                     r = Math.min(scaledval, 1.0)
                     ctx.fillStyle = "red"
                     ctx.fillRect(dx + 0.9 * dw, dy, (r-0.9) * dw, dh)
                 end
             end
             val = document.getElementById($idval)
             val.innerHTML = "" + (Math.round(100*newvalue)/100)
         end)

    scope(
          dom"div"(
                   dom"span"(label),
                   dom"canvas"(;
                               attributes=Dict(
                                               "id"=>id,
                                               "width"=>"150",
                                               "height"=>"25"
                                              ),
                               style=Dict("display" => "inline", stdmargin...)
                              ),
                   dom"span"("";
                             attributes=Dict("id" => idval),
                             style=stdmargin
                            ),
                   dom"span"("dB"; style=valstyle)
                  )
         )
end


"""
    renderui(m::WaveProbe, config::ConfigDict)

Supports configuring using [`uiconf`](@ref "Synth.uiconf"). Attributes
are `"width"`, `"height"` and `"colour"`.
"""
function renderui(m::WaveProbe, config::ConfigDict)
    width = parse(Int, get(config, "width", "320"))
    height = parse(Int, get(config, "height", "120"))
    colour = get(config, "colour", get(config, "color", "yellow"))

    scope = Scope()
    obs = Observable(scope, "monitor", dispval(m))
    on(m) do v
        obs[] = Dict(
                     "t1" => v.span[1],
                     "tend" => v.span[1] + v.span.step * length(v.samples),
                     "dt" => v.span.step,
                     "samples" => v.samples
                    )
    end
    id = mkid("wave_")
    onjs(obs,
         js"""(function (au) {
             let canvas = document.getElementById($id);
             let ctx = canvas.getContext("2d");
             let w = canvas.width;
             let h = canvas.height;
             let z = h/2;
             let scale = (h-10)/2;
             let N = au.samples.length;
             canvas.fillStyle = "black";
             canvas.fillRect(0, 0, w, h);

             if (w >= Math.floor(N/2)) {
                 ctx.strokeStyle = colour
                 ctx.beginPath()
                 ctx.moveTo(0, z - scale * au.samples[0])
                 for (let i = 1; i < N; ++i) {
                     ctx.lineTo(i*w/N, z - scale * au.samples[i]);
                 }
                 ctx.stroke()
             } else {
                 ctx.strokeStyle = colour
                 ctx.lineWidth = 1
                 ctx.beginPath()
                 for (let i = 0; i < w; ++i) {
                     let j1 = Math.floor(i * N / w);
                     let j2 = Math.round((i+1) * N / w);
                     let minval = 1000.0;
                     let maxval = -1000.0;
                     for (let j = j1; j < j2; ++j) {
                         minval = Math.min(minval, au.samples[j]);
                         maxval = Math.max(maxval, au.samples[j]);
                     }
                     ctx.moveTo(i, z - scale * minval);
                     ctx.lineTo(i, z - scale * maxval);
                 }
                 ctx.stroke()
             }
         })""")
    scope(
          dom"div"(
                   dom"canvas"(attributes=Dict("width" => width, "height" => height, "id" => id))
                  )
         )
end


