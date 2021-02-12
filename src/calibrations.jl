splat(f) = args -> f(args...)

struct Calibration{T}
    video::SystemPath
    extrinsic::Float64
    intrinsic::T
    checker_size::Float64
end

const Intrinsic = Pair{Float64, Float64}

struct ExtrinsicCalibration
    tform
    itform
    ϵ::Vector{Float64}
end

struct BothCalibration
    matlab
    ϵ::Vector{Float64}
end

extract(::Missing, _, path) = missing
function extract(extrinsic::Float64, video, path)
    to = joinpath(path, "extrinsic.png")
    ffmpeg_exe(`-loglevel 8 -ss $extrinsic -i $video -vf format=gray,yadif=1,scale=sar"*"iw:ih -pix_fmt gray -vframes 1 $to`)
    to
end
function extract(intrinsic::Intrinsic, video, path)
    ss, t2 = intrinsic
    t = t2 - ss
    r = 25/t
    files = joinpath(path, "intrinsic%03d.png")
    ffmpeg_exe(`-loglevel 8 -ss $ss -i $video -t $t -r $r -vf format=gray,yadif=1,scale=sar"*"iw:ih -pix_fmt gray $files`)
    readdir(path, join = true)
end

@memoize function build_calibration(c)
    # @debug "building calibration" c
    mktempdir() do path
        # path = mktempdir(cleanup = false)
        extrinsic = extract(c.extrinsic, c.video, path)
        intrinsic = extract(c.intrinsic, c.video, path)
        # spawnmatlab(c.checker_size, extrinsic, intrinsic)
        buildcalibration(c.checker_size, extrinsic, intrinsic)
    end
end

calibrate!(poi, c) = map!(xy -> calibrate(c, xy), space(poi), space(poi))

function createAffineMap(poic, expected)
    X = vcat((poic[k]' for k in keys(expected))...)
    X = hcat(X, ones(3))
    Y = hcat(values(expected)...)'
    c = (X \ Y)'
    A = c[:, 1:2]
    b = c[:, 3]
    AffineMap(SMatrix{2,2,Float64}(A), SVector{2, Float64}(b))
end

function build_extra_calibration(c, e)
    k = filter_collinearity(e)
    deleteat!(c, k)
    deleteat!(e, k)
    npoints = length(e)
    tform = if npoints < 2
        IdentityTransformation()
    elseif npoints < 3
        s = norm(e[2] - e[1])/norm(c[2] - c[1])
        # LinearMap(SDiagonal(s, s))
        LinearMap(UniformScaling(s))
    else
        createAffineMap(c[1:3], e[1:3])
    end
    itform = inv(tform)
    (; tform, itform)
end

function find_collinear(xy)
    inds = ((1, 2), (1, 3), (2, 3))
    Δ = [norm(xy[i1] - xy[i2]) for (i1, i2) in inds]
    M, i = findmax(Δ)
    j, l = setdiff(1:3, i)
    Δ[j] + Δ[l] ≈ M && return only(setdiff(1:3, inds[i]))
    nothing
end

updatek!(k, j, ::Nothing) = nothing
updatek!(k, j, i) = push!(k, j[i])

function filter_collinearity(xy)
    k = Int[]
    for j in combinations(1:length(xy), 3)
        if !any(∈(k), j)
            i = find_collinear(xy[j])
            updatek!(k, j, i)
        end
    end
    k
end
