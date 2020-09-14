const Space = SVector{2, Float64}
space(x::Space) = x
time(::Space) = error("no time in space")

struct SpaceTime
    xy::Space
    t::Float64
end
SpaceTime(x,y, t) = SpaceTime(Space(x, y), t)
space(x::SpaceTime) = x.xy
time(x::SpaceTime) = x.t

abstract type POI end

struct Singular <: POI
    xyt::SpaceTime
    video::String
end
Singular(x, y, t, v) = Singular(SpaceTime(x, y, t), v)
space(x::Singular) = space(x.xyt)
time(x::Singular) = time(x.xyt)
space(x::Singular, _) = space(x)
time(x::Singular, _) = time(x)

# struct Vertices <: POI
#     xys::Vector{Space}
#     t::Float64
#     video::String
# end
# Vertices(x, y, t, v) = Vertices(Space.(x, y), t, v)
# space(x::Vertices) = x.xys
# time(x::Vertices) = x.t

struct Interval <: POI
    xyts::Vector{SpaceTime}
    video::String
end
Interval(x, y, t, v) = Interval(SpaceTime.(x, y, t), v)
space(x::Interval) = space.(x.xyts)
time(x::Interval) = time.(x.xyts)
space(x::Interval, i) = space(x.xyts[i])
time(x::Interval, i) = time(x.xyts[i])


function resfile2coords(resfile, videofile)
    matopen(resfile) do io
        height = read(io, "status")["vidHeight"]
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
                Singular(xvals[i], height - yvals[i], rows[i]/fr, videofile)
            else
                Interval(xvals[is], height .- yvals[is], rows[is]/fr, videofile)
            end
            push!(coords, a)
        end
        return coords
    end
end
