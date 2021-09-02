## clean working environment
rm(list=ls())

## load packages
library(prophet)
library(dplyr)
library(tidyr)

## set working directory
path <- 'C:/Users/Yair/OneDrive/Desktop/GA_course/Submissions/Projects/capstone/coffee'
setwd(paste(path,"/data",sep=''))

## read the data
dat <- read.csv('daily_prices_historical.csv', header=T)

## rename the columns
names(dat)[1] <- 'ds'
names(dat)[2] <- 'y'

# summary(dat$y)

## extract the index of the row where the date is 2020-08-10
last_year_start_index <- as.numeric(rownames(dat[dat$ds == '2020-08-10',]))
last_year_start_index

## train-test split
train <- dat[1:last_year_start_index-1, ]
test <- dat[last_year_start_index:nrow(dat), ]

## fit the model
model <- prophet(train,
                 changepoint.prior.scale = 0.1,
                 seasonality.prior.scale = 0.01,
                 interval.width=0.95 # 95% credible intervals
                 #mcmc.samples = 3000 # for full sampling
                 )

## create data frame to be filled with predictions
future <- make_future_dataframe(model, 
                                periods = 365,
                                freq='days')

## make predictions
forecast <- predict(model, future)

## load source codes
## I modified some default settings in the plot functions
source(paste(path,'/code/plot_source.R',sep=''))
source(paste(path,'/code/prophet_source.R',sep=''))

## plot the trend in the model against the data, and the forecast
plot(model, forecast, 
     ylabel = 'USD / lb of green coffee\n(shaded area: 95% credible intervals)',
     xlabel = 'Date', 
     plot_title = 'Daily coffee prices - international market (1973-2021) & 1 year forecast'
) #+ add_changepoints_to_plot(model) # to see the changepoints in the data


## take new data frame with predicted and actual prices in the test data
setwd(paste(path,'/models/Prophet',sep=''))
forecast_vs_test <- read.csv('forecast_vs_test.csv',header=T)

## drop NA's
ss <- forecast_vs_test[!is.na(forecast_vs_test$test_ds),]
ss <- ss[!is.na(ss$fcst_ds), ]

## check that we have matching dates in the forecast data (fcst_ds) and the test data (test_ds)
length(which(ss$fcst_ds==ss$test_ds)) == nrow(ss)

## remain with relevant columns
ss <- ss[, c('fcst_ds', 'y', 'yhat')] 

## long format
library(reshape2)
ss_long <- melt(ss, id=c('fcst_ds'))
ss_long$fcst_ds <- as.Date(ss_long$fcst_ds, format = "%d-%m-%y")
levels(ss_long$variable) <- c('Actual', 'Predicted')

## plot actual values vs. predictions of test data
library(ggplot2)
ggplot(ss_long, aes(x=fcst_ds, y=value, color=variable)) + 
  geom_line(size=1.5) + theme_bw() + 
  ylab('USD / lb of green coffee beans') + 
  xlab('Date') + 
  scale_x_date(date_labels = "%Y-%m-%d") +
  #scale_colour_manual(values=c("#56B4E9","#E69F00"), name='')+
  scale_colour_manual(values=c('black','#CE1425'), name='')+
  theme(axis.text.x = element_text(color='black',size=16, angle=25),
        axis.text.y = element_text(color='black',size=16),
        axis.title = element_text(color='black',size=16),
        legend.text = element_text(color='black',size=16),
        legend.position = c(.1,.85),
        legend.background = element_blank())

## calculate MSE of test data
library(MLmetrics)
testing_mse = MSE(y_pred = ss$yhat, y_true = ss$y)
testing_mse # 0.317

## calculate MAPE of test data
mape <- function(y_true, y_pred){
  mape <- mean(abs( (y_true - y_pred) / y_true )) * 100
  return(mape)
}

testing_mape = mape(y_true = ss$y, y_pred = ss$yhat)
testing_mape # 37.36%

## plot model components
prophet_plot_components(model, forecast)

## save the model
setwd(paste(path,'/models/Prophet',sep=''))
saveRDS(model, file="daily_prices_international_change_0_1_season_0_01.RDS")

## read the model
# model <- readRDS(file="daily_prices_international_change_0_1_season_0_01.RDS")

## cross validation 
df.cv <- cross_validation(model, 
                          initial = 10950,    # training on the first 30 years (1973-2003)
                          period = 180,       # testing every 180 days
                          horizon = 365, units = 'days') # testing on a period of 365 days

# getwd()
write.csv(df.cv, file='cross_validation.csv')

# setwd(paste(path, '/models/Prophet', sep=''))
# df.cv <- read.csv('cross_validation.csv', header=T)
# df.cv <- df.cv[,-1]
# df.cv$ds <- as.Date(df.cv$ds)
# df.cv$cutoff <- as.Date(df.cv$cutoff)

## create performance metrics data frame
df.p <- performance_metrics(df.cv)

# getwd()
write.csv(df.p, file='performance_metrics.csv')

# setwd(paste(path, '/models/Prophet', sep=''))
# df.p <- read.csv('performance_metrics.csv', header=T)
# df.p <- df.p[,-1]

## plot performance metrics
plot_cross_validation_metric(df.cv, metric = 'mse')
plot_cross_validation_metric(df.cv, metric = 'mape')
