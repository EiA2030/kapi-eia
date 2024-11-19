# plumber.R

#* Return json with use case data
#* @param eia_code Use Case code
#* @param key authentication alphanumeric key
#* @serializer json
#* @get /use-case
function(res, req, eia_code, key) {
  keys <- read.csv("keys.csv")
  md <- read.csv("./data/clean/carob_eia_meta.csv")
  if (!(key %in% (keys$key))){
    res$status <- 401
    list("401 Unauthorized")
  } else if (!(eia_code %in% (md$usecase_code))){
    res$status <- 404
    list("404 Not Found")
  } else {
    uri <- md[md$usecase_code == eia_code, "uri"]
    uu <- do.call(carobiner::bindr,lapply(paste0("./data/clean/eia/", uri, ".csv"), read.csv))
  }
}

#* Return json with KPI use case data
#* @param eia_code Use Case code
#* @param kpi (yield,profit) Name of the KPI to compute
#* @param key authentication alphanumeric key
#* @serializer json
#* @get /kpi
function(res, req, eia_code, kpi, key) {
  keys <- read.csv("keys.csv")
  md <- read.csv("./data/clean/carob_eia_meta.csv")
  activity <- md[md$usecase_code == eia_code, "activity"]
  
  if (!(key %in% (keys$key))){
    res$status <- 401
    list(error = "Unauthorized")
  } else if (!("validation" %in% (activity))){
    res$status <- 404
    list("404 Not Found. No validation data")
  } else {
    uri <- md[md$usecase_code == eia_code & md$activity == "validation", "uri", drop = FALSE]
    uu <- read.csv(paste0("./data/clean/eia/", uri, ".csv"))
    if(kpi == "yield"){
      desired_cols <- c("country", "adm1", "adm2", "landscape_position" ,"year" , "crop",
                        "trial_id", "treatment", "yield","fwy_residue")
      existing_cols <- intersect(desired_cols, names(uu))
      k <- uu[, existing_cols, drop = FALSE]
      k
    } else if(kpi == "nue"){
      desired_cols <- c("country", "adm1", "adm2",  "landscape_position" ,"year" , "crop",
                        "trial_id", "treatment","yield", "N_fertilizer","P_fertilizer","K_fertilizer", "N_organic","P_organic","K_organic")
      #ensures you only select columns that actually exist in uu
      existing_cols <- intersect(desired_cols, names(uu))
      k <- uu[, existing_cols, drop = FALSE]
      # Replace missing columns values with zero
      #k[setdiff(desired_cols, names(k))] <- 0
      names_to_check <- c("N_fertilizer", "N_organic", "P_fertilizer", "P_organic", "K_fertilizer", "K_organic")
      # Initialize missing columns with 0
      k[names_to_check] <- lapply(names_to_check, function(name) ifelse(name %in% names(k), k[[name]], 0))
      
      #Calc KPI nutrient use efficiency values... while handling zero division
      k$NUE <- ifelse((k$N_fertilizer + k$N_organic) == 0, NA, k$yield / (k$N_fertilizer + k$N_organic))
      k$PUE <- ifelse((k$P_fertilizer + k$P_organic) == 0, NA, k$yield / (k$P_fertilizer + k$P_organic))
      k$KUE <- ifelse((k$K_fertilizer + k$K_organic) == 0, NA, k$yield / (k$K_fertilizer + k$K_organic))
      k<- k[,-which(names(k) %in% names_to_check)]
      k
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
      k<- k[,-which(names(k) %in% c("crop_price","fertilizer_price"))]
      k
    }else if(kpi == "wue"){
      desired_cols <- c("country", "adm1", "adm2", "landscape_position" ,"year" , "crop",
                        "trial_id", "treatment", "yield","irrigation_amount","rain")
      existing_cols <- intersect(desired_cols, names(uu))
      k <- uu[, existing_cols, drop = FALSE]
      # Replace missing columns values with zero
      #k[setdiff(desired_cols, names(k))] <- 0
      names_to_check <- c("irrigation_amount", "rain")
      # Initialize missing columns with 0
      k[names_to_check] <- lapply(names_to_check, function(name) ifelse(name %in% names(k), k[[name]], 0))
      k$WUE <- NA
      #Calc KPI nutrient use efficiency values... while handling zero division
      k$WUE <- ifelse((k$irrigation_amount + k$rain) == 0, NA, k$yield / (k$irrigation_amount + k$rain))
      k<- k[,-which(names(k) %in% names_to_check)]
      k
    }else if(kpi == "soc"){
      desired_cols <- c("country", "adm1", "adm2", "landscape_position" ,"year" , "crop",
                        "trial_id", "treatment", "soil_SOC")
      existing_cols <- intersect(desired_cols, names(uu))
      k <- uu[, existing_cols, drop = FALSE]
      # Replace missing columns values with zero
      k[setdiff(desired_cols, names(k))] <- NA
      k
    } else {
      res$status <- 404
      list(error = "Not Found")
    }
  }
}
