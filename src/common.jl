struct Common
    feeder::Space
    fictive_nest::Space
    track::Track
    pellets::Union{Missing, Vector{Space}}
    nest::Union{Missing, Space}
    pickup::Union{Missing, Space}
    dropoff::Space
end

Base.getproperty(x::Common, k::Symbol) = k === :homing ? homing(x.track) :
                                         k === :searching ? searching(x.track) :
                                         k === :center_of_search ? center_of_search(x.track) :
                                         k === :turning_point ? turning_point(x.track) :
                                         getfield(x, k)


using Unitful, Statistics, StaticArrays, Rotations, CoordinateTransformations, LinearAlgebra

function getmissingfeeder(guess, displacement, nest, dropoff, nest2feeder)
    c = calculatec(guess, displacement, nest, dropoff)
    u = LinearAlgebra.normalize(nest - c)
    return nest + nest2feeder*u
end

getfeeder(x, nest, dropoff, nest2feeder) = haskey(x, :initialfeeder) ? x[:initialfeeder] :
                                           haskey(x, :feeder) ? x[:feeder] :
                                           getmissingfeeder(x[:guess], x[:expected_dropoff], nest, dropoff, nest2feeder)

getpickup(data, ::Missing, _) = missing
getpickup(data, _, feeder) = haskey(data, :rightdowninitial) ? mean(point(data[k]) for k in (:rightdowninitial, :leftdowninitial, :rightupinitial, :leftupinitial)) : 
                             haskey(data, :initialfeeder) ? data[:initialfeeder] : 
                             get(data, :pickup, feeder)

# getdropoff(data, ::Nothing) = nothing
getdropoff(data) = haskey(data, :rightdownfinal) ? mean(data[k] for k in (:rightdownfinal, :leftdownfinal, :rightupfinal, :leftupfinal)) : 
                      haskey(data, :dropoff) ? data[:dropoff] :
                      data[:feeder]

getnest2feeder(x, metadata) = haskey(x, :nestbefore) ? norm(x[:nestbefore] - x[:feederbefore]) :
                    get(metadata, :nest2feeder, missing)


function getdata(x, metadata)
    nest = get(x, :nest, missing)
    tp = get(x, :turning_point, missing)
    track = Track(x[:track], tp)
    _pellet = get(x, :pellet, StructVector{SpaceTime}(undef, 0))
    pellet = _pellet.xy
    dropoff = getdropoff(x)
    nest2feeder = getnest2feeder(x, metadata)
    feeder = getfeeder(x, nest, dropoff, nest2feeder)
    pickup = getpickup(x, nest, feeder)
    feeder, nest, track, pellet, pickup, dropoff, nest2feeder
end

function common(x, metadata)
    feeder, nest, track, pellet, pickup, dropoff, nest2feeder = getdata(x, metadata)
    fictive_nest = getfictive_nest(x, metadata, pickup, nest, dropoff, nest2feeder)
    Common(feeder, fictive_nest, track, pellet, nest, pickup, dropoff)
end

getfictive_nest(x, metadata, pickup::Missing, nest::Space, dropoff::Missing, _) = nest
getfictive_nest(x, metadata, pickup::Space, nest::Space, dropoff::Space, _) = nest + dropoff - pickup
function getfictive_nest(x, metadata, pickup::Missing, nest::Missing, dropoff::Space, nest2feeder)
    south = point(x[:south])
    north = point(x[:north])
    v = north - south
    azimuth = getazimuth(x, metadata)
    α = atan(v[2], v[1]) + azimuth - π
    u = Space(cos(α), sin(α))
    return dropoff + u*nest2feeder
end

function calculatec(guess, displacement, nest, dropoff)
    v = dropoff - nest
    α = π/2 - atan(v[2], v[1])
    t = LinearMap(Angle2d(α)) ∘ Translation(-nest)
    ṫ = inv(t)
    ab = norm(displacement)
    bc², ac² = displacement.^2
    cy = (ab^2 + ac² - bc²)/2ab
    Δ = sqrt(ac² - cy^2)
    c = [ṫ([i*Δ, cy]) for i in (-1, 1)]
    l = norm.(c .- Ref(guess))
    _, i = findmin(l)
    c[i]
end

function anglebetween(north, south, nest, feeder)
    v = LinearAlgebra.normalize(north - south)
    u = LinearAlgebra.normalize(nest - feeder)
    acos(v ⋅ u)
    # atan(v[2], v[1]) - atan(u[2], u[1])
end
getazimuth(x, metadata) = haskey(x, :southbefore) ? anglebetween(x[:northbefore], x[:southbefore], x[:nestbefore], x[:feederbefore]) :
                haskey(metadata, :azimuth) ?  deg2rad(metadata[:azimuth]) :
                missing
                    
######################### END ######################

struct Standardized
    nest2feeder::Float64
    fictive_nest::Space
    track::Track
    pellets::Union{Missing, Vector{Space}}
    pickup::Union{Missing, Space}
    dropoff::Space
end

Base.getproperty(x::Standardized, k::Symbol) = k === :homing ? homing(x.track) :
                                         k === :searching ? searching(x.track) :
                                         k === :center_of_search ? center_of_search(x.track) :
                                         k === :turning_point ? turning_point(x.track) :
                                         k === :nest ? zero(Space) :
                                         k == :feeder ? Space(0.0, -x.nest2feeder) :
                                         getfield(x, k)

function Standardized(x)
    t = get_transform(x.nest, x.fictive_nest, x.feeder)
    fictive_nest = t(x.fictive_nest)
    map!(t, x.track.coords, x.track.coords)
    map!(t, x.pellets, x.pellets)
    pickup = t(x.pickup)
    dropoff = t(x.dropoff)
    nest2feeder = abs(last(t(x.feeder)))
    Standardized(nest2feeder, fictive_nest, x.track, x.pellets, pickup, dropoff)
end

get_center(::Missing, fictive_nest) = fictive_nest
get_center(nest, _) = nest
function get_rotation(v)
    α = atan(v[2], v[1]) + π/2
    LinearMap(Angle2d(-α))
end

function get_transform(nest, fictive_nest, feeder)
    c = get_center(nest, fictive_nest)
    trans = Translation(-c)
    rot = get_rotation(trans(feeder))
    passmissing(rot ∘ trans)
end