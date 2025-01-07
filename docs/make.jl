push!(LOAD_PATH,"../src/")

using Documenter, Synth
makedocs(
         warnonly=true,
         sitename="Synth Docs",
         modules=[Synth, Synth.Models],
         pages = [
                  "Home" => Any[
                             "index.md"
                            ],
                  "Other" => Any[
                            "faq.md"
                           ]
                 ]
        )

