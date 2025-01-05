mutable struct Noise{RNG <: AbstractRNG, Amp <: Signal} <: Signal
    rng :: RNG
    amp :: Amp
end

"""
    noise(rng :: RNG, amp :: A) where {RNG <: AbstractRNG, A <: Signal}
    noise(rng :: RNG, amp :: Real) where {RNG <: AbstractRNG}

Amplitude modulatable white noise generator.
"""
function noise(rng :: RNG, amp :: A) where {RNG <: AbstractRNG, A <: Signal}
    Noise(rng, amp)
end,
function noise(rng :: RNG, amp :: Real) where {RNG <: AbstractRNG}
    Noise(rng, konst(amp))
end

done(s :: Noise, t, dt) = done(s.amp, t, dt)

function value(s :: Noise, t, dt)
    2.0 * value(s.amp, t, dt) * (rand(s.rng) - 0.5)
end


