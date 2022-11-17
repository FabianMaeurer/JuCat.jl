abstract type AbstractSubcategory <: Category end

struct RingSubcategory <: AbstractSubcategory
    category::Category
    simples::Vector{<:Object}
    projector::Object
end

struct SubcategoryObject <: Object
    parent::AbstractSubcategory
    object::Object
end

struct SubcategoryMorphism <: Morphism
    domain::SubcategoryObject
    codomain::SubcategoryObject
    m::Morphism
end


object(X::SubcategoryObject) = X.object
morphism(f::SubcategoryMorphism) = f.m
base_ring(C::RingSubcategory) = base_ring(C.category)
#=-------------------------------------------------
    Constructors 
-------------------------------------------------=#

function RingSubcategory(C::Category,i::Int)
    @assert ismultitensor(C)
    𝟙ᵢ = decompose(one(C))[i][1] 
    projection = [𝟙ᵢ⊗S⊗𝟙ᵢ for S ∈ simples(C)]
    filter!(e -> e != zero(C), projection)
    return RingSubcategory(C,projection,𝟙ᵢ)
end

#=-------------------------------------------------
    Functionality 
-------------------------------------------------=#
function dsum(X::SubcategoryObject, Y::SubcategoryObject)
    @assert parent(X) == parent(Y)
    obj = dsum(object(X), object(Y))
    return SubcategoryObject(parent(X), obj)
end

function dsum(f::SubcategoryMorphism, g::SubcategoryMorphism)
    @assert parent(f) == parent(g)
    mor = dsum(morphism(f), morphism(g))
    return SubcategoryMorphism(domain(f)⊕domain(g), codomain(f)⊕codomain(g), mor)
end

function dsum_with_morphisms(X::SubcategoryObject, Y::SubcategoryObject)
    @assert parent(X) == parent(Y)
    obj,ix,px = dsum_with_morphisms(object(X), object(Y))
    sub_obj = SubcategoryObject(parent(X), obj)
    sub_ix = [SubcategoryMorphism(x,sub_obj,i) for (i,x) ∈ zip(ix,[X,Y])]
    sub_px = [SubcategoryMorphism(sub_obj,y,p) for (p,y) ∈ zip(px,[X,Y])]
    return sub_obj, sub_ix, sub_px
end

function tensor_product(X::SubcategoryObject, Y::SubcategoryObject)
    @assert parent(X) == parent(Y)
    obj = tensor_product(object(X),object(Y))
    return SubcategoryObject(parent(X), obj)
end

function tensor_product(f::SubcategoryMorphism, g::SubcategoryMorphism)
    @assert parent(f) == parent(g)
    mor = tensor_product(morphism(f),morphism(g))
    return SubcategoryMorphism(domain(f)⊗domain(g), codomain(f)⊗codomain(g), mor)
end

function compose(f::SubcategoryMorphism, g::SubcategoryMorphism)
    @assert parent(f) == parent(g)
    return SubcategoryMorphism(domain(f),codomain(g), compose(morphism(f),morphism(g)))
end

function dual(X::SubcategoryObject)
    return SubcategoryObject(parent(X), dual(object(X)))
end

function ev(X::SubcategoryObject)
    dom = dual(X)⊗X
    cod = one(parent(X))
    proj = basis(Hom(one(parent(X).category), parent(X).projector))[1]
    return SubcategoryMorphism(dom,cod, proj ∘ ev(object(X)))
end

function coev(X::SubcategoryObject)
    incl = basis(Hom(parent(X).projector, one(parent(X).category)))[1]
    return SubcategoryMorphism(X⊗dual(X),one(parent(X)), coev(object(X)) ∘ incl)
end
    
function spherical(X::SubcategoryObject)
    return SubcategoryMorphism(X,dual(dual(X)), spherical(object(X)))
end

function id(X::SubcategoryObject) 
    return SubcategoryMorphism(X,X, id(object(X)))
end

function zero_morphism(X::SubcategoryObject, Y::SubcategoryObject)
    return SubcategoryMorphism(X,Y, zero_morphism(object(X),object(Y)))
end

function Hom(X::SubcategoryObject, Y::SubcategoryObject)
    sub_basis = [SubcategoryMorphism(X,Y,f) for f ∈ Hom(object(X),object(Y))]
    return HomSpace(X,Y,sub_basis,VectorSpaces(base_ring(X)))
end

function isisomorphic(X::SubcategoryObject, Y::SubcategoryObject)
    b, iso = isisomorphic(object(X),object(Y))
    if !b 
        return false, nothing
    end
    return true, SubcategoryMorphism(X,Y, iso)
end

function kernel(f::SubcategoryMorphism)
    @assert isabelian(parent(f))
    k,i = kernel(morphism(f))
    sub_k = SubcategoryObject(parent(f), k)
    return sub_k, SubcategoryMorphism(sub_k, domain(f), i)
end

function cokernel(f::SubcategoryMorphism)
    @assert isabelian(parent(f))
    c,i = cokernel(morphism(f))
    sub_c = SubcategoryObject(parent(f), c)
    return sub_c, SubcategoryMorphism(codomain(f),sub_c, i)
end

left_inverse(f::SubcategoryMorphism) = SubcategoryMorphism(codomain(f),domain(f), left_inverse(morphism(f)))
right_inverse(f::SubcategoryMorphism) = SubcategoryMorphism(codomain(f),domain(f), right_inverse(morphism(f)))

is_simple(X::SubcategoryObject) = is_simple(object(X))

matrix(f::SubcategoryMorphism) = matrix(morphism(f))

issemisimple(C::AbstractSubcategory) = issemisimple(C.category)
ismultifusion(C::AbstractSubcategory) = ismultifusion(C.category)

*(x, f::SubcategoryMorphism) = SubcategoryMorphism(domain(f),codomain(f), x*morphism(f))
+(f::SubcategoryMorphism, g::SubcategoryMorphism) = SubcategoryMorphism(domain(f),codomain(f), morphism(f) + morphism(g))
inv(f::SubcategoryMorphism) = SubcategoryMorphism(codomain(f),domain(f), inv(morphism(f)))

function express_in_basis(f::SubcategoryMorphism, B::Vector{SubcategoryMorphism})
    express_in_basis(morphism(f), morphism.(B))
end
#=-------------------------------------------------
    Functionality for RingSubcategory 
-------------------------------------------------=#

one(C::RingSubcategory) = SubcategoryObject(C,C.projector)
zero(C::AbstractSubcategory) = SubcategoryObject(C,zero(C.category))
simples(C::RingSubcategory) = [SubcategoryObject(C,s) for s in C.simples]

function associator(X::SubcategoryObject, Y::SubcategoryObject, Z::SubcategoryObject)
    dom = (X ⊗ Y) ⊗ Z
    cod = X ⊗ (Y ⊗ Z)
    return SubcategoryMorphism(dom,cod, associator(object(X), object(Y), object(Z)))
end

isfusion(C::RingSubcategory) = ismultifusion(C.category)
#=-------------------------------------------------
    Pretty Printing 
-------------------------------------------------=#

function show(io::IO, X::SubcategoryObject)
    print(io, """(Subcategory) $(object(X))""")
end

function show(io::IO, f::SubcategoryMorphism)
    print(io, """(Subcategory) $(morphism(f))""")
end

function show(io::IO, C::RingSubcategory)
    i = findfirst(e -> e == C.projector, [c for (c,k) ∈ decompose(one(C.category))])
    print(io, """$i-th component fusion category of $(C.category)""")
end