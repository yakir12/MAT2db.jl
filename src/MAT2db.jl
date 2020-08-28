module MAT2db

using FileIO

using MAT, SparseArrays, StaticArrays, Serialization
using AbstractPlotting, GLMakie, FFMPEG_jll, ImageMagick, FFplay_jll
using AbstractPlotting.MakieLayout
using GLMakie.GLFW
using GLMakie: to_native
using REPL.TerminalMenus
using ContextTracking

const VIDEOFILES_FILE = "videofiles"
const CALIBRATONS_FILE = "calibrations"

include.(("resfile.jl", "choosePOIs.jl", "video.jl", "calibrations.jl"))

if !isfile(VIDEOFILES_FILE)
    serialize(VIDEOFILES_FILE, String[])
end
if !isfile(CALIBRATONS_FILE)
    serialize(CALIBRATONS_FILE, Calibration[])
end

_get_resfile(resfile::Nothing) = get_resfile()
_get_resfile(resfile) = badresfile(resfile) ? get_resfile() : resfile

function main(; resfile = nothing)
    @label start
    resfile = _get_resfile(resfile)
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
    poi_names = get_pois(data, videofile)
    POIs = Dict(zip(poi_names, data))
    calibration = get_calibration()
end

end
