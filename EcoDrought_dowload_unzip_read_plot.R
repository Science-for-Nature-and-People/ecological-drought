#############################################################################################################
### Routine to dowload,unzip,read and plot shapefiles from the US Drought Monitor website                 ###
### For the SNAP working Group Ecological Drought - https://www.nceas.ucsb.edu/projects/12703             ###  
###                                                                                                       ###
### Created on: Jan 19, 2015                                                                              ###
### Last updated: Jan 29, 2015                                                                            ###
### Author: Gabriel Antunes Daldegan (gdaldegan@nceas.ucsb.edu)                                           ###
### Contact: scicomp@nceas.ucsb.edu                                                                       ###
#############################################################################################################

# Clear all
#rm(list=ls(all=TRUE))

library(downloader) # Package to download files over http and https
library(sp) # package that defines a set of spatial classes that are the stantard spatial data types in R
library(rgdal) # package that provides a inteface to the GDAL/OGR library, powering the data import/export capabilities
# of many geospatially aware software applications.
#library(maptools)# tools for reading and writing spatial data (visualisation)
#library(maps)# Display of maps


#### CONSTANTS ####

## set the working directory where the data are
#setwd("/Users/daldegan/GeoDatabase/EcologicalDrought/2015/") 
path_to_wd <- "/Users/brun/redmine_git/snap_interns/EcologicalDrought"   # <- to be changed

## Website
URL = "http://droughtmonitor.unl.edu/data/shapefiles_m/"

## Years to download
YEAR_START = 2000
YEAR_END = 2016
year_vect = YEAR_START:YEAR_END


## Filename
ZIPFILE_EXT = "_USDM_M.zip"

## Processing options
# If you want to download the file, set it to TRUE
download_status = TRUE
# If you want to overwite the file when unzipping, set it to TRUE
overwrite_status = TRUE
# If you want to plot the shapefile, set it to TRUE
plotting_status = TRUE




#### FUNCTIONS ####

yearlyplots <- function(shapef_yearly_list){
  ##loop to plot all the shapefiles of the year
  for (l in 1:length(shapef_yearly_list)){
    plot(shapef_yearly_list[[l]])
  }
}

yearlyimport <- function(my_year, download_status=T, plotting_status=T){
  #transform my year into a string
  my_year <- toString(my_year)
  
  # Set the upper level working directory
  setwd(path_to_wd) 
  
  #Full zip archive name to download
  zipfile_name = paste0(my_year,ZIPFILE_EXT)
  full_url = paste0(URL,zipfile_name)
  
  ## dowload the original zip file containing the weekly zip data
  if (download_status){
    download(full_url,dest = zipfile_name, mode = "wb")
  }
  
  ## unzip the original file, extracting the weekly data zip files
  Data2015 <- unzip(zipfile_name, exdir = my_year, overwrite = overwrite_status)
  
  ## list the weekly data zip files for the year
  #Change working directory to year folder
  year_path <- paste(path_to_wd,my_year,sep = "/")
  setwd(year_path)
  #list the files
  weekly_zip_list <- list.files(pattern = "*.zip")
  
  ## create a loop to extract the files to the directory set above
  ## will build the file name of the extracted file
  for (i in 1:length(weekly_zip_list)){
    unzip(weekly_zip_list[[i]], exdir = "SHP", overwrite = overwrite_status)
  }
  
  ## set up the folder where all the shapefiles were unziped
  shp_path <- paste(year_path,"SHP",sep = "/")
  setwd(shp_path)
  
  ## create a list containing the name of all shapefiles
  shapefilename_list <- ogrListLayers(shp_path)
  
  ## create an empty list which size is equal to the shapefile list. It will be used on next loop 
  shapef_list <- vector("list",length(shapefilename_list))
  
  ## loop to read all the shapefiles and store it in a list
  for (k in 1:length(shapefilename_list)) {
    shapef_list[[k]] <- readOGR(shp_path,layer = shapefilename_list[[k]])
  }
  return(shapef_list)
}


#### MAIN ####
#Loop through the year of interest
for (year in year_vect){
  print(year)
  ## Getting all the shapefiles for a year into a list of 
  myshapefile_list <- yearlyimport(year,download_status,plotting_status)
  
  ## Plotting all the shapefiles
  if (plotting_status) {
    yearlyplots(myshapefile_list)
  }
  #Summary info
  summary(myshapefile_list[[1]])
}


