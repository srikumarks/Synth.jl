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
    ddlogv_release :: Float32
    vfloor :: Float32
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
- `release_factor` is the number of "release_secs" it takes to drop the amplitude to 0.
  When the amplitude drops below 1/32767, the signal will stop. If we let the decay
  happen at a steady logarithmic pace of a factor of 2 every `release_secs`, it can take
  a full 3 seconds for it to stop even when `release_secs == 0.2`. This can cause
  computational cost to go up because voices will remain alive for longer without
  actually being audible. So we accelerate the drop instead of using a steady
  logarithmic drop velocity, so that the signal will end within about `release_factor * release_secs`
  after release phase begins. This `release_factor` defaults to 4. This "acceleration"
  tends to 0 as the `release_factor` becomes larger. So if you strictly want
  the `release_secs` to be the "half life" of the signal, set this factor to be 15.0.
  Setting it to any value above 15.0 will cause the signal to linger on and decay
  at a slower rate than indicated by `release_secs`.
"""
function adsr(suslevel :: Real, sus_secs :: Real;
              attackfactor = 2.0, attack_secs = 0.002,
              decay_secs = 0.01, release_secs = 0.2, release_factor = 4.0)
    adsr(konst(suslevel), sus_secs; attackfactor, attack_secs, decay_secs, release_secs, release_factor)
end

function adsr(suslevel :: Signal, sus_secs :: Real;
              attackfactor = 2.0, attack_secs = 0.002,
              decay_secs = 0.01,
              release_secs = 0.2, release_factor = 4.0)
    susval = value(suslevel, 0.0, 1/48000)
    alevel = max(1.0, attackfactor) * susval
    asecs = max(0.0005, attack_secs)
    dsecs = max(0.01, decay_secs)
    relsecs = max(0.01, release_secs)
    relvel = -1.0/relsecs
    relaccel = (-15 + release_factor) / (0.5f0 * (release_factor * relsecs)^2)
    ADSR(Float32(alevel), Float32(asecs), Float32(dsecs), suslevel, Float32(sus_secs), Float32(relsecs),
         0.0f0, Float32(log2(alevel)),
         Float32(alevel/asecs),
         Float32(log2(susval/alevel)/dsecs),
         Float32(relvel),
         Float32(relaccel),
         Float32(1/32767),
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
        dlogvdt = s.ddlogv_release * dt
        s.logv += dt * (s.dlogv_release + 0.5f0 * dlogvdt)
        s.dlogv_release += dlogvdt
    end
    return v
end


