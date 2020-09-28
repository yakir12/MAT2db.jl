# MAT2db

This is a package for analysing tracks in the Dacke lab. This will only work if:
1. You have Matlab™ installed.
2. Each run in your experiment has exactly one:
    1. res-file (e.g. `file.res`) containing all the relevant POIs (Points of Interest).
    2. video-file containing all the relevant POIs.
    3. video-file containing the calibration.
3. The exact same file can be used as the POI video-file and as the calibration video-file within the same run as well as between multiple runs.


## To install
```julia
] add https://github.com/yakir12/MAT2db.jl
```

Create a `.csv` file like [this one](/example/example.csv) (e.g. with Microsoft Excel). Each row in the file (except the title row) is one run. There may be as many rows (=runs) as you like. The file must have the following columns:
1. `resfile`: the full path to the `.res` file containing all the pixel coordinates of the POIs.
2. `poi_videofile`: the full path to the video file containing the POIs.
3. `poi_names`: the names of the POIs (e.g. `track`, `nest`, `dropoff`, etc.), as well as the expected location for each POI (if such exists). Such expected locations are specified directly after the specific POI name and are separated with spaces (e.g. `feeder 0 -130`). For example:
   `nest 0 0,initialfeeder 0 -130,pellet,feeder 50 -130,track`
4. `calib_videofile`: the full path to the video file that contains the calibration for these POIs.
5. `extrinsic`: the time in seconds for when the checkerboard is flat on the ground in the `calib_videofile` (e.g. `2.5`).
6. `intrinsic_start`: the time in seconds for when the moving of the checkerboard starts in the `calib_videofile` (e.g. `3`).
7. `intrinsic_stop`: the time in seconds for when the moving of the checkerboard stops in the `calib_videofile` (e.g. `6.321`).
8. `checker_size`: the size of the checkers in the checkerboard in centimeters (e.g. `3.9`).
9. `nest2feeder`: in the case of a transfer experiment, this is the measured, actual, distance between the nest and the feeder in cm (e.g. `130.9`). Note, this value should agree with the distance between the expected location of the nest and feeder from #3 (if such estimates are available). 
10. `azimuth`: in the case of a transfer experiment, this is the azimuth between the nest and feeder in degrees (e.g. `272.9`).
11. `extra_correction`: when the expected locations of some of the POIs are available (see point #3 above), it is possible to correct (=force) the coordinates so that POIs are *exactly* where they are expected to be. This boolean column dictates if to apply (`true`) or not to apply (`false`) this extra correction.
12. `turning_point`: if you want to overide the automatic detection of the turning point, specify the time-stamp in the video (i.e. the `poi_videofile`) when the animal turns, otherwise leave empty.

### Notes
1. `intrinsic_start`, `intrinsic_stop`, `azimuth`, and `turning_point` can be left empty when not relevant.
2. `poi_videofile` and `calib_videofile` can be the exact same file within and between row/s. 
3. The expected locations in `poi_names` should only refer to POIs that you have an actual location for (e.g. a POI that has a columnin the `res` file). So for instance, it is not ok to specify `nest 0 0` for a transfer experiment.


## To run
First use the package:
```julia
using MAT2db
```
and then run the main function:
```
process_csv("this is the full path to the your csv file.csv")
```

This will first check for any errors in your files (read any error messages to discover what went wrong). If no errors were detected, it will save quality reports and results on all of the calibrations and runs in a `data` folder in the same location you ran the code from:
```
data
├── quality
│   ├── calibrations
│   │   └── 20181121_02_left.mov582.835.png
│   └── runs
│       └── 1
│           ├── calibrated POIs.png
│           ├── feeder.png
│           ├── initialfeeder.png
│           ├── nest.png
│           ├── pellet.png
│           └── track.mkv
└── results
    └── 1.png
```
In the quality folder: The calibration image shows how the calibrated checkerboard image compares to the raw one as well as the minimum, mean, and maximum calibration errors in cm.
In each run folder there are the raw POIs and their pixel coordinates (track is a movie while the others are images), as well as the calibrated POIs and their relative distances to each other in cm (this includes the calibrated and corrected representations).
In the results folder: Each run has one result image showing the track and POIs oriented so that the nest is at origo and the feeder is directly below it. 

## To check for
In terms of the calibrations:
- Is the checkerboard flush against the ground?
- Are the X and Y axes in the calibrated image correct (scale-wise and is the left bottom corner of the checkerboard at `(0,0)`)?
- Are the errors acceptable (e.g. what is the maximal error)?
In terms of the runs:
- Are all the POIs labeled correctly?
- Are all the POIs located accurately?
- Do the angles and distances in the calibrated POIs make sense (e.g. is the distance between the nest and feeder ~130cm)?
- Are the deviations in the calibrated image unacceptable (locations, distances, and angles are significantly off the marks)?
