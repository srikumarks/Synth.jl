
mutable struct Follow{S :< Signal, R <: Signal}
    sig :: S
    rate :: R
    v :: Float32
end

done(s :: S, t, dt) where {S <: Signal} = done(s.sig, t, dt)

function value(s :: Follow{S,R}, t, dt) where {S <: Signal, R <: Signal}
    v = value(s.sig, t, dt)
    r = value(s.rate, t, dt)
    if v > s.v
        # Follow on the way up.
        s.v = v
    else
        # Decay on the way down.
        frac = 2^(-r*dt)
        s.v = s.v * frac + (1-frac) * v
    end
    return s.v
end

"""
    follow(s :: S, rate :: R) where {S <: Signal, R <: Signal}

Follows a signal on the rise and decays on the fall.
This means if the input signal is an impulse, then 
you'll get a series of exponential decays on each of
the impulses.
"""
function follow(s :: S, rate :: R) where {S <: Signal, R <: Signal}
    Follow(s, rate, 0.0f0)
end

