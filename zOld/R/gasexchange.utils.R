#--------------------------------------------------------------------------------------------------#
# A set of helper functions for LiCor GE data processing
#--------------------------------------------------------------------------------------------------#

#--------------------------------------------------------------------------------------------------#
##'
##' Read settings file
##'  
##' @name settings
##' @title parse settings file used for spectra file import and processing
##' @param input.file settings file containing information needed for spectra processing
##' @export
##' @examples
##' \dontrun{
##' settings <- settings()
##' settings <- settings('/home/$USER/settings.xml')
##' }
##' 
##' @author Shawn P. Serbin
settings <- function(input.file=NULL){
  settings.xml <- NULL
  ### Parse input settings file
  if (!is.null(input.file) && file.exists(input.file)) {
    settings.xml <- xmlParse(input.file)  
    # convert the xml to a list
    settings.list <- xmlToList(settings.xml)   
  } else {
    print("***** WARNING: no settings file defined *****")
  }
  # make sure something was loaded
  if (is.null(settings.xml)) {
    #log.error("Did not find any settings file to load.")
    stop("Did not find any settings file to load.")
  }
  ### Remove comment or NULL fields
  settings.list <- settings.list[settings.list !="NULL" ]
  # Return settings file as a list
  #invisible(settings.list) # invisible option
  return(settings.list)
} ### End of function
#==================================================================================================#


#--------------------------------------------------------------------------------------------------#
##' A function to read in formatted LiCor 6400 data for processing
##' @name read.ge.data
##' @title A function to read in formatted LiCor 6400 data files.  Does some inital error
##' checking including removal of missing value flags (e.g. -99,-999,-9999,-9999.0) and
##' checking of proper data columns
##' @param file.dir
##' @param data.file Optional
##' @param QC Run QC checks on data import?  Dafault is QC=FALSE.  This is typically run
##' as part of the fitting functions.
##' 
##' @examples
##' \dontrun{
##' file.dir <- '/Users/sserbin/Data/GitHub/R-GasExchange/inst/extdata/barrow-aci.csv'
##' file.dir <- '/Users/sserbin/Data/GitHub/R-GasExchange/inst/extdata/barrow-aci-test.csv'
##' file.dir <- system.file("extdata/barrow-aci.csv",package="GasExchange")
##' ge.data <- read.ge.data(file.dir=file.dir)
##' 
##' }
##' 
##' @export
##' 
##' @author Shawn P. Serbin
read.ge.data <- function(file.dir=NULL,data.file=NULL,QC=FALSE){
  
  ### Set platform specific file path delimiter.  Probably will always be "/"
  dlm <- .Platform$file.sep # <--- What is the platform specific delimiter?
  
  print("--> Reading in LiCor data")
  
  # Check for in.dir/file or just in.dir
  check <- file.info(file.dir)
  
  if (check$isdir==FALSE | !is.null(data.file)){
    ge.data <- read.table(file.dir, header=T,sep=",")
  } else {
    ge.data <- read.table(paste(file.dir,"/",data.file,sep=""), header=T,sep=",")
  }

  # Clean up any missing data  
  ge.data[ge.data==-99] <- NA  
  ge.data[ge.data==-999] <- NA
  ge.data[ge.data==-9999] <- NA
  
  # Remove comments column
  remove <- match("COMMENTS",toupper(names(ge.data)))
  if (length(remove)>0){
    ge.data <- ge.data[,-remove]
  }
  rm(remove)

  # Check for required columns.  Order doesn't matter here.  Just looks for matching column names
  # !!Needs refinement!!
  template.names <- c("Date","Area","Tair","Tleaf","deltaT","RH_R","RH_S","VpdA","VpdL","PARi",
                      "PARo","Press","Ci_Ca","CO2R","CO2S","Photo","Cond","Ci")
  template.names.upper <- toupper(template.names)
  column.check <- toupper(template.names) %in% toupper(names(ge.data))
  if (length(which(column.check==FALSE))>0) {
    cols <- which(column.check==FALSE)
    print("Initial check of input data: FAIL")
    print("Missing Columns:")
    print(as.vector(template.names[cols]))
    stop("***Please correct error before proceeding***")
  } else {
    print("Initial check of input data: PASS")
  }
  rm(column.check)
  
  # Remove QC=1 observations.  Initial QC columns
#   qc.loc <- match("QC",toupper(names(ge.data)))
#   if (length(qc.loc)>0){
#     remove <- which(ge.data[qc.loc]==1)
#     if(length(remove)>0){
#       ge.data <- ge.data[-remove,]
#     }
#   }
#   rm(qc.loc,remove)

  # Make sure there is data in the required columns
  required <- c("Tleaf","VpdL","PARi","CO2R","CO2S","Photo","Cond","Ci")
  #required.upper <- toupper(required)
  cols <- which(toupper(names(ge.data)) %in% toupper(required))
  check <- which(is.na(ge.data[cols]))
  if (length(check)>0){
    warning("Some missing data found in required columns.  Please check that this is not an error")
    print("Proceeding for now....")
  } else {
    print("Initial check of missing data: PASS")
  }

  #op <- options(error = expression("Missing values"))
  #stopifnot(complete.cases(ge.data[cols]) != is.na(ge.data[cols]))
  #print("Missing data input dataset")
  #options(op)

  ### Find data columns and separate sample info
  template.names.2 <- toupper(c("Area","Tair","Tleaf","deltaT","RH_R","RH_S","VpdA","VpdL","PARi",
                    "PARo","Press","Ci_Ca","CO2R","CO2S","Photo","Cond","Ci"))
  keep <- match(template.names.2,toupper(names(ge.data)))
  sample.info <- ge.data[,-keep]
  ge.data.out <- ge.data[,keep]
  # Clean up sample info, remove any white spaces
  temp <- as.data.frame(lapply(sample.info,gsub,pattern=" ",replacement=""))
  sample.info <- temp
  rm(template.names.2,keep,temp)

  # return dataset
  print(" ")
  print("--> Returing dataset")
  print(" ")
  #return(ge.data)
  ### Return data and sample info
  return(list(Sample.Info=sample.info,GE.data=ge.data.out))

} ### End of function call
#==================================================================================================#


