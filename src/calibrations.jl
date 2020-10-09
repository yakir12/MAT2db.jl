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

push1(x) = push(x, 1.0)

function spawnmatlab(check, extrinsic, ::Missing)
    mat"""
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
    img = FileIO.load(extrinsic)
    h, w = size(img)
    _image = [(x, y) for x in 1:w for y in 1:h]
    image = hcat(first.(_image), last.(_image))
    mat"""
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
    $errors2 = errors;
    %%
    imUndistorted = undistortImage(extrinsicI, params);
    MinCornerMetric = 0.15;
    xy = detectCheckerboardPoints(imUndistorted, 'MinCornerMetric', MinCornerMetric);
    MinCornerMetric = 0.;
    while size(xy,1) ~= size(worldPoints, 1)
        MinCornerMetric = MinCornerMetric + 0.05;
        xy = detectCheckerboardPoints(imUndistorted, 'MinCornerMetric', MinCornerMetric);
    end
    [R,t] = extrinsics(xy,worldPoints,params);
    $world = pointsToWorld(params, R, t, $image);
    """
    _tform = interpolate(reshape(Space.(eachrow(world)), h, w)', BSpline(Linear()))
    tform = splat(extrapolate(scale(_tform, 1:w, 1:h), Flat()))
    mx, Mx = extrema(world[:,1])
    my, My = extrema(world[:,2])
    xs = mx:Mx
    ys = my:My
    worldPoints = vcat(([x y 0.0] for x in xs for y in ys)...)
    mat"""
    $projectedPoints = worldToImage(params,R,t,$worldPoints);
    """
    _itform = interpolate(reshape(Space.(eachrow(projectedPoints)), length(ys), length(xs))', BSpline(Linear()))
    itform = splat(extrapolate(scale(_itform, xs, ys), Flat()))
    ϵ = round.(quantile(errors2, [0, 0.5, 1]), digits = 2)
    BothCalibration((; tform, itform), ϵ)
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
    r = 2#80/t
    files = joinpath(path, "intrinsic%03d.png")
    ffmpeg_exe(`-loglevel 8 -ss $ss -i $video -t $t -r $r -vf format=gray,yadif=1,scale=sar"*"iw:ih -pix_fmt gray $files`)
    readdir(path, join = true)
end

@memoize function build_calibration(c)
    @debug "building calibration" c
    mktempdir() do path
    # path = mktempdir(cleanup = false)
        extrinsic = extract(c.extrinsic, c.video, path)
        intrinsic = extract(c.intrinsic, c.video, path)
        spawnmatlab(c.checker_size, extrinsic, intrinsic)
    end
end

calibrate!(poi, c) = map!(c, space(poi), space(poi))
calibrate!(poi, c::ExtrinsicCalibration) = map!(c.tform, space(poi), space(poi))
calibrate!(poi, c::BothCalibration) = map!(c.matlab.tform, space(poi), space(poi))


function calibrate(c::ExtrinsicCalibration, img)
    indices = ImageTransformations.autorange(img, c.tform)
    imgw = warp(img, c.itform, indices)
    return indices, parent(imgw)
end
function calibrate(c::BothCalibration, img)
    indices = ImageTransformations.autorange(img, c.matlab.tform)
    imgw = warp(img, c.matlab.itform, indices)
    return indices, parent(imgw)
end

build_extra_calibration(c::NTuple{0}, e::NTuple{0}) = IdentityTransformation()
build_extra_calibration(c::NTuple{1}, e::NTuple{1}) = IdentityTransformation()
function build_extra_calibration(c::NTuple{2}, e::NTuple{2})
    s = norm(e[2] - e[1])/norm(c[2] - c[1])
    LinearMap(Diagonal(SVector(s, s)))
end
build_extra_calibration(c::NTuple{3}, e::NTuple{3}) = createAffineMap(c, e)
function build_extra_calibration(c::NTuple{N}, e::NTuple{N}) where N 
    @warn "didn't implement an extra calibration for more than 3 expected locations. Using the first 3 only."
    createAffineMap(c[1:3], e[1:3])
end

function createAffineMap(poic, expected)
    X = vcat((poic[k]' for k in keys(expected))...)
    X = hcat(X, ones(3))
    Y = hcat(values(expected)...)'
    c = (X \ Y)'
    A = c[:, 1:2]
    b = c[:, 3]
    AffineMap(SMatrix{2,2,Float64}(A), SVector{2, Float64}(b))
end
