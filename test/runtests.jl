using LazyModules
using Test

module LazyOffsetArrays
    using LazyModules

    @lazy import OffsetArrays

    function zero_based(A)
        o = Base.invokelatest(OffsetArrays.Origin, 0)
        return Base.invokelatest(OffsetArrays.OffsetArray, A, o)
    end
    export zero_based
end

@testset "LazyModules" begin
    using .LazyOffsetArrays

    A = rand(10, 10)
    AO = zero_based(A)
    @test axes(AO) == (0:9, 0:9)

    using OffsetArrays
    @test AO isa OffsetArray

    @static if VERSION >= v"1.6"
        @lazy import OffsetArrays as FOO
        AOO = FOO.OffsetArray(A, -1, -1)
        @test AOO == AO
    end
end
