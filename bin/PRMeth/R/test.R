install.packages("matrixStats")
install.packages("quadprog")
library(matrixStats)
library(quadprog)
load("./data/Y_test.Rdata")
load("./data/W_test.Rdata")
load("./data/H_test.Rdata")
Y <- Y_test
W <- W_test

#select feature
feat <- select_feature(Y,1,500)
Y <- Y[feat,]
W1 <- W[feat,1:4]

#Determine the number of total cell types
optimalK <- getCellTypeNumber(Y,W1,10)
plot(5:10,optimalK$lambda_bic, col="red",xlab="Number of total cell types",
     ylab = "¦Ë_BIC",lwd = 1,type = 'b',main = "¦Ë_BIC")
abline(v = 7,lwd = 2,lty = 2,col = "gray")
optimalK$optimal_K
optimalK$lambda

#Predict the methylation profiles of cell types and the proportions of cell types
out <- prmeth(Y = Y, W1 = W1, K = optimalK$optimal_K, iters = 1000,rssDiffStop = 1e-10)
head(out$H)
dim(out$H)
dim(out$W)
head(out$W)

par(mar = c(3.5, 3, 1.6, 1.1), mgp = c(1.9, 0.5, 0),mfrow = c(1,2))
plot(t(H_test)[4,],out$H[4,],xlab = "True proportion",pch = 3,col="red",ylab = "Predicted proportion",main = "B cell")
plot(W[feat,5],out$W[,5],xlab = "True methylation profile",pch = 19,col="#00000050",ylab = "Predicted methylation profile",main = "NK cell")
