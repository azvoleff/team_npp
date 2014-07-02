
zoi_folder <- '/localdisk/home/azvoleff/ZOI_CSA_PAs'
in_base_dir <- '/localdisk/home/azvoleff/MODIS_NPP'
out_base_dir <- '/localdisk/home/azvoleff/MODIS_NPP'
in_folder <- file.path(in_base_dir, 'ZOI_Crops')
out_folder <- file.path(in_base_dir, 'ZOI_Crops')

tile_key <- read.csv('TEAM_Site_MODIS_Tiles.csv')
sitecodes <- unique(tile_key$sitecode)

npp_stats <- foreach (sitecode=iter(tile_key$sitecode),
                      .packages=c('rgdal', 'rgeos', 'raster'),
                      .inorder=FALSE, .combine=rbind, .inorder=FALSE) %dopar% {
    aoi_file <- dir(zoi_folder, pattern=paste0('^', sitecode), full.names=TRUE)
    stopifnot(length(aoi_file) == 1)
    load(aoi_file) # loads into "aois"

    data_files <- dir(in_folder, pattern=paste0('^MOD17A3_', sitecode), 
                      full.names=TRUE)
    site_npps <- foreach (aoi_label=iter(unique(aois@data$label)),
             .packages=c('rgdal', 'rgeos', 'raster'), .combine=rbind, 
             .inorder=FALSE) %:% 
        foreach (data_file=iter(data_files),
                 .packages=c('rgdal', 'rgeos', 'raster'), .combine=rbind, 
                 .inorder=FALSE) %do% {
            this_aoi <- aois[which(aois@data$label == aoi_label), ]
            this_date <- as.Date(str_extract(data_file, '[0-9]{7}'), '%Y%j')
            npp_image <- raster(data_file)
            npp_mean <- extract(npp_image, this_aoi, fun='mean', na.rm=TRUE)
            npp_sd <- extract(npp_image, this_aoi, fun='sd', na.rm=TRUE)
            npp_min <- extract(npp_image, this_aoi, fun='min', na.rm=TRUE)
            npp_max <- extract(npp_image, this_aoi, fun='max', na.rm=TRUE)
            return(data.frame(sitecode=sitecode, date=this_date, 
                              npp_mean=npp_mean, npp_min=npp_min, 
                              npp_max=npp_max, npp_sd=npp_sd))
        }
    return(site_npps)
}
