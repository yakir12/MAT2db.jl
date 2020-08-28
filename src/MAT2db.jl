module MAT2db

using FileIO

using MAT, SparseArrays, StaticArrays, Serialization
using AbstractPlotting, GLMakie, FFMPEG_jll, ImageMagick
using AbstractPlotting.MakieLayout
using GLMakie.GLFW
using GLMakie: to_native
using REPL.TerminalMenus
using ContextTracking

const VIDEOFILES_FILE = "videofiles"

include.(("resfile.jl", "choosePOIs.jl", "video.jl"))

if !isfile(VIDEOFILES_FILE)
    serialize(VIDEOFILES_FILE, String[])
end


function main()
    @label start
    resfile = get_resfile()
    data = mat2data(resfile)
    if isempty(data) 
        @warn "res file was empty"
        @goto start
    end
    if all(x -> !isa(x, Track), data) 
        @warn "res file missing track"
        @goto start
    end
    videofile = get_videofile()
    pois = get_pois(data, videofile)
    return Dict(zip(pois, data))
end

end
