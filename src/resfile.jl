function badresfile(fullpath) 
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
    if ext ≠ ".res"
        @warn "unidentified format"
        return true
    end
    return false
end

function get_resfile()
    @label start
    println("What is the file-path to the res-file?")
    resfile = readline()
    badresfile(resfile) && @goto start
    resfile
end

const SpaceTime = SVector{3, Float64}

abstract type POI end

struct Singular <: POI
    xyt::SpaceTime
    video::String
end
Singular(x, y, t, v) = Singular(SpaceTime(x, y, t), v)

time(x::Singular) = x.xyt[3]
space(x::Singular) = x.xyt[1:2]

# struct Vertices
#     xys::Vector{SpaceTime}
#     t::Float64
# end

struct Interval <: POI
    xyts::Vector{SpaceTime}
    video::String
end
Interval(x, y, t, v) = Interval(SpaceTime.(x, y, t), v)

time(x::Interval) = x.xyts[1][3]
space(x::Interval) = x.xyts[1][1:2]

function resfile2coords(resfile,videofile)
    matopen(resfile) do io
        xdata = read(io, "xdata")
        fr = read(io, "status")["FrameRate"]
        rows = rowvals(xdata)
        xvals = nonzeros(xdata)
        yvals = nonzeros(read(io, "ydata"))
        n = size(xdata, 2)
        coords = POI[]
        for j = 1:n
            is = nzrange(xdata, j)
            isempty(is) && continue
            a = if length(is) == 1
                i = only(is)
                Singular(xvals[i], yvals[i], rows[i]/fr, videofile)
            else
                Interval(xvals[is], yvals[is], rows[is]/fr, videofile)
            end
            push!(coords, a)
        end
        return coords
    end
end

function badcoords(coords)
    if isempty(coords) 
        @warn "res file was empty"
        return true
    end
    if all(x -> !isa(x, Interval), coords) 
        @warn "res file missing track"
        return true
    end
    return false
end
