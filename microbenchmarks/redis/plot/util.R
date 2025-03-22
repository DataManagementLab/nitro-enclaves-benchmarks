
# Function to install missing packages
install_if_missing <- function(packages) {
  installed_packages <- rownames(installed.packages())
  for (pkg in packages) {
    if (!pkg %in% installed_packages) {
      install.packages(pkg, repos = "https://cloud.r-project.org/")
    }
  }
}


# Install missing packages
required_packages <- c("dplyr", "lubridate", "yaml")
install_if_missing(required_packages)

# Load required packages
library(dplyr)
library(lubridate)
library(yaml)

# Define the base directory
data_dir <- "../results/data"
img_dir <- "../results/img"

read_and_construct_results <- function() {

  # Get subdirectories exactly 2 levels deep
  subdirs <- list.dirs(data_dir, recursive = FALSE)  # Get 1st-level subdirs
  subdirs <- list.dirs(subdirs, recursive = FALSE)   # Get 2nd-level subdirs
  subdirs <- list.dirs(subdirs, recursive = FALSE)   # Get 3rd-level subdirs

  # Construct full file paths and filter for existing and valid files
  files <- file.path(subdirs, "redis-benchmark.csv")
  files <- files[file.exists(files)]                             # exist
  files <- files[(lapply(files, read.csv) |> lapply(nrow)) > 0]  # valid

  # Early return if no files found
  if (length(files) == 0) {
    print(paste("No partial result files found in ", data_dir))
    return(data.frame())
  }

  # construct workload setups & metadata
  meta <- gsub(
    "^\\.\\./results/data/|/redis-benchmark.csv$",
    "", files
  ) |>
    strsplit("/")
  run_ids <- sapply(meta, `[[`, 3)
  setups <- sapply(meta, `[[`, 2) |> strsplit("-")
  meta <- sapply(meta, `[[`, 1) |> strsplit("-")

  # read config files
  configs <- gsub("/redis-benchmark\\.csv$", "", files)
  configs <- file.path(configs, "config.yaml")
  df_conf <- lapply(configs, read_yaml) |>
    bind_rows(.id = "id") |>
    as.data.frame() |>
    mutate(
      id = as.numeric(id),
      context = as.factor(sapply(setups, `[[`, 1)[id]),
      setup = as.factor(sapply(setups, `[[`, 2)[id]),
      instance_type = as.factor(sapply(meta, `[[`, 1)[id]),
      datetime = ymd_hms(sapply(meta, `[[`, 2)[id]),
      git_ref = sapply(meta, `[[`, 3)[id],
      run_id = run_ids[id]
    )

  # Read data files
  # -> requires all files to contain at least one row of data
  df_data <- lapply(files, read.csv) |>
    bind_rows(.id = "id") |>
    mutate(
      id = as.numeric(id),
      op = as.factor(
        sub(" .*", "", ifelse(
          grepl("^MSET", test),
          gsub("MSET \\((\\d+) keys\\)", "MSET_\\1", test, perl = TRUE),
          test
        ))
      ),
    )

  # Merge data and config
  df <- left_join(df_conf, df_data, by = "id") %>%
    subset(select = -c(id, test))

  return(df)
}

read_results <- function() {
  df <- read_and_construct_results()
  result_file <- file.path(data_dir, "results.csv")
  if (nrow(df)) {
    write.csv(df, result_file, row.names = FALSE)
    print(paste("Results re-written to", result_file))
  } else {
    df <- read.csv(result_file, stringsAsFactors = TRUE)
    print(paste("Results read from", result_file))
  }
  return(df)
}
