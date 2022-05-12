module LazyModules

using Base: invokelatest
using Base: PkgId

export @lazy

const _LOAD_LOCKER = Threads.ReentrantLock()
function do_aggressive_load()
    v = lowercase(get(ENV, "AGGRESSIVE_LOAD", "true"))
    return !(v == "false" || v == "0")
end

mutable struct LazyModule
    _lazy_pkgid::PkgId
    _lazy_loaded::Bool
end
LazyModule(id::PkgId) = LazyModule(id, false)
LazyModule(name::Symbol) = LazyModule(string(name))
function LazyModule(name::String)
    pkgid = Base.identify_package(name)
    isnothing(pkgid) && error("can't find package: $name")
    return LazyModule(pkgid)
end
Base.Docs.Binding(m::LazyModule, v::Symbol) = Base.Docs.Binding(checked_import(m._lazy_pkgid), v)
function Base.show(io::IO, m::LazyModule)
    print(io, "LazyModule(", m._lazy_pkgid.name, ")")
end

struct LazyFunction
    pkgid::PkgId
    s::Symbol
end

function (f::LazyFunction)(args...; kwargs...)
    m = checked_import(f.pkgid)
    return invokelatest(getfield(m, f.s), args...; kwargs...)
end
function Base.show(io::IO, f::LazyFunction)
    print(io, "LazyFunction(", f.pkgid.name, ".", f.s, ")")
end
Base.Docs.aliasof(f::LazyFunction,   b) = Base.Docs.Binding(checked_import(f.pkgid), f.s)

function Base.getproperty(m::LazyModule, s::Symbol)
    if s in (:_lazy_pkgid, :_lazy_loaded)
        return getfield(m, s)
    end
    checked_import(m)
    lm = Base.root_module(getfield(m, :_lazy_pkgid))
    obj = getfield(lm, s)
    if obj isa Function
        return LazyFunction(getfield(m, :_lazy_pkgid), s)
    else
        return obj
    end
end

function checked_import(pkgid::PkgId)
    mod = if Base.root_module_exists(pkgid)
        Base.root_module(pkgid)
    else
        lock(_LOAD_LOCKER) do
            @debug "loading package: $(pkgid.name)"
            Base.require(pkgid)
        end
    end

    return mod
end

function checked_import(m::LazyModule)
    if !getfield(m, :_lazy_loaded)
        checked_import(getfield(m, :_lazy_pkgid))
        setfield!(m, :_lazy_loaded, true)
    end
    return m
end


"""
    @lazy import PkgName

Lazily import package `PkgName` with the actual loading delayed to the first usage.
"""
macro lazy(ex)
    if ex.head != :import
        @warn "only `import` command is supported, fallback to eager mode"
        return ex
    end
    args = ex.args
    if length(args) != 1
        @warn "only single package import is supported, fallback to eager mode"
        return ex
    end
    x = args[1]
    if x.head == :.
        # usage: @lazy import Foo
        m = _lazy_load(__module__, x.args[1], x.args[1])
        # TODO(johnnychen94): the background eager loading seems to work only for Main scope
        isa(m, Module) && return m
        isnothing(m) && return ex
        _aggressive_load(m)
        return m
    elseif x.head == :(:)
        # usage: @lazy import Foo: foo, bar
        @warn "lazily importing symbols are not supported, fallback to eager mode"
        return ex
    elseif x.head == :as # compat: Julia at least v1.6
        # usage: @lazy import Foo as LazyFoo
        m = _lazy_load(__module__, x.args[2], x.args[1].args[1])
        isa(m, Module) && return m
        isnothing(m) && return ex
        _aggressive_load(m)
        return m
    else
        @warn "unrecognized syntax $ex"
        return ex
    end
end

function _lazy_load(mod, name::Symbol, sym::Symbol)
    if isdefined(mod, name)
        # otherwise, Revise will constantly trigger the constant redefinition warning
        m = getfield(mod, name)
        if m isa LazyModule || m isa Module
            return m
        else
            @warn "Failed to import module, the name `$name` already exists, do nothing"
            return nothing
        end
    end
    m = LazyModule(sym)
    Core.eval(mod, :(const $(name) = $m))
    return m
end

function _aggressive_load(m::LazyModule)
    do_aggressive_load() || return m
    @async checked_import(m)
    return m
end

if VERSION < v"1.1"
    isnothing(x) = x === nothing
end
end # module
