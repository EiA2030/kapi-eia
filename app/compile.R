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
required_packages <- c("remotes", "dplyr", "magrittr","plumber")

# Install and load the required packages
install_and_load(required_packages)

# install carobiner
remotes::install_github("reagro/carobiner", force = TRUE, ask = FALSE, upgrade ="always")

carobiner:::update_terms(local_terms=file.path(path,"terms"))

# Compile
carobiner::make_carob(path)

# Copy folder to apiworkspace
src_folder <- file.path(path,"data/clean/eia")
dest_folder <- file.path(path,"other/api/data/clean")

if (!dir.exists(dest_folder)) {
  dir.create(dest_folder, recursive = TRUE)
}
# Copy the folder using the system command
system2("cp", args = c("-r", shQuote(src_folder), shQuote(dest_folder)))


# Bind metadata files to access uri and usecase_code
md <- do.call(carobiner::bindr,lapply(paste0(file.path(path,"data/clean/eia/"),list.files(file.path(path,"data/clean/eia"), pattern = "_meta")),read.csv))
write.csv(md, file = file.path(path,"other/api/data/clean/carob_eia_meta.csv"), row.names = FALSE)

