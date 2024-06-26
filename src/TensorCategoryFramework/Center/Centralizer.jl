#=----------------------------------------------------------
    Structure for the Müger Centralizer 
----------------------------------------------------------=#

mutable struct CentralizerCategory <: Category
    base_ring::Ring
    category::Category
    simples::Vector{O} where O <: Object
    subcategory_simples::Vector{o} where o <:Object
    inductions::Dict{<:Object,<:Object}
    induction_gens::Vector{Object}

    function CentralizerCategory(C::Category, S::Vector{<:Object}; check = true)
        Z = new()
        Z.base_ring = base_ring(C)
        Z.category = C

        if check 
            S = topologize(S) 
        end

        Z.subcategory_simples = S

        return Z
    end

    function CentralizerCategory()
        new()
    end
end

struct CentralizerObject <: Object
    parent::CentralizerCategory
    object::Object
    γ::Vector{M} where M <: Morphism
end

struct CentralizerMorphism <: Morphism
    domain::CentralizerObject
    codomain::CentralizerObject
    m::Morphism
end

function ==(C::CentralizerCategory, D::CentralizerCategory)
    if !isdefined(C, :simples) || !isdefined(D, :simples)
        if !isdefined(C, :simples) ⊻ !isdefined(D, :simples)
            return false
        else
            return base_ring(C) == base_ring(D) && C.category == D.category
        end
    elseif length(C.simples) != length(D.simples)
        return false
    end
    return base_ring(C) == base_ring(D) && C.category == D.category && *([isequal_without_parent(s,t) for (s,t) ∈ zip(C.simples, D.simples)]...)
end

function isequal_without_parent(X::CentralizerObject, Y::CentralizerObject)
    return object(X) == object(Y) && half_braiding(X) == half_braiding(Y)
end

is_multifusion(C::CentralizerCategory) = is_multifusion(category(C))

function induction_generators(C::CentralizerCategory) 
    if isdefined(C, :induction_gens)
        return C.induction_gens
    end

    simpls = simples(category(C))
    ind_res = [induction_restriction(s, C.subcategory_simples) for s ∈ simpls]

    # Group the simples by isomorphic inductions
    is_iso = [s == t ? true : is_isomorphic(s,t)[1] for s ∈ ind_res, t ∈ ind_res]
    groups = connected_components(graph_from_adjacency_matrix(Undirected, is_iso))

    C.induction_gens = [simpls[g[1]] for g ∈ groups]
end

#-------------------------------------------------------------------------------
#   Centralizer Constructor
#-------------------------------------------------------------------------------
"""
    centralizer(C::Category, S::Vector{<:Object})
    centralizer(C::Category, X::Object)

Return the Müger centralizer of ```C``` with respect to the 
full topologizing subcategory generated by ``S``.
"""
function centralizer(C::Category, S::Vector{<:Object}; equivalence = false)
    @assert is_semisimple(C) "Semisimplicity required"
    return CentralizerCategory(C,S)
end

centralizer(C::Category, S::Object) = centralizer(C,[S])
centralizer(S::Vector{<:Object}) = centralizer(parent(S[1]), S)
centralizer(X::Object) = centralizer(parent(X), [X])

function Morphism(dom::CentralizerObject, cod::CentralizerObject, m::Morphism)
    return CentralizerMorphism(dom,cod,m)
end


"""
    half_braiding(Z::CentralizerObject)

Return  a vector with half braiding morphisms ```Z⊗S → S⊗Z``` for all simple
objects ```S```.
"""
half_braiding(Z::CentralizerObject) = Z.γ


"""
    object(X::CentralizerObject)

Return the image under the forgetful functor.
"""
object(X::CentralizerObject) = X.object

@doc raw""" 

    morphism(f::CentralizerMorphism)

Return the image under the forgetful functor.
"""
morphism(f::CentralizerMorphism) = f.m

is_weakly_fusion(C::CentralizerCategory) = true
is_fusion(C::CentralizerCategory) = all([int_dim(End(s)) == 1 for s ∈ simples(C)])
is_abelian(C::CentralizerCategory) = true
is_linear(C::CentralizerCategory) = true
is_monoidal(C::CentralizerCategory) = true

