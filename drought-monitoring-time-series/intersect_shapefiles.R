#############################################################################################################
### Calculate percent area in drought in administrative boundaries using U.S. Drought Monitor Weekly Data ###
### For the SNAP working group Ecological Drought - https://www.nceas.ucsb.edu/projects/12703             ###  
###                                                                                                       ###
### Created on: Feb 3, 2016                                                                               ###
### Last updated: Feb 22, 2016                                                                            ###
### Authors: Gabriel Antunes Daldegan (gdaldegan@nceas.ucsb.edu), Ian McCullough (immccull@gmail.com)     ###
###          Julien Brun (brun@nceas.ucsb.edu)                                                            ###
### Contact: scicomp@nceas.ucsb.edu                                                                       ###
#############################################################################################################

### Load necessary R packages ###
library(rgeos) # Display of maps
library(raster) # GIS operations
library(dplyr) # table manipulations
# Multiprocessing
library(doParallel)
library(foreach)

# Access the weekly drought shapefile download script (located in your working directory)
source('drought_monitoring_download_unzip_plot.R')


#### CONSTANTS ####

## Multiprocessing cores
# best to leave empty arguments; by default, the number of cores used for parallel 
# execution is 1/2 the number of detected cores (if number is unspecified)
registerDoParallel() 

## Set working directory
main_path <- "/Users/brun/GitHub/gitSNAPP/ecological-drought"
setwd(main_path)

## Input files
# Path to the admin shapefile used to extract percent area under various drought classes
admin_path <- main_path
admin_path <- "/Users/brun/Data/Tiger"
# Full path and filename
admin_shp <- file.path(admin_path,extract_shpname)

# Output directory
output_directory <- file.path(main_path,'output')

## Projection system used for the intersect, here NAD 1983 Albers Equal Area
NAD83_PROJ <- "+proj=aea +lat_1=20 +lat_2=60 +lat_0=40 +lon_0=-96 +x_0=0 +y_0=0 +datum=NAD83 +units=m +no_defs"

## Unique identifier of the polygons of interest (here US States)
ugeoid <- "GEOID"

## Years to download
YEAR_START <- 2016 # earliest available year = 2000
YEAR_END <- 2016 # if the current year is selected, all available data to date are downloaded

## Processing options
# If you want to download the file, set it to TRUE
download_status <- TRUE
# If you want to overwite the file when unzipping, set it to TRUE
overwrite_status <- TRUE
# If you want to plot the shapefile, set it to TRUE
plotting_status <- FALSE


#### FUNCTIONS ####

#' Read and reproject a shapefile to the provided coordinates system
#'
#' @param shapefile_folder A character
#' @param proj4_string 
#' @return reprojected shapefile
#' @examples
#'
reproject_shapefile_dir <- function(shapefile_folder, proj4_string) {
  shp <- raster::shapefile(shapefile_folder)
  shp83 <- spTransform(shp,CRS(NAD83_PROJ))
  return(shp83)
}


