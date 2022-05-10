module LazyModules

export LazyModule

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

end # module
