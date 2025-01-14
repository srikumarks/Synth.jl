mutable struct ADSR{Sus <: Signal} <: Signal
    attack_level :: Float32
    attack_secs :: Float32
    decay_secs :: Float32
    sustain_level :: Sus
    sustain_secs :: Float32
    release_secs :: Float32
    v :: Float32
    logv :: Float32
    dv_attack :: Float32
    dlogv_decay :: Float32
    dlogv_release :: Float32
    t1 :: Float32
    t2 :: Float32
    t3 :: Float32
    t4 :: Float32
    stage :: Int # 0 for attack, 1 for decay, 2 for sustain and 3 for release.
    susval :: Float32
end

"""
    adsr(suslevel :: Real, sus_secs :: Real;
         attackfactor = 2.0, attack_secs = 0.002,
         decay_secs = 0.01, release_secs = 0.2)

Makes an "attack-decay-sustain-release" envelope.
The decay and release phases are treated as exponential
and the others stay linear. The arguments are arranged
such that mostly you specify the `suslevel` and `sus_secs`,
which control the amplitude and duration of a note
controlled by the ADSR. The rest are given defaults that you
can change if needed.

- `suslevel` is the sustain level
- `sus_secs` is the duration of the sustain portion
- `attackfactor` determines the peak of the attack and multiplies the sustain level.
- `attack_secs` is the duration of the linear attack portion
- `decay_secs` is the duration of the exponential decay portion after the attack.
- `release_secs` is the "half life" of the release portion of the envelope.
"""
function adsr(suslevel :: Real, sus_secs :: Real;
              attackfactor = 2.0, attack_secs = 0.002,
              decay_secs = 0.01, release_secs = 0.2)
    adsr(konst(suslevel), sus_secs; attackfactor, attack_secs, decay_secs, release_secs)
end

function adsr(suslevel :: Signal, sus_secs :: Real;
              attackfactor = 2.0, attack_secs = 0.002,
              decay_secs = 0.01, release_secs = 0.2)
    susval = value(suslevel, 0.0, 1/48000)
    alevel = max(1.0, attackfactor) * susval
    asecs = max(0.0005, attack_secs)
    dsecs = max(0.01, decay_secs)
    relsecs = max(0.01, release_secs)
    ADSR(Float32(alevel), Float32(asecs), Float32(dsecs), suslevel, Float32(sus_secs), Float32(relsecs),
         0.0f0, Float32(log2(alevel)),
         Float32(alevel/asecs),
         Float32(log2(susval/alevel)/dsecs),
         Float32(-1.0/relsecs),
         Float32(asecs),
         Float32(asecs + dsecs),
         Float32(asecs + dsecs + sus_secs),
         Float32(asecs + dsecs + sus_secs + relsecs),
         0,
         susval)
end

function done(s :: ADSR, t, dt)
    (s.stage >= 3 && s.logv < -15.0)
end

function value(s :: ADSR, t, dt)
    v = 0.0
    if s.stage == 0 && t < s.t1
        v = s.v
        s.v += s.dv_attack * dt
    elseif s.stage <= 1 && t < s.t2
        suslevel = value(s.sustain_level, t, dt)
        s.dlogv_decay = (log2(suslevel) - s.logv)/max(dt, s.t2 - t - dt)
        v = 2 ^ s.logv
        s.logv += s.dlogv_decay * dt
        s.stage = 1
    elseif s.stage <= 2 && t < s.t3
        if s.stage <= 1
            # We were in decay/attack in the previous sample
            # and are just entering the sustain period.
            s.stage = 2
        end
        v = value(s.sustain_level, t, dt)
        #s.logv = 0.8f0 * s.logv + 0.2f0 * log2(v)
        #v = 2 ^ s.logv
        if done(s.sustain_level, t, dt)
            s.stage = 3
        end
    else
        s.stage = 3
        v = 2 ^ s.logv
        s.logv += s.dlogv_release * dt
    end
    return v
end


