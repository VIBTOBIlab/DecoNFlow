# Introduction
we proposed PRMeth, a method to deconvolve tumor mixtures using partially available DNA methylation data. By adopting an iteratively optimized non-negative matrix factorization framework, PRMeth took DNA methylation profiles of a portion of the cell types in the tissue mixtures (including blood and solid tumors) as input to estimate the proportions of all cell types as well as the methylation profiles of unknown cell types simultaneously.
# How to use?
First, you download this file locally from GitHub and load function codes in the *R* folder using Rstudio.
## Installing and loading these packages
```
    install.packages("matrixStats")
    install.packages("quadprog")
    library(matrixStats)
    library(quadprog)
```
## Loading datasets
We provided test datasets in the *data* folder, including the methylation profiles (Y_test) of tumor samples, the complete methylation profiles (W_test) of cell types and the proportions (H_test) of cell types constituting tumor samples. Y_test and W_test consisted of 100 tumor samples and 7 cell types, respectively.
```
    load("./data/Y_test.Rdata")
    load("./data/W_test.Rdata")
    load("./data/H_test.Rdata")
    Y <- Y_test
    W <- W_test
```
```
    head(W)
```
```
              CD4T      CD8T    Monocyte     B        NK      Neutrophil  Treg
cg10472651 0.5374553 0.5883594 0.1463455 0.6720863 0.6278311  0.1805606 0.5394341
cg27603015 0.7836380 0.7521135 0.3381076 0.8084323 0.7398579  0.3680155 0.6986226
cg14363249 0.7986152 0.7797788 0.1880759 0.6773750 0.6769277  0.1888117 0.5542615
cg12866960 0.8957482 0.8925703 0.1085343 0.8494344 0.8423281  0.1688397 0.7668559
cg18145759 0.7492490 0.6895485 0.2148763 0.5918013 0.6318281  0.2438058 0.6496115
cg23907051 0.8228125 0.7787870 0.4310057 0.7115869 0.7640459  0.3346429 0.7208708
```
## selecting CpG sites by the coefficient of variation (cv)
```
    feat <- select_feature(Y,1,500)
    Y <- Y[feat,]
    W1 <- W[feat,1:4]
```
## Determining the total number of cell types by λ_BIC
```
    optimalK <- getCellTypeNumber(Y,W1,10)
    plot(5:10,optimalK$lambda_bic, col="red",xlab="Number of total cell types", ylab = "λ_BIC",lwd = 1,type = 'b',main = "λ_BIC")
    abline(v = 7,lwd = 2,lty = 2,col = "gray")
```

![](https://github.com/hedingqin/PRMeth/blob/main/PRMeth/picture/optimalK.png)


```
    optimalK$optimal_K
    optimalK$lambda
```
```
    7
    0.4
```
The total number of cell types predicted by λ_BIC is 7 and λ is 0.4.
## Predicting the methylation profiles of unknown cell types and the proportions of all cell types by PRMeth
```
    out <- prmeth(Y = Y, W1 = W1, K = optimalK$optimal_K, iters = 1000,rssDiffStop = 1e-10)
```
### the proprotions of cell types
```
    dim(out$H)
```
```
    7 100
```

```
    head(out$H)
```
```
              1           2         3            4          5           6            7           8           9
CD4T     0.042782379 0.10865976 4.829844e-02 0.06766981 0.15274959 0.233641090  1.618703e-01 0.08376015 0.003901435
CD8T     0.058984475 0.07912329 5.170341e-02 0.10405994 0.02883215 0.008123475 -4.588630e-18 0.05907123 0.063267991
Monocyte 0.079674776 0.04947467 4.414308e-02 0.03289314 0.06399982 0.031482986  4.334223e-02 0.01260674 0.070872375
B        0.131101628 0.07164629 1.179793e-01 0.08927853 0.05397268 0.048493496  1.026495e-01 0.13717593 0.153992814
1        0.295629585 0.23732800 4.257464e-01 0.41374931 0.32125833 0.336699655  4.352929e-01 0.22832301 0.464753344
2        0.003787403 0.29452830 4.336809e-19 0.15855196 0.06812948 0.197736993  6.182408e-02 0.26491330 0.122080176
3        0.388039754 0.15923969 3.121293e-01 0.13379731 0.31105795 0.143822306  1.950210e-01 0.21414964 0.121131864
```
The output proportion matrix is the proportions of seven cell types for 100 samples. The first four rows show the proportions of known cell types, and the last three rows show the proportions of unknown cell types, which correspond to the cell types in the last three columns of W_test.

### the methylation profiles of cell types
```
     dim(out$W)
```
```
    500 7
```

```
     head(out$W)
```
```
               CD4T       CD8T     Monocyte      B          1           2           3
cg10387901 0.04336633 0.06419386 0.08911975 0.06803460 0.06761788 0.318490097 0.083285236
cg07664454 0.08682211 0.14104607 0.07349678 0.06954840 0.06975795 0.460982998 0.036158475
cg15994159 0.03550551 0.05349418 0.06438595 0.05293503 0.08400472 0.009074232 0.040681462
cg14612335 0.29490087 0.24312586 0.04897303 0.00100000 0.18691576 0.477418630 0.008551141
cg10041635 0.16065378 0.26070067 0.03489730 0.13847923 0.66076349 0.674242382 0.544970534
cg04776231 0.83981779 0.81227954 0.08091221 0.11784140 0.40999733 0.644811322 0.197640073
```
This methylation profiles of cell types are the methylation levels of 7 cell types at 500 sites.
### Comparison of predicted and true values
```
    par(mar = c(3.5, 3, 1.6, 1.1), mgp = c(1.9, 0.5, 0),mfrow = c(1,2))
    plot(t(H_test)[4,],out$H[4,],xlab = "True proportion",pch = 3,col="red",ylab = "Predicted proportion",main = "B cell")
    plot(W[feat,5],out$W[,5],xlab = "True methylation profile",pch = 19,col="#00000050",ylab = "Predicted methylation profile",main = "NK cell")
```

![](https://github.com/hedingqin/PRMeth/blob/main/PRMeth/picture/scatterPlot.png)
