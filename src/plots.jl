legendlines = OrderedDict(
                            :homing => (linestyle = nothing, linewidth = 0.3, color = :black),
                            :searching => (linestyle = nothing, linewidth = 0.3, color = :gray),
                           )
markers = Dict(:turning_point => '•', :center_of_search => '■')
legendmarkers = OrderedDict(
                            :nest => (color = :black, marker = '⋆', strokecolor = :black, markerstrokewidth = 0.5, strokewidth = 0.5, markersize = 15px),
                            :feeder => (color = :transparent, marker = '•', strokecolor = :black, markerstrokewidth = 0.5, strokewidth = 0.5, markersize = 25px),
                            :fictive_nest => (color = :white, marker = '⋆', strokecolor = :black, markerstrokewidth = 0.5, strokewidth = 0.5, markersize = 15px),
                            :dropoff => (color = :black, marker = '↓', strokecolor = :white, markerstrokewidth = 0.5, strokewidth = 0.1, markersize = 15px),
                            :pickup => (color = :black, marker = '↑', strokecolor = :white, markerstrokewidth = 0.5, strokewidth = 0.1, markersize = 15px),
                            :turning_point => (color = :black, marker = markers[:turning_point], strokecolor = :transparent, markersize = 15px),
                            :center_of_search => (color = :black, marker = markers[:center_of_search], strokecolor = :transparent, markersize = 5px),
                            :pellets => (color = :black, marker = '▴', strokecolor = :black, markerstrokewidth = 0.5, strokewidth = 0.5, markersize = 15px),
                                          )
function plotrun(x)
    scene, layout = layoutscene()
    ax = layout[1,1] = LAxis(scene, aspect = DataAspect(), xlabel = "X (cm)", ylabel = "Y (cm)")#, yreversed = true)
    for (k,v) in legendlines
        lines!(ax, getproperty(x, k); v...)
    end
    for (k,v) in legendmarkers
        xy = getproperty(x, k)
        if !ismissing(xy) && !isempty(xy)
            scatter!(ax, xy; v...)
        end
    end
    scene
end

