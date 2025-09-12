
#=
function wah(m1,m2,m3,f)
    w1 = sinosc(1.0, m1) * sinosc(0.5, f)
    w2 = sinosc(1.0, m2) * sinosc(0.5, 2 * f)
    w3 = sinosc(1.0, m3) * sinosc(0.5, 3 * f)
    m = w1 + w2 + w3
end
=#



function model(a,f)
    af = fanout(f)
    ff = sinosc(0.1 * af, phasor(0.25 * af))
    sinosc(a, phasor(af + ff))
end

function heterodyne(sig, fc, bw)
    sigm = sinosc(sig, phasor(fc))
    lpf(sigm, bw, 5.0)
end

function vocoder(sig, f0, N, fnew)
    asig = fanout(sig)
    bw = min(20.0, f0 * 0.1, fnew * 0.1)
    reduce(+, sinosc(heterodyne(asig, f0 * k, bw), phasor(fnew * k)) for k in 1:N)
end


function note(amp, freq, dur)
    env1 = adsr(amp * 2.0, 0.01, 0.05, amp, dur, 0.2) 
    env2 = adsr(amp * 2.0, 0.01, 0.05, amp, dur, 0.1) 
    sinosc(env1, phasor(freq, 0.0)) + 0.5 * sinosc(env2, phasor(freq * 2.0, 0.0)) 
end

function note(amp, freq, dur, spectrum)
    envs = [adsr(a * amp * 2.0, 0.01, 0.05, a * amp, dur, 0.2 / f) for (a,f) in spectrum]
    phasors = [phasor(freq * f) for (a,f) in spectrum]
    oscs = sinosc.(envs, phasors)
    return sum(oscs)
end

function noteseq(tempo, amp, freqs, dur)
    amp * seq(clock_bpm(tempo), [(1.0, note(0.5, f, dur)) for f in freqs])
end
