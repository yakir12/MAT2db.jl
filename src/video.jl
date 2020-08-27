function get_videofile()
    videofiles = deserialize(VIDEOFILES_FILE)
    if isempty(videofiles)
        addvideofile!(videofiles)
    else
        options = copy(videofiles)
        push!(options, "new file")
        menu = RadioMenu(options)
        choice = request("Which video file are the POIs in?", menu)
        if choice == length(options)
            addvideofile!(videofiles)
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

function addvideofile!(videofiles)
    @label start
    println("What is the file-path to the new video?")
    videofile = readline()
    badvideofile(videofile) && @goto start
    push!(videofiles, videofile)
    serialize(VIDEOFILES_FILE, videofiles)
    videofile
end

