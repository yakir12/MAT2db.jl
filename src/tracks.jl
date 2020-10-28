# const PointCollection = StructVector{TimedPoint}
# pointcollection(x::Missing, t₀) = StructVector{TimedPoint}(undef, 0)
# pointcollection(x, t₀) = StructVector(TimedPoint(Space(i[1], i[2]), i[3] - t₀) for i in eachrow(x.data))

struct Track
    coords::Vector{Space}
    t::StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}}
    tp::Int
end

function findturningpoint(::Missing, spl, tl, _)
    tp = gettpknot(spl)
    i = findfirst(≥(tp), tl)
    isnothing(i) && return length(tl)
    i
end

findturningpoint(t, _, tl, t₀) = findfirst(≥(t - t₀), tl)

function Track(xyt, tp)
    sort!(xyt, by = row -> row.t)
    Δt = mean(trim(diff(xyt.t), prop = 0.1))
    t, xy = filterdance(xyt.xy, Δt)
    spl = ParametricSpline(t, hcat(xy...); s = 250, k = 2)
    tl = range(0.0, step = Δt, stop = t[end])
    xyl = Space.(spl.(tl))
    i = findturningpoint(tp, spl, tl, xyt[1].t)
    Track(xyl, tl, i)
end

# homing(t::Track) = t.coords[1:t.tp]
# searching(t::Track) = t.coords[t.tp:end]
# center_of_search(t::Track) = mean(searching(t))
# turning_point(t::Track) = t.coords[t.tp]
Base.getproperty(x::Track, k::Symbol) = k === :homing ? x.coords[1:x.tp] :
                                         k === :searching ?  x.coords[x.tp:end] :
                                         k === :center_of_search ? mean(x.coords[x.tp:end]) :
                                         k === :turning_point ? x.coords[x.tp] :
                                         getfield(x, k)

const ignorefirst = 10 # cm
const bigturn = π/3 # 60°

_getv(spl, k) = SVector{2, Float64}(derivative(spl, k))

function gettpindex(spl, ks)
    tp = ks[1]
    vlast = _getv(spl, ks[1])
    for k in Iterators.drop(ks, 1)
        v = _getv(spl, k)
        Δ = angle(vlast, v)
        tp = k
        Δ > bigturn && break
        vlast = v
    end
    return tp
end

function gettpknot(spl)
    ks = Dierckx.get_knots(spl)
    filter!(k -> norm(spl(k) - spl(0)) > ignorefirst, ks)
    isempty(ks) && return 0.0
    tp2 = gettpindex(spl, ks)
    # return tp2
    tp1 = copy(tp2)
    for k in ks
        k == tp2 && break
        tp1 = k
    end
    tp1 += 0.1
    if tp1 < tp2
        main = _getv(spl, tp1)
        for t in tp2:-0.3:tp1
            v = _getv(spl, t)
            Δ = angle(main, v)
            Δ < bigturn && return t
        end
    end
    return tp2
end

function filterdance(xy, Δt)
    xy2 = [xy[1]]
    t = [0.0]
    for p in xy
        if norm(p - xy2[end]) > 4
            push!(xy2, p)
            push!(t, t[end] + Δt)
        else
            t[end] += Δt
        end
    end
    t .-= t[1]
    return t, xy2
end

