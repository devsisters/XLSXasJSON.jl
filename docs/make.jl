using Documenter, XLSXasJSON

makedocs(
   modules = [XLSXasJSON],
 checkdocs = :all,
   authors = "YongHee Kim",
  sitename = "XLSXasJSON.jl",
  pages = [ "Home" => "index.md",
            "Tutorial" => "tutorial.md",
            "API Reference" => "api.md" ]
)

deploydocs(
    repo   = "github.com/devsisters/XLSXasJSON.jl.git",
    target = "build",
    deps   = nothing,
    make   = nothing
)