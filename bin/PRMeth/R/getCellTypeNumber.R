getCellTypeNumber <- function(Y,W1,maxK){
  cat("Running lambda_bic...\n")
  minbic = 1
  lambda_bic = c()
  i = 1
  for(lambda in c(0.4)){
    row = c()
    for(K in c((ncol(W1)+1):maxK)){
      PRMethout <- prmeth(Y = Y,W1 = W1,K = K,iters = 1000,rssDiffStop=1e-10,lambda = lambda)
      if(PRMethout$bic < minbic){
        minbic = PRMethout$bic
        minbic_index = i
        optimal_lambda = lambda
        optimal_K = K
      }
      row = cbind(row,PRMethout$bic)
    }
    lambda_bic = rbind(lambda_bic,row)
    i = i + 1
  }
  result = list(lambda_bic=lambda_bic[minbic_index,],optimal_K = optimal_K,lambda = optimal_lambda )
  names(result) = c("lambda_bic","optimal_K","lambda")
  return(result)
}
