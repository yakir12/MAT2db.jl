function get_calibration()
    calibrations = deserialize(CALIBRATONS_FILE)
    if isempty(calibrations)
        addcalibration!(calibrations)
    else
        options = copy(calibrations)
        push!(options, "new file")
        menu = RadioMenu(options)
        choice = request("Which video file are the POIs in?", menu)
        if choice == length(options)
            addcalibration!(calibrations)
        else
            options[choice]
        end
    end
end

function badvideofile(fullpath) 
    path, file = splitdir(fullpath)
    if file[1] == '.'
        @warn "file is hidden"
        return true
    end
    if !isfile(fullpath)
        @warn "file does not exist"
        return true
    end
    name, ext = splitext(file)
    if !any(x -> occursin(Regex(x, "i"), ext), ("mp4", "avi", "mts", "mov"))
        @warn "unidentified video format"
        return true
    end
    return false
end

function extrinsic()
    @label start
    println("When in the video is the board flat and visible?")
    t = readline()
    if badtime(t)
        @warn "wrong time format"
        @goto start
    end::::
end

function intrinsic()
    println("When in the video is the board flat and visible?")
    t = readline()
end

function addcalibration!(calibrations)
    @label start
    println("What is the file-path to the new claibration-video?")
    videofile = readline()
    badvideofile(videofile) && @goto start
    options = ["Only extrinsic", "Intrinsic and extrinsic"]
    menu = RadioMenu(options)
    choice = request("Which calibration type is it?", menu)
    if choice == 1
    else


    push!(calibrations, videofile)
    serialize(CALIBRATONS_FILE, calibrations)
    videofile
end

