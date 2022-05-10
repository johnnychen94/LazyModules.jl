module LazyImageCore

const idImageCore = Base.PkgId(Base.UUID("a09fc81d-aa75-5fe9-8630-4744c3626534"), "ImageCore")

using LazyModules

ImageCore = LazyModule(idImageCore)

export ImageCore

end
