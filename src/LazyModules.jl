module LazyModules

using Base: invokelatest
using Base: PkgId

export @lazy

const _LOAD_LOCKER = Threads.ReentrantLock()
do_aggressive_load() = get(ENV, "AGGRESSIVE_LOAD", "true") != "false"

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

function Base.show(io::IO, m::LazyModule)
    print(io, "LazyModule(", m._lazy_pkgid.name, ")")
end

function Base.getproperty(m::LazyModule, s::Symbol)
    if s in (:_lazy_pkgid, :_lazy_loaded)
        return getfield(m, s)
    end
    checked_import(m)
    lm = Base.root_module(getfield(m, :_lazy_pkgid))
    # TODO: create meaningful function name using `s`
    f(args...; kw...) = invokelatest(getfield(lm, s), args...; kw...)
    return f
end

function checked_import(pkgid)
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
        @warn "only `import` command is supported"
        return ex
    end
    args = ex.args
    if length(args) != 1
        @warn "only single package import is supported"
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
    elseif x.head == :as # compat: Julia at least v1.6
        # usage: @lazy import Foo as LazyFoo
        m = _lazy_load(__module__, x.args[2], x.args[1].args[1])
        isa(m, Module) && return m
        isnothing(m) && return ex
        _aggressive_load(m)
        return m
    else
        @warn "unrecognized syntax $ex"
    end
end

function _lazy_load(mod, name::Symbol, sym::Symbol)
    if isdefined(mod, name)
        # otherwise, Revise will constantly trigger the constant redefinition warning
        m = getfield(mod, name)
        if m isa LazyModule || m isa Module
            return m
        else
            @warn "Failed to import module, the name $name already exists"
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
