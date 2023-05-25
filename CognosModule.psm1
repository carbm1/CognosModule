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
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/AR-k12code/CognosModule/master/CognosModule.psd1" -OutFile "$($ModulePath)\CognosModule.psd1"
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/AR-k12code/CognosModule/master/CognosModule.psm1" -OutFile "$($ModulePath)\CognosModule.psm1"
        Import-Module CognosModule -Force
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
        [parameter(Mandatory = $false)][string]$ConfigName="DefaultConfig",
        [parameter(Mandatory = $false)][securestring]$Password
    )

    if (Test-Path "$($HOME)\.config\Cognos\$($ConfigName).json") {
        $configPath = "$($HOME)\.config\Cognos\$($ConfigName).json"
        $config = Get-Content "$($HOME)\.config\Cognos\$($ConfigName).json" | ConvertFrom-Json
    } else {
        Write-Error "No configuration file found for the provided $($ConfigName). Run Show-CognosConfig to see available configurations." -ErrorAction STOP
    }

    try {
        if ($Password) {
            $CognosPassword = $Password | ConvertFrom-SecureString
        } else {
            #prompt for new password
            $CognosPassword = Read-Host -Prompt "Please provide your new Cognos Password" -AsSecureString | ConvertFrom-SecureString
        }
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
        Write-Error "No configuration file found for the provided $($ConfigName). Run Set-CognosConfig first." -ErrorAction Stop
    }

    #Attempt retrieving update information.
    try {
        $version = Get-Module -Name CognosModule | Select-Object -ExpandProperty Version
        $versioncheck = Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/AR-k12code/CognosModule/master/version.json' -MaximumRetryCount 0 -TimeoutSec 1
        if ($version -lt [version]($versioncheck.versions[0].version)) {
            Write-Host "Info: There is a new version of this module available at https://github.com/AR-k12code/CognosModule"
            Write-Host "Info: Version $($versioncheck.versions[0].version) is available. Description: $($versioncheck.versions[0].description)"
            Write-Host "Info: Run Update-CognosModule as an Administrator to update to the latest version."
        }
    } catch {} #Do and show nothing if we don't get a response.

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

            $global:CognosModuleSession = @{
                CognosSession = $session
                CognosProfile = $ConfigName
                CognosDSN = $dsnname
                CognoseFPUsername = $efpusername
                CognosUsername = $username
            }

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
            
            # $timeoutPercentage = 100
            # Write-Progress -Status "Report is still processing." -Activity "Downloading Report" -PercentComplete $timeoutPercentage #-ForegroundColor Yellow
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
                    if (($timeoutPercentage = ([Math]::Ceiling(((($startTime.AddMinutes($timeout) - $startTime).TotalSeconds - ((Get-Date) - $startTime).TotalSeconds) / ($startTime.AddMinutes($timeout) - $startTime).TotalSeconds) * 100))) -le 0) {
                        $timeoutPercentage = 0
                    }

                    Write-Progress -Activity "Downloading Report" -Status "Report is still processing." -PercentComplete $timeoutPercentage
                    #Write-Host '.' -NoNewline -ForegroundColor Yellow
                    Start-Sleep -Seconds 2
                }

                Write-Verbose "$($response2.receipt.status)"

            } until ($response2.receipt.status -ne "working")

            Write-Progress -Activity "Downloading Report" -Status "Ready" -Completed

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

function Get-CognosDataSet {
    <#
        .SYNOPSIS
        Pulls from RDS DataSet as JSON.

        .DESCRIPTION
        Pulls from RDS DataSet as JSON.

        .EXAMPLE
        Get-CognosDataSet -report schools -cognosfolder "_Shared Data File Reports\Clever Files" -TeamContent -PageSize 5000

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
        [parameter(Mandatory=$false,ParameterSetName="Default")] #If the report is in the Team Content folder we have to switch paths.
            [switch]$TeamContent,
        [parameter(Mandatory=$false,ParameterSetName="conversation")] #Provide a conversationID if you already started one via Start-CognosReport
            $conversationID,
        [parameter(Mandatory=$false)][int]$pageSize = 2500
    )

    $baseURL = "https://adecognos.arkansas.gov"
    $results = [System.Collections.Generic.List[Object]]::new()

    try {
        
        $startTime = Get-Date

        #If the conversationID has already been supplied then we will use that.
        if (-Not($conversationID)) {
            $conversation = Start-CognosReport @PSBoundParameters -extension json -pageSize $pageSize
            $conversationID = $conversation.conversationID
        }

        Write-Verbose $conversationID

        do {
            do {
                $response = Invoke-RestMethod -Uri "$($baseURL)/ibmcognos/bi/v1/disp/rds/sessionOutput/conversationID/$($conversationID)?v=3" -WebSession $CognosSession
            } until ($response.dataSet.dataTable.row -and -Not($response.receipt.status))
        
            #return $response #.dataSet.dataTable.row[0]
            Write-Verbose ($response.dataSet.dataTable.row | ConvertTo-Json -Depth 99)

            #headers with underscore have _x005f so we have to convert it back and forth. I have a bad feeling about this.
            # $properties = $response.dataset.dataTable.row[0].ChildNodes.Name
            $rows = $response.dataSet.dataTable.row # | Select-Object -Property $properties
            
            #fix name on properties.
            $properties = @()
            $rows[0].PSObject.Properties | Select-Object -ExpandProperty Name | ForEach-Object {
                if ($PSitem -like "*_x005f*" -or $PSitem -like "*__*") {
                    $propertyFixedName = $($Psitem -replace '_x005f','_' -replace '__','_')
                    $rows | Add-Member -MemberType AliasProperty -Name $propertyFixedName -Value $PSitem
                    $properties += $propertyFixedName
                } else {
                    $properties += $PSitem
                }
            }

            $rows = $rows | Select-Object -Property $properties
            #return $rows
            #trim everything up nice and neat.
            $rows | ForEach-Object {  
                $_.PSObject.Properties | ForEach-Object {
                    if ($null -ne $_.Value -and $_.Value.GetType().Name -eq 'String') {
                        $_.Value = $_.Value.Trim()
                    }
                }
            }
            
            $rows | ForEach-Object {
                $results.Add($PSitem)
            }

            if (($rows).Count -lt $pageSize) {
                $morePages = $False
            } else {
                #next page.
                $conversation = Invoke-RestMethod -Uri "$($baseURL)/ibmcognos/bi/v1/disp/rds/sessionOutput/conversationID/$($conversationID)/next?v=3" -WebSession $CognosSession
                $conversationID = $conversation.receipt.conversationID
                Write-Verbose $conversationID
                Write-Progress -Activity "Downloading Report Data" -Status "$($results.count) rows downloaded." -PercentComplete 0
            }
            
        } until ( $morePages -eq $False )

        return $results

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

    #To measure for a timeout.
    $startTime = Get-Date

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
                    Write-Error "Timeout of $Timeout minutes has been met. Exiting." -ErrorAction STOP
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
                } catch {
                    Remove-Variable -Name response3 -ErrorAction SilentlyContinue
                }

                if ($response3.receipt.status) {
                    Write-Verbose $response3.receipt.status
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
            [ValidateSet("csv","xlsx","pdf",'json')]
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
            [string]$JobName = $report, 
        [parameter(Mandatory=$false)] #Reference ID for specific request. Useful if you have to run the same report multiple times with different parameters.
            [string]$RefID,
        [parameter(Mandatory=$false)] #PageSize for JSON DataSet.
            [int]$pageSize = 2500
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

    if ($extension -eq "json") {
        $downloadURL = "$($baseURL)/ibmcognos/bi/v1/disp/rds/pagedReportData/path/$($cognosfolder)/$($report)/?v=3&async=MANUAL&fmt=DataSetJSON&rowLimit=$($pageSize)"
    } else {
        $downloadURL = "$($baseURL)/ibmcognos/bi/v1/disp/rds/outputFormat/path/$($cognosfolder)/$($report)/$($rdsFormat)?v=3&async=MANUAL"
    }

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
                RefID = $RefID
            }
        } else {
            Throw "Failed to run report. Please try with Get-CognosReport or Save-CognosReport."
        }

    } catch {
        Write-Error "$($_)" -ErrorAction STOP
    }

}

