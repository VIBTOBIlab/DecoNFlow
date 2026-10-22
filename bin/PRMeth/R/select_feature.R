## feature selection
## mat: the methylation profiles of tumor samples
## startn: the starting position for feature selection
## nmarker: the endpoint position for feature selection
## output: the top n CPG sites with the highest cv values
select_feature <- function(mat, startn = 1, nmarker = 1000) {
  mm = rowMeans(mat)
  vv = rowVars(mat)
  cv = sqrt(vv) / (mm + 1)
  cv[is.na(cv)] = 0
  ix = sort(cv, dec = TRUE, index = TRUE)$ix
  index.select = rownames(mat)[ix[startn:nmarker]]
  return(index.select)
}
