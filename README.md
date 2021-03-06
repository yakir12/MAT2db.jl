# MAT2db

This is a package for analysing tracks in the Dacke lab. This will only work if:
1. You have Matlab™ installed.
2. You have Matlab™'s `Computer Vision System` toolbox installed.
3. Each run in your experiment has exactly one:
    1. res-file (e.g. `file.res`) containing all the relevant POIs (Points of Interest).
    2. video-file containing all the relevant POIs.
    3. video-file containing the calibration.
4. The exact same file can be used as the POI video-file and as the calibration video-file within the same run as well as between multiple runs.

## To install
You'll need a new version of Julia installed (see [here](https://julialang.org/downloads/) for instructions on how to install Julia).

Start a new Julia REPL (e.g. by double-clicking the Julia icon). In the new terminal, type a right-hand-square-bracket (`]`) and then `add https://github.com/yakir12/MAT2db.jl`, followed by pressing `Enter`:
```julia
] add https://github.com/yakir12/MAT2db.jl
```

## Setup
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
12. `turning_point`: if you want to override the automatic detection of the turning point, specify the time-stamp in the video (i.e. the `poi_videofile`) when the animal turns, otherwise leave empty.

### Notes
- The number of names in the `poi_names` column must be equal to the number of columns in the `res` file, even if one (or more) of the columns is empty.
- `intrinsic_start`, `intrinsic_stop`, `azimuth`, and `turning_point` can be left empty when not relevant.
- `poi_videofile` and `calib_videofile` can be the exact same file within and between row/s. 
- The expected locations in `poi_names` should only refer to POIs that you have an actual location for (e.g. a POI that has a column in the `res` file). So for instance, it is not OK to specify `nest 0 0` for a transfer experiment, but `fictive_nest 0 0` is.
- Two expected locations in the `poi_names` can not possibly be identical unless they truly are. In a zero vector experiment, for example, if you meant to pick up the animal (and displace it) at the nest but in reality you picked it up close to the nest, `nest` and `pickup` cannot have identical expected locations. The easiest way to reason about this is, each POI was manually chosen by you when you tracked it (e.g. in `DungTrack`) -- how and why would you click at the exact same coordinate in the image?
- Do not add a plus sign, `+`, to the expected POI location: `feeder 0 130` is correct while `feeder 0 +130` is not. 
- Times can be given to an accuracy of milliseconds. So if an event happens at 5 seconds and 123 milliseconds, you can write 5.123.


## To run
First use the package:
```julia
using MAT2db
```
and then run the main function, where `<full_file_path>` is the full path to the `csv` file surrounded by quotation marks, `"` (e.g. `"/home/yakir/tmp/example.csv"`):
```julia
process_csv(<full_file_path>)
```

This will first check for any errors in your files. Read any error messages to discover what went wrong, for instance:
```julia
ERROR: 
Run #3
- intrinsic time-stamp is not in the video
Run #7
- extrinsic time-stamp is not in the video
- intrinsic time-stamp is not in the video
```
reports that in run #3 (so row #4 in the csv-file) the time-stamp of the intrinsic calibration is outside of the scope of the video (e.g. a time-stamp of 2 minutes in a video that is 1 minute long), and that in run #7, both the extrinsic time stamp and intrinsic time stamp are out of scope. After fixing the reported errors, rerun the `process_csv` function, and repeat until no errors are reported.

If no errors were detected, it will save quality reports and results on all of the calibrations and runs in a `data` folder in the same location you ran the code from. For example:
```
data
├── quality
│   ├── calibrations
│   │   └── 20181121_02_left.mov582.835.png
│   └── runs
│       └── 1
│           ├── calibrated POIs.png
│           ├── feeder.png
│           ├── initialfeeder.png
│           ├── nest.png
│           ├── pellet.png
│           ├── track1.png
│           ├── track2.png
│           ├── track3.png
│           ├── track4.png
│           └── track5.png
└── results
    └── 1.png
```
## data
### quality
#### calibrations
A calibration image shows how the calibrated checkerboard image compares to the raw one as well as the minimum, mean, and maximum calibration errors in cm (ϵ). This error is the mean distance (in cm) between the expected locations of the checkerboard's corners (e.g. `(0,0), (4, 0), (8,0)...`) and the location of the corners that were detected in the image and calibrated from pixel coordinates to real-world coordinates. You can think of this error as a measure of how bad the smallest errors in the image are (image locations that are further away from the checkerboard's location in the image may have larger errors). Depending on your needs, an error of 1 cm means that the location of any POIs (e.g. nest, turning point, fictive nest, etc.) may be 1 cm off its true location.

Check that:
- Is the checkerboard flush against the ground?
- Are the dimensions of the scene reasonable (i.e. not 10,000 or 10 cm wide/tall)?
- Is the aspect ratio of the scene normal (e.g. the scene is not 10 cm wide and 10 m tall)?
- Is the left top corner of the checkerboard at `(0,0)`)?
- Are there any other obvious problems with the calibrated image? 
- Are the errors acceptable?
#### runs
For each run there will be a folder (labeled 1, 2, 3 etc.). In each of those folders are images of the POIs. These are extracted frames from the POI-video highlighting (in red) where the specific POI is located. The `track` POI is a shown as a series of 5 images uniformly extracted from the video.

Check that:
- Are all the POIs labeled correctly?
- Are all the POIs located accurately?

An additional image, `calibrated POIs.png`, shows two panes:
1. a calibrated snapshot from the POI-video and with it all the calibrated POIs (labeled).
2. the same as above but corrected to the expected locations of the POIs.

Check that:
- Do the angles and distances in the calibrated POIs make sense (e.g. is the distance between the nest and feeder ~130cm, is the angle between the `initialfeeder`, `feeder`, and `nest` 90°)?
- Are the deviations in the calibrated image unacceptable (locations, distances, and angles are significantly off the marks)?
### results
Each run has one result image showing the track and POIs oriented so that the nest is at origo and the feeder is directly below it. 

Check that:
- everything looks right.

## Process multiple tracks in one run
If your data is a video with a beetle repeatedly running the same track you should specify a different processing function, like so:
```julia
process_csv(csvfile, fun = process_run_of_tracks)
```

## To debug
If you run into some unknown error, run the `process_csv` function in the debug mode:
```julia
process_csv("csvfile.csv", debug = true)
```
This will produce a (tarball) file that you can send to me.

If you want to send me a single run for inspection (even if it didn't error), use:
```julia
MAT2db.debugging(csvfile, i)
```
where `i` is the row number (excluding the title row in the csv file) of the run you want to send.
