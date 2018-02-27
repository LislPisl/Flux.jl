import Adapt: adapt

children(x) = ()
mapchildren(f, x) = x

children(x::Tuple) = x
mapchildren(f, x::Tuple) = map(f, x)

function treelike(T, fs = fieldnames(T))
  @eval current_module() begin
    children(x::$T) = ($([:(x.$f) for f in fs]...),)
    mapchildren(f, x::$T) = $T(f.(children(x))...)
    adapt(T, x::$T) = mapleaves(x -> adapt(T, x), x)
  end
end

isleaf(x) = isempty(children(x))

function mapleaves(f, x; cache = ObjectIdDict())
  haskey(cache, x) && return cache[x]
  cache[x] = isleaf(x) ? f(x) : mapchildren(x -> mapleaves(f, x, cache = cache), x)
end

using DataFlow: OSet

function prefor(f, x; seen = OSet())
  x ∈ seen && return
  f(x)
  foreach(x -> prefor(f, x, seen = seen), children(x))
  return
end

function params(m)
  ps = []
  prefor(p ->
    Tracker.istracked(p) && Tracker.isleaf(p) &&
      !any(p′ -> p′ === p, ps) && push!(ps, p),
    m)
  return ps
end

params(m...) = params(m)

# CPU/GPU movement conveniences

cpu(x) = adapt(Array, x)

default_adaptor = identity

@require CuArrays begin
  global default_adaptor = CuArrays.cu
end

gpu(x) = adapt(default_adaptor, x)
