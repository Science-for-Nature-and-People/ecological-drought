#############################################################################################################
### Routine to dowload,unzip,read and plot shapefiles from the US Drought Monitor website                 ###
### For the SNAP working Group Ecological Drought - https://www.nceas.ucsb.edu/projects/12703             ###  
###                                                                                                       ###
### Created on: Jan 19, 2016                                                                              ###
### Last updated: Jan 29, 2016                                                                            ###
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

## Drought Monitoring Website
URL = "http://droughtmonitor.unl.edu/data/shapefiles_m/"

## Filename
ZIPFILE_EXT = "_USDM_M.zip"


#### FUNCTIONS ####


#' Title
#'Loop through a list of Spatial Dataframe and plot it
#'
#' @param shapef_yearly_list A list of Spatial Dataframe
#' @examples 
yearlyplots <- function(shapef_yearly_list){
  ##loop to plot all the shapefiles of the year
  for (l in 1:length(shapef_yearly_list)){
    plot(shapef_yearly_list[[l]])
  }
}


#' Download, unzip, read ans store into a list the shapefiles for a specific year
#' 
#' @param my_year A number
#' @param shp_path A character
#' @param download_status A logical.
#' @param plotting_status A logical.
#' @return a list of shapeolygons for the year processed.
#' @examples
#' yearlyimport(2015, T, T)
#' yearlyimport(2016, T, F)
yearlyimport <- function(my_year, path_to_wd , download_status=T, plotting_status=T){
  #transform my year into a string
  my_year <- toString(my_year)
  
  #Full zip archive name to download
  zipfile_name = paste0(my_year,ZIPFILE_EXT)
  full_url = paste0(URL,zipfile_name)
  
  ## dowload the original zip file containing the weekly zip data
  if (download_status){
    download(full_url,dest = zipfile_name, mode = "wb")
  }
  
  ## unzip the original file, extracting the weekly data zip files
  unzip(zipfile_name, exdir = my_year, overwrite = overwrite_status)
  
  ## list the weekly data zip files for the year
  #Change working directory to year folder
  year_path <- file.path(path_to_wd,my_year)

  #list the files
  weekly_zip_list <- list.files(path=year_path, pattern = "*.zip")
  
  ## create a loop to extract the files to the directory set above
  ## will build the file name of the extracted file
  for (i in 1:length(weekly_zip_list)){
    unzip(file.path(year_path,weekly_zip_list[[i]]), exdir = paste0(year_path,"/SHP"), overwrite = overwrite_status)
    file.remove(file.path(year_path,weekly_zip_list[[i]]))
  }
  
  ## set up the folder where all the shapefiles were unziped
  shp_path <- paste(year_path,"SHP",sep = "/")
  
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




