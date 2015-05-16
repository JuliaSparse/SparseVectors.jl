
### Types

typealias CVecView{T} ContiguousView{T,1,Vector{T}}

immutable SparseVector{Tv,Ti<:Integer} <: AbstractSparseVector{Tv,Ti}
    n::Int              # the number of elements
    nzind::Vector{Ti}   # the indices of nonzeros
    nzval::Vector{Tv}   # the values of nonzeros

    function SparseVector(n::Int, nzind::Vector{Ti}, nzval::Vector{Tv})
        n >= 0 || throw(ArgumentError("The number of elements must be non-negative."))
        length(nzind) == length(nzval) ||
            throw(DimensionMismatch("The lengths of nzind and nzval are inconsistent."))
        new(n, nzind, nzval)
    end
end

SparseVector{Tv,Ti}(n::Integer, nzind::Vector{Ti}, nzval::Vector{Tv}) =
    SparseVector{Tv,Ti}(convert(Int, n), nzind, nzval)

immutable SparseVectorView{Tv,Ti<:Integer} <: AbstractSparseVector{Tv,Ti}
    n::Int                  # the number of elements
    nzind::CVecView{Ti}     # the indices of nonzeros
    nzval::CVecView{Tv}     # the values of nonzeros

    function SparseVectorView(n::Int, nzind::CVecView{Ti}, nzval::CVecView{Tv})
        n >= 0 || throw(ArgumentError("The number of elements must be non-negative."))
        length(nzind) == length(nzval) ||
            throw(DimensionMismatch("The lengths of nzind and nzval are inconsistent."))
        new(n, nzind, nzval)
    end
end

SparseVectorView{Tv,Ti}(n::Integer, nzind::CVecView{Ti}, nzval::CVecView{Tv}) =
    SparseVectorView{Tv,Ti}(convert(Int, n), nzind, nzval)

typealias GenericSparseVector{Tv,Ti} Union(SparseVector{Tv,Ti}, SparseVectorView{Tv,Ti})


### Conversion

# convert SparseMatrixCSC to SparseVector
function Base.convert{Tv,Ti}(::Type{SparseVector{Tv,Ti}}, s::SparseMatrixCSC{Tv,Ti})
    size(s, 2) == 1 || throw(ArgumentError("The input argument must have a single-column."))
    SparseVector(s.m, s.rowval, s.nzval)
end

Base.convert{Tv,Ti}(::Type{SparseVector{Tv}}, s::SparseMatrixCSC{Tv,Ti}) =
    convert(SparseVector{Tv,Ti}, s)

Base.convert{Tv,Ti}(::Type{SparseVector}, s::SparseMatrixCSC{Tv,Ti}) =
    convert(SparseVector{Tv,Ti}, s)


### View

view(x::SparseVector) = SparseVectorView(length(x), view(x.nzind), view(x.nzval))


### Basic properties

Base.length(x::GenericSparseVector) = x.n
Base.size(x::GenericSparseVector) = (x.n,)

Base.nnz(x::GenericSparseVector) = length(x.nzval)
Base.countnz(x::GenericSparseVector) = countnz(x.nzval)
Base.nonzeros(x::GenericSparseVector) = x.nzval

### Element access

function Base.getindex{Tv}(x::GenericSparseVector{Tv}, i::Int)
    m = length(x.nzind)
    ii = searchsortedfirst(x.nzind, i)
    (ii <= m && x.nzind[ii] == i) ? x.nzval[ii] : zero(Tv)
end

### Array manipulation

function Base.full{Tv}(x::GenericSparseVector{Tv})
    n = x.n
    nzind = x.nzind
    nzval = x.nzval
    r = zeros(Tv, n)
    for i = 1:length(nzind)
        r[nzind[i]] = nzval[i]
    end
    return r
end

Base.vec(x::GenericSparseVector) = x

Base.copy(x::GenericSparseVector) = SparseVector(x.n, copy(x.nzind), copy(x.nzval))


### Computation

Base.sum(x::GenericSparseVector) = sum(x.nzval)
Base.sumabs(x::GenericSparseVector) = sumabs(x.nzval)
Base.sumabs2(x::GenericSparseVector) = sumabs2(x.nzval)

function Base.dot{Tx<:Real,Ty<:Real}(x::StridedVector{Tx}, y::GenericSparseVector{Ty})
    n = length(x)
    length(y) == n || throw(DimensionMismatch())
    nzind = y.nzind
    nzval = y.nzval
    s = zero(Tx) * zero(Ty)
    for i = 1:length(nzind)
        s += x[nzind[i]] * nzval[i]
    end
    return s
end

Base.dot{Tx<:Real,Ty<:Real}(x::GenericSparseVector{Tx}, y::StridedVector{Ty}) = dot(y, x)

function Base.dot{Tx<:Real,Ty<:Real}(x::GenericSparseVector{Tx}, y::GenericSparseVector{Ty})
    n = length(x)
    length(y) == n || throw(DimensionMismatch())

    xnzind = x.nzind
    xnzval = x.nzval
    ynzind = y.nzind
    ynzval = y.nzval
    mx = length(xnzind)
    my = length(ynzind)

    ix = 1
    iy = 1
    s = zero(Tx) * zero(Ty)
    while ix <= mx && iy <= my
        jx = xnzind[ix]
        jy = ynzind[iy]
        if jx == jy
            s += xnzval[ix] * ynzval[iy]
            ix += 1
            iy += 1
        elseif jx < jy
            ix += 1
        else
            iy += 1
        end
    end
    return s
end