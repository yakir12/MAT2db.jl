struct Calibration{T}
    video::String
    extrinsic::Float64
    intrinsic::T
    checker_corners::Tuple{Int, Int}
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



function spawnmatlab(check, intrinsic, extrinsic)
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

function spawnmatlab(check, extrinsic, ::Missing)
    mat"""
    warning('off','all')
    [imagePoints, boardSize] = detectCheckerboardPoints($extrinsic);
    worldPoints = generateCheckerboardPoints(boardSize, $check);
    tform_ = fitgeotrans(imagePoints, worldPoints, 'projective');
    $tform = tform_.T;
    %%
    [x, y] =  transformPointsForward(tform_, imagePoints(:,1), imagePoints(:,2));
    $mean_error = mean(vecnorm(worldPoints - [x, y], 2, 2))
    """
    ϵ = mean_error
    (; tform, ϵ)
end

extract(::Missing, _, path) = nothing
function extract(ss::Float64, i, path)
    ffmpeg() do exe
        to = joinpath(path, "extrinsic.png")
        run(`$exe -loglevel 8 -ss $ss -i $i -vf format=gray,yadif=1,scale=sar"*"iw:ih -pix_fmt gray -vframes 1 $to`)
        to
    end
end
function extract(intrinsic::Intrinsic, i, path)
    ss, t2 = intrinsic
    t = t2 - ss
    ffmpeg() do exe
        run(`$exe -loglevel 8 -ss $ss -i $i -t $t -r 2 -vf format=gray,yadif=1,scale=sar"*"iw:ih -pix_fmt gray $path`)
    end
    readdir(path, join = true)
end

function build_calibration(c)
    mktempdir() do path
        extrinsic = extract(c.extrinsic, c.video, path)
        intrinsic = extract(c.intrinsic, c.video, path)
        spawnmatlab(c.checker_size, extrinsic, intrinsic)
    end
end





function calibrate_csv(csvfile, xyt::P) where {P <: AbstractPeriod}
    n = size(xyt.data,1)
    xy1 = [xyt.data[:,1:2] ones(n)]
    tform = readdlm(csvfile, ',', Float64)
    xy2 = xy1*tform
    xy3 = xy2[:,1:2]./xy2[:,3]
    P([xy3 xyt.data[:,3]])
end

function calibrate_mat(matfile, xyt::P) where {P <: AbstractPeriod}
    xy = xyt.data[:,1:2]
    mat"""
    a = load($matfile);
    $xy = pointsToWorld(a.params, a.R, a.t, $xy);
    """
    P([xy xyt.data[:,3]])
end


