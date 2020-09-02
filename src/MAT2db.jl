module MAT2db

using FileIO

using MAT, SparseArrays, StaticArrays, Serialization
using AbstractPlotting, GLMakie, FFMPEG_jll, ImageMagick, FFplay_jll, Colors, PyCall, ImageIO
using AbstractPlotting.MakieLayout
using GLMakie.GLFW
using GLMakie: to_native
using REPL.TerminalMenus
using ContextTracking

const DATABASE_FILE = "database"
const POI_NAMES = ["nest", "feeder", "dropoff", "pickup"]
const cv2 = pyimport("cv2")

if !isfile(DATABASE_FILE)
    serialize(DATABASE_FILE, nothing)
end

include.(("resfile.jl", "choosePOIs.jl", "video.jl", "calibrations.jl"))

const EX = ErrorException("can't process these files");

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

function create_run(resfile, poi_videofile, poi_names, calib_videofile, extrinsic, intrinsic1, intrinsic2)
    badresfile(resfile) && throw(EX)
    coords = resfile2coords(resfile)
    badcoords(coords) && throw(EX)
    badvideofile(poi_videofile) && throw(EX)
    badpoi_names(poi_names, coords) && throw(EX)
    calibration = Calibration(calib_videofile, extrinsic, intrinsic1 => intrinsic2)
    badintrinsic(calibration) && throw(EX)
    mat = calibration2mat(calibration)
    badmat(mat) && throw(EX)
    return (; pois, calibration)
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

end
