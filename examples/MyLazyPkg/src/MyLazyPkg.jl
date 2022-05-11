module MyLazyPkg

export generate_data, draw_figure
using LazyModules
@lazy import Plots

generate_data(n) = sin.(range(start=0, stop=5, length=n) .+ 0.1.*rand(n))
draw_figure(data) = invokelatest(Plots.plot, data, title="MyPkg Plot")

end
