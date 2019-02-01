#
# This file is a part of graphmol.jl
# Licensed under the MIT License http://opensource.org/licenses/MIT
#

export aromatic!


function aromatic!(mol::VectorMol; recalculate=false)
    if haskey(mol.v, :Aromatic) && !recalculate
        return
    end
    topology!(mol, recalculate=recalculate)
    elemental!(mol, recalculate=recalculate)
    # Precalculate carbonyl
    mol.v[:Aromatic] = falses(atomcount(mol))
    mol.v[:AromaticBond] = falses(bondcount(mol))
    for ring in mol.annotation[:Topology].rings
        sub = nodesubgraph(mol.graph, Set(ring))
        if satisfyHuckel(mol, ring)
            mol.v[:Aromatic][ring] .= true
            for e in edgekeys(sub)
                mol.v[:AromaticBond][e] = true
            end
        elseif nodetype(mol) === SmilesAtom
            # SMILES aromatic atom
            for (i, n) in nodesiter(sub)
                if n.isaromatic
                    mol.v[:Aromatic][i] = true
                end
            end
            for (i, e) in edgesiter(sub)
                if e.isaromatic
                    mol.v[:AromaticBond][i] = true
                end
            end
        end
    end
    return
end


function satisfyHuckel(mol::VectorMol, ring)
    cnt = 0
    # Carbonyl
    # TODO: polarized carbonyl
    carbonylC = Int[]
    carbonylO = findall(
        (mol.v[:Symbol] .== :O) .* (mol.v[:Degree] .== 1) .* (mol.v[:Pi] .== 1))
    for o in carbonylO
        c = collect(neighborkeys(mol.graph, o))[1]
        if mol.v[:Symbol][c] == :C
            push!(carbonylC, c)
        end
    end
    for r in ring
        if r in carbonylC
            continue
        elseif mol.v[:Pi][r] == 1
            cnt += 1
        elseif mol.v[:LonePair][r] === nothing
            return false
        elseif mol.v[:LonePair][r] > 0
            cnt += 2
        elseif mol.v[:LonePair][r] < 0
            continue
        else
            return false
        end
    end
    return cnt % 4 == 2
end
