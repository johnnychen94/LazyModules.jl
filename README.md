# LazyModules

> I want everything except latency

# Example: LazyImageCore

```julia
module MyPkg

using Base: invokelatest
using LazyModules

include("examples/LazyImageCore.jl")
using .LazyImageCore

function rand_image(sz)
    return invokelatest(rand, ImageCore.RGB, sz)
end

export rand_image

end
```

```julia
@time using .MyPkg # 0.001461 seconds

# the actual loading is delayed to the first usage of the package
img = @time rand_image((64, 64)) # 0.710679 seconds
```
