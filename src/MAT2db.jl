module MAT2db

using FilePathsBase, CoordinateTransformations, ImageTransformations, Memoization, Statistics, Combinatorics, LinearAlgebra
using MATLAB
using MAT, SparseArrays, StaticArrays, CSV
using AbstractPlotting, GLMakie, FFMPEG, ImageMagick
using AbstractPlotting.MakieLayout

export process_csv

const pathtype = String#typeof(Path())
const csvfile_columns = Dict(:resfile => pathtype, :poi_videofile => pathtype, :poi_names => String, :calib_videofile => pathtype, :extrinsic => Float64, :intrinsic_start => Float64, :intrinsic_stop => Float64, :checker_size => Float64, :nest2feeder => Float64, azimuth => Float64)

include.(("resfiles.jl", "assertions.jl", "calibrations.jl", "quality.jl"))

function process_csv(csvfile)
    t = loadcsv(csvfile)
    t2 = map(parserow, t)
    for (i, x) in enumerate(t2)
        check4errors(i, x)
    end
    path = mktempdir(homedir(); prefix="results_", cleanup=false)
    mkpath(joinpath(path, "quality", "runs"))
    mkdir(joinpath(path, "quality", "calibrations"))
    for (i, x) in enumerate(t2)
        process_run(x, path, string(i))
    end
end

function loadcsv(file)
    a_csvfile(file)
    t = CSV.File(file, normalizenames = true, types = csvfile_columns) #dateformat
    a_table(t)
    return t
end

parse_intrinsic(::Missing, ::Missing) = missing
parse_intrinsic(start, stop) = Intrinsic(start, stop)
parserow(row) = merge(NamedTuple(row), (poi_names = split(row.poi_names, ','), intrinsic = parse_intrinsic(row.intrinsic_start, row.intrinsic_stop)))

function check4errors(i, x)
    a_nest2feeder(i, x.nest2feeder, x.azimuth)
    a_resfile(i, x.resfile)
    a_poi_videofile(i, x.poi_videofile)
    coords = resfile2coords(x.resfile, x.poi_videofile)
    a_coords(i, coords, x.resfile)
    a_poi_names(i, x.poi_names, length(coords))
    calibration = Calibration(x.calib_videofile, x.extrinsic, x.intrinsic, x.checker_size)
    a_calibration(i, calibration)
    nothing
end

function process_run(x, path, runi)
    mkdir(joinpath(path, "quality", "runs", runi))
    coords = resfile2coords(x.resfile, x.poi_videofile)
    pois = Dict(zip(x.poi_names, coords))
    for (k, v) in pois
        plotrawpoi(v, joinpath(path, "quality", "runs", runi,  k))
    end
    calibration = Calibration(x.calib_videofile, x.extrinsic, x.intrinsic, x.checker_size)
    calib = build_calibration(calibration)
    plotcalibration(calibration, calib, joinpath(path, "quality", "calibrations", string(basename(calibration.video), calibration.extrinsic)))
    plotcalibratedpoi(pois, calib, joinpath(path, "quality", "runs", runi))
end

end
