struct Calibration{T}
    checkers::Tuple{Int, Int}
    video::String
    extrinsic::Float64
    intrinsic::T
end

const Intrinsic = Pair{Float64, Float64}

_format(c::Calibration{Missing}) = string(basename(c.video), ": ", c.extrinsic)
_format(c::Calibration) = string(basename(c.video), ": ", c.extrinsic, ", ", c.intrinsic)

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
    println("How many checkers are there (e.g. `7 8`, `7x8`, `7 by 8`, etc.)?")
    str = readline()
    m = match(r"(\d+)", str)
    if isnothing(m) || length(m.captures) ≠ 2
        @warn "bad format, try again"
        @goto start
    end
    (sort(parse.(Int, m.captures))...)
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

function getgrayimg(file, t)
    imgraw = ffmpeg() do exe
        read(`$exe -loglevel 8 -ss $t -i $file -vf format=gray,yadif=1,tmix=frames=15:weights="1 1 1 1 1 1 1 1 1 1 1 1 1 1 1",scale=sar"*"iw:ih -pix_fmt gray -vframes 1 -f image2pipe -`)
    end
    # return ImageIO.load(imgraw)
    return rotr90(reinterpret(UInt8, green.(ImageMagick.load_(imgraw))))
end

# -vf 'yadif=1    ,,scale=sar*iw:ih
function make_calibration(c::Calibration{Missing})
    img = getgrayimg(c.video, c.extrinsic)
    ret, corners = cv2.findChessboardCorners(img, (31,23))
end

