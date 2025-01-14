mutable struct Feedback <: Signal
    s :: Union{Nothing,Signal}
    last_t :: Float64
    calculating_t :: Float64
    last_val :: Float32
    last_done :: Bool
end

"""
    feedback()

Constructs a feedback node which can be connected to a signal later on
after construction. This is intended to be used in feedback loops and
introduces a single sample delay to prevent infinite recursion.

You can later on connect a signal to the feedback point by calling
`connect(::Signal,::Feedback)`. Just as `aliasable` is used to make
DAG signal flow graphs possible, `feedback` is used to make graphs
with loops possible.
"""
feedback() = Feedback(nothing, 0.0, 0.0, 0.0f0, false)

"""
    connect(s :: Signal, fb :: Feedback)

Connects a signal to a feedback point.
"""
function connect(s :: Signal, fb :: Feedback)
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


