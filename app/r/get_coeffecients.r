#Read in augmented matrix
getwd()
ab <- read.csv(file = 'temp\\dropped_coeffecients.csv')
ab <- data.matrix(ab)
ab <- ab[, colSums(ab != 0) > 0]



#Assemble A and B matrices
a <- ab[,1:ncol(ab)-1]
b <- data.matrix(ab[,ncol(ab)])


aT <- t(a)

#Ordinary Least Squares
#Multiply the inverse Gramian matrix (on the left) with moment matrix
solution <- ((solve(aT%*%a)%*%aT)%*%b)

solution

#write csv file to validation data folder
write.csv(solution, file = "temp\\solution_coeffecients.csv")

getwd()
