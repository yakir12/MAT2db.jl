const Space = SVector{2, Float64}

struct SpaceTime
    xy::Space
    t::Float64
end
SpaceTime(x, y, t) = SpaceTime(Space(x, y), t)

# const SpaceTime = typeof(StructArray((xy = Space.(rand(2), rand(2)), t = rand(2))))

struct POI
    xyt::StructVector{SpaceTime}
    video::String
end
POI(x, y, t, v) = POI(StructVector(SpaceTime.(x, y, t)), v)
space(x::POI) = x.xyt.xy
time(x::POI) = x.xyt.t
space(x::POI, i) = x.xyt[i].xy
time(x::POI, i) = x.xyt[i].t

function resfile2coords(resfile, videofile)
    matopen(resfile) do io
        xdata = read(io, "xdata")
        fr = read(io, "status")["FrameRate"]
        rows = rowvals(xdata)
        xvals = nonzeros(xdata)
        yvals = nonzeros(read(io, "ydata"))
        n = size(xdata, 2)
        coords = POI[]
        for j = 1:n
            i = nzrange(xdata, j)
            if !isempty(i)
                poi = POI(xvals[i], yvals[i], rows[i]/fr, videofile)
                push!(coords, poi)
            end
        end
        return coords
    end
end

cleanpoi(x::POI) = length(x.xyt) == 1 ? space(x, 1) : x.xyt
