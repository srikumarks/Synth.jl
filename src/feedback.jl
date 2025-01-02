mutable struct Feedback <: Signal
    s :: Union{Nothing,Signal}
    last_t :: Float64
    calculating_t :: Float64
    last_val :: Float32
    last_done :: Bool
end

feedback() = Feedback(nothing, 0.0, 0.0, 0.0f0, false)

function connect(s :: S, fb :: Feedback) where {S <: Signal}
    fb.s = s
end

function done(fb :: Feedback, t, dt)
    if t <= fb.calculating_t
        return fb.last_done
    end
    out_done = fb.last_done
    if t > fb.last_t
        fb.calculating_t = t
        fb.last_done = done(fb.s, t, dt)
        fb.last_t = t
    end
    return out_done
end

function value(fb :: Feedback, t, dt)
    if t <= fb.calculating_t
        return fb.last_val
    end
    out_val = fb.last_val
    if t > fb.last_t
        fb.calculating_t = t
        fb.last_val = value(fb.s, t, dt)
        fb.last_t = t
    end
    return out_val
end


