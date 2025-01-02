"""
Can be used to hide an underlying signal via dynamic dispatch.
"""
struct Gen <: Signal
    done :: Function
    value :: Function
end

done(g :: Gen, t, dt) = d.done(t, dt)
value(g :: Gen, t, dt) = d.value(t, dt)
function Gen(s :: S) where {S <: Signal}
    gdone(t, dt) = done(s, t, dt)
    gvalue(t, dt) = value(s, t, dt)
    return Gen(gdone, gvalue)
end


