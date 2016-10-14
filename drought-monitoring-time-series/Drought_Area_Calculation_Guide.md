# How to calculate percent area under drought using U.S. Drought Monitor weekly data

**Date**: February 25, 2016

**Script name**: intersect_shapefiles.R

**Authors**: NCEAS - Gabriel Antunes Daldegan, Ian McCullough and Julien Brun

**Contact**: scicomp@nceas.ucsb.edu

## Overview: 
The script [intersect\_shapefiles.R](intersect_shapefiles.R) calculates the percent area under drought using a user-supplied administrative boundary polygon shapefile (e.g., U.S. states) and U.S. Drought Monitor weekly data. The user supplies year(s) of interest and annual .csv files are generated as output. It relies on the script [drought\_monitoring\_download\_unzip\_plot.R](drought_monitoring_download_unzip_plot.R) to download and unzipp the [US Drought Monitor](http://droughtmonitor.unl.edu) shapefiles.

## Detailed summary (by section):

### R libraries

This script makes use of several R libraries that perform GIS operations (rgeos, raster), table manipulation (dplyr) and parallel processing (doParallel, foreach). Each of these must be installed prior to running the full script. (Tools menu > Install Packages in R Studio or install.packages(‘package name’) in the R console).

### Constants

Most of the specifications in this section may be left alone. There are several places within this section, however, in which the user must supply necessary information for the script to run smoothly. These include:

_main\_path_: path to your project working directory.

_admin\_path_: path to the shapefile contining the units you want to use for the drought percentage area computation

_extract\_shpname_: name of your administrative boundary polygon shapefile (e.g., ‘US\_states.shp’), which should be located in your working directory (main_path). Be sure to use single or double quotation marks and to include the .shp extension for the shapefile.

_ugeoid_: field name of the unique identifier of your polygons you want to use to calculate the percentage drought area.

_YEAR\_START_: first year to analyze (e.g., 2000) (earliest available year)

_YEAR\_END_: last year to analyze (e.g., 2016)
Note: if the current year is selected, all available data to date for that year are used. The start and end years may be the same year. We did not build in the capability to download portions of years.

###Functions

Two functions are defined that will be later run toward the end of the script. 

*reproject_shapefile*: performs a self-explanatory function. The necessary arguments are the name of the shapefile to reproject and the new coordinate system (which is a constant defined above: NAD83_proj). We reproject the administrative boundary shapefile into an Albers Equal Area projection (datum = NAD 1983). We selected an equal area projection because accurately calculating drought area is the clear objective of this analysis. 

*drought_area*: calculates percent area under various drought severity classes within the administrative boundary shapefile. The necessary arguments are the name of the administrative boundary shapefile and the name of the directory containing the time series of drought area shapefiles. This function is somewhat long and contains several steps, so we inserted text comments within the function to guide the user. Here are the basic steps:

1.	Create list of all weekly drought shapefiles in the user-specified directory
2.	Define drought severity classes
3.	Create unique IDs for each administrative polygon
4.	Create output data frame containing slots for each drought class for each administrative polygon
5.	Define a function reproject\_shapefile\_dir that reprojects all shapefiles within the user-specified directory to NAD 1983 Albers Equal Area (NAD83\_proj constant). The previously defined function reproject\_shapefile only accepts a shapefile and we needed a fast way to reproject all shapefiles within a directory. To minimize confusion, we embedded this second reproject function within the drought\_area function
6.	Loop through all shapefiles, calculating percent area classified as drought and non-drought by intersecting weekly drought shapefiles with the administrative polygons and assessing the overlap area. The command foreach allows the function to be run in parallel (simultaneously across multiple CPUs within a cluster)
7.	Finally, a table is returned that contains the drought area time series (by drought severity class specific to each year of analysis

### Main
Having defined constants and necessary functions, the actual processing can now take place. Note that because constants were defined above, this section requires no argument specifications and can be run as is. Below is a summary of what takes place in this section:

1.	Download weekly drought shapefiles based on user-defined YEAR_START and YEAR_END (constants)
2.	Reproject administrative boundary shapefile (using function reproject_shapefile) and calculate areas in square kilometers
3.	Make an output folder
4.	Calculate percent drought areas by running function drought_area in a for loop according to YEAR_START and YEAR_END
5.	Finally, annual .csv files are written to the output directory. There is a row for each administrative unit and for each drought severity class. There is a column for each week in the annual time series.