#--------------------------------------------------------------------------------------------------#
##'
##' !! NEEDS WORK !!
##'
##' QA/QC functions
##' @param data input licor data
##' @param out.dir output director for QC data and info
##' @param Cond.cutoff cutoff for low conductance. set previously
##' @param Ci.cutoff cutoff for nonsensical Cis
##' @param Tleaf.cutoff cutoff for individual Tleaf variation from mean
##' 
##' @author Shawn P. Serbin
##' 
data.qc <- function(data=NULL,out.dir=NULL,Cond.cutoff=NULL,Ci.cutoff=NULL,
                    Tleaf.cutoff=NULL){
  
  ### Remove samples not passing initial QC
  loc <- match("QC",toupper(names(data)))
  remove <- which(data[loc]==1)
  if(length(remove)>0){
    data <- data[-remove,]
  }
  rm(loc,remove)
  
  ### Remove QC and comments columns (if exists)
  pattern <- c("QC","COMMENTS")
  x <- toupper(names(data))
  remove <- match(pattern,x)
  if (length(remove)>0){
    data <- data[,-remove]
  }
  rm(pattern,x,remove)
  
  ### Find data columns
  pattern <- c("Tair","Tleaf","deltaT","RH_R","RH_S","PRESS","PARi","CO2Ref","PHOTO","COND","Ci")
  pattern <- toupper(pattern)
  x <- toupper(names(data))
  keep <- match(pattern,x)
  
  ### Extract sample info
  sample.info <- data[,-keep]
  data <- data[,keep]
  
  # Clean up sample info, remove any white spaces
  temp <- as.data.frame(lapply(sample.info,gsub,pattern=" ",replacement=""))
  sample.info <- temp
  rm(pattern,x,keep,temp)
  
  ### Apply QC filters to data
  dims <- dim(data)
  loc <- match(c("COND","CI"),toupper(names(data)))
  cond.check <- which(data[,loc[1]]<Cond.cutoff)
  ci.check <- which(data[,loc[2]]<Ci.cutoff[1] | data[,loc[2]]>Ci.cutoff[2])
  all.check <- which(data[,loc[2]]<Ci.cutoff[1] | data[,loc[2]]>Ci.cutoff[2] | data[,loc[1]]<Cond.cutoff)
  #nms <- unique(sample.info[check1,])
  nms1 <- sample.info[cond.check,]
  vals1 <- data[cond.check,loc[1]]
  nms2 <- sample.info[ci.check,]
  vals2 <- data[ci.check,loc[2]]
  
  # Tleaf check
  if (!is.null(Tleaf.cutoff)){
    temp.data <- data.frame(sample.info,data)
    # Create unique index for each sample group
    temp.data.index <- within(temp.data, indx <- as.numeric(interaction(sample.info, 
                                                                        drop=TRUE,lex.order=TRUE)))
    #Mean.Tleaf <- aggregate(Tleaf~indx,data=temp.data.index,mean)
    #Stdev.Tleaf <- aggregate(Tleaf~indx,data=temp.data.index,sd)
    #names(Mean.Tleaf) <- c("indx","Mean.Tleaf")
    #names(Stdev.Tleaf) <- c("indx","Stdev.Tleaf")
    #aggregate(Tleaf~indx,data=temp.data.index, FUN = function(x) quantile(x, probs  = c(0.05,0.95)))
    stats <- data.frame(Mean.Tleaf=aggregate(Tleaf~indx,data=temp.data.index,mean),
                        Stdev.Tleaf=aggregate(Tleaf~indx,data=temp.data.index,sd),
                        CI05=aggregate(Tleaf~indx,data=temp.data.index, 
                                       FUN = function(x) quantile(x, probs  = 0.05)),
                        CI95=aggregate(Tleaf~indx,data=temp.data.index, 
                                       FUN = function(x) quantile(x, probs  = 0.95)))
    stats <- stats[,-c(3,5,7)]
    names(stats) <- c("indx","Mean.Tleaf","Stdev.Tleaf","L05.Tleaf","U95.Tleaf")
    #temp.data2 <- merge(temp.data.index,Mean.Tleaf,by="indx",sort=F) # Preserve original order
    temp.data2 <- merge(temp.data.index,stats,by="indx",sort=F) # Preserve original order
    loc <- match(c("INDX"),toupper(names(temp.data2)))
    temp.data2 <- temp.data2[,-loc[1]]
    loc <- match(c("TLEAF","MEAN.TLEAF"),toupper(names(temp.data2)))
    Tleaf.check <- which(temp.data2[,loc[1]] < temp.data2[,loc[2]]-Tleaf.cutoff | 
                           temp.data2[,loc[1]] > temp.data2[,loc[2]]+Tleaf.cutoff)
    nms3 <- sample.info[Tleaf.check,]
    vals3 <- temp.data2[Tleaf.check,loc[1]]
    vals4 <- temp.data2[Tleaf.check,loc[2]]
    temp3 <- data.frame(nms3,Mean.Tleaf=vals4,Tleaf=vals3)
    
    # update all check flags
    all.check <- unique(c(all.check,Tleaf.check))
  } # end if
  
  ### Output QA/QC info
  temp1 <- data.frame(nms1,Cond=vals1)
  temp2 <- data.frame(nms2,Ci=vals2)
  
  if (dim(temp1)[1]>0){
    write.csv(temp1,file=paste(out.dir,"/","Failed_QC_Conductance_Check.csv",sep=""),row.names=FALSE)
  }
  if (dim(temp2)[1]>0){
    write.csv(temp2,file=paste(out.dir,"/","Failed_QC_Ci_Cutoff_Check.csv",sep=""),row.names=FALSE)
  }
  if (dim(temp3)[1]>0){
    write.csv(temp3,file=paste(out.dir,"/","Failed_QC_Temperature_Cutoff_Check.csv",sep=""),row.names=FALSE)
  }
  
  ### Remove bad data
  if (length(all.check>0)){
    data <- data[-all.check,]
    sample.info <- sample.info[-all.check,]
  }
  row.names(data) <- seq(len=nrow(data))
  row.names(sample.info) <- seq(len=nrow(sample.info))
  rm(dims,loc,cond.check,ci.check,all.check,nms1,vals1,nms2,vals2,temp1,temp2,Ci.cutoff,Cond.cutoff)
  
  ### Return QC data and sample info
  return(list(Sample.Info=sample.info,GE.data=data))
  
} # End of function
#==================================================================================================#


