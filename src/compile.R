
Sys.setenv(HOME="/usr/local/data")
path <- file.path(getwd())

# install carobiner
remotes::install_github("egbendito/carobiner", force = TRUE, ask = FALSE, upgrade = "never")

carobiner:::update_terms(local_terms = file.path(path, "terms"))

# Compile
carobiner::make_carob(path)