function Get-CogSqlData {
    <#
        .SYNOPSIS
        This function will help build the parameters, SQL queries, and return data objects.

        .DESCRIPTION
        This should never hit the timeout. If so, you need to break your reports into smaller chunks with SQL/dtStart/dtEnd parameters.
        DONE - We need to cache the table definitions so we know what to send as the tblUniqueCols.
        KINDA DONE - We need options on how to return the data. Raw, Json, Objects, or something else?

    #>

    [CmdletBinding(DefaultParametersetName="default")]
    Param(
        [Parameter(Mandatory=$true,ParameterSetName="default")]
        [ValidateSet('version','tblDefinitions','colDefinitions','_tblStateCourses','API_AUTH_LOG','API_CALLER_CFG','API_CALLER_CFG_OPTIONS','API_CALLER_SECURE_DET','API_CALLER_SUBSCRIBE','API_DELTA_CACHE','API_DISTRICT_DEFINED',
        'API_GUID_GB_ASMT','API_GUID_GB_SCORE','API_LOG','API_PROGRAMS','API_RULE_DET','API_RULE_HDR','API_RULE_SCOPES','API_RULE_SUBQUERY_JOIN','AR_CLASS_DOWN','AR_DOWN_ALE_DAYS',
        'AR_DOWN_ATTEND','AR_DOWN_CAL','AR_DOWN_DISCIPLINE','AR_DOWN_DISTRICT','AR_DOWN_EC','AR_DOWN_EIS1','AR_DOWN_EIS2','AR_DOWN_EMPLOYEE','AR_DOWN_GRADUATE','AR_DOWN_HEARING',
        'AR_DOWN_JOBASSIGN','AR_DOWN_REFERRAL','AR_DOWN_REGISTER','AR_DOWN_SCHL_AGE','AR_DOWN_SCHOOL','AR_DOWN_SCOLIOSIS','AR_DOWN_SE_STAFF','AR_DOWN_STU','AR_DOWN_STU_ID',
        'AR_DOWN_STUDENT_GRADES','AR_DOWN_VISION','ARTB_21CCLC','ARTB_DIST_LEARN','ARTB_DIST_LRNPROV','ARTB_DISTRICTS','ARTB_EC_ANTIC_SVC','ARTB_EC_DISAB','ARTB_EC_RELATE_SVC',
        'ARTB_INSTITUTIONS','ARTB_LEPMONITORED','ARTB_OTHERDISTRICT','ARTB_OUT_DIST','ARTB_RESIDENT','ARTB_RPT_PERIODS','ARTB_SA_ANTIC_SVC','ARTB_SA_DISAB','ARTB_SA_RELATE_SVC',
        'ARTB_SCHOOL_GRADE','ARTB_SE_CERT_STAT','ARTB_SE_DEV_NEEDS','ARTB_SE_EDD_3RD','ARTB_SE_EDD_REASON','ARTB_SE_EDU_ENVIRN','ARTB_SE_EDU_NEEDS','ARTB_SE_EDU_PLACE','ARTB_SE_EVAL_CODE',
        'ARTB_SE_EVL_EXCEED','ARTB_SE_FUNC_IMP','ARTB_SE_FUNC_SCORE','ARTB_SE_GRADE_LVL','ARTB_SE_INT_SERV','ARTB_SE_PROG_TYPE','ARTB_SE_REASON_NOT_ACCESSED','ARTB_SE_REFERRAL',
        'ARTB_SE_RFC_REASON','artb_se_staf_disab','ARTB_SE_TITLE_CODE','ARTB_SE_TRANS_CODE','ARTB_TUITION','ATT_AUDIT_TRAIL','ATT_BOTTOMLINE','ATT_CFG','ATT_CFG_CODES','ATT_CFG_MISS_SUB',
        'ATT_CFG_PERIODS','ATT_CODE','ATT_CODE_BUILDING','ATT_CONFIG_PERCENT','ATT_COURSE_SEATING','ATT_EMERGENCY','ATT_EMERGENCY_CFG','ATT_HRM_SEATING','ATT_INTERVAL','ATT_LOCK_DATE',
        'ATT_NOTIFY_CRIT','ATT_NOTIFY_CRIT_CD','ATT_NOTIFY_CRIT_PD','ATT_NOTIFY_ELIG_CD','ATT_NOTIFY_GROUP','ATT_NOTIFY_LANG','ATT_NOTIFY_STU_DET','ATT_NOTIFY_STU_HDR','ATT_PERIOD',
        'ATT_STU_AT_RISK','ATT_STU_COURSE_SEAT','ATT_STU_DAY_TOT_LAST','ATT_STU_DAY_TOTALS','ATT_STU_ELIGIBLE','ATT_STU_HRM_SEAT','ATT_STU_INT_CRIT','ATT_STU_INT_GROUP','ATT_STU_INT_MEMB',
        'ATT_TWS_TAKEN','ATT_VIEW_ABS','ATT_VIEW_CYC','ATT_VIEW_DET','ATT_VIEW_HDR','ATT_VIEW_INT','ATT_VIEW_MSE_BLDG','ATT_VIEW_PER','ATT_YREND_RUN','ATTTB_DISTRICT_GRP','ATTTB_INELIGIBLE',
        'ATTTB_SIF_STATUS','ATTTB_SIF_TYPE','ATTTB_STATE_GRP','BOOK_ALT_LOCATION','BOOK_ASSIGN','BOOK_BLDG_CFG','BOOK_BOOKMASTER','BOOK_CFG','BOOK_DIST','BOOK_ENROLL','BOOK_GRADES',
        'BOOK_MLC_COURSE','BOOK_REQ_DET','BOOK_REQ_HDR','BOOK_STU_BOOKS','BOOK_TEXTBOOK','BOOK_TRANS','BOOK_WAREALTLOC','BOOKTB_ADJ_COMMENT','BOOKTB_ADOPTION','BOOKTB_DEPOSITORY',
        'BOOKTB_MLC','BOOKTB_PUBLISHER','BOOKTB_TYPE','COTB_REPORT_PERIOD','CP_CFG','CP_GRADPLAN_COURSE','CP_GRADPLAN_GD','CP_GRADPLAN_HDR','CP_GRADPLAN_SUBJ','CP_STU_COURSE_OVR',
        'CP_STU_FUTURE_REQ','CP_STU_GRAD','CP_STU_GRAD_AREA','CP_STU_PLAN_ALERT','CP_VIEW_HDR','CP_VIEW_LTDB','CP_VIEW_MARKS','CP_VIEW_MARKS_MP','CP_VIEW_WORKSHEET','CRN_CFG',
        'DISC_ACT_USER','DISC_ATT_NOTIFY','DISC_CFG','DISC_CFG_LANG','DISC_DIST_CFG_AUTO_ACTION','DISC_DIST_OFF_TOT','DISC_DISTRICT_ACT','DISC_DISTRICT_CFG','DISC_DISTRICT_CFG_DETAIL',
        'DISC_DISTRICT_CFG_SUMMARY','DISC_DISTRICT_COST','DISC_DISTRICT_FINE','DISC_DISTRICT_TOT','DISC_INCIDENT','DISC_INCIDENT_CODE','DISC_LINK_ISSUE','DISC_LTR_CRIT','DISC_LTR_CRIT_ACT',
        'DISC_LTR_CRIT_ELIG','DISC_LTR_CRIT_OFF','DISC_LTR_DETAIL','DISC_LTR_HEADER','DISC_MSG_ACTIONCODE','DISC_NON_STU_RACES','DISC_NON_STUDENT','DISC_NOTES','DISC_OCCURRENCE',
        'DISC_OFF_ACTION','DISC_OFF_CHARGE','DISC_OFF_CODE','DISC_OFF_CONVICT','DISC_OFF_DRUG','DISC_OFF_FINE','DISC_OFF_SUBCODE','DISC_OFF_WEAPON','DISC_OFFENDER','DISC_PRINT_CITATION',
        'DISC_STU_AT_RISK','DISC_STU_ELIGIBLE','DISC_STU_ROLLOVER','DISC_USER','DISC_VICTIM','DISC_VICTIM_ACTION','DISC_VICTIM_INJURY','DISC_WITNESS','DISC_YEAREND_RUN','DISCTB_ACT_OUTCOME',
        'DISCTB_CHARGE','DISCTB_CONVICTION','DISCTB_DISPOSITION','DISCTB_DRUG','DISCTB_INC_SUBCODE','DISCTB_INJURY','DISCTB_LOCATION','DISCTB_MAGISTRATE','DISCTB_NOTIFIED',
        'DISCTB_OFF_ACTION','DISCTB_OFF_SUBCODE','DISCTB_POLICE_ACT','DISCTB_REASON','DISCTB_REFERRAL','DISCTB_TIMEFRAME','DISCTB_VIC_ACTION','DISCTB_VIC_CODE','DISCTB_VIC_DISP',
        'DISCTB_VIC_REASON','DISCTB_VIC_SUBCODE','DISCTB_WEAPON','DISCTB_WIT_CODE','DISCTB_WIT_SUBCODE','dtproperties','ESP_MENU_FAVORITES','ESP_MENU_ITEMS','FEE_CFG','FEE_CFG_PRO_RATE',
        'FEE_CFG_REDUCED','FEE_GROUP_CRIT','FEE_GROUP_DET','FEE_GROUP_HDR','FEE_ITEM','FEE_STU_AUDIT','FEE_STU_GROUP','FEE_STU_ITEM','FEE_STU_PAYMENT','FEE_TEXTBOOK','FEE_TEXTBOOK_CRS',
        'FEE_TEXTBOOK_TEA','FEE_YREND_RUN','FEETB_CATEGORY','FEETB_PAYMENT','FEETB_STU_STATUS','FEETB_SUB_CATEGORY','FEETB_UNIT_DESCR','GDBK_POST_CLS','GDBK_POST_DAT','GDBK_POST_IPR_COMM',
        'GDBK_POST_IPR_MARK','GDBK_POST_RC','GDBK_POST_RC_ABS','GDBK_POST_RC_COMM','GDBK_POST_RC_MARK','HAC_BUILDING_ALERT','HAC_BUILDING_ALERT_MARK_TYPE','HAC_Building_Cfg',
        'HAC_BUILDING_CFG_AUX','HAC_BUILDING_CFG_CONTACTS','HAC_BUILDING_CFG_DISC','HAC_BUILDING_CFG_HDR_RRK','HAC_BUILDING_CFG_INTER','HAC_BUILDING_CFG_RRK','HAC_CHALLENGE_QUES',
        'HAC_DIST_CFG_LDAP','HAC_DIST_CFG_ONLINE_PAYMT','HAC_DIST_CFG_PWD','HAC_District_Cfg','HAC_FAILED_LOGIN_ATTEMPTS','HAC_LINK','HAC_LINK_MACRO','HAC_MENU_LINKED_PAGES','HAC_MENULIST',
        'HAC_OLD_USER','HAC_ONLINE_PAYMENT','HAC_TRANSLATION','IEP_STUDENT_FILES','LTDB_DASHBOARD','ltdb_group_det','ltdb_group_hdr','LTDB_IMPORT_DEF','LTDB_IMPORT_DET','LTDB_IMPORT_HDR',
        'LTDB_IMPORT_TRN','LTDB_INTERFACE_DEF','LTDB_INTERFACE_DET','LTDB_INTERFACE_HDR','LTDB_INTERFACE_STU','LTDB_INTERFACE_TRN','LTDB_SCORE_HAC','LTDB_STU_AT_RISK','LTDB_STU_SUBTEST',
        'LTDB_STU_TEST','LTDB_STU_TRACKING','LTDB_STU_TRK_DATA','LTDB_SUBTEST','LTDB_SUBTEST_HAC','LTDB_SUBTEST_SCORE','LTDB_TEST','LTDB_TEST_BUILDING','LTDB_TEST_HAC','LTDB_TEST_TRACKING',
        'LTDB_USER_TEST','LTDB_VIEW_DET','LTDB_VIEW_HDR','LTDB_YEAREND_RUN','LTDBTB_SCORE_PESC_CODE','LTDBTB_SCORE_TYPE','LTDBTB_SUBTEST_PESC_CODE','LTDBTB_TEST_PESC_CODE',
        'MD_ATTENDANCE_DOWN','MD_LEVEL_MARKS','MD_PROCESS_SECTION','MD_PROCESS_STUDENT','MD_RUN','MD_SCGT_BLDG_ATT_VIEW_TYPE','MD_SCGT_BLDG_CFG','MD_SCGT_BLDG_MARK_TYPE','MD_SCGT_DOWN',
        'MDTB_CLASS_OF_RECORD','MDTB_COURSE_COMPLETION_STATUS','MDTB_CRS_PLACEMENT','MDTB_HSA_SUBJECT','MED_CFG','MED_CFG_LANG','MED_CUSTOM_EXAM_COLUMN','MED_CUSTOM_EXAM_ELEMENT',
        'MED_CUSTOM_EXAM_KEY','MED_CUSTOM_EXAM_TYPE','MED_DENTAL','MED_DENTAL_COLS','MED_DISTRICT_CFG','MED_GENERAL','MED_GRACE_SCHD','MED_GROWTH','MED_GROWTH_ARK','MED_GROWTH_BMI_ARK',
        'MED_HEARING','MED_HEARING_COLS','MED_HEARING_DET','MED_IMM_CRIT','MED_IMM_CRIT_GRP','med_imm_crit_grp_SD091114','med_imm_crit_SD091114','MED_IMM_CRIT_SHOTS',
        'med_imm_crit_shots_SD091114','MED_ISSUED','MED_NOTES','MED_OFFICE','MED_OFFICE_DET','MED_OFFICE_SCHD','MED_PHYSICAL','MED_PHYSICAL_EXAM','MED_REFERRAL','MED_REQUIRED',
        'MED_SCOLIOSIS','MED_SCREENING','MED_SERIES','MED_SERIES_DET','MED_SERIES_SCHD_BOOSTER','MED_SERIES_SCHD_HDR','med_series_schd_hdr_SD091114','MED_SERIES_SCHD_TYPES',
        'MED_SERIES_SCHED','med_series_sched_SD091114','MED_SHOT','MED_SHOT_DET','MED_STU_LETTER','MED_USER','MED_VISION','MED_VISION_COLS','MED_VITALS','MED_YEAREND_RUN',
        'MEDTB_ALT_DOSE','MEDTB_ALT_DOSE_DET','MEDTB_BMI_STATUS','MEDTB_CDC_LMS','MEDTB_DECIBEL','MEDTB_EVENT','MEDTB_EXAM','MEDTB_EXEMPT','MEDTB_FOLLOWUP','MEDTB_FREQUENCY','MEDTB_LENS',
        'MEDTB_LOCATION','MEDTB_MEDICINE','MEDTB_OUTCOME','MEDTB_PERCENTS','MEDTB_PERCENTS_ARK','MEDTB_REFER','MEDTB_SCREENING','MEDTB_SHOT','MEDTB_SOURCE_DOC','MEDTB_STATUS',
        'MEDTB_TEMP_METHOD','MEDTB_TREATMENT','MEDTB_VACCINATION_PESC_CODE','medtb_vis_exam_ark','MEDTB_VISION_EXAM_TYPE','MEDTB_VISIT','MENU_ITEMS','MR_ABSENCE_TYPES','MR_ABSENCE_VALID',
        'MR_ALT_LANG_CFG','MR_AVERAGE_CALC','MR_AVERAGE_SETUP','MR_CFG','mr_cfg_hold_fee','mr_cfg_hold_status','MR_CFG_LANG','MR_CFG_MISS_SUB','MR_CLASS_SIZE','MR_COMMENT_TYPES',
        'MR_COMMENT_VALID','MR_COMMENTS','MR_COMMENTS_ALT_LANG','MR_CRDOVR_REASON','MR_CREDIT_SETUP','MR_CREDIT_SETUP_AB','MR_CREDIT_SETUP_GD','MR_CREDIT_SETUP_MK','MR_CRSEQU_DET',
        'MR_CRSEQU_HDR','MR_CRSEQU_SETUP','MR_CRSEQU_SETUP_AB','MR_CRSEQU_SETUP_MK','MR_GB_ACCUMULATED_AVG','MR_GB_ALPHA_MARKS','MR_GB_ASMT','MR_GB_ASMT_COMP','MR_GB_ASMT_STU_COMP',
        'MR_GB_ASMT_STU_COMP_ATTACH','MR_GB_ASMT_STU_COMP_COMP','MR_GB_AVG_CALC','MR_GB_CAT_AVG','MR_GB_CAT_BLD','MR_GB_CAT_SESS_MARK','MR_GB_CAT_SESSION','MR_GB_CAT_STU_COMP',
        'MR_GB_CATEGORY_TYPE_DET','MR_GB_CATEGORY_TYPE_HDR','MR_GB_COMMENT','MR_GB_IPR_AVG','MR_GB_LOAD_AVG_ERR','MR_GB_MARK_AVG','MR_GB_MP_MARK','MR_GB_RUBRIC_CRIT','MR_GB_RUBRIC_DET',
        'MR_GB_RUBRIC_HDR','MR_GB_RUBRIC_PERF_LVL','MR_GB_SCALE','MR_GB_SCALE_DET','MR_GB_SESSION_PROP','MR_GB_STU_ALIAS','MR_GB_STU_ASMT_CMT','MR_GB_STU_COMP_ACCUMULATED_AVG',
        'MR_GB_STU_COMP_CAT_AVG','MR_GB_STU_COMP_STU_SCORE','MR_GB_STU_COMP_STU_SCORE_HIST','MR_GB_STU_COMPS_ALIAS','MR_GB_STU_COMPS_STU_ASMT_CMT','MR_GB_STU_COMPS_STU_NOTES',
        'MR_GB_STU_NOTES','MR_GB_STU_SCALE','MR_GB_STU_SCORE','MR_GB_STU_SCORE_HIST','MR_GPA_SETUP','MR_GPA_SETUP_BLDG','MR_GPA_SETUP_EXCL','MR_GPA_SETUP_GD','MR_GPA_SETUP_MK_GD',
        'MR_GPA_SETUP_MRK','MR_GRAD_REQ_DET','MR_GRAD_REQ_FOCUS','MR_GRAD_REQ_HDR','MR_GRAD_REQ_MRK_TYPE','MR_GRAD_REQ_TAG_RULES','MR_HONOR_ELIG_CD','MR_HONOR_SETUP','MR_HONOR_SETUP_ABS',
        'MR_HONOR_SETUP_ALT_LANG','MR_HONOR_SETUP_COM','MR_HONOR_SETUP_GD','MR_HONOR_SETUP_MKS','MR_HONOR_SETUP_Q_D','MR_IMPORT_STU_CRS_DET','MR_IMPORT_STU_CRS_GRADES',
        'MR_IMPORT_STU_CRS_HDR','MR_IPR_ELIG_CD','MR_IPR_ELIG_SETUP','MR_IPR_ELIG_SETUP_ABS','MR_IPR_ELIG_SETUP_COM','MR_IPR_ELIG_SETUP_GD','MR_IPR_ELIG_SETUP_MKS','MR_IPR_ELIG_SETUP_Q_D',
        'MR_IPR_PRINT_HDR','MR_IPR_PRT_STU_COM','MR_IPR_PRT_STU_DET','MR_IPR_PRT_STU_HDR','MR_IPR_PRT_STU_MSG','MR_IPR_RUN','MR_IPR_STU_ABS','MR_IPR_STU_AT_RISK','MR_IPR_STU_COM',
        'MR_IPR_STU_ELIGIBLE','MR_IPR_STU_HDR','MR_IPR_STU_MARKS','MR_IPR_STU_MESSAGE','MR_IPR_TAKEN','MR_IPR_VIEW_ATT','MR_IPR_VIEW_ATT_IT','MR_IPR_VIEW_DET','MR_IPR_VIEW_HDR',
        'MR_LEVEL_DET','MR_LEVEL_GPA','MR_LEVEL_HDR','MR_LEVEL_HONOR','MR_LEVEL_MARKS','MR_LTDB_MARK_DTL','MR_LTDB_MARK_HDR','MR_MARK_ISSUED_AT','MR_MARK_SUBS','MR_MARK_TYPES',
        'MR_MARK_TYPES_LMS_MAP','MR_MARK_VALID','MR_PRINT_GD_SCALE','MR_PRINT_HDR','MR_PRINT_KEY','MR_PRINT_STU_COMM','MR_PRINT_STU_CRSCP','MR_PRINT_STU_CRSTXT','MR_PRINT_STU_DET',
        'MR_PRINT_STU_GPA','MR_PRINT_STU_HDR','MR_PRINT_STU_HNR','mr_print_stu_hold','mr_print_stu_item','MR_PRINT_STU_LTDB','MR_PRINT_STU_PROG','MR_PRINT_STU_SCTXT',
        'MR_PRINT_STU_SEC_TEACHER','MR_PRINT_STU_STUCP','MR_RC_STU_AT_RISK','MR_RC_STU_ATT_VIEW','MR_RC_STU_ELIGIBLE','MR_RC_TAKEN','MR_RC_VIEW_ALT_LANG','MR_RC_VIEW_ATT',
        'MR_RC_VIEW_ATT_INT','MR_RC_VIEW_DET','MR_RC_VIEW_GPA','MR_RC_VIEW_GRD_SC','MR_RC_VIEW_HDR','MR_RC_VIEW_HONOR','MR_RC_VIEW_LTDB','MR_RC_VIEW_MPS','MR_RC_VIEW_SC_MP',
        'MR_RC_VIEW_SP','MR_RC_VIEW_SP_COLS','MR_RC_VIEW_SP_MP','MR_RC_VIEW_STUCMP','MR_REQ_AREAS','MR_SC_COMP_COMS','MR_SC_COMP_CRS','MR_SC_COMP_DET','MR_SC_COMP_DET_ALT_LANG',
        'MR_SC_COMP_HDR','MR_SC_COMP_MRKS','MR_SC_COMP_STU','MR_SC_CRS_TAKEN','MR_SC_CRSSTU_TAKEN','MR_SC_DISTR_FORMAT','MR_SC_GD_SCALE_ALT_LANG','MR_SC_GD_SCALE_DET','MR_SC_GD_SCALE_HDR',
        'MR_SC_ST_STANDARD','MR_SC_STU_COMMENT','MR_SC_STU_COMP','MR_SC_STU_CRS_COMM','MR_SC_STU_CRS_COMP','MR_SC_STU_TAKEN','MR_SC_STU_TEA','MR_SC_STU_TEA_XREF','MR_SC_STU_TEXT',
        'MR_SC_STUSTU_TAKEN','MR_SC_TEA_COMP','MR_STATE_COURSES','MR_STU_ABSENCES','MR_STU_BLDG_TYPE','MR_STU_COMMENTS','MR_STU_CRS_DATES','MR_STU_CRSEQU_ABS','MR_STU_CRSEQU_CRD',
        'MR_STU_CRSEQU_MARK','MR_STU_EXCLUDE_BUILDING_TYPE','MR_STU_GPA','MR_STU_GRAD','MR_STU_GRAD_AREA','MR_STU_GRAD_VALUE','MR_STU_HDR','MR_STU_HDR_SUBJ','MR_STU_HONOR','MR_STU_MARKS',
        'MR_STU_MP','MR_STU_MP_COMMENTS','MR_STU_OUT_COURSE','MR_STU_RUBRIC_COMP_SCORE','MR_STU_RUBRIC_COMP_SCORE_HIST','MR_STU_RUBRIC_SCORE','MR_STU_RUBRIC_SCORE_HIST','MR_STU_TAG_ALERT',
        'MR_STU_TEXT','MR_STU_USER','MR_STU_XFER_BLDGS','MR_STU_XFER_RUNS','MR_TRN_PRINT_HDR','MR_TRN_PRT_CRS_UD','MR_TRN_PRT_STU_ACT','MR_TRN_PRT_STU_BRK','MR_TRN_PRT_STU_COM',
        'MR_TRN_PRT_STU_DET','MR_TRN_PRT_STU_HDR','MR_TRN_PRT_STU_LTD','MR_TRN_PRT_STU_MED','MR_TRN_PRT_STU_REQ','MR_TRN_VIEW_ATT','MR_TRN_VIEW_BLDTYP','MR_TRN_VIEW_DET','MR_TRN_VIEW_GPA',
        'MR_TRN_VIEW_HDR','MR_TRN_VIEW_LTDB','MR_TRN_VIEW_MED','MR_TRN_VIEW_MPS','MR_TRN_VIEW_MS','MR_TRN_VIEW_UD','MR_TX_CREDIT_SETUP','MR_YEAREND_RUN','MRTB_DISQUALIFY_REASON',
        'MRTB_GB_CATEGORY','MRTB_GB_EXCEPTION','MRTB_LEVEL_HDR_PESC_CODE','MRTB_MARKOVR_REASON','MRTB_ST_CRS_FLAGS','MRTB_SUBJ_AREA_SUB','MSG_BUILDING_SETUP','MSG_BUILDING_SETUP_ENABLE',
        'MSG_BUILDING_SETUP_VALUES','MSG_DISTRICT_SETUP','MSG_DISTRICT_SETUP_ENABLE','MSG_DISTRICT_SETUP_VALUES','MSG_EVENT','MSG_IEP_AUDIENCE','MSG_SCHEDULE','MSG_SUB_EVENT',
        'MSG_USER_PREFERENCE_DET','MSG_USER_PREFERENCE_HDR','MSG_VALUE_SPECIFICATION','NSE_ADDRESS','NSE_ADMIN_DOCUMENTS','NSE_ADMIN_DOCUMENTS_FOR_GRADE','NSE_ADMIN_SETTINGS',
        'NSE_APPLICATION','NSE_APPLICATION_DETAILS','NSE_APPLICATION_RELATIONSHIP','NSE_APPLICATION_STUDENT','NSE_APPLICATION_TRANSLATION','NSE_BUILDING','NSE_CONFIGURABLE_FIELDS',
        'NSE_CONTACT','NSE_CONTACT_PHONE','NSE_CONTACT_VERIFY','NSE_CONTACTMATCH_LOG','NSE_CONTROLSLIST','NSE_CONTROLTRANSLATION','NSE_DISCLAIMER','NSE_DYNAMIC_FIELDS_APPLICATION',
        'NSE_DYNAMIC_FIELDS_GRADE','NSE_DYNAMIC_FIELDS_GROUP','NSE_DYNAMIC_FIELDS_TOOLTIP','NSE_EOCONTACT','NSE_FIELDS','NSE_HAC_ACCESS','NSE_LANGUAGE','NSE_MEDICAL','NSE_PHONENUMBERS',
        'NSE_REG_USER','NSE_RESOURCE','NSE_RESOURCE_TYPE','NSE_SECTION_COMPLETE','NSE_SIGNATURE','NSE_STU_CONTACT','NSE_STUDENT','NSE_STUDENT_RACE','NSE_TABS','NSE_TOOLTIP',
        'NSE_TRANSLATION','NSE_UPLOAD_DOCUMENTS','NSE_UPLOADFILES','NSE_USER','NSE_USERDETAIL','NSE_VACCINATION_CONFIGURATION','P360_NotificationLink','P360_NotificationResultSet',
        'P360_NotificationResultSetUser','P360_NotificationRule','P360_NotificationRuleKey','P360_NotificationRuleUser','P360_NotificationSchedule','P360_NotificationTasks',
        'P360_NotificationUserCriteria','PESC_SUBTEST_CODE','PESC_TEST_CODE','PESCTB_DIPLO_XWALK','PESCTB_GEND_XWALK','PESCTB_GPA_XWALK','PESCTB_GRADE_XWALK','PESCTB_SCORE_XWALK',
        'PESCTB_SHOT_XWALK','PESCTB_STU_STATUS','PESCTB_SUFFIX_XWALK','PESCTB_TERM_XWALK','PP_CFG','PP_DISTDEF_MAP','PP_MONTH_DAYS','PP_REBUILD_HISTORY','PP_SECURITY','PP_STUDENT_CACHE',
        'PP_STUDENT_MONTH','PP_STUDENT_MONTH_ABS','PP_STUDENT_TEMP','PRCH_STU_STATUS','PS_SPECIAL_ED_PHONE_TYPE_MAP','REG','REG_ACADEMIC','REG_ACADEMIC_SUPP','REG_ACT_PREREQ',
        'REG_ACTIVITY_ADV','REG_ACTIVITY_DET','REG_ACTIVITY_ELIG','REG_ACTIVITY_HDR','REG_ACTIVITY_INEL','REG_ACTIVITY_MP','REG_APPOINTMENT','REG_APPT_SHARE','REG_AT_RISK_FACTOR',
        'REG_AT_RISK_FACTOR_REASON','REG_BUILDING','REG_BUILDING_GRADE','REG_CAL_DAYS','REG_CAL_DAYS_LEARNING_LOC','REG_CAL_DAYS_LL_PDS','REG_CALENDAR','REG_CFG','REG_CFG_ALERT',
        'REG_CFG_ALERT_CODE','REG_CFG_ALERT_DEF_CRIT','REG_CFG_ALERT_DEFINED','REG_CFG_ALERT_UDS_CRIT_KTY','REG_CFG_ALERT_UDS_KTY','REG_CFG_ALERT_USER','REG_CFG_EW_APPLY',
        'REG_CFG_EW_COMBO','REG_CFG_EW_COND','REG_CFG_EW_REQ_ENT','REG_CFG_EW_REQ_FLD','REG_CFG_EW_REQ_WD','REG_CFG_EW_REQUIRE','REG_CLASSIFICATION','REG_CLASSIFICATION_EVA',
        'REG_CONTACT','REG_CONTACT_HIST','REG_CONTACT_HIST_TMP','REG_CONTACT_PHONE','REG_CYCLE','REG_DISABILITY','REG_DISTRICT','REG_DISTRICT_ATTACHMENT','REG_DURATION',
        'REG_EMERGENCY','REG_ENTRY_WITH','REG_ETHNICITY','REG_EVENT','REG_EVENT_ACTIVITY','REG_EVENT_COMP','REG_EVENT_HRM','REG_EVENT_MS','REG_EXCLUDE_HONOR','REG_EXCLUDE_IPR',
        'REG_EXCLUDE_RANK','REG_GEO_CFG','REG_GEO_CFG_DATES','REG_GEO_PLAN_AREA','REG_GEO_STU_PLAN','REG_GEO_ZONE_DATES','REG_GEO_ZONE_DET','REG_GEO_ZONE_HDR','REG_GRADE',
        'REG_GROUP_HDR','REG_GROUP_USED_FOR','REG_HISPANIC','REG_HISTORY_CFG','REG_HOLD','reg_hold_calc_detail','REG_HOLD_RC_STATUS','REG_IEP_SETUP','REG_IEP_STATUS','REG_IMMUNIZATION',
        'REG_IMPORT','REG_IMPORT_CONTACT','REG_IMPORT_PROGRAM','REG_KEY_CONTACT_ID','REG_LEGAL_INFO','REG_LOCKER','REG_LOCKER_COMBO','REG_MAP_STU_GEOCODE','REG_MED_ALERTS',
        'REG_MED_PROCEDURE','REG_MP_DATES','REG_MP_WEEKS','REG_NEXT_YEAR','REG_NOTES','REG_PERSONAL','REG_PHONE_HIST','REG_PHONE_HISTORY_CFG','REG_PROG_SETUP_BLD',
        'REG_PROGRAM_COLUMN','REG_PROGRAM_SETUP','REG_PROGRAM_USER','REG_PROGRAMS','REG_PRT_FLG_DFLT','REG_ROOM','REG_ROOM_AIN','REG_STAFF','REG_STAFF_ADDRESS','REG_STAFF_BLDGS',
        'REG_STAFF_BLDGS_ELEM_AIN','REG_STAFF_BLDGS_HRM_AIN','REG_STAFF_ETHNIC','REG_STAFF_HISPANIC','REG_STAFF_PHOTO_CFG','REG_STAFF_QUALIFY','REG_STAFF_SIGNATURE',
        'REG_STAFF_SIGNATURE_CFG','REG_STATE','REG_STU_AT_RISK','REG_STU_AT_RISK_CALC','REG_STU_CONT_HIST','REG_STU_CONTACT','REG_STU_CONTACT_ALERT','REG_STU_CONTACT_ALERT_ATT',
        'REG_STU_CONTACT_ALERT_AVG','REG_STU_CONTACT_ALERT_DISC','REG_STU_CONTACT_ALERT_GB','REG_SUMMER_SCHOOL','REG_TRACK','REG_TRAVEL','REG_USER','REG_USER_BUILDING',
        'REG_USER_DISTRICT','REG_USER_PLAN_AREA','REG_USER_STAFF','REG_USER_STAFF_BLD','REG_YREND_CRITERIA','REG_YREND_RUN','REG_YREND_RUN_CAL','REG_YREND_RUN_CRIT',
        'REG_YREND_SELECT','REG_YREND_STUDENTS','REG_YREND_UPDATE','REGPROG_YREND_RUN','REGPROG_YREND_TABS','REGTB_ACADEMIC_DIS','REGTB_ACCDIST','REGTB_ALT_PORTFOLIO',
        'REGTB_APPT_TYPE','REGTB_AR_ACT641','REGTB_AR_ANTICSVCE','REGTB_AR_BARRIER','REGTB_AR_BIRTHVER','REGTB_AR_CNTYRESID','REGTB_AR_COOPS','REGTB_AR_CORECONT',
        'REGTB_AR_DEVICE_ACC','REGTB_AR_ELDPROG','REGTB_AR_ELL_MONI','REGTB_AR_FACTYPE','REGTB_AR_HOMELESS','REGTB_AR_IMMSTATUS','REGTB_AR_INS_CARRI','REGTB_AR_LEARNDVC',
        'REGTB_AR_MILITARYDEPEND','REGTB_AR_NETPRFRM','REGTB_AR_NETTYPE','REGTB_AR_PRESCHOOL','REGTB_AR_RAEL','REGTB_AR_SCH_LEA','REGTB_AR_SEND_LEA','REGTB_AR_SHAREDDVC',
        'REGTB_AR_STU_INSTRUCT','REGTB_AR_SUP_SVC','REGTB_AT_RISK_REASON','REGTB_ATTACHMENT_CATEGORY','REGTB_BLDG_REASON','REGTB_BLDG_TYPES','REGTB_CC_BLDG_TYPE',
        'REGTB_CC_MARK_TYPE','REGTB_CITIZENSHIP','REGTB_CLASSIFY','REGTB_COMPLEX','REGTB_COMPLEX_TYPE','REGTB_COUNTRY','REGTB_COUNTY','REGTB_CURR_CODE','REGTB_DAY_TYPE',
        'REGTB_DEPARTMENT','REGTB_DIPLOMAS','REGTB_DISABILITY','REGTB_EDU_LEVEL','REGTB_ELIG_REASON','REGTB_ELIG_STATUS','REGTB_ENTRY','REGTB_ETHNICITY','REGTB_GENDER_IDENTITY',
        'REGTB_GENERATION','REGTB_GRAD_PLANS','REGTB_GRADE_CEDS_CODE','REGTB_GRADE_PESC_CODE','REGTB_GROUP_USED_FOR','REGTB_HISPANIC','REGTB_HOLD_RC_CODE','REGTB_HOME_BLDG_TYPE',
        'REGTB_HOMELESS','REGTB_HOSPITAL','REGTB_HOUSE_TEAM','REGTB_IEP_STATUS','REGTB_IMMUN_STATUS','REGTB_IMMUNS','REGTB_LANGUAGE','regtb_language_SD091114','REGTB_LEARNING_LOCATION',
        'REGTB_MEAL_STATUS','REGTB_MED_PROC','REGTB_MEDIC_ALERT','REGTB_NAME_CHGRSN ','REGTB_NOTE_TYPE','REGTB_PESC_CODE','REGTB_PHONE','REGTB_PROC_STATUS','REGTB_PROG_ENTRY',
        'REGTB_PROG_WITH','REGTB_QUALIFY','REGTB_RELATION','REGTB_RELATION_PESC_CODE','REGTB_REQ_GROUP','REGTB_RESIDENCY','REGTB_ROOM_TYPE','REGTB_SCHOOL','REGTB_SCHOOL_YEAR',
        'REGTB_SIF_AUTH_MAP','REGTB_SIF_JOBCLASS','REGTB_ST_PREFIX','REGTB_ST_SUFFIX','REGTB_ST_TYPE','REGTB_STATE_BLDG','REGTB_TITLE','REGTB_TRANSPORT_CODE','REGTB_TRAVEL',
        'REGTB_WITHDRAWAL','SCHD_ALLOCATION','SCHD_CFG','SCHD_CFG_DISC_OFF','SCHD_CFG_ELEM_AIN','SCHD_CFG_FOCUS_CRT','SCHD_CFG_HOUSETEAM','SCHD_CFG_HRM_AIN','SCHD_CFG_INTERVAL',
        'SCHD_CNFLCT_MATRIX','SCHD_COURSE','SCHD_COURSE_BLOCK','SCHD_COURSE_GPA','SCHD_COURSE_GRADE','SCHD_COURSE_HONORS','SCHD_COURSE_QUALIFY','SCHD_COURSE_SEQ','SCHD_COURSE_SUBJ',
        'SCHD_COURSE_SUBJ_TAG','SCHD_COURSE_USER','SCHD_CRS_BLDG_TYPE','SCHD_CRS_GROUP_DET','SCHD_CRS_GROUP_HDR','SCHD_CRS_MARK_TYPE','SCHD_CRS_MSB_COMBO','SCHD_CRS_MSB_DET',
        'SCHD_CRS_MSB_HDR','SCHD_CRS_MSB_PATRN','SCHD_CRSSEQ_MARKTYPE','SCHD_DISTCRS_BLDG_TYPES','SCHD_DISTCRS_SECTIONS_OVERRIDE','SCHD_DISTRICT_CFG','SCHD_DISTRICT_CFG_UPD',
        'SCHD_LUNCH_CODE','SCHD_MS','SCHD_MS_ALT_LANG','SCHD_MS_BLDG_TYPE','SCHD_MS_BLOCK','SCHD_MS_CYCLE','SCHD_MS_GPA','SCHD_MS_GRADE','SCHD_MS_HONORS','SCHD_MS_HOUSE_TEAM',
        'SCHD_MS_HRM_AIN','SCHD_MS_KEY','SCHD_MS_LUNCH','SCHD_MS_MARK_TYPES','SCHD_MS_MP','SCHD_MS_QUALIFY','SCHD_MS_SCHEDULE','SCHD_MS_SESSION','SCHD_MS_STAFF','SCHD_MS_STAFF_DATE',
        'SCHD_MS_STAFF_STUDENT','SCHD_MS_STAFF_STUDENT_pa','SCHD_MS_STAFF_USER','SCHD_MS_STU_FILTER','SCHD_MS_STUDY_SEAT','SCHD_MS_SUBJ','SCHD_MS_SUBJ_TAG','SCHD_MS_USER',
        'SCHD_MSB_MEET_CYC','SCHD_MSB_MEET_DET','SCHD_MSB_MEET_HDR','SCHD_MSB_MEET_PER','SCHD_PARAMS','SCHD_PARAMS_SORT','SCHD_PERIOD','SCHD_PREREQ_COURSE_ERR','SCHD_REC_TAKEN',
        'SCHD_RESOURCE','SCHD_RESTRICTION','SCHD_RUN','SCHD_RUN_TABLE','SCHD_SCAN_REQUEST','SCHD_STU_CONF_CYC','SCHD_STU_CONF_MP','SCHD_STU_COURSE','SCHD_STU_CRS_DATES',
        'SCHD_STU_PREREQOVER','SCHD_STU_RECOMMEND','SCHD_STU_REQ','SCHD_STU_REQ_MP','SCHD_STU_STAFF_USER','SCHD_STU_STATUS','SCHD_STU_USER','SCHD_TIMETABLE','SCHD_TIMETABLE_HDR',
        'SCHD_TMP_STU_REQ_LIST','SCHD_UNSCANNED','SCHD_YREND_RUN','SCHDTB_AR_DIG_LRN','SCHDTB_AR_DIST_PRO','SCHDTB_AR_HQT','SCHDTB_AR_INST','SCHDTB_AR_JOBCODE','SCHDTB_AR_LEARN',
        'SCHDTB_AR_LIC_EX','SCHDTB_AR_TRANSVEN','SCHDTB_AR_VOCLEA','SCHDTB_COURSE_NCES_CODE','SCHDTB_CREDIT_BASIS','SCHDTB_CREDIT_BASIS_PESC_CODE','SCHDTB_SIF_CREDIT_TYPE',
        'SCHDTB_SIF_INSTRUCTIONAL_LEVEL','SCHDTB_STU_COURSE_TRIGGER','SCHOOLOGY_ASMT_XREF','SCHOOLOGY_INTF_DET','SCHOOLOGY_INTF_HDR','SDE_CAMPUS','SDE_CERT','SDE_DIST_CFG',
        'SDE_INSTITUTION','SDE_IPP_TRANSACTIONS_DATA','SDE_PESC_IMPORT','SDE_PESC_TRANSCRIPT','SDE_SECURITY','SDE_SESSION_TRACKER','SDE_TRANSACTION_TIME','SDE_TRANSCRIPT',
        'SDE_TRANSCRIPT_CONFIGURATION','SEC_GLOBAL_ID','SEC_LOOKUP_INFO','SEC_LOOKUP_MENU_ITEMS','SEC_LOOKUP_MENU_REL','SEC_LOOKUP_NON_MENU','SEC_USER','SEC_USER_AD','SEC_USER_BUILDING',
        'SEC_USER_MENU_CACHE','SEC_USER_RESOURCE','SEC_USER_ROLE','SEC_USER_ROLE_BLDG_OVR','SEC_USER_STAFF','SECTB_ACTION_FEATURE','SECTB_ACTION_RESOURCE','SECTB_PACKAGE',
        'SECTB_PAGE_RESOURCE','SECTB_RESOURCE','SECTB_SUBPACKAGE','SIF_AGENT_CFG','SIF_EVENT_DET','SIF_EVENT_HDR','SIF_EXTENDED_MAP','SIF_GUID_ATT_CLASS','SIF_GUID_ATT_CODE',
        'SIF_GUID_ATT_DAILY','SIF_GUID_AUTH','SIF_GUID_BUILDING','SIF_GUID_BUS_DETAIL','SIF_GUID_BUS_INFO','SIF_GUID_BUS_ROUTE','SIF_GUID_BUS_STOP','SIF_GUID_BUS_STU',
        'SIF_GUID_CALENDAR_SUMMARY','SIF_GUID_CONTACT','SIF_GUID_COURSE','SIF_GUID_CRS_SESS','SIF_GUID_DISTRICT','SIF_GUID_GB_ASMT','SIF_GUID_HOSPITAL','SIF_GUID_IEP',
        'SIF_GUID_MED_ALERT','SIF_GUID_PROGRAM','SIF_GUID_REG_EW','SIF_GUID_ROOM','SIF_GUID_STAFF','SIF_GUID_STAFF_BLD','SIF_GUID_STU_SESS','SIF_GUID_STUDENT','SIF_GUID_TERM',
        'SIF_LOGFILE','SIF_PROGRAM_COLUMN','SIF_PROVIDE','SIF_PUBLISH','SIF_REQUEST_QUEUE','SIF_RESPOND','SIF_SUBSCRIBE','SIF_USER_FIELD','SMS_CFG','SMS_PROGRAM_RULES',
        'SMS_PROGRAM_RULES_MESSAGES','SMS_USER_FIELDS','SMS_USER_RULES','SMS_USER_RULES_MESSAGES','SMS_USER_SCREEN','SMS_USER_SCREEN_COMB_DET','SMS_USER_SCREEN_COMB_HDR',
        'SMS_USER_TABLE','SPI_APPUSERDEF','SPI_AUDIT_DET1','SPI_AUDIT_DET2','SPI_AUDIT_HISTORY','SPI_AUDIT_HISTORY_FIELDS','SPI_AUDIT_HISTORY_KEYS','SPI_AUDIT_SESS',
        'SPI_AUDIT_TASK','SPI_AUDIT_TASK_PAR','SPI_BACKUP_TABLES','SPI_BLDG_PACKAGE','SPI_BUILDING_LIST','Spi_checklist_menu_items','SPI_CHECKLIST_RESULTS','SPI_CHECKLIST_SETUP_DET',
        'SPI_CHECKLIST_SETUP_HDR','SPI_CODE_IN_USE','SPI_CODE_IN_USE_FILTER','SPI_COLUMN_CONTROL','SPI_COLUMN_INFO','SPI_COLUMN_NAMES','SPI_COLUMN_VALIDATION','SPI_CONFIG_EXTENSION',
        'SPI_CONFIG_EXTENSION_DETAIL','SPI_CONFIG_EXTENSION_ENVIRONMENT','SPI_CONVERT','SPI_CONVERT_CONTACT','SPI_CONVERT_ERROR_LOG','SPI_CONVERT_MAP','SPI_CONVERT_STAFF',
        'SPI_CONVERT_TYPE','SPI_COPY_CALC','SPI_COPY_DET','spi_copy_det_731719','SPI_COPY_HDR','spi_copy_hdr_731719','SPI_COPY_JOIN','SPI_COPY_LINK','spi_copy_link_731719',
        'SPI_COPY_MS_DET','SPI_CUST_TEMPLATES','SPI_CUSTOM_CODE','SPI_CUSTOM_DATA','SPI_CUSTOM_LAUNCH','SPI_CUSTOM_MODS','SPI_CUSTOM_SCRIPT','SPI_DATA_CACHE','SPI_DIST_BUILDING_CHECKLIST',
        'SPI_DIST_PACKAGE','SPI_DISTRICT_INIT','SPI_DYNAMIC_CONTAINERTYPE','SPI_DYNAMIC_LAYOUT','SPI_DYNAMIC_PAGE','SPI_DYNAMIC_PAGE_WIDGET','SPI_DYNAMIC_SETTING','SPI_DYNAMIC_WIDGET',
        'SPI_DYNAMIC_WIDGET_SETTING','SPI_DYNAMIC_WIDGET_TYPE','SPI_EVENT','SPI_FEEDBACK_ANS','SPI_FEEDBACK_Q_HDR','SPI_FEEDBACK_QUEST','SPI_FEEDBACK_RECIP','SPI_FIELD_HELP',
        'SPI_FIRSTWAVE','SPI_HAC_NEWS','SPI_HAC_NEWS_BLDG','SPI_HOME_SECTIONS','SPI_HOME_USER_CFG','SPI_HOME_USER_SEC','SPI_IEPWEBSVC_CFG','SPI_IMM_TSK_RESULT','SPI_INPROG',
        'SPI_INTEGRATION_DET','SPI_INTEGRATION_HDR','SPI_INTEGRATION_LOGIN','SPI_INTEGRATION_SESSION_DET','SPI_INTEGRATION_SESSION_HDR','SPI_INTEGRATION_STUDATA_DET',
        'SPI_INTEGRATION_STUDATA_HDR','SPI_JOIN_COND','SPI_JOIN_SELECT','SPI_MAP_CFG','SPI_NEWS','SPI_NEWS_BLDG','SPI_OBJECT_PERM','SPI_OPTION_COLUMN_NULLABLE','SPI_OPTION_EXCLD',
        'SPI_OPTION_LIST_FIELD','SPI_OPTION_NAME','SPI_OPTION_SIMPLE_SEARCH','SPI_OPTION_TABLE','SPI_OPTION_UPDATE','SPI_POWERPACK_CONFIGURATION','SPI_PRIVATE_FIELD','SPI_RESOURCE',
        'SPI_RESOURCE_OVERRIDE','SPI_SEARCH_FAV','SPI_SEARCH_FAV_SUBSCRIBE','SPI_SECONDARY_KEY_USED','SPI_SESSION_STATE','SPI_STATE_REQUIREMENTS','SPI_TABLE_JOIN','SPI_TABLE_NAMES',
        'SPI_TASK','SPI_TASK_ERR_DESC','SPI_TASK_ERROR','SPI_TASK_LOG_DET','SPI_TASK_LOG_HDR','SPI_TASK_LOG_MESSAGE','SPI_TASK_LOG_PARAMS','SPI_TASK_PARAMS','SPI_TASK_PROG',
        'SPI_TIME_OFFSET','SPI_TMP_WATCH_LIST','SPI_TRIGGER_STATE','SPI_USER_GRID','SPI_USER_OPTION','SPI_USER_OPTION_BLDG','SPI_USER_PROMPT','SPI_USER_SEARCH',
        'SPI_USER_SEARCH_LIST_FIELD','SPI_USER_SORT','SPI_VAL_TABS','SPI_VALIDATION_TABLES','SPI_VERSION','SPI_WATCH_LIST','SPI_WATCH_LIST_STUDENT','SPI_WORKFLOW_MESSAGES',
        'SPI_Z_SCALE','SPITB_SEARCH_FAV_CATEGORY','SSP_CFG','SSP_CFG_AUX','SSP_CFG_PLAN_GOALS','SSP_CFG_PLAN_INTERVENTIONS','SSP_CFG_PLAN_REASONS','SSP_CFG_PLAN_RESTRICTIONS',
        'SSP_COORDINATOR','SSP_COORDINATOR_FILTER','SSP_DISTRICT_CFG','SSP_GD_SCALE_DET','SSP_GD_SCALE_HDR','SSP_INTER_FREQ_DT','SSP_INTER_MARKS','SSP_INTERVENTION','SSP_MARK_TYPES',
        'SSP_PARENT_GOAL','SSP_PARENT_OBJECTIVE','SSP_PERF_LEVEL_DET','SSP_PERF_LEVEL_HDR','SSP_QUAL_DET','SSP_QUAL_HDR','SSP_QUAL_SEARCH','SSP_RSN_TEMP_GOAL','SSP_RSN_TEMP_GOAL_OBJ',
        'SSP_RSN_TEMP_HDR','SSP_RSN_TEMP_INT','SSP_RSN_TEMP_PARENT_GOAL','SSP_RSN_TEMP_PARENT_GOAL_OBJ','SSP_STU_AT_RISK','SSP_STU_GOAL','SSP_STU_GOAL_STAFF','SSP_STU_GOAL_TEMP',
        'SSP_STU_GOAL_USER','SSP_STU_INT','SSP_STU_INT_COMM','SSP_STU_INT_FREQ_DT','SSP_STU_INT_PROG','SSP_STU_INT_STAFF','SSP_STU_INT_TEMP','SSP_STU_OBJ_USER','SSP_STU_OBJECTIVE',
        'SSP_STU_PLAN','SSP_STU_PLAN_USER','SSP_USER_FIELDS','SSP_YEAREND_RUN','SSPTB_AIS_LEVEL','SSPTB_AIS_TYPE','SSPTB_GOAL','SSPTB_GOAL_LEVEL','SSPTB_OBJECTIVE','SSPTB_PLAN_STATUS',
        'SSPTB_PLAN_TYPE','SSPTB_ROLE_EVAL','STATE_DISTDEF_SCREENS','STATE_DNLD_SUM_INFO','STATE_DNLD_SUM_TABLES','STATE_DNLD_SUMMARY','STATE_DOWNLOAD_AUDIT','STATE_DWNLD_COLUMN_NAME',
        'STATE_OCR_BLDG_CFG','STATE_OCR_BLDG_MARK_TYPE','STATE_OCR_BLDG_RET_EXCLUDED_CALENDAR','STATE_OCR_DETAIL','STATE_OCR_DIST_ATT','STATE_OCR_DIST_CFG','STATE_OCR_DIST_COM',
        'STATE_OCR_DIST_DISC','STATE_OCR_DIST_EXP','STATE_OCR_DIST_LTDB_TEST','STATE_OCR_DIST_STU_DISC_XFER','STATE_OCR_NON_STU_DET','STATE_OCR_QUESTION','STATE_OCR_SUMMARY',
        'STATE_TASK_LOG_CFG','STATE_TASK_LOG_DET','STATE_TASK_LOG_HDR','STATE_VLD_GROUP','STATE_VLD_GRP_MENU','STATE_VLD_GRP_RULE','STATE_VLD_GRP_USER','STATE_VLD_RESULTS',
        'STATE_VLD_RULE','STATETB_AP_SUBJECT','STATETB_DEF_CLASS','STATETB_ENTRY_SOURCE','STATETB_OCR_COM_TYPE','STATETB_OCR_COUNT_TYPE','STATETB_OCR_DISC_TYPE','STATETB_OCR_EXP_TYPE',
        'Statetb_Ocr_Record_types','STATETB_RECORD_FIELDS','STATETB_RECORD_TYPES','STATETB_RELIGION','STATETB_STAFF_ROLE','STATETB_SUBMISSION_COL','STATETB_SUBMISSIONS',
        'TAC_CFG','TAC_CFG_ABS_SCRN','TAC_CFG_ABS_SCRN_CODES','TAC_CFG_ABS_SCRN_DET','TAC_CFG_ATTACH','TAC_CFG_ATTACH_CATEGORIES','TAC_CFG_HAC','TAC_DISTRICT_CFG','TAC_ISSUE',
        'TAC_ISSUE_ACTION','TAC_ISSUE_REFER','TAC_ISSUE_REFER_SSP','TAC_ISSUE_RELATED','TAC_ISSUE_STUDENT','TAC_LINK','TAC_LINK_MACRO','TAC_LUNCH_COUNTS','TAC_LUNCH_TYPES',
        'TAC_MENU_ITEMS','TAC_MESSAGES','TAC_MS_SCHD','TAC_MSG_CRS_DATES','TAC_PRINT_RC','TAC_SEAT_CRS_DET','TAC_SEAT_CRS_HDR','TAC_SEAT_HRM_DET','TAC_SEAT_HRM_HDR','TAC_SEAT_PER_DET',
        'TAC_SEAT_PER_HDR','TACTB_ISSUE','TACTB_ISSUE_ACTION','TACTB_ISSUE_LOCATION','tmp_medtb_vis_exam_ark','WSSecAuthenticationLogTbl')]
        [string]$Page,
        [Parameter(Mandatory=$true,ParameterSetName="awesomeSauce")]
        [ValidateSet('_tblStateCourses','API_AUTH_LOG','API_CALLER_CFG','API_CALLER_CFG_OPTIONS','API_CALLER_SECURE_DET','API_CALLER_SUBSCRIBE','API_DELTA_CACHE','API_DISTRICT_DEFINED',
        'API_GUID_GB_ASMT','API_GUID_GB_SCORE','API_LOG','API_PROGRAMS','API_RULE_DET','API_RULE_HDR','API_RULE_SCOPES','API_RULE_SUBQUERY_JOIN','AR_CLASS_DOWN','AR_DOWN_ALE_DAYS',
        'AR_DOWN_ATTEND','AR_DOWN_CAL','AR_DOWN_DISCIPLINE','AR_DOWN_DISTRICT','AR_DOWN_EC','AR_DOWN_EIS1','AR_DOWN_EIS2','AR_DOWN_EMPLOYEE','AR_DOWN_GRADUATE','AR_DOWN_HEARING',
        'AR_DOWN_JOBASSIGN','AR_DOWN_REFERRAL','AR_DOWN_REGISTER','AR_DOWN_SCHL_AGE','AR_DOWN_SCHOOL','AR_DOWN_SCOLIOSIS','AR_DOWN_SE_STAFF','AR_DOWN_STU','AR_DOWN_STU_ID',
        'AR_DOWN_STUDENT_GRADES','AR_DOWN_VISION','ARTB_21CCLC','ARTB_DIST_LEARN','ARTB_DIST_LRNPROV','ARTB_DISTRICTS','ARTB_EC_ANTIC_SVC','ARTB_EC_DISAB','ARTB_EC_RELATE_SVC',
        'ARTB_INSTITUTIONS','ARTB_LEPMONITORED','ARTB_OTHERDISTRICT','ARTB_OUT_DIST','ARTB_RESIDENT','ARTB_RPT_PERIODS','ARTB_SA_ANTIC_SVC','ARTB_SA_DISAB','ARTB_SA_RELATE_SVC',
        'ARTB_SCHOOL_GRADE','ARTB_SE_CERT_STAT','ARTB_SE_DEV_NEEDS','ARTB_SE_EDD_3RD','ARTB_SE_EDD_REASON','ARTB_SE_EDU_ENVIRN','ARTB_SE_EDU_NEEDS','ARTB_SE_EDU_PLACE','ARTB_SE_EVAL_CODE',
        'ARTB_SE_EVL_EXCEED','ARTB_SE_FUNC_IMP','ARTB_SE_FUNC_SCORE','ARTB_SE_GRADE_LVL','ARTB_SE_INT_SERV','ARTB_SE_PROG_TYPE','ARTB_SE_REASON_NOT_ACCESSED','ARTB_SE_REFERRAL',
        'ARTB_SE_RFC_REASON','artb_se_staf_disab','ARTB_SE_TITLE_CODE','ARTB_SE_TRANS_CODE','ARTB_TUITION','ATT_AUDIT_TRAIL','ATT_BOTTOMLINE','ATT_CFG','ATT_CFG_CODES','ATT_CFG_MISS_SUB',
        'ATT_CFG_PERIODS','ATT_CODE','ATT_CODE_BUILDING','ATT_CONFIG_PERCENT','ATT_COURSE_SEATING','ATT_EMERGENCY','ATT_EMERGENCY_CFG','ATT_HRM_SEATING','ATT_INTERVAL','ATT_LOCK_DATE',
        'ATT_NOTIFY_CRIT','ATT_NOTIFY_CRIT_CD','ATT_NOTIFY_CRIT_PD','ATT_NOTIFY_ELIG_CD','ATT_NOTIFY_GROUP','ATT_NOTIFY_LANG','ATT_NOTIFY_STU_DET','ATT_NOTIFY_STU_HDR','ATT_PERIOD',
        'ATT_STU_AT_RISK','ATT_STU_COURSE_SEAT','ATT_STU_DAY_TOT_LAST','ATT_STU_DAY_TOTALS','ATT_STU_ELIGIBLE','ATT_STU_HRM_SEAT','ATT_STU_INT_CRIT','ATT_STU_INT_GROUP','ATT_STU_INT_MEMB',
        'ATT_TWS_TAKEN','ATT_VIEW_ABS','ATT_VIEW_CYC','ATT_VIEW_DET','ATT_VIEW_HDR','ATT_VIEW_INT','ATT_VIEW_MSE_BLDG','ATT_VIEW_PER','ATT_YREND_RUN','ATTTB_DISTRICT_GRP','ATTTB_INELIGIBLE',
        'ATTTB_SIF_STATUS','ATTTB_SIF_TYPE','ATTTB_STATE_GRP','BOOK_ALT_LOCATION','BOOK_ASSIGN','BOOK_BLDG_CFG','BOOK_BOOKMASTER','BOOK_CFG','BOOK_DIST','BOOK_ENROLL','BOOK_GRADES',
        'BOOK_MLC_COURSE','BOOK_REQ_DET','BOOK_REQ_HDR','BOOK_STU_BOOKS','BOOK_TEXTBOOK','BOOK_TRANS','BOOK_WAREALTLOC','BOOKTB_ADJ_COMMENT','BOOKTB_ADOPTION','BOOKTB_DEPOSITORY',
        'BOOKTB_MLC','BOOKTB_PUBLISHER','BOOKTB_TYPE','COTB_REPORT_PERIOD','CP_CFG','CP_GRADPLAN_COURSE','CP_GRADPLAN_GD','CP_GRADPLAN_HDR','CP_GRADPLAN_SUBJ','CP_STU_COURSE_OVR',
        'CP_STU_FUTURE_REQ','CP_STU_GRAD','CP_STU_GRAD_AREA','CP_STU_PLAN_ALERT','CP_VIEW_HDR','CP_VIEW_LTDB','CP_VIEW_MARKS','CP_VIEW_MARKS_MP','CP_VIEW_WORKSHEET','CRN_CFG',
        'DISC_ACT_USER','DISC_ATT_NOTIFY','DISC_CFG','DISC_CFG_LANG','DISC_DIST_CFG_AUTO_ACTION','DISC_DIST_OFF_TOT','DISC_DISTRICT_ACT','DISC_DISTRICT_CFG','DISC_DISTRICT_CFG_DETAIL',
        'DISC_DISTRICT_CFG_SUMMARY','DISC_DISTRICT_COST','DISC_DISTRICT_FINE','DISC_DISTRICT_TOT','DISC_INCIDENT','DISC_INCIDENT_CODE','DISC_LINK_ISSUE','DISC_LTR_CRIT','DISC_LTR_CRIT_ACT',
        'DISC_LTR_CRIT_ELIG','DISC_LTR_CRIT_OFF','DISC_LTR_DETAIL','DISC_LTR_HEADER','DISC_MSG_ACTIONCODE','DISC_NON_STU_RACES','DISC_NON_STUDENT','DISC_NOTES','DISC_OCCURRENCE',
        'DISC_OFF_ACTION','DISC_OFF_CHARGE','DISC_OFF_CODE','DISC_OFF_CONVICT','DISC_OFF_DRUG','DISC_OFF_FINE','DISC_OFF_SUBCODE','DISC_OFF_WEAPON','DISC_OFFENDER','DISC_PRINT_CITATION',
        'DISC_STU_AT_RISK','DISC_STU_ELIGIBLE','DISC_STU_ROLLOVER','DISC_USER','DISC_VICTIM','DISC_VICTIM_ACTION','DISC_VICTIM_INJURY','DISC_WITNESS','DISC_YEAREND_RUN','DISCTB_ACT_OUTCOME',
        'DISCTB_CHARGE','DISCTB_CONVICTION','DISCTB_DISPOSITION','DISCTB_DRUG','DISCTB_INC_SUBCODE','DISCTB_INJURY','DISCTB_LOCATION','DISCTB_MAGISTRATE','DISCTB_NOTIFIED',
        'DISCTB_OFF_ACTION','DISCTB_OFF_SUBCODE','DISCTB_POLICE_ACT','DISCTB_REASON','DISCTB_REFERRAL','DISCTB_TIMEFRAME','DISCTB_VIC_ACTION','DISCTB_VIC_CODE','DISCTB_VIC_DISP',
        'DISCTB_VIC_REASON','DISCTB_VIC_SUBCODE','DISCTB_WEAPON','DISCTB_WIT_CODE','DISCTB_WIT_SUBCODE','dtproperties','ESP_MENU_FAVORITES','ESP_MENU_ITEMS','FEE_CFG','FEE_CFG_PRO_RATE',
        'FEE_CFG_REDUCED','FEE_GROUP_CRIT','FEE_GROUP_DET','FEE_GROUP_HDR','FEE_ITEM','FEE_STU_AUDIT','FEE_STU_GROUP','FEE_STU_ITEM','FEE_STU_PAYMENT','FEE_TEXTBOOK','FEE_TEXTBOOK_CRS',
        'FEE_TEXTBOOK_TEA','FEE_YREND_RUN','FEETB_CATEGORY','FEETB_PAYMENT','FEETB_STU_STATUS','FEETB_SUB_CATEGORY','FEETB_UNIT_DESCR','GDBK_POST_CLS','GDBK_POST_DAT','GDBK_POST_IPR_COMM',
        'GDBK_POST_IPR_MARK','GDBK_POST_RC','GDBK_POST_RC_ABS','GDBK_POST_RC_COMM','GDBK_POST_RC_MARK','HAC_BUILDING_ALERT','HAC_BUILDING_ALERT_MARK_TYPE','HAC_Building_Cfg',
        'HAC_BUILDING_CFG_AUX','HAC_BUILDING_CFG_CONTACTS','HAC_BUILDING_CFG_DISC','HAC_BUILDING_CFG_HDR_RRK','HAC_BUILDING_CFG_INTER','HAC_BUILDING_CFG_RRK','HAC_CHALLENGE_QUES',
        'HAC_DIST_CFG_LDAP','HAC_DIST_CFG_ONLINE_PAYMT','HAC_DIST_CFG_PWD','HAC_District_Cfg','HAC_FAILED_LOGIN_ATTEMPTS','HAC_LINK','HAC_LINK_MACRO','HAC_MENU_LINKED_PAGES','HAC_MENULIST',
        'HAC_OLD_USER','HAC_ONLINE_PAYMENT','HAC_TRANSLATION','IEP_STUDENT_FILES','LTDB_DASHBOARD','ltdb_group_det','ltdb_group_hdr','LTDB_IMPORT_DEF','LTDB_IMPORT_DET','LTDB_IMPORT_HDR',
        'LTDB_IMPORT_TRN','LTDB_INTERFACE_DEF','LTDB_INTERFACE_DET','LTDB_INTERFACE_HDR','LTDB_INTERFACE_STU','LTDB_INTERFACE_TRN','LTDB_SCORE_HAC','LTDB_STU_AT_RISK','LTDB_STU_SUBTEST',
        'LTDB_STU_TEST','LTDB_STU_TRACKING','LTDB_STU_TRK_DATA','LTDB_SUBTEST','LTDB_SUBTEST_HAC','LTDB_SUBTEST_SCORE','LTDB_TEST','LTDB_TEST_BUILDING','LTDB_TEST_HAC','LTDB_TEST_TRACKING',
        'LTDB_USER_TEST','LTDB_VIEW_DET','LTDB_VIEW_HDR','LTDB_YEAREND_RUN','LTDBTB_SCORE_PESC_CODE','LTDBTB_SCORE_TYPE','LTDBTB_SUBTEST_PESC_CODE','LTDBTB_TEST_PESC_CODE',
        'MD_ATTENDANCE_DOWN','MD_LEVEL_MARKS','MD_PROCESS_SECTION','MD_PROCESS_STUDENT','MD_RUN','MD_SCGT_BLDG_ATT_VIEW_TYPE','MD_SCGT_BLDG_CFG','MD_SCGT_BLDG_MARK_TYPE','MD_SCGT_DOWN',
        'MDTB_CLASS_OF_RECORD','MDTB_COURSE_COMPLETION_STATUS','MDTB_CRS_PLACEMENT','MDTB_HSA_SUBJECT','MED_CFG','MED_CFG_LANG','MED_CUSTOM_EXAM_COLUMN','MED_CUSTOM_EXAM_ELEMENT',
        'MED_CUSTOM_EXAM_KEY','MED_CUSTOM_EXAM_TYPE','MED_DENTAL','MED_DENTAL_COLS','MED_DISTRICT_CFG','MED_GENERAL','MED_GRACE_SCHD','MED_GROWTH','MED_GROWTH_ARK','MED_GROWTH_BMI_ARK',
        'MED_HEARING','MED_HEARING_COLS','MED_HEARING_DET','MED_IMM_CRIT','MED_IMM_CRIT_GRP','med_imm_crit_grp_SD091114','med_imm_crit_SD091114','MED_IMM_CRIT_SHOTS',
        'med_imm_crit_shots_SD091114','MED_ISSUED','MED_NOTES','MED_OFFICE','MED_OFFICE_DET','MED_OFFICE_SCHD','MED_PHYSICAL','MED_PHYSICAL_EXAM','MED_REFERRAL','MED_REQUIRED',
        'MED_SCOLIOSIS','MED_SCREENING','MED_SERIES','MED_SERIES_DET','MED_SERIES_SCHD_BOOSTER','MED_SERIES_SCHD_HDR','med_series_schd_hdr_SD091114','MED_SERIES_SCHD_TYPES',
        'MED_SERIES_SCHED','med_series_sched_SD091114','MED_SHOT','MED_SHOT_DET','MED_STU_LETTER','MED_USER','MED_VISION','MED_VISION_COLS','MED_VITALS','MED_YEAREND_RUN',
        'MEDTB_ALT_DOSE','MEDTB_ALT_DOSE_DET','MEDTB_BMI_STATUS','MEDTB_CDC_LMS','MEDTB_DECIBEL','MEDTB_EVENT','MEDTB_EXAM','MEDTB_EXEMPT','MEDTB_FOLLOWUP','MEDTB_FREQUENCY','MEDTB_LENS',
        'MEDTB_LOCATION','MEDTB_MEDICINE','MEDTB_OUTCOME','MEDTB_PERCENTS','MEDTB_PERCENTS_ARK','MEDTB_REFER','MEDTB_SCREENING','MEDTB_SHOT','MEDTB_SOURCE_DOC','MEDTB_STATUS',
        'MEDTB_TEMP_METHOD','MEDTB_TREATMENT','MEDTB_VACCINATION_PESC_CODE','medtb_vis_exam_ark','MEDTB_VISION_EXAM_TYPE','MEDTB_VISIT','MENU_ITEMS','MR_ABSENCE_TYPES','MR_ABSENCE_VALID',
        'MR_ALT_LANG_CFG','MR_AVERAGE_CALC','MR_AVERAGE_SETUP','MR_CFG','mr_cfg_hold_fee','mr_cfg_hold_status','MR_CFG_LANG','MR_CFG_MISS_SUB','MR_CLASS_SIZE','MR_COMMENT_TYPES',
        'MR_COMMENT_VALID','MR_COMMENTS','MR_COMMENTS_ALT_LANG','MR_CRDOVR_REASON','MR_CREDIT_SETUP','MR_CREDIT_SETUP_AB','MR_CREDIT_SETUP_GD','MR_CREDIT_SETUP_MK','MR_CRSEQU_DET',
        'MR_CRSEQU_HDR','MR_CRSEQU_SETUP','MR_CRSEQU_SETUP_AB','MR_CRSEQU_SETUP_MK','MR_GB_ACCUMULATED_AVG','MR_GB_ALPHA_MARKS','MR_GB_ASMT','MR_GB_ASMT_COMP','MR_GB_ASMT_STU_COMP',
        'MR_GB_ASMT_STU_COMP_ATTACH','MR_GB_ASMT_STU_COMP_COMP','MR_GB_AVG_CALC','MR_GB_CAT_AVG','MR_GB_CAT_BLD','MR_GB_CAT_SESS_MARK','MR_GB_CAT_SESSION','MR_GB_CAT_STU_COMP',
        'MR_GB_CATEGORY_TYPE_DET','MR_GB_CATEGORY_TYPE_HDR','MR_GB_COMMENT','MR_GB_IPR_AVG','MR_GB_LOAD_AVG_ERR','MR_GB_MARK_AVG','MR_GB_MP_MARK','MR_GB_RUBRIC_CRIT','MR_GB_RUBRIC_DET',
        'MR_GB_RUBRIC_HDR','MR_GB_RUBRIC_PERF_LVL','MR_GB_SCALE','MR_GB_SCALE_DET','MR_GB_SESSION_PROP','MR_GB_STU_ALIAS','MR_GB_STU_ASMT_CMT','MR_GB_STU_COMP_ACCUMULATED_AVG',
        'MR_GB_STU_COMP_CAT_AVG','MR_GB_STU_COMP_STU_SCORE','MR_GB_STU_COMP_STU_SCORE_HIST','MR_GB_STU_COMPS_ALIAS','MR_GB_STU_COMPS_STU_ASMT_CMT','MR_GB_STU_COMPS_STU_NOTES',
        'MR_GB_STU_NOTES','MR_GB_STU_SCALE','MR_GB_STU_SCORE','MR_GB_STU_SCORE_HIST','MR_GPA_SETUP','MR_GPA_SETUP_BLDG','MR_GPA_SETUP_EXCL','MR_GPA_SETUP_GD','MR_GPA_SETUP_MK_GD',
        'MR_GPA_SETUP_MRK','MR_GRAD_REQ_DET','MR_GRAD_REQ_FOCUS','MR_GRAD_REQ_HDR','MR_GRAD_REQ_MRK_TYPE','MR_GRAD_REQ_TAG_RULES','MR_HONOR_ELIG_CD','MR_HONOR_SETUP','MR_HONOR_SETUP_ABS',
        'MR_HONOR_SETUP_ALT_LANG','MR_HONOR_SETUP_COM','MR_HONOR_SETUP_GD','MR_HONOR_SETUP_MKS','MR_HONOR_SETUP_Q_D','MR_IMPORT_STU_CRS_DET','MR_IMPORT_STU_CRS_GRADES',
        'MR_IMPORT_STU_CRS_HDR','MR_IPR_ELIG_CD','MR_IPR_ELIG_SETUP','MR_IPR_ELIG_SETUP_ABS','MR_IPR_ELIG_SETUP_COM','MR_IPR_ELIG_SETUP_GD','MR_IPR_ELIG_SETUP_MKS','MR_IPR_ELIG_SETUP_Q_D',
        'MR_IPR_PRINT_HDR','MR_IPR_PRT_STU_COM','MR_IPR_PRT_STU_DET','MR_IPR_PRT_STU_HDR','MR_IPR_PRT_STU_MSG','MR_IPR_RUN','MR_IPR_STU_ABS','MR_IPR_STU_AT_RISK','MR_IPR_STU_COM',
        'MR_IPR_STU_ELIGIBLE','MR_IPR_STU_HDR','MR_IPR_STU_MARKS','MR_IPR_STU_MESSAGE','MR_IPR_TAKEN','MR_IPR_VIEW_ATT','MR_IPR_VIEW_ATT_IT','MR_IPR_VIEW_DET','MR_IPR_VIEW_HDR',
        'MR_LEVEL_DET','MR_LEVEL_GPA','MR_LEVEL_HDR','MR_LEVEL_HONOR','MR_LEVEL_MARKS','MR_LTDB_MARK_DTL','MR_LTDB_MARK_HDR','MR_MARK_ISSUED_AT','MR_MARK_SUBS','MR_MARK_TYPES',
        'MR_MARK_TYPES_LMS_MAP','MR_MARK_VALID','MR_PRINT_GD_SCALE','MR_PRINT_HDR','MR_PRINT_KEY','MR_PRINT_STU_COMM','MR_PRINT_STU_CRSCP','MR_PRINT_STU_CRSTXT','MR_PRINT_STU_DET',
        'MR_PRINT_STU_GPA','MR_PRINT_STU_HDR','MR_PRINT_STU_HNR','mr_print_stu_hold','mr_print_stu_item','MR_PRINT_STU_LTDB','MR_PRINT_STU_PROG','MR_PRINT_STU_SCTXT',
        'MR_PRINT_STU_SEC_TEACHER','MR_PRINT_STU_STUCP','MR_RC_STU_AT_RISK','MR_RC_STU_ATT_VIEW','MR_RC_STU_ELIGIBLE','MR_RC_TAKEN','MR_RC_VIEW_ALT_LANG','MR_RC_VIEW_ATT',
        'MR_RC_VIEW_ATT_INT','MR_RC_VIEW_DET','MR_RC_VIEW_GPA','MR_RC_VIEW_GRD_SC','MR_RC_VIEW_HDR','MR_RC_VIEW_HONOR','MR_RC_VIEW_LTDB','MR_RC_VIEW_MPS','MR_RC_VIEW_SC_MP',
        'MR_RC_VIEW_SP','MR_RC_VIEW_SP_COLS','MR_RC_VIEW_SP_MP','MR_RC_VIEW_STUCMP','MR_REQ_AREAS','MR_SC_COMP_COMS','MR_SC_COMP_CRS','MR_SC_COMP_DET','MR_SC_COMP_DET_ALT_LANG',
        'MR_SC_COMP_HDR','MR_SC_COMP_MRKS','MR_SC_COMP_STU','MR_SC_CRS_TAKEN','MR_SC_CRSSTU_TAKEN','MR_SC_DISTR_FORMAT','MR_SC_GD_SCALE_ALT_LANG','MR_SC_GD_SCALE_DET','MR_SC_GD_SCALE_HDR',
        'MR_SC_ST_STANDARD','MR_SC_STU_COMMENT','MR_SC_STU_COMP','MR_SC_STU_CRS_COMM','MR_SC_STU_CRS_COMP','MR_SC_STU_TAKEN','MR_SC_STU_TEA','MR_SC_STU_TEA_XREF','MR_SC_STU_TEXT',
        'MR_SC_STUSTU_TAKEN','MR_SC_TEA_COMP','MR_STATE_COURSES','MR_STU_ABSENCES','MR_STU_BLDG_TYPE','MR_STU_COMMENTS','MR_STU_CRS_DATES','MR_STU_CRSEQU_ABS','MR_STU_CRSEQU_CRD',
        'MR_STU_CRSEQU_MARK','MR_STU_EXCLUDE_BUILDING_TYPE','MR_STU_GPA','MR_STU_GRAD','MR_STU_GRAD_AREA','MR_STU_GRAD_VALUE','MR_STU_HDR','MR_STU_HDR_SUBJ','MR_STU_HONOR','MR_STU_MARKS',
        'MR_STU_MP','MR_STU_MP_COMMENTS','MR_STU_OUT_COURSE','MR_STU_RUBRIC_COMP_SCORE','MR_STU_RUBRIC_COMP_SCORE_HIST','MR_STU_RUBRIC_SCORE','MR_STU_RUBRIC_SCORE_HIST','MR_STU_TAG_ALERT',
        'MR_STU_TEXT','MR_STU_USER','MR_STU_XFER_BLDGS','MR_STU_XFER_RUNS','MR_TRN_PRINT_HDR','MR_TRN_PRT_CRS_UD','MR_TRN_PRT_STU_ACT','MR_TRN_PRT_STU_BRK','MR_TRN_PRT_STU_COM',
        'MR_TRN_PRT_STU_DET','MR_TRN_PRT_STU_HDR','MR_TRN_PRT_STU_LTD','MR_TRN_PRT_STU_MED','MR_TRN_PRT_STU_REQ','MR_TRN_VIEW_ATT','MR_TRN_VIEW_BLDTYP','MR_TRN_VIEW_DET','MR_TRN_VIEW_GPA',
        'MR_TRN_VIEW_HDR','MR_TRN_VIEW_LTDB','MR_TRN_VIEW_MED','MR_TRN_VIEW_MPS','MR_TRN_VIEW_MS','MR_TRN_VIEW_UD','MR_TX_CREDIT_SETUP','MR_YEAREND_RUN','MRTB_DISQUALIFY_REASON',
        'MRTB_GB_CATEGORY','MRTB_GB_EXCEPTION','MRTB_LEVEL_HDR_PESC_CODE','MRTB_MARKOVR_REASON','MRTB_ST_CRS_FLAGS','MRTB_SUBJ_AREA_SUB','MSG_BUILDING_SETUP','MSG_BUILDING_SETUP_ENABLE',
        'MSG_BUILDING_SETUP_VALUES','MSG_DISTRICT_SETUP','MSG_DISTRICT_SETUP_ENABLE','MSG_DISTRICT_SETUP_VALUES','MSG_EVENT','MSG_IEP_AUDIENCE','MSG_SCHEDULE','MSG_SUB_EVENT',
        'MSG_USER_PREFERENCE_DET','MSG_USER_PREFERENCE_HDR','MSG_VALUE_SPECIFICATION','NSE_ADDRESS','NSE_ADMIN_DOCUMENTS','NSE_ADMIN_DOCUMENTS_FOR_GRADE','NSE_ADMIN_SETTINGS',
        'NSE_APPLICATION','NSE_APPLICATION_DETAILS','NSE_APPLICATION_RELATIONSHIP','NSE_APPLICATION_STUDENT','NSE_APPLICATION_TRANSLATION','NSE_BUILDING','NSE_CONFIGURABLE_FIELDS',
        'NSE_CONTACT','NSE_CONTACT_PHONE','NSE_CONTACT_VERIFY','NSE_CONTACTMATCH_LOG','NSE_CONTROLSLIST','NSE_CONTROLTRANSLATION','NSE_DISCLAIMER','NSE_DYNAMIC_FIELDS_APPLICATION',
        'NSE_DYNAMIC_FIELDS_GRADE','NSE_DYNAMIC_FIELDS_GROUP','NSE_DYNAMIC_FIELDS_TOOLTIP','NSE_EOCONTACT','NSE_FIELDS','NSE_HAC_ACCESS','NSE_LANGUAGE','NSE_MEDICAL','NSE_PHONENUMBERS',
        'NSE_REG_USER','NSE_RESOURCE','NSE_RESOURCE_TYPE','NSE_SECTION_COMPLETE','NSE_SIGNATURE','NSE_STU_CONTACT','NSE_STUDENT','NSE_STUDENT_RACE','NSE_TABS','NSE_TOOLTIP',
        'NSE_TRANSLATION','NSE_UPLOAD_DOCUMENTS','NSE_UPLOADFILES','NSE_USER','NSE_USERDETAIL','NSE_VACCINATION_CONFIGURATION','P360_NotificationLink','P360_NotificationResultSet',
        'P360_NotificationResultSetUser','P360_NotificationRule','P360_NotificationRuleKey','P360_NotificationRuleUser','P360_NotificationSchedule','P360_NotificationTasks',
        'P360_NotificationUserCriteria','PESC_SUBTEST_CODE','PESC_TEST_CODE','PESCTB_DIPLO_XWALK','PESCTB_GEND_XWALK','PESCTB_GPA_XWALK','PESCTB_GRADE_XWALK','PESCTB_SCORE_XWALK',
        'PESCTB_SHOT_XWALK','PESCTB_STU_STATUS','PESCTB_SUFFIX_XWALK','PESCTB_TERM_XWALK','PP_CFG','PP_DISTDEF_MAP','PP_MONTH_DAYS','PP_REBUILD_HISTORY','PP_SECURITY','PP_STUDENT_CACHE',
        'PP_STUDENT_MONTH','PP_STUDENT_MONTH_ABS','PP_STUDENT_TEMP','PRCH_STU_STATUS','PS_SPECIAL_ED_PHONE_TYPE_MAP','REG','REG_ACADEMIC','REG_ACADEMIC_SUPP','REG_ACT_PREREQ',
        'REG_ACTIVITY_ADV','REG_ACTIVITY_DET','REG_ACTIVITY_ELIG','REG_ACTIVITY_HDR','REG_ACTIVITY_INEL','REG_ACTIVITY_MP','REG_APPOINTMENT','REG_APPT_SHARE','REG_AT_RISK_FACTOR',
        'REG_AT_RISK_FACTOR_REASON','REG_BUILDING','REG_BUILDING_GRADE','REG_CAL_DAYS','REG_CAL_DAYS_LEARNING_LOC','REG_CAL_DAYS_LL_PDS','REG_CALENDAR','REG_CFG','REG_CFG_ALERT',
        'REG_CFG_ALERT_CODE','REG_CFG_ALERT_DEF_CRIT','REG_CFG_ALERT_DEFINED','REG_CFG_ALERT_UDS_CRIT_KTY','REG_CFG_ALERT_UDS_KTY','REG_CFG_ALERT_USER','REG_CFG_EW_APPLY',
        'REG_CFG_EW_COMBO','REG_CFG_EW_COND','REG_CFG_EW_REQ_ENT','REG_CFG_EW_REQ_FLD','REG_CFG_EW_REQ_WD','REG_CFG_EW_REQUIRE','REG_CLASSIFICATION','REG_CLASSIFICATION_EVA',
        'REG_CONTACT','REG_CONTACT_HIST','REG_CONTACT_HIST_TMP','REG_CONTACT_PHONE','REG_CYCLE','REG_DISABILITY','REG_DISTRICT','REG_DISTRICT_ATTACHMENT','REG_DURATION',
        'REG_EMERGENCY','REG_ENTRY_WITH','REG_ETHNICITY','REG_EVENT','REG_EVENT_ACTIVITY','REG_EVENT_COMP','REG_EVENT_HRM','REG_EVENT_MS','REG_EXCLUDE_HONOR','REG_EXCLUDE_IPR',
        'REG_EXCLUDE_RANK','REG_GEO_CFG','REG_GEO_CFG_DATES','REG_GEO_PLAN_AREA','REG_GEO_STU_PLAN','REG_GEO_ZONE_DATES','REG_GEO_ZONE_DET','REG_GEO_ZONE_HDR','REG_GRADE',
        'REG_GROUP_HDR','REG_GROUP_USED_FOR','REG_HISPANIC','REG_HISTORY_CFG','REG_HOLD','reg_hold_calc_detail','REG_HOLD_RC_STATUS','REG_IEP_SETUP','REG_IEP_STATUS','REG_IMMUNIZATION',
        'REG_IMPORT','REG_IMPORT_CONTACT','REG_IMPORT_PROGRAM','REG_KEY_CONTACT_ID','REG_LEGAL_INFO','REG_LOCKER','REG_LOCKER_COMBO','REG_MAP_STU_GEOCODE','REG_MED_ALERTS',
        'REG_MED_PROCEDURE','REG_MP_DATES','REG_MP_WEEKS','REG_NEXT_YEAR','REG_NOTES','REG_PERSONAL','REG_PHONE_HIST','REG_PHONE_HISTORY_CFG','REG_PROG_SETUP_BLD',
        'REG_PROGRAM_COLUMN','REG_PROGRAM_SETUP','REG_PROGRAM_USER','REG_PROGRAMS','REG_PRT_FLG_DFLT','REG_ROOM','REG_ROOM_AIN','REG_STAFF','REG_STAFF_ADDRESS','REG_STAFF_BLDGS',
        'REG_STAFF_BLDGS_ELEM_AIN','REG_STAFF_BLDGS_HRM_AIN','REG_STAFF_ETHNIC','REG_STAFF_HISPANIC','REG_STAFF_PHOTO_CFG','REG_STAFF_QUALIFY','REG_STAFF_SIGNATURE',
        'REG_STAFF_SIGNATURE_CFG','REG_STATE','REG_STU_AT_RISK','REG_STU_AT_RISK_CALC','REG_STU_CONT_HIST','REG_STU_CONTACT','REG_STU_CONTACT_ALERT','REG_STU_CONTACT_ALERT_ATT',
        'REG_STU_CONTACT_ALERT_AVG','REG_STU_CONTACT_ALERT_DISC','REG_STU_CONTACT_ALERT_GB','REG_SUMMER_SCHOOL','REG_TRACK','REG_TRAVEL','REG_USER','REG_USER_BUILDING',
        'REG_USER_DISTRICT','REG_USER_PLAN_AREA','REG_USER_STAFF','REG_USER_STAFF_BLD','REG_YREND_CRITERIA','REG_YREND_RUN','REG_YREND_RUN_CAL','REG_YREND_RUN_CRIT',
        'REG_YREND_SELECT','REG_YREND_STUDENTS','REG_YREND_UPDATE','REGPROG_YREND_RUN','REGPROG_YREND_TABS','REGTB_ACADEMIC_DIS','REGTB_ACCDIST','REGTB_ALT_PORTFOLIO',
        'REGTB_APPT_TYPE','REGTB_AR_ACT641','REGTB_AR_ANTICSVCE','REGTB_AR_BARRIER','REGTB_AR_BIRTHVER','REGTB_AR_CNTYRESID','REGTB_AR_COOPS','REGTB_AR_CORECONT',
        'REGTB_AR_DEVICE_ACC','REGTB_AR_ELDPROG','REGTB_AR_ELL_MONI','REGTB_AR_FACTYPE','REGTB_AR_HOMELESS','REGTB_AR_IMMSTATUS','REGTB_AR_INS_CARRI','REGTB_AR_LEARNDVC',
        'REGTB_AR_MILITARYDEPEND','REGTB_AR_NETPRFRM','REGTB_AR_NETTYPE','REGTB_AR_PRESCHOOL','REGTB_AR_RAEL','REGTB_AR_SCH_LEA','REGTB_AR_SEND_LEA','REGTB_AR_SHAREDDVC',
        'REGTB_AR_STU_INSTRUCT','REGTB_AR_SUP_SVC','REGTB_AT_RISK_REASON','REGTB_ATTACHMENT_CATEGORY','REGTB_BLDG_REASON','REGTB_BLDG_TYPES','REGTB_CC_BLDG_TYPE',
        'REGTB_CC_MARK_TYPE','REGTB_CITIZENSHIP','REGTB_CLASSIFY','REGTB_COMPLEX','REGTB_COMPLEX_TYPE','REGTB_COUNTRY','REGTB_COUNTY','REGTB_CURR_CODE','REGTB_DAY_TYPE',
        'REGTB_DEPARTMENT','REGTB_DIPLOMAS','REGTB_DISABILITY','REGTB_EDU_LEVEL','REGTB_ELIG_REASON','REGTB_ELIG_STATUS','REGTB_ENTRY','REGTB_ETHNICITY','REGTB_GENDER_IDENTITY',
        'REGTB_GENERATION','REGTB_GRAD_PLANS','REGTB_GRADE_CEDS_CODE','REGTB_GRADE_PESC_CODE','REGTB_GROUP_USED_FOR','REGTB_HISPANIC','REGTB_HOLD_RC_CODE','REGTB_HOME_BLDG_TYPE',
        'REGTB_HOMELESS','REGTB_HOSPITAL','REGTB_HOUSE_TEAM','REGTB_IEP_STATUS','REGTB_IMMUN_STATUS','REGTB_IMMUNS','REGTB_LANGUAGE','regtb_language_SD091114','REGTB_LEARNING_LOCATION',
        'REGTB_MEAL_STATUS','REGTB_MED_PROC','REGTB_MEDIC_ALERT','REGTB_NAME_CHGRSN ','REGTB_NOTE_TYPE','REGTB_PESC_CODE','REGTB_PHONE','REGTB_PROC_STATUS','REGTB_PROG_ENTRY',
        'REGTB_PROG_WITH','REGTB_QUALIFY','REGTB_RELATION','REGTB_RELATION_PESC_CODE','REGTB_REQ_GROUP','REGTB_RESIDENCY','REGTB_ROOM_TYPE','REGTB_SCHOOL','REGTB_SCHOOL_YEAR',
        'REGTB_SIF_AUTH_MAP','REGTB_SIF_JOBCLASS','REGTB_ST_PREFIX','REGTB_ST_SUFFIX','REGTB_ST_TYPE','REGTB_STATE_BLDG','REGTB_TITLE','REGTB_TRANSPORT_CODE','REGTB_TRAVEL',
        'REGTB_WITHDRAWAL','SCHD_ALLOCATION','SCHD_CFG','SCHD_CFG_DISC_OFF','SCHD_CFG_ELEM_AIN','SCHD_CFG_FOCUS_CRT','SCHD_CFG_HOUSETEAM','SCHD_CFG_HRM_AIN','SCHD_CFG_INTERVAL',
        'SCHD_CNFLCT_MATRIX','SCHD_COURSE','SCHD_COURSE_BLOCK','SCHD_COURSE_GPA','SCHD_COURSE_GRADE','SCHD_COURSE_HONORS','SCHD_COURSE_QUALIFY','SCHD_COURSE_SEQ','SCHD_COURSE_SUBJ',
        'SCHD_COURSE_SUBJ_TAG','SCHD_COURSE_USER','SCHD_CRS_BLDG_TYPE','SCHD_CRS_GROUP_DET','SCHD_CRS_GROUP_HDR','SCHD_CRS_MARK_TYPE','SCHD_CRS_MSB_COMBO','SCHD_CRS_MSB_DET',
        'SCHD_CRS_MSB_HDR','SCHD_CRS_MSB_PATRN','SCHD_CRSSEQ_MARKTYPE','SCHD_DISTCRS_BLDG_TYPES','SCHD_DISTCRS_SECTIONS_OVERRIDE','SCHD_DISTRICT_CFG','SCHD_DISTRICT_CFG_UPD',
        'SCHD_LUNCH_CODE','SCHD_MS','SCHD_MS_ALT_LANG','SCHD_MS_BLDG_TYPE','SCHD_MS_BLOCK','SCHD_MS_CYCLE','SCHD_MS_GPA','SCHD_MS_GRADE','SCHD_MS_HONORS','SCHD_MS_HOUSE_TEAM',
        'SCHD_MS_HRM_AIN','SCHD_MS_KEY','SCHD_MS_LUNCH','SCHD_MS_MARK_TYPES','SCHD_MS_MP','SCHD_MS_QUALIFY','SCHD_MS_SCHEDULE','SCHD_MS_SESSION','SCHD_MS_STAFF','SCHD_MS_STAFF_DATE',
        'SCHD_MS_STAFF_STUDENT','SCHD_MS_STAFF_STUDENT_pa','SCHD_MS_STAFF_USER','SCHD_MS_STU_FILTER','SCHD_MS_STUDY_SEAT','SCHD_MS_SUBJ','SCHD_MS_SUBJ_TAG','SCHD_MS_USER',
        'SCHD_MSB_MEET_CYC','SCHD_MSB_MEET_DET','SCHD_MSB_MEET_HDR','SCHD_MSB_MEET_PER','SCHD_PARAMS','SCHD_PARAMS_SORT','SCHD_PERIOD','SCHD_PREREQ_COURSE_ERR','SCHD_REC_TAKEN',
        'SCHD_RESOURCE','SCHD_RESTRICTION','SCHD_RUN','SCHD_RUN_TABLE','SCHD_SCAN_REQUEST','SCHD_STU_CONF_CYC','SCHD_STU_CONF_MP','SCHD_STU_COURSE','SCHD_STU_CRS_DATES',
        'SCHD_STU_PREREQOVER','SCHD_STU_RECOMMEND','SCHD_STU_REQ','SCHD_STU_REQ_MP','SCHD_STU_STAFF_USER','SCHD_STU_STATUS','SCHD_STU_USER','SCHD_TIMETABLE','SCHD_TIMETABLE_HDR',
        'SCHD_TMP_STU_REQ_LIST','SCHD_UNSCANNED','SCHD_YREND_RUN','SCHDTB_AR_DIG_LRN','SCHDTB_AR_DIST_PRO','SCHDTB_AR_HQT','SCHDTB_AR_INST','SCHDTB_AR_JOBCODE','SCHDTB_AR_LEARN',
        'SCHDTB_AR_LIC_EX','SCHDTB_AR_TRANSVEN','SCHDTB_AR_VOCLEA','SCHDTB_COURSE_NCES_CODE','SCHDTB_CREDIT_BASIS','SCHDTB_CREDIT_BASIS_PESC_CODE','SCHDTB_SIF_CREDIT_TYPE',
        'SCHDTB_SIF_INSTRUCTIONAL_LEVEL','SCHDTB_STU_COURSE_TRIGGER','SCHOOLOGY_ASMT_XREF','SCHOOLOGY_INTF_DET','SCHOOLOGY_INTF_HDR','SDE_CAMPUS','SDE_CERT','SDE_DIST_CFG',
        'SDE_INSTITUTION','SDE_IPP_TRANSACTIONS_DATA','SDE_PESC_IMPORT','SDE_PESC_TRANSCRIPT','SDE_SECURITY','SDE_SESSION_TRACKER','SDE_TRANSACTION_TIME','SDE_TRANSCRIPT',
        'SDE_TRANSCRIPT_CONFIGURATION','SEC_GLOBAL_ID','SEC_LOOKUP_INFO','SEC_LOOKUP_MENU_ITEMS','SEC_LOOKUP_MENU_REL','SEC_LOOKUP_NON_MENU','SEC_USER','SEC_USER_AD','SEC_USER_BUILDING',
        'SEC_USER_MENU_CACHE','SEC_USER_RESOURCE','SEC_USER_ROLE','SEC_USER_ROLE_BLDG_OVR','SEC_USER_STAFF','SECTB_ACTION_FEATURE','SECTB_ACTION_RESOURCE','SECTB_PACKAGE',
        'SECTB_PAGE_RESOURCE','SECTB_RESOURCE','SECTB_SUBPACKAGE','SIF_AGENT_CFG','SIF_EVENT_DET','SIF_EVENT_HDR','SIF_EXTENDED_MAP','SIF_GUID_ATT_CLASS','SIF_GUID_ATT_CODE',
        'SIF_GUID_ATT_DAILY','SIF_GUID_AUTH','SIF_GUID_BUILDING','SIF_GUID_BUS_DETAIL','SIF_GUID_BUS_INFO','SIF_GUID_BUS_ROUTE','SIF_GUID_BUS_STOP','SIF_GUID_BUS_STU',
        'SIF_GUID_CALENDAR_SUMMARY','SIF_GUID_CONTACT','SIF_GUID_COURSE','SIF_GUID_CRS_SESS','SIF_GUID_DISTRICT','SIF_GUID_GB_ASMT','SIF_GUID_HOSPITAL','SIF_GUID_IEP',
        'SIF_GUID_MED_ALERT','SIF_GUID_PROGRAM','SIF_GUID_REG_EW','SIF_GUID_ROOM','SIF_GUID_STAFF','SIF_GUID_STAFF_BLD','SIF_GUID_STU_SESS','SIF_GUID_STUDENT','SIF_GUID_TERM',
        'SIF_LOGFILE','SIF_PROGRAM_COLUMN','SIF_PROVIDE','SIF_PUBLISH','SIF_REQUEST_QUEUE','SIF_RESPOND','SIF_SUBSCRIBE','SIF_USER_FIELD','SMS_CFG','SMS_PROGRAM_RULES',
        'SMS_PROGRAM_RULES_MESSAGES','SMS_USER_FIELDS','SMS_USER_RULES','SMS_USER_RULES_MESSAGES','SMS_USER_SCREEN','SMS_USER_SCREEN_COMB_DET','SMS_USER_SCREEN_COMB_HDR',
        'SMS_USER_TABLE','SPI_APPUSERDEF','SPI_AUDIT_DET1','SPI_AUDIT_DET2','SPI_AUDIT_HISTORY','SPI_AUDIT_HISTORY_FIELDS','SPI_AUDIT_HISTORY_KEYS','SPI_AUDIT_SESS',
        'SPI_AUDIT_TASK','SPI_AUDIT_TASK_PAR','SPI_BACKUP_TABLES','SPI_BLDG_PACKAGE','SPI_BUILDING_LIST','Spi_checklist_menu_items','SPI_CHECKLIST_RESULTS','SPI_CHECKLIST_SETUP_DET',
        'SPI_CHECKLIST_SETUP_HDR','SPI_CODE_IN_USE','SPI_CODE_IN_USE_FILTER','SPI_COLUMN_CONTROL','SPI_COLUMN_INFO','SPI_COLUMN_NAMES','SPI_COLUMN_VALIDATION','SPI_CONFIG_EXTENSION',
        'SPI_CONFIG_EXTENSION_DETAIL','SPI_CONFIG_EXTENSION_ENVIRONMENT','SPI_CONVERT','SPI_CONVERT_CONTACT','SPI_CONVERT_ERROR_LOG','SPI_CONVERT_MAP','SPI_CONVERT_STAFF',
        'SPI_CONVERT_TYPE','SPI_COPY_CALC','SPI_COPY_DET','spi_copy_det_731719','SPI_COPY_HDR','spi_copy_hdr_731719','SPI_COPY_JOIN','SPI_COPY_LINK','spi_copy_link_731719',
        'SPI_COPY_MS_DET','SPI_CUST_TEMPLATES','SPI_CUSTOM_CODE','SPI_CUSTOM_DATA','SPI_CUSTOM_LAUNCH','SPI_CUSTOM_MODS','SPI_CUSTOM_SCRIPT','SPI_DATA_CACHE','SPI_DIST_BUILDING_CHECKLIST',
        'SPI_DIST_PACKAGE','SPI_DISTRICT_INIT','SPI_DYNAMIC_CONTAINERTYPE','SPI_DYNAMIC_LAYOUT','SPI_DYNAMIC_PAGE','SPI_DYNAMIC_PAGE_WIDGET','SPI_DYNAMIC_SETTING','SPI_DYNAMIC_WIDGET',
        'SPI_DYNAMIC_WIDGET_SETTING','SPI_DYNAMIC_WIDGET_TYPE','SPI_EVENT','SPI_FEEDBACK_ANS','SPI_FEEDBACK_Q_HDR','SPI_FEEDBACK_QUEST','SPI_FEEDBACK_RECIP','SPI_FIELD_HELP',
        'SPI_FIRSTWAVE','SPI_HAC_NEWS','SPI_HAC_NEWS_BLDG','SPI_HOME_SECTIONS','SPI_HOME_USER_CFG','SPI_HOME_USER_SEC','SPI_IEPWEBSVC_CFG','SPI_IMM_TSK_RESULT','SPI_INPROG',
        'SPI_INTEGRATION_DET','SPI_INTEGRATION_HDR','SPI_INTEGRATION_LOGIN','SPI_INTEGRATION_SESSION_DET','SPI_INTEGRATION_SESSION_HDR','SPI_INTEGRATION_STUDATA_DET',
        'SPI_INTEGRATION_STUDATA_HDR','SPI_JOIN_COND','SPI_JOIN_SELECT','SPI_MAP_CFG','SPI_NEWS','SPI_NEWS_BLDG','SPI_OBJECT_PERM','SPI_OPTION_COLUMN_NULLABLE','SPI_OPTION_EXCLD',
        'SPI_OPTION_LIST_FIELD','SPI_OPTION_NAME','SPI_OPTION_SIMPLE_SEARCH','SPI_OPTION_TABLE','SPI_OPTION_UPDATE','SPI_POWERPACK_CONFIGURATION','SPI_PRIVATE_FIELD','SPI_RESOURCE',
        'SPI_RESOURCE_OVERRIDE','SPI_SEARCH_FAV','SPI_SEARCH_FAV_SUBSCRIBE','SPI_SECONDARY_KEY_USED','SPI_SESSION_STATE','SPI_STATE_REQUIREMENTS','SPI_TABLE_JOIN','SPI_TABLE_NAMES',
        'SPI_TASK','SPI_TASK_ERR_DESC','SPI_TASK_ERROR','SPI_TASK_LOG_DET','SPI_TASK_LOG_HDR','SPI_TASK_LOG_MESSAGE','SPI_TASK_LOG_PARAMS','SPI_TASK_PARAMS','SPI_TASK_PROG',
        'SPI_TIME_OFFSET','SPI_TMP_WATCH_LIST','SPI_TRIGGER_STATE','SPI_USER_GRID','SPI_USER_OPTION','SPI_USER_OPTION_BLDG','SPI_USER_PROMPT','SPI_USER_SEARCH',
        'SPI_USER_SEARCH_LIST_FIELD','SPI_USER_SORT','SPI_VAL_TABS','SPI_VALIDATION_TABLES','SPI_VERSION','SPI_WATCH_LIST','SPI_WATCH_LIST_STUDENT','SPI_WORKFLOW_MESSAGES',
        'SPI_Z_SCALE','SPITB_SEARCH_FAV_CATEGORY','SSP_CFG','SSP_CFG_AUX','SSP_CFG_PLAN_GOALS','SSP_CFG_PLAN_INTERVENTIONS','SSP_CFG_PLAN_REASONS','SSP_CFG_PLAN_RESTRICTIONS',
        'SSP_COORDINATOR','SSP_COORDINATOR_FILTER','SSP_DISTRICT_CFG','SSP_GD_SCALE_DET','SSP_GD_SCALE_HDR','SSP_INTER_FREQ_DT','SSP_INTER_MARKS','SSP_INTERVENTION','SSP_MARK_TYPES',
        'SSP_PARENT_GOAL','SSP_PARENT_OBJECTIVE','SSP_PERF_LEVEL_DET','SSP_PERF_LEVEL_HDR','SSP_QUAL_DET','SSP_QUAL_HDR','SSP_QUAL_SEARCH','SSP_RSN_TEMP_GOAL','SSP_RSN_TEMP_GOAL_OBJ',
        'SSP_RSN_TEMP_HDR','SSP_RSN_TEMP_INT','SSP_RSN_TEMP_PARENT_GOAL','SSP_RSN_TEMP_PARENT_GOAL_OBJ','SSP_STU_AT_RISK','SSP_STU_GOAL','SSP_STU_GOAL_STAFF','SSP_STU_GOAL_TEMP',
        'SSP_STU_GOAL_USER','SSP_STU_INT','SSP_STU_INT_COMM','SSP_STU_INT_FREQ_DT','SSP_STU_INT_PROG','SSP_STU_INT_STAFF','SSP_STU_INT_TEMP','SSP_STU_OBJ_USER','SSP_STU_OBJECTIVE',
        'SSP_STU_PLAN','SSP_STU_PLAN_USER','SSP_USER_FIELDS','SSP_YEAREND_RUN','SSPTB_AIS_LEVEL','SSPTB_AIS_TYPE','SSPTB_GOAL','SSPTB_GOAL_LEVEL','SSPTB_OBJECTIVE','SSPTB_PLAN_STATUS',
        'SSPTB_PLAN_TYPE','SSPTB_ROLE_EVAL','STATE_DISTDEF_SCREENS','STATE_DNLD_SUM_INFO','STATE_DNLD_SUM_TABLES','STATE_DNLD_SUMMARY','STATE_DOWNLOAD_AUDIT','STATE_DWNLD_COLUMN_NAME',
        'STATE_OCR_BLDG_CFG','STATE_OCR_BLDG_MARK_TYPE','STATE_OCR_BLDG_RET_EXCLUDED_CALENDAR','STATE_OCR_DETAIL','STATE_OCR_DIST_ATT','STATE_OCR_DIST_CFG','STATE_OCR_DIST_COM',
        'STATE_OCR_DIST_DISC','STATE_OCR_DIST_EXP','STATE_OCR_DIST_LTDB_TEST','STATE_OCR_DIST_STU_DISC_XFER','STATE_OCR_NON_STU_DET','STATE_OCR_QUESTION','STATE_OCR_SUMMARY',
        'STATE_TASK_LOG_CFG','STATE_TASK_LOG_DET','STATE_TASK_LOG_HDR','STATE_VLD_GROUP','STATE_VLD_GRP_MENU','STATE_VLD_GRP_RULE','STATE_VLD_GRP_USER','STATE_VLD_RESULTS',
        'STATE_VLD_RULE','STATETB_AP_SUBJECT','STATETB_DEF_CLASS','STATETB_ENTRY_SOURCE','STATETB_OCR_COM_TYPE','STATETB_OCR_COUNT_TYPE','STATETB_OCR_DISC_TYPE','STATETB_OCR_EXP_TYPE',
        'Statetb_Ocr_Record_types','STATETB_RECORD_FIELDS','STATETB_RECORD_TYPES','STATETB_RELIGION','STATETB_STAFF_ROLE','STATETB_SUBMISSION_COL','STATETB_SUBMISSIONS',
        'TAC_CFG','TAC_CFG_ABS_SCRN','TAC_CFG_ABS_SCRN_CODES','TAC_CFG_ABS_SCRN_DET','TAC_CFG_ATTACH','TAC_CFG_ATTACH_CATEGORIES','TAC_CFG_HAC','TAC_DISTRICT_CFG','TAC_ISSUE',
        'TAC_ISSUE_ACTION','TAC_ISSUE_REFER','TAC_ISSUE_REFER_SSP','TAC_ISSUE_RELATED','TAC_ISSUE_STUDENT','TAC_LINK','TAC_LINK_MACRO','TAC_LUNCH_COUNTS','TAC_LUNCH_TYPES',
        'TAC_MENU_ITEMS','TAC_MESSAGES','TAC_MS_SCHD','TAC_MSG_CRS_DATES','TAC_PRINT_RC','TAC_SEAT_CRS_DET','TAC_SEAT_CRS_HDR','TAC_SEAT_HRM_DET','TAC_SEAT_HRM_HDR','TAC_SEAT_PER_DET',
        'TAC_SEAT_PER_HDR','TACTB_ISSUE','TACTB_ISSUE_ACTION','TACTB_ISSUE_LOCATION','tmp_medtb_vis_exam_ark','WSSecAuthenticationLogTbl')]
        [string]$Table,
        [Parameter(Mandatory=$false,ParameterSetName="awesomeSauce")][string]$SQLWhere, #no not include where at the beginning.
        [Parameter(Mandatory=$false,ParameterSetName="awesomeSauce")][string]$Columns, #single string '[STUDENT_ID],[DISTRICT]'
        [Parameter(Mandatory=$false,ParameterSetName="awesomeSauce")][string]$dtEquals,
        [Parameter(Mandatory=$false)][string]$dtStart,
        [Parameter(Mandatory=$false)][string]$dtEnd,
        [Parameter(Mandatory=$false)][string]$dtColumn = '[CHANGE_DATE_TIME]',
        [Parameter(Mandatory=$false,ParameterSetName="default")][string]$ReportParams,
        [Parameter(Mandatory=$false,ParameterSetName="default")][switch]$JSON, #data to be retrieved with the Get-CognosDataSet cmdlet.
        [Parameter(Mandatory=$false,ParameterSetName="awesomeSauce")][switch]$Trim,
        [Parameter(Mandatory=$false,ParameterSetName="awesomeSauce")][switch]$ReturnUID,
        [Parameter(Mandatory=$false)][switch]$StartOnly,
        [Parameter(Mandatory=$false)][string]$RefId #to be used with StartOnly to reference the report again.
    )

    if ($null -eq $CognosDSN) { Connect-ToCognos }

    #if table is specified we will use awesomeSauce.
    if ($table) {
        $awesomeSauce = $true
            
        if (-Not(Test-Path "$($HOME)\.config\Cognos\espTables.csv")) {
            Update-CogTableDefintions
        }

        $tblDefinitions = Import-Csv "$($HOME)\.config\Cognos\espTables.csv" | Group-Object -Property name -AsHashTable
    }

    $params = @{
        report = $CognosDSN
        reportparams = ''
        TeamContent = $true
        cognosfolder = "_Shared Data File Reports\automation"
    }

    if ($JSON) {
        $params.extension = 'json'
    }

    if ($awesomeSauce) {
        $params.reportparams = "p_page=awesomeSauce&p_tblName=[$($table)]"

        #uniqueness from the table definitions.
        $PKColumns = ($tblDefinitions.$table.PKColumns).Split(',') | ForEach-Object {
            if ($PSItem -eq '[STUDENT_ID]') {
                "RTRIM([STUDENT_ID])"
            } elseif ($PSItem -eq '[DISTRICT]') {
                #do nothing.
            } else {
                $PSItem
            }
        }

        $params.reportparams += "&p_tblUniqId=CONCAT(" + "$($PKColumns -join ',')" +  ",'')"

        if ($Columns) {
            $params.reportparams += "&p_colSpecify=$($Columns)"
        }

        #build WHERE SQL for final params.
        if ($dtEquals) {
            $dtSql = " CONVERT(date,$($dtColumn)) = CONVERT(date,'" + (Get-Date "$dtEquals").ToShortDateString() + "') "
        } else {
            if ($dtStart) {
                $dtSql = " CONVERT(date,$($dtColumn)) >= CONVERT(date,'" + (Get-Date "$dtStart").ToShortDateString() + "') "
            } 
            if ($dtStart -and $dtEnd) {
                $dtSql += "AND"
            }
            if ($dtEnd) {
                $dtSql += " CONVERT(date,$($dtColumn)) <= CONVERT(date,'" + (Get-Date "$dtStart").ToShortDateString() + "') "
            }
        }

    } else {

        $params.reportparams = "p_page=$($page)"

        #if not awesome sauce then use the regular paramaters for date time.
        if ($dtStart) {
            $params.reportparams += "&p_dtStart=" + (Get-Date "$dtStart").ToShortDateString()
        }
        if ($dtEnd) {
            $params.reportparams += "&p_dtEnd=" + (Get-Date "$dtEnd").ToShortDateString()
        }
    }

    if ($SQLWhere -or $dtSql) {
        if ($dtSql) {
            $SQLWhere += $SQLWhere + $dtSql
        }

        if ($SQLWhere.Substring(0,6) -ne "where ") {
            $SQLWhere = "WHERE " + $SQLWhere
        }

        $params.reportparams += "&p_where=" + $SQLWhere
    }

    Write-Verbose ($params | ConvertTo-Json)

    if ($StartOnly) {
        return (Start-CognosReport @params -RefID $RefId)
    } else {
        

        if ($awesomeSauce) {

            $data = (Get-CognosReport @params)
            if ($null -eq $data) {
                Write-Warning "No data returned."
                return
            } else {
                $data = $data.j | ConvertFrom-Json
            }

            if ($Trim) {
                $data | ForEach-Object {  
                    $_.PSObject.Properties | ForEach-Object {
                        if ($null -ne $_.Value -and $_.Value.GetType().Name -eq 'String') {
                            $_.Value = $_.Value.Trim()
                        }
                    }
                }
            }

            if ($ReturnUID) {
                return $data
            } else {
                return ($data | Select-Object -ExcludeProperty uid)
            }
        } else {
            if ($page -ne 'version' -and $data.version -eq '23.5.23') {
                Write-Verbose ($data | ConvertTo-Json)
                Throw "Incorrect page specified."
            } else {
                return $data
            }
        }
    }

}

