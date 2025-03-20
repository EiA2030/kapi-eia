#* @tag KPI-validation-Use-Case-Data
#* Get computed validation KPIs for use cases
#* Retrieve computed KPIs for all validation records in a use case. It uses metrics from [Saito et al., 2023](https://hdl.handle.net/10568/134668)<br>
#* <br>
#* `kpi` attribute should be one of:
#* <br>
#* - `yield.primary`
#* - `yield.secondary`
#* - `profit`
#* - `nue`
#* - `wue`
#* @param eia_code Use Case code
#* @param kpi Name of the KPI to compute (yield.primary, profit, nue, etc) 
#* @serializer json
#* @get /kpi-validation
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
    if(kpi == "yield.primary"){
      desired_cols <- c("country", "adm1", "landscape_position" ,"year" , "crop",
                        "trial_id", "treatment", "yield", "fw_yield", "dm_yield")
      existing_cols <- intersect(desired_cols, names(uu))
      if (any(c("yield", "fw_yield", "dm_yield") %in% existing_cols)){
        if ("yield" %in% existing_cols){
          cols <- existing_cols[!(existing_cols %in% c("fw_yield", "dm_yield"))]
        } else if ("fw_yield" %in% existing_cols){
          cols <- existing_cols[!(existing_cols %in% c("dm_yield"))]
        } else {
          cols <- existing_cols
        }
        out <- uu[, cols, drop = FALSE]
        colnames(out)[length(colnames(out))] <- "yield.primary"
        # Filter missing records
        # out <- out[!is.na(out$yield.primary), ]
        out
      } else {
        res$body <- list(response = "No data.",
                         user = usr)
        res$status <- 404
        list("404 Not Found. No primary yield KPI data.")
      }
    } else if (kpi == "yield.secondary"){
      desired_cols <- c("country", "adm1", "landscape_position" ,"year" , "crop",
                        "trial_id", "treatment", "fwy_residue", "dmy_residue")
      existing_cols <- intersect(desired_cols, names(uu))
      if (c("fwy_residue", "dmy_residue") %in% existing_cols){
        if ("fwy_residue" %in% existing_cols){
          cols <- existing_cols[!(existing_cols %in% c("dmy_residue"))]
        } else {
          cols <- existing_cols
        }
        out <- uu[, cols, drop = FALSE]
        colnames(out)[length(colnames(out))] <- "yield.secondary"
        # Filter missing records
        # out <- out[!is.na(out$yield.secondary), ]
        out
      } else {
        res$body <- list(response = "No data.",
                         user = usr)
        res$status <- 404
        list("404 Not Found. No secondary yield KPI data.")
      }
    } else if (kpi == "nue"){
      desired_cols <- c("country", "adm1", "landscape_position" ,"year" , "crop",
                        "trial_id", "treatment","yield", "fw_yield", "dm_yield",
                        "N_fertilizer","P_fertilizer","K_fertilizer", "N_organic","P_organic","K_organic")
      #ensures you only select columns that actually exist in uu
      existing_cols <- intersect(desired_cols, names(uu))
      k <- uu[, existing_cols, drop = FALSE]
      # Replace missing columns values with zero
      names_to_check <- c("N_fertilizer", "P_fertilizer", "K_fertilizer", "N_organic", "P_organic", "K_organic")
      # Initialize missing columns with 0
      k[names_to_check] <- lapply(names_to_check, function(name) {
        if (name %in% names(k)) {
          return(k[[name]])
          } else {
            return(rep(0, nrow(k)))
          }
        })
      #Calc KPI nutrient use efficiency values... while handling zero division
      k$NUE <- ifelse((k$N_fertilizer + k$N_organic) == 0, NA, k$yield / (k$N_fertilizer + k$N_organic))
      k$PUE <- ifelse((k$P_fertilizer + k$P_organic) == 0, NA, k$yield / (k$P_fertilizer + k$P_organic))
      k$KUE <- ifelse((k$K_fertilizer + k$K_organic) == 0, NA, k$yield / (k$K_fertilizer + k$K_organic))
      out <- k[,-which(names(k) %in% c(names_to_check, "yield"))]
      out
    } else if(kpi == "profit"){
      desired_cols <- c("country", "adm1", "landscape_position" ,"year" , "crop",
                        "trial_id", "treatment", "yield", "fw_yield", "dm_yield", "crop_price", "fertilizer_amount", "fertilizer_price", "currency")
      existing_cols <- intersect(desired_cols, names(uu))
      if (any(c("yield", "fw_yield", "dm_yield") %in% existing_cols)){
        if ("yield" %in% existing_cols){
          cols <- existing_cols[!(existing_cols %in% c("fw_yield", "dm_yield"))]
        } else if ("fw_yield" %in% existing_cols){
          cols <- existing_cols[!(existing_cols %in% c("dm_yield"))]
        } else {
          cols <- existing_cols
        }
        out <- uu[, cols, drop = FALSE]
        colnames(out)[grepl("_yield", colnames(out))] <- "yield"
        out$crop.revenue <- out$yield * out$crop_price
        out$fertilizer.costs <- out$fertilizer_amount * out$fertilizer_price
        #Error handling: Initialize 'profit' to NA
        out$profit <- NA
        # If both 'crop_price' and 'fertilizer_price' exist, calculate 'profit'
        if (all(c("crop_price", "fertilizer_price") %in% names(out))) {
          out$profit <- out$crop.revenue - out$fertilizer.costs
        }
        out[,-which(names(out) %in% c("yield", "crop_price", "crop.revenue", "fertilizer_amount", "fertilizer_price", "fertilizer.costs"))]
      }
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

#* @tag KPI-MELIA-Use-Case-Data
#* Get computed MELIA KPIs for use cases
#* Retrieve computed KPIs for all MELIA records in a use case. It uses metrics from [Saito et al., 2023](https://hdl.handle.net/10568/134668)<br>
#* <br>
#* `kpi` attribute should be one of:
#* <br>
#* - `yield.primary`
#* - `yield.secondary`
#* - `profit`
#* - `nue`
#* - `wue`
#* @param eia_code Use Case code
#* @param kpi Name of the KPI to compute (yield.primary, profit, nue, etc) 
#* @serializer json
#* @get /kpi-melia
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
    list("404 Not Found. No MELIA data.")
  } else {
    usr <- keys[keys$key == req$HTTP_X_API_KEY, "email"]
    res$body <- list(response = "Success!",
                     user = usr)
    uri <- md[md$usecase_code == eia_code & md$activity == "MELIA", "uri", drop = FALSE]
    uu <- read.csv(paste0("../eia-carob/data/clean/eia/", uri, ".csv"))
    if(kpi == "yield.primary"){
      desired_cols <- c("country", "adm1", "landscape_position" ,"year" , "crop",
                        "trial_id", "treatment", "yield", "fw_yield", "dm_yield")
      existing_cols <- intersect(desired_cols, names(uu))
      if (any(c("yield", "fw_yield", "dm_yield") %in% existing_cols)){
        if ("yield" %in% existing_cols){
          cols <- existing_cols[!(existing_cols %in% c("fw_yield", "dm_yield"))]
        } else if ("fw_yield" %in% existing_cols){
          cols <- existing_cols[!(existing_cols %in% c("dm_yield"))]
        } else {
          cols <- existing_cols
        }
        out <- uu[, cols, drop = FALSE]
        colnames(out)[length(colnames(out))] <- "yield.primary"
        # Filter missing records
        # out <- out[!is.na(out$yield.primary), ]
        out
      } else {
        res$body <- list(response = "No data.",
                         user = usr)
        res$status <- 404
        list("404 Not Found. No primary yield MELIA KPI data.")
      }
    } else if (kpi == "yield.secondary"){
      desired_cols <- c("country", "adm1", "landscape_position" ,"year" , "crop",
                        "trial_id", "treatment", "fwy_residue", "dmy_residue")
      existing_cols <- intersect(desired_cols, names(uu))
      if (c("fwy_residue", "dmy_residue") %in% existing_cols){
        if ("fwy_residue" %in% existing_cols){
          cols <- existing_cols[!(existing_cols %in% c("dmy_residue"))]
        } else {
          cols <- existing_cols
        }
        out <- uu[, cols, drop = FALSE]
        colnames(out)[length(colnames(out))] <- "yield.secondary"
        # Filter missing records
        # out <- out[!is.na(out$yield.secondary), ]
        out
      } else {
        res$body <- list(response = "No data.",
                         user = usr)
        res$status <- 404
        list("404 Not Found. No secondary yield MELIA KPI data.")
      }
    } else if (kpi == "nue"){
      desired_cols <- c("country", "adm1", "landscape_position" ,"year" , "crop",
                        "trial_id", "treatment","yield", "fw_yield", "dm_yield",
                        "N_fertilizer","P_fertilizer","K_fertilizer", "N_organic","P_organic","K_organic")
      #ensures you only select columns that actually exist in uu
      existing_cols <- intersect(desired_cols, names(uu))
      k <- uu[, existing_cols, drop = FALSE]
      # Replace missing columns values with zero
      names_to_check <- c("N_fertilizer", "P_fertilizer", "K_fertilizer", "N_organic", "P_organic", "K_organic")
      # Initialize missing columns with 0
      k[names_to_check] <- lapply(names_to_check, function(name) {
        if (name %in% names(k)) {
          return(k[[name]])
        } else {
          return(rep(0, nrow(k)))
        }
      })
      #Calc KPI nutrient use efficiency values... while handling zero division
      k$NUE <- ifelse((k$N_fertilizer + k$N_organic) == 0, NA, k$yield / (k$N_fertilizer + k$N_organic))
      k$PUE <- ifelse((k$P_fertilizer + k$P_organic) == 0, NA, k$yield / (k$P_fertilizer + k$P_organic))
      k$KUE <- ifelse((k$K_fertilizer + k$K_organic) == 0, NA, k$yield / (k$K_fertilizer + k$K_organic))
      out <- k[,-which(names(k) %in% c(names_to_check, "yield"))]
      out
    } else if(kpi == "profit"){
      desired_cols <- c("country", "adm1", "landscape_position" ,"year" , "crop",
                        "trial_id", "treatment", "yield", "fw_yield", "dm_yield", "crop_price", "fertilizer_amount", "fertilizer_price", "currency")
      existing_cols <- intersect(desired_cols, names(uu))
      k <- uu[, existing_cols, drop = FALSE]
      k$crop.revenue <- k$yield * k$crop_price
      k$fertilizer.costs <- k$fertilizer_amount * k$fertilizer_price
      #Error handling: Initialize 'profit' to NA
      k$profit <- NA
      # If both 'crop_price' and 'fertilizer_price' exist, calculate 'profit'
      if (all(c("crop_price", "fertilizer_price") %in% names(k))) {
        k$profit <- k$crop.revenue - k$fertilizer.costs
      }
      k[,-which(names(k) %in% c("yield", "crop_price", "crop.revenue", "fertilizer_amount", "fertilizer_price", "fertilizer.costs"))]
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

