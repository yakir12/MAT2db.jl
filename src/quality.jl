function getimg(file, t)
    imgraw = ffmpeg() do exe
        read(`$exe -loglevel 8 -ss $t -i $file -vf tmix=frames=15:weights="1 1 1 1 1 1 1 1 1 1 1 1 1 1 1" -vframes 1 -f image2pipe -`)
    end
    return rotr90(ImageMagick.load_(imgraw))
end


