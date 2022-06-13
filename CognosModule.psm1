function Update-CognosModule {
    
    <#
        .SYNOPSIS
        Update the Cognos Module from Github.

        .DESCRIPTION
        Update the Cognos Module from Github.

        .EXAMPLE
        Update-CognosModule

    #>
        
    if (-Not $(New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Error "Must run as administrator!" -ErrorAction STOP
    }
    
    $ModulePath = Get-Module CognosModule | Select-Object -ExpandProperty ModuleBase

    try {
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/carbm1/CognosModule/master/CognosModule.psd1" -OutFile "$($ModulePath)\CognosModule.psd1"
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/carbm1/CognosModule/master/CognosModule.psm1" -OutFile "$($ModulePath)\CognosModule.psm1"
    } catch {
        Throw "Failed to update module. $PSitem"
    }

}

function Set-CognosConfig {
    <#
        .SYNOPSIS
        Creates or updates a config

        .DESCRIPTION
        Creates or updates a config

        .PARAMETER ConfigName
        The friendly name for the config you are creating or updating. Will be stored at $HOME\.config\Coognos\[ConfigName].json

        .PARAMETER Username
        Your Cognos Username

        .PARAMETER espDSN
        Your school database name in Cognos.

        .EXAMPLE
        Set-CognosConfig -Username "0403cmillsap" -dsnname "gentrysms"

        .EXAMPLE
        Set-CognosConfig -ConfigName "GentryeFinance" -Username "0403cmillsap" -dsnname "gentryfms" -eFinanceUsername "cmillsap"

    #>

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", "")]
    [cmdletbinding()]
    Param(
        [parameter(Mandatory = $false)]
        [ValidateScript( {
                if ($_ -notmatch '^[a-zA-Z]+[a-zA-Z0-9]*$') {
                    throw "You must specify a ConfigName that starts with a letter and does not contain any spaces, otherwise the Configuration could break."
                } else {
                    $true
                }
            })]
        [string]$ConfigName = "DefaultConfig",
        [parameter(Mandatory = $true)][string]$username,
        [parameter(Mandatory = $false)][string]$eFinanceUsername,
        [parameter(Mandatory = $true)][string]$dsnname

    )

    #ensure the configuration folder exists under this users local home.
    if (-Not(Test-Path "$($HOME)\.config\Cognos")) {
        New-Item "$($HOME)\.config\Cognos" -ItemType Directory -Force
    }

    $CognosPassword = Read-Host -Prompt "Please provide your Cognos Password" -AsSecureString | ConvertFrom-SecureString

    $config = @{
        ConfigName = $ConfigName
        Username = $username
        eFinanceUsername = $eFinanceUsername
        dsnname = $dsnname
        password = $CognosPassword
    }

    $configPath = "$($HOME)\.config\Cognos\$($ConfigName).json"
    $config | ConvertTo-Json | Out-File $configPath -Force

}

function Show-CognosConfig {
    <#
        .SYNOPSIS
        Display saved Cognos Configurations

        .DESCRIPTION
        Display saved Cognos Configurations

        .EXAMPLE
        Show-CognosConfig

    #>
    $configs = Get-ChildItem "$($HOME)\.config\Cognos\*.json" -File

    if ($configs) {

        $configList = [System.Collections.Generic.List[PSObject]]@()
        
        $configs | ForEach-Object { 
            $config = Get-Content $PSitem.FullName | ConvertFrom-Json | Select-Object -Property ConfigName,username,eFinanceUsername,dsnname,fileName
            $config.fileName = $PSitem.FullName

            if ($config.ConfigName -ne $PSItem.BaseName) {
                Write-Error "ConfigName should match the file name. $($PSitem.FullName) is invalid."
            } else {
                $configList.Add($config)
            }
        }

        $configList | Format-Table

    } else {
        Throw "No configuration files found."
    }

}

function Remove-CognosConfig {
    <#
        .SYNOPSIS
        Remove a saved config

        .DESCRIPTION
        Remove a saved config

        .PARAMETER ConfigName
        The friendly name for the config you want to remove. Will be removed from $HOME\.config\Coognos\[ConfigName].json

        .EXAMPLE
        Remove-CognosConfig -ConfigName "Gentry"

    #>
    Param(
        [parameter(Mandatory = $true)][string]$ConfigName
    )

    if (Test-Path "$($HOME)\.config\Cognos\$($ConfigName).json") {
        Write-Host "Removing configuration file $($HOME)\.config\Cognos\$($ConfigName).json"
        Remove-Item "$($HOME)\.config\Cognos\$($ConfigName).json" -Force
    } else {
        Write-Error "No configuration file found for the provided $($ConfigName). Run Show-CognosConfig to see available configurations."
    }

}

function Update-CognosPassword {
    <#
        .SYNOPSIS
        Display saved Cognos Configurations

        .DESCRIPTION
        Display saved Cognos Configurations

        .EXAMPLE
        Show-CognosConfig

    #>
    Param(
        [parameter(Mandatory = $false)][string]$ConfigName="DefaultConfig"
    )

    if (Test-Path "$($HOME)\.config\Cognos\$($ConfigName).json") {
        $configPath = "$($HOME)\.config\Cognos\$($ConfigName).json"
        $config = Get-Content "$($HOME)\.config\Cognos\$($ConfigName).json" | ConvertFrom-Json
    } else {
        Write-Error "No configuration file found for the provided $($ConfigName). Run Show-CognosConfig to see available configurations." -ErrorAction STOP
    }

    try {
        $CognosPassword = Read-Host -Prompt "Please provide your new Cognos Password" -AsSecureString | ConvertFrom-SecureString
        $config.password = $CognosPassword
        $config | ConvertTo-Json | Out-File $configPath -Force
    } catch {
        Throw "Failed to update password. $PSItem"
    }

}

function Connect-ToCognos {
    <#
        .SYNOPSIS
        Establish a session to Cognos

        .DESCRIPTION
        Establish a session to Cognos

        .PARAMETER ConfigName
        The friendly name for the config that contains your username, dsn, eFinance username.

        .EXAMPLE
        Connect-ToCognos

        .EXAMPLE
        Connect-ToCognos -ConfigName "Gentry"
        
    #>

    Param(
        [parameter(Mandatory = $false)][string]$ConfigName = "DefaultConfig",
        [parameter(Mandatory = $false)][switch]$eFinance
    )

    $baseURL = "https://adecognos.arkansas.gov"

    #Test that configuration file exists.
    if (-Not(Test-Path "$($HOME)\.config\Cognos\$($ConfigName).json" )) {
        Write-Error "No configuration file found for the provided $($ConfigName). Run Set-CognosConfig first."
    }

    $config = Get-Content "$($HOME)\.config\Cognos\$($ConfigName).json" -ErrorAction STOP | ConvertFrom-Json
    $username = $config.username
    $efpusername = $config.eFinanceUsername
    $CognosDSN = $config.dsnname
    $password = $config.password | ConvertTo-SecureString

    $credentials = New-Object System.Management.Automation.PSCredential $username,$password

    if ($eFinance) {
        $camName = "efp"    #efp for eFinance
        $dsnparam = "spi_db_name"
        $dsnname = $CognosDSN.SubString(0,$CognosDSN.Length - 3) + 'fms'
        # if ($efpusername) {
        #     $camid = "CAMID(""efp_x003Aa_x003A$($efpusername)"")"
        # } else {
        #     $camid = "CAMID(""efp_x003Aa_x003A$($username)"")"
        # }
    } else {
        $camName = "esp"    #esp for eSchool
        $dsnparam = "dsn"
        $dsnname = $CognosDSN
        # $camid = "CAMID(""esp_x003Aa_x003A$($username)"")"
    }

    #Attempt two authentications. Sometimes Cognos just doesn't reply. [shock face goes here]
    $failedlogin = 0
    do {
        try {
            Write-Host "Authenticating and switching to $dsnname... " -ForegroundColor Yellow -NoNewline
            $response1 = Invoke-RestMethod -Uri "$($baseURL)/ibmcognos/bi/v1/login" -SessionVariable session `
            -Method "POST" `
            -ContentType "application/json; charset=UTF-8" `
            -Credential $credentials `
            -Body "{`"parameters`":[{`"name`":`"h_CAM_action`",`"value`":`"logonAs`"},{`"name`":`"CAMNamespace`",`"value`":`"$camName`"},{`"name`":`"$dsnparam`",`"value`":`"$dsnname`"}]}" 

            Write-Host "Success." -ForegroundColor Yellow

            #Set the $CognosSession variable globally. This allows us to reference them in the Get-CognosReport.
            $global:CognosSession = $session
            $global:CognosProfile = $ConfigName
            $global:CognosDSN = $dsnname
            $global:CognoseFPUsername = $efpusername
            $global:CognosUsername = $username

        } catch {
            $failedlogin++            
            if ($failedlogin -ge 2) {
                Write-Error "Unable to authenticate and switch into $dsnname. $($_)" -ErrorAction STOP
            } else {
                #Unfortuantely we are still having an issue authenticating to Cognos. So we need to make another attemp after a random number of seconds.
                Write-Host "Failed to authenticate. Attempting again..." -ForegroundColor Red
                Remove-Variable -Name session
                Start-Sleep -Seconds (Get-Random -Maximum 15 -Minimum 5)
            }
        }
    } until ($session)

}

function Get-CognosReport {
    <#
        .SYNOPSIS
        Returns a Cognos Report as an object

        .DESCRIPTION
        Returns a Cognos Report as an object

        .EXAMPLE
        Get-CognosReport -report schools -cognosfolder "_Shared Data File Reports\Clever Files" -TeamContent

        .EXAMPLE
        Get-CognosReport -report schools -cognosfolder "_Shared Data File Reports\Clever Files" -TeamContent | Export-CSV -Path "schools.csv" -UseQuotes AsNeeded

        .EXAMPLE
        Get-CognosReport -report advisors -raw | Out-File advisors.csv
    #>

    [CmdletBinding(DefaultParametersetName="default")]
    Param(
        [parameter(Mandatory=$true,HelpMessage="Give the name of the report you want to download.",ParameterSetName="Default")]
            [string]$report,
        [parameter(Mandatory=$false,HelpMessage="Cognos Folder Structure.",ParameterSetName="Default")]
            [string]$cognosfolder = "My Folders", #Cognos Folder "Folder 1/Sub Folder 2/Sub Folder 3" NO TRAILING SLASH
        [parameter(Mandatory=$false,HelpMessage="Report Parameters",ParameterSetName="Default")]
            [string]$reportparams, #If a report requires parameters you can specifiy them here. Example:"p_year=2017&p_school=Middle School"
        [parameter(Mandatory=$false,ParameterSetName="Default")]
            [string]$XMLParameters, #Path to XML for answering prompts.
        [parameter(Mandatory=$false,ParameterSetName="Default")]
            [switch]$SavePrompts, #Interactive submitting and saving of complex prompts.
        [parameter(Mandatory=$false,ParameterSetName="Default")] #How long in minutes are you willing to let CognosDownloader run for said report? 5 mins is default and gives us a way to error control.
            [int]$Timeout = 5,
        [parameter(Mandatory=$false,ParameterSetName="Default")] #This will dump the raw CSV data to the terminal.
            [switch]$Raw,
        [parameter(Mandatory=$false,ParameterSetName="Default")] #If the report is in the Team Content folder we have to switch paths.
            [switch]$TeamContent,
        [parameter(Mandatory=$false,ParameterSetName="conversation")] #Provide a conversationID if you already started one via Start-CognosReport
            $conversationID
    )

    try {
        
        $startTime = Get-Date

        #If the conversationID has already been supplied then we will use that.
        if (-Not($conversationID)) {
            $conversation = Start-CognosReport @PSBoundParameters
            $conversationID = $conversation.conversationID
        }

        $baseURL = "https://adecognos.arkansas.gov"

        #Attempt first download.
        Write-Verbose "$($baseURL)/ibmcognos/bi/v1/disp/rds/sessionOutput/conversationID/$($conversationID)?v=3&async=MANUAL"
        $response = Invoke-RestMethod -Uri "$($baseURL)/ibmcognos/bi/v1/disp/rds/sessionOutput/conversationID/$($conversationID)?v=3&async=MANUAL" -WebSession $CognosSession -ErrorAction STOP
                
        #This would indicate a generic failure or a prompt failure.
        if ($response.error) {
            $errorResponse = $response.error
            Write-Error "$($errorResponse.message)"

            if ($errorResponse.promptID) {

                $promptid = $errorResponse.promptID

                #The report ID is included in the prompt response.
                $errorResponse.url -match 'storeID%28%22(.{33})%22%29' | Out-Null
                $reportId = $Matches.1

                #Expecting prompts. Lets see if we can find them.
                $promptsConversation = Invoke-RestMethod -Uri "$($baseURL)/ibmcognos/bi/v1/disp/rds/reportPrompts/report/$($reportID)?v=3&async=MANUAL" -WebSession $CognosSession
                $prompts = Invoke-WebRequest -Uri "$($baseURL)/ibmcognos/bi/v1/disp/rds/sessionOutput/conversationID/$($promptsConversation.receipt.conversationID)?v=3&async=MANUAL" -WebSession $CognosSession
                Write-Error "This report expects the following prompts:"

                Select-Xml -Xml ([xml]$prompts.Content) -XPath '//x:pname' -Namespace @{ x = "http://www.ibm.com/xmlns/prod/cognos/layoutData/201310" } | ForEach-Object {
                    
                    $promptname = $PSItem.Node.'#text'
                    Write-Host "p_$($promptname)="

                    if (Select-Xml -Xml ([xml]$prompts.Content) -XPath '//x:p_value' -Namespace @{ x = "http://www.ibm.com/xmlns/prod/cognos/layoutData/200904" }) {
                        $promptvalues = Select-Xml -Xml ([xml]$prompts.Content) -XPath '//x:p_value' -Namespace @{ x = "http://www.ibm.com/xmlns/prod/cognos/layoutData/200904" } | Where-Object { $PSItem.Node.pname -eq $promptname }
                        if ($promptvalues.Node.selOptions.sval) {
                            $promptvalues.Node.selOptions.sval
                        }
                    }

                }

                Write-Host "Info: If you want to save prompts please run the script again with the -SavePrompts switch."

                if ($SavePrompts) {
                    
                    Write-Host "`r`nInfo: For complex prompts you can submit your prompts at the following URL. You must have a browser window open and signed into Cognos for this URL to work." -ForegroundColor Yellow
                    Write-Host ("$($baseURL)" + ([uri]$errorResponse.url).PathAndQuery) + "`r`n"
                    
                    $promptAnswers = Read-Host -Prompt "After you have followed the link above and finish the prompts, would you like to download the responses for later use? (y/n)"

                    if (@('Y','y') -contains $promptAnswers) {
                        Write-Host "Info: Saving Report Responses to $($reportID).xml to be used later." -ForegroundColor Yellow
                        Invoke-WebRequest -Uri "$($baseURL)/ibmcognos/bi/v1/disp/rds/promptAnswers/conversationID/$($promptid)?v=3&async=OFF" -WebSession $CognosSession -OutFile "$($reportID).xml"
                        Write-Host "Info: You will need to rerun this script to download the report using the saved prompts." -ForegroundColor Yellow

                        $promptXML = [xml]((Get-Content "$($reportID).xml") -replace ' xmlns:rds="http://www.ibm.com/xmlns/prod/cognos/rds/types/201310"','' -replace 'rds:','')
                        $promptXML.promptAnswers.promptValues | ForEach-Object {
                            $promptname = $PSItem.name
                            $PSItem.values.item.SimplePValue.useValue | ForEach-Object {
                                Write-Host "&p_$($promptname)=$($PSItem)"
                            }
                        }
                        
                    }
                }
            }

            Throw "This report requires prompts."

        } elseif ($response.receipt) { #task is still in a working status
            
            Write-Host "`r`nInfo: Report is still working." -ForegroundColor Yellow
            Start-Sleep -Milliseconds 500 #Cognos is stupid fast sometimes but not so fast that we can make another query immediately.
            
            #The Cognos Server has started randomly timing out, 502 bad gateway, or TLS errors. We need to allow at least 3 errors becuase its not consistent.
            $errorResponse = 0
            do {

                if ((Get-Date) -gt $startTime.AddMinutes($Timeout)) {
                    Write-Error "Timeout of $Timeout met. Exiting." -ErrorAction STOP
                }

                try {
                    $response2 = Invoke-RestMethod -Uri "$($baseURL)/ibmcognos/bi/v1/disp/rds/sessionOutput/conversationID/$($conversationID)?v=3&async=AUTO" -WebSession $CognosSession
                    $errorResponse = 0 #reset error response counter. We want three in a row, not three total.
                } catch {
                    #on failure $response2 is not overwritten.
                    $errorResponse++ #increment error response counter.
                    #we have failed 3 times.
                    if ($errorResponse -ge 3) {
                        Write-Error "Failed to download file. $($PSitem)" -ErrorAction STOP
                    }

                    Start-Sleep -Seconds (Get-Random -Minimum 2 -Maximum 10) #Lets wait just a bit longer to see if its a timing issue.
                }

                if ($response2.receipt.status -eq "working") {
                    Write-Host '.' -NoNewline -ForegroundColor Yellow
                    Start-Sleep -Seconds 2
                }

                Write-Verbose "$($response2.receipt.status)"

            } until ($response2.receipt.status -ne "working")

            #Return the actual data.
            try {
                if ($Raw) {
                    return [System.Text.Encoding]::UTF8.GetString([System.Text.Encoding]::GetEncoding(28591).GetBytes($response2))
                } else {
                    return [System.Text.Encoding]::UTF8.GetString([System.Text.Encoding]::GetEncoding(28591).GetBytes($response2)) | ConvertFrom-Csv
                }
            } catch {
                Throw "Unable to convert encoding on downloaded file to an object or the object is empty."
            }

        } else {
            #we did not get a prompt page or an error so we should be able to output to disk.
            
            Write-Verbose "$($response.receipt.status)"

            try {
                if ($Raw) {
                    return [System.Text.Encoding]::UTF8.GetString([System.Text.Encoding]::GetEncoding(28591).GetBytes($response))
                } else {
                    return [System.Text.Encoding]::UTF8.GetString([System.Text.Encoding]::GetEncoding(28591).GetBytes($response)) | ConvertFrom-Csv
                }
            } catch {
                Throw "Unable to convert encoding on downloaded file to an object or the object is empty."
            }     
        }

    } catch {
        Write-Error "$($PSItem)" -ErrorAction STOP
    }

}

function Save-CognosReport {
    <#
        .SYNOPSIS
        Save a Cognos Report to disk

        .DESCRIPTION
        Save a Cognos Report to disk

        .EXAMPLE
        Save-CognosReport -report schools -cognosfolder "_Shared Data File Reports\Clever Files" -TeamContent

        .EXAMPLE
        Save-CognosReport -report schools -cognosfolder "_Shared Data File Reports\Clever Files" -TeamContent -savepath "c:\scripts"

        .EXAMPLE
        Save-CognosReport -report advisors
        #Will save to the current folder.

    #>

    [CmdletBinding(DefaultParametersetName="default")]
    Param(
        [parameter(Mandatory=$true,HelpMessage="Give the name of the report you want to download.",ParameterSetName="default")]
            [string]$report,
        [parameter(Mandatory=$false,HelpMessage="Format you want to download report as.",ParameterSetName="default")]
        [parameter(Mandatory=$false,HelpMessage="Format you want to download report as.",ParameterSetName="conversation")]
            [ValidateSet("csv","xlsx","pdf")]
            [string]$extension="csv",
        [parameter(Mandatory=$false,HelpMessage="Override filename. Must include the extension.",ParameterSetName="default")]
        [parameter(Mandatory=$false,HelpMessage="Override filename. Must include the extension.",ParameterSetName="conversation")]
            [string]$filename = "$($report).$($extension)",
        [parameter(Mandatory=$false,HelpMessage="Folder to save report to.",ParameterSetName="default")]
        [parameter(Mandatory=$false,HelpMessage="Folder to save report to.",ParameterSetName="conversation")]
            [ValidateScript( {
                if ([System.IO.Directory]::Exists("$PSitem")) {
                    $True
                } else {
                    Throw "Unable to find folder $PSItem"
                }
            })]
            [string]$savepath = (Get-Location).Path,
        [parameter(Mandatory=$false,HelpMessage="Cognos Folder Structure.",ParameterSetName="default")]
        [parameter(Mandatory=$false,HelpMessage="Cognos Folder Structure.",ParameterSetName="conversation")]
            [string]$cognosfolder = "My Folders", #Cognos Folder "Folder 1/Sub Folder 2/Sub Folder 3" NO TRAILING SLASH
        [parameter(Mandatory=$false,HelpMessage="Report Parameters",ParameterSetName="default")]
        [parameter(Mandatory=$false,HelpMessage="Report Parameters",ParameterSetName="conversation")]
            [string]$reportparams, #If a report requires parameters you can specifiy them here. Example:"p_year=2017&p_school=Middle School"
        [parameter(Mandatory=$false,ParameterSetName="default")]
        [parameter(Mandatory=$false,ParameterSetName="conversation")]
            [string]$XMLParameters, #Path to XML for answering prompts.
        [parameter(Mandatory=$false,ParameterSetName="default")]
        [parameter(Mandatory=$false,ParameterSetName="conversation")]
            [switch]$SavePrompts, #Interactive submitting and saving of complex prompts.
        [parameter(Mandatory=$false,ParameterSetName="default")] #How long in minutes are you willing to let CognosDownloader run for said report? 5 mins is default and gives us a way to error control.
        [parameter(Mandatory=$false,ParameterSetName="conversation")]
            [int]$Timeout = 5,
        [parameter(Mandatory=$false,ParameterSetName="default")] #If the report is in the Team Content folder we have to switch paths.
        [parameter(Mandatory=$false,ParameterSetName="conversation")]
            [switch]$TeamContent,
        [parameter(Mandatory=$false,ParameterSetName="default")] #Remove Spaces in CSV files. This requires Powershell 7.1+
        [parameter(Mandatory=$false,ParameterSetName="conversation")]
            [switch]$TrimCSVWhiteSpace,
        [parameter(Mandatory=$false,ParameterSetName="default")] #If you Trim CSV White Space do you want to wrap everything in quotes?
        [parameter(Mandatory=$false,ParameterSetName="conversation")]
            [switch]$CSVUseQuotes,
        [parameter(Mandatory=$false,ParameterSetName="default")] #If you need to download the same report multiple times but with different parameters we have to use a random temp file so they don't conflict.
        [parameter(Mandatory=$false,ParameterSetName="conversation")]    
            [switch]$RandomTempFile,
        [parameter(Mandatory=$true,ParameterSetName="conversation")] #Provide a conversationID if you already started one via Start-CognosReport
            $conversationID
    )

    

    $baseURL = "https://adecognos.arkansas.gov"
    $fullFilePath = Join-Path -Path "$savepath" -ChildPath "$filename"
    $progressPreference = 'silentlyContinue'

    try{

        #If the conversationID has already been supplied then we will use that.
        if (-Not($conversationID)) {
            $conversation = Start-CognosReport @PSBoundParameters
            $conversationID = $conversation.conversationID
        }

        #We need a predicatable save path name but not one that overwrites the final file name. So we will take a hash of the report name. Once the file is verified it will be
        #copied to its final location overwriting the existing file.
        if ($RandomTempFile) {
            $reportIDHash = (New-Guid).Guid.ToString()
        } else {   
            $reportIDHash = (Get-FileHash -InputStream ([System.IO.MemoryStream]::New([System.Text.Encoding]::ASCII.GetBytes($report)))).Hash
        }

        $reportIDHashFilePath = Join-Path -Path "$(Split-Path $fullFilePath)" -ChildPath "$($reportIDHash)"

        Write-Verbose $filename
        Write-Verbose $fullFilePath
        Write-Verbose $savepath
        Write-Verbose $reportIDHashFilePath

        #At this point we have our conversationID that we can use to query for if the report is done or not. If it is still running it will return an XML response with reciept.status = working.
        #The problem now is that Cognos decides to either reply with the actual file or another receipt. Since we can't decipher which one prior to our next request we need to check for possible
        #values in the XML reponse.

        #Attempt first download.
        Invoke-WebRequest -Uri "$($baseURL)/ibmcognos/bi/v1/disp/rds/sessionOutput/conversationID/$($conversationID)?v=3&async=MANUAL" -WebSession $CognosSession -OutFile "$reportIDHashFilePath" -ErrorAction STOP
        
        try {
            $response2 = [XML](Get-Content $reportIDHashFilePath)
        } catch {}

        #This would indicate a generic failure or a prompt failure.
        if ($response2.error) {
            $errorResponse = $response2.error
            Write-Error "$($errorResponse.message)"

            if ($errorResponse.promptID) {

                $promptid = $errorResponse.promptID

                #The report ID is included in the prompt response.
                $errorResponse.url -match 'storeID%28%22(.{33})%22%29' | Out-Null
                $reportId = $Matches.1

                #Expecting prompts. Lets see if we can find them.
                $promptsConversation = Invoke-RestMethod -Uri "$($baseURL)/ibmcognos/bi/v1/disp/rds/reportPrompts/report/$($reportID)?v=3&async=MANUAL" -WebSession $CognosSession
                $prompts = Invoke-WebRequest -Uri "$($baseURL)/ibmcognos/bi/v1/disp/rds/sessionOutput/conversationID/$($promptsConversation.receipt.conversationID)?v=3&async=MANUAL" -WebSession $CognosSession
                Write-Error "This report expects the following prompts:"

                Select-Xml -Xml ([xml]$prompts.Content) -XPath '//x:pname' -Namespace @{ x = "http://www.ibm.com/xmlns/prod/cognos/layoutData/201310" } | ForEach-Object {
                    
                    $promptname = $PSItem.Node.'#text'
                    Write-Host "p_$($promptname)="

                    if (Select-Xml -Xml ([xml]$prompts.Content) -XPath '//x:p_value' -Namespace @{ x = "http://www.ibm.com/xmlns/prod/cognos/layoutData/200904" }) {
                        $promptvalues = Select-Xml -Xml ([xml]$prompts.Content) -XPath '//x:p_value' -Namespace @{ x = "http://www.ibm.com/xmlns/prod/cognos/layoutData/200904" } | Where-Object { $PSItem.Node.pname -eq $promptname }
                        if ($promptvalues.Node.selOptions.sval) {
                            $promptvalues.Node.selOptions.sval
                        }
                    }

                }

                Write-Host "Info: If you want to save prompts please run the script again with the -SavePrompts switch."

                if ($SavePrompts) {
                    
                    Write-Host "`r`nInfo: For complex prompts you can submit your prompts at the following URL. You must have a browser window open and signed into Cognos for this URL to work." -ForegroundColor Yellow
                    Write-Host ("$($baseURL)" + ([uri]$errorResponse.url).PathAndQuery) + "`r`n"
                    
                    $promptAnswers = Read-Host -Prompt "After you have followed the link above and finish the prompts, would you like to download the responses for later use? (y/n)"

                    if (@('Y','y') -contains $promptAnswers) {
                        Write-Host "Info: Saving Report Responses to $($reportID).xml to be used later." -ForegroundColor Yellow
                        Invoke-WebRequest -Uri "$($baseURL)/ibmcognos/bi/v1/disp/rds/promptAnswers/conversationID/$($promptid)?v=3&async=OFF" -WebSession $CognosSession -OutFile "$($reportID).xml"
                        Write-Host "Info: You will need to rerun this script to download the report using the saved prompts." -ForegroundColor Yellow

                        $promptXML = [xml]((Get-Content "$($reportID).xml") -replace ' xmlns:rds="http://www.ibm.com/xmlns/prod/cognos/rds/types/201310"','' -replace 'rds:','')
                        $promptXML.promptAnswers.promptValues | ForEach-Object {
                            $promptname = $PSItem.name
                            $PSItem.values.item.SimplePValue.useValue | ForEach-Object {
                                Write-Host "&p_$($promptname)=$($PSItem)"
                            }
                        }
                        
                    }
                }
            }

            Throw "This report requires prompts."

        } elseif ($response2.receipt) { #task is still in a working status
            
            Write-Host "`r`nInfo: Report is still working."
            Start-Sleep -Milliseconds 500 #Cognos is stupid fast sometimes but not so fast that we can make another query immediately.
            
            #The Cognos Server has started randomly timing out, 502 bad gateway, or TLS errors. We need to allow at least 3 errors becuase its not consistent.
            $errorResponse = 0
            do {

                if ((Get-Date) -gt $startTime.AddMinutes($Timeout)) {
                    Write-Error "Timeout of $Timeout met. Exiting." -ErrorAction STOP
                }

                try {
                    Invoke-WebRequest -Uri "$($baseURL)/ibmcognos/bi/v1/disp/rds/sessionOutput/conversationID/$($conversationID)?v=3&async=AUTO" -WebSession $CognosSession -OutFile "$reportIDHashFilePath"
                    $errorResponse = 0 #reset error response counter. We want three in a row, not three total.
                } catch {
                    #on failure $response3 is not overwritten.
                    $errorResponse++ #increment error response counter.
                    #we have failed 3 times.
                    if ($errorResponse -ge 3) {
                        Write-Error "Failed to download file. $($PSitem)" -ErrorAction STOP
                    }

                    Start-Sleep -Seconds (Get-Random -Minimum 2 -Maximum 10) #Lets wait just a bit longer to see if its a timing issue.
                }

                try {
                    $response3 = [XML](Get-Content $reportIDHashFilePath)
                } catch {}

                if ($response3.receipt.status -eq "working") {
                    Write-Host '.' -NoNewline
                    Start-Sleep -Seconds 2
                }

            } until ($response3.receipt.status -ne "working")

            #We should have the actual file now. We need to test if a previous file exists and back it up first.
            if (Test-Path $fullFilePath) {
                $backupFileName = Join-Path -Path (Split-Path $fullFilePath) -ChildPath ((Split-Path -Leaf $fullFilePath) + '.bak')
                Write-Host "Info: Backing up $($fullFilePath) to $($backupFileName)" -ForegroundColor Yellow
                Move-Item -Path $fullFilePath -Destination $backupFileName -Force
            }

            Write-Host "Info: Saving to $($fullfilePath)" -ForeGroundColor Yellow

            if ($extension -eq "csv" -and $TrimCSVWhiteSpace) {
                $trimmedValues = Import-Csv -Path $reportIDHashFilePath
                $trimmedValues | Foreach-Object {  
                    $_.PSObject.Properties | Foreach-Object {
                        $_.Value = $_.Value.Trim()
                    }
                }

                if ($CSVUseQuotes) {
                    Write-Host "Info: Exporting CSV using quotes." -ForegroundColor Yellow
                    $trimmedValues | Export-Csv -UseQuotes Always -Path $fullfilepath -Force
                } else {
                    $trimmedValues | Export-Csv -UseQuotes AsNeeded -Path $fullfilepath -Force
                }
                
                Remove-Item -Path $reportIDHashFilePath -Force

            } else {
                Move-Item -Path $reportIDHashFilePath -Destination $fullFilePath -Force
            }

        } else {
            
            #No prompt page. Move forward.
            if (Test-Path $fullFilePath) {
                $backupFileName = Join-Path -Path (Split-Path $fullFilePath) -ChildPath ((Split-Path -Leaf $fullFilePath) + '.bak')
                Write-Host "Info: Backing up $($fullFilePath) to $($backupFileName)" -ForegroundColor Yellow
                Move-Item -Path $fullFilePath -Destination $backupFileName -Force
            }

            Write-Host "Info: Saving to $($fullfilePath)" -ForeGroundColor Yellow

            #if specified lets clean up the file.
            if ($extension -eq "csv" -and $TrimCSVWhiteSpace) {
                $trimmedValues = Import-Csv -Path $reportIDHashFilePath
                $trimmedValues | Foreach-Object {  
                    $_.PSObject.Properties | Foreach-Object {
                        $_.Value = $_.Value.Trim()
                    }
                }

                if ($CSVUseQuotes) {
                    Write-Host "Info: Exporting CSV using quotes." -ForegroundColor Yellow
                    $trimmedValues | Export-Csv -UseQuotes Always -Path $fullFilePath -Force
                } else {
                    $trimmedValues | Export-Csv -UseQuotes AsNeeded -Path $fullFilePath -Force
                }

                Remove-Item -Path $reportIDHashFilePath -Force

            } else {
                Move-Item -Path $reportIDHashFilePath -Destination $fullFilePath -Force
            }

        }
        

    } catch {
        Write-Error "$($_)" -ErrorAction STOP
    }

}

function Start-CognosReport {
    <#
        .SYNOPSIS
        Run a Cognos Report on the server and return a Conversation ID to be retrieved later.

        .DESCRIPTION
        Run a Cognos Report on the server and return a Conversation ID to be retrieved later.

        .EXAMPLE
        Start-CognosReport -report schools -cognosfolder "_Shared Data File Reports\Clever Files" -TeamContent

    #>

    #Start-CognosReport must have all parameters that Get-CognosReport and Save-CognosReport has.
    Param(
        [parameter(Mandatory=$true,HelpMessage="Give the name of the report you want to download.")]
            [string]$report,
        [parameter(Mandatory=$false,HelpMessage="Format you want to download report as.")]
            [ValidateSet("csv","xlsx","pdf")]
            [string]$extension="csv",
        [parameter(Mandatory=$false,HelpMessage="Override filename. Must include the extension.")]
            [string]$filename = "$($report).$($extension)",
        [parameter(Mandatory=$false,HelpMessage="Folder to save report to.")]
            [string]$savepath = (Get-Location).Path,
        [parameter(Mandatory=$false,HelpMessage="Cognos Folder Structure.")]
            [string]$cognosfolder = "My Folders", #Cognos Folder "Folder 1/Sub Folder 2/Sub Folder 3" NO TRAILING SLASH
        [parameter(Mandatory=$false,HelpMessage="Report Parameters")]
            [string]$reportparams, #If a report requires parameters you can specifiy them here. Example:"p_year=2017&p_school=Middle School"
        [parameter(Mandatory=$false)]
            [string]$XMLParameters, #Path to XML for answering prompts.
        [parameter(Mandatory=$false)]
            [switch]$SavePrompts, #Interactive submitting and saving of complex prompts.
        [parameter(Mandatory=$false)] #How long in minutes are you willing to let CognosDownloader run for said report? 5 mins is default and gives us a way to error control.
            [int]$Timeout = 5,
        [parameter(Mandatory=$false)] #If the report is in the Team Content folder we have to switch paths.
            [switch]$TeamContent,
        [parameter(Mandatory=$false)] #Remove Spaces in CSV files. This requires Powershell 7.1+
            [switch]$TrimCSVWhiteSpace,
        [parameter(Mandatory=$false)] #If you Trim CSV White Space do you want to wrap everything in quotes?
            [switch]$CSVUseQuotes,
        [parameter(Mandatory=$false)] #If you need to download the same report multiple times but with different parameters we have to use a random temp file so they don't conflict.
            [switch]$RandomTempFile,
        [parameter(Mandatory=$false)]
            [switch]$Raw,
        [parameter(Mandatory=$false)] #provide a name for the report so it can be returned with the ConverstationID.
            [string]$JobName = $report
    )

    $baseURL = "https://adecognos.arkansas.gov"
    $progressPreference = 'silentlyContinue'

    if (-Not($CognosSession)) {
        if ($CognosProfile) {
            Connect-ToCognos -ConfigName $CognosProfile
        } else {
            Connect-ToCognos
        }
    }

    #if the dsn name ends in fms then set eFinance to $True.
    if ($CognosDSN.Substring($CognosDSN.Length -3) -eq 'fms') {
        $eFinance = $True
    }

    #To measure for a timeout.
    $startTime = Get-Date

    if ($eFinance) {
        $camName = "efp" #efp for eFinance
        $dsnparam = "spi_db_name"
        $dsnname = $CognosDSN.SubString(0,$CognosDSN.Length - 3) + 'fms'
        if ($CognoseFPUsername) {
            $camid = "CAMID(""efp_x003Aa_x003A$($CognoseFPUsername)"")"
        } else {
            $camid = "CAMID(""efp_x003Aa_x003A$($CognosUsername)"")"
        }
    } else {
        $camName = "esp"    #esp for eSchool
        $dsnparam = "dsn"
        $dsnname = $CognosDSN
        $camid = "CAMID(""esp_x003Aa_x003A$($CognosUsername)"")"
    }

    #Do not use UrlEncode here. The only character that must be encoded is the space so we have to use a Replace.
    if ($cognosfolder -eq "My Folders") {
        $cognosfolder = "$($camid)/My Folders"
    } elseif ($TeamContent) {
        if ($eFinance) {
            $cognosfolder = "Team Content/Financial Management System/$($cognosfolder)"
        } else {
            $cognosfolder = "Team Content/Student Management System/$($cognosfolder)"
        }
    } else {
        $cognosfolder = "$($camid)/My Folders/$($cognosfolder)"
    }

    #Do not use UrlEncode here. The only character that must be encoded is the space so we have to use a Replace.
    $cognosfolder = $cognosfolder.Replace(' ','%20')

    switch ($extension) {
        "pdf" { $rdsFormat = "PDF" }
        "csv" { $rdsFormat = "CSV" }
        "xlsx" { $rdsFormat = "spreadsheetML" }
    }

    $downloadURL = "$($baseURL)/ibmcognos/bi/v1/disp/rds/outputFormat/path/$($cognosfolder)/$($report)/$($rdsFormat)?v=3&async=MANUAL"

    if ($reportparams -ne '') {
        $downloadURL = $downloadURL + '&' + $reportparams
    }

    Write-Verbose $downloadURL

    #Complex parameters require an XML file to work properly. The path must be specified when invoking this module.
    if ($XMLParameters -ne '') {
        if (Test-Path "$XMLParameters") {
            Write-Verbose "Using $($XMLParameters) for report prompts."
            $reportParamXML = (Get-Content "$XMLParameters") -replace ' xmlns:rds="http://www.ibm.com/xmlns/prod/cognos/rds/types/201310"','' -replace 'rds:','' -replace '<','%3C' -replace '>','%3E' -replace '/','%2F'
            $promptXML = [xml]((Get-Content "$XMLParameters") -replace ' xmlns:rds="http://www.ibm.com/xmlns/prod/cognos/rds/types/201310"','' -replace 'rds:','')
            $downloadURL = $downloadURL + '&xmlData=' + $reportParamXML
        } else {
            Write-Error "The XML parameters file $XMLParameters can not be found." -ErrorAction STOP
        }
    }

    #if you specify -verbose this information will be output to the terminal.
    if ($promptXML) {
        Write-Verbose "Info: You can customize your prompts by changing any of the following fields and using the -reportparams parameter."
        $promptXML.promptAnswers.promptValues | ForEach-Object {
            $promptname = $PSItem.name
            $PSItem.values.item.SimplePValue.useValue | ForEach-Object {
                Write-Verbose ("&p_$($promptname)=$($PSItem)").Trim()
            }
        }
    }

    try {

        #This should always return a ticket.
        $response = Invoke-RestMethod -Uri $downloadURL -WebSession $CognosSession -SkipHttpErrorCheck -ErrorAction STOP

        Write-Verbose $response

        #It is possible the terminal has sat long enough for the session to be expired. Try to reauthenticate.
        if ($response.error.message -eq "RDS-ERR-1020 The currently provided credentials are invalid. Please provide the logon credentials.") {
            Connect-ToCognos -ConfigName $CognosProfile
        }

        if ($response.error.message) {
            #Throw "$($response4.error.message)"
            #Instead of throwing an error if we just try again without -SkipHttpErrorCheck we can get the actual error output to the console.
            Write-Verbose $response.error.message
            $response = Invoke-RestMethod -Uri $downloadURL -WebSession $CognosSession -ErrorAction STOP
        }

        if ($response.receipt.status -eq "working") {
            #At this point we have our conversationID. Lets return an object with with some information.
            return [PSCustomObject]@{
                ConversationID = $($response.receipt.conversationID)
                Report = $JobName
                StartTime = Get-Date
            }
        } else {
            Throw "Failed to run report. Please try with Get-CognosReport or Save-CognosReport."
        }

    } catch {
        Write-Error "$($_)" -ErrorAction STOP
    }

}

function Get-CogStudent {
    <#
        .SYNOPSIS
        Returns an object of enrolled student data

        .DESCRIPTION
        Returns an object of enrolled student data

        .EXAMPLE
        Get-CogStudent -All

        .EXAMPLE
        Get-CogStudent -id 403005966
        Get-CogStudent -id "403005966,403005988"

        .EXAMPLE
        Get-CogStudent -Building 15 -Grade 8

        .EXAMPLE
        Get-CogStudent -EntryAfter "1/1/22"
        Get all students that have enrolled after 1/1/22
    #>

    [CmdletBinding(DefaultParametersetName="default")]
    Param(
        [parameter(Mandatory=$false,ValueFromPipeline=$true,ParameterSetName="Default")]$id,
        [parameter(Mandatory=$false,ParameterSetName="Default")]$Building,
        [parameter(Mandatory=$false,ParameterSetName="Default")]$Grade,
        [parameter(Mandatory=$false,ParameterSetName="Default")]$FirstName,
        [parameter(Mandatory=$false,ParameterSetName="Default")]$LastName,
        [parameter(Mandatory=$false,ParameterSetName="Default")][datetime]$EntryAfter,
        [parameter(Mandatory=$false,ParameterSetName="Default")][switch]$InActive,
        [parameter(Mandatory=$false,ParameterSetName="Default")][switch]$Graduated,
        [parameter(Mandatory=$false,ParameterSetName="All")][switch]$All
    )

    Begin {
        $students = [System.Collections.Generic.List[PSObject]]@()
        $studentIds = [System.Collections.Generic.List[PSObject]]@()
    }

    Process {

        #process incoming Ids either as a property on incoming objects, a comma separated string, or as an array.
        if ($id) {
            if ($id.Student_id) {
                #processing an array of objects with Student_id propery.
                $studentIds.Add($id.Student_id)
            } elseif (([string]$id).IndexOf(',') -ge 1) {
                #processing a comma separated string.
                $studentIds = $id.Split(',')
            } else {
                #processing an array of ids. @(123456789,8675309) | Get-CogStudent
                $studentIds.Add($id)
            }
        }

    }

    End {

        $parameters = @{
            report = "students"
            cognosfolder = "_Shared Data File Reports/API"
            reportparams = ""
        }

        if ($All) {
            $parameters.reportparams += "p_status=A&p_status=I&p_status=G"
            Write-Verbose "$($parameters.reportparams)"
            return (Get-CognosReport @parameters -TeamContent)
        }

        if ($InActive) {
            $parameters.reportparams += "p_status=I&"
        } elseif ($Graduated) {
            $parameters.reportparams += "p_status=G&"
        } else {
            $parameters.reportparams += "p_status=A&"    
        }

        #If -id was specified or an incoming object with a property of Student_id was provided then we should loop through them to query for them.
        if ($studentIds.Count -ge 1) {

            #75 seems like a good break point and will keep us under the url limit. We need to make multiple queries.
            $skip = 0
            $loops = [Math]::Round([Math]::Ceiling($studentIds.count / 75))

            for ($i = 0; $i -lt $loops; $i++) {
                $param = $parameters.reportparams

                $studentIds | Select-Object -First 75 -Skip $skip | ForEach-Object {
                    $param += "p_studentid=$($PSItem)&"
                }

                Write-Verbose "$($param)"
                Get-CognosReport @parameters -reportparams "$($param)p_fake=1" -TeamContent | ForEach-Object {
                    $students.Add($PSItem)
                }

                $skip = $skip + 75
            }

            return $students     

        }

        #if student Ids weren't specified then we can filter on other parameters.
        
        if ($firstname) {
            $parameters.reportparams += "p_firstname=$($firstname)&"
        } 
        
        if ($lastname) {
            $parameters.reportparams += "p_lastname=$($lastname)&"
        } 
        
        if ($entryafter) {
            $parameters.reportparams += "p_entryafter=$($entryafter.ToString('MM/dd/yyyy'))&"
        }
        
        if ($building) {
            $parameters.reportparams += "p_building=$($building)&"
        }

        if ($grade) {
            $parameters.reportparams += "p_grade=$($grade)&"
        }

        $parameters.reportparams += "p_fake=1"
        
        Write-Verbose "$($parameters.reportparams)"
        return (Get-CognosReport @parameters -TeamContent)
    }

}

function Get-CogSchool {
    <#
        .SYNOPSIS
        Returns an object with the building information

        .DESCRIPTION
        Returns an object with the building information

        .EXAMPLE
        Get-CogSchool

        .EXAMPLE
        Get-CogSchool -Building 15

    #>

    Param(
        [parameter(Mandatory=$false)]$Building
    )

    $parameters = @{
        report = "schools"
        cognosfolder = "_Shared Data File Reports/API"
    }

    if ($building) {
        $parameters.reportparams += "p_building=$($building)&"
    }

    $parameters.reportparams += "p_fake=1"

    return (Get-CognosReport @parameters -TeamContent)

}

function Get-CogStuSchedule {
    <#
        .SYNOPSIS
        Returns an array of an array of a students schedule

        .DESCRIPTION
        Returns an array of an array of a students schedule

        .EXAMPLE
        Get-CogStudentSchedule -id 403005966 | Format-Table

        .EXAMPLE
        Get-CogStudentSchedule -Building 15 | ForEach-Object { $PSItem | Format-Table }

    #>

    Param(
        [parameter(Mandatory=$false,ValueFromPipeline=$true)]$id,
        [parameter(Mandatory=$false)]$Grade,
        [parameter(Mandatory=$false)]$Building
    )

    Begin {
        $studentIds = [System.Collections.Generic.List[PSObject]]@()
    }

    Process {

        if ($id) {
            if ($id.Student_id) {
                #processing an array of objects with Student_id propery.
                $studentIds.Add($id.Student_id)
            } elseif (([string]$id).IndexOf(',') -ge 1) {
                #processing a comma separated string.
                $studentIds = $id.Split(',')
            } else {
                #processing an array of ids.
                $studentIds.Add($id)
            }
        }

    }

    End {

        $schedules = [System.Collections.Generic.List[PSObject]]@()

        $parameters = @{
            report = "schedules"
            cognosfolder = "_Shared Data File Reports/API"
        }

        if ($studentIds.Count -ge 1) {

            #75 seems like a good break point and will keep the url under the url limit. We need to make multiple queries.
            $skip = 0
            $loops = [Math]::Round([Math]::Ceiling($studentIds.count / 75))
            $students = [System.Collections.Generic.List[PSObject]]@()

            for ($i = 0; $i -lt $loops; $i++) {
                $param = ''

                $studentIds | Select-Object -First 75 -Skip $skip | ForEach-Object {
                    $param += "p_studentid=$($PSItem)&"
                }

                Write-Verbose "$($param)"
                Get-CognosReport @parameters -reportparams "$($param)p_fake=1" -TeamContent | ForEach-Object {
                    $students.Add($PSItem)
                }
                
                $skip = $skip + 75
            }

            $students | Group-Object -Property 'Student_id' | ForEach-Object {
                $schedules.Add($PSitem.Group)
            }

            return $schedules

            
        }
        
        #if student Ids weren't specified then we can filter on other parameters.
        
        if ($Building) {
            $parameters.reportparams += "p_building=$($building)&"
        }

        if ($Grade) {
            if ($Grade -eq 'K') {
                $Grade = 'KF'
            } else {
                $Grade = "$Grade".PadLeft(2,'0')
            }
            $parameters.reportparams += "p_grade=$($Grade)&"
        }

        $parameters.reportparams += "p_fake=1"

        Write-Verbose "$($parameters.reportparams)"
        (Get-CognosReport @parameters -TeamContent) | Group-Object -Property 'Student_id' | ForEach-Object {
            $schedules.Add($PSitem.Group)
        }

        return $schedules
    }

}

function Get-CogStuAttendance {
    <#
        .SYNOPSIS
        Returns Student Attendance Codes for a specified day, date after, or for the current school year. By default pulls todays date only.

        .DESCRIPTION
        Returns Student Attendance Codes for a specified day, date after, or for the current school year. By default pulls todays date only.

        .PARAMETER date
        Pull a specific dates attendance. If not specified it will always be the current day.

        .PARAMETER dateafter
        Pull all attendance after this specific date.

        .PARAMETER All
        Pull attendance for this school year. equivalent to -dateafter "7/1/202X"

        .PARAMETER AttendanceCode
        Specify what attendance codes you want to pull.

        .PARAMETER ExcludePeriodsByName
        Exclude certain periods by their name. Example: ADV or an Advisory hour that we do not track attendance for.

        .EXAMPLE
        Get-CogStuAttendance -id 403005966

        .EXAMPLE
        To get a specific dates attendance
        Get-CogStuAttendance -date "4/15/2022"

        .EXAMPLE
        Get-CogStuAttendance -dateafter "1-14-2022" -AttendanceCode "A,M"

    #>    

    Param(
        [parameter(Mandatory=$false,ValueFromPipeline=$true)]$id,
        [parameter(Mandatory=$false)]$Building,
        [parameter(Mandatory=$false)]$AttendanceCode,
        [parameter(Mandatory=$false)]$ExcludePeriodsByName,
        [parameter(Mandatory=$false)][datetime]$date=(Get-Date),
        [parameter(Mandatory=$false)][string]$dateafter,
        [parameter(Mandatory=$false)][switch]$All #Everything for this year.
    )

    Begin {
        $studentIds= [System.Collections.Generic.List[int]]@()
        $buildingIds = [System.Collections.Generic.List[PSObject]]@()
        $excludePeriodsByNames = [System.Collections.Generic.List[PSObject]]@()
        $AttendanceCodes = [System.Collections.Generic.List[PSObject]]@()
    }

    Process {

        if ($id) {
            if ($id.Student_id) {
                #processing an array of objects with Student_id propery.
                $studentIds.Add($id.Student_id)
            } elseif (([string]$id).IndexOf(',') -ge 1) {
                #processing a comma separated string.
                $studentIds = $id.Split(',')
            } else {
                #processing an array of ids.
                $studentIds.Add($id)
            }
        }

        if ($Building) {
            if ($id.School_id) {
                #processing an array of objects with Student_id propery.
                $buildingIds.Add($id.School_id)
            } elseif (([string]$Building).IndexOf(',') -ge 1) {
                #processing a comma separated string.
                $buildingIds = $Building.Split(',')
            } else {
                #processing an array of ids.
                $buildingIds.Add($Building)
            }
        }

        #the singular to plurar (bad naming convention?)
        if ($excludePeriodsByName) {
            if (([string]$excludePeriodsByName).IndexOf(',') -ge 1) {
                #processing a comma separated string.
                $excludePeriodsByNames = $excludePeriodsByName.Split(',')
            } else {
                $excludePeriodsByNames.Add($excludePeriodsByName)
            }
        }

        if ($AttendanceCode) {
            if (([string]$AttendanceCode).IndexOf(',') -ge 1) {
                #processing a comma separated string.
                $AttendanceCodes = $AttendanceCode.Split(',')
            } else {
                $AttendanceCodes.Add($AttendanceCode)
            }
        }

    }

    End {

        $parameters = @{
            report = "attendance"
            cognosfolder = "_Shared Data File Reports/API"
        }

        if (-Not($dateafter -or $All)) {
            #If we don't specify an after date or all then pull either the supplied or current date.
            $dateCognosFormat = $date.ToString('yyyy-MM-dd')
            $parameters.reportparams = "p_date=$($dateCognosFormat)&"
        } elseif ($dateafter) {
            $dateCognosFormat = ([datetime]$dateafter).ToString('yyyy-MM-dd')
            $parameters.reportparams = "p_dateafter=$($dateCognosFormat)&"
        } elseif ($All) {
            if ([int](Get-Date -Format MM) -ge 7) {
                $schoolyear = [int](Get-Date -Format yyyy) + 1
            } else {
                $schoolyear = [int](Get-Date -Format yyyy)
            }
            $dateCognosFormat = ([datetime]"7-1-$($schoolyear - 1)").ToString('yyyy-MM-dd')
            $parameters.reportparams = "p_dateafter=$($dateCognosFormat)&"
        }

        if ($AttendanceCodes.Count -ge 1) {
            $AttendanceCodes | ForEach-Object {
                $parameters.reportparams += "p_attendancecodes=$($PSItem)&"
            }
        }

        if ($ExcludePeriodsByNames.Count -ge 1) {
            $excludePeriodsByNames | Foreach-Object {
                $parameters.reportparams += "p_ExcludePeriodsByName=$($PSitem)&"
            }
        }
  
        if ($studentIds.Count -ge 1) {

            #75 seems like a good break point and keeps us under the url limit. We need to make multiple queries.
            $skip = 0
            $loops = [Math]::Round([Math]::Ceiling($id.count / 75))
            $students = [System.Collections.Generic.List[PSObject]]@()

            for ($i = 0; $i -lt $loops; $i++) {
                $param = $parameters.reportparams

                $id | Select-Object -First 75 -Skip $skip | ForEach-Object {
                    $param += "p_studentid=$($PSItem)&"
                }

                Write-Verbose "$param"
                Get-CognosReport @parameters -reportparams "$($param)p_fake=1" -TeamContent | ForEach-Object {
                    $students.Add($PSItem)
                }

                $skip = $skip + 75
            }
    
            return $students     
        
        }
        
        if ($buildingIds.Count -ge 1) {
            $buildingIds | ForEach-Object {
                $parameters.reportparams += "p_building=$($PSitem)&"
            }
        }
    
        $parameters.reportparams += "p_fake=1"
        Write-Verbose "$($parameters.reportparams)"
        return (Get-CognosReport @parameters -TeamContent)
    }
}

function Start-CognosBrowser {

    Param(
        [parameter(Mandatory=$false)][string]$url="https://adecognos.arkansas.gov/ibmcognos/bi/v1/disp/rds/wsil/path",
        [parameter(Mandatory=$false)][string]$savepath=(Get-Location).Path
    )

    if (-Not($CognosSession)) {
        Connect-ToCognos
    }

    #if the dsn name ends in fms then set eFinance to $True.
    if ($CognosDSN.Substring($CognosDSN.Length -3) -eq 'fms') {
        $eFinance = $True
    }

    $results = [System.Collections.Generic.List[PSObject]]@()
    $itemNumber = 1

    $foldercontents = Invoke-WebRequest -Uri "$url" -WebSession $CognosSession
    $folders = Select-Xml -Xml ([xml]$foldercontents.Content) -XPath '//x:link' -Namespace @{ x = "http://schemas.xmlsoap.org/ws/2001/10/inspection/" }
    $files = Select-Xml -Xml ([xml]$foldercontents.Content) -XPath '//x:service' -Namespace @{ x = "http://schemas.xmlsoap.org/ws/2001/10/inspection/" }

    #process folders.
    $folders.Node | Where-Object { $null -ne $PSitem.name } | ForEach-Object {

        $name = $PSitem.abstract
        $location = $PSitem.location -replace 'http://adecognos.arkansas.gov:80','https://adecognos.arkansas.gov'

        $results.Add(
            [PSCustomObject]@{
                item = $itemNumber
                name = $name
                type = 'folder'
                url = $location
            }
        )

        $itemNumber++

    }

    $files.Node | Where-Object { $null -ne $PSitem.name } | ForEach-Object {

        $name = $PSitem.Name
        $location = $PSitem.description.location -replace 'http://adecognos.arkansas.gov:80','https://adecognos.arkansas.gov'

        $results.Add(
            [PSCustomObject]@{
                item = $itemNumber
                name = $name
                type = 'report'
                url = $location
            }
        )

        $itemNumber++

    }
    
    Write-Host ('╔' + ('═' * 58) + '╗') -ForegroundColor Yellow
    Write-Host "║                      Cognos Browser                      ║" -ForeGroundColor Yellow
    Write-Host ('╚' + ('═' * 58) + '╝') -ForegroundColor Yellow

    $results | Select-Object Item,Name,Type | Format-Table

    $selection = Read-Host "Please choose an item #, (r) to restart, or (e) to exit"

    if ($selection -eq 'r') {
        Start-CognosBrowser
    } elseif ($selection -eq 'e') {
        break
    } elseif ($selection -ge 1) {

        try {
            if ($results[$selection - 1].type -eq 'report') {

                $parameters = @{
                    report = $results[$selection - 1].name
                }

                $fileURL = $results[$selection - 1].url
                $decodedURL = [System.Web.HttpUtility]::UrlDecode($results[$selection - 1].url)
                Write-Verbose "$decodedURL"

                if ($decodedURL.indexOf('/path/Team Content') -ge 1) {
                    #team content
                    $teamContent = $True
                    if ($eFinance) {
                        $parameters.cognosFolder = Split-Path -Parent ($decodedURL.split('Team Content/Financial Management System/')[1..99] -join '/')
                    } else {
                        $parameters.cognosFolder = Split-Path -Parent ($decodedURL.split('Team Content/Student Management System/')[1..99] -join '/')
                    }
                } else {
                    #my folder
                    $teamContent = $False
                    $parameters.cognosFolder = Split-Path -Parent ($decodedURL.split('My Folders/')[1..99] -join '/')
                }

                try {
                    $atomURL = $decodedURL -replace '/rds/wsdl/path/','/rds/atom/path/'
                    $reportDetails = Invoke-RestMethod -Uri $atomURL -WebSession $CognosSession -SkipHttpErrorCheck
                    $reportDetails.feed | Select-Object -Property title,owner,ownerEmail,description,location | Format-List
                    if ($reportDetails.error) {
                        $reportDetails.error | Format-List -
                    }
                } catch {
                    $PSitem
                    
                }

                $fileAction = Read-Host "You have selected a Report. Do you want to preview (p) or download (d) the report?"
                if (@('p','preview','d','download') -contains $fileAction) {
                    
                    try {
                        if (@('p','preview') -contains $fileAction) {
                            if ($teamContent) {
                                $report = Get-CognosReport @parameters -TeamContent
                            } else {
                                $report = Get-CognosReport @parameters
                            }
                            Write-Host "---- Preview of Report Data -----" -ForegroundColor Yellow
                            $report | Select-Object -First 10 | Format-Table
                            Write-Host "---- Preview of Data Object -----" -ForegroundColor Yellow
                            $report | Select-Object -First 1 | Format-List
                        } else {
                            $parameters.extension = 'csv'
                            $parameters.savepath = $savepath
                            if ($teamContent) {
                                Save-CognosReport @parameters -TeamContent
                            } else {
                                Save-CognosReport @parameters
                            }
                        }
                    } catch {
                        Write-Host "Error: Could not run report. $PSItem" -ForegroundColor Red

                        Write-Host "Notice: It is possible the report requires additional prompts."
                        if (@('y','yes') -contains (Read-Host -Prompt "Would you like to try and answer the prompts?")) {

                            $a = Invoke-WebRequest -Uri "$fileURL" -WebSession $CognosSession
                            $b = Select-Xml -Xml ([xml]$a) -XPath '//x:types' -Namespace @{ x = "http://schemas.xmlsoap.org/wsdl/" }
                            $c = $b.Node.schema[1].complexType | Where-Object { $PSItem.name -eq 'PromptAnswersType' }
                            
                            $requiredPrompts = $c.sequence.element | Where-Object { @('advanced','extension') -notcontains $PSItem.name }
                            if ($requiredPrompts.Count -ge 1) {
                                Write-Host "Info: Detected the following required prompts:" -ForegroundColor Yellow
                                $requiredPrompts | ForEach-Object {
                                    Write-Host "p_$($PSItem.name)="
                                }
                            } else {
                                Write-Host "Info: No required prompts were found for this report. Optional prompts still require the prompt page to be sumitted. Please use ""p_fake=1""."
                            }

                            $parameters.reportparams = Read-Host "Please enter the prompts values. Should look something like ""p_year=2022&studentid=105966"""
                        
                            if (@('p','preview') -contains $fileAction) {
                                if ($teamContent) {
                                    $report = Get-CognosReport @parameters -TeamContent
                                } else {
                                    $report = Get-CognosReport @parameters
                                }
                                Write-Host "---- Preview of Report Data -----" -ForegroundColor Yellow
                                $report | Select-Object -First 15 | Format-Table
                                Write-Host "---- Preview of Data Object -----" -ForegroundColor Yellow
                                $report | Select-Object -First 1 | Format-List
                            } else {
                                $parameters.extension = 'csv'
                                $parameters.savepath = $savepath
                                if ($teamContent) {
                                    Save-CognosReport @parameters -TeamContent
                                } else {
                                    Save-CognosReport @parameters
                                }
                            }
                        }

                        #Start-CognosBrowser -url $url
                    }

                    if ($parameters.savepath) {
                        $manualDownload = "To manually download this report`nSave-CognosReport -report ""$($parameters.report)"" -cognosfolder ""$($parameters.cognosFolder)"""
                        $manualDownload += " -savepath ""$($parameters.savepath)"""
                    } else {
                        if ($null -eq $($parameters.cognosFolder) -or $parameters.cognosFolder -eq '') {
                            $parameters.cognosFolder = "My Folders"
                        }
                        $manualDownload = "To manually download this report`nGet-CognosReport -report ""$($parameters.report)"" -cognosfolder ""$($parameters.cognosFolder)"""
                    }

                    if ($teamContent) {
                        $manualDownload += " -TeamContent"
                    }

                    Write-Host $manualDownload

                    Read-Host "Press enter to continue..."

                    Start-CognosBrowser -url $url
                    
                } else {
                    Write-Host "To manually run this report`nSave-CognosReport -report ""$name"" -cognosfolder ""$cognosFolder"""
                    Read-Host "Press enter to continue..."
                    Start-CognosBrowser -url $url
                }
            } else {
                Start-CognosBrowser -url $results[$selection - 1].url
            }
        } catch {
            #most likely an out of bounds on the array so start over.
            Start-CognosBrowser -url $url
        }

    } else {
        Start-CognosBrowser -url $url
    }

}