"""
    add_simple!(C::CentralizerCategory, S::CentralizerObject)

Add the simple object ```S``` to the vector of simple objects.
"""
function add_simple!(C::CentralizerCategory, S::CentralizerObject)
    @assert dim(End(S)) == 1 "Not simple"
    if isdefined(C, :simples)
        C.simples = filter(e -> e != zero(C), unique_simples([simples(C); S]))
    else
        C.simples = filter(e -> e != zero(C), unique_simples([S]))
    end
end


function add_simple!(C::CentralizerCategory, S::Array{CentralizerObject})
    @assert prod(dim(End(s)) for s ∈ S) == 1 "Not simple"
    if isdefined(C, :simples)
        C.simples = unique_simples([simples(C); S])
    else
        C.simples = unique_simples(S)
    end
end

"""
    spherical(X::CentralizerObject)

Return the spherical structure ```X → X∗∗``` of ```X```.
"""
spherical(X::CentralizerObject) = Morphism(X,dual(dual(X)), spherical(X.object))

(F::Field)(f::CentralizerMorphism) = F(f.m)

#=-------------------------------------------------
    MISC 
-------------------------------------------------=#

==(f::CentralizerMorphism, g::CentralizerMorphism) = f.m == g.m

#-------------------------------------------------------------------------------
#   Direct Sum & Tensor Product
#-------------------------------------------------------------------------------

"""
    direct_sum(X::CentralizerObject, Y::CentralizerObject)

Return the direct sum object of ```X``` and ```Y```.
"""
function direct_sum(X::CentralizerObject, Y::CentralizerObject)
    S = parent(X).subcategory_simples
    Z,(ix,iy),(px,py) = direct_sum(X.object, Y.object)

    γZ = [(id(S[i])⊗ix)∘(X.γ[i])∘(px⊗id(S[i])) + (id(S[i])⊗iy)∘(Y.γ[i])∘(py⊗id(S[i])) for i ∈ 1:length(S)]

    CZ = CentralizerObject(parent(X), Z, γZ)
    ix,iy = CentralizerMorphism(X,CZ,ix), CentralizerMorphism(Y,CZ, iy)
    px,py = CentralizerMorphism(CZ,X,px), CentralizerMorphism(CZ,Y,py)
    return CZ,[ix,iy],[px,py]
end



"""
    direct_sum(f::CentralizerMorphism, g::CentralizerMorphism)

Return the direct sum of ```f``` and ```g```.
"""
function direct_sum(f::CentralizerMorphism, g::CentralizerMorphism)
    dom = domain(f) ⊕ domain(g)
    cod = codomain(f) ⊕ codomain(g)
    m = f.m ⊕ g.m
    return Morphism(dom,cod, m)
end

"""
    tensor_product(X::CentralizerObject, Y::CentralizerObject)

Return the tensor product of ```X``` and ```Y```.
"""
function tensor_product(X::CentralizerObject, Y::CentralizerObject)
    Z = X.object ⊗ Y.object
    γ = Morphism[]
    simple_objects = parent(X).subcategory_simples

    x,y = X.object, Y.object

    for (S, yX, yY) ∈ zip(simple_objects, half_braiding(X), half_braiding(Y))

        half_braiding_with_S = associator(S,x,y) ∘ 
                                (yX⊗id(y)) ∘
                                inv_associator(x,S,y) ∘ 
                                (id(x)⊗yY) ∘ 
                                associator(x,y,S)
                                
        push!(γ, half_braiding_with_S)
    end
    return CentralizerObject(parent(X), Z, γ)
end


"""
    tensor_product(f::CentralizerMorphism,g::CentralizerMorphism)

Return the tensor product of ```f``` and ```g```.
"""
function tensor_product(f::CentralizerMorphism,g::CentralizerMorphism)
    dom = domain(f)⊗domain(g)
    cod = codomain(f)⊗codomain(g)
    return Morphism(dom,cod,f.m⊗g.m)
end

