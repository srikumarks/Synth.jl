mutable struct ExpDecay{R <: Signal} <: Signal
    rate :: R
    attack_secs :: Float64
    logval :: Float32
end

"""
    expdecay(rate :: R) where {R <: Signal}

Produces a decaying exponential signal with a "half life" determined
by 1/rate. It starts with 1.0. The signal includes a short attack
at the start to prevent glitchy sounds.
"""
expdecay(rate :: R; attack_secs = 0.005) where {R <: Signal} = ExpDecay(rate, attack_secs, 0.0f0)

done(s :: ExpDecay, t, dt) = s.lval < -15.0f0 || done(s.rate, t, dt)

function value(s :: ExpDecay, t, dt)
    if t < s.attack_secs return t / s.attack_secs end
    v = 2^(s.logval)
    s.logval -= value(s.rate, t, dt) * dt
    return v
end


