rm(list = ls())


#packages
#install.packages("quadprog")
#install.packages("ggplot2")
#install.packages("plotly")
#install.packages("readxl")

library(quadprog)
library(ggplot2)
library(plotly)
library(readxl)

#change this input. These must be columns with asset prices in ascending order over time
#name of the columns must be the names of the assets
prices <- read_excel("D:/R/finance/test_mark2.xlsx")
#prices=prices[,-1]

# Find the minimum length among all price columns and truncate all columns to that length
#only if needed
min_length <- min(sapply(prices, length))
prices <- prices[1:min_length, ]

# Calculate the logarithmic returns for each asset and remove any rows with NA values
returns <- apply(prices, 2, function(x) diff(log(as.numeric(x))))
returns <- na.omit(returns)

# Compute the covariance matrix of the returns
cov_matrix <- cov(returns)
# Calculate the mean returns for each asset
mean_returns <- colMeans(returns)
efficient_frontier <- function(mean_returns, cov_matrix, n_portfolios = 100) {
  
  
  n_assets <- length(mean_returns)
  
  # Initialize vectors for portfolio returns, risks, and weights
  port_returns <- numeric(n_portfolios)
  port_risks <- numeric(n_portfolios)
  port_weights <- matrix(0, nrow = n_portfolios, ncol = n_assets)
  
  #Generate random portfolios and calculate their returns and risks
  for (i in 1:n_portfolios) {
    weights <- runif(n_assets)
    weights <- weights / sum(weights)
    
    port_weights[i, ] <- weights
    port_returns[i] <- sum(weights * mean_returns)
    port_risks[i] <- sqrt(t(weights) %*% cov_matrix %*% weights)
  }
  
  #dataframe with portfolio returns, risks, and weights
  data.frame(Return = port_returns, Risk = port_risks, Weights = port_weights)
}

# Between 10,000 and 50,000 portfolios when we have between 3 and 6 assets
# Between 5,000 and 20,000 portfolios when we have more than 10 assets

n_portfolios <- 50000  
frontier <- efficient_frontier(mean_returns, cov_matrix, n_portfolios)


min_risk_idx <- which.min(frontier$Risk)
min_risk_weights <- frontier[min_risk_idx, 3:ncol(frontier)]

column_names <- colnames(prices)
cat("The optimal allocations for the minimum-risk portfolio are:\n")
allocation_min_risk <- setNames(as.numeric(min_risk_weights), column_names)


#creation of the chart
plot_data <- data.frame(Risk = frontier$Risk, Return = frontier$Return, Weights = I(frontier[, 3:ncol(frontier)]))

p <- ggplot(plot_data, aes(x = Risk, y = Return)) +
  geom_point(color = 'blue', alpha = 0.5) +
  geom_point(aes(x = plot_data$Risk[min_risk_idx], y = plot_data$Return[min_risk_idx]), color = 'red', size = 3) +
  labs(title = 'Markowitz Efficient Frontier',
       x = 'Risk (Standard Deviation)',
       y = 'Expected Return') +
  theme_minimal()


p_interactive <- ggplotly(p)


for (i in 1:nrow(plot_data)) {
  allocations <- setNames(as.numeric(plot_data$Weights[i, ]), column_names)
  tooltip_text <- paste(names(allocations), ": ", round(allocations, 4), collapse = "<br>")
  p_interactive$x$data[[1]]$text[i] <- paste("Risk: ", round(plot_data$Risk[i], 4),
                                             "<br>Return: ", round(plot_data$Return[i], 4),
                                             "<br>Allocations:<br>", tooltip_text)
}

# display chart
p_interactive
#best portfolio

print(allocation_min_risk) 


# Ask the user to enter the current allocation as a vector
cat("Enter your current portfolio allocation (as a vector of percentages, matching the number of assets):\n")
# Example: current_allocation <- c(0.6, 0.3, 0.1) for a portfolio with three assets
current_allocation <- c(0.76, 0.11, 0.65, 0.57)  # Replace this line with your current allocation vector or prompt for input

# Check if the length of the vector matches the number of assets
if (length(current_allocation) != length(column_names)) {
  stop("The length of the current allocation vector does not match the number of assets.")
}

# Normalize the current allocation so that the sum equals 1 (if necessary)
current_allocation <- current_allocation / sum(current_allocation)

# Calculate the current portfolio's risk and return based on the user's input allocation
current_return <- sum(current_allocation * mean_returns)
current_risk <- sqrt(t(current_allocation) %*% cov_matrix %*% current_allocation)

# Find the point on the efficient frontier with the closest risk but the highest return
closest_risk_idx <- which.min(abs(frontier$Risk - current_risk))
# Check if there are other points on the frontier with the same risk, and choose the one with the highest return
same_risk_points <- frontier[frontier$Risk == frontier$Risk[closest_risk_idx], ]
if (nrow(same_risk_points) > 1) {
  closest_risk_point <- same_risk_points[which.max(same_risk_points$Return), ]
} else {
  closest_risk_point <- same_risk_points
}

# Now that we have the point with the closest risk and highest return, we extract the allocation
closest_allocation <- closest_risk_point[3:ncol(frontier)]

cat("The portfolio on the efficient frontier with the closest risk and the highest return has the following allocation:\n")
print(setNames(as.numeric(closest_allocation), column_names))

cat("\nRisk (Standard Deviation):", closest_risk_point$Risk)
cat("\nExpected Return:", closest_risk_point$Return)

# Add a yellow point to represent the current allocation on the interactive plot
p_interactive <- p_interactive %>% 
  add_trace(x = current_risk, y = current_return, mode = "markers", marker = list(color = 'yellow', size = 10),
            name = 'Current Allocation')

# Display the interactive plot
p_interactive


# Ask the user for another allocation to calculate the cumulative return
cat("\nEnter another portfolio allocation (as a vector of percentages, matching the number of assets):\n")
# Example: another_allocation <- c(0.4, 0.4, 0.2) for a portfolio with three assets
another_allocation <- c(0.5, 0.5, 0, 0)  # Replace this line with your new allocation or prompt the user for input

# Check if the length of the vector matches the number of assets
if (length(another_allocation) != length(column_names)) {
  stop("The length of the new allocation vector does not match the number of assets.")
}

# Normalize the allocation so that the sum is equal to 1 (if necessary)
another_allocation <- another_allocation / sum(another_allocation)

# Ask the user for the current capital (e.g., 1000€)
cat("\nEnter your current capital (e.g., 1000):\n")
current_capital <- 1000

# Calculate the expected return of the portfolio with this allocation (mean_returns should be in daily terms)
expected_daily_return_portfolio <- sum(another_allocation * mean_returns)

# Calculate the total number of days (i.e., number of rows in the returns data)
total_days <- nrow(returns)

# Convert the total number of days into years (this accounts for any gaps in days)
years <- total_days / 252  #252 is the average number of trading day in a year

# Calculate the cumulative return over the total period based on the number of actual days
cumulative_return <- (1 + expected_daily_return_portfolio)^total_days - 1

# Calculate the future value of the portfolio after the total period
future_value <- current_capital * (1 + cumulative_return)

# Display the cumulative return and future value over the total period
cat("\nThe expected cumulative return of the portfolio over", round(years, 2), "years is:", round(cumulative_return * 100, 2), "%\n")
cat("With a starting capital of", current_capital, "the amount after", round(years, 2), "years will be:", round(future_value, 2), "€\n")