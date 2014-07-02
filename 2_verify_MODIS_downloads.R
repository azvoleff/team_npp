library(stringr)
library(plyr)

in_path <- '/localdisk/home/azvoleff/MODIS_NPP'
start_date <- as.Date('2000/2/18')
end_date <- as.Date('2014/2/18')

desired_tiles <- read.csv('TEAM_Site_MODIS_Tiles.csv')
desired_tile_strings <- paste0('h', sprintf('%02i', desired_tiles$h),
                               'v', sprintf('%02i', desired_tiles$v))
desired_tile_strings <- unique(desired_tile_strings)

hdf_files <- dir(in_path, 
                 pattern='^MOD17A3.A[0-9]{7}.h[0-9]{2}v[0-9]{2}.[0-9]{3}.[0-9]{13}.hdf$')
hdf_files <- hdf_files[!is.na(hdf_files)]
tile_hv <- str_extract(hdf_files, 'h[0-9]{2}v[0-9]{2}')
file_dates <- gsub('[A.]', '', str_extract(hdf_files, '.A[0-9]{7}.'))
file_dates <- as.Date(file_dates, '%Y%j')

files <- data.frame(name=hdf_files, date=file_dates, tile=tile_hv)

table(tile_hv)