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

# Read csv
data.df <- read.csv(args[[1]], stringsAsFactors = FALSE)

# Column names required to be in the CSV file
required_columns <- c("id", "psqi1.clean", "psqi2.clean", "psqi3.clean", "psqi4.clean", "psqi5a.clean")

# Check if the required columns are present in the loaded CSV file
columns <- colnames(data.df)
if (!all(required_columns %in% str_to_lower(columns))){
  stop("The required columns are not present in the input file.", call.=FALSE)
}

############################################################
#                                                          #
#                    Scoring Functions                     #
#                                                          #
############################################################

sleepDuration <- function(psqi4){
  score <- ifelse(psqi4 < 5, 3,
         ifelse(psqi4 <= 6, 2,
                ifelse (psqi4 <= 7, 1, 0)
                )
         )
  return(score)
}

sleepEfficiency <- function(psqi4, psqi1, psqi3){
  #Time parsing to find difference
  difference <- ifelse(str_detect(psqi1, "PM"), 
                       (parse_hm(psqi3) + 24 * 60 * 60) - (parse_hm(psqi1) + 12 * 60 * 60),
                       ifelse(str_detect(psqi1, "AM") & str_extract(psqi1, "\\d{2}") == "12",
                              parse_hm(psqi3) - parse_hm(gsub("\\d{2}", "00", psqi1)),
                              ifelse(str_detect(psqi1, "AM") & str_detect(psqi3, "PM"),
                                     (parse_hm(psqi3) + 12 * 60 * 60) - parse_hm(psqi1),
                                     parse_hm(psqi3) - parse_hm(psqi1))))
  
  sleep_efficiency <- psqi4/(as.numeric(difference)/(60 * 60))
  
  score <- ifelse(sleep_efficiency < 0.65, 3,
                  ifelse(sleep_efficiency < 0.74, 2,
                         ifelse(sleep_efficiency < 0.84, 1, 0)))
  return(score)
}

############################################################
#                                                          #
#                     Calculate Scores                     #
#                                                          #
############################################################

data.df$score.sleep_duration <- sleepDuration(data.df$psqi4.clean)
data.df$score.sleep_efficiency <- sleepEfficiency(data.df$psqi4.clean, data.df$psqi1.clean, data.df$psqi3.clean)

############################################################
#                                                          #
#                     Write CSV Output                     #
#                                                          #
############################################################

write.csv(data.df, args[[2]], row.names = FALSE)