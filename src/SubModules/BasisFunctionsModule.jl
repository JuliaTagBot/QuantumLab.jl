module BasisFunctionsModule
export PrimitiveGaussianBasisFunction, ContractedGaussianBasisFunction, identityPGF, identityCGF
import Base.show
import QuantumLab.BaseModule.evaluateFunction
using ..BaseModule

"""
A PrimitiveGaussianBasisFunction is a function of the form x^a y^b z^c exp(-ζ r^2) centered at a position in space. (a,b,c) here are by definition the cartesian MQuantumNumber tuple.
"""
mutable struct PrimitiveGaussianBasisFunction
  center::Position
  exponent::Float64
  mqn::MQuantumNumber
end

"""
A ContractedGaussianBasisFunction is defined as a sum of PrimitiveGaussianBasisFunctions with fixed relative coefficients. Different from other Quantum Chemistry codes we do not require
an additional scaling for the total ContractedGaussianBasisFunction - scaling the whole ContractedGaussianBasisFunction happens by modifying the contraction coefficients accordingly.
"""
mutable struct ContractedGaussianBasisFunction
  coefficients::Vector{Float64}
  primitiveBFs::Vector{PrimitiveGaussianBasisFunction}
end

function show(io::IO,::MIME"text/plain",cgbf::ContractedGaussianBasisFunction,indent="")
  print(io,indent); println(io,typeof(cgbf))
  for idx in 1:length(cgbf.coefficients)
    print(io,indent * "  $(cgbf.coefficients[idx]) × "); println(io,typeof(cgbf.primitiveBFs[idx]))
    print(io,indent * "    center:   "); println(io,cgbf.primitiveBFs[idx].center)
    print(io,indent * "    exponent: "); println(io,cgbf.primitiveBFs[idx].exponent)
    print(io,indent * "    mqn:      "); println(io,cgbf.primitiveBFs[idx].mqn)
  end
end

function evaluateFunction(x::Position,pgbf::PrimitiveGaussianBasisFunction)
  α = pgbf.exponent
  O = pgbf.center
  r = distance(x,O)
  return (x.x - O.x)^(pgbf.mqn.x) * (x.y - O.y)^(pgbf.mqn.y) * (x.z - O.z)^(pgbf.mqn.z) * exp(-α*r^2)
end

function evaluateFunction(x::Position,cgbf::ContractedGaussianBasisFunction)
  result = 0.
  for (coeff,pgbf) in zip(cgbf.coefficients,cgbf.primitiveBFs)
    result += coeff * evaluateFunction(x,pgbf)
  end
  return result
end

const identityPGF = PrimitiveGaussianBasisFunction(origin, 0., MQuantumNumber(0,0,0))
const identityCGF = ContractedGaussianBasisFunction([1.],[identityPGF])


end
