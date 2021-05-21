unfliprotate(img) = rotl90(img[:, end:-1:1])
fliprotate(img) = rotr90(img)[:, end:-1:1]
# tmix=frames=15:weights="1 1 1 1 1 1 1 1 1 1 1 1 1 1 1" 
function getimg(file, t)
    imgraw = FFMPEG.ffmpeg() do exe
        read(`$exe -loglevel 8 -ss $t -i $file -vf yadif=1,scale=sar"*"iw:ih -vframes 1 -f image2pipe -`)
    end
    return fliprotate(ImageMagick.load_(imgraw))
end

function plotrawpoi(poi::POI, file)
    ind = Node(1)
    img = lift(ind) do i
        getimg(poi.video, time(poi, i))
    end
    timestamp = lift(ind) do i
        string("time stamp: ", round(time(poi)[i], digits = 3), " sec")
    end
    spot = lift(ind) do i
        space(poi, i)
    end
    fig = Figure()
    ax = fig[1, 1] = Axis(fig, aspect = DataAspect(), yreversed = true, xlabel = "X (pixel)", ylabel = "Y (pixel)", title = timestamp)
    # scene, layout = layoutscene(0)
    # ax = layout[1,1] = LAxis(scene, aspect = DataAspect(), yreversed = true, xlabel = "X (pixel)", ylabel = "Y (pixel)", title = timestamp)
    image!(ax, img)
    # layout[0, :] = LText(scene, timestamp)
    scatter!(ax, spot, color = :transparent, strokecolor = :red, strokewidth = 3)
    tightlimits!(ax)
    if length(time(poi)) == 1
        recordit(file, fig)
    else
        recordit(poi, file, ind, fig)
        # recordmovie(poi, file, ind, scene)
    end
end

recordit(file, scene) = save("$file.png", scene)

function recordit(poi, file, ind, scene)
    for (j,i) in enumerate(round.(Int, range(1, stop = length(time(poi)) - 1, length = 5)))
        ind[] = i
        save("$file$j.png", scene)
    end
end

function recordmovie(poi, file, ind, scene)
    GLMakie.Makie.inline!(true)
    record(scene, "$file.mp4", eachindex(time(poi))) do i
        ind[] = i
    end
    GLMakie.Makie.inline!(false)
end

decompose(imgw) = (UnitRange.(axes(imgw)), parent(imgw))
function plotcalibration(calibration::Calibration, calib, file)
    fig = Figure()
    ax = fig[1, 1] = Axis(fig, aspect = DataAspect(), yreversed = true, xlabel = "X (pixel)", ylabel = "Y (pixel)", title = "Raw", backgroundcolor = :black)
    # scene, layout = layoutscene(0)
    # ax = layout[1,1] = LAxis(scene, aspect = DataAspect(), yreversed = true, xlabel = "X (pixel)", ylabel = "Y (pixel)", title = "Raw", backgroundcolor = :black)
    img = getimg(calibration.video, calibration.extrinsic)
    image!(ax, img)
    tightlimits!(ax)
    ax = fig[1, 2] = Axis(fig, aspect = DataAspect(), yreversed = true, xlabel = "X (cm)", ylabel = "Y (cm)", title = "Calibrated", backgroundcolor = :black)
    # ax = layout[1,2] = LAxis(scene, aspect = DataAspect(), yreversed = true, xlabel = "X (cm)", ylabel = "Y (cm)", title = "Calibrated", backgroundcolor = :black)
    indices, imgw = decompose(calibrate(calib, img))
    image!(ax, indices..., imgw)
    tightlimits!(ax)
    fig[2,1:2] = Label(fig, "ϵ (± pixel) = $(round.(calib.ϵ, digits = 2))")
    save("$file.png", fig)
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
    ps = [Pair(only(p1), only(p2)) for (p1, p2) in combinations(space.(values(poic)), 2)]
    lps = _label_position_distances.(ps)
    # textlayer = textlayer!(ax)
    annotations(first.(lps), Point2f0.(last.(lps)), color = :yellow, align = (:center, :center), textsize = 12)#, rotation = π/6)
    linesegments!(ax, ps, color = :white)
    opts = (marker = '+', color = :red, strokewidth = 0, markersize = 6)
    scatter!(ax, only.(space.(values(poic))); opts..., color = :green)
    labels = String.(keys(poic))
    pos = [Point(only(space(xy)) .- (0, 5)) for xy in values(poic)]
    annotations!(labels, pos, color = :yellow, align = (:center, :bottom), textsize = 12)#, rotation = π/6)
    if !isempty(expected_locations)
        scatter!(ax, Point.(values(expected_locations)); opts...)
    end
