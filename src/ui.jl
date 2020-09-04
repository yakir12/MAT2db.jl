
function play(videofile) 
    err = Pipe()
    p = ffplay() do exe
        run(pipeline(`$exe -hide_banner $videofile`, stderr = err))
    end
    wait(p)
    close(err.in)
    ls = last(readlines(err))
    for l in reverse(split(ls, '\r'))
        m = match(r"(\d+\.\d+)\s+A-V", l)
        if !isnothing(m)
            return parse(Float64, only(m.captures))
        end
    end
end

function get_calibration(calibrations, videofiles)
    if isempty(calibrations)
        return addcalibration!()
    else
        options = _format.(calibrations)
        push!(options, "new calibration")
        menu = RadioMenu(options)
        choice = request("Which calibration calibrates these POIs?", menu)
        if choice == length(options)
            return addcalibration!(calibrations)
        else
            return calibrations[choice]
        end
    end
end

# get_duration(videofile) = ffprobe() do exe
#     parse(Float64, read(`$exe -i $videofile -show_entries format=duration -v quiet -of csv="p=0"`, String))
# end


function get_extrinsic(videofile)
    println("Navigate until the board is flat and visible, then close the video-player")
    play(videofile)
end

function get_intrinsic(videofile)
    @label start
    println("Navigate until the user starts moving the board, then close the video-player")
    t1 = play(videofile)
    println("Navigate until the user stops moving the board, then close the video-player")
    t2 = play(videofile)
    return Intrinsic(t1, t2)
end

badintrinsic(::Missing) = false
function badintrinsic(intrinsic::Intrinsic) 
    if !issorted(intrinsic) 
        @warn "the starting time cannot come after the ending time" 
        return true
    end
    return false
end

function badcheckers(x) 
    if any(<(2), x)
        @warn "the number of checkers must be larger than 1" 
        return true
    end
    return false
end

function get_checkers()
    @label start
    println("how many checkers are there (e.g. `7 8`, `7x8`, `7 by 8`, etc.)?")
    str = readline()
    m = match(r"^(\d+)[^\d]+(\d+)$", str)
    if isnothing(m)
        @warn "bad format, try again"
        @goto start
    end
    tuple(sort(parse.(Int, m.captures))...)
end

function addcalibration!(videofiles)
    calib_videofile = get_videofile(videofiles, "Which video file is the calibration in?")
    checkers = get_checkers()
    options = ["Only extrinsic", "Intrinsic and extrinsic"]
    menu = RadioMenu(options)
    choice = request("Which calibration type is it?", menu)
    if choice == 1
        extrinsic = get_extrinsic(videofile)
        intrinsic = missing
    else
        @label start
        extrinsic = get_extrinsic(videofile)
        intrinsic = get_intrinsic(videofile)
    end
    badintrinsic(intrinsic) && @goto start
    Calibration(calib_videofile, extrinsic, intrinsic)
end


function get_videofile(videofiles, msg)
    if isempty(videofiles)
        newvideo() else
        push!(videofiles, "new file")
        menu = RadioMenu(videofiles)
        choice = request(msg, menu)
        if choice == length(videofiles)
            newvideo()
        else
            videofiles[choice]
        end
    end
end

function badvideofile(fullpath) 
    path, file = splitdir(fullpath)
    if file[1] == '.'
        @warn "file is hidden"
        return true
    end
    if !isfile(fullpath)
        @warn "file does not exist"
        return true
    end
    name, ext = splitext(file)
    if !any(x -> occursin(Regex(x, "i"), ext), ("mp4", "avi", "mts", "mov"))
        @warn "unidentified video format"
        return true
    end
    return false
end

function newvideo()
    @label start
    println("What is the file-path to the new video?")
    videofile = readline()
    badvideofile(videofile) && @goto start
    videofile
end




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

function get_videofiles!(videofiles, pois)
    for v in values(pois)
        push!(videofiles, v.video)
    end
    return videofiles
end
function get_videofiles(runs)
    videofiles = Set{String}()
    for (pois, c) in runs
        get_videofiles!(videofiles, pois)
        push!(videofiles, c.video)
    end
    return videofiles
end

function ui_run(videofiles, calibrations)
    resfile = get_resfile()
    poi_videofile = get_videofile(videofiles, "Which video file are the POIs in?")
    push!(videofiles, poi_videofile)
    coords = resfile2coords(resfile, poi_videofile)
    poi_names = get_poi_names(coords)
    pois = Dict(zip(poi_names, coords))
    calibration = get_calibration(calibrations, videofiles)
    return (; pois, calibration)
end

function add_run!(runs)
    videofiles = get_videofiles(runs)
    calibrations = getfield.(runs, :calib)
    r = ui_run(videofiles, calibrations)
    push!(runs, r)
end

function add_run()
    runs = deserialize(DATABASE_FILE)
    add_run!(runs)
    serialize(DATABASE_FILE, runs)
end

function add_run(resfile, poi_videofile, poi_names, calib_videofile, extrinsic, intrinsic1, intrinsic2)
    r = create_run(resfile, poi_videofile, poi_names, calib_videofile, extrinsic, intrinsic1, intrinsic2)
    runs = deserialize(DATABASE_FILE)
    push!(runs, r)
    serialize(DATABASE_FILE, runs)
end
