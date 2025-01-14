mutable struct Seq{Sch <: Signal, T <: Tuple{Float64, Signal}} <: Signal
    clock :: Sch
    triggers :: Vector{T}
    ts :: Vector{Float64}
    realts :: Vector{Float64}
    ti :: Int
    active_i :: Int
end

"""
    seq(clock :: Signal, triggers :: Vector{Tuple{Float64,Signal}})

Sequences the given signals in a virtual timeline determined by the given
clock. Use `clock_bpm` to make such a clock.
"""
function seq(clock :: Signal, triggers :: Vector{T}) where {T <: Tuple{Float64,Signal}}
    Seq(clock,
        triggers,
        accumulate(+, first.(triggers)),
        zeros(Float64, length(triggers)),
        1,
        1)
end

done(s :: Seq, t, dt) = done(s.clock, t, dt) || s.active_i > length(s.triggers)
function value(s :: Seq, t, dt)
    if done(s.clock, t, dt) return 0.0f0 end
    virt = value(s.clock, t, dt)
    v = 0.0f0
    if virt >= s.ts[s.ti]
        s.ti += 1
        if s.ti <= length(s.triggers)
            s.realts[s.ti] = t
        end
    end
    for i in s.active_i:min(length(s.triggers), s.ti)
        if i == s.active_i
            if done(s.triggers[i][2], t - s.realts[i], dt)
                s.active_i += 1
            else
                v += value(s.triggers[i][2], t - s.realts[i], dt)
            end
        else
            v += value(s.triggers[i][2], t - s.realts[i], dt)
        end
    end
    return v
end


