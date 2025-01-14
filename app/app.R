library(plumber)

# logging
library(logger)

# Specify how logs are written
log_dir <- "logs"
if (!fs::dir_exists(log_dir)) fs::dir_create(log_dir)
log_appender(appender_tee(tempfile("plumber_", log_dir, ".log")))
# log_appender(appender_tee(tempfile(log_dir, "plumber_", log_dir, ".log")))

convert_empty <- function(string) {
  if (is.null(string) || is.na(string) || string == "") {
    "-"
  } else {
    string
  }
}

# Adds authentication to a given set of paths (if paths = NULL, apply to all)
add_auth <- function(x, paths = NULL) {
  
  # Adds the components element to openapi (specifies auth method)
  x[["components"]] <- list(
    securitySchemes = list(
      ApiKeyAuth = list(
        type = "apiKey",
        `in` = "header",
        name = "X-API-KEY",
        description = "Your API key goes here."
      )
    )
  )
  if (is.null(paths)) paths <- names(x$paths)
  for (path in paths) {
    nn <- names(x$paths[[path]])
    for (p in intersect(nn, c("get", "head", "post", "put", "delete"))) {
      x$paths[[path]][[p]] <- c(
        x$paths[[path]][[p]],
        list(security = list(list(ApiKeyAuth = vector())))
      )
    }
  }
  x
}

pr <- plumb("endpoints.R") %>%
  pr_set_api_spec(add_auth)

pr$registerHooks(
  list(
    preroute = function() {
      # Start timer for log info
      tictoc::tic()
    },
    postroute = function(req, res) {
      end <- tictoc::toc(quiet = TRUE)
      # Log details about the request and the response
      log_info('{convert_empty(req$REMOTE_ADDR)} "{convert_empty(req$HTTP_USER_AGENT)}" {convert_empty(req$HTTP_HOST)} {convert_empty(req$REQUEST_METHOD)} {convert_empty(req$PATH_INFO)} {convert_empty(res$body$user)} {convert_empty(req$HTTP_X_API_KEY)} {convert_empty(res$status)} {round(end$toc - end$tic, digits = getOption("digits", 5))}')
    }
  )
)

pr$run(port=8567, host = "0.0.0.0")
