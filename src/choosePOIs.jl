function getimg(videofile, t)
    imgraw = ffmpeg() do exe
        read(`$exe -loglevel 8 -ss $t -i $videofile -vf tmix=frames=15:weights="1 1 1 1 1 1 1 1 1 1 1 1 1 1 1" -vframes 1 -f image2pipe -`)
    end
    return rotr90(ImageMagick.load_(imgraw))
end

function plotit(x::TimedCoordinate)
    c = (; context().data...)
    c.img[] = getimg(c.videofile, x.t)
    c.xy[] = x.xy
    cond = Condition()
    on(c.menu.selection) do _
        notify(cond)
    end
    wait(cond)
    # options = menu.options[]
    # i = findfirst(==(menu.selection[]), options)
    # deleteat!(options, i)
    # menu.options[] = options
    return c.menu.selection[]
end

plotit(xs::Track) = "track"

function get_pois(data, videofile)
    @memo videofile = videofile
    @memo img = Node(getimg(videofile, 0))
    on(img) do i
        FileIO.save(string(rand(1:9, 5), ".jpg"), i)
    end
    scene, layout = layoutscene()
    @memo menu = LMenu(scene, options = ["nest", "feeder", "dropoff", "pickup"])
    layout[1, 1] = vbox!(LText(scene, "Choose correct POI", width = nothing), menu, tellheight = false, width = 200)
    ax = layout[1, 2] = LAxis(scene, aspect = DataAspect())
    tightlimits!(ax)
    hidedecorations!(ax)
    @memo xy = Node(Coordinate(0.0, 0.0))
    image!(ax, img)
    scatter!(ax, xy, color = :transparent, strokecolor = :red, markersize = 30)
    glfw_window = to_native(display(scene))
    pois = plotit.(data)
    GLFW.SetWindowShouldClose(glfw_window, true) 
    return pois
end


