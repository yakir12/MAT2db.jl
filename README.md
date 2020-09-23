# MAT2db

## To install
```julia
] add https://github.com/yakir12/MAT2db.jl
```

Create a `.csv` file like [this one](/example/example.csv) (e.g. with Microsoft Excel). The file must have 10 columns:
1. `resfile`: the full path to the `.res` file with all the pixel coordinates of all of the POIs (Points of Interest).
2. `poi_videofile`: the full path to the video file that contains all the POIs.
3. `poi_names`: the names of the POIs (e.g. `track`, `nest`, `dropoff`, etc.), as well as the expected location for each POI (if such exists). Such expected locations are specified directly after the specific POI name and separated with spaces (e.g. `feeder 0 -130`). For example:
   `nest 0 0,initialfeeder 0 -130,feeder 50 -130,track`
4. `calib_videofile`: the full path to the video file that contains the calibration for these POIs.
5. `extrinsic`: the time in seconds for when the checkerboard is flat on the ground in the `calib_videofile` (e.g. `2.5`).
6. `intrinsic_start`: the time in seconds for when the moving of the checkerboard starts in the `calib_videofile` (e.g. `3`).
7. `intrinsic_stop`: the time in seconds for when the moving of the checkerboard stops in the `calib_videofile` (e.g. `6.321`).
8. `checker_size`: the size of the checkers in the checkerboard in centimeters (e.g. `3.9`).
9. `nest2feeder`: in the case of a "transfer" experiment, this is the measured, actual, distance between the nest and the feeder in cm (e.g. `130.9`).
10. `azimuth`: in the case of a "transfer" experiment, this is the azimuth between the nest and feeder in degrees (e.g. `272.9`).
11. `extra_correction`: when the expected locations of some of the POIs are available (see point #3 above), it is possible to correct the coordinates so that POIs are *exactly* where they are expected to be. This boolean column dictates if to apply (`true`) or not to apply (`false`) this extra correction.

*Note:* `intrinsic_start`, `intrinsic_stop`, `nest2feeder`, and `azimuth` can be left empty when not relevant. `poi_videofile` and `calib_videofile` can be the exact same file. 

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
│   └── 20181121_02_left.mov582.835.png
└── runs
    └── 1
        ├── calibrated POIs.png
        ├── feeder.png
        ├── initialfeeder.png
        ├── nest.png
        ├── pellet.png
        └── track.mkv
```
The calibration image shows how the calibrated checkerboard image compares to the raw one as well as the minimum, mean, and maximum calibration errors in cm.
In each run folder there are the raw POIs and their pixel coordinates (track is a movie while the others are images), as well as the calibrated POIs and their relative distances to each other in cm.

## To check for
In terms of the calibrations:
- Is the checkerboard flush against the ground?
- Are the X and Y axes in the calibrated image correct (scale wise and is the left bottom corner of the checkerboard at `(0,0)`)?
- Are the errors acceptable (e.g. what is the maximal error)?
In terms of the runs:
- Are all the POIs labeled correctly?
- Are all the POIs located accurately?
- Do the angles and distances in the calibrated POIs make sense (e.g. is the distance between the nest and feeder ~130cm)?
- Are the deviations in the calibrated image unacceptable (locations, distances, and angles are significantly off the marks)?
