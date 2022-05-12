# LazyModules

> No, no, not now

This package provides package developers an alternative option to delay package loading until used.
If some dependency is not used, then users don't need to pay for its latency.

This package is not panacea, it only works for a very limited set of use cases. This package is only
for (maybe experienced) package authors. End-users is not recommended to use this package directly.

## Syntax

- `@lazy import Foo` ✅
- `@lazy import Foo as LazyFoo` ✅ (Julia 1.6+)
- `@lazy using Foo` ❌

## The lazy Plots story

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

## The aggressive lazy loading in the background

Suprisingly, this package can also be used to smooth the REPL experience by moving package loading
in the background. Let's also take Plots as an example. From above test we know you're going to wait
about 4.5s to draw the first plot. But it can be shorter if you're using `@lazy import` in the Main
Module.

```julia
julia> @time @lazy import Plots
  0.000000 seconds
LazyModule(Plots)

julia> @time Plots.plot(1:10); # The Plots package will be ready while I'm typing
  1.563655 seconds (3.86 M allocations: 214.179 MiB, 2.24% gc time, 99.72% compilation time)
```

Congrats, you've just saved 2.8s everytime when you open a new Julia REPL to plot something!

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

## World-age issue

The simplest example to trigger the world age issue is perhaps the following:

```julia
julia> using LazyModules

julia> @lazy import ImageCore
LazyModule(ImageCore)

julia> function foo()
           c = ImageCore.RGB(0.0, 0.0, 0.0)
           return c .* 3
       end
foo (generic function with 1 method)

julia> foo()
ERROR: MethodError: no method matching length(::ColorTypes.RGB{Float64})
The applicable method may be too new: running in world age 31343, while current world is 31370.
...

julia> foo()
RGB{Float64}(0.0,0.0,0.0)
```

Here we can see that:

- at first `foo()` call, it triggers the world-age issue
- at the second call, it is working okay

This happens because when you first call `foo()`, the `length` method required by `*` is not yet
available (to the current world age). When the `ImageCore.RGB` triggers the package loading of
`ImageCore`, which again triggers the recompilation of many methods (in a new world age). But still,
`*` from the old world age can't see the `length` method in the new world age. Things changed at the
second call, where `foo()` gets recompiled in the new world age.

There are commonly two ways to work around the world-age issue:

The first workaround is to use `invokelatest` whenever world-age issue occurs.
But this has some overhead due to the dynamic dispatch.

```julia
julia> using LazyModules

julia> @lazy import ImageCore
LazyModule(ImageCore)

julia> function foo()
           c = ImageCore.RGB(0.0, 0.0, 0.0)
           return Base.invokelatest(*, c, 3)
       end
foo (generic function with 1 method)

julia> foo()
RGB{Float64}(0.0,0.0,0.0)
```

The second workaround is to load the "core" packages eagerly so that we don't need to process
"alien" types. For instance, `RGB` and its arithmetic are provided by `Colors` and
`ColorVectorSpace`:

```julia
julia> using Colors, ColorVectorSpace

julia> using LazyModules

julia> @lazy import ImageCore
LazyModule(ImageCore)

julia> function foo()
           c = ImageCore.RGB(0.0, 0.0, 0.0)
           return c * 3
       end
foo (generic function with 1 method)

julia> foo()
RGB{Float64}(0.0,0.0,0.0)
```

The world-age issue is exactly the reason why this package should not be used by users directly.

## Overhead

The overhead is about ~80ns in Intel i9-12900K due to the dynamic dispatch via `invokelatest`. Thus
you should not use this package for very trivial functions.

```julia
julia> @lazy import ImageCore as LazyImageCore
LazyModule(ImageCore)

julia> import ImageCore

julia> @btime zero(LazyImageCore.RGB)
  82.633 ns (0 allocations: 0 bytes)
RGB{N0f8}(0.0,0.0,0.0)

julia> @btime zero(ImageCore.RGB)
  0.012 ns (0 allocations: 0 bytes)
RGB{N0f8}(0.0,0.0,0.0)
```
