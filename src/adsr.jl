mutable struct ADSR <: Signal
    attack_level :: Float32
    attack_secs :: Float32
    decay_secs :: Float32
    sustain_level :: Float32
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
end

"""
    adsr(
        alevel :: Real, asecs :: Real, 
        dsecs :: Real,
        suslevel :: Real, sussecs :: Real,
        relsecs :: Real
    )

Makes an "attack-decay-sustain-release" envelope.
The decay and release phases are treated as exponential
and the others stay linear.
"""

function adsr(
        alevel :: Real, asecs :: Real, 
        dsecs :: Real,
        suslevel :: Real, sussecs :: Real,
        relsecs :: Real
    )
    ADSR(Float32(alevel), Float32(asecs), Float32(dsecs), Float32(suslevel), Float32(sussecs), Float32(relsecs),
         0.0f0, Float32(log2(alevel)),
         Float32(alevel/asecs),
         Float32(log2(suslevel/alevel)/dsecs),
         Float32(-1.0/relsecs),
         Float32(asecs),
         Float32(asecs + dsecs),
         Float32(asecs + dsecs + sussecs),
         Float32(asecs + dsecs + sussecs + relsecs))
end

function done(s :: ADSR, t, dt)
    t > s.t3 && s.logv < -15.0
end

function value(s :: ADSR, t, dt)
    v = 0.0
    if t < s.t1
        v = s.v
        s.v += s.dv_attack * dt
    elseif t < s.t2
        v = 2 ^ s.logv
        s.logv += s.dlogv_decay * dt
    elseif t < s.t3
        v = s.sustain_level
    else
        v = 2 ^ s.logv
        s.logv += s.dlogv_release * dt
    end
    return v
end


