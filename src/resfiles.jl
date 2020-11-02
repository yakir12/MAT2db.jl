const Space = SVector{2, Float64}

struct SpaceTime
    xy::Space
    t::Float64
end
SpaceTime(x, y, t) = SpaceTime(Space(x, y), t)

# const SpaceTime = typeof(StructArray((xy = Space.(rand(2), rand(2)), t = rand(2))))

struct POI
    xyt::StructVector{SpaceTime}
    video::SystemPath
end
POI(x, y, t, v) = POI(StructVector(SpaceTime.(x, y, t)), v)
space(x::POI) = x.xyt.xy
time(x::POI) = x.xyt.t
space(x::POI, i) = x.xyt[i].xy
time(x::POI, i) = x.xyt[i].t

correctedges(x, nframes) = x == nframes ? nframes - 1 :
                           x == 1 ? 2 :
                           x

function resfile2coords(resfile, videofile, poi_names)
    matopen(string(resfile)) do io
        xdata = read(io, "xdata")
        fr = read(io, "status")["FrameRate"]
        nframes = size(xdata, 1)
        rows = rowvals(xdata)
        xvals = nonzeros(xdata)
        yvals = nonzeros(read(io, "ydata"))
        pois = Dict{Symbol, POI}()
        for (j, name) in enumerate(poi_names)
            i = nzrange(xdata, j)
            if !isempty(i) && !all(isnumeric, String(name))
                r = map(x -> correctedges(x, nframes), rows[i])
                pois[name] = POI(xvals[i], yvals[i], r/fr, videofile)
            end
        end
        return pois
    end
end

cleanpoi(x::POI) = length(x.xyt) == 1 ? space(x, 1) : x.xyt
