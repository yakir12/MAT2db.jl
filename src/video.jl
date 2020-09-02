function get_videofile(videofiles, msg)
    if isempty(videofiles)
        newvideo() else
        push!(videofiles, "new file")
        menu = RadioMenu(videofiles)
        choice = request(msg, menu)
        if choice == length(videofiles)
            newvideo()
        else
            videofiles[choice]
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

function newvideo()
    @label start
    println("What is the file-path to the new video?")
    videofile = readline()
    badvideofile(videofile) && @goto start
    videofile
end

