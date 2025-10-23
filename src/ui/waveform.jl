
const TimeSpan = StepRangeLen{Float64}
const TimedSamples = @NamedTuple{span :: TimeSpan, samples :: Vector{Float32}}

struct Waveform
    label::String
    width::Int
    height::Int
    bkgcolour::RGBA
    wavecolour::RGBA
    canvas::Ref{Union{Nothing,GtkCanvas}}
    val::Ref{Union{Nothing,TimedSamples}}
end

function render(wf::Waveform, panel::Panel)
    box = GtkBox(:v)
    label = GtkLabel(wg.label)
    canvas = GtkCanvas(wf.width, wf.height)
    push!(box, canvas)
    push!(box, label)
    wf.canvas = canvas

    maxs = zeros(Int, wf.width)
    mins = zeros(Int, wf.width)

    @guarded draw(canvas) do widget
        ctx = Gtk4.getgc(widget)
        w = Gtk4.width(widget)
        h = Gtk4.height(widget)
        t = wf.val[1]
        v = wf.val[2]

        label.label = @sprintf("[%s] %f : %f == %d : %d", wf.label, t[1], t[end], floor(Int, t[1] / t.step), ceil(Int, t[end]/t.step))
        Cairo.rectangle(ctx, 0, 0, w, h)
        Cairo.set_source_rgb(ctx, wf.bkgcolour.r, wf.blkcolour.g, wf.bkgcolour.b)
        Cairo.fill(ctx)

       
        N = length(v)
        x0 = 0.0f0
        y0 = h/2.0f0
        dy = h * 0.4
        if w != length(maxs)
            maxs = zeros(Float32,w)
            mins = zeros(Float32,w)
        end
        if N > w
            for i in 0:w-1
                i1 = div(i * N, w)
                i2 = div((i+1)*N, w)
                (mn,mx) = extrema(view(v, i1+1:i2))
                maxs[i+1] = dy * mx
                mins[i+1] = dy * mn
            end

            # We treat the drawn waveform as a path that runs along all
            # the maxima and turns around and runs back along all the minima
            # and then we fill out the whole polygon.
            Cairo.new_path(ctxt)
            Cairo.move_to(ctxt, x0, y0 - maxs[1])
            for i in 2:w
                Cairo.line_to(ctxt, x0 + i-1, y0 - maxs[i])
            end
            for i in w:-1:1
                Cairo.line_to(ctxt, x0 + i-1, y0 - mins[i])
            end
            Cairo.close_path(ctxt)
            Cairo.set_source_rgb(ctxt, wf.wfcolour.r, wf.wfcolour.g, wf.wfcolour.b)
            Cairo.stroke(ctxt)
            Cairo.fill(ctxt)
        else
            # For other cases, we draw a linearly interpolated waveform.
            Cairo.new_path(ctxt)
            Cairo.move_to(ctxt, x0, y0 - dy * v[1])
            for i in 2:w
                Cairo.line_to(ctxt, x0 + i-1, y0 - dy * v[i])
            end
            Cairo.set_source_rgb(ctxt, wf.wfcolour.r, wf.wfcolour.g, wf.wfcolour.b)
            Cairo.stroke(ctxt)
        end

        # Draw the clip bounds
        Cairo.rectangle(ctxt, x0, y0 - dy - 1.0f0, w, 2.0f0)
        Cairo.set_source_rgb(ctxt, 1.0f0, 0.0f0, 0.0f0)
        Cairo.stroke(ctxt)
        Cairo.rectangle(ctxt, x0, y0 + dy, w, 2.0f0)
        Cairo.set_source_rgb(ctxt, 1.0f0, 0.0f0, 0.0f0)
        Cairo.stroke(ctxt)
    end

    panel.widgetof[wf] = box
    return box
end

"""
"""
function waveform(
        label::String,
        width::Int,
        height::Int,
        bkgcolour::RGBA = RGBA(0.0f0, 0.0f0, 0.0f0, 1.0f0),
        wavecolour::RGBA = RGBA(0.4196f0, 0.7961f0, 0.4588f0, 1.0f0),
        source::Channel{TimedSamples} = Channel{TimedSamples}(2)
    )
    wf = Waveform(
                  label,
                  width,
                  height,
                  bkgcolour,
                  wavecolour,
                  nothing,
                  nothing
                 )
    @async begin
        try
            while true
                val[] = take!(source)
                if !isnothing(wf.canvas[])
                    draw(wf.canvas[])
                end
            end
        catch e
            # Channel closed
            nothing
        end
    end
    return wf
end



