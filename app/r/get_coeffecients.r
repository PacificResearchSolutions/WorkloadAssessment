#Set the working directory
setwd("C:/Users/RSchuetz/github/WorkloadAssessment/app/vdata/Round 2")

#Read in A and B matrices
a <- read.csv(file = 'a.csv', header=FALSE)
a <- data.matrix(a)
b <- read.csv(file = 'b.csv', header=FALSE)
b <- data.matrix(b)
aT <- t(a)

#Ordinary Least Squares
#Multiply the inverse Gramian matrix (on the left) with moment matrix
solution <- ((solve(aT%*%a)%*%aT)%*%b)

#write csv file to validation data folder
write.csv(solution, file = "coeffecients.csv")
