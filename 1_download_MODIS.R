library(RCurl)
library(foreach)
library(iterators)
library(stringr)

library(doParallel)
library(foreach)

start_date <- as.Date('2000/2/18')
end_date <- as.Date('2014/2/18')

output_path <- '/localdisk/home/azvoleff/MODIS_NPP'

MODIS_product_base_url <- 'ftp://ftp.ntsg.umt.edu/pub/MODIS/NTSG_Products/MOD17/MOD17A3'

desired_tiles <- read.csv('TEAM_Site_MODIS_Tiles.csv')
desired_tile_strings <- paste0('h', sprintf('%02i', desired_tiles$h),
                               'v', sprintf('%02i', desired_tiles$v))
desired_tile_strings <- unique(desired_tile_strings)

# Calculate dates for all desired MODIS tiles
year_strings <- paste0('Y', seq(2000, 2013))

# Calculate base URLs for these dates
base_urls <- paste0(MODIS_product_base_url, '/', year_strings, '/')

foreach (base_url=iter(base_urls)) %do%  {
    file_list <- getURL(base_url, dirlistonly=TRUE) 
    file_list <- strsplit(file_list, "\r*\n")[[1]]
    tile_hv <- str_extract(file_list, 'h[0-9]{2}v[0-9]{2}')

    modis_filenames <- file_list[tile_hv %in% desired_tile_strings]
    if (length(modis_filenames) != length(desired_tile_strings)) {
        warning(length(modis_filenames), ' downloads found for ', 
                length(desired_tile_strings), ' desired tiles')
    }

    foreach (modis_filename=iter(modis_filenames), .inorder=FALSE) %do% {
        local_file <- file.path(output_path, modis_filename)
        if (file_test('-f', local_file)) {
            return()
        }
        remote_file <- paste0(base_url, modis_filename)
        ret_code <- download.file(remote_file, local_file, mode="w", quiet=TRUE)
    }

}


