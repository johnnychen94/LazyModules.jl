using LazyModules
using Test

module LazySparseArrays
    using LazyModules

    @lazy import SparseArrays

    function lsprand(args...)
        return invokelatest(SparseArrays.sprand, args...)
    end
    export lsprand
end

@testset "LazyModules" begin
    using .LazySparseArrays

    A = lsprand(10, 10, 0.5)
    @test size(A) == (10, 10)

    using SparseArrays
    @test A isa SparseMatrixCSC
end
