struct Calibration{T}
    video::String
    extrinsic::Float64
    intrinsic::T
    checker_size::Float64
end

const Intrinsic = Pair{Float64, Float64}

# _format(c::Calibration{Missing}) = string(basename(c.video), ": ", c.extrinsic)
# _format(c::Calibration) = string(basename(c.video), ": ", c.extrinsic, ", ", c.intrinsic)

# tmix=frames=15:weights="1 1 1 1 1 1 1 1 1 1 1 1 1 1 1",
#=function getgrayimg(file, t)
    imgraw = ffmpeg() do exe
        read(`$exe -loglevel 8 -ss $t -i $file -vf format=gray,yadif=1,scale=sar"*"iw:ih -pix_fmt gray -vframes 1 -f image2pipe -`)
    end
    # return ImageIO.load(imgraw)
    return rotr90(reinterpret(UInt8, green.(ImageMagick.load_(imgraw))))
end=#

# -vf 'yadif=1    ,,scale=sar*iw:ih
#=function make_calibration(c::Calibration{Missing})
    img = getgrayimg(c.video, c.extrinsic)
    ret, corners = cv2.findChessboardCorners(img, c.checkers)
end=#

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
    (; ϵ, tform, itform)
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
    $mean_error = mean(errors);
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
    ϵ = mean_error
    (; parameters, R, t, ϵ)
    
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
    ffmpeg_exe(`-loglevel 8 -ss $ss -i $video -t $t -r 2 -vf format=gray,yadif=1,scale=sar"*"iw:ih -pix_fmt gray $path`)
    readdir(path, join = true)
end

@memoize function build_calibration(c)
    path = mktempdir(homedir(); prefix="calibration_", cleanup=false)
    extrinsic = extract(c.extrinsic, c.video, path)
    intrinsic = extract(c.intrinsic, c.video, path)
    spawnmatlab(c.checker_size, extrinsic, intrinsic)
end

calibrate(tform, i::Interval) = tform.(space(i))
calibrate(tform, x) = tform(space(x))


function calibrate_mat(matfile, xyt)
    xy = xyt.data[:,1:2]
    mat"""
    a = load($matfile);
    $xy = pointsToWorld(a.params, a.R, a.t, $xy);
    """
    P([xy xyt.data[:,3]])
end