"""
    zero(C::CentralizerCategory)

Return the zero object of ```C```.
"""
function zero(C::CentralizerCategory)
    Z = zero(C.category)
    CentralizerObject(C,Z,[zero_morphism(Z,Z) for _ ∈ C.subcategory_simples])
end

"""
    one(C::CentralizerCategory)

Return the one object of ```C```.
"""
function one(C::CentralizerCategory)
    Z = one(C.category)
    CentralizerObject(C,Z,[id(s) for s ∈ C.subcategory_simples])
end



@doc raw""" 

    half_braiding(X::CentralizerObject, Y::Object)

Return the half braiding isomorphism ```γ_X(Y): X⊗Y → Y⊗X```.
"""
function half_braiding(X::CentralizerObject, Y::Object)
    simpls = parent(X).subcategory_simples

    if is_simple(Y) 
        if !(Y ∈ simpls)
            k = findfirst(e -> is_isomorphic(e, Y)[1], simpls)
            iso = is_isomorphic(Y,simpls[k])[2]
            return (inv(iso)⊗id(X.object)) ∘ X.γ[k] ∘ (id(X.object)⊗iso)
        else
            k = findfirst(e -> e == Y, simpls)
            return X.γ[k]
        end
    end
    dom = X.object⊗Y
    cod = Y⊗X.object
    braid = zero_morphism(dom, cod)
   
  
    _,iso, incl, proj = direct_sum_decomposition(Y)

    for (p,i) ∈ zip(proj, incl)
        k = findfirst(e -> is_isomorphic(e, domain(i))[1], simpls)
        incliso = is_isomorphic(domain(i), domain(i))[2]
        #projiso = is_isomorphic(codomain(p), )[2]

        i = i ∘ incliso
        p = inv(incliso) ∘ p 

        braid = braid + (i⊗id(X.object))∘X.γ[k]∘(id(X.object)⊗p)
    end

    return braid
end


#-------------------------------------------------------------------------------
#   Functionality
#-------------------------------------------------------------------------------

"""
    dim(X::CentralizerObject)

Return the categorical dimension of ```X```.
"""
dim(X::CentralizerObject) = dim(X.object)

"""
    simples(C::CentralizerCategory)

Return a vector containing the simple objects of ```C```. 
"""
function simples(C::CentralizerCategory; sort = false, show_progress = false)
    if isdefined(C, :simples) 
        return C.simples 
    end
    # if is_modular(category(C))
    #     C.simples = center_simples_by_braiding(category(C), C)
    #     return C.simples
    # end
    simples_by_induction!(C, show_progress)
    if sort 
        sort_simples_by_dimension!(C)
    end
    return C.simples
end


function decompose(X::CentralizerObject)
    C = parent(X)
    if isdefined(C, :simples)
        return decompose_by_simples(X,simples(C))
    else
        try
            return decompose_by_endomorphism_ring(X)
        catch
            @assert is_semisimple(C)
            error("cannot decompose")
            indecs = indecomposable_subobjects(X)
            return [(x, div(int_dim(Hom(x,X)), int_dim(End(x)))) for x ∈ indecs]
        end
    end
end

function decompose(X::CentralizerObject, S::Vector{CentralizerObject})
    decompose_by_simples(X,S)
end

# function indecomposable_subobjects(X::CentralizerObject)

#     !is_split_semisimple(category(parent(X))) && return _indecomposable_subobjects(X)


#     B = basis(End(object(X)))

#     if length(B) == 1
#         return [X]
#     end

#     S = simples(parent(object(X)))

#     if length(B) ≤ length(S)^2
#         return _indecomposable_subobjects(X)
#     end

#     eig_spaces = []


#     while length(eig_spaces) ≤ 1 && length(B) > 0
#         f = popat!(B, rand(eachindex(B)))
#         proj_f = central_projection(X,X,f,S)
#         eig_spaces = collect(values(eigenvalues(proj_f)))
#     end

#     if length(eig_spaces) ≤ 1 
#         is_simple(X) && return [X]
#         return [x for (x,k) ∈ decompose(X)]
#     end

