struct Gen <: Signal
    done :: Function
    value :: Function
end

done(g :: Gen, t, dt) = d.done(t, dt)
value(g :: Gen, t, dt) = d.value(t, dt)

"""
    Gen(s :: Signal)

A general wrapper for an arbitrary signal that can hide
the signal type within underlying functions.
"""
function Gen(s :: Signal)
    gdone(t, dt) = done(s, t, dt)
    gvalue(t, dt) = value(s, t, dt)
    return Gen(gdone, gvalue)
end


