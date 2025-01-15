push!(LOAD_PATH,"../src/")

using Documenter, Synth
makedocs(
         warnonly=true,
         sitename="Synth Docs",
         modules=[Synth, Synth.Models],
         pages = [
                  "Home" => Any[
                             "index.md",
                             "basic.md",
                             "stereo.md",
                             "gen.md",
                             "music.md",
                             "render.md",
                             "rt.md",
                             "filters.md",
                             "tx.md",
                             "wt.md",
                             "gran.md",
                             "utils.md"
                            ],
                  "Other" => Any[
                            "design.md",
                            "faq.md"
                           ]
                 ]
        )

