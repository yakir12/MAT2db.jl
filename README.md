# MAT2db

## To install
```julia
] add https://github.com/yakir12/MAT2db.jl
```

Ceate a `.csv` file like [this one](/example/example.csv) (e.g. with Microsoft Excel). The file must have 8 columns:
1. `resfile`: the full path to the `.res` file with all the pixel coordinates of all of the POIs (Points of Interest).
2. `poi_videofile`: the full path to the video file that contains all the POIs.
3. `poi_names`: the names of the POIs (e.g. `track`, `nest`, `dropoff`, etc.).
4. `calib_videofile`: the full path to the video file that contains the calibration for these POIs.
5. `extrinsic`: the time in seconds for when the checkboard is flat on the ground in the `calib_videofile` (e.g. `2.5`).
6. `intrinsic_start`: the time in seconds for when the moving of the checkboard starts in the `calib_videofile` (e.g. `3`).
7. `intrinsic_stop`: the time in seconds for when the moving of the checkboard stops in the `calib_videofile` (e.g. `6.321`).
8. `checker_size`: the size of the checkers in the checkerb in centimeters (e.g. `3.9`).

Each row in the file (except the title row) is one run. There may be as many rows (=runs) as you like.

## To run 
First use the package:
```julia
using MAT2db
```
and then run the main function:
```
process_csv("this is the full path to the your csv file.csv")
```

This will first check for any errors in your files (read any error messages to discover what went wrong). If no errors were detected, it will save quality reports on all of the calibrations and runs in a `results` folder in your home directory:
```
quality
├── calibrations
│   └── 20181121_02_left.mov582.835.png
└── runs
    └── 1
        ├── calibrated POIs.png
        ├── feeder.png
        ├── initialfeeder.png
        ├── nest.png
        ├── pellet.png
        └── track.mkv
```
The calibration image shows how the calibrated checkboard image compares to the raw one as well as the minimum, mean, and maximum calibration errors in cm.
In each run folder there are the raw POIs and their picel coordinates (track is a movie while the others are images), as well as the calibrated POIs and their relative distances to each other in cm.

## To check for
In terms of the calibrations:
- Is the checkboard flush against the ground?
- Are the X and Y axes in the calibrated image correct (scale wise and is the left bottom corner of the checkboard at `(0,0)`)?
- Are the errors acceptable (e.g. what is the maximal error)?
In terms of the runs:
- Are all the POIs labeled correctly?
- Are all the POIs located accurately?
- Do the angles and distances in the calibrated POIs make sense (e.g. is the distance between the nest and feeder ~130cm)?
