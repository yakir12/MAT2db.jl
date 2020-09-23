
firstpass(str) = match(r"^\s*(\w+)\s+(-?\d+)\s+(-?\d+)\s*$", str)
secondpass(::Nothing, str) = strip(str), nothing
function secondpass(m, _) 
    poi, _x, _y = m.captures
    x = parse(Float64, _x)
    y = parse(Float64, _y)
    return poi, Space(x, y)
end
parsepoi(str) = secondpass(firstpass(str), str)
function parsepois(row) 
    poi_names = String[]
    expected_locations = Dict{String, Space}()
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
    y = Dict{String, Space}()
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

