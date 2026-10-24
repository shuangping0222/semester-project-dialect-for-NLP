library(dialectR)
library(sf)
library(ggplot2)

#read files from preprocessed and merged csv
df <- read.csv("all_vari_matrix.csv", row.names = 1, check.names = FALSE)

#from dialectR, count the distance and get the mean, not the sum
dist_all <- dialectR::distance_matrix(df, "leven", alignment_normalization = TRUE)

n_sites <- nrow(df)
shared <- outer(
  1:n_sites, 1:n_sites,
  Vectorize(function(i, j) sum(!is.na(df[i, ]) & !is.na(df[j, ])))
)

dist_mean <- dist_all * n_sites / shared
diag(dist_mean) <- 0

# print to see if we got correct matrix
# range(dist_mean, na.rm = TRUE)
# dist_mean[1:3, 1:3]

dist_BTH <- as.dist(as.matrix(dist_mean))

# save for reuse
# write.csv(dist_mean, "dist_BTH.csv")

#######draw the map#########

#read kml data, 'BTH_sites' just have data for all sites
k <- st_read("BTH_sites.kml", quiet = TRUE)
xy <- st_coordinates(k)

points_df <- data.frame(
  name = k$Name,
  lon  = xy[,1],
  lat  = xy[,2],
  stringsAsFactors = FALSE
)

# print to check
# head(points_df)

#read to draw the admin line for Beijing, Hebei and Tianjin
poly <- st_read("BTH_admin.kml", quiet = TRUE)

#dist_mat <- read.csv("dist_BTH.csv",row.names = 1, check.names = FALSE)
#dist_mat <- as.matrix(dist_mat)
#storage.mode(dist_mat) <- "double"
#dist_BTH <- as.dist(dist_mat)

d <- if (inherits(dist_BTH, "dist")) dist_BTH else as.dist(dist_BTH)

# MDS map (RGB)
mds <- cmdscale(d, k = 3)
if (is.null(rownames(mds))) rownames(mds) <- attr(d, "Labels")

scale01 <- function(x) (x - min(x)) / (max(x) - min(x) + 1e-9)
cols <- rgb(scale01(mds[,1]), scale01(mds[,2]), scale01(mds[,3]))

mds_df <- data.frame(name = rownames(mds), col = cols, stringsAsFactors = FALSE)

pts <- merge(points_df, mds_df, by = "name", all.x = TRUE)

pts_ll <- st_as_sf(points_df, coords = c("lon","lat"), crs = 4326)

pts_m  <- st_transform(pts_ll, 3857)

poly_m <- st_transform(poly, 3857)
boundary <- st_union(poly_m)

head(points_df$name)
head(rownames(dist_BTH))

v <- st_voronoi(st_union(pts_m), envelope = st_as_sfc(st_bbox(boundary)))
v_sf <- st_collection_extract(st_as_sf(v), "POLYGON")

v_sf$name <- points_df$name

v_clip <- st_intersection(v_sf, boundary)

v_mds <- merge(v_clip, mds_df, by = "name", all.x = TRUE)

ggplot() +
  geom_sf(data = poly, fill = NA) +             
  geom_sf(data = st_transform(v_mds, 4326),      
          aes(fill = col), color = NA) +
  scale_fill_identity() +
  geom_sf(data = pts_ll, size = 0.8) +   
  theme_minimal()


hc <- hclust(dist_BTH, method = "ward.D2")

clusters <- cutree(hc, k = 3)#cut into 3 clusters
clusters

cluster_df <- data.frame(
  name = names(clusters),
  cluster = factor(clusters)
)

pts2 <- merge(points_df, cluster_df, by = "name", all.x = TRUE)

pts2_sf <- st_as_sf(pts2, coords = c("lon","lat"), crs = 4326)

v_clu <- merge(v_clip, cluster_df, by = "name", all.x = TRUE)

ggplot() +
  geom_sf(data = poly, fill = NA) +
  geom_sf(data = st_transform(v_clu, 4326),
          aes(fill = cluster), color = NA) +
  theme_minimal()

