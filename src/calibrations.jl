struct Calibration{T}
    video::String
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

push1(x) = push(x, 1.0)

function spawnmatlab(check, extrinsic, ::Missing)
    mat"""
    warning('off','all')
    I = imread($extrinsic);
    [imagePoints, boardSize] = detectCheckerboardPoints(I);
    worldPoints = generateCheckerboardPoints(boardSize, $check);
    tform_ = fitgeotrans(imagePoints, worldPoints, 'projective');
    $xy1 = imagePoints;
    $xy2 = worldPoints;
    $tform = tform_.T;
    %%
    [x, y] = transformPointsForward(tform_, imagePoints(:,1), imagePoints(:,2));
    $errors = vecnorm(worldPoints - [x, y], 2, 2);
    """
    M = LinearMap(SMatrix{3,3, Float64}(tform'))
    tform = PerspectiveMap() ∘ M ∘ push1
    itform = PerspectiveMap() ∘ inv(M) ∘ push1
    ϵ = round.(quantile(errors, [0, 0.5, 1]), digits = 2)
    ExtrinsicCalibration(tform, itform, ϵ)
end


function spawnmatlab(check, extrinsic, intrinsic)
    mat"""
    warning('off','all')
    [imagePoints, boardSize, imagesUsed] = detectCheckerboardPoints($intrinsic);
    $kept = 1:length($intrinsic);
    $kept = $kept(imagesUsed);
    extrinsicI = imread($extrinsic);
    sz = size(extrinsicI);
    worldPoints = generateCheckerboardPoints(boardSize, $check);
    %%
    params = estimateCameraParameters(imagePoints, worldPoints, 'ImageSize', sz, 'EstimateSkew', true, 'NumRadialDistortionCoefficients', 3, 'EstimateTangentialDistortion', true, 'WorldUnits', 'cm');
    n = size(imagePoints, 3);
    errors = zeros(n,1);
    for i = 1:n
        [R,t] = extrinsics(imagePoints(:,:,i), worldPoints, params);
        newWorldPoints = pointsToWorld(params, R, t, imagePoints(:,:,i));
        errors(i) = mean(vecnorm(worldPoints - newWorldPoints, 1, 2));
    end
    kill = errors > 1;
    while any(kill)
        imagePoints(:,:,kill) = [];    
        $kept(kill) = [];
        params = estimateCameraParameters(imagePoints, worldPoints, 'ImageSize', sz, 'EstimateSkew', true, 'NumRadialDistortionCoefficients', 3, 'EstimateTangentialDistortion', true, 'WorldUnits', 'cm');
        n = size(imagePoints, 3);
        errors = zeros(n,1);
        for i = 1:n
            [R,t] = extrinsics(imagePoints(:,:,i), worldPoints, params);
            newWorldPoints = pointsToWorld(params, R, t, imagePoints(:,:,i));
            errors(i) = mean(vecnorm(worldPoints - newWorldPoints, 1, 2));
        end
        kill = errors > 1;
    end
    $errors2 = errors
    %%
    MinCornerMetric = 0.15;
    xy = detectCheckerboardPoints(extrinsicI, 'MinCornerMetric', MinCornerMetric);
    MinCornerMetric = 0.;
    while size(xy,1) ~= size(worldPoints, 1)
        MinCornerMetric = MinCornerMetric + 0.05;
        xy = detectCheckerboardPoints(extrinsicI, 'MinCornerMetric', MinCornerMetric);
    end
    [$R, $t] = extrinsics(xy, worldPoints, params);
    $parameters = params
    """
    ϵ = round.(quantile(errors2, [0, 0.5, 1]), digits = 2)
    BothCalibration((; parameters, R, t), ϵ)
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
    files = joinpath(path, "intrinsic%03d.png")
    ffmpeg_exe(`-loglevel 8 -ss $ss -i $video -t $t -r 2 -vf format=gray,yadif=1,scale=sar"*"iw:ih -pix_fmt gray $files`)
    readdir(path, join = true)
end

@memoize function build_calibration(c)
    mktempdir() do path
        extrinsic = extract(c.extrinsic, c.video, path)
        intrinsic = extract(c.intrinsic, c.video, path)
        spawnmatlab(c.checker_size, extrinsic, intrinsic)
    end
end

calibrate!(poi, c) = map!(c, space(poi), space(poi))
calibrate!(poi, c::ExtrinsicCalibration) = map!(c.tform, space(poi), space(poi))

function calibrate!(poi, c::BothCalibration)
    parameters, R, t = c.matlab
    xy = space(poi)
    mat"""
    $xy2 = pointsToWorld($params, $R, $t, $xy);
    """
    space(poi) .= xy2
end

# calibrate(c::ExtrinsicCalibration, i::Interval) = c.tform.(space(i))
# calibrate(c::ExtrinsicCalibration, x::Singular) = c.tform(space(x))
# function calibrate(c::BothCalibration, i::POI)
#     parameters, R, t = c.matlab
#     xy = space(i)
#     mat"""
#     $xy2 = pointsToWorld($params, $R, $t, $xy);
#     """
#     return xy2
# end

function calibrate(c::ExtrinsicCalibration, img)
    indices = ImageTransformations.autorange(img, c.tform)
    imgw = warp(img, c.itform, indices)
    return indices, parent(imgw)
end
function calibrate(c::BothCalibration, img)
    mat"""
    img2 = undistortImage($img, $(c.matlab.params));
    tform = projective2d($(c.matlab.R));
    $imgw = imwarp(img2, tform);
    """
    indices = axes(imgw)
    return indices, imgw
end

build_extra_calibration(c::NTuple{0}, e::NTuple{0}) = IdentityTransformation()
build_extra_calibration(c::NTuple{1}, e::NTuple{1}) = IdentityTransformation()
function build_extra_calibration(c::NTuple{2}, e::NTuple{2})
    s = norm(diff(e))/norm(diff(c))
    LinearMap(Diagonal(SVector(s, s)))
end
build_extra_calibration(c::NTuple{3}, e::NTuple{3}) = createAffineMap(c, e)
function build_extra_calibration(c::NTuple{N}, e::NTuple{N}) where N 
    @warn "didn't implement an extra calibration for more than 3 expected locations. Using the first 3 only."
    createAffineMap(c[1:3], e[1:3])
end

# function build_extra_calibration(c2e)
#     n = length(c2e)
#     if n ≤ 1
#         Translation(Space(0, 0))
#     elseif n == 2
#         s = norm(diff(last.(c2e)))/norm(diff(first.(c2e)))
#         LinearMap(Diagonal(SVector(s, s)))
#     elseif n == 3
#         createAffineMap(first.(c2e), last.(c2e))
#     else
#         @warn "didn't implement an extra calibration for more than 3 expected locations. Using the first 3 only."
#         createAffineMap(first.(c2e[1:3]), last.(c2e[1:3]))
#     end
# end

function createAffineMap(poic, expected)
    X = vcat((poic[k]' for k in keys(expected))...)
    X = hcat(X, ones(3))
    Y = hcat(values(expected)...)'
    c = (X \ Y)'
    A = c[:, 1:2]
    b = c[:, 3]
    AffineMap(SMatrix{2,2,Float64}(A), SVector{2, Float64}(b))
end


# extracalib(calib, _, poi) = calib
# extracalib(calib::ExtrinsicCalibration, ::Missing, poi) = calib
# function extracalib(calib::ExtrinsicCalibration, expected_locations, poi)
#     # Space = SVector{2, Float64}
#     # d = Vector{Pair{Space, Space}}(undef, 3)
#     # for (i, kxy) in enumerate(split(expected_locations, ','))
#     #     _k, _x, _y = filter(!isempty, split(kxy, ' '))
#     #     k = strip(_k)
#     #     x = parse(Float64, strip(_x))
#     #     y = parse(Float64, strip(_y))
#     #     d[i] = Space(x, y) => space(poi[k]) 
#     # end
#     # itform = AffineMap(d)
#     tform = Translation(SVector{2, Float64}(100,0))
#     ExtrinsicCalibration(calib.tform ∘ tform, calib.itform, calib.ϵ)
# end