#     return unique_simples(vcat([indecomposable_subobjects(Y) for Y ∈ eig_spaces]...))
# end

# function indecomposable_subobjects_of_induction(X::Object, IX::CentralizerObject = induction(X))
#     @assert object(IX) == X
#     B = basis(Hom(X, object(IX)))

#     while length(B) > 0
#         f = popat!(B, rand(eachindex(B)))
#         f = induction_adjunction(f,IX,IX)
        
#         eig = collect(values(eigenspaces(f)))

#         length(B) ≥ 2 && break
#     end
# end


"""
    associator(X::CentralizerObject, Y::CentralizerObject, Z::CentralizerObject)

Return the associator isomorphism ```(X⊗Y)⊗Z → X⊗(Y⊗Z)```.
"""
function associator(X::CentralizerObject, Y::CentralizerObject, Z::CentralizerObject)
    dom = (X⊗Y)⊗Z
    cod = X⊗(Y⊗Z)
    return Morphism(dom,cod, associator(X.object, Y.object, Z.object))
end

matrices(f::CentralizerMorphism) = matrices(f.m)
matrix(f::CentralizerMorphism) = matrix(f.m)

"""
    compose(f::CentralizerMorphism, g::CentralizerMorphism)

Return the composition ```g∘f```.
"""
compose(f::CentralizerMorphism, g::CentralizerMorphism) = Morphism(domain(f), codomain(g), g.m∘f.m) 

"""
    dual(X::CentralizerObject)

Return the (left) dual object of ```X```.
"""
function dual(X::CentralizerObject)
    a = associator
    inv_a = inv_associator
    e = ev(X.object)
    c = coev(X.object)
    γ = Morphism[]
    dX = dual(X.object)
    for (Xi,yXi) ∈ zip(parent(X).subcategory_simples, X.γ)
        f = (e ⊗ id(Xi ⊗ dX)) ∘ 
            inv_a(dX, X.object, Xi ⊗ dX) ∘ 
            (id(dX) ⊗ a(X.object, Xi, dX)) ∘ 
            (id(dX) ⊗ (inv(yXi) ⊗ id(dX))) ∘ 
            (id(dX) ⊗ inv_a(Xi, X.object, dX)) ∘ 
            a(dX, Xi, X.object ⊗ dX) ∘ 
            (id(dX ⊗ Xi) ⊗ c)
        γ = [γ; f]
    end
    return CentralizerObject(parent(X),dX,γ)
end

"""
    ev(X::CentralizerObject)

Return the evaluation morphism ``` X⊗X → 1```.
"""
function ev(X::CentralizerObject)
    Morphism(dual(X)⊗X,one(parent(X)),ev(X.object))
end

"""
    coev(X::CentralizerObject)

Return the coevaluation morphism ```1 → X⊗X∗```.
"""
function coev(X::CentralizerObject)
    Morphism(one(parent(X)),X⊗dual(X),coev(X.object))
end

"""
    id(X::CentralizerObject)

Return the identity on ```X```.
"""
id(X::CentralizerObject) = Morphism(X,X,id(X.object))

"""
    tr(f:::CentralizerMorphism)

Return the categorical trace of ```f```.
"""
function tr(f::CentralizerMorphism)
    C = parent(domain(f))
    return CentralizerMorphism(one(C),one(C),tr(f.m))
end

"""
    inv(f::CentralizerMorphism)

Return the inverse of ```f```if possible.
"""
function inv(f::CentralizerMorphism)
    return Morphism(codomain(f),domain(f), inv(f.m))
end


"""
    is_isomorphic(X::CentralizerObject, Y::CentralizerObject)

Check if ```X≃Y```. Return ```(true, m)``` where ```m```is an isomorphism if true,
else return ```(false,nothing)```.
"""
function is_isomorphic(X::CentralizerObject, Y::CentralizerObject)
    # TODO: Fix This. How to compute a central isomorphism?

    if is_simple(X) && is_simple(Y)
        H = Hom(X,Y)
        if int_dim(H) > 0
            return true, basis(H)[1]
        else
            return false, nothing
        end
    end

    S = simples(parent(X))

    if [dim(Hom(X,s)) for s ∈ S] == [dim(Hom(Y,s)) for s ∈ S]
        _, iso = is_isomorphic(X.object, Y.object)
        return true, Morphism(X,Y,central_projection(X,Y,iso))
    else
        return false, nothing
    end
