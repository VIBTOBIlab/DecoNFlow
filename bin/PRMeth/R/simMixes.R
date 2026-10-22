## simulation of tumor sample methylation profiles (Y) and cell type proportions (H) from cell type methylation profiles (W)
## pureCts: the methylation profiles of cell types
## methVarMatrix: the noise matrix, which column indicates cell types, row indicates sites
##                and each value indicates the noise level, with values ranging from (0,1].
##                For example, value = 0.4 indicates 40% of the maximum variance that
##                can be obtained by a beta variable with a given mean.
## propsVector: the percentage of each cell type. such as propsVector = c(60,30,10)
##              indicates that these three cell types accounte for 60%, 30% and 10% in the tumor tissue, respectively.
## nSamples: the number of tumor samples
## output: the simulated methylation profiles of tumor samples and the simulated proportions of cell types in each sample
simMixes <- function(pureCts,methVarMatrix,propsVector,nSamples){
  allNoisyMethProfs = list()
  for(j in 1:ncol(pureCts)){
    noisyMethProfs = matrix(0,nrow=nrow(pureCts),ncol=nSamples)
    for(i in 1:nrow(pureCts)){
      avg = pureCts[i,j]
      if(avg == 1){
        avg = 0.999999
      }
      if(avg == 0){
        avg = 0.000001
      }
      methVar = (avg*(1-avg))*methVarMatrix[i,j]
      a = avg*(((avg*(1-avg))/methVar)-1)
      b = (1-avg)*(((avg*(1-avg))/methVar)-1)
      noisyMethProfs[i,] = rbeta(nSamples,a,b)
    }
    allNoisyMethProfs[[j]] = noisyMethProfs
  }
  props = as.data.frame(rdirichlet(nSamples,propsVector))
  colnames(props) = colnames(pureCts)
  mixes = matrix(0,nrow=nrow(pureCts),ncol=nSamples)
  for(i in 1:nSamples){
    mix = rep(0,nrow(pureCts))
    for(j in 1:ncol(pureCts)){
      mix = mix + props[i,j]*allNoisyMethProfs[[j]][,i]
    }
    mixes[,i] = mix
  }
  result = list(mixes,props)
  names(result) = c("mixes","proportions")
  return(result)
}
