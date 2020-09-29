module MAT2db

using FilePathsBase, CoordinateTransformations, ImageTransformations, Memoization, Statistics, Combinatorics, LinearAlgebra, OffsetArrays, StructArrays, StatsBase, Dierckx, AngleBetweenVectors, DataStructures, Missings, ProgressMeter, DataFrames, LabelledArrays, Measurements
using MATLAB
using MAT, SparseArrays, StaticArrays, CSV
using AbstractPlotting, GLMakie, FFMPEG, ImageMagick
using AbstractPlotting.MakieLayout

export process_csv

const pathtype = String#typeof(Path())
const csvfile_columns = Dict(:resfile => pathtype, :poi_videofile => pathtype, :poi_names => String, :calib_videofile => pathtype, :extrinsic => Float64, :intrinsic_start => Float64, :intrinsic_stop => Float64, :checker_size => Float64, :nest2feeder => Float64, :azimuth => Float64, :extra_correction => Bool, :turning_point => Float64)

include.(("resfiles.jl", "assertions.jl", "calibrations.jl", "quality.jl", "pois.jl", "tracks.jl", "common.jl", "plots.jl", "stats.jl"))

function process_csv(csvfile)
    t = loadcsv(csvfile)
    t2 = map(parserow, t)
    ss = check4errors.(t2)
    io = IOBuffer()
    for (i, s) in enumerate(ss)
        if !isempty(s)
            println(io, "\nRun #", i)
            print(io, s)
        end
    end
    msg = String(take!(io))
    !isempty(msg) && error(msg)
    path = joinpath(pwd(), "data")
    mkpath(joinpath(path, "quality", "runs"))
    mkpath(joinpath(path, "quality", "calibrations"))
    mkpath(joinpath(path, "results"))
    p = Progress(length(t2), 1, "Processing runs...")
    tracks = progress_map(enumerate(t2), progress=p) do (i, x)
        process_run(x, path, i)
    end
    df = DataFrame(torow.(tracks))
    df[:, Not(All(:homing, :searching, :track))]  |> CSV.write(joinpath(path, "results", "data.csv"))
end

function loadcsv(file)
    a_csvfile(file)
    t = CSV.File(file, normalizenames = true, types = csvfile_columns)
    a_table(t)
    return t
end

parse_intrinsic(::Missing, ::Missing) = missing
parse_intrinsic(start, stop) = Intrinsic(start, stop)
parserow(row) = merge(NamedTuple(row), parsepois(row.poi_names), (; intrinsic = parse_intrinsic(row.intrinsic_start, row.intrinsic_stop)))

@memoize Dict function process_run(x, path, i)
    runi = string(i)
    mkpath(joinpath(path, "quality", "runs", runi))

    coords = resfile2coords(x.resfile, x.poi_videofile)
    pois = Dict(zip(x.poi_names, coords))
    for (k, v) in pois
        plotrawpoi(v, joinpath(path, "quality", "runs", runi,  String(k)))
    end

    calibration = Calibration(x.calib_videofile, x.extrinsic, x.intrinsic, x.checker_size)
    calib = build_calibration(calibration)
    plotcalibration(calibration, calib, joinpath(path, "quality", "calibrations", string(basename(calibration.video), calibration.extrinsic)))
    calibrate!.(values(pois), Ref(calib))

    expected = adjust_expected(pois, x.expected_locations)
    calib2 = build_extra_calibration(Tuple(only(space(pois[k])) for k in keys(expected)), Tuple(values(expected)))
    plotcalibratedpoi(Dict(k => deepcopy(v) for (k,v) in pois if length(time(v)) == 1), calib, joinpath(path, "quality", "runs", runi), expected, calib2)

    if x.extra_correction
        calibrate!.(values(pois), Ref(calib2))
    end

    flipy!(pois)
    coords = Dict{Symbol, AbstractArray{T,1} where T}(k => k ∈ (:track, :pellet) ? v.xyt : only(space(v)) for (k,v) in pois if !ismissing(v))


    metadata = Dict(:nest2feeder => x.nest2feeder, :azimuth => x.azimuth, :turning_point => x.turning_point)
    if haskey(x.expected_locations, :dropoff)
        metadata[:expected_dropoff] = x.expected_locations[:dropoff]
    end

    z = common(coords, metadata)
    s = Standardized(z)
    scene = plotrun(s)
    AbstractPlotting.save(joinpath(path, "results", "$runi.png"), scene)

    return s

end

function torow(s)
    fs = (:homing, :searching , :center_of_search, :turning_point, :nest, :feeder)
    xs = map(f -> getproperty(s,f), fs)
    return merge(to_namedtuple(s), NamedTuple{fs}(xs), speedstats(s.track))
end

to_namedtuple(x::T) where {T} = NamedTuple{fieldnames(T)}(ntuple(i -> getfield(x, i), Val(nfields(x))))

end

# TODO
# use labeledarrays to build_extra_calibration functions
# break process_run into composable parts so that the file paths and function srguments can be memoized seperately
# clean extra packages in the using and dependencies
# add the resulting table and figures
# clean the plotting