# =============================== Temperature Dependence Functions ================================= 


#--------------------------------------------------------------------------------------------------#
##'
##' Simple Arrhenius temperature scaling function
##' 
##' @name arrhenius.scaling
##' @title An Arrhenius temperature scaling function for temperature dependent parameters
##' @param Tleaf.1 the temperature (in degrees C) of the observation at the base temperature
##' @param Tleaf.2 the desired temperature (in degrees C) to scale the observation
##' @param Ea activation energy of the Arrhenius equation
##' @param Obs.val the value of the observation at the base temperature (i.e. Tleaf.1)
##' 
##' @examples
##' arrhenius.scaling(Tleaf.1=25,Tleaf.2=30,Ea=45.23,Obs.val=140.4)
##' 
##' # Bernacchi et al., 
##' Kc <- arrhenius.scaling(Tleaf.1=25,Tleaf.2=30,Ea=79.430,Obs.val=404.9)
##' Ko <- arrhenius.scaling(Tleaf.1=25,Tleaf.2=30,Ea=36.380,Obs.val=278.4)
##' Ko <- arrhenius.scaling(Tleaf.1=25,Tleaf.2=30,Ea=36.380,Obs.val=278.4)
##' Gamma.Star <- arrhenius.scaling(Tleaf.1=25,Tleaf.2=30,Ea=37.830,Obs.val=42.75)
##' 
##'
##' @author Shawn P. Serbin
##' 
arrhenius.scaling <- function(Tleaf.1=NULL,Tleaf.2=NULL,Ea=NULL,Obs.val=NULL){
  R <- 0.008314472        ## Ideal gas constant
  Obs.val.Tleaf2 <- Obs.val*exp((Ea*((Tleaf.2+273.15)-(Tleaf.1+273.15)))/((Tleaf.1+273.15)*R*(Tleaf.2+273.15)))
  return(Obs.val.Tleaf2)
  
  # Param25 <- x[1]
  # E <- x[2]
  #Param <- Param25*exp((E*((Tleaf+273.15)-(stand.temp+273.15)))/((stand.temp+273.15)*R*(Tleaf+273.15)))
  #RMSE <- sqrt(mean((Photo.Parameter-Param)^2))  ## RMSE cost function
  #return(RMSE)
  
} # End of function
#==================================================================================================#


####################################################################################################
### EOF.  End of R script file.              
####################################################################################################