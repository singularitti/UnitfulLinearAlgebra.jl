#import Base: (*), (+), (-)
abstract type AbstractUnitfulDimVecOrMat{T,N,UD<:Tuple,D<:Tuple,A} <: AbstractDimArray{T,N,D,A} end

const AbstractUnitfulDimVector{T<:Number} = AbstractUnitfulDimVecOrMat{T,1} where T
const AbstractUnitfulDimMatrix{T<:Number} = AbstractUnitfulDimVecOrMat{T,2} where T

"""
    struct UnitfulDimMatrix

    Built on DimensionalData.DimArray.
    Add `unitdims` for unit dimensions (range and domain).
    Add `exact::Bool` which is true for geometric interpretation.
"""
struct UnitfulDimMatrix{T,N,UD<:Tuple,D<:Tuple,R<:Tuple,A<:AbstractArray{T,N},Na,Me} <: AbstractUnitfulDimVecOrMat{T,N,UD,D,A}
    data::A
    unitdims::UD
    dims::D
    refdims::R
    name::Na
    metadata::Me
    exact::Bool
end

# 2 arg version: required input: numerical values and unitdims
UnitfulDimMatrix(data::AbstractArray, unitdims; kw...) = UnitfulMatrix(data, (unitdims,); kw...)
function UnitfulDimMatrix(data::AbstractArray, unitdims::Union{Tuple,NamedTuple}; 
    dims=(), refdims=(), name=DimensionalData.NoName(), metadata=DimensionalData.NoMetadata(), exact = true)
    if eltype(unitdims) <: Vector
        return UnitfulDimMatrix(data, format(Units.(unitdims), data), format(dims,data), refdims, name, metadata, exact)
    elseif eltype(unitdims) <: Units
        return UnitfulMatrix(data, format(unitdims, data), format(dims,data), refdims, name, metadata, exact)
    end        
end
# back consistency with MMatrix
function UnitfulDimMatrix(data::AbstractArray, unitrange, unitdomain; 
    dims=(), refdims=(), name=DimensionalData.NoName(), metadata=DimensionalData.NoMetadata(), exact = true)
    return UnitfulDimMatrix(data, format((Units(unitrange),Units(unitdomain)), data), format(dims, data), refdims, name, metadata, exact)
end

"""
    function unitdims(A::UnitfulDimMatrix)

    Return tuple -> (unitrange, unitdomain)
"""
unitdims(A::UnitfulDimMatrix) = A.unitdims
exact(A::UnitfulDimMatrix) = A.exact

"""
    rebuild(A::UnitfulDimMatrix, data, [dims, refdims, name, metadata]) => UnitfulMatrix
    rebuild(A::UnitfulDimMatrix; kw...) => UnitfulMatrix

Rebuild a `UnitfulDimMatrix` with some field changes. All types
that inherit from `UnitfulMatrix` must define this method if they
have any additional fields or alternate field order.

Implementations can discard arguments like `refdims`, `name` and `metadata`.

This method can also be used with keyword arguments in place of regular arguments.
"""
@inline function DimensionalData.rebuild(
    A::UnitfulDimMatrix, data, unitdims::Tuple=unitdims(A), dims::Tuple=dims(A), refdims=refdims(A), name=name(A))
    DimensionalData.rebuild(A, data, unitdims, dims, refdims, name, metadata(A), exact(A))
end

@inline function DimensionalData.rebuild(
    A::UnitfulDimMatrix, data::AbstractArray, unitdims::Tuple, dims::Tuple, refdims::Tuple, name, metadata, exactflag
)
    UnitfulDimMatrix(data, unitdims, dims, refdims, name, metadata,exactflag)
end

#@inline function rebuild(
#     A::UnitfulMatrix, data; dims::Tuple=dims(A), refdims=refdims(A), name=name(A))
#     DimensionalData.rebuild(A, data, dims, refdims, name, metadata(A),exact(A))
# end

"""
    rebuild(A::UnitfulMatrix, data, dims, refdims, name, metadata,exactflag) => UnitfulMatrix
    rebuild(A::UnitfulMatrix; kw...) => UnitfulMatrix

Rebuild a `UnitfulMatrix` with new fields. Handling partial field
update is dealt with in `rebuild` for `AbstractDimArray` (still true?).
"""
#@inline function rebuild(
#    A::UnitfulMatrix, data::AbstractArray, dims::Tuple, refdims::Tuple, name, metadata, exactflag
#)
#    UnitfulMatrix(data, dims, refdims, name, metadata, exactflag)
#end

