############################################################
#                                                          #
#                    Argument Handling                     #
#                                                          #
############################################################
#Get arguments
args <- as.list(commandArgs(trailingOnly = TRUE))

# If argument list is empty, have stdin as the input and stdout as output
if (length(args) == 0) {
  args[[1]] <- "stdin"
}
if (length(args) == 1) {
  args[[2]] <- stdout()
}

############################################################
#                                                          #
#                      Load Packages                       #
#                                                          #
############################################################
library(stringr)
library(hms)

############################################################
#                                                          #
#                  Load & Check CSV Input                  #
#                                                          #
############################################################

loadData <- function(file = args[[1]], requiredColumns = c("id", "psqi1.clean", "psqi2.clean", "psqi3.clean", "psqi4.clean", "psqi5a.clean")){
  # Read csv
  data.df <- read.csv(file, stringsAsFactors = FALSE)
  
  # Check if the required columns are present in the loaded CSV file
  columns <- colnames(data.df)
  
  if (!all(requiredColumns %in% str_to_lower(columns))){
    stop("The required columns are not present in the input file.", call.=FALSE)
  }
  
  return(data.df)
}

############################################################
#                                                          #
#                    Scoring Functions                     #
#                                                          #
############################################################
# Score sleep duration using scoring windows and psqi4 answer
sleepDuration <- function(psqi4){
  ## ifelse to vectorise scoring on a column of input
  score <- ifelse(psqi4 < 5, 3,
         ifelse(psqi4 <= 6, 2,
                ifelse (psqi4 <= 7, 1, 0)
                )
         )
  return(score)
}

# Score sleep effienciency using psqi1, psqi3 and psqi4
sleepEfficiency <- function(psqi4, psqi1, psqi3){
  # Time parsing to find difference
  ## Need to know if to add 1 day to the wake-up time to calculate time difference
  difference <- ifelse(str_detect(psqi1, "PM"), 
                       (parse_hm(psqi3) + 24 * 60 * 60) - (parse_hm(psqi1) + 12 * 60 * 60),
                       ifelse(str_detect(psqi1, "AM") & str_extract(psqi1, "\\d{2}") == "12",
                              parse_hm(psqi3) - parse_hm(gsub("\\d{2}", "00", psqi1)),
                              ifelse(str_detect(psqi1, "AM") & str_detect(psqi3, "PM"),
                                     (parse_hm(psqi3) + 12 * 60 * 60) - parse_hm(psqi1),
                                     parse_hm(psqi3) - parse_hm(psqi1))))
  
  # Calculate sleep effieciency
  sleep_efficiency <- psqi4/(as.numeric(difference)/(60 * 60))
  
  # Calculate sleep efficiency score
  score <- ifelse(sleep_efficiency < 0.65, 3,
                  ifelse(sleep_efficiency < 0.74, 2,
                         ifelse(sleep_efficiency < 0.84, 1, 0)))
  return(score)
}


# Combine scoring functions into 1 call

calculateScores <- function(.data){
  data.temp <- .data
  data.temp$score.sleep_duration <- sleepDuration(data.temp$psqi4.clean)
  data.temp$score.sleep_efficiency <- sleepEfficiency(data.temp$psqi4.clean, data.temp$psqi1.clean, data.temp$psqi3.clean)
  
  return(data.temp)
}


############################################################
#                                                          #
#                      Use Functions                       #
#                                                          #
############################################################
# Load data
data.df <- loadData()
# Score data
data.df <- calculateScores(data.df)
# Write output
write.csv(data.df, args[[2]], row.names = FALSE)