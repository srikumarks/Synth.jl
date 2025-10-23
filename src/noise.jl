struct Noise{RNG<:AbstractRNG,Amp<:Signal} <: Signal
    rng::RNG
    amp::Amp
end

defaultRNG = MersenneTwister(31415)

"""
    noise(rng :: AbstractRNG, amp :: Signal)
    noise(rng :: AbstractRNG, amp :: Real = 1.0f0)
    noise(amp :: Signal)
    noise(amp :: Real = 1.0f0)

Amplitude modulatable white noise generator.
"""
function noise(rng::AbstractRNG, amp::Signal)
    Noise(rng, amp)
end, function noise(rng::AbstractRNG, amp::Real = 1.0f0)
    Noise(rng, konst(amp))
end, function noise(amp::Real = 1.0f0)
    Noise(defaultRNG, konst(amp))
end, function noise(amp::Signal)
    Noise(defaultRNG, amp)
end

done(s::Noise, t, dt) = done(s.amp, t, dt)

function value(s::Noise, t, dt)
    2.0 * value(s.amp, t, dt) * (rand(s.rng) - 0.5)
end
