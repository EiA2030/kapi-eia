# ### DATE: August 2024 ############ 
# ### AUTHOR:

Sys.setenv(HOME="/home/kapivara")
path <- file.path(Sys.getenv("HOME"), "kapi", "eia-carob")

#Install and load required packages
install_and_load <- function(packages, repos = "http://cran.us.r-project.org") {
  # Install any packages that are not yet installed
  new_packages <- packages[!(packages %in% installed.packages()[, "Package"])]
  if (length(new_packages) > 0) {
    install.packages(new_packages, repos = repos)
  }
  
  # Load all specified packages
  invisible(sapply(packages, function(pkg) {
    suppressMessages(suppressWarnings(require(pkg, character.only = TRUE)))
  }))
}

# Define the required packages
required_packages <- c("remotes", "dplyr", "magrittr","plumber", "logger", "tictoc")

# Install and load the required packages
install_and_load(required_packages)

# install carobiner
remotes::install_github("egbendito/carobiner", force = TRUE, ask = FALSE, upgrade ="always")

carobiner:::update_terms(local_terms=file.path(path,"terms"))

# Compile
carobiner::make_carob(path)
