# tmix=frames=15:weights="1 1 1 1 1 1 1 1 1 1 1 1 1 1 1" 
function getimg(file, t)
    imgraw = ffmpeg() do exe
        read(`$exe -loglevel 8 -ss $t -i $file -vf yadif=1,scale=sar"*"iw:ih -vframes 1 -f image2pipe -`)
    end
    return rotr90(ImageMagick.load_(imgraw)[end:-1:1, :])
end

function plotit(v::Singular, k, title, spot, img, io)
    title[] = k
    spot[] = Tuple(v.xyt[1:2])
    img[] = getimg(v.video, v.xyt[3])
    recordframe!(io)
end
function plotit(v::Interval, k, title, spot, img, io)
    title[] = k
    for i in round.(Int, range(1, stop = length(v.xyts), length = 10))
        # Y = size(img[], 1)
        spot[] = Tuple(v.xyts[i][1:2])
        img[] = getimg(v.video, v.xyts[i][3])
        recordframe!(io)
    end
end

function image_with_poi(pois)
    scene, layout = layoutscene(0)
    k, v = first(pois)
    title = Node(k)
    ax = layout[1,1] = LAxis(scene, aspect = DataAspect())
    spot = Node(Tuple(v.xyt[1:2]))
    img = Node(getimg(v.video, v.xyt[3]))
    image!(ax, img)
    scatter!(ax, spot, color = :transparent, strokecolor = :red, strokewidth = 3)
    text!(ax, title, position = lift(xy -> xy .- (0, 25), spot), textsize = 30, align = (:center, :top))
    tightlimits!(ax)
    hidedecorations!(ax)
    record(scene, "quality.mkv"; framerate = 2) do io
        for (k,v) in pois
            plotit(v, k, title, spot, img, io)
        end
    end
end

function plot_calibration(calib, pois)
    pois2 = Dict(k => calibrate(calib.tform, v) for (k, v) in pois)
    scene, layout = layoutscene()
    ax = layout[1,1] = LAxis(scene, aspect = DataAspect())
    img = getimg(pois["track"].video, 1.0)
    wimg = warp(img, CoordinateTransformations.Transformation(calib.tform))
    image!(ax, wimg)
    h = heatmap!(ax, calib.x, calib.y, calib.ϵ.(calib.x, calib.y'))
    cbar = layout[1, 2] = LColorbar(scene, h, label = "Error (mm)")
    hs = [myplot!(ax, v) for v in values(pois)]
    leg = layout[2, 1:2] = LLegend(scene, hs, string.(keys(pois2)))
    leg.orientation = :horizontal
    cbar.width = 30
    tightlimits!(ax)
    AbstractPlotting.save("calibration.png", scene)
end

myplot!(ax, v::Singular) = scatter!(ax, Tuple(v.xyt[1:2]))
myplot!(ax, v::Interval) = lines!(ax, [Tuple(xyt[1:2]) for xyt in v.xyts])
