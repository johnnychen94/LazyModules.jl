# LazyModules

> No, no, not now

This package provides package developers an alternative option to delay package loading until used.
If some dependency is not used, then users don't need to pay for its latency.

Only for package authors, end-users should not use this package directly.

# The lazy Plots story

Assume that you've built a fantastic package `examples/MyPkg` with some built-in plot functions:

```julia
module MyPkg

export generate_data, draw_figure
import Plots

generate_data(n) = sin.(range(start=0, stop=5, length=n) .+ 0.1.*rand(n))
draw_figure(data) = plot(data, title="MyPkg Plot")

end
```

Normally, you spend quite a long time on loading the package because `Plots` is heavy:

```julia
(@v1.7) pkg> activate examples/MyPkg
  Activating project at `~/Documents/Julia/LazyModules.jl/examples/MyPkg`

(MyPkg) pkg> instantiate
Precompiling project...
  1 dependency successfully precompiled in 36 seconds (133 already precompiled)

julia> @time using MyPkg # 💤
  2.857596 seconds (9.81 M allocations: 670.470 MiB, 8.53% gc time, 19.95% compilation time)

julia> x = @time generate_data(100); # 🚀
  0.000006 seconds (2 allocations: 1.750 KiB)

julia> @time draw_figure(x) # 💤
1.608146 seconds (4.00 M allocations: 223.266 MiB, 2.83% gc time, 99.74% compilation time)
```

If Plots is the needed feature to `MyPkg`, then the latency is what I need to pay for, which is
okay. **BUT**, from time to time, I might just generate the data and save it to disk, **without
plotting the figure at all!** Then why should I still wait for the `Plots` loading?

This is where `LazyModules` can become useful: it delays the loading of heavy packages such as
`Plots` to its first call. By doing this, we don't need to wait for it if we don't use the `Plots`
functionalities.

What you need to do, is to change the package code a bit (`examples/MyLazyPkg`):

```diff
module MyLazyPkg

export generate_data, draw_figure
+using LazyModules
-import Plots
+@lazy import Plots

generate_data(n) = sin.(range(start=0, stop=5, length=n) .+ 0.1.*rand(n))
draw_figure(data) = Plots.plot(data, title="MyPkg Plot")

end
```

By doing this, if the users don't use `draw_figure` feature, then they don't need to load `Plots` at
all, which makes package loading significantly faster:

```julia
(@v1.7) pkg> activate examples/MyLazyPkg
  Activating project at `~/Documents/Julia/LazyModules.jl/examples/MyPkg`

(MyLazyPkg) pkg> instantiate
Precompiling project...
  1 dependency successfully precompiled in 36 seconds (133 already precompiled)

julia> @time using MyLazyPkg # 🚀🚀🚀🚀🚀
  0.053273 seconds (154.16 k allocations: 8.423 MiB, 97.62% compilation time)

julia> x = @time generate_data(100); # 🚀
  0.000006 seconds (2 allocations: 1.750 KiB)
```

The actual loading of `Plots` is delayed to the first `draw_figure` call:

```julia
julia> @time draw_figure(x) # 💤💤
  4.454738 seconds (13.82 M allocations: 897.071 MiB, 8.81% gc time, 49.97% compilation time)
```

Here `4.4` seconds is approximately `2.8` (Plots loading time) plus `1.6` (time to first plot time).
For this reason, if a functionality is really necessary and widely used by almost everyone, then
this LazyModules package won't be helpful at all.

## What is a LazyModule

`LazyModule` is not a `Module`; it is indeed, a struct that overrides `getproperty`.

```julia
julia> using LazyModules

julia> @lazy import SparseArrays
LazyModule(SparseArrays)

julia> SparseArrays.sprand(10, 10, 0.3) # triggers the loading
10×10 SparseArrays.SparseMatrixCSC{Float64, Int64} with 40 stored entries:
...
```

Package is loaded whenever there's a `getproperty` call, e.g., `SparseArrays.sprand` as shown above.

## FAQ

**What's the syntax?**

There is only one way to use it so far

- `@lazy import Foo` ✅
- `@lazy import Foo as LazyFoo` ❌ (Not yet)
- `@lazy using Foo` ❌

**What can I use?**

For functions and constructors, only.

**How large is the overhead?**

The overhead is about ~100ns in Intel i9-12900K due to the dynamic dispatch via `invokelatest`. Thus
you should not use this package for very trivial functions.
