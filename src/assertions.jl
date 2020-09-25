a_csvfile(file) = @assert isfile(file) "csv file, $file, does not exist"
function a_table(t)
    @assert length(t) ≠ 0 "csv file has no lines"
    for x in keys(csvfile_columns)
        @assert x ∈ propertynames(t) "column $x is missing from the csv file"
    end
    for x in propertynames(t)
        @assert haskey(csvfile_columns, x) "unkown column, $x, is in the csv file"
    end
end

a_resfile(i, resfile) = @assert isfile(resfile) "res file in run #$i does not exist"

function a_poi_videofile(i, poi_videofile)
    @assert isfile(poi_videofile) "POI video file in run #$i does not exist"
    @assert lowercase.(extension(Path(poi_videofile))) ∈ ("mp4", "avi", "mts", "mov") "unidentified video format for POI video file in run #$i"
end

function a_coords(i, resfile, npois)
    matopen(resfile) do io
        for field in ("xdata", "ydata", "status")
            @assert MAT.exists(io, field) "resfile missing $field"
        end
        @assert haskey(read(io, "status"), "FrameRate") "resfile missing frame rate"
        xdata = read(io, "xdata")
        n = size(xdata, 2)
        npoints = [length(nzrange(xdata, j)) for j in 1:n]
        nmax = maximum(npoints)
        @assert nmax > 5 "res file in run #$i missing a POI with more than 5 data points (e.g. a track)"
        n = count(!iszero, npoints)
        @assert n ≠ 0 "res file is empty"
        @assert npois == n "number of POIs, $npois, doesn't match the number of res columns, $n, in run #$i"
    end
end

function a_poi_names(i, poi_names)
    @assert all(x -> !occursin(' ', String(x)), poi_names) "POI name/s contains space/s in run #$i"
    @assert allunique(poi_names) "POI names must be unique in run #$i"
    @assert :track ∈ poi_names "a track POI is missing in run #$i"
end

function a_calibration(i, c)
    @assert isfile(c.video) "calibration video file in run #$i does not exist"
    duration = get_duration(c.video)
    @assert 0 ≤ c.extrinsic ≤ duration "extrinsic time stamp in run #$i is not in the video"
    @assert c.checker_size > 0 "checkers must be larger than zero in run #$i"
    a_intrinsic(i, c.intrinsic, duration)
end
function get_duration(file)
    p = FFMPEG.exe(`-i $file -show_entries format=duration -v quiet -of csv="p=0"`, command=FFMPEG.ffprobe, collect=true)
    parse(Float64, only(p))
end
function a_intrinsic(i, intrinsic, duration)
    @assert all(x -> 0 ≤ x ≤ duration, intrinsic) "intrinsic time stamp in run #$i is not in the video"
    @assert issorted(intrinsic) "the intrinsic starting time in run #$i cannot come after the ending time" 
end
a_intrinsic(i, ::Missing, _) = nothing

function a_nest2feeder(i, nest2feeder, azimuth, expected_locations) 
    _a_nest2feeder1(i, nest2feeder, expected_locations)
    _a_nest2feeder2(i, nest2feeder, azimuth)
end

function _a_nest2feeder1(i, nest2feeder, expected_locations)
    expected_nest2feeder = _get_expected_nest2feeder(expected_locations)
    a_expected_nest2feeder(i, expected_nest2feeder, nest2feeder)
end

__getfeeder(x) = get(x, :initialfeeder, get(x, :pickup, get(x, :feeder, missing)))
_get_expected_nest2feeder(x) = _get_expected_nest2feeder(get(x, :nest, missing), __getfeeder(x))
_get_expected_nest2feeder(nest, feeder) = norm(nest - feeder)
_get_expected_nest2feeder(::Missing, feeder) = missing
_get_expected_nest2feeder(nest, ::Missing) = missing
_get_expected_nest2feeder(::Missing, ::Missing) = missing

a_expected_nest2feeder(i, expected_nest2feeder::Float64, ::Missing) = throw(AssertionError("nest2feeder is missing, even though the expected distance should be $expected_nest2feeder in run #$i"))
a_expected_nest2feeder(i, ::Missing, _) = nothing
a_expected_nest2feeder(i, expected_nest2feeder, nest2feeder) = @assert expected_nest2feeder ≈ nest2feeder "nest2feeder, $nest2feeder, is not equal to the distance between the expected nest and feederlocations, $expected_nest2feeder, in run #$i"

function _a_nest2feeder2(i, nest2feeder::Float64, azimuth::Float64)
    @assert nest2feeder > 0 "nest to feeder distance must be larger than zero in run #$i"
    @assert 0 < azimuth < 360 "azimuth must be between 0° and 360° in run #$i"
end
_a_nest2feeder2(_, x, ::Missing) = nothing
_a_nest2feeder2(i, ::Missing, ::Float64) = throw(AssertionError("nest to feeder distance is missing in run #$i"))

a_turning_point(i, _, ::Missing) = nothing
function a_turning_point(i, poi_videofile, t)
    duration = get_duration(poi_videofile)
    @assert 0 ≤ t ≤ duration "turning point time stamp in run #$i is not in the video"
end
