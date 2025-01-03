
function tone(amp, freq, duration; attackfactor = 2.0, attack = 0.005, decay = 0.05, release = 0.2)
    env = adsr(amp * attackfactor, attack, decay, amp, duration, release) 
    sinosc(env, phasor(freq, 0.0))
end
