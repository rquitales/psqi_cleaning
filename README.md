# PSQI Cleaning and Scoring

This project is able to clean and score PSQI survey data from an input `csv` file.

## Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes. See deployment for notes on how to deploy the project on a live system.

### Prerequisites

The project requires the R statistical programming language to be installed on the system.

On a Debian based Linux distribution, this can be installed via the terminal with the following command:
```
sudo apt install r-base
```

#### Installing Packages

To enable the R scripts to run properly, the following two R packages are required:
 * hms
 * stringr

These can be installed within an R terminal/environment using the following command:

```
> install.packages(c("hms", "stringr"))
```

### Running the Scripts
#### Cleaning Survey Data

To clean a PSQI survey, invoke the `clean_psqi` shell script.

```
./clean_psqi [input csv] [output csv]
```

Data can also be piped into `clean_psqi`

```
cat [input csv] | ./clean psqi > [output csv]
```

If the first argument, `[input csv]`, is not given, the input file is read from `stdin`. Similarly, if the second argument, `[output csv]`, is not given, the output file is written to `stdout`.

#### Scoring Survey Data

To score PSQI survey data, invoke the `score_psqi` shell script. This script only works on an input that has cleaned data columns. This means that the `clean_psqi` script must be invoked first.

Currently, `score_psqi` only scores components 2, 3 and 4.

To run:

```
./score_psqi [input cleaned csv] [output csv]
```

Data from the `clean_psqi` script can also be piped into `score_psqi` as such:

```
./clean_psqi [input csv] | ./score_psqi > [output csv]
```

Similar to `clean_psqi`, `score_psqi` will output to `stdout` if argument 2 is not given.

## Script Details
### clean.R
`clean.R` contains the logic to clean PSQI survey data. Basically, it doesn't use the column names to help it parse/clean the data. Instead, it checks to see what each cell within the data frame already contains, then carries out specific cleaning functions.

After going through each cell, the cleaning function then checks the data on a column by column basis. If it detects that the column has more than 50% of cells containing times (in the format: `HH:MM AM/PM`) from the initial cleaning, it then further tries to clean data within that column if it is not in the `HH:MM AM/PM` format. If it doesn't detect a time based column, it then makes sure every entry in that column is converted into a numerical value. If both fail, an empty value, `NA`, is appended instead.

As such, this script can clean any column without being told what that column type should be.

#### Cleaning Assumptions
Please check the R script for the full logic. *TODO: expand on this*

 * `7:00-8:00 AM` is parsed as `8:00 AM`, it takes the end of the range. See TODO (8)
 * `between 7 or 8 hours` is parsed as `7.5`, the middle/mean of 7 and 8.
 * `7-8 hrs` is parsed as `7.5`, the middle/mean of 7 and 8. Note, all numeric (not time) ranges obtains the middle value.
 * `12-Oct` is parsed as `11`, the middle of 12 and 10 (as October is the 10th month in the year). We assume that Excel converted a range into a date.
 * `12/7/2017` is parsed as `9.5`, the middle of 7 and 12. We assume that Excel converted the range 7-12 into a date in the format MM/DD/YYYY
 * We assume that every answer needs to have some numerical digits. This script does not currently parse numeric information in text, see TODO (7)
 * `midnight` (when original data is converted to lower case) is parsed as `12:00 AM`
 * `all nite` and its variations are parsed as `NA` values as there are no digits present, and is also meaningless in calculating a score

### score.R
`score.R` contains the functions required to calculate the component scores. Currently, only components 2, 3 and 4 are implemented. This script only works on cleaned data columns, in the name format: `psqi*.clean` where `*` is the question number. This is the format output by `clean.R`.



## Running the tests

Unit and intergration tests have not been implemented yet, due to time constraints. This is a TODO (6)

## Deployment

Due to time constraints, a docker image was not created. TODO (9)

## Known Bugs
 1. Does not accurately parse a time if there are numbers between "am or pm". For example, `7am8` is parsed as `78:00 AM` initially which is then parsed as NA since it is not a valid time.
 2. Does not accurately parse time values if am, pm, or similar variations are not present in original data. `11:00` is parsed as `11` which turns to `11:00 PM` (or AM depending if it's a response to question 1 or 3). However, `11:30` would also turn to `11` then to `11:00 XX` hence the finer minute graduations is lost.
 3. Linked to (2), times are only accurately parsed if there is "AM" or "PM" present (or its variations). As such, military time is not accurately parsed.
 4. We assume that the input csv file is smaller than the available memory/RAM. If not, the data will not be imported, and the script will fail to exceute. TODO (5) is one possible solution, other than using a machine with more RAM.

## TODO
 1. Better documentation - more details regarding R scripts
 2. Fix time parsing to allow times not already containing an "AM" or "PM" component. Linked to bugs (2) and (3).
 3. Fix bug (1) to only extract numbers either before or after the "AM"/"PM" component. For example, `7am8` should be `7:00 AM`, while `am7` will be `7:00 AM` and `7am` is also `7:00 AM`. Currently, only `7am8` is not parsed.
 4. Vectorise inital data cleaning function for increased efficiency. Current function loops through every row and column to do a first pass of parsing. This is **VERY** inefficient in R as modify a data object in place within a loop is causing slow-downs.
 5. Implement row by row data reading and parsing to be able to parse/clean/score extremely large data files. Related to bug (4). Python and the `re` lib might be better for this than R.
 6. Create unit and integration tests.
 7. Parse numeric data in text format, eg `one hours` to `1`
 8. Parse a time range by getting the middle time, not end time, eg `7:00-8:00 AM` to `7:30 AM` not `8:00 AM`.
 9. Create a Docker image

## Built With

* [R](https://www.r-project.org/) - The R programming language

## Authors

* **Ramon Quitales** - *Initial work* - [rquitales](https://github.com/rquitales)

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details