function Base.show(io::IO, mime::MIME"text/plain", A::UnitfulDimMatrix{T,N}) where {T,N}
    lines = 0
    summary(io, A)
    print_name(io, name(A))
    #lines += Dimensions.print_dims(io, mime, dims(A))
    !(isempty(dims(A)) || isempty(refdims(A))) && println(io)
    lines += Dimensions.print_refdims(io, mime, refdims(A))
    println(io)

    # DELETED THIS OPTIONAL PART HERE
    # Printing the array data is optional, subtypes can 
    # show other things here instead.
    ds = displaysize(io)
    ioctx = IOContext(io, :displaysize => (ds[1] - lines, ds[2]))
    #println("show after")
    #DimensionalData.show_after(ioctx, mime, Matrix(A))

    #function print_array(io::IO, mime, A::AbstractDimArray{T,2}) where T
    T2 = eltype(A)
    Base.print_matrix(DimensionalData._print_array_ctx(ioctx, T2), Matrix(A))

    return nothing
end

"""
    function UnitfulDimMatrix(A::AbstractMatrix)

    Constructor to make inexact UnitfulDimMatrix.
    Satisfies algebraic interpretation of multipliable
    matrices.
"""
function UnitfulDimMatrix(A::AbstractMatrix)
    numbers = ustrip.(A)
    M,N = size(numbers)
    unitdomain = Vector{Unitful.FreeUnits}(undef,N)
    unitrange = Vector{Unitful.FreeUnits}(undef,M)

    for i = 1:M
        unitrange[i] = unit(A[i,1])
    end
    
    for j = 1:N
        unitdomain[j] = unit(A[1,1])/unit(A[1,j])
    end

    B = UnitfulDimMatrix(numbers,unitrange,unitdomain)
    # if the array is not multipliable, return nothing
    if Matrix(B) == A
        return B
    else
        return nothing
    end
end
function UnitfulDimMatrix(A::AbstractVector) # should be called UnitfulVector?
    numbers = ustrip.(A)
    M = size(numbers)
    unitrange = Vector{Unitful.FreeUnits}(undef,M)

    unitrange = unit.(A)
    B = UnitfulDimMatrix(numbers,unitrange)
    # if the array is not multipliable, return nothing
    if Matrix(B) == A
        return B
    else
        return nothing
    end
end


function DimensionalData._rebuildmul(A::AbstractUnitfulDimMatrix, B::AbstractUnitfulDimMatrix)
    # compare unitdims
    DimensionalData.comparedims(last(unitdims(A)), first(unitdims(B)); val=true)

    # compare regular (axis) dims
    DimensionalData.comparedims(last(dims(A)), first(dims(B)); val=true)
    
    rebuild(A, parent(A) * parent(B), (first(unitdims(A)),last(unitdims(B))), (first(dims(A)),last(dims(B))))
end
Base.:*(A::AbstractUnitfulDimMatrix, B::AbstractUnitfulDimMatrix) = _rebuildmul(A,B)

function DimensionalData._rebuildmul(A::AbstractUnitfulDimMatrix, B::AbstractUnitfulDimVector)
    # compare unitdims
    DimensionalData.comparedims(last(unitdims(A)), first(unitdims(B)); val=true)

    # compare regular (axis) dims
    DimensionalData.comparedims(last(dims(A)), first(dims(B)); val=true)
    
    DimensionalData.rebuild(A, parent(A) * parent(B), (first(unitdims(A)),), (first(dims(A)),))
end
Base.:*(A::AbstractUnitfulDimMatrix, B::AbstractUnitfulDimVector) = _rebuildmul(A,B)

#copied from ULA.* 
DimensionalData._rebuildmul(A::AbstractUnitfulDimMatrix, b::Quantity) = rebuild(A,parent(A)*ustrip(b),(Units(unitrange(A).*unit(b)),unitdomain(A)))
Base.:*(A::AbstractUnitfulDimMatrix, b::Quantity) = _rebuildmul(A,b)
Base.:*(b::Quantity, A::AbstractUnitfulDimMatrix) = _rebuildmul(A,b)