end

function +(f::CentralizerMorphism, g::CentralizerMorphism)
    return Morphism(domain(f), codomain(f), g.m +f.m)
end

function *(x, f::CentralizerMorphism)
    return Morphism(domain(f),codomain(f),x*f.m)
end
#-------------------------------------------------------------------------------
#   Functionality: Image
#-------------------------------------------------------------------------------

"""
    kernel(f::CenterMoprhism)

Return a tuple ```(K,k)``` where ```K```is the kernel object and ```k```is the inclusion.
"""
function kernel(f::CentralizerMorphism)
    ker, incl = kernel(f.m)
    #f_inv = left_inverse(incl)

    if ker == zero(parent(f.m))
        return zero(parent(f)), zero_morphism(zero(parent(f)), domain(f))
    end

    braiding = [id(s)⊗left_inverse(incl)∘γ∘(incl⊗id(s)) for (s,γ) ∈ zip(parent(f).subcategory_simples, domain(f).γ)]

    Z = CentralizerObject(parent(domain(f)), ker, braiding)
    return Z, Morphism(Z,domain(f), incl)
end

"""
    cokernel(f::CentralizerMorphism)

Return a tuple ```(C,c)``` where ```C```is the cokernel object and ```c```is the projection.
"""
function cokernel(f::CentralizerMorphism)
    coker, proj = cokernel(f.m)
    #f_inv = right_inverse(proj)

    if coker == zero(parent(f.m))
        return zero(parent(f)), zero_morphism(codomain(f), zero(parent(f)))
    end

    braiding = [(id(s)⊗proj)∘γ∘(right_inverse(proj)⊗id(s)) for (s,γ) ∈ zip(parent(f).subcategory_simples, codomain(f).γ)]

    Z = CentralizerObject(parent(domain(f)), coker, braiding)
    return Z, Morphism(codomain(f),Z, proj)
end

function image(f::CentralizerMorphism)
    I, incl = image(f.m)

    if I == zero(parent(f.m))
        return zero(parent(f)), zero_morphism(zero(parent(f)), domain(f))
    end

    braiding = [id(s)⊗left_inverse(incl)∘γ∘(incl⊗id(s)) for (s,γ) ∈ zip(parent(f).subcategory_simples, codomain(f).γ)]

    Z = CentralizerObject(parent(domain(f)), I, braiding)
    return Z, Morphism(Z,domain(f), incl)
end


# function left_inverse(f::CentralizerMorphism)
#     X = domain(f)
#     Y = codomain(f)
#     l_inv = central_projection(Y,X,left_inverse(morphism(f)))
#     return Morphism(Y,X,l_inv)
# end

function quotient(Y::CentralizerObject, X::Object)
    # TODO: Compute quotient
    @assert parent(X) == parent(Y).Category
end

#-------------------------------------------------------------------------------
#   Hom Spaces
#-------------------------------------------------------------------------------


Hom(X::CentralizerObject, Y::CentralizerObject) = hom_by_adjunction(X,Y)

@doc raw""" 

    central_projection(X::CentralizerObject, Y::CentralizerObject, f::Morphism)

Compute the image under the projection ```Hom(F(X),F(Y)) → Hom(X,Y)```.
"""
function central_projection(dom::CentralizerObject, cod::CentralizerObject, f::Morphism, simpls = parent(dom).subcategory_simples)
    X = domain(f)
    Y = codomain(f)
    C = parent(X)
    D = dim(C)
    proj = zero_morphism(X, Y)
    a = associator
    inv_a = inv_associator

    for (Xi, yX) ∈ zip(simpls, dom.γ)
        dXi = dual(Xi)

        yY = half_braiding(cod, dXi)
        
        ϕ = (ev(dXi)⊗id(Y))∘inv_a(dual(dXi),dXi,Y)∘(spherical(Xi)⊗yY)∘a(Xi,Y,dXi)∘((id(Xi)⊗f)⊗id(dXi))∘(yX⊗id(dXi))∘inv_a(X,Xi,dXi)∘(id(X)⊗coev(Xi))

        proj = proj + dim(Xi)*ϕ
    end
    return Morphism(dom, cod, inv(D*base_ring(dom)(1))*proj)
