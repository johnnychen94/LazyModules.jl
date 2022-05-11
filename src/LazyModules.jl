module LazyModules

using Base: invokelatest
using Base: PkgId

export @lazy, invokelatest

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
function LazyModule(name::String)
    pkgid = Base.identify_package(name)
    isnothing(pkgid) && error("can't find package: $name")
    return LazyModule(pkgid)
end

function Base.show(io::IO, m::LazyModule)
    print(io, "LazyModule(", m._lazy_pkgid.name, ")")
end

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

Lazily import package `PkgName` with the actual loading delayed to the first usage.
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
    m = LazyModule(pkgname)
    Core.eval(__module__, :($(x.args[1]) = $m))
end


if VERSION < v"1.1"
    isnothing(x) = x === nothing
end
end # module
