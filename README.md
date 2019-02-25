# IGVEugene

Load Trio Data into IGV.

This is a short script that slices bams at a provided set of coordinates and then loads them into IGV interactively. The script then pauses for user input with a prompt on the quality of the site. After running, the script then dumps all variant (with coordinate and proband name) qualities.

## Options

| Option | Description | Default |
|:-------------- |:------------ |:--------- |
| -bams | input of bam paths and variant coordinates (see example_bams.txt) | **none** |
| -hostname | ip address or hostname of computer on which remote IGV is running | **none** |
| -port | port number set within IGV to accept data | 60151 |
| -window | window size to slice bams and view in IGV | 50 |
| -slicedir | directory where bam slices are stored | **none** |
| -volumes | directory where bam slices are stored on local machine | **none** |

**Note:** -slicedir and -volumes are seperate so that if bams and slices are stored on a remote machine, you can provide a different directory to store slices and a different directory to view from. On macos, this is typically done via mounting a fileshare which will appear in the `/Volumes/` directory.

## Input

This script takes a file (provided via -bams) in the following column format:

| Column # | Description |
|:----------- |:------------- |
| 1 | Proband bam path |
| 2 | Mum bam path |
| 3 | Dad bam path |
| 4 | variant chromosome |
| 5 | variant position |

## Use

1. Open IGV and ensure port information is set (go to View->Preferences->Enable Port) to either 60151 or whatever value is in that box.

2. Run trio_slicer:

`./trio_slicer.pl -bams <BAMFILE> -hostname <192.168.1.0> -slicedir /scratch/bamslices/ -volumes /Volumes/bamslices/`

3. Look at bams. The script will proceed one line at a time and pause with the prompt "Site Quality: " and wait for the user to put in some value, or simply press the "RETURN" key. Or, if "QUIT" is entered, all previous variant site information will be dumped for the user.
