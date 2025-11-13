using ..Synth

function chorus(modDepth::Signal, effectMix::Signal, sig::Signal; baseDelay = 6000/48000)
    d = delay(sig, baseDelay * 1.414 + 2/48000)
    m1 = sinosc(1.0, 0.2)
    m2 = sinosc(1.0, 0.222222)
    t1 = tap(d, baseDelay * 0.707 * (1.0 + modDepth * m1))
    t2 = tap(d, baseDelay * 0.5 * (1.0 + modDepth * m2))
    stereo(effectMix * (t1 - sig) + sig, effectMix * (t2 - sig) + sig)
end

function jettable(sig::Signal)
    clamp(sig * (sig * sig - 1.0f0), -1.0f0, 1.0f0)
end

function blowbotl(
    sus::Signal,
    freq::Signal,
    vibratoGain::Signal,
    noiseGain::Signal;
    maxPressure::Real = 1.0f0,
    vibratoFreq = 5.925,
    q = 4.0,
)
    env = adsr(
        sus,
        0.1;
        attack_factor = 1.0,
        attack_secs = 0.005,
        decay_secs = 0.01,
        release_secs = 0.01,
    )
    breathPressure = fanout(maxPressure * env + sinosc(vibratoGain, vibratoFreq))
    resonator = feedback()
    pressureDiff = fanout(breathPressure - resonator)
    randPressure = noiseGain * noise() * breathPressure * (1.0f0 + pressureDiff)
    r = bpf0(breathPressure + randPressure - pressureDiff * jettable(pressureDiff), freq, q)
    connect(r, resonator)

    0.2 * dcblock(pressureDiff)
end

function blowbotl(sus::Signal, freq::Signal, vibratoGain::Real, noiseGain::Real; maxPressure::Real = 1.0f0)
    blowbotl(sus, freq, konst(vibratoGain), konst(noiseGain); maxPressure)
end


function blowbotl(sus::Signal, freq::Real, vibratoGain::Real, noiseGain::Real; maxPressure::Real = 1.0f0)
    blowbotl(sus, konst(freq), vibratoGain, noiseGain; maxPressure)
end
