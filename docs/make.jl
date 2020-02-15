using Documenter, XLSXasJSON

makedocs(
   modules = [XLSXasJSON],
 checkdocs = :all,
   authors = "YongHee Kim",
  sitename = "XLSXasJSON.jl",
     pages = Any[
              "Index" => "index.md",
              "User Guide" => "userguide.md",
             ]
)

deploydocs(
    repo   = "github.com/devsisters/XLSXasJSON.jl.git",
    target = "build",
    deps   = nothing,
    make   = nothing
)