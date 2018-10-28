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

############################################################
#                                                          #
#                  Load & Check CSV Input                  #
#                                                          #
############################################################

loadData <- function(file = args[[1]], requiredColumns = c("id", "psqi1", "psqi2", "psqi3", "psqi4", "psqi5a")){
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
#                    Cleaning Functions                    #
#                                                          #
############################################################
# Parse time data strings
parseTime <- function(.input){
    # Check if it is a time range, 7-8 am, and get the max of the range
    if (str_detect(.input, "\\d{1,2}-\\d{1,2}")){
      .input <- paste0(str_extract(.input, "(?<=-)\\d{1,2}"), " ", ifelse(str_detect(.input, "am|a.m"), "am", "pm"))
    }
    
    # Parse the date-time into HH:MM format, if it is in HH:MM or HH:MM:SS format already
    if (str_detect(.input, "\\d{1,2}[:;.,\\s]\\d{1,2}")){
      temp <- str_extract(.input, "\\d{1,2}[:;.,\\s]\\d{1,2}")
      temp <- unlist(strsplit(temp, "[:;.,\\s]"))
      # Determine if AM or PM to be appended based on on-cleaned cell info
      if (str_detect(.input, "am|a.m")){
        return(paste(paste(temp, collapse = ":"), "AM"))
      } else {
        return(paste(paste(temp, collapse = ":"), "PM"))
      }
    } else { # Try to parse time if not in HH:MM or HH:MM:SS format
      # Extract all the digits present
      temp <- unlist(str_extract_all(.input, "\\d"))
      # Parse into HH:MM format based on number of digits in un-cleaned cell
      if (length(temp) == 3){
        return(paste0(temp[1], ":", temp[2], temp[3], " ", ifelse(str_detect(.input, "am|a.m"), "AM", "PM")))
      } else if (length(temp) == 4){
        return(paste0(temp[1], temp[2], ":", temp[3], temp[4], " ", ifelse(str_detect(.input, "am|a.m"), "AM", "PM")))
      } else if (length(temp) == 2){
        return(paste0(temp[1], temp[2], ":", "00", " ", ifelse(str_detect(.input, "am|a.m"), "AM", "PM")))
      } else {
        return(paste0(temp[1], ":", "00", " ", ifelse(str_detect(.input, "am|a.m"), "AM", "PM")))
      }
    }
  return(.input)
}

# Convert a date (12-Oct) to a range and get the middle
dateRange <- function(.input){
  temp <- unlist(strsplit(.input, "-"))
  temp[2] <- match(temp[2], str_to_lower(month.abb))
  return(mean(as.numeric(temp)))
}

# Extract the "day" and "month" from mm-dd-yyyy and assume it's a range and get middle
dateRange2 <- function(.input){
  if (is.na(.input))
    return(NA)
  
  temp <- unlist(strsplit(.input, "/"))
  return(mean(as.numeric(temp[1:2])))
}

# Get middle of any range that is separated with '-'
numRange <- function(.input){
  temp <- str_extract(.input, "\\d{1,3}\\s?-\\s?\\d{1,3}")
  temp <- unlist(strsplit(temp, "-"))
  return(mean(as.numeric(temp)))
}

# Extract the hour/hrs
extractHours <- function(.input){
  return(str_extract(.input, "\\d{1,2}"))
}

# Extract range for 'or', eg 10 or 11 hours becomes 10.5
orRange <- function(.input){
  temp <- str_extract(.input, "\\d{1,3}\\s?or\\s?\\d{1,3}")
  temp <- unlist(strsplit(temp, "or"))
  return(mean(as.numeric(temp)))
}

# Just extract the digits
extractDigits <- function(.input){
  return(str_extract(.input, "\\d{1,4}\\.?\\d?"))
}

# Combine all cleaning functions into one call

cleanData <- function(.input){
  if (!is.na(.input)){
    string <- str_to_lower(.input)
    
    if (string == "midnight"){
      string <- "12:00 AM"
    } else if (!str_detect(string, "\\d")){
      string <- NA
    } else if (str_detect(string, "am|pm|a.m|p.m")){
      string <- parseTime(string)
    } else if (str_detect(string, "\\d{1,2}-\\D{3,4}")){
      string <- dateRange(string)
    } else if (str_detect(string, "/")){
      string <- dateRange2(string)
    } else if (str_detect(string, "\\d{1,3}\\s?-\\s?\\d{1,3}")){
      string <- numRange(string)
    } else if (str_detect(string, "hours|hr|hrs|hr's")){
      string <- extractHours(string)
    } else if (str_detect(string, "\\d{1,3}\\s?or\\s?\\d{1,3}")){
      string <- orRange(string)
    } else if (str_detect(.input, "\\d")) {
      string <- extractDigits(string)
    }
    return(string)
  }
}

cleanColumn <- function(.data){
  data.clean <- .data
  
  # Use information within that column to determine if time or numeric column
  for (column in colnames(data.clean)){
    ## Check if at least half of the entries in the column are times, then parse it as a time component
    if (sum(str_detect(data.clean[[column]], "AM|PM"), na.rm = TRUE) > nrow(data.clean) / 2){
      for (row in 1:nrow(data.clean)){
        # Parse a time from any non AM or PM entry in a column that is mostly AM/PM
        if (!is.na(data.clean[row, column])){
          # If it is not in (HH:MM AM/PM) foramt, try to parse it as a time
          if (!str_detect(data.clean[row, column], "\\d{1,2}:\\d{1,2}\\s\\D{2}")){
            temp <- unlist(str_extract_all(data.clean[row, column], "\\d"))
            
            if (length(temp) == 3){
              data.clean[row, column] <- paste0(temp[1], ":", temp[2], temp[3], " ", ifelse(as.numeric(temp[1]) < 12, "PM", "AM"))
            } else if (length(temp) == 4){
              data.clean[row, column] <- paste0(temp[1], temp[2], ":", temp[3], temp[4], " ", ifelse(as.numeric(paste0(temp[1], temp[2])) < 12, "PM", "AM"))
            } else if (length(temp) == 2){
              data.clean[row, column] <- paste0(temp[1], temp[2], ":", "00", " ", ifelse(as.numeric(paste0(temp[1], temp[2])) < 12, "PM", "AM"))
            } else {
              data.clean[row, column] <- paste0(temp[1], ":", "00", " ", ifelse(as.numeric(temp[1]) < 12, "PM", "AM"))
            } 
          }
        }
      }
    } else {
      # If not a time column, parse as numeric data instead
      data.clean[[column]] <- suppressWarnings(as.numeric(data.clean[[column]]))
    }
  }
  return(data.clean)
}

############################################################
#                                                          #
#                     Cleaning Wrapper                     #
#                                                          #
############################################################

cleanDataFrame <- function(.data, columnPrefix = "psqi"){
  columns <- colnames(.data)[str_detect(colnames(.data), columnPrefix)]
  data.clean <- .data[, columns]
  
  # Initial cleaning
  ## Cell by cell basis to extract information
  for (column in columns){
    for (row in 1:nrow(data.clean)){
      data.clean[row, column] <- cleanData(data.clean[row, column])
    }
  }
  
  # Secondary cleaning
  data.clean <- cleanColumn(data.clean)
  
  # Merge original and clean data
  ## Changed column names of cleaned data to have '.clean'
  colnames(data.clean) <- paste0(colnames(data.clean), ".clean")
  
  # Return merged dataframe
  return(cbind(.data, data.clean))
}

############################################################
#                                                          #
#                      Use functions                       #
#                                                          #
############################################################
# Load data
data.df <- loadData()
# Clean data
data.df <- cleanDataFrame(data.df)
# Write data
write.csv(data.df, args[[2]], row.names = FALSE)