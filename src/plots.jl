legendlines = OrderedDict(
                            :homing => (linestyle = nothing, linewidth = 0.3, color = :black),
                            :searching => (linestyle = nothing, linewidth = 0.3, color = :gray),
                           )
markers = Dict(:turning_point => '•', :center_of_search => '■')
legendmarkers = OrderedDict(
                            :nest => (color = :black, marker = '⋆', strokecolor = :black, markerstrokewidth = 0.5, strokewidth = 0.5, markersize = 15px),
                            :feeder => (color = :transparent, marker = '•', strokecolor = :black, markerstrokewidth = 0.5, strokewidth = 0.5, markersize = 25px),
                            :fictive_nest => (color = :white, marker = '⋆', strokecolor = :black, markerstrokewidth = 0.5, strokewidth = 0.5, markersize = 10px),
                            :dropoff => (color = :black, marker = '↓', strokecolor = :white, markerstrokewidth = 0.5, strokewidth = 0.1, markersize = 15px),
                            :pickup => (color = :black, marker = '↑', strokecolor = :white, markerstrokewidth = 0.5, strokewidth = 0.1, markersize = 15px),
                            :turning_point => (color = :black, marker = markers[:turning_point], strokecolor = :transparent, markersize = 15px),
                            :center_of_search => (color = :black, marker = markers[:center_of_search], strokecolor = :transparent, markersize = 5px),
                            :pellets => (color = :black, marker = '▴', strokecolor = :black, markerstrokewidth = 0.5, strokewidth = 0.5, markersize = 15px),
                                          )
function plotrun(x)

    fig = Figure(resolution = (1000,1000))
    ax = fig[1, 1] = Axis(fig, aspect = DataAspect(), xlabel = "X (cm)", ylabel = "Y (cm)")

    # scene, layout = layoutscene()
    # ax = layout[1,1] = LAxis(scene, aspect = DataAspect(), xlabel = "X (cm)", ylabel = "Y (cm)")#, yreversed = true)
    h = OrderedDict()
    for (k,v) in legendlines
        h[k] = lines!(ax, getproperty(x, k); v...)
    end
    for (k,v) in legendmarkers
        xy = getproperty(x, k)
        if !ismissing(xy) && !isempty(xy)
            h[k] = scatter!(ax, xy; v...)
        end
    end
    fig[0,1] = Legend(fig, collect(values(h)), string.(keys(h)), orientation = :vertical, nbanks = 5, tellheight = true, height = Auto(), groupgap = 30);

    for radius in intervals
        lines!(ax, Circle(Point(x.dropoff), radius), color = :red)
    end
    fig
end

function plotrun_of_tracks(x)
    fig = Figure()
    ax = fig[1, 1] = Axis(fig, aspect = DataAspect(), xlabel = "X (cm)", ylabel = "Y (cm)")
    # scene, layout = layoutscene()
    # ax = layout[1,1] = LAxis(scene, aspect = DataAspect(), xlabel = "X (cm)", ylabel = "Y (cm)")#, yreversed = true)
    for (k,v) in x
        lines!(ax, space(v))
    end
    fig
end
