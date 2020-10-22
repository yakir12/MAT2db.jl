function debugging(ti)
    tbname, tbio = mktemp(cleanup = false)
    mktempdir() do path
        rowi = NamedTuple(ti)
        tbl = merge(rowi, (resfile = basename(rowi.resfile), poi_videofile = basename(rowi.poi_videofile), calib_videofile = basename(rowi.calib_videofile)))
        CSV.write(joinpath(path, "csvfile.csv"), [tbl])
        cp(rowi.resfile, joinpath(path, basename(rowi.resfile)))
        map(unique((rowi.poi_videofile, rowi.calib_videofile))) do file
            cp(file, joinpath(path, basename(file)))
        end
        Tar.create(path, tbio)
        close(tbio)
        @error "an error has occurred! please send me this file:" tbname
    end
end
debugging(csvfile, i) = debugging(loadcsv(csvfile)[i])

function debug(tbname)
    tmp = "/home/yakir/tmp2"
    for file in readdir(tmp, join = true)
        if last(splitext(file)) ≠ ".toml"
            rm(file, force = true, recursive = true)
        end
    end
    files = Tar.extract(tbname)
    map(readdir(files, join = true)) do file
        mv(file, joinpath(tmp, basename(file)))
    end
    process_csv("csvfile.csv")
end

