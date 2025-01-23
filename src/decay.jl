mutable struct Decay{R <: Signal} <: Signal
    rate :: R
    attack_secs :: Float64
    logval :: Float32
end

"""
    decay(rate :: Signal)

Produces a decaying exponential signal with a "half life" determined
by 1/rate. It starts with 1.0. The signal includes a short attack
at the start to prevent glitchy sounds.
"""
decay(rate :: Signal; attack_secs = 0.005) = Decay(rate, attack_secs, 0.0f0)

done(s :: Decay, t, dt) = s.logval < -15.0f0 || done(s.rate, t, dt)

function value(s :: Decay, t, dt)
    if t < s.attack_secs return t / s.attack_secs end
    v = 2^(s.logval)
    s.logval -= value(s.rate, t, dt) * dt
    return v
end