end

"""
    zero_morphism(X::CentralizerObject, Y::CentralizerObject)

Return the zero morphism ```0:X → Y```.
"""
zero_morphism(X::CentralizerObject, Y::CentralizerObject) = Morphism(X,Y,zero_morphism(X.object,Y.object))

#-------------------------------------------------------------------------------
#   Pretty Printing
#-------------------------------------------------------------------------------

function show(io::IO, X::CentralizerObject)
    print(io, "Central object: $(X.object)")
end

function show(io::IO, C::CentralizerCategory)
    print(io, "Drinfeld centralizer of $(C.category)")
end

function show(io::IO, f::CentralizerMorphism)
    print(io, "Morphism in $(parent(domain(f)))")
end


#=------------------------------------------------
    Centralizer by Induction
------------------------------------------------=#
function add_induction!(C::CentralizerCategory, X::Object, IX::CentralizerObject)
    if isdefined(C, :inductions)
        if !(X ∈ keys(C.inductions))
            push!(C.inductions, X => IX)
        end
    else
        C.inductions = Dict(X => IX)
    end
end

function simples_by_induction!(C::CentralizerCategory, log = true)
    S = CentralizerObject[]
    d = dim(C.category)^2
    C.induction_gens = object_type(category(C))[]
    simpls = simples(C.category)

    FI_simples = []

    ind_res = [induction_restriction(s, C.subcategory_simples) for s ∈ simpls]

    # Group the simples by isomorphic inductions
    is_iso = [s == t ? true : is_isomorphic(s,t)[1] for s ∈ ind_res, t ∈ ind_res]
    groups = connected_components(graph_from_adjacency_matrix(Undirected, is_iso))
    
    for gr ∈ groups 
        Is = relative_induction(simpls[gr[1]], C.subcategory_simples, simpls, parent_category = C)
        push!(FI_simples, (simpls[gr[1]], ind_res[gr[1]], Is))
        push!(C.induction_gens, simpls[gr[1]])
    end
    
    log && println("Simples:")

    #center_dim = 0

    for k ∈ eachindex(FI_simples)

        s, _, Z = FI_simples[k]
        #contained_simples = filter(x -> int_dim(Hom(object(x),s)) != 0, S)
        # if length(contained_simples) > 0
        #     if is_isomorphic(Is, direct_sum(object.(contained_simples))[1])[1]
        #         continue
        #     end
        # end

        #Z = induction(s, simpls, parent_category = C)

        # for x ∈ contained_simples
        #     f = horizontal_direct_sum(basis(Hom(x,Z)))
        #     Z = cokernel(f)[1]
        # end

        # Compute subobjects by computing central primitive central_primitive_idempotents of End(I(X))
        H = end_of_induction(s, C.subcategory_simples, Z)
        # idems = central_primitive_idempotents(H)
        new_simples = [n for (n,_) ∈ decompose_by_endomorphism_ring(Z,H)]

        # Every simple such that Hom(s, Zᵢ) ≠ 0 for an already dealt with s is not new
        filter!(Zi -> sum(Int[int_dim(Hom(s,object(Zi))) for (s,_) ∈ FI_simples[1:k-1]]) == 0, new_simples)

        # if length(new_simples) == 0
        #     continue
        # end
        
        log && println.(["    " * "$s" for s ∈ new_simples])

        S = [S; new_simples]
        #center_dim += sum(dim.(new_simples).^2)
        # if d == center_dim
        #     break
        # end
    end
    C.simples = S
end

function sort_simples_by_dimension!(C::CentralizerCategory)  
    fp_dims = [fpdim(s) for s ∈ simples(C)]
    σ = sortperm(fp_dims, by = abs)
    C.simples = C.simples[σ]
