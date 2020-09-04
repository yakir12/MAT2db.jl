module MAT2db

using FileIO, FilePathsBase

using MATLAB
using MAT, SparseArrays, StaticArrays, Serialization, CSV
using AbstractPlotting, GLMakie, FFMPEG_jll, ImageMagick, FFplay_jll, Colors, PyCall, ImageIO
using AbstractPlotting.MakieLayout
using GLMakie.GLFW
using GLMakie: to_native
using REPL.TerminalMenus
using ContextTracking
using FFMPEG 

const pathtype = String#typeof(Path())
const DATABASE_FILE = "database"
# const POI_NAMES = ["nest", "feeder", "dropoff", "pickup"]
const cv2 = PyNULL()
const csvfile_columns = Dict(:resfile => pathtype, :poi_videofile => pathtype, :poi_names => String, :calib_videofile => pathtype, :extrinsic => Float64, :intrinsic => String, :checker_corners => String, :checker_size => Float64)

function __init__()
    copy!(cv2, pyimport_conda("cv2", "cv2"))
end

if !isfile(DATABASE_FILE)
    serialize(DATABASE_FILE, nothing)
end

include.(("resfiles.jl", "assertions.jl", "calibrations.jl"))

function loadcsv(file)
    @assert isfile(file) "$file does not exist"
    t = CSV.File(file, normalizenames = true, types = csvfile_columns) #dateformat
    @assert length(t) ≠ 0 "csv file has no lines"
    for x in keys(csvfile_columns)
        @assert x ∈ propertynames(t) "column $x is missing from the csv file"
    end
    for x in propertynames(t)
        @assert haskey(csvfile_columns, x) "unkown column, $x, is in the csv file"
    end
    return t
end

function process_csv(csvfile)
    t = loadcsv(csvfile)
    map(t) do row
        create_run(row.resfile,
                   row.poi_videofile,
                   split(row.poi_names, ','),
                   row.calib_videofile,
                   row.extrinsic,
                   tuple(parse.(Float64, split(row.intrinsic, ','))...),
                   tuple(parse.(Int, split(row.checker_corners, ','))...), 
                   row.checker_size)
    end
end

function create_run(resfile, poi_videofile, poi_names, calib_videofile, extrinsic, intrinsic, checker_corners, checker_size)
    a_resfile(resfile)
    a_poi_videofile(poi_videofile)
    coords = resfile2coords(resfile, poi_videofile)
    a_coords(coords)
    a_poi_names(poi_names, length(coords))
    pois = Dict(zip(poi_names, coords))
    calibration = Calibration(calib_videofile, extrinsic, intrinsic, checker_corners, checker_size)
    a_calibration(calibration)
    return (; pois, calibration)
end





end
