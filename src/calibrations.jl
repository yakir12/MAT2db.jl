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

push1(x) = push(x, 1)

function spawnmatlab(check, extrinsic, ::Missing)
    mat"""
    warning('off','all')
    I = imread($extrinsic);
    I = flipud(I);
    [imagePoints, boardSize] = detectCheckerboardPoints(I);
    worldPoints = generateCheckerboardPoints(boardSize, $check);
    tform_ = fitgeotrans(imagePoints, worldPoints, 'affine');
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

calibrate(c::ExtrinsicCalibration, i::Interval) = c.tform.(space(i))
calibrate(c::ExtrinsicCalibration, x::Singular) = c.tform(space(x))
function calibrate(c::BothCalibration, i::POI)
    parameters, R, t = c.matlab
    xy = space(i)
    mat"""
    $xy2 = pointsToWorld($params, $R, $t, $xy);
    """
    return xy2
end



function calibrate(c::ExtrinsicCalibration, img)
    indices = ImageTransformations.autorange(img, c.tform)
    imgw = parent(warp(img, c.itform, indices))
    return indices, imgw
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