end


#=----------------------------------------------------------
    Hom Spaces 2.0 
----------------------------------------------------------=#


function hom_by_adjunction(X::CentralizerObject, Y::CentralizerObject)
    Z = parent(X)
    C = category(Z)

    S = induction_generators(Z)

    X_Homs = [Hom(object(X),s) for s ∈ S]
    Y_Homs = [Hom(s,object(Y)) for s ∈ S]

    candidates = [int_dim(H)*int_dim(H2) > 0 for (H,H2) ∈ zip(X_Homs,Y_Homs)]

    !any(candidates) && return HomSpace(X,Y, CentralizerMorphism[]) 

    
    # X_Homs = X_Homs[candidates]
    # Y_Homs = Y_Homs[candidates]
    

    M = zero_matrix(base_ring(C),0,*(size(matrix(zero_morphism(X,Y)))...))

    mors = []

    @threads for i ∈ findall(==(true), candidates)
        s, X_s, s_Y = S[i], X_Homs[i], Y_Homs[i]
        Is = relative_induction(s, Z.subcategory_simples, parent_category = Z)

        B = induction_right_adjunction(X_s, X, Is)
        B2 = induction_adjunction(s_Y, Y, Is)

        # Take all combinations
        B3 = [h ∘ b for b ∈ B, h in B2][:]
        mors = [mors; B3]
        # Build basis
    end
    
    mats = matrix.(mors)
    M = transpose(matrix(base_ring(C), hcat(hcat([collect(m)[:] for m in mats]...))))

    Mrref = hnf(M)
    base = CentralizerMorphism[]
    mats_morphisms = Morphism.(mats)

    for k ∈ 1:rank(Mrref)
        coeffs = express_in_basis(Morphism(transpose(matrix(base_ring(C), size(mats[1])..., Mrref[k,:]))), mats_morphisms)
        f = sum([m*bi for (m,bi) ∈ zip(coeffs, mors)])
        push!(base, f)
    end

    return HomSpace(X,Y, base)
end


function hom_by_linear_equations(X::CentralizerObject, Y::CentralizerObject)
    #@assert parent(X) == parent(Y)

    H = Hom(object(X), object(Y))
    B = basis(H)
    F = base_ring(X)
    n = length(basis(H))

    if n == 0 
        return HomSpace(X,Y, CentralizerMorphism[])
    end 

    Fx,poly_basis = polynomial_ring(F,n)
    
    eqs = []

    S = parent(X).subcategory_simples

    for (s,γₛ,λₛ) ∈ zip(S,half_braiding(X), half_braiding(Y))
        Hs = Hom(object(X)⊗s, s⊗object(Y))
        base = basis(Hs)
        if length(base) == 0
            continue
        end
        eq_i = [zero(Fx) for _ ∈ 1:length(base)]
        for (f,a) ∈ zip(B,poly_basis)
            coeffs = express_in_basis((id(s)⊗f)∘γₛ - λₛ∘(f⊗id(s)), base)
            eq_i = eq_i .+ (a .* coeffs)
        end
        
        eqs = [eqs; eq_i]

    end

    M = zero(matrix_space(F,length(eqs),n))

    for (i,e) ∈ zip(1:length(eqs),eqs)
        M[i,:] = [coeff(e, a) for a ∈ poly_basis]
    end

    N = nullspace(M)[2]

    _,cols = size(N)

    basis_coeffs = [collect(N[:,i]) for i ∈ 1:cols]

    center_basis = [CentralizerMorphism(X,Y,sum(b .* B)) for b ∈ basis_coeffs]

    return HomSpace(X,Y,center_basis)
end

