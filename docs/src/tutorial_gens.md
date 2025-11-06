# Musical processes

The core of `Synth.jl` deals with "signal processes" as described on earlier
parts. However, purely working at the signal level alone does not make for
"music" and we need to be able to orchestrate (a.k.a. "schedule") signals with
appropriate parameterization in order to make interesting noises.

To do this, `Synth.jl` defines the `Gen` abstract type with the only method to
implement being `proc(::Gen,::Bus,t) :: Tuple{Float64,Gen}`.

Before we get to it, we need to understand the core "signal process" that makes
this possible - the [`bus`](@ref). 

## The bus

A "bus" is like a reusable (read "supports fanout") line to which various
signal processes can write their values by being "scheduled" on to the bus
using [`sched`](@ref). You can use a bus with signals alone for its scheduling
capabilities like shown below --

```julia
> b = bus()
> play(b, 20)
> sched(b, oscil(adsr(0.25, 1.0), 440))
```

A few things to note here -

1. We can start playing a bus immediately after creation and it will
   produce silence until something is scheduled on to it.

2. Signals can be scheduled on to the bus using [`sched`](@ref) to either
   be played immediately or at a later time. This "time" is relative to the
   start of playback of the bus.

3. The intrinsic duration of a bus is infinite - i.e. if you start playing
   it without an explicit stop time, it will continue forever.

Next, we'll see how to use the bus in conjunction with [`Gen`](@ref).

## Gens

The `Gen` type abstracts the notion of a "musical process" - a process whose
task is to schedule musical events on to a bus and to decide the next musical
event to follow. In this sense, `Gen`s are define to be "temporally recursive",
to use the term introduced by Andrew Sorenson. Such a "musical process" runs at
a far lower temporal granularity than a "signal process" -- about 60 times a
second, compared to the 48000Hz sampling rate. This is fine grained enough for
interactivity while the processes can schedule signals in a sample-accurate
manner.

Several simple noise making "musical processes" are available via the [`tone`](@ref)
and [`ping`](@ref) and it is easy to make your own by defining a subtype of `Gen`
and implementing the `proc(::Gen,::Bus,t) :: Tuple{Float64,Gen}` method.

The [`tone`](@ref) provides a number of constructors that facilitate ease of
scheduling notes on a timeline.

```julia
> b = bus()
> play(b, 20)
> trk = track([
         tone(ch([60,64,67]), 1.0),
         tone(ch(12 .+ [60,62,65,69]), 1.0),
         ping(72, 1.0),
         pause(0.5),
         loop(3, ping([67,72], 0.2)),
         tone(12 .+ [60, 62, 64, 65, 67, 69, 71, 72, 71, 69, 67, 65, 64, 62, 60], 1/16)
        ])
> sched(b, trk)
```

The above sample illustrates the use of [`track`](@ref) to create sequences,
[`tone`](@ref) to construct simple pitched tones, [`ch`](@ref) to specify
chording, [`pause`](@ref) to insert pauses and [`loop`](@ref) to repeat
a musical process a set number of times.

"Chording" refers to playing multiple Gens simultaneously and waiting for all of
them to complete before moving on. This is implemented using [`chord`](@ref),
with overloads of [`tone`](@ref) supporting chording via [`ch`](@ref).

### Making your own musical process

While some basic higher order processes like [`track`](@ref) and [`loop`](@ref)
are available, t is relatively simple to roll your own as you can find from the
code. Below is an example of something that plays all the twelve tones of an
octave once with an accelerando.

```julia
struct AllToneAccel <: Synth.Gen
    start :: Int
    finish :: Int
    dur :: Float64
end

function proc(g :: AllToneAccel, b :: Bus, t)
    if g.start > g.finish
        (t, Cont()) # Indicates that the gen is done and
                    # the bus must continue with whatever is
                    # to follow, ex: if this is placed in a track.
    else
        # Schedule a tone to be rendered on to the bus at time t.
        sched(b, t, oscil(adsr(0.25, g.dur), midi2hz(g.start)))

        # Return the next time and the next gen in the sequence.
        (t + g.dur, AllToneAccel(g.start + 1, g.finish, g.dur * 0.9))
    end
end

b = bus(60.0) # 60 beats per minute
play(b, 20)
sched(b, AllToneAccel(60, 84, 1.0))
```

Some things to note --

1. Each proc call decides what comes after as well. This way, we can
   setup temporal progressions (such as accelerando in the above example)
   easily.

2. All implemented `Gen` subtypes are immutable. This is desirable since they
   can then be reused as simple values across multiple tracks. Since the cost
   of creating these small structures is very small, new instances can be
   created when needed, like in the case above where we choose to continue the
   accelerando.

3. Each bus can be given a clock whose tempo can be varied in real time using
   another signal or a [`control`](@ref). This means the tempo of all the events
   scheduled on the bus can be influenced centrally.

4. A musical process is welcome to return **any other** musical process to
   follow it. So in that sense, this supports mutual temporal recursion.

### Recurrent musical processes

It is common to make musical processes that appear to maintain a state and
evolve it over time, much like ordinary signal processes. So there are 
prebuilt "meta musical processes" that facilitate this.

The simpler one of them is the [`dyn`](@ref) which can be given a function
that will be called a number of times with an index, with the expectation
to return a `Gen` to schedule. It's called a "dyn" short for "dynamic" because
the specific Gen to use can be decided by the function dynamically. Such a
[`dyn`](@ref) does not explicitly use state, though the function passed can be
a closure that modifies its state internally on every call (not recommended).

```julia
b = bus()
play(b, 10)
sched(b, dyn((n,i) -> tone(60+i,0.5), 12, 0))
# Plays rising semitones, two per second.
```

The more general recurrent process, called [`rec`](@ref) can be used with
functions that need to keep track of state, but without using mutation to
do so, so that these Gens can be reused across tracks. Below is the same
example above implemented using [`rec`](@ref)

```julia
b = bus()
play(b, 10)
semitones(n,i) = begin
    if i < n
        (tone(60+i, 0.5), i+1)
    else
        (Cont(), i+1)
    end
end
sched(b, rec(semitones, 12, 0))
```

Both [`rec`](@ref) and [`dyn`](@ref) are to be considered as "dynamic"
because the decision on which Gen to use is made just in time. Hence
there is no explicit mention of `t` in the recurrent function. If you
wish to delay the returned Gen by, say, 0.1 seconds, you'll need to
sequence it with a pause like `seq(pause(0.1), ...the_gen...)`.