function Update-CognosTableDefintions {
    Param(
        [Parameter(Mandatory=$false)]$eFinance
    )

    $params = @{
        page = 'tblDefinitions'
    }

    if ($eFinance) {
        $fileName = 'efpTables.csv'
        $params.eFinance = $true
    } else {
        $fileName = 'espTables.csv'
    }

    $definitions = Get-CogSqlData @params

    if (($definitions[0].psobject.Properties.Name) -contains 'TableColumns') {
        #validate by checking if at least one of the very important columns exist.
        $definitions | Export-Csv -Path "$($HOME)\.config\Cognos\$($fileName)" -Verbose
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

                    if ($null -eq $($parameters.cognosFolder) -or $parameters.cognosFolder -eq '') {
                        $parameters.cognosFolder = "My Folders"
                    }

                    if ($parameters.savepath) {
                        #Save-CognosReport
                        $manualDownload = "To manually download this report`nSave-CognosReport -report ""$($parameters.report)"" -cognosfolder ""$($parameters.cognosFolder)"""
                        $manualDownload += " -savepath ""$($parameters.savepath)"""
                    } else {
                        #Get-CognosReport
                        $manualDownload = "To manually download this report`nGet-CognosReport -report ""$($parameters.report)"" -cognosfolder ""$($parameters.cognosFolder)"""
                    }

                    if ($parameters.reportparams) {
                        $manualDownload += " -reportparams ""$($parameters.reportparams)"""
                    }

                    if ($teamContent) {
                        $manualDownload += " -TeamContent"
                    }

                    Write-Host $manualDownload

                    Read-Host "Press enter to continue..."

                    Start-CognosBrowser -url $url
                    
                } else {

                    if ($null -eq $($parameters.cognosFolder) -or $parameters.cognosFolder -eq '') {
                        $parameters.cognosFolder = "My Folders"
                    }

                    $manualDownload = "To manually run this report`nSave-CognosReport -report ""$($parameters.report)"" -cognosfolder ""$($parameters.cognosFolder)"""
                    
                    if ($teamContent) {
                        $manualDownload += " -TeamContent"
                    }
                    
                    Write-Host $manualDownload

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