# Function to calculate percent drought area within specified administrative boundaries
#' drought_area
#'
#' @param admin_shp A spatial dataframe
#' @param drought_direc A character
#' @return A dataframe containing the yearly time-series
#' @examples
#' 
drought_area <- function(admin_shp, drought_direc) {
  ## DEFINITION of ARGUMENTS
  #admin_shp = single shapefile of administrative boundaries (e.g., US states, counties)
  #drought_direc = directory containing time-series of drought area shapefiles
  
  # List the shapefiles for a specific year
  drought_list <- list.files(drought_direc, pattern='.shp$')

  ## Create the output dataframe to store the drought area (pct) time-series
  # Drought categories, following the Drought Monitoring classification scheme (http://droughtmonitor.unl.edu/AboutUs/ClassificationScheme.aspx)
  # Coding used: 0 = D0;	1 = D1; 2 =	D2; 3 =	D3; 4 =	D4 and 10 = No drought 
  DroughtClass = c(0:4,10)
  
  # All admin units
  geoids <- unique(admin_shp_prj@data[,ugeoid])
  # Combination of all the options => fix the problem of missing info when there is no drought in certain areas
  drought_ts <- expand.grid(GEOID=geoids,DM=DroughtClass) #expand.grid creates data frame from all combinations of factors
  drought_ts <- left_join(drought_ts,admin_shp_prj@data, by=c(ugeoid))

  # for (shp in drought_list[1:length(drought_list)]) {
  drought_year <- foreach(shp=drought_list[1:length(drought_list)],.combine='cbind',.inorder = TRUE) %dopar% {
    ## READ AND REPROJECT THE WEEKLY DROUGHT SHAPEFILES (from the containing directory)
    shape_weekly_drought_NAlbers <- reproject_shapefile_dir(file.path(drought_direc,shp),NAD83_PROJ)
  
    ## Intersect shapefiles (admin shapefile, drought shapefile)
    inter.drought <- raster::intersect(admin_shp_prj,shape_weekly_drought_NAlbers)
    
    ## Compute Area
    # Calculate areas from intersected polygons, then append as attribute
    inter.drought@data$Area_km2 <- gArea(inter.drought, byid = TRUE) / 1e6 #1e6 to convert sq m to sq km
    
    ## Compute the total drought area by admin units and drought level
    drought_area <- inter.drought@data %>%
      group_by(GEOID,DM) %>%
      summarise(DroughtArea_km2=sum(Area_km2))
    
    # Add the Drought Area
    drought_week <- left_join(drought_ts,drought_area, by=c(ugeoid, 'DM'))
    
    # Set the drought category with no area to 0
    drought_week[(drought_week$DM<10)&(is.na(drought_week$DroughtArea_km2)),"DroughtArea_km2"] <- 0
    
    # Compute the No Drought area per admin unit
    no_drought_area <- drought_week %>%
      group_by(GEOID) %>% 
      summarise(No_DroughtArea_km2 = (mean(AreaUnit_km2) - sum(DroughtArea_km2, na.rm=T))) 
    
    #join the no drought area
    drought_week <- left_join(drought_week,no_drought_area,by=c(ugeoid))
    
    ## Assign the No drought value and compute the percentage area
    drought_week <- mutate(drought_week, DroughtArea_p = ifelse(is.na(DroughtArea_km2),
                                                            round(100*No_DroughtArea_km2/AreaUnit_km2),
                                                            round(100*DroughtArea_km2/AreaUnit_km2))) %>%
      # select(-DroughtArea_km2,-No_DroughtArea_km2)
      select(DroughtArea_p)
    # Rename the column with the filename containing the date
    names(drought_week)[names(drought_week)=="DroughtArea_p"]  <- substr(shp,1,(nchar(shp)-4))
    drought_week
  }
  
  return(cbind(drought_ts,drought_year))
} 


#### MAIN ####

### DOWNLOAD THE FILES ####

if (download_status | overwrite_status) {
  # Loop through the year of interest
  for (year in YEAR_START:YEAR_END){
    ## Getting all the shapefiles for a year into a list of 
    myshapefile_list <- yearlyimport(year,main_path,download_status,plotting_status)
    
    ## Plotting all the shapefiles
    if (plotting_status) {
      yearlyplots(myshapefile_list)
    }
  }
}
print("All the files have been downloaded and unzipped")


### COMPUTE THE DROUGHT LEVELS RELATIVE AREA TIME-SERIES####

## Load and Reproject the shapefile used to extract the drought information
admin_shp_prj <- reproject_shapefile_dir(admin_shp, NAD83_PROJ)

## Calculate area for the admin shapefiles in km2
admin_shp_prj@data$AreaUnit_km2 <- gArea(admin_shp_prj, byid = TRUE)/1e6

## Create the output directory
dir.create(output_directory, showWarnings = FALSE)

## Compute the percentage are under drought conditions
for (y in YEAR_START:YEAR_END) {
  # Directory containing the drought shapefiles for a particular year
  year_path <- file.path(main_path, y, 'SHP')
  
  # Compute the percentage area for the different drought classes
  yearly_drought = drought_area(admin_shp = admin_shp, drought_direc = year_path)
  
  # Write the output file
  filename <- paste0(output_directory,'/USAdrought', y, '.csv')
  write.csv(yearly_drought, file=filename,row.names =FALSE) 
}

print("Drought levels relative area have been computed for all years")


