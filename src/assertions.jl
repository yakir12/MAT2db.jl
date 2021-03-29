function a_computer_vision_toolbox() 
    mat"""$i = license('test','Video_and_Image_Blockset')"""
    @assert i == 1 "the Matlab Computer Vision System Toolbox is not available"
end
a_csvfile(file) = @assert isfile(file) "missing csv file"
function a_table(t)
    @assert length(t) ≠ 0 "csv file has no lines"
    for x in keys(csvfile_columns)
        @assert x ∈ propertynames(t) "missing column $x from csv file"
    end
    for x in propertynames(t)
        @assert haskey(csvfile_columns, x) "unkown column, $x, in csv file"
    end
end

c_resfile(io, ::Missing) = (println(io, "- res file missing in csv file"); return missing)
function c_resfile(io, resfile)
    if isfile(resfile) 
        resfile
    else
        println(io, "- res file does not exist")
        missing
    end
end

c_poi_names(io, ::Missing) = (println(io, "- POI names missing in csv file"); return missing)
function c_poi_names(io, poi_names)
    good = true
    if !all(x -> !occursin(' ', String(x)), poi_names) 
        println(io, "- POI name/s contains space/s")
        good = false
    end
    if !allunique(poi_names) 
        println(io, "- POI names must be unique")
        good = false
    end
    if all(!occursin("track", String(name)) for name in poi_names)
        println(io, "- a track POI is missing")
        good = false
    end
    good ? poi_names : missing
end

c_expected_locations(io, ::Missing) = nothing
function c_expected_locations(io, expected_locations)
    if !allunique(values(expected_locations))
        println(io, "- at least two of the POI's expected locations are identical")
        return missing
    end
    expected_locations
end

a_expected_locations(io, ::Missing, poi_names, npoints) = nothing
function a_expected_locations(io, expected_locations, poi_names, npoints)
    for (k, v) in expected_locations
        i = findfirst(==(k), poi_names)
        n = npoints[i]
        n == 1 || println(io, "- you expected $k to be at $v, yet there are $n lines in its column (column #$i) in the res-file (instead of just one)")
    end
end

a_singular_pois(io, poi_names, npoints) = map(poi_names, npoints) do name, n
    if n ≠ 1 && name ∈ (:feeder, :pickup, :dropoff, :nest, :north, :south)
        println(io, "- $name is expected to have exactly one row (point) in its res file, yet it has $n rows")
    end
end

a_coords(io, x, y, d, e) = nothing
function a_coords(io, resfile::SystemPath, poi_names::Vector{Symbol}, duration::Float64, expected_locations)
    matopen(string(resfile)) do mio
        for field in ("xdata", "ydata", "status")
            if !MAT.exists(mio, field) 
                println(io, "- resfile missing $field")
                return nothing
            end
        end
        haskey(read(mio, "status"), "FrameRate") || println(io,  "- resfile missing frame rate")
        xdata = read(mio, "xdata")
        n = size(xdata, 2)
        npoints = [length(nzrange(xdata, j)) for j in 1:n]
        a_expected_locations(io, expected_locations, poi_names, npoints)
        a_singular_pois(io, poi_names, npoints)
        !all(iszero, npoints) || println(io, "- res file is empty")
        nmax = maximum(npoints)
        nmax > 5 || println(io, "- res file missing a POI with more than 5 data points (e.g. a track)")
        npois = length(poi_names)
        npois == n || println(io, "- number of POIs, $npois, doesn't match the number of res columns, $n")
        rows = rowvals(xdata)
        fr = read(mio, "status")["FrameRate"]
        haskey(read(mio, "status"), "nFrames") || println(io,  "- resfile missing number of total frames")
        nf = read(mio, "status")["nFrames"]
        duration2 = nf/fr
        isapprox(duration2, duration, atol = 1) || println(io, "- the duration of the POI video file, $duration s, and the one reported in the res file, $duration2 s, are not the same")
        if npois > n
            println(io, "- there are more POIs ($npois) than there are columns in the res file ($n)")
            return nothing
        end
        for (j, name) in enumerate(poi_names)
            i = nzrange(xdata, j)
            if !isempty(i)
                t = rows[i[end]]/fr
                t ≤ duration || println(io, "- the time-stamp of the $name POI is not in the video")
            end
        end
    end
end

c_videofile(io, ::Missing, what) = (println(io, "- ", what, " video file missing in csv file"); return missing) 
function c_videofile(io, videofile, what)
    if !isfile(videofile) 
        println(io, "- ", what, " video file does not exist")
        return missing
    else
        return videofile
    end
end

a_turning_point(io, x, y, d) = nothing
function a_turning_point(io, poi_videofile::AbstractString, t::Float64, duration::Float64)
    0 ≤ t ≤ duration || println(io, "- turning point time-stamp is not in the video")
