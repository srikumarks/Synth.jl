module TK3

export tala

using ..Synth
using ..Synth: Bus
using URIs


"""
A simple sine tone "bell" with a sharp attack and an exponential decay.
"""
struct Bell <: Gen
    freq::Float32
    halfLife::Float32
    amplitude::Float32
    attackTime::Float32
    delay::Float32
end

function Synth.genproc(g::Bell, b::Bus, t, rt)
    env = adsr(
        g.amplitude,
        0.0;
        attack_secs = g.attackTime,
        release_secs = g.halfLife,
        release_factor = 8.0,
    )
    s = oscil(env, g.freq)
    sched(b, t + g.delay, s)
    (t, Cont())
end

function bell(freq::Real, halfLife::Real, amplitude::Real, attackTime::Real, delay::Real)
    Bell(
        Float32(freq),
        Float32(halfLife),
        Float32(amplitude),
        Float32(attackTime),
        Float32(delay),
    )
end

function click(freqFactor, volume, tempo_bpm)
    bell(880.0 * freqFactor, 0.0125 * 2.0 * sqrt(60.0 / tempo_bpm), 0.1 * volume, 0.01, 0.0)
end

function high(volume)
    bell(880.0 * 3.0, 0.1, 0.1 * volume, 0.015, 0.0)
end

function low(volume)
    bell(880.0 * 2.0, 0.05, 0.1 * volume, 0.015, 0.0)
end

function supreme(volume, detune, delay, tempo_bpm)
    bell(
        880.0 * 4.0 * (2.0 ^ (detune / 1200.0)),
        2.0 * 60.0 / tempo_bpm,
        0.01 * volume,
        0.015,
        delay,
    )
end


function chime(strength, tempo_bpm)
    par([
        supreme(1.0, 19, 0.0123, tempo_bpm),
        supreme(1.0, 12, 0.0123, tempo_bpm),
        supreme(1.0, 730, 0.0213, tempo_bpm),
        supreme(1.0, -510, 0.0343, tempo_bpm),
        supreme(1.0, -490, 0.0343, tempo_bpm),
    ])
end

function kalaipulse(strength, tempo_bpm)
    click(1.0, 0.7 * strength, tempo_bpm)
end

function nadaipulse(strength, tempo_bpm)
    click(2.0, 0.75 * strength, tempo_bpm)
end

struct Gati
    n::Int
    d::Int
end

struct TalaSection
    pattern::String     # Like "lrr_lrlr"
    kalai::String   # Like "___" or using "," instead of "_" for unvoiced division.
    nadai::String   # Same syntax as Kalai
    gati::Gati    # Like "___.__" - two parts separated by a period. Only the counts matter.
end

struct Tala <: Gen
    bpm::Float64
    sections::Vector{TalaSection}
    pulseaudible::Bool
    chimeatstart::Bool
    name::Union{String,Nothing}
end

