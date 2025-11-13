using ..Synth: Gen, Bus, sched, Cont

"""
Represents a sampled drum sound to be played without
a "duration". You can use the [`hit`])(@ref) function
with it to reuse it with a different velocity.

- `samplefile` - file name of the sample containing the drum hit.
- `vel` - the velocity of the hit - in the range [0.0,1.0].
"""
struct DrumHit <: Gen
    samplefile::String
    vel::Float32
end

function Synth.proc(g::DrumHit, b::Bus, t)
    sched(b, t, g.vel * sample(g.samplefile))
    (t, Cont())
end

"""
    hit(samplefile::AbstractString, vel::Real = 1.0f0) :: DrumHit
    hit(drum::DrumHit, vel::Real = 1.0f0) :: DrumHit

Constructs a [`DrumHit`](@ref) that can be used in `Gen` compositions.
Drum hits have an inherent duration of 0.0. So if you want to put a 
gap between two drum hits, you'll need to use [`pause`](@ref).
`hit` will load the sample and cache it so the loading doesn't
happen at actual play time.

Usage: `play(track([hit("kick.wav", 0.5), pause(0.5), hit("snare.wav", 0.5)]), 2.0)`

See also [`Synth.Models.drumkit`](@ref)
"""
function hit(samplefile::AbstractString, vel::Real = 1.0f0)
    @assert isfile(samplefile) "Sample file '$samplefile' not found"
    sample(samplefile)
    DrumHit(samplefile, Float32(vel))
end

function hit(drum::DrumHit, vel::Float32 = 1.0f0)
    DrumHit(drum.samplefile, vel)
end

"""
Collects together a number of "standard" drums belonging to
a "kit".
"""
struct DrumKit
    kick::DrumHit
    hihat::DrumHit
    snare::DrumHit
    tom1::DrumHit
    tom2::DrumHit
    tom3::DrumHit
end

"""
    drumkit(kit::AbstractString, dir::AbstractString) :: DrumKit
    drumkit(kit::AbstractString) :: DrumKit

Loads a "standard" drum kit consisting of a kick, hihat, snare and three toms.
`kit` gives the name of the kit to load and maps to the name of a directory
under the given `dir`. If `dir` is omitted, then the kits included within
Synth.jl are scanned.

Usage:

```
using Synth.Models: drumkit

k = drumkit("Techno")
play(track([hit(k.kick, 0.5), pause(0.5), hit(k.snare, 0.5)]), 2.0)
```

See also [`Synth.Models.hit`](@ref)
"""
function drumkit(kit::AbstractString, dir::AbstractString)
    @assert isdir(dir) "Invalid drumkit directory $dir"
    @assert isdir("$dir/$kit") "Invalid drumkit $kit within $dir"
    DrumKit(
            hit("$dir/$kit/kick.wav"),
            hit("$dir/$kit/snare.wav"),
            hit("$dir/$kit/hihat.wav"),
            hit("$dir/$kit/tom1.wav"),
            hit("$dir/$kit/tom2.wav"),
            hit("$dir/$kit/tom3.wav")
           )
end
drumkit(kit::AbstractString) = drumkit(kit, (@__DIR__) * "/drumkits")

struct Riff <: Gen
    kit::DrumKit
    pattern::String
    i::Int
    speed::Rational
    loop::Bool
end

function riff(kit::AbstractString, pattern::AbstractString; speed=1, loop=true)
    Riff(drumkit(kit), pattern, 1, speed, loop)
end

namedhit(kit::DrumKit, c::Char) = if c == 'k'
    kit.kick
elseif c == 's'
    kit.snare
elseif c == 'h'
    kit.hihat
elseif c == '1'
    kit.tom1
elseif c == '2'
    kit.tom2
elseif c == '3'
    kit.tom3
else
    kit.snare
end

function Synth.proc(g::Riff, b::Bus, t)
    i = g.i
    if i > length(g.pattern)
        if g.loop
            i = 1
        else
            return (t, Cont())
        end
    end
    c = g.pattern[i]
    step = 1.0/g.speed
    t2 = t + step
    if c != '_' && c != '-' && c != ',' && c != ' '
        sched(b, t, namedhit(g.kit, c))
    end
    (t2, Riff(g.kit, g.pattern, i+1, g.speed, g.loop))
end
