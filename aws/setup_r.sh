#!/bin/bash

sudo dnf install R -y

# install R packages
sudo Rscript -e 'install.packages(c(
  "dplyr",
  "lubridate",
  "yaml",
  "ggplot2",
  "tidyr",
  "ggbeeswarm",
  "patchwork",
  "stringr"
  ), repos="https://cloud.r-project.org/")'
