# tmix=frames=15:weights="1 1 1 1 1 1 1 1 1 1 1 1 1 1 1" 
function getimg(file, t)
    imgraw = FFMPEG.ffmpeg() do exe
        read(`$exe -loglevel 8 -ss $t -i $file -vf yadif=1,scale=sar"*"iw:ih -vframes 1 -f image2pipe -`)
    end
    return rotr90(ImageMagick.load_(imgraw))
end

function plotrawpoi(poi::POI, file)
    scene, layout = layoutscene(0)
    ax = layout[1,1] = LAxis(scene, aspect = DataAspect(), xlabel = "X (pixel)", ylabel = "Y (pixel)")
    ind = Node(1)
    img = lift(ind) do i
        getimg(poi.video, time(poi, i))
    end
    spot = lift(ind) do i
        space(poi, i)
    end
    image!(ax, img)
    scatter!(ax, spot, color = :transparent, strokecolor = :red, strokewidth = 3)
    tightlimits!(ax)
    recordit(poi, file, ind, scene)
end

recordit(::Singular, file, _, scene) = AbstractPlotting.save("$file.png", scene)

function recordit(poi::Interval, file, ind, scene)
    fps = 15
    AbstractPlotting.inline!(true)
    record(scene, "$file.mkv", round.(Int, range(1, stop = length(poi.xyts), length = 1fps)); framerate = fps) do i
        ind[] = i
    end
    AbstractPlotting.inline!(false)
end

@memoize function plotcalibration(calibration::Calibration, calib, file)
    scene, layout = layoutscene(0)
    ax = layout[1,1] = LAxis(scene, aspect = DataAspect(), xlabel = "X (pixel)", ylabel = "Y (pixel)", title = "Raw")
    img = getimg(calibration.video, calibration.extrinsic)
    image!(ax, img)
    tightlimits!(ax)
    ax = layout[1,2] = LAxis(scene, aspect = DataAspect(), xlabel = "X (cm)", ylabel = "Y (cm)", title = "Calibrated")
    indices = ImageTransformations.autorange(img, calib.tform)
    img = parent(warp(img, calib.itform, indices))
    image!(ax, indices..., img)
    tightlimits!(ax)
    layout[2,1:2] = LText(scene, "ϵ (±cm) = $(calib.ϵ)")
    AbstractPlotting.save("$file.png", scene)
end

function plotcalibratedpoi(pois, calib, file)
    poi = Dict(k => v for (k,v) in pois if v isa Singular)
    poic = Dict(k => calibrate(calib.tform, v) for (k, v) in poi)
    scene, layout = layoutscene(0)
    ax = layout[1,1] = LAxis(scene, aspect = DataAspect(), xlabel = "X (cm)", ylabel = "Y (cm)")
    x = first(values(poi))
    img = getimg(x.video, time(x))
    indices = ImageTransformations.autorange(img, calib.tform)
    img = parent(warp(img, calib.itform, indices))
    image!(ax, indices..., img)
    for (p1, p2) in combinations(collect(values(poic)), 2)
        linesegments!(ax, [p1 => p2], color = :white)
        d = norm(p2 - p1)
        text!(ax, string(round(Int, d)), position = p1 + d/2*LinearAlgebra.normalize(p2 - p1), align = (:center, :center), textsize = 12)#, rotation = atan(reverse(p2 - p1)...))
    end
    for (k, v) in poic
        scatter!(ax, v, color = :white, strokecolor = :red, strokewidth = 3)
        text!(ax, k, position = v .- (0, 3), align = (:center, :top), textsize = 12)
    end
    tightlimits!(ax)
    AbstractPlotting.save(joinpath(file, "calibrated POIs.png"), scene)
end

