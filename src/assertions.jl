a_resfile(resfile) = @assert isfile(resfile) "res file does not exist"

function a_coords(coords)
    @assert !isempty(coords) "res file was empty"
    @assert any(x -> isa(x, Interval), coords) "res file missing track"
end

function a_poi_videofile(poi_videofile)
    @assert isfile(poi_videofile) "POI video file does not exist"
    @assert lowercase.(extension(Path(poi_videofile))) ∈ ("mp4", "avi", "mts", "mov") "unidentified video format"
end

function a_poi_names(poi_names, n)
    @assert allunique(poi_names) "POI names must be unique"
    npois = length(poi_names)
    @assert npois == n "number of POIs, $npois, doesn't match the number of res columns, $n"
end

function a_calibration(c)
    @assert isfile(c.video) "calibration video file does not exist"
    duration = get_duration(c.video)
    @assert 0 ≤ c.extrinsic ≤ duration "extrinsic time stamp is not in the video"
    @assert c.checker_size > 0 "checkers must be larger than zero"
    a_intrinsic(c.intrinsic, duration)
end
function get_duration(file)
    p = ffprobe() do exe
        read(`$exe -i $file -show_entries format=duration -v quiet -of csv="p=0"`, String)
    end
    parse(Float64, p)
end
function a_intrinsic(intrinsic, duration)
    @assert all(x -> 0 ≤ x ≤ duration, intrinsic) "intrinsic time stamp is not in the video"
    @assert issorted(intrinsic) "the intrinsic starting time cannot come after the ending time" 
end
a_intrinsic(::Missing, _) = nothing