end

function plotcalibratedpoi(pois, calib, file, expected_locations, calib2)
    fig = Figure()
    # scene, layout = layoutscene(0)
    # poic = Dict(k => calibrate(calib, v) for (k,v) in poi)
    x = first(values(pois))
    img = getimg(x.video, time(x))
    imgww = calibrate(calib, img)
    indices, imgw = decompose(imgww)
    ax1 = fig[1, 1] = Axis(fig, aspect = DataAspect(), yreversed = true, xlabel = "X (cm)", ylabel = "Y (cm)", title = "Calibrated", backgroundcolor = :black)
    # ax1 = layout[1,1] = LAxis(scene, aspect = DataAspect(), yreversed = true, xlabel = "X (cm)", ylabel = "Y (cm)", title = "Calibrated", backgroundcolor = :black)
    _plotpoic(ax1, indices, imgw, pois, expected_locations)
    for v in values(pois)
        # map!(calib2, space(v), space(v))
        calibrate!(v, calib2)# = map!(xy -> calibrate(c, xy), space(poi), space(poi))
    end
    # imgw = warp(OffsetArray(imgw, indices...), inv(calib2))
    # imgw = warp(imgw, inv(calib2), indices)
    # indices = parent.(axes(imgw))
    # imgw = parent(imgw)
    #
    # @show calib2.tform
    # @show typeof(calib2.tform)
    # @show typeof(imgww)
    # @show axes(imgww)
    # @show calib2.itform
    # @show typeof(calib2.itform)
    indices, imgw = decompose(calibrate(calib2, imgww))
    ax2 = fig[1, 2] = Axis(fig, aspect = DataAspect(), yreversed = true, xlabel = "X (cm)", ylabel = "Y (cm)", title = "& corrected", backgroundcolor = :black)
    # ax2 = layout[1,2] = LAxis(scene, aspect = DataAspect(), yreversed = true, xlabel = "X (cm)", ylabel = "Y (cm)", title = "& corrected", backgroundcolor = :black)
    _plotpoic(ax2, indices, imgw, pois, expected_locations)
    linkaxes!(ax1, ax2)
    mx = minimum(first.(only.(space.(values(pois))))) - 100
    Mx = maximum(first.(only.(space.(values(pois))))) + 100
    my = minimum(last.(only.(space.(values(pois))))) - 100
    My = maximum(last.(only.(space.(values(pois))))) + 100
    limits!(ax1, mx, Mx, My, my)
    hideydecorations!(ax2)
    hidexdecorations!(ax1, ticklabels = false, ticks = false, grid = false)
    hidexdecorations!(ax2, ticklabels = false, ticks = false, grid = false)
    fig[2,1:2] = Label(fig, "X (cm)")
    save(joinpath(file, "calibrated POIs.png"), fig)
end




# function textlayer!(ax::Axis)
#     pxa = lift(AbstractPlotting.zero_origin, ax.scene.px_area)
#     Scene(ax.scene, pxa, raw = true, camera = campixel!)
# end
#
# function AbstractPlotting.annotations!(textlayer::Figure, ax::Axis, texts, positions; kwargs...)
#     positions = positions isa Observable ? positions : Observable(positions)
#     screenpositions = lift(positions, ax.scene.camera.projectionview, ax.scene.camera.pixel_space) do positions, pv, pspace
#         p4s = to_ndim.(Vec4f0, to_ndim.(Vec3f0, positions, 0.0), 1.0)
#         p1m1s = [pv *  p for p in p4s]
#         projected = [inv(pspace) * p1m1 for p1m1 in p1m1s]
#         pdisplay = [Point2(p[1:2]...) for p in projected]
#     end
#     annotations!(textlayer, texts, screenpositions; kwargs...)
# end

