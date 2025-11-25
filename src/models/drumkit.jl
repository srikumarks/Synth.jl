using ..Synth: Gen, Bus, sched, Cont

"""
Represents a sampled drum sound to be played without
a "duration". You can use the [`hit`])(@ref "Synth.Models.hit") function
with it to reuse it with a different velocity.

- `samplefile` - file name of the sample containing the drum hit.
- `vel` - the velocity of the hit - in the range [0.0,1.0].
"""
struct DrumHit <: Gen
    samplefile::String
    vel::Float32
end

function Synth.genproc(g::DrumHit, b::Bus, t, rt)
    sched(b, t, g.vel * sample(g.samplefile))
    (t, Cont())
end

"""
    hit(samplefile::AbstractString, vel::Real = 1.0f0) :: DrumHit
    hit(drum::DrumHit, vel::Real = 1.0f0) :: DrumHit

Constructs a [`DrumHit`](@ref "Synth.Models.DrumHit") that can be used in `Gen` compositions.
Drum hits have an inherent duration of 0.0. So if you want to put a 
gap between two drum hits, you'll need to use [`pause`](@ref "Synth.pause").
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

See also [`hit`](@ref "Synth.Models.hit")
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