function hom_by_projection(X::CentralizerObject, Y::CentralizerObject)
    b = basis(Hom(X.object, Y.object))

    projs = [central_projection(X,Y,f) for f in b]

    proj_exprs = [express_in_basis(p,b) for p ∈ projs]

    M = zero(matrix_space(base_ring(X), length(b),length(b)))
    for i ∈ 1:length(proj_exprs)
        M[i,:] = proj_exprs[i]
    end
    r, M = rref(M)
    H_basis = CentralizerMorphism[]
    for i ∈ 1:r
        f = Morphism(X,Y,sum([m*bi for (m,bi) ∈ zip(M[i,:], b)]))
        H_basis = [H_basis; f]
    end
    return HomSpace(X,Y,H_basis)
end


#=----------------------------------------------------------
    Modular Stuff 
----------------------------------------------------------=#    

function smatrix(C::CentralizerCategory)
    simpls = simples(C)
    n = length(simpls)
    K = base_ring(C)
    S = [zero_morphism(category(C)) for _ ∈ 1:n, _ ∈ 1:n]
    @threads for i ∈ 1:n
        for j ∈ i:n
            S[i,j] = S[j,i] = tr(half_braiding(simpls[i], object(simpls[j])) ∘ half_braiding(simpls[j], object(simpls[i])))
        end
    end

    try
        return matrix(K, n, n, [K(s) for s ∈ S])
    catch
        return S
    end
end

#=----------------------------------------------------------
    extension_of_scalars 
----------------------------------------------------------=#    

function extension_of_scalars(C::CentralizerCategory, L::Field)
    CL = _extension_of_scalars(C,L, category(C)⊗L)

    CL.simples = vcat([[x for (x,_) ∈ decompose(extension_of_scalars(s, L, CL))] for s ∈ simples(C)]...)

    if isdefined(C, :inductions)
        CL.inductions = Dict(extension_of_scalars(x, L, category(CL)) =>
                        extension_of_scalars(Ix, L, CL) for (x,Ix) ∈ C.inductions)
    end

    if isdefined(C, :induction_gens)
        CL.induction_gens = [extension_of_scalars(is, L, category(CL)) for is ∈ C.induction_gens]
    end

    return CL
end

function _extension_of_scalars(C::CentralizerCategory, L::Field, cL = category(C)⊗L)
    CentralizerCategory(cL)
end

function extension_of_scalars(X::CentralizerObject, L::Field, CL = _extension_of_scalars(parent(X),L))
    CentralizerObject(CL, extension_of_scalars(object(X), L, category(CL)), [f ⊗ L for f ∈ half_braiding(X)])
end

function karoubian_envelope(C::CentralizerCategory)
    KC = CentralizerCategory(category(C))
    simpls = unique_simples(vcat([simple_subobjects(s) for s ∈ simples(C)]...))
    KC.simples = [CentralizerObject(KC, object(s), half_braiding(s)) for s ∈ simpls]
    return KC
end


#=----------------------------------------------------------
    Centralizer for non-degenerate braided fusion categories
    by C ⊠ C^rev ≃ 𝒵(C) 
----------------------------------------------------------=#

# function center_simples_by_braiding(C::Category, Z = centralizer(C))
#     S = simples(C)

#     S_braided = [CentralizerObject(Z, s, [braiding(s,t) for t ∈ S]) for s ∈ S]
#     S_rev_braided = [CentralizerObject(Z, s, [inv(braiding(t,s)) for t ∈ S]) for s ∈ S]

#     [t⊗s for s ∈ S_braided, t ∈ S_rev_braided][:]
# end

#=----------------------------------------------------------
    Drinfeld Morphism 
----------------------------------------------------------=#

function drinfeld_morphism(X::CentralizerObject) 
    Morphism(X,dual(dual(X)), _drinfeld_morphism(X))
end

function _drinfeld_morphism(X::CentralizerObject)
    x = object(X)
    u = (ev(x)⊗id(dual(dual(x)))) ∘ 
        (half_braiding(X,dual(x))⊗id(dual(dual(x)))) ∘ 
        inv_associator(x, dual(x), dual(dual(x))) ∘ 
        (id(x)⊗coev(dual(x)))
end

function twist(X::CentralizerObject)
    u = _drinfeld_morphism(X)
    
    B,k = is_scalar_multiple(matrix(spherical(object(X))), matrix(u))

    !B && error("Something went wrong")

    return k
end
