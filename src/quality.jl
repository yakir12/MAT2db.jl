fliprotate(img) = rotr90(img)[:, end:-1:1]
# tmix=frames=15:weights="1 1 1 1 1 1 1 1 1 1 1 1 1 1 1" 
function getimg(file, t)
    imgraw = FFMPEG.ffmpeg() do exe
        read(`$exe -loglevel 8 -ss $t -i $file -vf yadif=1,scale=sar"*"iw:ih -vframes 1 -f image2pipe -`)
    end
    return fliprotate(ImageMagick.load_(imgraw))
end

function plotrawpoi(poi::POI, file)
    scene, layout = layoutscene(0)
    ax = layout[1,1] = LAxis(scene, aspect = DataAspect(), yreversed = true, xlabel = "X (pixel)", ylabel = "Y (pixel)")
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
    if space(poi) isa Space
        recordit(file, scene)
    else
        recordit(poi, file, ind, scene)
    end
end

recordit(file, scene) = AbstractPlotting.save("$file.png", scene)

function recordit(poi, file, ind, scene)
    fps = 15
    AbstractPlotting.inline!(true)
    record(scene, "$file.mkv", round.(Int, range(1, stop = length(poi.xy), length = 1fps)); framerate = fps) do i
        ind[] = i
    end
    AbstractPlotting.inline!(false)
end

@memoize function plotcalibration(calibration::Calibration, calib, file)
    scene, layout = layoutscene(0)
    ax = layout[1,1] = LAxis(scene, aspect = DataAspect(), yreversed = true, xlabel = "X (pixel)", ylabel = "Y (pixel)", title = "Raw", backgroundcolor = :black)
    img = getimg(calibration.video, calibration.extrinsic)
    image!(ax, img)
    tightlimits!(ax)
    ax = layout[1,2] = LAxis(scene, aspect = DataAspect(), yreversed = true, xlabel = "X (cm)", ylabel = "Y (cm)", title = "Calibrated", backgroundcolor = :black)
    indices, imgw = calibrate(calib, img)
    image!(ax, indices..., imgw)
    tightlimits!(ax)
    layout[2,1:2] = LText(scene, "ϵ (±cm) = $(calib.ϵ)")
    AbstractPlotting.save("$file.png", scene)
end

function _label_position_distances(ps)
    p1, p2 = ps
    Δ = p2 - p1
    d = norm(Δ)
    label = string(round(Int, d))
    pos = p1 + d/2*LinearAlgebra.normalize(Δ)
    return label, pos
end

function _plotpoic(ax, indices, img, poic, expected_locations)
    image!(ax, indices..., img)
    ps = [Pair(p1, p2) for (p1, p2) in combinations(space.(values(poic)), 2)]
    lps = _label_position_distances.(ps)
    textlayer = textlayer!(ax)
    annotations!(textlayer, ax, first.(lps), last.(lps), color = :yellow, align = (:center, :center), textsize = 12)#, rotation = π/6)
    linesegments!(ax, ps, color = :white)
    opts = (marker = '+', color = :red, strokewidth = 0, markersize = 6)
    scatter!(ax, space.(values(poic)); opts..., color = :green)
    labels = collect(keys(poic))
    pos = [Point(space(xy) .- (0, 5)) for xy in values(poic)]
    annotations!(textlayer, ax, labels, pos, color = :yellow, align = (:center, :bottom), textsize = 12)#, rotation = π/6)
    if !isempty(expected_locations)
        scatter!(ax, Point.(values(expected_locations)); opts...)
    end
end

function plotcalibratedpoi(pois, calib, file, expected_locations, calib2)
    scene, layout = layoutscene(0)
    # poic = Dict(k => calibrate(calib, v) for (k,v) in poi)
    x = first(values(pois))
    img = getimg(x.video, time(x))
    indices, imgw = calibrate(calib, img)
    ax1 = layout[1,1] = LAxis(scene, aspect = DataAspect(), yreversed = true, xlabel = "X (cm)", ylabel = "Y (cm)", title = "Calibrated", backgroundcolor = :black)
    _plotpoic(ax1, indices, imgw, pois, expected_locations)
    for v in values(pois)
        map!(calib2, v.xy, v.xy)
    end
    imgw = warp(OffsetArray(imgw, indices...), inv(calib2))
    indices = UnitRange.(axes(imgw))
    imgw = parent(imgw)
    ax2 = layout[1,2] = LAxis(scene, aspect = DataAspect(), yreversed = true, xlabel = "X (cm)", ylabel = "Y (cm)", title = "& corrected", backgroundcolor = :black)
    _plotpoic(ax2, indices, imgw, pois, expected_locations)
    linkaxes!(ax1, ax2)
    mx = minimum(first.(space.(values(pois)))) - 100
    Mx = maximum(first.(space.(values(pois)))) + 100
    my = minimum(last.(space.(values(pois)))) - 100
    My = maximum(last.(space.(values(pois)))) + 100
    limits!(ax1, mx, Mx, My, my)
    hideydecorations!(ax2)
    hidexdecorations!(ax1, ticklabels = false, ticks = false, grid = false)
    hidexdecorations!(ax2, ticklabels = false, ticks = false, grid = false)
    layout[2,1:2] = LText(scene, "X (cm)")
    AbstractPlotting.save(joinpath(file, "calibrated POIs.png"), scene)
end




function textlayer!(ax::LAxis)
    pxa = lift(AbstractPlotting.zero_origin, ax.scene.px_area)
    Scene(ax.scene, pxa, raw = true, camera = campixel!)
end

function AbstractPlotting.annotations!(textlayer::Scene, ax::LAxis, texts, positions; kwargs...)
    positions = positions isa Observable ? positions : Observable(positions)
    screenpositions = lift(positions, ax.scene.camera.projectionview, ax.scene.camera.pixel_space) do positions, pv, pspace
        p4s = to_ndim.(Vec4f0, to_ndim.(Vec3f0, positions, 0.0), 1.0)
        p1m1s = [pv *  p for p in p4s]
        projected = [inv(pspace) * p1m1 for p1m1 in p1m1s]
        pdisplay = [Point2(p[1:2]...) for p in projected]
    end
    annotations!(textlayer, texts, screenpositions; kwargs...)
end

