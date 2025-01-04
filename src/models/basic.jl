
"""
    tone(amp, freq, duration; attackfactor = 2.0, attack_secs = 0.005, decay_secs = 0.05, release_secs = 0.2)

A simple sine tone modulator by an ADSR envelope. `amp` is the amplitude of the
sustain portion, `freq` is the Hz value of the frequency of the tone and `duration`
is the duration in seconds of the sustain portion.

# Envelope characteristics
- `attackfactor` - the factor (usually > 1.0) that multiplies the amplitude value to 
  determine the peak of the attack portion of the envelope.
- `attack_secs` - the duration of the attack portion. This should be kept short in general.
- `decay_secs` - the duration of the portion of the envelope where it decays from the
  peak attack value down to the sustain level.
- `release_secs` - the "half life" of the release portion of the envelope. Over this time,
  the amplitude of the signal will decay by a factor of 2.
"""
function tone(amp, freq, duration; attackfactor = 2.0, attack_secs = 0.005, decay_secs = 0.05, release_secs = 0.2)
    env = adsr(amp * attackfactor, attack_secs, decay_secs, amp, duration, release_secs) 
    sinosc(env, phasor(freq))
end

heterodyne(sig, fc, bw) = lpf(sinosc(sig, phasor(fc)), bw, 5.0)

"""
    basicvocoder(sig, f0, N, fnew; bwfactor = 0.2, bwfloor = 20.0)

A simple vocoder for demo purposes. Takes \\(N\\) evenly spaced frequencies \\(k f_0\\) and moves
them over to a new set of frequencies \\(k f_{\text{new}}\\) using a heterodyne filter. 
The `bwfactor` setting gives the fraction of the inter-frequency bandwidth to filter in.
The bandwidth has a floor given by `bwfloor` in Hz.
"""
function basicvocoder(sig, f0, N, fnew; bwfactor = 0.2, bwfloor = 20.0)
    asig = aliasable(sig)
    bw = max(bwfloor, f0 * bwfactor)
    reduce(+, sinosc(heterodyne(asig, f0 * k, bw * k), phasor(fnew * k)) for k in 1:N)
end
