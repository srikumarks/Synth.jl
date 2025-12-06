push!(LOAD_PATH,"../src/")

using Documenter, Synth
makedocs(
         warnonly=true,
         sitename="Synth Docs",
         modules=[Synth, Synth.Models],
         pages = [
                  "Home" => Any[
                                "index.md",
                                "start.md",
                               ],
                  "Tutorials" => Any[
                                     "tutorial_basic.md",
                                     "tutorial_synth.md",
                                     "tutorial_gens.md",
                                     "tutorial_signals.md",
                                    ],
                  "Reference" => Any[
                                     "basic.md",
                                     "stereo.md",
                                     "gen.md",
                                     "music.md",
                                     "midi.md",
                                     "render.md",
                                     "rt.md",
                                     "filters.md",
                                     "fx.md",
                                     "tx.md",
                                     "wt.md",
                                     "gran.md",
                                     "utils.md",
                                     "osc.md",
                                     "ui.md"
                                    ],
                  "Other" => Any[
                                 "design.md",
                                 "faq.md"
                                ]
                 ]
        )

deploydocs(
    repo = "github.com/srikumarks/Synth.jl.git",
)
