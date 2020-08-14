using LazyArrays, FillArrays, LinearAlgebra, StaticArrays, ArrayLayouts, Test, Base64
import LazyArrays: MemoryLayout, DenseColumnMajor, PaddedLayout, materialize!, call, paddeddata,
                    MulAdd, Applied, ApplyLayout, arguments, DefaultApplyStyle, sub_materialize, resizedata!

@testset "concat" begin
    @testset "Vcat" begin
        @testset "Vector" begin
            A = @inferred(Vcat(Vector(1:10), Vector(1:20)))
            @test eltype(A) == Int
            @test @inferred(axes(A)) == (Base.OneTo(30),)
            @test @inferred(A[5]) == A[15] == 5
            @test_throws BoundsError A[31]
            @test reverse(A) == Vcat(Vector(reverse(1:20)), Vector(reverse(1:10)))
            b = Array{Int}(undef, 31)
            @test_throws DimensionMismatch copyto!(b, A)
            b = Array{Int}(undef, 30)
            @test @allocated(copyto!(b, A)) == 0
            @test b == vcat(A.args...)
            @test copy(A) isa Vcat
            @test copy(A) == A
            @test copy(A) !== A
            @test vec(A) === A
            @test A' == transpose(A) == Vector(A)'
            @test permutedims(A) == permutedims(Vector(A))

            A = @inferred(Vcat(1:10, 1:20))
            @test @inferred(length(A)) == 30
            @test @inferred(A[5]) == A[15] == 5
            @test_throws BoundsError A[31]
            @test reverse(A) == Vcat(reverse(1:20), reverse(1:10))
            b = Array{Int}(undef, 31)
            @test_throws DimensionMismatch copyto!(b, A)
            b = Array{Int}(undef, 30)
            copyto!(b, A)
            @test_broken @allocated(copyto!(b, A)) == 0
            @test @allocated(copyto!(b, A)) ≤ 200
            @test b == vcat(A.args...)
            @test copy(A) === A
            @test vec(A) === A
            @test A' == transpose(A) == Vector(A)'
            @test A' === Hcat((1:10)', (1:20)')
            @test transpose(A) === Hcat(transpose(1:10), transpose(1:20))
            @test permutedims(A) == permutedims(Vector(A))

            @test map(copy,A) isa Vcat 
            @test Applied(A)[3] == 3
        end

        @testset "Matrix" begin
            A = Vcat(randn(2,10), randn(4,10))
            @test @inferred(length(A)) == 60
            @test @inferred(size(A)) == (6,10)
            @test_throws BoundsError A[61]
            @test_throws BoundsError A[7,1]
            b = Array{Float64}(undef, 7,10)
            @test_throws DimensionMismatch copyto!(b, A)
            b = Array{Float64}(undef, 6,10)
            @test_broken @allocated(copyto!(b, A)) == 0
            @test @allocated(copyto!(b, A)) ≤ 200
            @test b == vcat(A.args...)
            @test copy(A) isa Vcat
            @test copy(A) == A
            @test copy(A) !== A
            @test vec(A) == vec(Matrix(A))
            @test A' == transpose(A) == Matrix(A)'
            @test permutedims(A) == permutedims(Matrix(A))
            @test_throws BoundsError A[7,2] = 6
            @test Applied(A)[1,3] == A[1,3]

            A = Vcat(randn(2,10).+im.*randn(2,10), randn(4,10).+im.*randn(4,10))
            @test eltype(A) == ComplexF64
            @test @inferred(length(A)) == 60
            @test @inferred(size(A)) == (6,10)
            @test_throws BoundsError A[61]
            @test_throws BoundsError A[7,1]
            b = Array{ComplexF64}(undef, 7,10)
            @test_throws DimensionMismatch copyto!(b, A)
            b = Array{ComplexF64}(undef, 6,10)
            @test_broken @allocated(copyto!(b, A)) == 0
            @test @allocated(copyto!(b, A)) ≤ 200
            @test b == vcat(A.args...)
            @test copy(A) isa Vcat
            @test copy(A) == A
            @test copy(A) !== A
            @test vec(A) == vec(Matrix(A))
            @test A' == Matrix(A)'
            @test transpose(A) == transpose(Matrix(A))
            @test permutedims(A) == permutedims(Matrix(A))
        end

        @testset "etc" begin
            @test Vcat() isa Vcat{Any,1,Tuple{}}

            A = Vcat(1,zeros(3,1))
            @test A isa AbstractMatrix
            @test A[1,1] == 1.0
            @test A[2,1] == 0.0
            @test axes(A) == (Base.OneTo(4),Base.OneTo(1))
            @test permutedims(A) == permutedims(Matrix(A))
        end
    end
    @testset "Hcat" begin
        A = @inferred(Hcat(1:10, 2:11))
        @test_throws BoundsError A[1,3]
        @test_throws BoundsError A[11,1]
        
        @test @inferred(call(A)) == hcat
        @test @inferred(size(A)) == (10,2)
        @test @inferred(A[5]) == @inferred(A[5,1]) == 5
        @test @inferred(A[11]) == @inferred(A[1,2]) == 2
        b = Array{Int}(undef, 11, 2)
        @test_throws DimensionMismatch copyto!(b, A)
        b = Array{Int}(undef, 10, 2)
        @test_broken @allocated(copyto!(b, A)) == 0
        @test @allocated(copyto!(b, A)) ≤ 200
        @test b == hcat(A.args...)
        @test copy(A) === A
        @test vec(A) == vec(Matrix(A))
        @test vec(A) === Vcat(1:10,2:11)
        @test A' == Matrix(A)'
        @test A' === Vcat((1:10)', (2:11)')

        A = Hcat(Vector(1:10), Vector(2:11))
        b = Array{Int}(undef, 10, 2)
        copyto!(b, A)
        @test b == hcat(A.args...)
        if VERSION ≥ v"1.5"
            @test @allocated(copyto!(b, A)) == 0
        end
        @test @allocated(copyto!(b, A)) ≤ 100
        @test copy(A) isa Hcat
        @test copy(A) == A
        @test copy(A) !== A
        @test vec(A) == vec(Matrix(A))
        @test vec(A) === Vcat(A.args...)
        @test A' == Matrix(A)'
        @test_throws BoundsError A[11,1] = 5
        @test_throws BoundsError A[5,3] = 5

        A = @inferred(Hcat(1, zeros(1,5)))
        @test A == hcat(1, zeros(1,5))
        @test vec(A) == vec(Matrix(A))
        @test A' == Matrix(A)'

        A = @inferred(Hcat(Vector(1:10), randn(10, 2)))
        b = Array{Float64}(undef, 10, 3)
        copyto!(b, A)
        @test b == hcat(A.args...)
        @test @allocated(copyto!(b, A)) == 0
        @test vec(A) == vec(Matrix(A))

        A = Hcat(randn(5).+im.*randn(5), randn(5,2).+im.*randn(5,2))
        b = Array{ComplexF64}(undef, 5, 3)
        copyto!(b, A)
        @test b == hcat(A.args...)
        @test @allocated(copyto!(b, A)) == 0
        @test vec(A) == vec(Matrix(A))
        @test A' == Matrix(A)'
        @test transpose(A) == transpose(Matrix(A))

        @testset "getindex bug" begin
            A = randn(3,3)
            H = Hcat(A,A)
            @test H[1,1] == applied(hcat,A,A)[1,1] == A[1,1]
        end

        @testset "adjoint vec / permutediims" begin
            @test vec(Hcat([1,2]', 3)) == 1:3
            @test permutedims(Hcat([1,2]', 3)) == reshape(1:3,3,1)
        end
    end

    @testset "DefaultApplyStyle" begin
        v = Applied{DefaultApplyStyle}(vcat, (1, zeros(3)))
        @test v[1] == 1
        v = Applied{DefaultApplyStyle}(vcat, (1, zeros(3,1)))
        @test v[1,1] == 1
        H = Applied{DefaultApplyStyle}(hcat, (1, zeros(1,3)))
        @test H[1,1] == 1
    end

    @testset "PaddedLayout" begin
        A = Vcat([1,2,3], Zeros(7))
        B = Vcat([1,2], Zeros(8))

        C = @inferred(A+B)
        @test C isa Vcat{Float64,1}
        @test C.args[1] isa Vector{Float64}
        @test C.args[2] isa Zeros{Float64}
        @test C == Vector(A) + Vector(B)


        B = Vcat([1,2], Ones(8))

        C = @inferred(A+B)
        @test C isa Vcat{Float64,1}
        @test C.args[1] isa Vector{Float64}
        @test C.args[2] isa Ones{Float64}
        @test C == Vector(A) + Vector(B)

        B = Vcat([1,2], randn(8))

        C = @inferred(A+B)
        @test C isa BroadcastArray{Float64}
        @test C == Vector(A) + Vector(B)

        B = Vcat(SVector(1,2), Ones(8))
        C = @inferred(A+B)
        @test C isa Vcat{Float64,1}
        @test C.args[1] isa Vector{Float64}
        @test C.args[2] isa Ones{Float64}
        @test C == Vector(A) + Vector(B)


        A = Vcat(SVector(3,4), Zeros(8))
        B = Vcat(SVector(1,2), Ones(8))
        C = @inferred(A+B)
        @test C isa Vcat{Float64,1}
        @test C.args[1] isa SVector{2,Int}
        @test C.args[2] isa Ones{Float64}
        @test C == Vector(A) + Vector(B)

        @testset "multiple scalar" begin
            # We only do 1 or 2 for now, this should be redesigned later
            A = Vcat(1, Zeros(8))
            @test MemoryLayout(A) isa PaddedLayout{ScalarLayout}
            @test paddeddata(A) == 1
            B = Vcat(1, 2, Zeros(8))
            @test paddeddata(B) == [1,2]
            @test MemoryLayout(B) isa PaddedLayout{ApplyLayout{typeof(vcat)}}
            C = Vcat(1, cache(Zeros(8)));
            @test paddeddata(C) == [1]
            @test MemoryLayout(C) isa PaddedLayout{ApplyLayout{typeof(vcat)}}
            D = Vcat(1, 2, cache(Zeros(8)));
            @test paddeddata(D) == [1,2]
            @test MemoryLayout(D) isa PaddedLayout{ApplyLayout{typeof(vcat)}}
        end
    end

    @testset "Empty Vcat" begin
        @test @inferred(Vcat{Int}([1])) == [1]
        @test @inferred(Vcat{Int}()) == Int[]
    end

    @testset "in" begin
        @test 1 in Vcat(1, 1:10_000_000_000)
        @test 100_000_000 in Vcat(1, 1:10_000_000_000)
    end

    @testset "convert" begin
        for T in (Float32, Float64, ComplexF32, ComplexF64)
            Z = Vcat(zero(T),Zeros{T}(10))
            @test convert(AbstractArray,Z) ≡ Z
            @test convert(AbstractArray{T},Z) ≡ AbstractArray{T}(Z) ≡ Z
            @test convert(AbstractVector{T},Z) ≡ AbstractVector{T}(Z) ≡ Z
        end
    end

    @testset "setindex!" begin
        x = randn(5)
        y = randn(6)
        A = Vcat(x, y, 3)
        A[1] = 1
        @test A[1] == x[1] == 1
        A[6] = 2
        @test A[6] == y[1] == 2
        @test_throws MethodError A[12] = 3
        @test_throws BoundsError A[13] = 3

        x = randn(2,2); y = randn(3,2)
        A = Vcat(x,y)
        A[1,1] = 1
        @test A[1,1] == x[1,1] == 1
        A[3,1] = 2
        @test A[3,1] == y[1,1] == 2
        A[6] = 3
        @test A[1,2] == x[1,2] == 3

        x = randn(2,2); y = randn(2,3)
        B = Hcat(x,y)
        B[1,1] = 1
        @test B[1,1] == x[1,1] == 1
        B[1,3] = 2
        @test B[1,3] == y[1,1] == 2
    end

    @testset "fill!" begin
        A = Vcat([1,2,3],[4,5,6])
        fill!(A,2)
        @test A == fill(2,6)

        A = Vcat(2,[4,5,6])
        @test fill!(A,2) == fill(2,4)
        @test_throws ArgumentError fill!(A,3)

        A = Hcat([1,2,3],[4,5,6])
        fill!(A,2)
        @test A == fill(2,3,2)
    end

    @testset "Any/All" begin
        @test all(Vcat(true, Fill(true,100_000_000)))
        @test any(Vcat(false, Fill(true,100_000_000)))
        @test all(iseven, Vcat(2, Fill(4,100_000_000)))
        @test any(iseven, Vcat(2, Fill(1,100_000_000)))
        @test_throws TypeError all(Vcat(1))
        @test_throws TypeError any(Vcat(1))
    end

    @testset "isbitsunion #45" begin
        @test copyto!(Vector{Vector{Int}}(undef,6), Vcat([[1], [2], [3]], [[1], [2], [3]])) ==
            [[1], [2], [3], [1], [2], [3]]

        a = Vcat{Union{Float64,UInt8}}([1.0], [UInt8(1)])
        @test Base.isbitsunion(eltype(a))
        r = Vector{Union{Float64,UInt8}}(undef,2)
        @test copyto!(r, a) == a
        @test r == a
        @test copyto!(Vector{Float64}(undef,2), a) == [1.0,1.0]
    end

    @testset "Mul" begin
        A = Hcat([1.0 2.0],[3.0 4.0])
        B = Vcat([1.0,2.0],[3.0,4.0])

        @test MemoryLayout(typeof(A)) isa ApplyLayout{typeof(hcat)}
        @test MemoryLayout(typeof(B)) isa ApplyLayout{typeof(vcat)}
        @test A*B == Matrix(A)*Vector(B) == mul!(Vector{Float64}(undef,1),A,B) == (Vector{Float64}(undef,1) .= @~ A*B)
        @test materialize!(MulAdd(1.1,A,B,2.2,[5.0])) == 1.1*Matrix(A)*Vector(B)+2.2*[5.0]

        A = Hcat([1.0 2.0; 3 4],[3.0 4.0; 5 6])
        B = Vcat([1.0,2.0],[3.0,4.0])
        @test MemoryLayout(typeof(A)) isa ApplyLayout{typeof(hcat)}
        @test MemoryLayout(typeof(B)) isa ApplyLayout{typeof(vcat)}
        @test A*B == Matrix(A)*Vector(B) == mul!(Vector{Float64}(undef,2),A,B) == (Vector{Float64}(undef,2) .= @~ A*B)
        @test materialize!(MulAdd(1.1,A,B,2.2,[5.0,6])) ≈ 1.1*Matrix(A)*Vector(B)+2.2*[5.0,6]

        A = Hcat([1.0 2.0; 3 4],[3.0 4.0; 5 6])
        B = Vcat([1.0 2.0; 3 4],[3.0 4.0; 5 6])
        @test MemoryLayout(typeof(A)) isa ApplyLayout{typeof(hcat)}
        @test MemoryLayout(typeof(B)) isa ApplyLayout{typeof(vcat)}
        @test A*B == Matrix(A)*Matrix(B) == mul!(Matrix{Float64}(undef,2,2),A,B) == (Matrix{Float64}(undef,2,2) .= @~ A*B)
        @test materialize!(MulAdd(1.1,A,B,2.2,[5.0 6; 7 8])) ≈ 1.1*Matrix(A)*Matrix(B)+2.2*[5.0 6; 7 8]
    end

    @testset "broadcast" begin
        x = Vcat(1:2, [1,1,1,1,1], 3)
        y = 1:8
        f = (x,y) -> cos(x*y)
        @test f.(x,y) isa Vcat
        @test @inferred(broadcast(f,x,y)) == f.(Vector(x), Vector(y))

        @test (x .+ y) isa Vcat
        @test (x .+ y).args[1] isa AbstractRange
        @test (x .+ y).args[end] isa Int

        z = Vcat(1:2, [1,1,1,1,1], 3)
        @test (x .+ z) isa BroadcastArray
        @test (x + z) isa BroadcastArray
        @test Vector( x .+ z) == Vector( x + z) == Vector(x) + Vector(z)

        @testset "Lazy mixed with Static treats as Lazy" begin
            s = SVector(1,2,3,4,5,6,7,8)
            @test f.(x , s) isa Vcat
            @test f.(x , s) == f.(Vector(x), Vector(s))
        end

        @testset "special cased" begin
            @test Vcat(1, Ones(5))  + Vcat(2, Fill(2.0,5)) ≡ Vcat(3, Fill(3.0,5))
            @test Vcat(SVector(1,2,3), Ones(5))  + Vcat(SVector(4,5,6), Fill(2.0,5)) ≡
                Vcat(SVector(5,7,9), Fill(3.0,5))
            @test Vcat([1,2,3],Fill(1,7)) .* Zeros(10) ≡ Zeros(10) .* Vcat([1,2,3],Fill(1,7)) ≡ Zeros(10)
        end

        H = Hcat(1, zeros(1,10))
        @test H/2 isa Hcat
        @test 2\H isa Hcat
        @test H./Ref(2) isa Hcat
        @test Ref(2).\H isa Hcat
        @test H/2  == H./Ref(2) == 2\H == Ref(2) .\ H == [1/2 zeros(1,10)]
    end

    @testset "maximum/minimum Vcat" begin
        x = Vcat(1:2, [1,1,1,1,1], 3)
        @test maximum(x) == 3
        @test minimum(x) == 1
    end

    @testset "copyto!" begin
        a = Vcat(1, Zeros(10));
        c = cache(Zeros(11));
        @test MemoryLayout(typeof(a)) isa PaddedLayout
        @test MemoryLayout(typeof(c)) isa PaddedLayout{DenseColumnMajor}
        @test copyto!(c, a) ≡ c;
        @test c.datasize[1] == 1
        @test c == a

        a = Vcat(1:3, Zeros(10))
        c = cache(Zeros(13));
        @test MemoryLayout(typeof(a)) isa PaddedLayout
        @test MemoryLayout(typeof(c)) isa PaddedLayout{DenseColumnMajor}
        @test copyto!(c, a) ≡ c;
        @test c.datasize[1] == 3
        @test c == a

        @test dot(a,a) ≡ dot(a,c) ≡ dot(c,a) ≡ dot(c,c) ≡ 14.0


        a = Vcat(1:3, Zeros(5))
        c = cache(Zeros(13));
        @test copyto!(c, a) ≡ c;
        @test c.datasize[1] == 3
        @test c[1:8] == a

        a = cache(Zeros(13)); b = cache(Zeros(15));
        @test a ≠ b
        b = cache(Zeros(13));
        a[3] = 2; b[3] = 2; b[5]=0;
        @test a == b
    end

    @testset "norm" begin
        for a in (Vcat(1,2,Fill(5,3)), Hcat([1,2],randn(2,2)), Vcat(1,Float64[])),
            p in (-Inf, 0, 0.1, 1, 2, 3, Inf)
            @test norm(a,p) ≈ norm(Array(a),p)
        end
    end

    @testset "SubVcat" begin
        A = Vcat(1,[2,3], Fill(5,10))
        V = view(A,3:5)
        @test MemoryLayout(typeof(V)) isa ApplyLayout{typeof(vcat)}
        @inferred(arguments(V))
        @test arguments(V)[1] ≡ Fill(1,0)
        @test A[parentindices(V)...] == copy(V) == Array(A)[parentindices(V)...]

        A = Vcat((1:100)', Zeros(1,100),Fill(1,2,100))
        V = view(A,:,3:5)
        @test MemoryLayout(typeof(V)) isa ApplyLayout{typeof(vcat)}
        @test A[parentindices(V)...] == copy(V) == Array(A)[parentindices(V)...]
        V = view(A,2:3,3:5)
        @test MemoryLayout(typeof(V)) isa ApplyLayout{typeof(vcat)}
        @test A[parentindices(V)...] == copy(V) == Array(A)[parentindices(V)...]

        A = Hcat(1:10, Zeros(10,10))
        V = view(A,3:5,:)
        @test MemoryLayout(typeof(V)) isa ApplyLayout{typeof(hcat)}
        @test A[parentindices(V)...] == copy(V) == Array(A)[parentindices(V)...]
        V = view(A,3:5,1:4)
        @test MemoryLayout(typeof(V)) isa ApplyLayout{typeof(hcat)}
        @inferred(arguments(V))
        @test arguments(V)[1] == reshape(3:5,3,1)

        v = view(A,2,1:5)
        @test MemoryLayout(typeof(v)) isa ApplyLayout{typeof(vcat)}
        @test arguments(v) == ([2], zeros(4))
        @test @inferred(call(v)) == vcat
        @test A[2,1:5] == copy(v) == sub_materialize(v)
    end

    @testset "Padded subarrays" begin
        a = Vcat([1,2,3],[4,5,6])
        @test sub_materialize(view(a,2:6)) == a[2:6]
        a = Vcat([1,2,3], Zeros(10))
        c = cache(Zeros(10)); c[1:3] = 1:3;
        v = view(a,2:4)
        w = view(c,2:4);
        @test MemoryLayout(typeof(a)) isa PaddedLayout{DenseColumnMajor}
        @test MemoryLayout(typeof(v)) isa PaddedLayout{DenseColumnMajor}
        @test sub_materialize(v) == a[2:4] == sub_materialize(w)
        @test sub_materialize(v) isa Vcat
        @test sub_materialize(w) isa Vcat
        A = Vcat(Eye(2), Zeros(10,2))
        V = view(A, 1:5, 1:2)
        @test sub_materialize(V) == A[1:5,1:2]
    end

    @testset "searchsorted" begin
        a = Vcat(1:1_000_000, [10_000_000_000,12_000_000_000])
        b = Vcat(1, 3:1_000_000)
        @test searchsortedfirst(a, 6_000_000_001) == 1_000_001
        @test searchsortedlast(a, 2) == 2
        @test searchsortedfirst(b, 5) == 4
        @test searchsortedlast(b, 1) == 1
    end

    @testset "args with hcat and view" begin
        A = Vcat(fill(2.0,1,10),ApplyArray(hcat, Zeros(1), fill(3.0,1,9)))
        @test arguments(view(A,:,10)) == ([2.0], [3.0])
    end

    @testset "union" begin
        a = Vcat([1,3,4],5:7)
        b = Vcat([1,3,4],5:7)
        union(a,b)
    end

    @testset "col/rowsupport" begin
        H = Hcat(Diagonal([1,2,3]), Zeros(3,3), Diagonal([1,2,3]))
        V = Vcat(Diagonal([1,2,3]), Zeros(3,3), Diagonal([1,2,3]))
        @test colsupport(H,2) == rowsupport(V,2) == 2:2
        @test colsupport(H,4) == rowsupport(V,4) == 1:0
        @test colsupport(H,8) == rowsupport(V,8) == 2:2
        @test colsupport(H,10) == rowsupport(V,10)== 1:0
        @test rowsupport(H,1) == colsupport(V,1) == 1:7
        @test rowsupport(H,2) == colsupport(V,2) == 2:8
        @test colsupport(H,3:4) == rowsupport(V,3:4) == Base.OneTo(3)
        @test rowsupport(H,2:3) == colsupport(V,2:3) == 2:9
    end

    @testset "print" begin
        H = Hcat(Diagonal([1,2,3]), Zeros(3,3))
        V = Vcat(Diagonal([1,2,3]), Zeros(3,3))
        @test stringmime("text/plain", H) == "3×6 ApplyArray{Float64,2,typeof(hcat),Tuple{Diagonal{$Int,Array{$Int,1}},Zeros{Float64,2,Tuple{Base.OneTo{$Int},Base.OneTo{$Int}}}}}:\n 1.0   ⋅    ⋅    ⋅    ⋅    ⋅ \n  ⋅   2.0   ⋅    ⋅    ⋅    ⋅ \n  ⋅    ⋅   3.0   ⋅    ⋅    ⋅ "
        @test stringmime("text/plain", V) == "6×3 ApplyArray{Float64,2,typeof(vcat),Tuple{Diagonal{$Int,Array{$Int,1}},Zeros{Float64,2,Tuple{Base.OneTo{$Int},Base.OneTo{$Int}}}}}:\n 1.0   ⋅    ⋅ \n  ⋅   2.0   ⋅ \n  ⋅    ⋅   3.0\n  ⋅    ⋅    ⋅ \n  ⋅    ⋅    ⋅ \n  ⋅    ⋅    ⋅ "
        v = Vcat(1, Zeros(3))
        @test colsupport(v,1) == 1:1
        @test stringmime("text/plain", v) == "4-element ApplyArray{Float64,1,typeof(vcat),Tuple{$Int,Zeros{Float64,1,Tuple{Base.OneTo{$Int}}}}}:\n 1.0\n  ⋅ \n  ⋅ \n  ⋅ "
        A = Vcat(Ones{Int}(1,3), Diagonal(1:3))
        @test stringmime("text/plain", A) == "4×3 ApplyArray{$Int,2,typeof(vcat),Tuple{Ones{$Int,2,Tuple{Base.OneTo{$Int},Base.OneTo{$Int}}},Diagonal{$Int,UnitRange{$Int}}}}:\n 1  1  1\n 1  ⋅  ⋅\n ⋅  2  ⋅\n ⋅  ⋅  3"
    end

    @testset "==" begin
        A = Vcat([1,2],[0])
        B = Vcat([1,2],[0])
        C = Vcat([1],[2,0])
        @test A == B == C == [1,2,0]
        @test A ≠ [1,2,4]
    end

    @testset "resizedata!" begin
        # allow emulating a cached Vector
        a = Vcat([1,2], Zeros(8))
        @test resizedata!(a, 2) ≡ a
        @test_throws ArgumentError resizedata!(a,3)
    end

    @testset "Axpy" begin
        a = Vcat([1.,2],Zeros(1_000_000))
        b = Vcat([1.,2],Zeros(1_000_000))
        BLAS.axpy!(2.0, a, b)
        @test b[1:10] == [3; 6; zeros(8)]
        BLAS.axpy!(2.0, view(a,:), b)
        @test b[1:10] == [5; 10; zeros(8)]
    end

    @testset "l/rmul!" begin
        a = Vcat([1.,2],Zeros(1_000_000))
        @test ArrayLayouts.lmul!(2,a) ≡ a
        @test a[1:10] == [2; 4; zeros(8)]
        @test ArrayLayouts.rmul!(a,2) ≡ a
        @test a[1:10] == [4; 8; zeros(8)]
    end

    @testset "Dot" begin
        a = Vcat([1,2],Zeros(1_000_000))
        b = Vcat([1,2,3],Zeros(1_000_000))        
        @test @inferred(dot(a,b)) ≡ 5.0
        @test @inferred(dot(a,1:1_000_002)) ≡ @inferred(dot(1:1_000_002,a)) ≡ 5.0
    end

    @testset "search" begin
        a = Vcat([1,2], 5:100)
        v = Vector(a)
        @test searchsortedfirst(a, 0) ≡ searchsortedfirst(v, 0) ≡ 1
        @test searchsortedfirst(a, 2) ≡ searchsortedfirst(v, 2) ≡ 2
        @test searchsortedfirst(a, 4) ≡ searchsortedfirst(v, 4) ≡ 3
        @test searchsortedfirst(a, 50) ≡ searchsortedfirst(v, 50) ≡ 48
        @test searchsortedfirst(a, 101) ≡ searchsortedfirst(v, 101) ≡ 99
        @test searchsortedlast(a, 0) ≡ searchsortedlast(v, 0) ≡ 0
        @test searchsortedlast(a, 2) ≡ searchsortedlast(v, 2) ≡ 2
        @test searchsortedlast(a, 4) ≡ searchsortedlast(v, 4) ≡ 2
        @test searchsortedlast(a, 50) ≡ searchsortedlast(v, 50) ≡ 48
        @test searchsortedlast(a, 101) ≡ searchsortedlast(v, 101) ≡ 98
        @test searchsorted(a, 0) ≡ searchsorted(v, 0) ≡ 1:0
        @test searchsorted(a, 2) ≡ searchsorted(v, 2) ≡ 2:2
        @test searchsorted(a, 4) ≡ searchsorted(v, 4) ≡ 3:2
        @test searchsorted(a, 50) ≡ searchsorted(v, 50) ≡ 48:48
        @test searchsorted(a, 101) ≡ searchsorted(v, 101) ≡ 99:98
    end

    @testset "print" begin
        @test Base.replace_in_print_matrix(Vcat(1:3,Zeros(10)), 4, 1, "0.0") == " ⋅ "
    end
end