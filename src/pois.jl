firstpass(str) = match(r"^\s*(\w+)\s+(-?\d+)\s+(-?\d+)\s*$", str)

secondpass(::Nothing, str) = Symbol(strip(str)), nothing
function secondpass(m, _) 
    poi, _x, _y = m.captures
    x = parse(Float64, _x)
    y = parse(Float64, _y)
    return Symbol(poi), Space(x, y)
end

parsepoi(str) = secondpass(firstpass(str), str)

function parsepois(row) 
    poi_names = Symbol[]
    expected_locations = Dict{Symbol, Space}()
    for poi in split(row, ',')
        poi_name, xy = parsepoi(poi) 
        push!(poi_names, poi_name)
        if !isnothing(xy)
            expected_locations[poi_name] = xy
        end
    end
    (; poi_names, expected_locations)
end

function _adjust_expected(pois, expected_locations)
    e = @LArray Matrix(hcat(values(expected_locations)...)) (; Dict(k => (2i-1:2i) for (i,k) in enumerate(keys(expected_locations)))...)
    r = Matrix(hcat((only(space(pois[k])) for k in keys(expected_locations))...))
    R, μ = getR(e, r)
    Dict(k => Space(R * e[k] + μ) for k in keys(expected_locations))
end

function getR(e, r)
    e .-= mean(e, dims = 2)
    μr = mean(r, dims = 2)
    r .-= μr
    F = svd(e * r')
    R = F.V * F.U'
    return R, μr
end

adjust_expected(pois, expected_locations) = length(expected_locations) ≤ 1 ?  Dict(k => only(space(pois[k])) for k in keys(expected_locations)) : _adjust_expected(pois, expected_locations)

function flipy!(pois)
    ymax = maximum(maximum(last, space(v)) for v in values(pois))
    for v in values(pois), row in LazyRows(v.xyt)
        x2, y = row.xy
        row.xy = Space(x2, ymax - y)
    end
end
