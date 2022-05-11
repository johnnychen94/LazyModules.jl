using LazyModules
using Test

module LazyOffsetArrays
    using LazyModules

    @lazy import OffsetArrays

    function zero_based(A)
        return OffsetArrays.OffsetArray(A, OffsetArrays.Origin(0))
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
end
