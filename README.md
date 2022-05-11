# LazyModules

> I want everything except latency

# Example: LazyImageCore

```julia
module MyPkg

using Base: invokelatest
using LazyModules

@lazy import ImageCore

function rand_image(sz)
    return invokelatest(rand, ImageCore.RGB, sz)
end

function black_pixel()
    return invokelatest(ImageCore.RGB, 0.0, 0.0, 0.0)
end

export rand_image, black_pixel

end
```

```julia
@time using .MyPkg # 0.001461 seconds

# the actual loading is delayed to the first usage of the package
img = @time rand_image((64, 64)); # 0.710679 seconds

using Colors
@btime black_pixel() # ~100ns
@btime zero(RGB) # ~1ns
```
