@ctx function getimg!(t)
    c = context()
    video = c.data[:video]
    img = c.data[:img]
    seek(video, t)
    img[] = rotr90(read(video))
end

@ctx function plotit!(x::TimedCoordinate)
    getimg!(x.t)
    c = context()
    xy = c.data[:xy]
    menu = c.data[:menu]
    xy[] = x.xy
    c = Condition()
    on(menu.selection) do _
        notify(c)
    end
    wait(c)
    # options = menu.options[]
    # i = findfirst(==(menu.selection[]), options)
    # deleteat!(options, i)
    # menu.options[] = options
    return menu.selection[]
end

plotit!(xy, img, xs::Track, _) = "track"

@ctx function get_pois(data, videofile)
    @memo video = VideoIO.openvideo(videofile)
    @memo img = Node(rotr90(read(video)))
    scene, layout = layoutscene()
    @memo menu = LMenu(scene, options = ["nest", "feeder", "dropoff", "pickup"])
    layout[1, 1] = vbox!(LText(scene, "Choose correct POI", width = nothing), menu, tellheight = false, width = 200)
    ax = layout[1, 2] = LAxis(scene, aspect = DataAspect())
    tightlimits!(ax)
    hidedecorations!(ax)
    @memo xy = Node(Coordinate(0.0, 0.0))
    image!(ax, img)
    scatter!(ax, xy)
    glfw_window = to_native(display(scene))
    pois = plotit!.(data)
    GLFW.SetWindowShouldClose(glfw_window, true) 
    return pois
end
