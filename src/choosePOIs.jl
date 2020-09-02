function getimg(file, t)
    imgraw = ffmpeg() do exe
        read(`$exe -loglevel 8 -ss $t -i $file -vf tmix=frames=15:weights="1 1 1 1 1 1 1 1 1 1 1 1 1 1 1" -vframes 1 -f image2pipe -`)
    end
    return rotr90(ImageMagick.load_(imgraw))
end

function plotit(x::Singular, img, xy, menu)
    img[] = getimg(x.video, time(x))
    xy[] = space(x)
    cond = Condition()
    on(menu.selection) do _
        notify(cond)
    end
    wait(cond)
    #
    # TODO remove selected items so that poi_names are unique
    #
    # options = menu.options[]
    # i = findfirst(==(menu.selection[]), options)
    # deleteat!(options, i)
    # menu.options[] = options
    return c.menu.selection[]
end

plotit(xs::Interval) = "track"

function get_poi_names(data)
    img = Node(getimg(data[1].video, 0))
    scene, layout = layoutscene()
    menu = LMenu(scene, options = POI_NAMES)
    layout[1, 1] = vbox!(LText(scene, "Choose correct POI", width = nothing), menu, tellheight = false, width = 200)
    ax = layout[1, 2] = LAxis(scene, aspect = DataAspect())
    tightlimits!(ax)
    hidedecorations!(ax)
    xy = Node(Coordinate(0.0, 0.0))
    image!(ax, img)
    scatter!(ax, xy, color = :transparent, strokecolor = :red, markersize = 30)
    glfw_window = to_native(display(scene))
    poi_names = [plotit(x, img, xy, menu) for x in data]
    GLFW.SetWindowShouldClose(glfw_window, true) 
    return poi_names
end

function badpoi_names(poi_names, data)
    if length(poi_names) ≠ length(data)
        @warn "number of POI names not equal to number of POI coordinates"
        return true
    end
    if !isuinque(poi_names)
        @warn "POI names are not unique"
        return true
    end
    if any(name -> occursin(" ", name), poi_names)
        @warn "POI names may not contain spaces"
        return true
    end
    return false
end

