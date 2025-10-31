#* @apiTitle Excellence in Agronomy KPI API
#* @apiDescription Endpoint for the agronomic gain key performance indicators (KPIs)used to to monitor, evaluate and measure the impact of changes in agronomic practices in the CGIAR Excellence in Agronomy initiative.
#* @apiVersion 0.1.1

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
      desired_cols <- c("country", "adm1", "adm2", "landscape_position" ,"planting_date" , "crop",
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
        # Add year
        names(out)[names(out) == 'planting_date'] <- 'year'
        out$year <- substr(out$year, 1, 4)
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
      desired_cols <- c("country", "adm1", "adm2", "landscape_position" ,"planting_date" , "crop",
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
        # Add year
        names(out)[names(out) == 'planting_date'] <- 'year'
        out$year <- substr(out$year, 1, 4)
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
      desired_cols <- c("country", "adm1", "adm2", "landscape_position" ,"planting_date" , "crop",
                        "trial_id", "treatment","yield", "fw_yield", "dm_yield",
                        "N_fertilizer","P_fertilizer","K_fertilizer", "N_organic","P_organic","K_organic")
      #ensures you only select columns that actually exist in uu
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
        # Initialize missing columns with 0
        out[c("N_fertilizer", "P_fertilizer", "K_fertilizer", "N_organic", "P_organic", "K_organic")] <- lapply(c("N_fertilizer", "P_fertilizer", "K_fertilizer", "N_organic", "P_organic", "K_organic"), function(name) {
          if (name %in% names(out)) {
            return(out[[name]])
          } else {
            return(rep(0, nrow(out)))
          }
        })
        #Calc KPI nutrient use efficiency values... while handling zero division
        out$NUE <- ifelse((out$N_fertilizer + out$N_organic) == 0, NA, out$yield / (out$N_fertilizer + out$N_organic))
        out$PUE <- ifelse((out$P_fertilizer + out$P_organic) == 0, NA, out$yield / (out$P_fertilizer + out$P_organic))
        out$KUE <- ifelse((out$K_fertilizer + out$K_organic) == 0, NA, out$yield / (out$K_fertilizer + out$K_organic))
        out <- out[,-which(names(out) %in% c("N_fertilizer", "P_fertilizer", "K_fertilizer", "N_organic", "P_organic", "K_organic", "yield"))]
        # Add year
        names(out)[names(out) == 'planting_date'] <- 'year'
        out$year <- substr(out$year, 1, 4)
        out
      }
    } else if(kpi == "profit"){
      desired_cols <- c("country", "adm1", "adm2", "landscape_position" ,"planting_date" , "crop",
                        "trial_id", "treatment", "yield", "fw_yield", "dm_yield", "crop_price", "fertilizer_amount", "fertilizer_price", "labour_price", "currency")
      existing_cols <- intersect(desired_cols, names(uu))
      if (any(c("yield", "fw_yield", "dm_yield", "crop_price") %in% existing_cols)){
        if ("yield" %in% existing_cols){
          cols <- existing_cols[!(existing_cols %in% c("fw_yield", "dm_yield"))]
        } else if ("fw_yield" %in% existing_cols){
          cols <- existing_cols[!(existing_cols %in% c("dm_yield"))]
        } else {
          cols <- existing_cols
        }
        out <- uu[, cols, drop = FALSE]
        colnames(out)[grepl("_yield", colnames(out))] <- "yield"
        if (all(c("crop_price") %in% existing_cols)){
          #Error handling: Initialize 'profit' to NA
          out$profit <- NA
          out$revenue <- out$yield * out$crop_price
          # Fertilizer and Labor
          if (all(c("fertilizer_amount", "fertilizer_price", "labour_price") %in% existing_cols)){
            out$fertilizer.costs <- out$fertilizer_amount * out$fertilizer_price
            out$costs <- out$fertilizer.costs + out$labour_price
            out$profit <- out$revenue - out$costs
          } else if(all(c("fertilizer_amount", "fertilizer_price") %in% existing_cols)) {
            # Fertilizer only
            out$fertilizer.costs <- out$fertilizer_amount * out$fertilizer_price
            out$costs <- out$fertilizer.costs
            out$profit <- out$revenue - out$costs
          } else if(all(c("labour_price") %in% existing_cols)) {
            # Labor only
            out$fertilizer.costs <- out$fertilizer_amount * out$fertilizer_price
            out$costs <- out$fertilizer.costs
            out$profit <- out$revenue - out$costs
          } else {
            # Profit only... Still missing irrigation, weeding, etc.
            out$profit <- out$revenue
          }
          # Add year
          names(out)[names(out) == 'planting_date'] <- 'year'
          out$year <- substr(out$year, 1, 4)
          
          out[,-which(names(out) %in% c("yield", "revenue", "costs", "crop_price", "crop.revenue", "fertilizer_amount", "fertilizer_price", "fertilizer.costs"))]
        } else {
          res$body <- list(response = "No data.",
                           user = usr)
          res$status <- 404
          list("404 Not Found. No profit KPI data.")
        }
      } else {
        # If there is no data...
        res$body <- list(response = "No data.",
                         user = usr)
        res$status <- 404
        list("404 Not Found. No profit KPI data.")
      }
    } else if(kpi == "wue"){
      desired_cols <- c("country", "adm1", "adm2", "landscape_position" ,"planting_date" , "crop",
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
      # Add year
      names(k)[names(k) == 'planting_date'] <- 'year'
      k$year <- substr(k$year, 1, 4)
      
      k[,-which(names(k) %in% names_to_check)]
    } else if(kpi == "soc"){
      desired_cols <- c("country", "adm1", "adm2", "landscape_position" ,"planting_date" , "crop",
                        "trial_id", "treatment", "soil_SOC")
      existing_cols <- intersect(desired_cols, names(uu))
      k <- uu[, existing_cols, drop = FALSE]
      # Add year
      names(k)[names(k) == 'planting_date'] <- 'year'
      k$year <- substr(k$year, 1, 4)
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
      desired_cols <- c("country", "adm1", "adm2", "landscape_position" ,"year" , "crop",
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
      desired_cols <- c("country", "adm1", "adm2", "landscape_position" ,"year" , "crop",
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
      desired_cols <- c("country", "adm1", "adm2", "landscape_position" ,"year" , "crop",
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
      desired_cols <- c("country", "adm1", "adm2", "landscape_position" ,"year" , "crop",
                        "trial_id", "treatment", "yield", "fw_yield", "dm_yield", "crop_price", "fertilizer_amount", "fertilizer_price", "labour_price", "currency")
      existing_cols <- intersect(desired_cols, names(uu))
      if (any(c("yield", "fw_yield", "dm_yield", "crop_price") %in% existing_cols)){
        if ("yield" %in% existing_cols){
          cols <- existing_cols[!(existing_cols %in% c("fw_yield", "dm_yield"))]
        } else if ("fw_yield" %in% existing_cols){
          cols <- existing_cols[!(existing_cols %in% c("dm_yield"))]
        } else {
          cols <- existing_cols
        }
        out <- uu[, cols, drop = FALSE]
        colnames(out)[grepl("_yield", colnames(out))] <- "yield"
        if (all(c("crop_price") %in% existing_cols)){
          #Error handling: Initialize 'profit' to NA
          out$profit <- NA
          out$revenue <- out$yield * out$crop_price
          # Fertilizer and Labor
          if (all(c("fertilizer_amount", "fertilizer_price", "labour_price") %in% existing_cols)){
            out$fertilizer.costs <- out$fertilizer_amount * out$fertilizer_price
            out$costs <- out$fertilizer.costs + out$labour_price
            out$profit <- out$revenue - out$costs
          } else if(all(c("fertilizer_amount", "fertilizer_price") %in% existing_cols)) {
            # Fertilizer only
            out$fertilizer.costs <- out$fertilizer_amount * out$fertilizer_price
            out$costs <- out$fertilizer.costs
            out$profit <- out$revenue - out$costs
          } else if(all(c("labour_price") %in% existing_cols)) {
            # Labor only
            out$fertilizer.costs <- out$fertilizer_amount * out$fertilizer_price
            out$costs <- out$fertilizer.costs
            out$profit <- out$revenue - out$costs
          } else {
            # Profit only... Still missing irrigation, weeding, etc.
            out$profit <- out$revenue
          }
          out[,-which(names(out) %in% c("yield", "revenue", "costs", "crop_price", "crop.revenue", "fertilizer_amount", "fertilizer_price", "fertilizer.costs"))]
        } else {
          res$body <- list(response = "No data.",
                           user = usr)
          res$status <- 404
          list("404 Not Found. No profit KPI data.")
        }
      } else {
        # If there is no data...
        res$body <- list(response = "No data.",
                         user = usr)
        res$status <- 404
        list("404 Not Found. No profit KPI data.")
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
