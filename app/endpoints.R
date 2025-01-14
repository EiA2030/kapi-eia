#* Return json with use case data
#* @param eia_code Use Case code
#* @serializer json
#* @get /use-case
function(res, req, eia_code) {
  keys <- read.csv("secrets/keys.csv")
  md <- read.csv("../eia-carob/data/compiled/carob_eia_metadata.csv")
  
  if (!"HTTP_X_API_KEY" %in% names(req) || !(req$HTTP_X_API_KEY %in% (keys$key))) {
    res$body <- list(response = "Unauthorized.")
    res$status <- 401
    return(list(response = jsonlite::unbox("Unauthorized")))
  } else if (!(eia_code %in% (md$usecase_code))){
    usr <- keys[keys$key == req$HTTP_X_API_KEY, "email"]
    res$body <- list(response = "No data.",
                     user = usr)
    res$status <- 404
    return(list(response = jsonlite::unbox("No validation data.")))
  } else {
    usr <- keys[keys$key == req$HTTP_X_API_KEY, "email"]
    res$body <- list(response = "Success!",
                     user = usr)
    uri <- md[md$usecase_code == eia_code, "uri"]
    usr <- keys[keys$key == req$HTTP_X_API_KEY, "email"]
    return(list(jsonlite::toJSON(do.call(carobiner::bindr,lapply(paste0("../eia-carob/data/clean/eia/", uri, ".csv"), read.csv)))))
  }
}

#* Return json with KPI use case data
#* @param eia_code Use Case code
#* @param kpi (yield, profit) Name of the KPI to compute
#* @serializer json
#* @get /kpi
function(res, req, eia_code, kpi) {
  keys <- read.csv("secrets/keys.csv")
  md <- read.csv("../eia-carob/data/compiled/carob_eia_metadata.csv")
  activity <- md[md$usecase_code == eia_code, "activity"]
  
  if (!"HTTP_X_API_KEY" %in% names(req) || !(req$HTTP_X_API_KEY %in% (keys$key))) {
    res$body <- list(response = "Unauthorized.")
    res$status <- 401
    list("401 Unauthorized")
  } else if (!(eia_code %in% (md$usecase_code))){
    usr <- keys[keys$key == req$HTTP_X_API_KEY, "email"]
    res$body <- list(response = "No data.",
                     user = usr)
    res$status <- 404
    list("404 Not Found. No validation data.")
  } else {
    usr <- keys[keys$key == req$HTTP_X_API_KEY, "email"]
    res$body <- list(response = "Success!",
                     user = usr)
    uri <- md[md$usecase_code == eia_code & md$activity == "validation", "uri", drop = FALSE]
    uu <- read.csv(paste0("../eia-carob/data/clean/eia/", uri, ".csv"))
    if(kpi == "yield"){
      desired_cols <- c("country", "adm1", "adm2", "landscape_position" ,"year" , "crop",
                        "trial_id", "treatment", "yield","fwy_residue")
      existing_cols <- intersect(desired_cols, names(uu))
      uu[, existing_cols, drop = FALSE]
    } else if (kpi == "nue"){
      desired_cols <- c("country", "adm1", "adm2",  "landscape_position" ,"year" , "crop",
                        "trial_id", "treatment","yield", "N_fertilizer","P_fertilizer","K_fertilizer", "N_organic","P_organic","K_organic")
      #ensures you only select columns that actually exist in uu
      existing_cols <- intersect(desired_cols, names(uu))
      k <- uu[, existing_cols, drop = FALSE]
      # Replace missing columns values with zero
      names_to_check <- c("N_fertilizer", "N_organic", "P_fertilizer", "P_organic", "K_fertilizer", "K_organic")
      # Initialize missing columns with 0
      k[names_to_check] <- lapply(names_to_check, function(name) ifelse(name %in% names(k), k[[name]], 0))
      
      #Calc KPI nutrient use efficiency values... while handling zero division
      k$NUE <- ifelse((k$N_fertilizer + k$N_organic) == 0, NA, k$yield / (k$N_fertilizer + k$N_organic))
      k$PUE <- ifelse((k$P_fertilizer + k$P_organic) == 0, NA, k$yield / (k$P_fertilizer + k$P_organic))
      k$KUE <- ifelse((k$K_fertilizer + k$K_organic) == 0, NA, k$yield / (k$K_fertilizer + k$K_organic))
      k[,-which(names(k) %in% names_to_check)]
    } else if(kpi == "profit"){
      desired_cols <- c("country", "adm1", "adm2",  "landscape_position" ,"year" , "crop",
                        "trial_id", "treatment", "crop_price","fertilizer_price","currency")
      existing_cols <- intersect(desired_cols, names(uu))
      k <- uu[, existing_cols, drop = FALSE]
      #Error handling: Initialize 'profit' to NA
      k$profit <- NA
      # If both 'crop_price' and 'fertilizer_price' exist, calculate 'profit'
      if (all(c("crop_price", "fertilizer_price") %in% names(k))) {
        k$profit <- k$crop_price + k$fertilizer_price
      }
      k[,-which(names(k) %in% c("crop_price","fertilizer_price"))]
    } else if(kpi == "wue"){
      desired_cols <- c("country", "adm1", "adm2", "landscape_position" ,"year" , "crop",
                        "trial_id", "treatment", "yield","irrigation_amount","rain")
      existing_cols <- intersect(desired_cols, names(uu))
      k <- uu[, existing_cols, drop = FALSE]
      # Replace missing columns values with zero
      names_to_check <- c("irrigation_amount", "rain")
      # Initialize missing columns with 0
      k[names_to_check] <- lapply(names_to_check, function(name) ifelse(name %in% names(k), k[[name]], 0))
      k$WUE <- NA
      #Calc KPI nutrient use efficiency values... while handling zero division
      k$WUE <- ifelse((k$irrigation_amount + k$rain) == 0, NA, k$yield / (k$irrigation_amount + k$rain))
      k[,-which(names(k) %in% names_to_check)]
    } else if(kpi == "soc"){
      desired_cols <- c("country", "adm1", "adm2", "landscape_position" ,"year" , "crop",
                        "trial_id", "treatment", "soil_SOC")
      existing_cols <- intersect(desired_cols, names(uu))
      k <- uu[, existing_cols, drop = FALSE]
      # Replace missing columns values with zero
      k[setdiff(desired_cols, names(k))] <- NA
    } else {
      res$status <- 404
      list(error = "Not Found")
    }
  }
}
