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

const Coordinate = SVector{2, Float64}

struct TimedCoordinate
    xy::Coordinate
    t::Float64
end
TimedCoordinate(x, y, t) = TimedCoordinate(Coordinate(x, y), t)

# struct Vertices
#     xys::Vector{Coordinate}
#     t::Float64
# end

struct Track
    xys::Vector{TimedCoordinate}
end
Track(x, y, t) = Track(TimedCoordinate.(x, y, t))

function mat2data(resfile)
    matopen(resfile) do io
        xdata = read(io, "xdata")
        fr = read(io, "status")["FrameRate"]
        rows = rowvals(xdata)
        xvals = nonzeros(xdata)
        yvals = nonzeros(read(io, "ydata"))
        n = size(xdata, 2)
        data = Union{TimedCoordinate, Track}[]
        for j = 1:n
            is = nzrange(xdata, j)
            isempty(is) && continue
            a = if length(is) == 1
                i = only(is)
                TimedCoordinate(xvals[i], yvals[i], rows[i]/fr)
            else
                Track(xvals[is], yvals[is], rows[is]/fr)
            end
            push!(data, a)
        end
        return data
    end
end