end

a_checker_size(io, ::Missing) = println(io, "- checker-size is missing in the csv file")
a_checker_size(io, checker_size) = checker_size > 0 || println(io, "- checkers must be larger than zero")

a_extrinsic(io, ::Missing, duration) = println(io, "- extrinsic time-stamp is missing in the csv file")
a_extrinsic(io, extrinsic, duration) = 0 ≤ extrinsic ≤ duration || println(io, "- extrinsic time-stamp is not in the video")

function a_intrinsic(io, intrinsic, duration)
    all(x -> 0 ≤ x ≤ duration, intrinsic) || println(io, "- intrinsic time-stamp is not in the video")
    issorted(intrinsic) || println(io, "- the intrinsic starting time cannot come after the ending time")
end
a_intrinsic(io, ::Missing, _) = nothing

a_calibration(io, ::Missing, extrinsic, intrinsic, checker_size) = nothing
function a_calibration(io, calib_videofile, extrinsic, intrinsic, checker_size)
    a_checker_size(io, checker_size)
    duration = get_duration(calib_videofile)
    a_extrinsic(io, extrinsic, duration)
    a_intrinsic(io, intrinsic, duration)
end

c_nest2feeder(io, ::Missing) = missing
function c_nest2feeder(io, nest2feeder) 
    if nest2feeder < 0 
        println(io, "- nest to feeder distance must be larger than zero")
        return missing
    else
        return nest2feeder
    end
end
a_azimuth(io, ::Missing) = nothing
a_azimuth(io, azimuth) = 0 < azimuth < 360 || println(io, "- azimuth must be between 0° and 360°")

__getfeeder(x) = get(x, :initialfeeder, get(x, :pickup, get(x, :feeder, missing)))
_get_expected_nest2feeder(::Missing) = missing
_get_expected_nest2feeder(x) = _get_expected_nest2feeder(get(x, :nest, missing), __getfeeder(x))
_get_expected_nest2feeder(nest, feeder) = norm(nest - feeder)
_get_expected_nest2feeder(::Missing, feeder) = missing
_get_expected_nest2feeder(nest, ::Missing) = missing
_get_expected_nest2feeder(::Missing, ::Missing) = missing
a_expected_nest2feeder(io, ::Missing, nest2feeder::Missing) = nothing
a_expected_nest2feeder(io, ::Real, nest2feeder::Missing) = println(io, "- it seems like you have expectations on the distance between the nest and feeder, but nest2feeder is missing")
a_expected_nest2feeder(io, ::Missing, nest2feeder::Real) = nothing#println(io, "- it seems like you should have expectations on the distance between the nest and feeder since nest2feeder is not missing")
a_expected_nest2feeder(io, expected_nest2feeder::Real, nest2feeder::Real) = expected_nest2feeder ≈ nest2feeder || println(io, "- nest2feeder, $nest2feeder, is not equal to the distance between the expected nest and feeder locations, $expected_nest2feeder")

a_extra_correction(io, ::Bool) = nothing
a_extra_correction(io, _) = println(io, "- extra correction is missing/wrong (use true/false)")

function check4errors(x)
    io = IOBuffer()
    resfile = c_resfile(io, x.resfile)
    poi_names = c_poi_names(io, x.poi_names)
    expected_locations = c_expected_locations(io, x.expected_locations)
    poi_videofile = c_videofile(io, x.poi_videofile, "POI")
    duration = get_duration(poi_videofile)
    a_coords(io, resfile, poi_names, duration, expected_locations)
    a_turning_point(io, poi_videofile, x.turning_point, duration)
    calib_videofile = c_videofile(io, x.calib_videofile, "Calibration")
    a_calibration(io, calib_videofile, x.extrinsic, x.intrinsic, x.checker_size)
    nest2feeder = c_nest2feeder(io, x.nest2feeder)
    a_azimuth(io, x.azimuth)
    expected_nest2feeder = _get_expected_nest2feeder(expected_locations)
    a_expected_nest2feeder(io, expected_nest2feeder, nest2feeder)
    a_extra_correction(io, x.extra_correction)
    String(take!(io))
end

get_duration(::Missing) = missing
function get_duration(file)
    p = FFMPEG.exe(`-i $file -show_entries format=duration -v quiet -of csv="p=0"`, command=FFMPEG.ffprobe, collect=true)
    parse(Float64, only(p))
end

# function get_dimentions(file)
#     p = FFMPEG.exe(`-i $file -show_entries stream=width,height -of csv=p=0:s=x`, command=FFMPEG.ffprobe, collect=true)
#     txt = split(only(p), 'x')
#     parse.(Int, txt)
# end
