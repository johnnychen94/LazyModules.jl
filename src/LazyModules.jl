module LazyModules

export lazy_import, @lazy

using Base: PkgId

const load_locker = Threads.ReentrantLock()

function checked_import(pkgid)
    mod = if Base.root_module_exists(pkgid)
            Base.root_module(pkgid)
        else
            lock(load_locker) do
                Base.require(pkgid)
            end
        end

    return mod
end

mutable struct LazyModule
    _lazy_pkgid::PkgId
    _lazy_loaded::Bool
end
LazyModule(id::PkgId) = LazyModule(id, false)

function Base.getproperty(m::LazyModule, s::Symbol)
    if s in (:_lazy_pkgid, :_lazy_loaded)
        return getfield(m, s)
    end
    if !getfield(m, :_lazy_loaded)
        checked_import(getfield(m, :_lazy_pkgid))
        setfield!(m, :_lazy_loaded, true)
    end
    lm = Base.root_module(getfield(m, :_lazy_pkgid))
    return getfield(lm, s)
end

"""
    @lazy import PkgName

Lazily import package `PkgName`.

The package loading of `PkgName` will be delayed to when it's actually required.
For instance, if one does `@lazy import ImageCore`, then any symbol usage such
as `ImageCore.RGB` will trigger the package loading.

!!!info "dispatch overhead"
    This strategy uses `invokelatest` to work around the world age issues, it
    has about 100ns overhead for each call. Thus it should only be used for
    non-trivial function call.

"""
macro lazy(ex)
    if ex.head != :import
        @warn "only `import` command is supported"
        return ex
    end
    args = ex.args
    if length(args) != 1
        @warn "only single package import is supported"
        return ex
    end
    x = args[1]
    if x.head != :.
        return ex
    end
    pkgname = String(x.args[1])
    m = lazy_import(pkgname)
    Core.eval(__module__, :($(x.args[1]) = $m))
end

function lazy_import(pkgname::String)
    pkgid = Base.identify_package(pkgname)
    return LazyModule(pkgid)
end

end # module
