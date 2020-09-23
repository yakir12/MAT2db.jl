const Space = SVector{2, Float64}
# space(x::Space) = x
# time(::Space) = error("no time in space")

struct POI
    xy::Vector{Space}
    t::Vector{Float64}
    video::String
end
POI(x, y, t, v) = POI(Space.(x, y), t, v)
space(x::POI) = length(x.xy) == 1 ? only(x.xy) : x.xy
time(x::POI) = length(x.t) == 1 ? only(x.t) : x.t
space(x::POI, i) = x.xy[i]
time(x::POI, i) = x.t[i]

function resfile2coords(resfile, videofile)
    matopen(resfile) do io
        # height = read(io, "status")["vidHeight"]
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
