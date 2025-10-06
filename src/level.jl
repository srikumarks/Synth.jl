
struct Level{S<:Signal} <: Signal
    s::S
    x²::Float32
    wx::Float32
    ws::Float32
    refmin::Float32
    floor::Float32
end

done(s::Level{S}, t, dt) where {S<:Signal} = done(s.s, t, dt)
function value(s::Level{S}, t, dt) where {S<:Signal}
    v = value(s.s, t, dt)
    v² = v * v
    s.x² = s.wx * s.x² + s.ws * v²
    floor + 10.0f0*log10(s.x² + refmin)
end

"""
    level(s::Signal; interval=0.015, refmin=1/(32767*32767), samplingrate=48000)

Computes the smoothed dB level of a signal. The range is from 0 to about 90dB. 

- `refmin` is the tiniest sliver of sound intensity that can be registered.
  The default is set to a value appropriate for 16-bit sampled sound.
- `interval` is the smoothing interval - i.e. the time constant of the
  first order filter that's applied on the square of the signal.

`refmin` determines the range since it is the floor of the signal that is 0dB.
For the default value, the max ends up around ``20\\log_{10}(32767) \\approx 90.309\\text{dB}``.
A factor of two change in amplitude is a change in level of around 6.021 dB.
"""
function level(s::Signal; interval = 0.015, refmin = 1/32767, samplingrate = 48000)
    wx = Float32(2^(-1/(interval*samplingrate)))
    ws = 1.0f0 - wx
    Level(s, 0.0f0, wx, ws, Float32(refmin^2), Float32(-20.0f0 * log10(refmin)))
end
