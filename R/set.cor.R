"set.cor" <-
function(y,x,data,z=NULL,n.obs=NULL,use="pairwise",std=TRUE,square=FALSE,main="Regression Models",plot=TRUE,show=FALSE,zero=TRUE)  {
setCor(y=y,x=x,data=data,z=z,n.obs=n.obs,use=use,std=std,square=square,main=main,plot=plot,show=show)}


"setCor" <-
function(y,x,data,z=NULL,n.obs=NULL,use="pairwise",std=TRUE,square=FALSE,main="Regression Models",plot=TRUE,show=FALSE,zero=TRUE,alpha=.05)  {

 #a function to extract subsets of variables (a and b) from a correlation matrix m or data set m
  #and find the multiple correlation beta weights + R2 of the a set predicting the b set
  #seriously rewritten, March 24, 2009 to make much simpler
  #minor additons, October, 20, 2009 to allow for print and summary function
  #major addition in April, 2011 to allow for set correlation
  #added calculation of residual matrix December 30, 2011
  #added option to allow square data matrices
  #modified December, 2014  to allow for covariances as well as to fix a bug with single x variable
  #modified April, 2015 to handle data with non-numeric values in the data, which are not part of the analysis
  #Modified November, 2107 to handle "lm" style input using my parse function.
  #modified July 4, 2018 to add intercepts and confidence intervals (requested by Franz Strich)
  
   cl <- match.call()
    #convert names to locations 
    prod <- ex <-  NULL   #in case we do not have formula input
   #first, see if they are in formula mode  
   if(class(y) == "formula") {
   ps <- fparse(y)
   y <- ps$y
   x <- ps$x
   med <- ps$m #but, mediation is not done here, so we just add this to x
  # if(!is.null(med)) x <- c(x,med)   #not  necessary, because we automatically put this in
   prod <- ps$prod
   z <- ps$z   #do we have any variable to partial out
   ex <- ps$ex
}
           #  data <- char2numeric(data)   #move to later (01/05/19)
        
    if(is.numeric(y )) y <- colnames(data)[y]
    if(is.numeric(x )) x <- colnames(data)[x]
    if(is.numeric(z )) z <- colnames(data)[z]
  

#check for bad input
if(any( !(c(y,x,z,ex) %in% colnames(data)) )) {
 print(c(y, x, z, ex)[which(!(c(y, x, z, ex) %in% colnames(data)))])
 stop("Variable names are incorrect")}
 
 
  if(!isCorrelation(data))  {

 
                  data <- data[,c(y,x,z,ex)] 
                   data <- char2numeric(data)              
                   if(!is.matrix(data)) data <- as.matrix(data)  
                   if(!is.numeric(data)) stop("The data must be numeric to proceed")
                   if(!is.null(prod) | (!is.null(ex))) {#we want to find a product term
                  if(zero) data <- scale(data,scale=FALSE)
                  if(!is.null(prod)) {
                 
                     prods <- matrix(NA,ncol=length(prod),nrow=nrow(data))
                     colnames(prods) <- prod
                     colnames(prods) <- paste0("V",1:length(prod))
                     for(i in 1:length(prod)) {
                       prods[,i] <- apply(data[,prod[[i]]],1,prod) 
                       colnames(prods)[i] <- paste0(prod[[i]],collapse="*")
                       }
                      
                      data <- cbind(data,prods)
                      x <- c(x,colnames(prods))
                    }
                    
                    if(!is.null(ex)) {
                 
                    quads <- matrix(NA,ncol=length(ex),nrow=nrow(data))  #find the quadratric terms
                    colnames(quads) <- paste0(ex)
                     for(i in 1:length(ex)) {
                      quads[,i] <- data[,ex[i]] * data[,ex[i]]
                      colnames(quads)[i] <- paste0(ex[i],"^2")
                     }
                     data <- cbind(data,quads)
                     x <- c(x,colnames(quads))
                    }

                    }
                    means <- colMeans(data,na.rm=TRUE)   #use these later to find the intercept
                    C <- cov(data,use=use)
                    if(std) {m <- cov2cor(C)
                             C <- m} else {m <- C}
                    raw <- TRUE
                   # n.obs=dim(data)[1]   #this does not take into account missing data
                    n.obs <- max(pairwiseCount(data),na.rm=TRUE )  #this does
                    }  else {
                    raw <- FALSE
                    if(!is.matrix(data)) data <- as.matrix(data)  
                    C <- data
                    if(std) {m <- cov2cor(C)} else {m <- C}}
    #We do all the calculations on the Covariance or correlation matrix (m)
   #convert names to locations                 

        nm <- dim(data)[1]
        xy <- c(x,y)
        numx <- length(x)
     	numy <- length(y)
     	numz <- 0
        nxy <- numx+numy
        m.matrix <- m[c(x,y),c(x,y)]
     	x.matrix <- m[x,x,drop=FALSE]
     	xc.matrix <- m[x,x,drop=FALSE]  #fixed19/03/15
     	xy.matrix <- m[x,y,drop=FALSE]
     	xyc.matrix <- m[x,y,drop=FALSE]  #fixed 19/03/15
     	y.matrix <- m[y,y,drop=FALSE]
     	

        	
     	if(!is.null(z)){numz <- length(z)      #partial out the z variables
     	                zm <- m[z,z,drop=FALSE]
     	                za <- m[x,z,drop=FALSE]
     	                zb <- m[y,z,drop=FALSE]
     	                zmi <- solve(zm)
     	                 x.matrix <- x.matrix - za %*% zmi %*% t(za)
     	                 y.matrix <- y.matrix - zb %*% zmi %*% t(zb)
     	                xy.matrix <- xy.matrix - za  %*% zmi %*% t(zb)
     	                m.matrix <- cbind(rbind(y.matrix,xy.matrix),rbind(t(xy.matrix),x.matrix))
     	               #m.matrix is now the matrix of partialled covariances -- make sure we use this one!
     	                 }
     	if(numx == 1 ) {beta <- matrix(xy.matrix,nrow=1)/x.matrix[1,1]
     	                rownames(beta) <- rownames(xy.matrix)
     	                colnames(beta) <- colnames(xy.matrix)
     	                } else   #this is the case of a single x 
      				 { beta <- solve(x.matrix,xy.matrix)       #solve the equation bY~aX
       					 beta <- as.matrix(beta) 
       					 }
       if(raw) {if(numx ==1) {intercept <- means[y] - sum(means[x] * beta[x,y ])} else {if(numy > 1) { intercept <- means[y] - colSums(means[x] * beta[x,y ])} else {intercept <- means[y] - sum(means[x] * beta[x,y ])}} } else {intercept <- NA}



       	yhat <- t(xy.matrix) %*% solve(x.matrix) %*% (xy.matrix)
       	resid <- y.matrix - yhat
    	if (numy > 1 ) { 
    	               if(is.null(rownames(beta))) {rownames(beta) <- x}
    	                if(is.null(colnames(beta))) {colnames(beta) <- y}
     	 
     	 R2 <- colSums(beta * xy.matrix)/diag(y.matrix) } else {  
     	 colnames(beta) <- y
     		
     		 R2 <- sum(beta * xy.matrix)/y.matrix
     		 R2 <- matrix(R2)
    		      	 	 rownames(beta) <- x
    		 rownames(R2) <- colnames(R2) <- y
     		 }
     	 VIF <- 1/(1-smc(x.matrix))

     	
     	#now find the unit weighted correlations  
     	#reverse items in X and Y so that they are all positive signed
     	
     	#But this  doesn't help in predicting y 
     	#we need to weight by the sign of the xy,matrix
     	#this gives a different key for each y
     	#need to adjust this for y
     	#  px <- principal(x.matrix)  
#             keys.x <- diag(as.vector(1- 2* (px$loadings < 0 )) )
#          py <- principal(y.matrix)
#             keys.y <- diag(as.vector(1- 2* (py$loadings < 0 ) ))
# 
#         Vx <- sum( t(keys.x) %*% x.matrix %*% t(keys.x))
#         Vy <- sum( keys.y %*% y.matrix %*% t(keys.y))
#      		 
#      	ruw <- colSums(abs(xy.matrix))/sqrt(Vx)	 
#      	Ruw <- sum(diag(keys.x) %*% xy.matrix %*% t(keys.y))/sqrt(Vx * Vy)
     	#end of old way of doing it
     	#new way  (2/17/18)
     	
     	keys.x <- sign(xy.matrix)  #this converts zero order correlations into -1, 0, 1 weights for each y
        Vx <-  t(keys.x) %*% x.matrix %*% (keys.x) #diag are scale variances
        #Vy <- t(keys.x) %*% y.matrix %*% keys.x #diag are y variances ?
        Vy <- (y.matrix)
        uCxy <- t(keys.x) %*% xy.matrix 
         ruw <- diag(uCxy)/sqrt(diag(Vx))  #these are the individual multiple Rs
         Ruw <-  sum(uCxy)/sqrt(sum(Vx)*sum(Vy))  #what are these?
       
     	if(numy < 2) {Rset <- 1 - det(m.matrix)/(det(x.matrix) )
     	             Myx <- solve(x.matrix) %*% xy.matrix  %*% t(xy.matrix)
     	             cc2 <- cc <- T <- NULL} else {if (numx < 2) {Rset <- 1 - det(m.matrix)/(det(y.matrix) )
     	            Myx <-  xy.matrix %*% solve(y.matrix) %*% t(xy.matrix)
     	            cc2 <- cc <- T <- NULL} else {Rset <- 1 - det(m.matrix)/(det(x.matrix) * det(y.matrix))
     	            if(numy > numx) {
     	            Myx <- solve(x.matrix) %*% xy.matrix %*% solve(y.matrix) %*% t(xy.matrix)} else { Myx <- solve(y.matrix) %*% t(xy.matrix )%*% solve(x.matrix) %*% (xy.matrix)}
     	           }
     	            cc2 <- eigen(Myx)$values
     	            cc <- sqrt(cc2)
     	            T <- sum(cc2)/length(cc2)             
     	            }
     	       
     	if(!is.null(n.obs)) {k<- length(x)
     	                     
     	                    # uniq <- (1-smc(x.matrix,covar=!std))
     	                     uniq <- (1-smc(x.matrix))
     	                     se.beta <- list() 
     	                     ci.lower <- list()
     	                     ci.upper <- list()
     	                     for (i in 1:length(y)) {
     	                     df <- n.obs-k-1   #this is the n.obs - length(x)
     	                     se.beta[[i]] <- (sqrt((1-R2[i])/(df))*sqrt(1/uniq))}    
     	                     se <- matrix(unlist(se.beta),ncol=length(y))
     	                       if(!is.null(z)) {colnames(beta) <- paste0(colnames(beta),"*")  }
     	                       colnames(se) <- colnames(beta)
     	                      if(!is.null(z)) {rownames(beta) <- paste0(rownames(beta),"*")}
     	                     rownames(se) <- rownames(beta)
     	                   
     	                    # se <- t(t(se) * sqrt(diag(C)[y]))/sqrt(diag(xc.matrix))  #need to use m.matrix
     	                    se <- t(t(se) * sqrt(diag(m.matrix)[y]))/sqrt(diag(x.matrix)) #corrected 11/29/18
     	                     for(i in 1:length(y))  {ci.lower[[i]] <-  beta[,i] - qt(1-alpha/2,df)*se[,i]
     	                                             ci.upper[[i]] <- beta[,i] + qt(1-alpha/2,df)*se[,i]}
     	                     ci.lower <- matrix(unlist(ci.lower),ncol=length(y))
     	                     ci.upper <- matrix(unlist(ci.upper),ncol=length(y))
     	               
     	                       colnames( ci.lower) <-  colnames( ci.upper) <- colnames( beta)
     	                     rownames( ci.lower)<- rownames( ci.upper) <- rownames(beta)

     	                     confid.beta <- cbind(ci.lower,ci.upper)
     	                    
     	                     tvalue <- beta/se
     	               # prob <- 2*(1- pt(abs(tvalue),df))
     	                prob <- -2 *  expm1(pt(abs(tvalue),df,log.p=TRUE))  
     	                     SE2 <- 4*R2*(1-R2)^2*(df^2)/((n.obs^2-1)*(n.obs+3))
     	                     SE =sqrt(SE2)
     	                     F <- R2*df/(k*(1-R2))
     	                    # pF <- 1 - pf(F,k,df)
     	                     
     	                     pF <-  -expm1(pf(F,k,df,log.p=TRUE))  
     	                     shrunkenR2 <- 1-(1-R2)*(n.obs-1)/df 
     	                   
     	               #find the shrunken R2 for set cor  (taken from CCAW p 615)
     	                     u <- numx * numy
     	                     m1 <- n.obs - max(numy ,(numx+numz)) - (numx + numy +3)/2 
     	                    
     	                     s <- sqrt((numx ^2 * numy^2 -4)/(numx^2 + numy^2-5)) 
     	                     if(numx*numy ==4) s <- 1
     	                   
     	                     v <- m1 * s + 1 - u/2
     	                     R2set.shrunk <- 1 - (1-Rset) * ((v+u)/v)^s
     	                     L <- 1-Rset
     	                     L1s <- L^(-1/s)
     	                     Rset.F <- (L1s-1)*(v/u)
     	                     df.m <- n.obs -  max(numy ,(numx+numz))  -(numx + numy +3)/2
     	                      s1 <- sqrt((numx ^2 * numy^2 -4)/(numx^2 + numy^2-5)) #see cohen p 321
     	                     if(numx^2*numy^2 < 5) s1 <- 1
     	                     df.v <- df.m * s1 + 1 - numx * numy/2 #which is just v
     	                    # df.v <- (u+v)  #adjusted for bias to match the CCAW results
     	                    #Rset.F <- Rset.F * (u+v)/v 
     	                   
     	                    Chisq <- -(n.obs - 1 -(numx + numy +1)/2)*log((1-cc2))
     	                   
     	                              }
     	
     #	if(numx == 1) {beta <-  beta * sqrt(diag(C)[y])
     #	   } else {beta <-  t(t(beta) * sqrt(diag(C)[y]))/sqrt(diag(xc.matrix))} #this puts the betas into the raw units
        
       # coeff <- data.frame(beta=beta,se = se,t=tvalue, Probabilty=prob)
       # colnames(coeff) <- c("Estimate", "Std. Error" ,"t value", "Pr(>|t|)")
     	if(is.null(n.obs)) {set.cor <- list(beta=beta,R=sqrt(R2),R2=R2,Rset=Rset,T=T,intercept=intercept,cancor = cc, cancor2=cc2,raw=raw,residual=resid,ruw=ruw,Ruw=Ruw,x.matrix=x.matrix,y.matrix=y.matrix,VIF=VIF,Call = cl)} else {
     	              set.cor <- list(beta=beta,se=se,t=tvalue,Probability = prob,intercept=intercept,ci=confid.beta,R=sqrt(R2),R2=R2,shrunkenR2 = shrunkenR2,seR2 = SE,F=F,probF=pF,df=c(k,df),Rset=Rset,Rset.shrunk=R2set.shrunk,Rset.F=Rset.F,Rsetu=u,Rsetv=df.v,T=T,cancor=cc,cancor2 = cc2,Chisq = Chisq,raw=raw,residual=resid,ruw=ruw,Ruw=Ruw,x.matrix=x.matrix,y.matrix=y.matrix,VIF=VIF,data=data,Call = cl)}
     	class(set.cor) <- c("psych","setCor")
     	if(plot) setCor.diagram(set.cor,main=main,show=show)
     	return(set.cor)
     	
     	}
