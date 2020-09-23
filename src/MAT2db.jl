module MAT2db

using FilePathsBase, CoordinateTransformations, ImageTransformations, Memoization, Statistics, Combinatorics, LinearAlgebra, OffsetArrays
using MATLAB
using MAT, SparseArrays, StaticArrays, CSV
using AbstractPlotting, GLMakie, FFMPEG, ImageMagick
using AbstractPlotting.MakieLayout

export process_csv

const pathtype = String#typeof(Path())
const csvfile_columns = Dict(:resfile => pathtype, :poi_videofile => pathtype, :poi_names => String, :calib_videofile => pathtype, :extrinsic => Float64, :intrinsic_start => Float64, :intrinsic_stop => Float64, :checker_size => Float64, :nest2feeder => Float64, :azimuth => Float64, :extra_correction => Bool)

include.(("resfiles.jl", "assertions.jl", "calibrations.jl", "quality.jl", "pois.jl"))

function process_csv(csvfile)
    t = loadcsv(csvfile)
    t2 = map(parserow, t)
    for (i, x) in enumerate(t2)
        check4errors(i, x)
    end
    @info "found no errors in the data"
    path = joinpath(pwd(), "results")
    # path = mktempdir(pwd(); prefix="results_", cleanup=false)
    mkpath(joinpath(path, "quality", "runs"))
    mkpath(joinpath(path, "quality", "calibrations"))
    for (i, x) in enumerate(t2)
        runi = string(i)
        mkpath(joinpath(path, "quality", "runs", runi))
        process_run(x, path, runi)
        @info "processed run #$i"
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
parserow(row) = merge(NamedTuple(row), parsepois(row.poi_names), (; intrinsic = parse_intrinsic(row.intrinsic_start, row.intrinsic_stop)))

function check4errors(i, x)
    a_nest2feeder(i, x.nest2feeder, x.azimuth)
    a_resfile(i, x.resfile)
    a_poi_videofile(i, x.poi_videofile)
    a_poi_names(i, x.poi_names)
    a_coords(i, x.resfile, length(x.poi_names))
    calibration = Calibration(x.calib_videofile, x.extrinsic, x.intrinsic, x.checker_size)
    a_calibration(i, calibration)
    nothing
end

function process_run(x, path, runi)
    coords = resfile2coords(x.resfile, x.poi_videofile)
    pois = Dict(zip(x.poi_names, coords))
    for (k, v) in pois
        plotrawpoi(v, joinpath(path, "quality", "runs", runi,  k))
    end
    calibration = Calibration(x.calib_videofile, x.extrinsic, x.intrinsic, x.checker_size)
    calib = build_calibration(calibration)
    plotcalibration(calibration, calib, joinpath(path, "quality", "calibrations", string(basename(calibration.video), calibration.extrinsic)))

    calibrate!.(values(pois), Ref(calib))
    y = Dict(k => (v, space(pois[k])) for (k,v) in x.expected_locations)
    expected = adjust_expected(y)
    calib2 = build_extra_calibration(Tuple(space(pois[k]) for k in keys(expected)), Tuple(values(expected)))

    plotcalibratedpoi(Dict(k => deepcopy(v) for (k,v) in pois if space(v) isa Space), calib, joinpath(path, "quality", "runs", runi), expected, calib2)

    if x.extra_correction
        calibrate!.(values(pois), Ref(calib2))
    end
    pois
end

end
