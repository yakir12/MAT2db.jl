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

function adjust_expected(e2c)
    n = length(e2c)
    y = Dict{Symbol, Space}()
    if n ≤ 1
        for (k, v) in e2c
            y[k] = last(v)
        end
    else
        realpoints = Matrix{Float64}(undef, 2, n)
        expectedpoints = Matrix{Float64}(undef, 2, n)
        for (i, v) in enumerate(values(e2c))
            e, c = v
            expectedpoints[:, i] .= e
            realpoints[:, i] .= c
        end
        μr = mean(realpoints, dims = 2)
        μe = mean(expectedpoints, dims = 2)
        realpoints .-= μr
        expectedpoints .-= μe
        F = svd(expectedpoints * realpoints')
        R = F.V * F.U'
        expectedpoints = R * expectedpoints .+ μr
        for (i, k) in enumerate(keys(e2c))
            y[k] = Space(expectedpoints[:, i])
        end
    end
    return y
end

function flipy!(pois)
    ymax = maximum(maximum(last, space(v)) for v in values(pois))
    for v in values(pois), row in LazyRows(v.xyt)
        x2, y = row.xy
        row.xy = Space(x2, ymax - y)
    end
end