#modified July 12,2007 to allow for NA in the overall matrix
#modified July 9, 2008 to give statistical tests
#modified yet again August 15 , 2008 to convert covariances to correlations
#modified January 3, 2011 to work in the case of a single predictor 
#modified April 25, 2011 to add the set correlation (from Cohen)
#modified April 21, 2014 to allow for mixed names and locations in call
#modified February 19, 2015 to just find the covariances of the data that are used in the regression
#this gets around the problem that some users have large data sets, but only want a few variables in the regression
#corrected February 17, 2018 to correctly find the unweighted correlations
#mdified Sept 22, 2018 to allow cex and l.cex to be set

#mdified November, 2017 to allow an override of which way to draw the arrows  
setCor.diagram <- function(sc,main="Regression model",digits=2,show=FALSE,cex=1,l.cex=1,...) { 
if(missing(l.cex)) l.cex <- cex  
beta <- round(sc$beta,digits)
x.matrix <- round(sc$x.matrix,digits)
y.matrix <- round(sc$y.matrix,digits)
y.resid <- round(sc$resid,digits)
x.names <- rownames(sc$beta)
y.names <- colnames(sc$beta)
nx <- length(x.names)
ny <- length(y.names)
top <- max(nx,ny)
xlim=c(-nx/3,10)
ylim=c(0,top)
top <- max(nx,ny)
x <- list()
y <- list()
x.scale <- top/(nx+1)
y.scale <- top/(ny+1)
plot(NA,xlim=xlim,ylim=ylim,main=main,axes=FALSE,xlab="",ylab="")
for(i in 1:nx) {x[[i]] <- dia.rect(3,top-i*x.scale,x.names[i],cex=cex,...) }
 
for (j in 1:ny) {y[[j]] <- dia.rect(7,top-j*y.scale,y.names[j],cex=cex,...) }
for(i in 1:nx) {
  for (j in 1:ny) {
   dia.arrow(x[[i]]$right,y[[j]]$left,labels = beta[i,j],adj=4-j,cex=l.cex,...)
   }
} 
if(nx >1) {
  for (i in 2:nx) {
  for (k in 1:(i-1)) {dia.curved.arrow(x[[i]]$left,x[[k]]$left,x.matrix[i,k],scale=-(abs(i-k)),both=TRUE,dir="u",cex = l.cex,...)}
                      #dia.curve(x[[i]]$left,x[[k]]$left,x.matrix[i,k],scale=-(abs(i-k)))  } 
  } }
  
  if(ny>1) {for (i in 2:ny) {
  for (k in 1:(i-1)) {dia.curved.arrow(y[[i]]$right,y[[k]]$right,y.resid[i,k],scale=(abs(i-k)),dir="u",cex=l.cex, ...)} 
  }}
  for(i in 1:ny) {dia.self(y[[i]],side=3,scale=.2,... )}
 if(show) {text((10-nx/3)/2,0,paste("Unweighted matrix correlation  = ",round(sc$Ruw,digits)))}
}
		 

      

     	
print.psych.setCor <- function(x,digits=2) {

cat("Call: ")
              print(x$Call)
            if(x$raw) {cat("\nMultiple Regression from raw data \n")} else {
            cat("\nMultiple Regression from matrix input \n")}
            ny <- NCOL(x$beta)
          for(i in 1:ny) {cat("\n DV = ",colnames(x$beta)[i],"\n")
          if(!is.na(x$intercept[i])) {cat(' intercept = ',round(x$intercept[i],digits=digits),"\n")}
          if(!is.null(x$se)) {result.df <- data.frame( round(x$beta[,i],digits),round(x$se[,i],digits),round(x$t[,i],digits),signif(x$Probability[,i],digits),round(x$ci[,i],digits), round(x$ci[,(i +ny)],digits),round(x$VIF,digits))
              colnames(result.df) <- c("slope","se", "t", "p","lower.ci","upper.ci",  "VIF")        
              print(result.df)      
              result.df <- data.frame(R = round(x$R[i],digits), R2 = round(x$R2[i],digits), Ruw = round(x$ruw[i],digits),R2uw =  round( x$ruw[i]^2,digits), round(x$shrunkenR2[i],digits),round(x$seR2[i],digits), round(x$F[i],digits),x$df[1],x$df[2], signif(x$probF[i],digits+1))
              colnames(result.df) <- c("R","R2", "Ruw", "R2uw","Shrunken R2", "SE of R2", "overall F","df1","df2","p")
              cat("\n Multiple Regression\n")
             print(result.df) } else {
              result.df <- data.frame( round(x$beta[,i],digits),round(x$VIF,digits))
              colnames(result.df) <- c("slope", "VIF")        
              print(result.df)      
              result.df <- data.frame(R = round(x$R[i],digits), R2 = round(x$R2[i],digits), Ruw = round(x$Ruw[i],digits),R2uw =  round( x$Ruw[i]^2,digits))
              colnames(result.df) <- c("R","R2", "Ruw", "R2uw")
              cat("\n Multiple Regression\n")
             print(result.df)
              } 
}
}