using Observables
using ..Synth: TimedSamples, Probe, source

struct Waveform
    label::String
    width::Int
    height::Int
    bkgcolour::RGBA
    wavecolour::RGBA
    canvas::Ref{Union{Nothing,GtkCanvas}}
    val::Observable{TimedSamples}
    conn::Ref{Union{Nothing,ObserverFunction}}
end

function Observables.connect!(wf::Waveform, p::Probe{TimedSamples})
    obs = source(p)
    # Only one source may send to the waveform.
    if !isnothing(wf.conn[])
        off(wf.conn[])
        wf.conn[] = nothing
    end
    wf.conn[] = on(obs; weak=true) do val
        wf.val[] = val
    end
end

function render(wf::Waveform, panel::Panel)
    @debug "Rendering waveform box"
    box = GtkBox(:v)
    label = GtkLabel(wf.label)
    canvas = GtkCanvas(wf.width, wf.height)
    push!(box, canvas)
    push!(box, label)
    wf.canvas[] = canvas

    maxs = zeros(Float32, round(Int,wf.width))
    mins = zeros(Float32, round(Int,wf.width))
    @debug "Waveform box dimensions" width=wf.width height=wf.height

    @guarded draw(canvas) do widget
        @debug "Drawing..."
        ctx = Gtk4.getgc(widget)
        w ::Int = round(Int, Gtk4.width(widget))
        h ::Int = round(Int, Gtk4.height(widget))
        tv = wf.val[]
        t = tv.span
        v = tv.samples
        @debug "Received timed samples" len=length(t)

        label.label = @sprintf("[%s] %f : %f == %d : %d", wf.label, t[1], t[end], floor(Int, t[1] / Float64(t.step)), ceil(Int, t[end]/Float64(t.step)))
        Cairo.rectangle(ctx, 0, 0, w, h)
        Cairo.set_source_rgb(ctx, wf.bkgcolour.r, wf.bkgcolour.g, wf.bkgcolour.b)
        Cairo.fill(ctx)

        N = length(v)
        x0 = 0.0f0
        y0 = h/2.0f0
        dy :: Float64 = h * 0.4
        if w != length(maxs)
            maxs = zeros(Float32,w)
            mins = zeros(Float32,w)
        end
        if N > w
            for i in 0:w-1
                i1 = div(i * N, w)
                i2 = div((i+1)*N, w)
                (mn,mx) = extrema(view(v, i1+1:i2))
                maxs[i+1] = Float32(dy * mx)
                mins[i+1] = Float32(dy * mn)
            end
            @debug "Extrema" diff=sum(maxs .>= mins) total=length(maxs)

            # We treat the drawn waveform as a path that runs along all
            # the minima and turns around and runs back along all the maxima
            # and then we fill out the whole polygon.
            Cairo.new_path(ctx)
            Cairo.move_to(ctx, x0, y0 - mins[1])
            for i in 2:w
                Cairo.line_to(ctx, x0 + i-1, y0 - mins[i])
            end
            for i in w:-1:1
                Cairo.line_to(ctx, x0 + i-1, y0 - maxs[i])
            end
            Cairo.close_path(ctx)
            Cairo.set_source_rgb(ctx, wf.wavecolour.r, wf.wavecolour.g, wf.wavecolour.b)
            Cairo.stroke(ctx)
            Cairo.fill(ctx)
        else
            # For other cases, we draw a linearly interpolated waveform.
            Cairo.new_path(ctx)
            Cairo.move_to(ctx, x0, y0 - dy * v[1])
            for i in 2:length(v)
                Cairo.line_to(ctx, x0 + i-1, y0 - dy * v[i])
            end
            Cairo.set_source_rgb(ctx, wf.wavecolour.r, wf.wavecolour.g, wf.wavecolour.b)
            Cairo.stroke(ctx)
        end

        # Draw the clip bounds
        Cairo.rectangle(ctx, x0, y0 - dy - 1.0f0, w, 2.0f0)
        Cairo.set_source_rgb(ctx, 1.0f0, 0.0f0, 0.0f0)
        Cairo.stroke(ctx)
        Cairo.rectangle(ctx, x0, y0 + dy, w, 2.0f0)
        Cairo.set_source_rgb(ctx, 1.0f0, 0.0f0, 0.0f0)
        Cairo.stroke(ctx)
    end

    panel.widgetof[wf] = box
    return box
end

"""
"""
function Waveform(
        label::String,
        width::Int,
        height::Int,
        bkgcolour::RGBA = RGBA(0.0f0, 0.0f0, 0.0f0, 1.0f0),
        wavecolour::RGBA = RGBA(0.4196f0, 0.7961f0, 0.4588f0, 1.0f0)
    )
    obs = Observable{TimedSamples}(TimedSamples())
    wf = Waveform(
                  label,
                  width,
                  height,
                  bkgcolour,
                  wavecolour,
                  nothing,
                  obs,
                  nothing
                 )
    on(obs) do tv
        try
            @debug "TimedSamples received by waveform box" len=(length(tv.span), length(tv.samples)) min=minimum(tv.samples) max=maximum(tv.samples)
            if !isnothing(wf.canvas[])
                draw(wf.canvas[])
            end
        catch e
            @error "WaveProbe draw error" error=(e, catch_backtrace())
        end
    end
    return wf
end



