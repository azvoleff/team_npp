library(foreach)
library(iterators)
library(stringr)
library(rgeos)

source("notify.R")

library(doParallel)
registerDoParallel(15)

zoi_folder <- '/localdisk/home/azvoleff/ZOI_CSA_PAs'
in_base_dir <- '/localdisk/home/azvoleff/MODIS_NPP'
out_base_dir <- '/localdisk/home/azvoleff/MODIS_NPP'
in_folder <- file.path(in_base_dir, 'ZOI_Crops')
out_folder <- file.path(in_base_dir, 'ZOI_Crops')

tile_key <- read.csv('TEAM_Site_MODIS_Tiles.csv')
sitecodes <- unique(tile_key$sitecode)

npp <- foreach (sitecode=iter(sitecodes),
                .packages=c('rgdal', 'rgeos', 'raster'),
                .combine=rbind, .inorder=FALSE) %dopar% {
    aoi_file <- dir(zoi_folder, pattern=paste0('^', sitecode), full.names=TRUE)
    stopifnot(length(aoi_file) == 1)
    load(aoi_file) # loads into "aois"
    
    npp_files <- dir(in_folder, pattern=paste0('^MOD17A3_', sitecode,
                                               '_[0-9]*_Npp_1km.tif'), 
                      full.names=TRUE)
    qc_files <- dir(in_folder, pattern=paste0('^MOD17A3_', sitecode,
                                              '_[0-9]*_Gpp_Npp_QC_1km.tif'), 
                      full.names=TRUE)
    
    site_npp <- foreach (aoi_label=iter(unique(aois@data$label)),
                        .combine=rbind, .inorder=FALSE)  %:% 
        foreach (npp_file=iter(npp_files), qc_file=iter(qc_files),
                 .packages=c('rgdal', 'rgeos', 'raster'),
                 .combine=rbind, .inorder=FALSE) %do% {
            npp_image <- stack(npp_file)
            npp_image[npp_image > 65500] <- NA
            npp_image[npp_image < 0] <- NA
            # Convert NPP into units of kg_C/m^2
            npp_image <- npp_image * .0001
            
            # qc_file gives percentage of 8-day input values that were infilled
            # due to cloud cover or other conditions
            qc_image <- raster(qc_file)
            qc_image[qc_image > 100] <- NA
            qc_image[qc_image < 0] <- NA
            
            this_aoi <- aois[which(aois@data$label == aoi_label), ]
            this_aoi <- spTransform(this_aoi, CRS(proj4string(npp_image)))
            this_aoi <- gUnaryUnion(this_aoi)
            
            qc_mean <- extract(qc_image, this_aoi, fun='mean', na.rm=TRUE)
            qc_sd <- extract(qc_image, this_aoi, fun='sd', na.rm=TRUE)
            qc_min <- extract(qc_image, this_aoi, fun='min', na.rm=TRUE)
            qc_max <- extract(qc_image, this_aoi, fun='max', na.rm=TRUE)
            
            npp_mean <- extract(npp_image, this_aoi, fun='mean', na.rm=TRUE)
            npp_sd <- extract(npp_image, this_aoi, fun='sd', na.rm=TRUE)
            npp_min <- extract(npp_image, this_aoi, fun='min', na.rm=TRUE)
            npp_max <- extract(npp_image, this_aoi, fun='max', na.rm=TRUE)
            
            npp_n_vals <- extract(!is.na(npp_image), this_aoi, fun='sum')
            npp_n_nas <- extract(is.na(npp_image), this_aoi, fun='sum')
            npp_n_pix <- npp_n_vals + npp_n_nas
            
            qc_n_vals <- extract(!is.na(qc_image), this_aoi, fun='sum')
            qc_n_nas <- extract(is.na(qc_image), this_aoi, fun='sum')
            qc_n_pix <- qc_n_vals + qc_n_nas
            
            this_date <- as.Date(str_extract(npp_file, '[0-9]{7}'), '%Y%j')
            
            return(data.frame(sitecode=sitecode, area=aoi_label, date=this_date,
                              npp_mean=npp_mean, npp_min=npp_min, 
                              npp_max=npp_max, npp_sd=npp_sd,
                              npp_nvals=npp_n_vals, npp_n_nas=npp_n_nas,
                              npp_n_pix=npp_n_pix,
                              qc_mean=qc_mean, qc_min=qc_min, 
                              qc_max=qc_max, qc_sd=qc_sd,
                              qc_nvals=qc_n_vals, qc_n_nas=qc_n_nas,
                              qc_n_pix=qc_n_pix))
        }
    return(site_npp)
}

npp <- npp[order(npp$sitecode, npp$area, npp$date), ]

save(npp, file='npp.RData')
write.csv(npp, file='npp.csv', row.names=FALSE)

notify("NPP calculation complete.")