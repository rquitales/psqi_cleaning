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
required_columns <- c("id", "psqi1", "psqi2", "psqi3", "psqi4", "psqi5a")

# Check if the required columns are present in the loaded CSV file
columns <- colnames(data.df)
if (!all(required_columns %in% str_to_lower(columns))){
  stop("The required columns are not present in the input file.", call.=FALSE)
}

# Extract all pasqi* columns, ie all columns that have 'psqi' in their name
columns <- columns[str_detect(columns, "psqi")]

# Clone original for later
data.orig <- data.df

############################################################
#                                                          #
#                      Clean the Data                      #
#                                                          #
############################################################

# Cell-by-cell basis using a nested-loop
for (column in columns){
  for (row in 1:nrow(data.df)){
    # Make sure the cell isn't NA, otherwise don't clean at all
    if (!is.na(data.df[row, column])){
      
      # Convert all text to lowercase in that cell to reduce permutations for string detection
      rowData <- str_to_lower(data.df[row, column])
      
      # Change 'midnight' to '12:00 AM'
      if (rowData == "midnight"){
        data.df[row, column] <- "12:00 AM"
        next
      }
      
      # Check if any digits present, if not, return NA
      if (!str_detect(rowData, "\\d")){
        data.df[row, column] <- NA
        next
      }
      
      # Check if it is a time by detecting 'am' or 'pm' present
      if (str_detect(rowData, "am|pm|a.m|p.m")){
        # Check if it is a time range, 7-8 am, and get the max of the range
        if (str_detect(rowData, "\\d{1,2}-\\d{1,2}")){
          rowData <- paste0(str_extract(rowData, "(?<=-)\\d{1,2}"), " ", ifelse(str_detect(rowData, "am|a.m"), "am", "pm"))
        }
        
        # Parse the date-time into HH:MM format, if it is in HH:MM or HH:MM:SS format already
        if (str_detect(rowData, "\\d{1,2}[:;.,\\s]\\d{1,2}")){
          temp <- str_extract(rowData, "\\d{1,2}[:;.,\\s]\\d{1,2}")
          temp <- unlist(strsplit(temp, "[:;.,\\s]"))
          # Determine if AM or PM to be appended based on on-cleaned cell info
          if (str_detect(rowData, "am|a.m")){
            data.df[row, column] <- paste(paste(temp, collapse = ":"), "AM")
          } else {
            data.df[row, column] <- paste(paste(temp, collapse = ":"), "PM")
          }
        } else { # Try to parse time if not in HH:MM or HH:MM:SS format
          # Extract all the digits present
          temp <- unlist(str_extract_all(rowData, "\\d"))
          # Parse into HH:MM format based on number of digits in un-cleaned cell
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

# Use column data to try and further parse anomolous data within that column
for (column in columns){
  ## Check if at least half of the entries in the column are times, then parse it as a time component
  if (sum(str_detect(data.df[[column]], "AM|PM"), na.rm = TRUE) > nrow(data.df) / 2){
    for (row in 1:nrow(data.df)){
      # Parse a time from any non AM or PM entry in a column that is mostly AM/PM
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
  } else {
    # If not a time column, parse as numeric data instead
    data.df[[column]] <- suppressWarnings(as.numeric(data.df[[column]]))
  }
}

############################################################
#                                                          #
#             Merge Cleaned and Uncleaned Data             #
#                                                          #
############################################################

data.df <- data.df[,columns]
colnames(data.df) <- paste0(colnames(data.df), ".clean")
data.df <- cbind(data.orig, data.df)

############################################################
#                                                          #
#                        Write CSV                         #
#                                                          #
############################################################

write.csv(data.df, args[[2]], row.names = FALSE)

