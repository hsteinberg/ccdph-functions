library(RSelenium)
library(keyring)
library(purrr)

#source("general-use-rselenium-functions.R")

#=================LOGGING INTO THE I-NEDSS PORTAL======================#

login_inedss = function(app = "I-NEDSS", username_key = "idph_username", password_key = "idph_portal"){
  
  #Navigating to log-in page
  rD$navigate("https://dph.partner.illinois.gov/my.policy")
  
  #Pause to give page time to load
  Sys.sleep(5)
  
  #Check for cookies error
  login_error <- try(rD$findElement("css", "#newSessionDIV > a:nth-child(1)"))
  if (class(login_error) != "try-error") {login_error$clickElement()}
  
  #Pause to give page time to load
  Sys.sleep(5)
  
  #Clicking link to access log-in screen
  rD$findElement("css", ".interaction_table_text_cell > a:nth-child(1)")$clickElement()
  
  #Pausing execution to give time to log in and load page
  Sys.sleep(5)
  
  #Enter credentials and log in
  rD$findElement(using = "css", value = "#input_1")$sendKeysToElement(list(key_get(username_key), key = "tab", key_get(password_key)))
  rD$findElement("css", "input[value = \"Logon\"]")$clickElement()
  
  #Pausing execution to give time to log in and load page
  Sys.sleep(10)
  
  #Mousing over applications button
  rD$findElement(using = "xpath", value = '//*[@id="zz6_RootAspMenu"]/li/ul/li[1]/a/span/span')$mouseMoveToLocation()
  
  #Finding production apps button
  rD$findElement(using = "xpath", value = '//*[@id="zz6_RootAspMenu"]/li/ul/li[1]/a')$clickElement()
  
  #Identify production apps present on page
  appsTableLinks <- rD$findElements("css", "a.dph-applink") 
  
  #Store location of INEDSS link  
  inedssLink <- map_chr(appsTableLinks, function(x) x$getElementText()[[1]]) %>%
    grepl(app, .) %>%
    which(. == TRUE)
  
  #Click INEDSS link
  appsTableLinks[[inedssLink]]$clickElement()
  
  #Pausing execution to give time to load page
  Sys.sleep(10)
  
  #Switching focus to INEDSS tab   
  windows <- rD$getWindowHandles()   
  rD$switchToWindow(windows[[2]])
  
  #Clicking login button
  if(app =="I-NEDSS"){
    rD$findElement(using = "css", value = "input[name = \"login\"]")$clickElement()
  }
  
  #Pausing execution to give time to load page
  Sys.sleep(5)
}

#ICARE LOGIN
login_icare = function(username_key = "idph_username", password_key = "idph_portal"){
  login_inedss(app = "I-CARE", username_key = username_key, password_key = password_key)
}

#==============SEARCHING FOR A NAME======================#

#Search for a case in Add/Search
search_name = function(first, last, sex, dob){
  enter_text("#first", first)
  enter_text("#last", last)
  enter_text("#sex", sex)
  enter_text("#dob", c(format(dob, "%m"),format(dob, "%d"), format(dob, "%Y")))
  Sys.sleep(1) #Adding a pause, seems to freeze a lot during search
  click("#bnameSearch")
}



#============RETURN NAME OF CURRENT PAGE==========#
#Return name of current I-NEDSS page
current_page = function(){
  rD$findElement(using = "css", value = ".pageDesc")$getElementText()[[1]] 
}

#============GET BACK TO DASHBOARD==========#
#Click on Dash Board if not already there
click_dashboard = function(){
  if(current_page() != "Dash Board"){
    click("th.dataTableNotSelected:nth-child(1) > a:nth-child(1)")
    
  }
}

#============WAIT FOR PAGE TO LOAD==========#
#Wait for a given page to load, return false if not there by end of waitTime
wait_page = function(pageName, waitTime = 90){
  #Give time to load
  c = 0
  while(try(current_page(), silent = T)!=pageName & c < waitTime){
    Sys.sleep(1)
    c = c+1
    if(c == waitTime-1){
      message("Not on page")
      return(FALSE)
    }
  }
  return(TRUE)
}

#============SEARCH STATE CASE NUMBER==========#
#Search for a state case number and go to their case summary
search_scn = function(caseNumber){
  click_dashboard()
  if(wait_page("Dash Board") == TRUE){
    enter_text("#idNumber", caseNumber)
    click("input[name = \"Search\"]")
  }
  else{
    message("Not on Dash Board")
  }
}

#============ASSIGN INVESTIGATOR==========#
#Assign an investigator
assign_investigator = function(caseNumber, investigator, overwrite = F){
  
  search_scn(caseNumber)
  wait_page("Case Summary")
  
  #Check to see if case has been transferred
  jurisdiction = get_text(".NoBorderFull > table:nth-child(1) > tbody:nth-child(1) > tr:nth-child(1) > td:nth-child(2)")
  
  if(jurisdiction != "Cook County Department of Public Health"){
    message(paste(caseNumber, "has been transferred to", jurisdiction))
    return()
  }
  
  #Check to see if case has been closed
  investigation_status = get_text("#container > div:nth-child(4) > form:nth-child(4) > table:nth-child(1) > tbody:nth-child(1) > tr:nth-child(3) > td:nth-child(1) > table:nth-child(2) > tbody:nth-child(1) > tr:nth-child(3) > td:nth-child(4)")
  if(investigation_status == "Closed" | investigation_status == "Completed - Needs Closure"){
    message(paste(caseNumber, "has been Closed"))
    return()
  }
  
  
  #Click Assign Investigator
  #click("fieldset.fieldsetHeader:nth-child(6) > table:nth-child(2) > tbody:nth-child(1) > tr:nth-child(2) > td:nth-child(1) > a:nth-child(1)")
  click_link("Assign Investigator")
  wait_page("Assign Investigator")
  
  #Investigators dropdown menu
  investigatorsMenu = rD$findElement(using = "css", value = "#investigator")
  
  #Make sure no one assigned yet
  if(overwrite == F){
    first = investigatorsMenu$findChildElements("css", "option")[[1]]
    if(first$isElementSelected() == FALSE){
      message(paste(caseNumber, "already assigned"))
      click("input[name = \"cancel\"]")
      return()
    }
  }

  
  #Assign investigator
  investigatorsList = investigatorsMenu$selectTag()$text 
  if(investigator == ""| investigator == " "){
    investigatorIndex = 1
  }else{
    investigatorIndex = which(investigatorsList == investigator)[[1]]
  }
  click(paste0("#investigator > option:nth-child(", investigatorIndex,")"))
  
  #Confirm on correct case
  if(get_text("#container > div:nth-child(4) > form:nth-child(3) > table:nth-child(1) > tbody:nth-child(1) > tr:nth-child(3) > td:nth-child(1) > table:nth-child(2) > tbody:nth-child(1) > tr:nth-child(6) > td:nth-child(1)")
     != caseNumber){
    #If case numbers don't match, cancel and give message
    message("Not in correct case")
    click("input[name = \"cancel\"]")
  }
  
  #Save
  click("input[name = \"save\"]")
  message(paste(caseNumber, "assigned to", investigator))
  
  #Close
  #click("input[value = \"Close\"]") #takes too long, don't think it's necessary
}


#===========CLICK LINK IN CASE SUMMARY PAGE=============#
#Click a Link by it's text from the Case Summary page
click_link = function(text){
  links = rD$findElements(using = "css", ".menuLink")
  link_names = sapply(1:length(links), function(x){
    link = links[[x]]
    link$getElementText()[[1]]
  })
  index = which(link_names == text)
  link = links[[index]]
  link$clickElement()
}
