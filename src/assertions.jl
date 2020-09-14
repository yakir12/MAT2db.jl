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

function a_coords(i, coords, resfile)
    @assert !isempty(coords) "res file in run #$i was empty"
    @assert any(x -> isa(x, Interval), coords) "res file in run #$i missing track"
end

function a_poi_names(i, poi_names, n)
    @assert allunique(poi_names) "POI names must be unique in run #$i"
    npois = length(poi_names)
    @assert npois == n "number of POIs, $npois, doesn't match the number of res columns, $n, in run #$i"
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
