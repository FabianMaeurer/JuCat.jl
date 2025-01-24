#=----------------------------------------------------------
    Transfer algebraic numbers into a number_field
    along a complex embedding       
----------------------------------------------------------=#

function preimage(e::NumFieldEmb, x; tol = 10^(-10))

    # Get the number field in question
    K = number_field(e)

    # Get the Complex Field 
    CC = parent(e(K(1)))

    min = minpoly(x) 

    # roots in domain 
    rs = roots(change_base_ring(K, min))

    # Roots in Complex Field 
    complex_rs = e.(rs) 

    # find closest root 
    i = argmin(abs.(e.(rs) .- CC(x)))

    if abs(e(rs[i]) - CC(x)) > tol
        error("Preimage not in $K")
    end

    return rs[i]
end