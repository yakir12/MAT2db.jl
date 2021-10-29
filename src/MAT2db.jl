module MAT2db

using FilePathsBase, CoordinateTransformations, ImageTransformations, Memoization, Statistics, Combinatorics, LinearAlgebra, OffsetArrays, StructArrays, StatsBase, Dierckx, AngleBetweenVectors, DataStructures, Missings, ProgressMeter, DataFrames, LabelledArrays, Measurements, ImageCore, Interpolations, Tar, OnlineStats
using MATLAB, FileIO
using MAT, SparseArrays, StaticArrays, CSV
using GLMakie, FFMPEG, ImageMagick
import GLMakie.@colorant_str
using OnlineStats
using ThreadsX

using CameraCalibrations

using IterTools, UnPack, Arrow


export process_csv, process_run, process_run_of_tracks, plotruns, save2db

const pathtype = typeof(Path())
const csvfile_columns = Dict(:resfile => pathtype, :poi_videofile => pathtype, :poi_names => String, :calib_videofile => pathtype, :extrinsic => Float64, :intrinsic_start => Float64, :intrinsic_stop => Float64, :checker_size => Float64, :nest2feeder => Float64, :azimuth => Float64, :extra_correction => Bool, :turning_point => Float64)

include.(("resfiles.jl", "assertions.jl", "calibrations.jl", "quality.jl", "pois.jl", "tracks.jl", "common.jl", "plots.jl", "stats.jl", "debug.jl"))

a_computer_vision_toolbox()

function process_csv(csvfile; debug = false, fun = process_run, delim = nothing)
  t = loadcsv(csvfile, delim)
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
  tracks = ThreadsX.map(enumerate(t2)) do (i, x)
    ProgressMeter.next!(p; showvalues = [(:run_number, i), (:csv_row, i + 1)])
    # println(string(i))
    if debug
      Memoization.empty_all_caches!();
      try 
        fun(x, path, i)
      catch ex
        debugging(t[i], ex)
      end
    else
      fun(x, path, i)
    end
  end
  df = DataFrame(torow.(tracks))
  df[:, Not(Cols(:homing, :searching, :track))]  |> CSV.write(joinpath(path, "results", "data.csv"))
  return tracks
end

function loadcsv(file, delim)
  a_csvfile(file)
  t = CSV.File(file, normalizenames = true, types = csvfile_columns, delim = delim)
  a_table(t)
  return t
end

parse_intrinsic(::Missing, ::Missing) = missing
parse_intrinsic(start, stop) = Intrinsic(start, stop)
parserow(row) = merge(NamedTuple(row), parsepois(row.poi_names), (; intrinsic = parse_intrinsic(row.intrinsic_start, row.intrinsic_stop)))

@memoize Dict function process_run(x, path, i)
  runi = FilePathsBase.filename(x.resfile)#string(i)
  mkpath(joinpath(path, "quality", "runs", runi))

  pois = resfile2coords(x.resfile, x.poi_videofile, x.poi_names)
  for (k, v) in pois
    plotrawpoi(v, joinpath(path, "quality", "runs", runi,  String(k)))
  end

  calibration = Calibration(x.calib_videofile, x.extrinsic, x.intrinsic, x.checker_size)
  calib = build_calibration(calibration)
  plotcalibration(calibration, calib, joinpath(path, "quality", "calibrations", string(basename(calibration.video), calibration.extrinsic)))
  calibrate!.(values(pois), Ref(calib))

  expected = adjust_expected(pois, x.expected_locations)
  calib2 = build_extra_calibration([only(space(pois[k])) for k in keys(expected)], deepcopy(collect(values(expected))))
  calib_poi2plot = Dict(k => deepcopy(v) for (k,v) in pois if length(time(v)) == 1)
  plotcalibratedpoi(calib_poi2plot, calib, joinpath(path, "quality", "runs", runi), expected, calib2)

  if x.extra_correction
    calibrate!.(values(pois), Ref(calib2))
  end

  flipy!(pois)
  coords = Dict{Symbol, AbstractArray{T,1} where T}(k => k ∈ (:track, :pellet) ? v.xyt : only(space(v)) for (k,v) in pois if !ismissing(v))


  metadata = Dict{Symbol, Any}(:nest2feeder => x.nest2feeder, :azimuth => x.azimuth, :turning_point => x.turning_point, :runid => FilePathsBase.filename(x.resfile))
  if haskey(x.expected_locations, :dropoff)
    metadata[:expected_dropoff] = x.expected_locations[:dropoff]
  end

  z = common(coords, metadata)
  s = Standardized(z)
  scene = plotrun(s)
  save(joinpath(path, "results", "$runi.png"), scene)

  scene = plotturningpoint(s)
  save(joinpath(path, "results", "TP$runi.png"), scene)

  return s

end

function torow(s::Standardized)
  fs = (:homing, :searching , :center_of_search, :turning_point, :nest, :feeder)
  xs = map(f -> getproperty(s,f), fs)
  return merge(to_namedtuple(s), NamedTuple{fs}(xs), speedstats(s.track), directionstats(s.track, s.dropoff), dropoff2tp(s.track, s.dropoff), discretedirection(s.track, s.dropoff), tp_discretedirection(s.track), path_length(s))
end

torow(s::Dict) = (; (f => missing for f in (:homing, :searching , :center_of_search, :turning_point, :nest, :feeder))..., track = missing)

to_namedtuple(x::T) where {T} = NamedTuple{fieldnames(T)}(ntuple(i -> getfield(x, i), Val(nfields(x))))


@memoize Dict function process_run_of_tracks(x, path, i)
  runi = string(i)
  mkpath(joinpath(path, "quality", "runs", runi))

  pois = resfile2coords(x.resfile, x.poi_videofile, x.poi_names)
  for (k, v) in pois
    plotrawpoi(v, joinpath(path, "quality", "runs", runi,  String(k)))
  end

  calibration = Calibration(x.calib_videofile, x.extrinsic, x.intrinsic, x.checker_size)
  calib = build_calibration(calibration)
  plotcalibration(calibration, calib, joinpath(path, "quality", "calibrations", string(basename(calibration.video), calibration.extrinsic)))
  calibrate!.(values(pois), Ref(calib))

  flipy!(pois)

  scene = plotrun_of_tracks(pois)
  save(joinpath(path, "results", "$runi.png"), scene)

  return pois

end

function save2db(xs, factors_file; filename = "db.arrow")
  factors = CSV.File(factors_file) |> DataFrame
  @assert nrow(factors) == length(xs) "number of runs in the factors file must be equal to the number of tracks"
  df = DataFrame(nest = Vector[], feeder = Vector[], dropoff = Vector[], fictive_nest = Vector[], nest2feeder = Float64[], pellets = Vector{Vector}[], pickup = Vector[], runid = String[], coords = Vector{Vector}[], t = StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}}[], tp = Int[], rawcoords = [])
  allowmissing!(df, [:nest, :pellets, :pickup])
  for x in xs
    @unpack nest, dropoff, fictive_nest, nest2feeder, pellets, pickup, runid, track = x
    @unpack coords, t, tp, rawcoords = track
    push!(df, (; nest, x.feeder, dropoff, fictive_nest, nest2feeder, pellets, pickup, runid, coords, t, tp, rawcoords))
  end
  Arrow.write(filename, hcat(factors, df, makeunique=true))
end

end

# TODO
# break process_run into composable parts so that the file paths and function srguments can be memoized seperately
# clean extra packages in the using and dependencies
# add the resulting table and figures
# clean the plotting
# clean the stats
