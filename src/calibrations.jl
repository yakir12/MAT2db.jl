struct Calibration{T}
    videofile::String
    extrinsic::Float64
    intrinsic::T
end

_format(c::Calibration{Missing}) = string(basename(c.videofile), ": ", c.extrinsic)
_format(c::Calibration) = string(basename(c.videofile), ": ", c.extrinsic, ", ", c.intrinsic)

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

function get_calibration()
    calibrations = deserialize(CALIBRATONS_FILE)
    if isempty(calibrations)
        addcalibration!(calibrations)
    else
        options = _format.(calibrations)
        push!(options, "new calibration")
        menu = RadioMenu(options)
        choice = request("Which calibration calibrates these POIs?", menu)
        if choice == length(options)
            addcalibration!(calibrations)
        else
            options[choice]
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
    if t1 ≥ t2
        @warn "the starting time cannot come after the ending time"
        @goto start
    end
    return t1 => t2
end

function addcalibration!(calibrations)
    @label start
    println("What is the file-path to the new claibration-video?")
    videofile = readline()
    badvideofile(videofile) && @goto start
    options = ["Only extrinsic", "Intrinsic and extrinsic"]
    menu = RadioMenu(options)
    choice = request("Which calibration type is it?", menu)
    if choice == 1
        extrinsic = get_extrinsic(videofile)
        intrinsic = missing
    else
        extrinsic = get_extrinsic(videofile)
        intrinsic = get_intrinsic(videofile)
    end
    c = Calibration(videofile, extrinsic, intrinsic)
    push!(calibrations, c)
    serialize(CALIBRATONS_FILE, calibrations)
    c
end

