args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 0) {
  args[1] <- stdin()
}
if (length(args) == 1) {
  args[2] <- stdout()
}

library(tidyverse)

data.df <- read.csv("/home/rquitales/git/neuroscience/instructions/psqi_dirty.csv", stringsAsFactors = FALSE)

required_columns <- c("id", "psqi1", "psqi2", "psqi3", "psqi4", "psqi5a")
columns <- colnames(data.df)

if (!all(required_columns %in% str_to_lower(columns))){
  stop("The required columns are not present in the input file.", call.=FALSE)
}

# Extract all pasqi* columns

columns <- columns[str_detect(columns, "psqi")]


# check if dates in columns:
for (column in columns){
  for (row in 1:nrow(data.df)){
    if (!is.na(data.df[row, column]) | data.df[row, column] != ""){
      # Convert all text to lowercase in that cell
      rowData <- str_to_lower(data.df[row, column])
      # Check if any digits present, if not, return NA
      if (!str_detect(rowData, "\\d")){
        data.df[row, column] <- NA
        next
      }
      
      # Check if it is a time by detecting am or pm present
      if (str_detect(rowData, "am|pm|a.m|p.m")){
        if (str_detect(rowData, "\\d{1,2}-\\d{1,2}")){
          rowData <- paste0(str_extract(rowData, "(?<=-)\\d{1,2}"), " ", ifelse(str_detect(rowData, "am|a.m"), "am", "pm"))
        }
        # Parse the date-time into HH:MM format
        if (str_detect(rowData, "\\d{1,2}[:;.,\\s]\\d{1,2}")){
          temp <- str_extract(rowData, "\\d{1,2}[:;.,\\s]\\d{1,2}")
          temp <- unlist(strsplit(temp, "[:;.,\\s]"))
          if (str_detect(rowData, "am|a.m")){
            data.df[row, column] <- paste(paste(temp, collapse = ":"), "AM")
          } else {
            data.df[row, column] <- paste(paste(temp, collapse = ":"), "PM")
          }
        } else {
          temp <- unlist(str_extract_all(rowData, "\\d"))
          
          if (length(temp) == 3){
            data.df[row, column] <- paste0(temp[1], ":", temp[2], temp[3], " ", ifelse(str_detect(rowData, "am|a.m"), "AM", "PM"))
          } else if (length(temp) == 4){
            data.df[row, column] <- paste0(temp[1], temp[2], ":", temp[3], temp[4], " ", ifelse(str_detect(rowData, "am|a.m"), "AM", "PM"))
          } else if (length(temp) == 2){
            data.df[row, column] <- paste0(temp[1], temp[2], ":", "00", " ", ifelse(str_detect(rowData, "am|a.m"), "AM", "PM"))
          } else {
            data.df[row, column] <- paste0(temp[1], ":", "00", " ", ifelse(str_detect(rowData, "am|a.m"), "AM", "PM"))
          }
        }
        next
      }
      
      # Convert a date (12-Oct) to a range and get the middle
      if (str_detect(rowData, "\\d{1,2}-\\D{3,4}")){
        temp <- unlist(strsplit(rowData, "-"))
        temp[2] <- match(temp[2], str_to_lower(month.abb))
        data.df[row, column] <- mean(as.numeric(temp))
        next
      }
      # Extract the "day" and "month" from mm-dd-yyyy and assume it's a range and get middle
      if (str_detect(rowData, "/")){
        temp <- unlist(strsplit(rowData, "/"))
        data.df[row, column] <- mean(as.numeric(temp[1:2]))
        next
      }
      
      # Change 'midnight'
      if (rowData == "midnight"){
        data.df[row, column] <- "12:00 AM"
        next
      }
      
      # Get middle of any range that is separated with '-'
      if (str_detect(rowData, "\\d{1,3}\\s?-\\s?\\d{1,3}")){
        temp <- str_extract(data.df[row, column], "\\d{1,3}\\s?-\\s?\\d{1,3}")
        temp <- unlist(strsplit(temp, "-"))
        data.df[row, column] <- mean(as.numeric(temp))
        next
      }
      
      # Extract the hour/hrs
      if (str_detect(rowData, "hours|hr|hrs|hr's")){
        data.df[row, column] <- str_extract(data.df[row, column], "\\d{1,2}")
        next
      }
      
      # Extract range for 'or', eg 10 or 11 hours becomes 10.5
      if (str_detect(rowData, "\\d{1,3}\\s?or\\s?\\d{1,3}")){
        temp <- str_extract(data.df[row, column], "\\d{1,3}\\s?or\\s?\\d{1,3}")
        temp <- unlist(strsplit(temp, "or"))
        data.df[row, column] <- mean(as.numeric(temp))
        next
      }
      
      # If all above were false, just extract the digits
      if (str_detect(rowData, "\\d")){
        data.df[row, column] <- str_extract(rowData, "\\d{1,4}")
      }
    } else {
      data.df[row, column] <- NA
    }
  }
}

# Check if at least half of the entries in the column are times, then parse it as a time component
for (column in columns){
  if (sum(str_detect(data.df[[column]], "AM|PM"), na.rm = TRUE) > nrow(data.df) / 2){
    for (row in 1:nrow(data.df)){
      if (!is.na(data.df[row, column])){
        if (!str_detect(data.df[row, column], "\\d{1,2}:\\d{1,2}\\s\\D{2}")){
          temp <- unlist(str_extract_all(data.df[row, column], "\\d"))
          
          if (length(temp) == 3){
            data.df[row, column] <- paste0(temp[1], ":", temp[2], temp[3])
          } else if (length(temp) == 4){
            data.df[row, column] <- paste0(temp[1], temp[2], ":", temp[3], temp[4])
          } else if (length(temp) == 2){
            data.df[row, column] <- paste0(temp[1], temp[2], ":", "00")
          } else {
            data.df[row, column] <- paste0(temp[1], ":", "00")
          } 
        }
      }
    }
    data.df[[column]] <- hms::parse_hm(data.df[[column]])
  } else {
    data.df[[column]] <- as.numeric(data.df[[column]])
  }
}