"""
    tala(url::AbstractString) :: Tala

Construct a "Tala" generator from a "TalaKeeper v3" style URL.
The URL specifies all aspects of the tala. You can construct
such urls from https://talakeeper.org/talas.html . Once
you press "Play", a "shareable link" will pop up next to it
which you can use as the URL argument.

The query parameters give various aspects of the tala.

- "pat": A pattern of the form "lrl_r|lrlr" where the "|" separates
  parts of the full pattern. The kalai, nadai and gati patterns must
  have a corresponding number of parts.
- "kal": Describes the "kalai" of the pattern parts. Is also a "|"
  separated string, where each part consists of a sequence of "_" or ","
  characters. Defaults to "_" for each part of the pattern.
- "nad": Same syntax as the "kal" argument, but describes the "nadai"
  or subdivisions of the pattern. Defaults to "_" for each part of the pattern.
- "gat": Of the form "____.___" (for each part of the pattern) where there are
  two parts separated by "." and the two parts only consist of "_" characters.
  The "gati" offers a complex overlay of subdivision expressed as a fraction.
  Defaults to "_._" for each part of the pattern.
- "ps": Either "y" or "n", says whether the pulses described by "kalai"
  should be audible. Defaults to "n".
- "c": Either "y" or "n", says whether to include a strong "chime" at
  the start of each tala cycle. Defaults to "y".
- "bpm": Integer giving the tempo of the tala, beats per minute.
  Defaults to 100.
- "name": Optional name part if the nomenclature fits.

Example tala URL - 

```
https://talakeeper.org/tk3?bpm=80&pat=lrrrlrlrrrlrrr&kal=__&nad=_,_&name=Catusra%20(4)%20jati%20Dhruva%20tala%20(2%20kalai)
```

This describes a 4-2-4-4 pattern with each count doubled into two pulses ("kal"
= "__") and each pulse subdivided into threes ("nad" = "_,_"), at a tempo of
80bpm. This tala would be described as "Catusra jati Dhruva tala in 2 kalai,
tisra nadai".

"""
function tala(url::AbstractString)
    u = parse(URI, url)
    fields = queryparams(u)
    if !haskey(fields, "pat")
        throw(ArgumentError("Tala pattern not given in 'pat' field"))
    end
    pat = fields["pat"]
    p = match(r"^(([lr]([_]*))+)([|](([lr]([_]*))+))*$", pat)
    if isnothing(p)
        throw(ArgumentError("Invalid Tala pattern '$pat'"))
    end
    patparts = split(pat, "|")

    bpm = parse(Int, get(fields, "bpm", "100"))

    kalai = split(get(fields, "kal", join("_" ^ length(patparts), "|")), "|")
    if length(kalai) != length(patparts)
        throw(ArgumentError("Kalai pattern parts don't match tala pattern parts"))
    end
    kalaistr = join(kalai, "|")
    if !occursin(r"^([_,]+)([|]([_,]+))*$", kalaistr)
        throw(ArgumentError("Invalid Kalai pattern '$(kalaistr)'"))
    end

    nadai = split(get(fields, "nad", join("_" ^ length(patparts), "|")), "|")
    if length(nadai) != length(patparts)
        throw(ArgumentError("Nadai pattern parts don't match tala pattern parts"))
    end
    nadaistr = join(nadai, "|")
    if !occursin(r"^([_,]+)([|]([_,]+))*", nadaistr)
        throw(ArgumentError("Invalid Nadai pattern '$(nadaistr)'"))
    end

    gatis = split(get(fields, "gat", ("|_._"^length(patparts))[2:end]), "|")
    if length(gatis) != length(patparts)
        throw(ArgumentError("Gati pattern parts don't match tala pattern parts"))
    end
    println("gatis = ", gatis)
    gatistr = join(gatis, "|")
    if !occursin(r"^([_,]+)([|]([_,]+))*", gatistr)
        throw(ArgumentError("Invalid Gati pattern '$(gatistr)'"))
    end
    println("gatistr = ", gatistr)
    gati = [Gati(length.(split(p, "."))...) for p in gatis]
    println("gati = ", gati)
    if !all(g.d > 0 for g in gati)
        throw(ArgumentError("Invalid Gati pattern component in $(repr("text/plain",gati))"))
    end

    pulseaudible = if haskey(fields, "ps")
        fields["ps"] == "y"
    else
        false
    end

    chimeatstart = if haskey(fields, "c")
        fields["c"] == "y"
    else
        true
    end

    namestr = if haskey(fields, "name")
        fields["name"]
    else
        nothing
    end

    println("gati = ", gati)
    Tala(
        Float64(bpm),
        [
            TalaSection(patparts[i], kalai[i], nadai[i], gati[i]) for
            i in eachindex(patparts)
        ],
        pulseaudible,
        chimeatstart,
        namestr,
    )
end

function Synth.genproc(tala::Tala, b::Bus, t, rt)
    (t, seq(composeTala(tala), tala))
end

function composeTala(tala::Tala)
    duration = sum(
        length(sec.pattern) * length(sec.kalai) * sec.gati.d / sec.gati.n for
        sec in tala.sections
    )
    durn(
        duration,
        par([
            composeChimeAtStart(tala),
            composeStrokesForChar(tala, 'l'),
            composeStrokesForChar(tala, 'r'),
            tala.pulseaudible ? composeStrokesForChar(tala, '_') : Cont(),
            tala.pulseaudible ? composeKalaiPulses(tala) : Cont(),
            composeNadaiPulses(tala),
        ]),
    )
end

function composeChimeAtStart(tala::Tala)
    if tala.chimeatstart
        chime(1.0, tala.bpm * 2.0)
    else
        Cont()
    end
end

function composeStrokesForChar(tala::Tala, ch::Char)
    @assert ch in "lr_" "Stroke character must be one of l or r or _, but was $ch"
    s = Dict('l' => high(1.0), 'r' => low(1.0), '_' => kalaipulse(1.0, tala.bpm))

    function composeStrokesForOne(sec::TalaSection)
        dt = length(sec.kalai) * sec.gati.d / sec.gati.n
        track([durn(dt, s[c]) for c in sec.pattern])
    end

    track(composeStrokesForOne.(tala.sections))
end

function composeKalaiPulses(tala::Tala)
    function composeForOneTala(sec::TalaSection)
        dt = sec.gati.d / sec.gati.n
        pulses = [
            durn(dt, i > 1 && k == '_' ? kalaipulse(1.0, tala.bpm) : Cont()) for
            (i, k) in enumerate(sec.kalai)
        ]
        loop(length(sec.pattern), track(pulses))
    end

    if tala.pulseaudible
        track(composeForOneTala.(tala.sections))
    else
        Cont()
    end
end

function composeNadaiPulses(tala::Tala)
    function composeForOneTala(sec::TalaSection)
        dt = sec.gati.d / (length(sec.nadai) * sec.gati.n)
        pulses = [
            durn(dt, i > 1 && n == '_' ? nadaipulse(1.0, tala.bpm) : Cont()) for
            (i, n) in enumerate(sec.nadai)
        ]
        loop(length(sec.pattern) * length(sec.kalai), track(pulses))
    end

    track(composeForOneTala.(tala.sections))
end


end