DimensionalData._rebuildmul(A::AbstractUnitfulDimMatrix, b::Number) = rebuild(A, parent(A).*b, (unitrange(A), unitdomain(A)))
Base.:*(A::AbstractUnitfulDimMatrix, b::Number) = _rebuildmul(A,b)
Base.:*(b::Number, A::AbstractUnitfulDimMatrix) = _rebuildmul(A,b)



#from ULA.+ 
function Base.:+(A::AbstractUnitfulDimMatrix{T1},B::AbstractUnitfulDimMatrix{T2}) where T1 where T2
    
    # compare unitdims
    DimensionalData.comparedims(first(unitdims(A)), first(unitdims(B)); val=true)

    # compare regular (axis) dims
    DimensionalData.comparedims(last(dims(A)), last(dims(B)); val=true)
    
    bothexact = exact(A) && exact(B)
    if (unitrange(A) == unitrange(B) && unitdomain(A) == unitdomain(B)) ||
        ( unitrange(A) ∥ unitrange(B) && unitdomain(A) ∥ unitdomain(B) && ~bothexact)
        return rebuild(A,parent(A)+parent(B),(unitrange(A),unitdomain(A))) 
    else
        error("matrices not dimensionally conformable for addition")
    end
end

function Base.:-(A::AbstractUnitfulDimMatrix{T1},B::AbstractUnitfulDimMatrix{T2}) where T1 where T2
    
    # compare unitdims
    DimensionalData.comparedims(first(unitdims(A)), first(unitdims(B)); val=true)

    # compare regular (axis) dims
    DimensionalData.comparedims(last(dims(A)), last(dims(B)); val=true)
    
    bothexact = exact(A) && exact(B)
    if (unitrange(A) == unitrange(B) && unitdomain(A) == unitdomain(B)) ||
        ( unitrange(A) ∥ unitrange(B) && unitdomain(A) ∥ unitdomain(B) && ~bothexact)
        return rebuild(A,parent(A)-parent(B),(unitrange(A),unitdomain(A))) 
    else
        error("matrices not dimensionally conformable for subtraction")
    end
end

#this is probably bad - automatically broadcasts because I don't know how to override
#the dot syntax
function Base.:+(A::AbstractUnitfulDimMatrix{T1},b::Quantity) where T1
    if unitrange(A)[1] == unit(b)
        println("broadcasting!")
        return rebuild(A, parent(A) .+ ustrip(b), (unitrange(A), unitdomain(A)))
    else
        error("matrix and scalar are not dimensionally conformable for subtraction")
    end
    
    
end

function Base.:-(A::AbstractUnitfulDimMatrix{T1},b::Quantity) where T1
    if unitrange(A)[1] == unit(b)
        println("broadcasting!")
        return rebuild(A, parent(A) .- ustrip(b), (unitrange(A), unitdomain(A)))
    else
        error("matrix and scalar are not dimensionally conformable for subtraction")
    end
    
    
end


#LinearAlgebra.inv(A::AbstractUnitfulDimMatrix) = ~singular(A) ? rebuild(A,inv(parent(A)),(unitdomain(A),unitrange(A)), (last(dims(A)),first(dims(A)) )) : error("matrix is singular")
LinearAlgebra.inv(A::AbstractUnitfulDimMatrix) = rebuild(A,inv(parent(A)), (unitdomain(A),unitrange(A)), (last(dims(A)),first(dims(A)) ))

"""
    function det

    Unitful matrix determinant.
    same as ULA.det
"""
function LinearAlgebra.det(A::AbstractUnitfulDimMatrix)
    if square(A)
        detunit = prod([unitrange(A)[i]/unitdomain(A)[i] for i = 1:size(A)[1]])
        return Quantity(det(parent(A)),detunit)
    else
        error("Determinant requires square matrix")
    end
end

"""
    function singular
    was same as ULA.singular, but I was getting singular on matrices that aren't actually
"""
#singular(A::AbstractUnitfulDimMatrix) = iszero(ustrip(det(A)))
singular(A::AbstractUnitfulDimMatrix) = rank(parent(A)) == max(size(parent(A))...)
