# Sampling synthesis

The "Basic tutorial" showed how to construct and use simple
oscillators and control them using other signals. Along similar
lines, we can also use audio samples - either short waveforms
intended for looping through or full samples intended to be
played even as single shot.

## Playing a sample

[`sample`](@ref) provides means to take a pre-recorded snippet
and play it back end to end, with optional looping builtin.
You can create a sample player either from a raw `Vector{Float32}`
or load it from a file in a format supported by FileIO/LibSndFile.

```julia
> s = sample("speech.wav")
# By default, the sample is not configured to loop. See `looping`
# and `loopto` arguments for how to set that up.
> play(s)
```

**Note:** For now, only 48000Hz is supported as the sampling rate.
No sampling rate conversion will be done on files and therefore the
files must all be at 48KHz. Furthermore, [`sample`](@ref) will only
load one channel from the file if it is stereo. Full stereo support
and sampling rate conversion may be added in the future, but for now
these limits apply.

## Looping a wave table

While [`sample`](@ref) plays back a recorded piece of sound,
what we often want to do is to take a periodic waveform recorded
off a real instrument and loop it with various time stretches 
to mimic playing the instrument. This is referred to as "wavetable synthesis".

You can make such a wavetable sound with parametric control over the
amplitude and phase using [`wavetable`](@ref). A case of basic playback
of a loop with a "sirening" of the frequency is shown below -

```julia
> w = wavetable(sample("waveform.wav"), 0.25f0, phasor(440 + oscil(50, 10)))
> play(w, 2.0)
```

The wavetable player supports 4-point interpolation and therefore 
even short tables can be stretched out a fair bit.

Otherwise, a wavetable player is an ordinary stateful `Signal` and can be used
in the same way as any other "signal process".

## Registered sounds

It is often convenient to load a bunch of sounds and refer to them by name. The
[`register!`](@ref) method can store wavetables and samples associated with a
symbol and the symbol can then be used with [`wavetable`](@ref) and
[`sample`](@ref) to retrieve them.

```julia
> register!(:hh, sample("hihat.wav"))
> play(sample(:hh))
> register!(:horn, sample("horn_loop.wav"))
> play(wavetable(:horn, 0.25, 440), 2.0)
```

Note that when given a number as the third argument, [`wavetable`](@ref)
will treat it as a frequency and not as a phase, because it doesn't make
sense to fix the phase of a wavetable when playing it. If you want to vary
the frequency over time, use a [`phasor`](@ref) and vary its argument
like shown in the example above.


