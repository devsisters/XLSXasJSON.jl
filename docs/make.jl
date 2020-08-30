using Documenter, XLSXasJSON

function copy_coverage()
  source = joinpath(@__DIR__, "src/coverage")
  target = joinpath(@__DIR__, "build/coverage")
  @info "Copy coverage report from `src/coverge` to `build/coverage`" 

  cp(source, target; force = true)
end

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
    deps   = copy_coverage(),
    make   = nothing
)