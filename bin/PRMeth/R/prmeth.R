
## partial reference-based
## Y: the methylation profiles of tumor samples
## W1: the methylation profiles of partial reference cell types
## K: the number of cell types
## iters: the number of iterations
## rssDiffStop: the convergence state
## lambda: the penalty factor of BIC
## output: the methylation profiles of cell types and the proportions of cell types in each input sample
prmeth <- function(Y,W1,K,iters = 500,rssDiffStop=1e-10,lambda = 1){
  if (is.null(W1)){
    ### ref-free
    print("This is ref-free case")
    out.RF = rf(Y, K = K, iters = iters)
    W.pred = out.RF$W
    H.pred = out.RF$H
    out = list(W=W.pred, H = H.pred)
    return(out)
  } else {
    if (ncol(W1) == K){
      #### ref-based
      print("This is ref-based case")
      return(qp(Y,W1))
    } else if (ncol(W1) < K){
      ### partial ref
      mu02 <- RefFreeCellMixInitialize(Y,K=K-ncol(W1),dist.method = "binary")
      mu02 <- as.matrix(mu02)
      mu0 <-cbind(as.matrix(W1),mu02)
      rss0 = 0

      for(i in 1:iters){
        flag <- !apply(is.na(mu0),1,any)
        omega <- QPfunction(Y[flag,],mu0[flag,], sumLessThanOne=TRUE)
        omega1 <- omega[,1:ncol(W1)]
        omega2 <- omega[,(ncol(W1)+1):ncol(mu0)]
        ##calculate W2
        mu1 <- QPfunction(t(Y-W1%*%t(omega1)), omega2, sumLessThanOne=FALSE)
        mu = cbind(W1,mu1)
        rss.new = norm(Y - mu%*%t(omega),"F")^2
        ## check convergence
        dd = abs(rss.new-rss0)
        if(dd < rssDiffStop)
          break

        ## updata
        mu0 = cbind(W1,mu1); rss0 = rss.new
      }

      W.pred = mu
      H.pred = t(omega)

      # lambda_BIC
      rss = norm(Y - W.pred %*% H.pred,type = "F")^2
      nSamples = ncol(Y)*nrow(Y) ### sample size * number of CpG
      nParam = K*(nrow(Y)+ncol(Y)) - nrow(W1)*ncol(W1) ### total number of parameters
      bic = nSamples*log(rss/nSamples)+ log(nSamples)*nParam*lambda

      out = list(W=W.pred, H = H.pred, bic = bic)
      return(out)
    } else {
      stop("ncol(W1) should be less than or equal to ncol(W)!")
    }
  }
}


## reference-based
## Y: the methylation profiles of tumor samples
## W: the methylation profiles of cell types
## output: the proportions of constituent cell types in each input sample
qp <- function(Y,W){
  H.pred = t(QPfunction(Y = Y, Xmat = W, sumLessThanOne=TRUE))
  return(list(H = H.pred))
}

## reference-free
## Y: the methylation profiles of tumor samples
## K: the number of cell types
## iters: the number of iterations
## rssDiffStop: convergence state
## output: the methylation profiles of cell types and the proportions of cell types in each input sample
rf <- function(Y,K,iters = 500,rssDiffStop=1e-10){
  mu0 <- RefFreeCellMixInitialize(Y,K=K,dist.method = "binary") ## initial profiles of cell types
  mu0 <- matrix(mu0,ncol = K)
  rss0 = 0
  for(i in 1:iters){
    flag <- !apply(is.na(mu0),1,any)
    omega <- QPfunction(Y[flag,],mu0[flag,],sumLessThanOne=TRUE)
    mu <- QPfunction(t(Y), omega, sumLessThanOne=FALSE)
    rss.new = norm(Y - mu%*%t(omega),"F")^2
    ## check convergence
    dd = abs(rss.new-rss0)
    if(dd < rssDiffStop)
      break

    ## updata
    mu0 = mu; rss0 = rss.new
  }

  W.pred = mu
  H.pred = t(omega)

  # AIC
  rss = norm(Y - W.pred %*% H.pred,type = "F")^2
  nSamples = ncol(Y)*nrow(Y) ### sample size * number of CpG
  nParam = K*(nrow(Y)+ncol(Y)) ### total number of parameters
  aic = nSamples*log(rss/nSamples)+ 2*nParam + (2*nParam*(nParam+1))/(nSamples-nParam-1)

  out = list(W=W.pred, H = H.pred, aic = aic)
  return(out)
}


## quadratic programming
## Y: the methylation profiles of tumor samples
## Xmat: When sumLessThanOne is TRUE, it is the methylation profiles of cell types.
##       When sumLessThanOne is FALSE, it is the proportion matrix of cell types
## sumLessThanOne: the value is TRUE, for calculating the proportion matrix of cell types or calculating the methylation profiles of cell types
## output: the methylation profiles of cell types or the proportions of cell types in each input sample
QPfunction <- function(Y, Xmat, sumLessThanOne=TRUE){
  Xmat = as.matrix(Xmat)
  nCol = dim(Xmat)[2]   # the number of cell types
  nSubj = dim(Y)[2]     # sample size
  mixCoef = matrix(0, nSubj, nCol) ## the proportion of cell types in each samples
  rownames(mixCoef) = colnames(Y)
  colnames(mixCoef) = colnames(Xmat)

  # calculate H matrix from W
  if(sumLessThanOne){
    Amat = cbind(rep(-1,nCol), diag(nCol))
    b0vec = c(-1,rep(0,nCol))

    for(i in 1:nSubj){
      obs = which(!is.na(Y[,i]))
      Dmat = t(Xmat[obs,]) %*% Xmat[obs,]
      dvec = t(Xmat[obs,])%*%Y[obs,i]
      meq = 1
      mixCoef[i,] = solve.QP(Dmat=Dmat, dvec=dvec, Amat=Amat, bvec=b0vec, meq=meq)$sol
    }
  }


  # calculate W matrix from H
  else{
    Amat = cbind(-diag(nCol), diag(nCol))
    b0vec = c(rep(-1, nCol), rep(0, nCol))

    for(i in 1:nSubj){
      obs = which(!is.na(Y[,i]))
      Dmat = t(Xmat[obs,])%*%Xmat[obs,]
      mixCoef[i,] = solve.QP(Dmat, t(Xmat[obs,])%*%Y[obs,i], Amat, b0vec)$sol
    }
  }

  return(mixCoef)
}

## Initialization of the reference matrix (W2)
## Y: the methylation profiles of tumor samples
## K: the number of clusters
## dist.method: the distance formula
## output: the initialized methylation profiles (W2) of cell types
RefFreeCellMixInitialize <- function(Y,K=2,dist.method = "binary", ...){

  if(!is.matrix(Y) | !is.numeric(Y)){
    stop("Y is not a numeric matrix\n")
  }
  n <- dim(Y)[2]
  if(n < K){
    stop("Can't initialize because K is too big\n")
  }

  Y.Distance <- dist(t(Y), method = dist.method)
  Y.Cluster <- hclust(Y.Distance, ...)

  classes <- cutree(Y.Cluster, K)
  s <- split(1:n,classes)
  W0 = sapply(s, function(u) apply(Y[,u,drop=FALSE],1,mean,na.rm=TRUE))
  return(W0)
}
