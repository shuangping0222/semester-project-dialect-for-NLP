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
pts_sf <- st_as_sf(pts, coords = c("lon","lat"), crs = 4326)

ggplot() +
  geom_sf(data = poly, fill = NA) +
  geom_sf(data = pts_sf, aes(color = col), size = 3) +
  scale_color_identity() +
  theme_minimal()

#Cluster map (point-level)
hc <- hclust(dist_BTH, method = "ward.D2")

clusters <- cutree(hc, k = 3)#cut into 3 clusters
clusters

cluster_df <- data.frame(
  name = names(clusters),
  cluster = factor(clusters)
)

pts2 <- merge(points_df, cluster_df, by = "name", all.x = TRUE)

pts2_sf <- st_as_sf(pts2, coords = c("lon","lat"), crs = 4326)

ggplot() +
  geom_sf(data = poly, fill = NA) +
  geom_sf(data = pts2_sf, aes(color = cluster), size = 3) +
  theme_minimal()
