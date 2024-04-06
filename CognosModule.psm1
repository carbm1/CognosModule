function Update-CognosModule {
    
    <#
        .SYNOPSIS
        Update the Cognos Module from Github.

        .DESCRIPTION
        Update the Cognos Module from Github.

        .EXAMPLE
        Update-CognosModule

    #>
    
    Param(
        [Parameter(Mandatory=$false)][switch]$dev
    )

    if (-Not $(New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Error "Must run as administrator!" -ErrorAction STOP
    }
    
    $ModulePath = Get-Module CognosModule | Select-Object -ExpandProperty ModuleBase

    try {
        if ($dev) {
            Invoke-WebRequest -Uri "https://raw.githubusercontent.com/carbm1/CognosModule/master/CognosModule.psd1" -OutFile "$($ModulePath)\CognosModule.psd1"
            Invoke-WebRequest -Uri "https://raw.githubusercontent.com/carbm1/CognosModule/master/CognosModule.psm1" -OutFile "$($ModulePath)\CognosModule.psm1"
            Import-Module CognosModule -Force
        } else {
            Invoke-WebRequest -Uri "https://raw.githubusercontent.com/AR-k12code/CognosModule/master/CognosModule.psd1" -OutFile "$($ModulePath)\CognosModule.psd1"
            Invoke-WebRequest -Uri "https://raw.githubusercontent.com/AR-k12code/CognosModule/master/CognosModule.psm1" -OutFile "$($ModulePath)\CognosModule.psm1"
            Import-Module CognosModule -Force
        }
    } catch {
        Throw "Failed to update module. $PSItem"
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
                if ($PSItem -notmatch '^[a-zA-Z]+[a-zA-Z0-9]*$') {
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
            $config = Get-Content $PSItem.FullName | ConvertFrom-Json | Select-Object -Property ConfigName,username,eFinanceUsername,dsnname,fileName
            $config.fileName = $PSItem.FullName

            if ($config.ConfigName -ne $PSItem.BaseName) {
                Write-Error "ConfigName should match the file name. $($PSItem.FullName) is invalid."
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

            # I want to eventually move to a single variable for all properties.
            # However, at this point its a breaking change and not one I'm ready to tackle yet.
            # $global:CognosModuleSession = @{
            #     CognosSession = $session
            #     CognosProfile = $ConfigName
            #     CognosDSN = $dsnname
            #     CognoseFPUsername = $efpusername
            #     CognosUsername = $username
            # }

        } catch {
            $failedlogin++            
            if ($failedlogin -ge 2) {
                Write-Error "Unable to authenticate and switch into $dsnname. $($PSItem)" -ErrorAction STOP
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
        Retrieves Cognos Report Data

        .DESCRIPTION
        Retrieves Cognos Report Data

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
        [parameter(Mandatory=$false,ParameterSetName="conversation")]
            [int]$Timeout = 5,
        [parameter(Mandatory=$false)] #This will dump the raw CSV data to the terminal.
            [switch]$Raw,
        [parameter(Mandatory=$false,ParameterSetName="Default")] #If the report is in the Team Content folder we have to switch paths.
            [switch]$TeamContent,
        [parameter(Mandatory=$false,ParameterSetName="conversation",ValueFromPipelineByPropertyName=$True)] #Provide a conversationID if you already started one via Start-CognosReport
            $conversationID,
        [parameter(Mandatory=$false)]
            [switch]$DisableProgress
    )

    try {
        
        $startTime = Get-Date

        #If the conversationID has already been supplied then we will use that.
        if (-Not($conversationID)) {
            if (-Not($DisableProgress)) {
                Write-Progress -Activity "Downloading Report" -Status "Starting Report." -PercentComplete 100
            }
            $conversation = Start-CognosReport @PSBoundParameters
            $conversationID = $conversation.conversationID
        }

        $baseURL = "https://adecognos.arkansas.gov"
        Write-Verbose "$($baseURL)/ibmcognos/bi/v1/disp/rds/sessionOutput/conversationID/$($conversationID)?v=3&async=MANUAL"

        do {
            
            #Attempt Download
            try {
                $response = Invoke-WebRequest -Uri "$($baseURL)/ibmcognos/bi/v1/disp/rds/sessionOutput/conversationID/$($conversationID)?v=3&async=MANUAL" -WebSession $CognosSession -ErrorAction Stop -SkipHttpErrorCheck
            } catch {
                #Because of random Cognos TLS/Connection issues we should try again after a few seconds. Otherwise this should fail with -ErrorAction STOP.
                Start-Sleep -Seconds (Get-Random -Minimum 5 -Maximum 15)
                $response = Invoke-WebRequest -Uri "$($baseURL)/ibmcognos/bi/v1/disp/rds/sessionOutput/conversationID/$($conversationID)?v=3&async=MANUAL" -WebSession $CognosSession -ErrorAction Stop -SkipHttpErrorCheck
            }
            
            Write-Verbose ("$($response.StatusCode)")
            Write-Verbose ("$($response.Headers.'Content-Type')")

            switch ($response.StatusCode) {

                200 {

                    if ($response.Headers.'Content-Type'[0] -eq "text/xml; charset=UTF-8") {
                        
                        $errorResponse = [xml]$response.Content
                        $errorMessage = "$($errorResponse.error.message)"

                        if ($errorMessage -match "RDS-ERR-(\d+) ") {

                            if ($Matches.1 -eq '1021') {
                                #Retrieve Required Prompts.

                                $promptid = $errorResponse.error.promptID
                    
                                #The report ID is included in the prompt response.
                                $errorResponse.error.url -match 'storeID%28%22(.{33})%22%29' | Out-Null
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
                
                                Write-Warning "If you want to save prompts please run the script again with the -SavePrompts switch."
                
                                if ($SavePrompts) {
                                    
                                    Write-Warning "For complex prompts you can submit your prompts at the following URL. And save them for later use. You must have a browser window open and signed into Cognos for this URL to work."
                                    Write-Warning "$("$($baseURL)" + ([uri]$errorResponse.error.url).PathAndQuery)"
                                                                                
                                    $promptAnswers = Read-Host -Prompt "Do you want to save your prompt responses? (y/n)"
                
                                    if (@('Y','y') -contains $promptAnswers) {
                                        Write-Warning "Info: Saving Report Responses to $($reportID).xml to be used later."
                                        Invoke-WebRequest -Uri "$($baseURL)/ibmcognos/bi/v1/disp/rds/promptAnswers/conversationID/$($promptid)?v=3&async=OFF" -WebSession $CognosSession -OutFile "$($reportID).xml"
                                        Write-Warning "Info: You will need to rerun this script to download the report using the saved prompts." -ForegroundColor Yellow
                
                                        $promptXML = [xml]((Get-Content "$($reportID).xml") -replace ' xmlns:rds="http://www.ibm.com/xmlns/prod/cognos/rds/types/201310"','' -replace 'rds:','')
                                        $promptXML.promptAnswers.promptValues | ForEach-Object {
                                            $promptname = $PSItem.name
                                            $PSItem.values.item.SimplePValue.useValue | ForEach-Object {
                                                Write-Host "&p_$($promptname)=$($PSItem)"
                                            }
                                        }
                                        
                                    }

                                }

                                throw [System.ArgumentNullException]::New('Missing Cognos Required Report Parameter.')
                            }

                        }
                        
                        # return $response

                        Write-Error $errorMessage -ErrorAction Stop

                    } else {
                        #Complete.
                        if (-Not($DisableProgress)) {
                            Write-Progress -Activity "Downloading Report" -Status "Ready" -Completed
                        }
                    }
                }

                202 {
                    #Accepted, processing.

                    if ((Get-Date) -gt $startTime.AddMinutes($Timeout)) {
                        Write-Error "Timeout of $Timeout minutes met. Exiting." -ErrorAction STOP
                    }

                    $secondsLeft = [Math]::Round(($startTime.AddMinutes($timeout) - $startTime).TotalSeconds - ((Get-Date) - $startTime).TotalSeconds)
                    if (($timeoutPercentage = ([Math]::Ceiling(($secondsLeft / ($startTime.AddMinutes($timeout) - $startTime).TotalSeconds) * 100))) -le 0) {
                        $timeoutPercentage = 0
                    }

                    if (-Not($DisableProgress)) {
                        Write-Progress -Activity "Downloading Report" -Status "Report is still processing. $($secondsLeft) seconds until timeout." -PercentComplete $timeoutPercentage
                    }
                    Start-Sleep -Seconds 1

                }

                default {

                    #anything else should be an XML Error.
                    $errorResponse = [xml]$response.Content
                    $errorMessage = "$($errorResponse.error.message)"
                        

                    if ($errorMessage -match "RDS-ERR-(\d+) ") {

                        #1018 = Params/SqlPrepare Error
                        #1021 = Missing Required Parameters.
                        #1023 = FileSize limit of 50MB exceeded.

                        if ($Matches.1 -eq '1023') {
                            Throw [System.DataMisalignedException] "Arbitrary RDS 50MB File Size Limit"
                        }

                    }
                    
                    if ($errorResponse.error.trace) {
                        Write-Warning "$($errorResponse.error.trace)"
                    }
                    Write-Error "$($errorResponse.error.message)" -ErrorAction Stop

                }
                
            }
        } until ($response.StatusCode -eq 200)

        try {

            $contentType = (($response.Headers)['Content-Type'])
            Write-Verbose "$contentType"
            
            if ($Raw) {
                return [System.Text.Encoding]::UTF8.GetString([System.Text.Encoding]::GetEncoding($response.Encoding.CodePage).GetBytes($response.Content))
            } else {

                switch ($contentType) {

                    #CSV
                    'text/csv' {
                        return [System.Text.Encoding]::UTF8.GetString([System.Text.Encoding]::GetEncoding($response.Encoding.CodePage).GetBytes($response.Content)) | ConvertFrom-CSV
                    }

                    #CognosDataSet
                    'application/json; charset=utf-8' {
                        return (($response.Content) -replace '_x005f','_' -replace '__','_' | ConvertFrom-Json).dataSet.dataTable.Row
                    }

                    #Excel
                    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' {
                        return $response.Content
                        #Set-Content -Path "filename.xlsx" -AsByteStream
                    }

                    #PDF
                    'application/pdf' {
                        return $response.Content
                        #Set-Content -Path "filename.pdf" -AsByteStream
                    }

                    default {
                        Write-Error "Unknown file content type." -ErrorAction Stop
                    }

                }
                
            }
        } catch {
            Write-Error "Unable to convert object. $($PSItem)" -ErrorAction Stop
        }

    } catch {
        Write-Error "$($PSItem)" -ErrorAction STOP
    }

}

function Get-CognosDataSet {
    <#
        .SYNOPSIS
        Pulls from RDS DataSet as JSON and loops through pages.

        .DESCRIPTION
        Pulls from RDS DataSet as JSON and loops through pages.

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
        [parameter(Mandatory=$false,ParameterSetName="conversation",ValueFromPipelineByPropertyName=$True)] #Provide a conversationID if you already started one via Start-CognosReport
            [string]$conversationID,
        [parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$True)][int]$pageSize = 2500,
        [parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$True)][int]$ReturnAfter,
        [parameter(Mandatory=$false)][Alias("Server")][switch]$Trim,
        [parameter(Mandatory=$false)][switch]$DisableProgress
    )

    $baseURL = "https://adecognos.arkansas.gov"
    $results = [System.Collections.Generic.List[Object]]::new()

    #If the conversationID has already been supplied then we will use that.
    if (-Not($conversationID)) {
        $conversation = Start-CognosReport @PSBoundParameters -extension json -pageSize $pageSize
        $conversationID = $conversation.conversationID
    }

    Write-Verbose $conversationID

    try {

        if (-Not($DisableProgress)) {
            Write-Progress -Activity "Downloading Report Data" -Status "Report Started." -PercentComplete 0
        }

        do {

            $data = Get-CognosReport -conversationID $conversationID -DisableProgress

            if ($Trim) {
                $data | ForEach-Object {  
                    $PSItem.PSObject.Properties | ForEach-Object {
                        if ($null -ne $PSItem.Value -and $PSItem.Value.GetType().Name -eq 'String') {
                            $PSItem.Value = $PSItem.Value.Trim()
                        }
                    }
                }
            }

            Write-Verbose "$($data.Count) records returned"
            
            $data | ForEach-Object {
                $results.Add($PSItem)
            }

            if (($data).Count -lt $pageSize) {
                $morePages = $False
            } else {
                #next page.
                Write-Verbose "$($baseURL)/ibmcognos/bi/v1/disp/rds/sessionOutput/conversationID/$($conversationID)/next?v=3"
                $conversation = Invoke-RestMethod -Uri "$($baseURL)/ibmcognos/bi/v1/disp/rds/sessionOutput/conversationID/$($conversationID)/next?v=3" -WebSession $CognosSession -ErrorAction Stop
                #$conversationID = $conversation.receipt.conversationID
                #Write-Verbose $conversationID
                if (-Not($DisableProgress)) {
                    Write-Progress -Activity "Downloading Report Data" -Status "$($results.count) rows downloaded." -PercentComplete 0
                }
            }

            #You would process this externally. Then pass this right back to this cmdlet to continue where you left off.
            if ($ReturnAfter -ge 1 -and $results.Count -ge $ReturnAfter) {
                return [PSCustomObject]@{
                    ConversationID = $conversationID
                    data = $results
                    ReturnAfter = $ReturnAfter
                    PageSize = $pageSize
                }
            }
            
        } until ( $morePages -eq $False )

        if (-Not($DisableProgress)) {
            Write-Progress -Activity "Downloading Report Data" -Status "$($results.count) rows downloaded." -Completed
        }

        if ($ReturnAfter -ge 1) {
            return [PSCustomObject]@{
                ConversationID = $conversationID
                data = $results
                ReturnAfter = $ReturnAfter
                PageSize = $pageSize
            }
        } else {
            return $results
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
                if ([System.IO.Directory]::Exists("$PSItem")) {
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
            [Alias('Trim')][switch]$TrimCSVWhiteSpace,
        [parameter(Mandatory=$false,ParameterSetName="default")] #If you Trim CSV White Space do you want to wrap everything in quotes?
        [parameter(Mandatory=$false,ParameterSetName="conversation")]
            [switch]$CSVUseQuotes,
        [parameter(Mandatory=$false,ParameterSetName="default")] #If you need to download the same report multiple times but with different parameters we have to use a random temp file so they don't conflict.
        [parameter(Mandatory=$false,ParameterSetName="conversation")]    
            [switch]$RandomTempFile,
        [parameter(Mandatory=$true,ParameterSetName="conversation",ValueFromPipelineByPropertyName=$True)] #Provide a conversationID if you already started one via Start-CognosReport
            $conversationID
    )

    $baseURL = "https://adecognos.arkansas.gov"
    $fullFilePath = Join-Path -Path "$savepath" -ChildPath "$filename"
    #$progressPreference = 'silentlyContinue'

    #If the conversationID has already been supplied then we will use that.
    if (-Not($conversationID)) {
        
        $conversation = Start-CognosReport @PSBoundParameters
        $conversationID = $conversation.ConversationID

    }

    if ($extension -eq 'csv' -and (-Not($TrimCSVWhiteSpace -or $CSVUseQuotes))) {
        $data = Get-CognosReport -conversationID $conversationID -Raw -Timeout $Timeout
    } else {
        $data = Get-CognosReport -conversationID $conversationID -Timeout $Timeout
    }

    #We should have the actual file now in $data. We need to test if a previous file exists and back it up first.
    if (Test-Path $fullFilePath) {
        $backupFileName = Join-Path -Path (Split-Path $fullFilePath) -ChildPath ((Split-Path -Leaf $fullFilePath) + '.bak')
        Write-Host "Info: Backing up $($fullFilePath) to $($backupFileName)" -ForegroundColor Yellow
        Move-Item -Path $fullFilePath -Destination $backupFileName -Force
    }

    Write-Host "Info: Saving to $($fullfilePath)" -ForeGroundColor Yellow

    if ($extension -eq "csv" -and ($TrimCSVWhiteSpace -or $CSVUseQuotes)) {
        
        if ($TrimCSVWhiteSpace) {
            $data | Foreach-Object {  
                $PSItem.PSObject.Properties | Foreach-Object {
                    $PSItem.Value = $PSItem.Value.Trim()
                }
            }
        }

        if ($CSVUseQuotes) {
            Write-Host "Info: Exporting CSV using quotes." -ForegroundColor Yellow
            $data | Export-Csv -UseQuotes Always -Path $fullfilepath -Force
        } else {
            $data | Export-Csv -UseQuotes AsNeeded -Path $fullfilepath -Force
        }

    } elseif ($extension -eq "csv") {
        $data | Out-File -Path $fullfilepath -Force -NoNewline
    } else {
        $data | Set-Content -Path $fullFilePath -AsByteStream -Force
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
            [int]$PageSize = 2500,
        [parameter(Mandatory=$false)] #ReturnAfter for Get-CognosDataSet. #This is not used here.
            [int]$ReturnAfter
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

    if ($cognosDSN -like "*fms") {
        #eFinance
        if ($CognoseFPUsername) {
            $camid = "CAMID(""efp_x003Aa_x003A$($CognoseFPUsername)"")"
        } else {
            $camid = "CAMID(""efp_x003Aa_x003A$($CognosUsername)"")"
        }
    } else {
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
                PageSize = $PageSize
                Parameters = $PSBoundParameters # | ConvertTo-Json
            }
        } else {
            Throw "Failed to run report. Please try with Get-CognosReport or Save-CognosReport."
        }

    } catch {
        Write-Error "$($PSItem)" -ErrorAction STOP
    }

}

function Get-CogSqlData {
    <#
        .SYNOPSIS
        This function will help build the parameters, SQL queries, and return data objects directly from the eSchool SQL database.

        .DESCRIPTION
        4/1/2024 - This is now using a new version of the reports. We no longer have pages for the larger tables. Deprecated the UID column.

        .NOTES
        This should never hit the timeout. If so, you need to break your reports into smaller chunks with SQL/dtStart/dtEnd parameters.
        
        Note to Craig - quit trying to use -RawCSV to return the data. It is not going to work. Use -AsDataSet and -RawCSV together to get a clean
        JSONL file. It has to process each returned row to remove the quotes. This is the only way to get a clean CSV file unless you use the
        -StarOnly and process externally.

        Things to do.
        - Add -Top parameter. Will require a new version of the report.
        - Add -OrderBy parameter. Will require a new version of the report.

        Table Definitions: Get-CogSqlData -Page tblDefinitions
        Column Definitions: Get-CogSqlData -Page colDefinitions 

    #>

    [CmdletBinding(DefaultParametersetName="default")]
    Param(
        [Parameter(Mandatory=$true,ParameterSetName="default")]
        [ValidateSet('version','tblDefinitions','colDefinitions')][string]$Page,
        [Parameter(Mandatory=$true,ParameterSetName="awesomeSauce")]
        [ValidateScript( {
            #we have to validate each side.
            if ((Get-CogTableDefinitions -All).name -contains $PSItem) {
                return $true
            } else {
                Throw "The specified table $Table was not found in the eSchool/eFinance definitions."
            }
        })]
        [string]$Table,
        [Parameter(Mandatory=$false,ParameterSetName="awesomeSauce")][switch]$eFinance,
        [Parameter(Mandatory=$false,ParameterSetName="awesomeSauce")][string]$SQLWhere, #no not include where at the beginning.
        [Parameter(Mandatory=$false,ParameterSetName="awesomeSauce")][string]$Columns, #single string '[STUDENT_ID],[DISTRICT]'
        [Parameter(Mandatory=$false,ParameterSetName="awesomeSauce")][string]$dtEquals,
        [Parameter(Mandatory=$false)][string]$dtStart,
        [Parameter(Mandatory=$false)][string]$dtEnd,
        [Parameter(Mandatory=$false)][string]$dtColumn = '[CHANGE_DATE_TIME]',
        [Parameter(Mandatory=$false,ParameterSetName="default")][string]$ReportParams,
        [Parameter(Mandatory=$false)][switch]$AsDataSet, #data to be retrieved with the Get-CognosDataSet cmdlet.
        [Parameter(Mandatory=$false)][int]$PageSize = 2500, #data to be retrieved with the Get-CognosDataSet cmdlet.
        [Parameter(Mandatory=$false)][Alias('TrimCSVWhiteSpace')][switch]$Trim,
        [Parameter(Mandatory=$false)][switch]$StartOnly, #start the report and return the reference id.
        [Parameter(Mandatory=$false)][string]$RefId, #to be used with StartOnly to reference the report again.
        [Parameter(Mandatory=$false,ParameterSetName="awesomeSauce")]$PKColumns, #override with string '[STUDENT_ID],[STUDENT_GUID]'
        [Parameter(Mandatory=$false,ParameterSetName="awesomeSauce")][int]$Top,
        [Parameter(Mandatory=$false,ParameterSetName="awesomeSauce")][string]$OrderBy, # STUDENT_ID DESC
        [Parameter(Mandatory=$false)][switch]$RawCSV, #return the data as a string instead of objects.
        [Parameter(Mandatory=$false)][Switch]$DoNotLimitSchoolYear #by default all queries, if table has SCHOOL_YEAR OR SECTION_ID, will be limited to the current school year.
    )

    function Get-Hash {

        Param(
            [Parameter(ValueFromPipeline, Mandatory=$true, Position=0)][String]$String,
            [Parameter(ValueFromPipelineByPropertyName, Mandatory=$false, Position=1)][ValidateSet("MD5", "SHA1", "SHA256", "SHA384", "SHA512")][String]$Hash = "SHA1"
        )
        
        $StringBuilder = New-Object System.Text.StringBuilder
        [System.Security.Cryptography.HashAlgorithm]::Create($Hash).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($String))| ForEach-Object {
            [Void]$StringBuilder.Append($PSItem.ToString("x2"))
        }
        
        return ($StringBuilder.ToString())
    
    }

    if ($null -eq $CognosDSN) { Connect-ToCognos }

    #if table is specified we will use awesomeSauce.
    if ($Table) {
        #This is just a flag to let the script know we are using the awesomeSauce so it will extract the j column as an object if you don't specify -RawCSV.
        $awesomeSauce = $True
    }

    $params = @{
        report = (Get-Hash $CognosDSN -Hash SHA256).Substring(0,24)
        reportparams = ''
        TeamContent = $True
        cognosfolder = "_Shared Data File Reports\automation"
    }

    if ($awesomeSauce) {
        if ($eFinance) {
            # verify we are logged into eFinance side and switch if needed.
            try {
                #If the eFinancePLUS folder is not found then we are not logged into the eFinance side.
                if (-Not(Invoke-IndexCognosFolder -url "https://adecognos.arkansas.gov/ibmcognos/bi/v1/disp/rds/wsil/path/Team%20Content" |
                    Where-Object -Property Name -eq "eFinancePLUS")) {
                        Connect-ToCognos -eFinance
                }
            } catch {
                #Failure means either Cognos is Down OR we are not logged into the eFinance side.
                Write-Warning "Switching to eFinancePLUS"
                Connect-ToCognos -eFinance
            }
        }

        $params.reportparams = "p_page=awesomeSauce&p_tblName=[$($table)]"

        if ($Top) {
            $params.reportparams += "&p_top=TOP $($Top)"
        }

        if ($OrderBy) {
            $params.reportparams += "&p_orderby=ORDER BY $($OrderBy)"
        }

        #Primary Keys need to be specified or we will attempt to pull from the Get-CogTableDefinitions.
        if ($PKColumns) {
            $primaryKeys = $PKColumns.Split(',')

            $primaryKeysMatch = $primaryKeys | ForEach-Object {
                " $($PSItem) = t.$($PSItem) "
            }
            
        } else {

            $tblParams = @{
                Table = $Table
                PKColumns = $true #return an array of primary keys.
                TableColumns = $false #do not return the columns.
                eFinance = $eFinance ? $true : $false #if eFinance is specified then set to true.
            }

            $primaryKeys = Get-CogTableDefinitions @tblParams
        
            if ($primaryKeys) {
                $primaryKeysMatch = $primaryKeys | ForEach-Object {
                    " $($PSItem) = t.$($PSItem) "
                }
            } else {
                #some tables have no ROW_IDENTIY or PRIMARY KEYS. This is a problem and must be matched on all columns OR a uniquely generated identifying column.
                Write-Warning "Table $Table does not contain ROW_IDENTITY or PRIMARY KEYS. We will match on all columns instead."

                $tblParams.PKColumns = $false
                $tblParams.Columns = $true

                $primaryKeysMatch = Get-CogTableDefinitions @tblParams | ForEach-Object {
                    "$($PSItem) = t.$($PSItem)"
                }
            }

            #joinKeys is the left join match. Primary Keys are required but it can also be a custom list.
            $joinKeys = $primaryKeysMatch -join ' AND '
            $params.reportparams += "&p_joinKeys=$($joinKeys)"

        }

        Write-Verbose ($params.reportparams)

        if ($Columns) {
            $params.reportparams += "&p_colSpecify=$($Columns)"
        } else {
            #by default always exclude the SSN and FMS_EMPL_NUMBER. If you need those you must specify them.
            $tblParams = @{
                Table = $Table
                Columns = $true
                eFinance = $eFinance ? $true : $false
            }
            $columns = (Get-CogTableDefinitions @tblParams | Where-Object { @('SSN','FMS_EMPL_NUMBER') -notcontains $PSItem }) -join ','
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

        if ($ReportParams) {
            $params.reportparams += "&$($ReportParams)"
        }

        #if not awesome sauce then use the regular paramaters for date time.
        if ($dtStart) {
            $params.reportparams += "&p_dtStart=" + (Get-Date "$dtStart").ToShortDateString()
        }
        if ($dtEnd) {
            $params.reportparams += "&p_dtEnd=" + (Get-Date "$dtEnd").ToShortDateString()
        }
    }

    #default to using the current school year unless specified. This is eSchool specific and does not apply to eFinance.
    if (-Not($DoNotLimitSchoolYear) -and -Not($eFinance)) {
        if ((Get-CogTableDefinitions -Table $Table -TableColumns) -contains 'SCHOOL_YEAR') {
            if ($SQLWhere) {
                #append to existing where clause.
                $SQLWhere += " AND SCHOOL_YEAR = (SELECT CASE WHEN MONTH(GETDATE()) > 6 THEN YEAR(DATEADD(year,1,GetDate())) ELSE YEAR(GetDate()) END) "
            } else {
                #create a new where clause.
                $SQLWhere = " SCHOOL_YEAR = (SELECT CASE WHEN MONTH(GETDATE()) > 6 THEN YEAR(DATEADD(year,1,GetDate())) ELSE YEAR(GetDate()) END) "
            }
        }

        if ((Get-CogTableDefinitions -Table $Table -TableColumns) -contains 'SECTION_ID') {
            if ($SQLWhere) {
                #append to existing where clause.
                $SQLWhere += " AND SECTION_KEY IN (SELECT SECTION_KEY FROM SCHD_MS WHERE SCHOOL_YEAR = (SELECT CASE WHEN MONTH(GETDATE()) > 6 THEN YEAR(DATEADD(YEAR,1,GETDATE())) ELSE YEAR(GETDATE()) END)) "
            } else {
                #create a new where clause.
                $SQLWhere = " SECTION_KEY IN (SELECT SECTION_KEY FROM SCHD_MS WHERE SCHOOL_YEAR = (SELECT CASE WHEN MONTH(GETDATE()) > 6 THEN YEAR(DATEADD(YEAR,1,GETDATE())) ELSE YEAR(GETDATE()) END)) "
            }
        }
    }

    if ($SQLWhere -or $dtSql) {
        if ($SQLWhere -and $dtSql) {
            $SQLWhere += " AND $dtSql "
        } elseif ($dtSql) {
            $SQLWhere += " $dtSql "
        }
        
        $params.reportparams += "&p_where=" + $SQLWhere
    }

    if ($AsDataSet) {
        $params.extension = 'json'
        $params.PageSize = $PageSize
    }

    #runkey - *eyeroll*
    $runKey = Get-Hash ($CognosDSN.Substring(0,$CognosDSN.Length - 3)) -Hash SHA256
    $params.reportparams += "&p_runKey=$($runKey.Substring(0,24))"

    Write-Verbose ($params | ConvertTo-Json)

    if ($StartOnly) {
        return (Start-CognosReport @params -RefID $RefId)
    } else {
        
        if ($AsDataSet) {

            #We have to return the data set after each run so we can decide what to do with it. The automation
            #reports in Cognos will always return one more page of data being the version page.

            $Conversation = Start-CognosReport @params

            $DataSetParams = @{
                conversationID = $Conversation.ConversationID
                PageSize = $Conversation.PageSize
                ReturnAfter = $Conversation.PageSize #Each time we run this its going to return a data object.
                DisableProgress = $true
            }

            if ($Trim) {
                $DataSetParams.Trim = $True
            }

            if ($RawCSV) {
                $RawCSVHeaders = $False
                $dataCounter = 0
            } else {
                $data = [System.Collections.Generic.List[Object]]::new()
                $dataCounter = 0
            }
            
            
            #This will loop through all the pages until we get the version page.
            do {
                
                $dataSet = (Get-CognosDataSet @DataSetParams)

                Write-Verbose ($dataSet | ConvertTo-Json)

                if ($dataSet.Data.value -eq "No Data Available") {
                    Write-Warning "No Data Available"
                    return #return null.
                }

                #This is for Get-CogSqlData. If you have mulitple pages then it pages through all of them. Even the default.
                if (($dataSet.Data).Count -eq 1) {
                    if (($dataSet.Data).Version -match '\d+\.\d+\.\d+') {
                        Write-Verbose "Version page returned. We are done."
                        break
                    }
                }

                if ((($dataSet.data).Count) -lt $PageSize) {
                    $Done = $True
                }

                $dataCounter += ($dataSet.Data).Count
                Write-Progress -Activity "Downloading Report Data" -Status "$($dataCounter) rows downloaded." -PercentComplete 0

                if ($RawCSV) {
                    if ($RawCSVHeaders -eq $False) {
                        #first iteration includes the headers.
                        $RawCSVHeaders = $True
                        $data += $dataSet.data | ConvertTo-CSV
                    } else {
                        #no headers afterwards.
                        $data += $dataSet.data | ConvertTo-Csv | Select-Object -Skip 1
                    }
                } else {
                    #add each row to the original list array. Otherwise you end up with an array of arrays.
                    # $data.Add($dataSet.data)
                    $dataSet.data | ForEach-Object {
                        $data.Add($PSItem)
                    }
                }

            } until ($Done)

            if ($RawCSV) {
                #return the raw CSV string.
                return $data
            }

        } else {
            #this must be returned. If you return the CSV now it won't be escaped correctly. It must be processed as a CSV then returned.
            $data = (Get-CognosReport @params)
        }

        if ($awesomeSauce) {
           
            if ($null -eq $data) {
                Write-Warning "No data returned."
                return
            } else {
                #extract the data from the data object.
                $data = $data.j | ConvertFrom-Json
            }

            if ($Trim) {
                $data | ForEach-Object {  
                    $PSItem.PSObject.Properties | ForEach-Object {
                        if ($null -ne $PSItem.Value -and $PSItem.Value.GetType().Name -eq 'String') {
                            $PSItem.Value = $PSItem.Value.Trim()
                        }
                    }
                }
            }

            if ($RawCSV) {
                #return it as a CSV.
                return $data | ConvertTo-Csv
            } else {
                #return it as an object.
                return $data
            }
            
        } else {
            if ($page -ne 'version' -and $data.version -match '\d+\.\d+\.\d+') {
                Write-Verbose "Version page returned."
                return @()
                Write-Verbose ($data | ConvertTo-Json)
                Write-Error "Incorrect page specified." -ErrorAction Stop
            } else {
                
                if ($Trim) {
                    $data | ForEach-Object {  
                        $PSItem.PSObject.Properties | ForEach-Object {
                            if ($null -ne $PSItem.Value -and $PSItem.Value.GetType().Name -eq 'String') {
                                $PSItem.Value = $PSItem.Value.Trim()
                            }
                        }
                    }
                }

                if ($RawCSV) {
                    return $data | ConvertTo-Csv
                } else {
                    return $data
                }
            }
        }
    }

}

function Update-CogTableDefinitions {
    <#
    .DESCRIPTION
    The FMS side of this isn't ready yet.
    #>

    Param(
        [Parameter(Mandatory=$false)][switch]$eFinance
    )

    if ($eFinance) {
        $fileName = 'efpTables.csv'
    
        $params = @{
            page = 'tblDefinitionsFMS'
            eFinance = $true
        }

    } else {
        $fileName = 'espTables.csv'

        $params = @{
            page = 'tblDefinitions'
        }

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
                $schedules.Add($PSItem.Group)
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
            $schedules.Add($PSItem.Group)
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
        [parameter(Mandatory=$false)][switch]$IncludeComments, #Include the commented reason for the absence
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
                $parameters.reportparams += "p_ExcludePeriodsByName=$($PSItem)&"
            }
        }
  
        if ($IncludeComments) {
            $parameters.reportparams += "p_page=attendance_with_comments&"
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
                $parameters.reportparams += "p_building=$($PSItem)&"
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
    $folders.Node | Where-Object { $null -ne $PSItem.name } | ForEach-Object {

        $name = $PSItem.abstract
        $location = $PSItem.location -replace 'http://adecognos.arkansas.gov:80','https://adecognos.arkansas.gov'

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

    $files.Node | Where-Object { $null -ne $PSItem.name } | ForEach-Object {

        $name = $PSItem.Name
        $location = $PSItem.description.location -replace 'http://adecognos.arkansas.gov:80','https://adecognos.arkansas.gov'

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
                    $PSItem
                    
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

function Invoke-IndexCognosFolder {
        
    Param(
        [parameter(Mandatory=$true)][string]$url
    )

    $results = [System.Collections.Generic.List[PSObject]]@()
    try {
        $foldercontents = Invoke-WebRequest -Uri "$url" -WebSession $CognosSession
    } catch {
        #because sometimes Cognos simply doesn't reply.
        Start-Sleep -Seconds 1
    } finally {
        $foldercontents = Invoke-WebRequest -Uri "$url" -WebSession $CognosSession
    }
    $folders = Select-Xml -Xml ([xml]$foldercontents.Content) -XPath '//x:link' -Namespace @{ x = "http://schemas.xmlsoap.org/ws/2001/10/inspection/" }
    $reports = Select-Xml -Xml ([xml]$foldercontents.Content) -XPath '//x:service' -Namespace @{ x = "http://schemas.xmlsoap.org/ws/2001/10/inspection/" }

    Write-Verbose "Found: $($folders.Count) folders and $($reports.Count) reports."

    #process folders.
    $folders.Node | Where-Object { $null -ne $PSItem.name } | ForEach-Object {

        $name = $PSItem.abstract
        $location = $PSItem.location -replace 'http://adecognos.arkansas.gov:80','https://adecognos.arkansas.gov'

        $results.Add(
            [PSCustomObject]@{
                name = $name
                type = 'folder'
                url = $location
            }
        )

    }

    $reports.Node | Where-Object { $null -ne $PSItem.name } | ForEach-Object {

        $name = $PSItem.Name
        $location = $PSItem.description.location -replace 'http://adecognos.arkansas.gov:80','https://adecognos.arkansas.gov'

        $results.Add(
            [PSCustomObject]@{
                name = $name
                type = 'report'
                url = $location
            }
        )

    }

    if ($results) {
        Write-Verbose ($results | ConvertTo-Json)
        return $results
    } else {
        Write-Warning "Empty folder."
        return $null
    }

}

function Invoke-IndexCognosTeamContent {

    Param(
        [parameter(Mandatory=$false)][string]$url="https://adecognos.arkansas.gov/ibmcognos/bi/v1/disp/rds/wsil/path/Team%20Content"
    )

    $indexedFolders = @{}
    $allReports = [System.Collections.Generic.List[PSObject]]@()
    $allFolders = [System.Collections.Generic.List[PSObject]]@()

    do {
        Write-Host "$url"

        $index = Invoke-IndexCognosFolder -url $url

        $reports = $index | Where-Object -Property type -EQ 'report'
        
        $reports | ForEach-Object {
            $allReports.Add($PSItem)
        }
        
        $folders = $index | Where-Object -Property type -EQ 'folder'
        
        $folders | ForEach-Object {
            $allFolders.Add($PSItem)
        }

        Write-Host "Found $($reports.Count) reports and $($folders.Count) folders."

        #this folder has been indexed.
        $indexedFolders."$($url)" = $True

        #find the next folder that needs indexed and let this loop continue.
        $url = $allFolders | Where-Object { $indexedFolders.Keys -notcontains $PSItem.url } | Select-Object -First 1 -ExpandProperty url

    } while ($url)

    return $allReports

}

function Get-CognosReportMetaData {
    
    Param(
        [parameter(Mandatory=$true)][string]$url
    )

    $url = $url -replace '/wsdl/','/atom/'

    Write-Verbose ($url)

    try {
        $reportDetails = Invoke-RestMethod -Uri $url -WebSession $CognosSession
    } catch {
        Start-Sleep -Seconds 1
    } finally {
        $reportDetails = Invoke-RestMethod -Uri $url -WebSession $CognosSession
    }
    
    $reportIDMatch = $reportDetails.feed.thumbnailURL -match "/report/(.{33})\?"
    $reportID = $Matches.1

    return (
        [PSCustomObject]@{
            Title = $reportDetails.feed.title
            Location = $reportDetails.feed.location -replace 'Team Content > Student management System > ',''
            Preview = $reportID ? "=HYPERLINK(""https://adecognos.arkansas.gov/ibmcognos/bi/?perspective=classicviewer&objRef=$($reportID)&action=run&format=HTML"",""Preview"")" : $null
            CSV = $reportID ? "=HYPERLINK(""https://adecognos.arkansas.gov/ibmcognos/bi/?perspective=classicviewer&objRef=$($reportID)&action=run&format=CSV"",""CSV"")" : $null
            Excel = $reportID ? "=HYPERLINK(""https://adecognos.arkansas.gov/ibmcognos/bi/?perspective=classicviewer&objRef=$($reportID)&action=run&format=spreadsheetML"",""Excel"")" : $null
            Description = $reportDetails.feed.description
            Author = $reportDetails.feed.author.name
            Contact = $reportDetails.feed.contact
            Owner = $reportDetails.feed.owner
            Updated = $reportDetails.feed.updated
            ReportID = $reportID
        }
    )

}

function Get-CogTableDefinitions {
    <#
    
        .SYNOPSIS
        Return the table definitions for eSchool or Efinance
    
        .DESCRIPTION
        We do not want to be reaching back out to github for this information. This is a static list of tables and their columns. It will need to be updated with the module.
        This data must come from the Get-CogSqlData -Page tblDefinitions as it contains the primary keys correctly.
    
    #>

    [CmdletBinding(DefaultParametersetName="columns")]
    Param(
        [Parameter(Mandatory=$false,ParameterSetName="All")][Switch]$All, #return the entire thing. Must be specified alone.
        [Parameter(Mandatory=$false)][Switch]$eFinance, #will filter down to "db" = "eFin"
        [Parameter(Mandatory=$false)][String]$Table, #return only a specific table.
        [Parameter(Mandatory=$false,ParameterSetName="PK")][Switch]$PKColumns, #return only the primary key columns
        [Parameter(Mandatory=$false,ParameterSetName="default")][Alias("Columns")][Switch]$TableColumns, #return only the Table Columns
        [Parameter(Mandatory=$false,ParameterSetName="PK")][Parameter(Mandatory=$false,ParameterSetName="default")][Switch]$AsString #You can only return a string of the PKColumns or Columns
    )

$dbDefinitions = @'
[
  {
    "db": "eFin",
    "name": "aca_1094load",
    "PKColumns": "",
    "TableColumns": "row_id,taxyr,batch_no,paygrp01,paygrp02,paygrp03,paygrp04,paygrp05,paygrp06,paygrp07,paygrp08,paygrp09,paygrp10,paygrp11,paygrp12,paygrp13,paygrp14,paygrp15,paygrp16,paygrp17,paygrp18,paygrp19,paygrp20,paygrp21,paygrp22,paygrp23,paygrp24,fte_calc_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "aca_1094loadsave",
    "PKColumns": "",
    "TableColumns": "row_id,taxyr,batch_no,paygrp01,paygrp02,paygrp03,paygrp04,paygrp05,paygrp06,paygrp07,paygrp08,paygrp09,paygrp10,paygrp11,paygrp12,paygrp13,paygrp14,paygrp15,paygrp16,paygrp17,paygrp18,paygrp19,paygrp20,paygrp21,paygrp22,paygrp23,paygrp24,fte_calc_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "aca_1094payrun",
    "PKColumns": "",
    "TableColumns": "taxyr,eid,prunjan,prunfeb,prunmar,prunapr,prunmay,prunjun,prunjul,prunaug,prunsep,prunoct,prunnov,prundec",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "aca_aggregate_ale",
    "PKColumns": "",
    "TableColumns": "eid,taxyr,aggr_ale_name,aggr_ale_eid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "aca_ben_class",
    "PKColumns": "",
    "TableColumns": "type,start_date,end_date,class",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "aca_ben_deduct",
    "PKColumns": "",
    "TableColumns": "type,start_date,end_date,ded_cd,plan_title,covg_group,low_prem_ind",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "aca_ben_grps",
    "PKColumns": "",
    "TableColumns": "type,title,full_part_emp,start_date,end_date,offer,summer_covg,covg_offset_type,covg_offset_days,term_offset_type,term_offset_days,benefit_start_type,benefit_start_offset_days,summer_covg_date,emp_share",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "aca_benefit_status",
    "PKColumns": "",
    "TableColumns": "ded_code,aca_status,offer_code",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "aca_code_table",
    "PKColumns": "",
    "TableColumns": "yr,code_type,code,short_desc,value",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "aca_cov_ind",
    "PKColumns": "",
    "TableColumns": "taxyr,empl_no,empl_ssn,seq_no,batch_no,depend_no,f_name,l_name,m_name,name_suffix,ssn,birthdate,covered_all,covered_jan,covered_feb,covered_mar,covered_apr,covered_may,covered_jun,covered_jul,covered_aug,covered_sep,covered_oct,covered_nov,covered_dec,data_source,data_sourced_date,ben_dep_key,full_name",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "aca_empl_ovrd",
    "PKColumns": "",
    "TableColumns": "empl_no,offer_code_all,offer_code_jan,offer_code_feb,offer_code_mar,offer_code_apr,offer_code_may,offer_code_jun,offer_code_jul,offer_code_aug,offer_code_sep,offer_code_oct,offer_code_nov,offer_code_dec,emp_share_all,emp_share_jan,emp_share_feb,emp_share_mar,emp_share_apr,emp_share_may,emp_share_jun,emp_share_jul,emp_share_aug,emp_share_sep,emp_share_oct,emp_share_nov,emp_share_dec,safe_harbor_all,safe_harbor_jan,safe_harbor_feb,safe_harbor_mar,safe_harbor_apr,safe_harbor_may,safe_harbor_jun,safe_harbor_jul,safe_harbor_aug,safe_harbor_sep,safe_harbor_oct,safe_harbor_nov,safe_harbor_dec,paper_1095c",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "aca_employee",
    "PKColumns": "",
    "TableColumns": "taxyr,empl_no,seq_no,batch_no,chk_locn,date_corrected,corrected_by,date_voided,voided_by,date_locked,locked_by,data_source,data_sourced_date,data_sourced_by,f_name,l_name,m_name,name_suffix,ssn,birthdate,street_addr,city,state_id,zip,country,offer_code_all,offer_code_jan,offer_code_feb,offer_code_mar,offer_code_apr,offer_code_may,offer_code_jun,offer_code_jul,offer_code_aug,offer_code_sep,offer_code_oct,offer_code_nov,offer_code_dec,emp_share_all,emp_share_jan,emp_share_feb,emp_share_mar,emp_share_apr,emp_share_may,emp_share_jun,emp_share_jul,emp_share_aug,emp_share_sep,emp_share_oct,emp_share_nov,emp_share_dec,safe_harbor_all,safe_harbor_jan,safe_harbor_feb,safe_harbor_mar,safe_harbor_apr,safe_harbor_may,safe_harbor_jun,safe_harbor_jul,safe_harbor_aug,safe_harbor_sep,safe_harbor_oct,safe_harbor_nov,safe_harbor_dec,ben_grp_all,ben_grp_jan,ben_grp_feb,ben_grp_mar,ben_grp_apr,ben_grp_may,ben_grp_jun,ben_grp_jul,ben_grp_aug,ben_grp_sep,ben_grp_oct,ben_grp_nov,ben_grp_dec,note,waived_all,waived_jan,waived_feb,waived_mar,waived_apr,waived_may,waived_jun,waived_jul,waived_aug,waived_sep,waived_oct,waived_nov,waived_dec,plan_start,print_date,mail_date,xml_date,subid,recid,xmlname,edited_date,edited_by,street_addr2,foreign_state,foreign_postal,zip_code_all,zip_code_jan,zip_code_feb,zip_code_mar,zip_code_apr,zip_code_may,zip_code_jun,zip_code_jul,zip_code_aug,zip_code_sep,zip_code_oct,zip_code_nov,zip_code_dec,employee_age",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "aca_employer",
    "PKColumns": "",
    "TableColumns": "reporting_type,eid,taxyr,batch_no,ename,street_addr,city,state_id,zip,country,contact,phone,dge_name,dge_eid,dge_addr1,dge_city,dge_state_id,dge_zip,dge_country,dge_contact,dge_phone,box17,cnt_1095_transmit,auth_transmittal,cnt_1095_total,ale_group_mem,cert_a,cert_b,cert_c,cert_d,all_mec_offer,all_count_fte,all_count_total,all_aggr_group,all_trans_relief,jan_mec_offer,jan_count_fte,jan_count_total,jan_aggr_group,jan_trans_relief,feb_mec_offer,feb_count_fte,feb_count_total,feb_aggr_group,feb_trans_relief,mar_mec_offer,mar_count_fte,mar_count_total,mar_aggr_group,mar_trans_relief,apr_mec_offer,apr_count_fte,apr_count_total,apr_aggr_group,apr_trans_relief,may_mec_offer,may_count_fte,may_count_total,may_aggr_group,may_trans_relief,jun_mec_offer,jun_count_fte,jun_count_total,jun_aggr_group,jun_trans_relief,jul_mec_offer,jul_count_fte,jul_count_total,jul_aggr_group,jul_trans_relief,aug_mec_offer,aug_count_fte,aug_count_total,aug_aggr_group,aug_trans_relief,sep_mec_offer,sep_count_fte,sep_count_total,sep_aggr_group,sep_trans_relief,oct_mec_offer,oct_count_fte,oct_count_total,oct_aggr_group,oct_trans_relief,nov_mec_offer,nov_count_fte,nov_count_total,nov_aggr_group,nov_trans_relief,dec_mec_offer,dec_count_fte,dec_count_total,dec_aggr_group,dec_trans_relief,issuer_name,issuer_eid,issuer_phone,issuer_addr1,issuer_city,issuer_state_id,issuer_zip,issuer_country,mask_ssn,use_aca_hours_fte,self_insured,calc_date,use_ben_mod,use_deduct_beff_date,tcc,print_date,subid,xmlname,xml_date,edited_date,edited_by,street_addr2,origin_code,issuer_contact_f_name,issuer_contact_m_name,issuer_contact_l_name,issuer_contact_name_suffix,issuer_addr2",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "aca_hrs_conversion",
    "PKColumns": "",
    "TableColumns": "group_x,classify,pay_code,imp_hr_per_unit,load_hr_per_unit,priority,use_fte,use_cal_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "aca_load",
    "PKColumns": "",
    "TableColumns": "taxyr,batch_no,start_date,end_date,empl_no,bengrp01,bengrp02,bengrp03,bengrp04,bengrp05,bengrp06,bengrp07,bengrp08,bengrp09,bengrp10,bengrp11,bengrp12,bengrp13,bengrp14,bengrp15,bengrp16,bengrp17,bengrp18,bengrp19,bengrp20,bengrp21,bengrp22,bengrp23,bengrp24,paygrp01,paygrp02,paygrp03,paygrp04,paygrp05,paygrp06,paygrp07,paygrp08,paygrp09,paygrp10,paygrp11,paygrp12,paygrp13,paygrp14,paygrp15,paygrp16,paygrp17,paygrp18,paygrp19,paygrp20,paygrp21,paygrp22,paygrp23,paygrp24,load_deps,safeharbor",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "aca_prt_setup",
    "PKColumns": "",
    "TableColumns": "flg_print,comp_name,density,p_name,flg_form,flg_media,state_id,mailer,preback,prefront,prtform",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "aca_xml_track",
    "PKColumns": "",
    "TableColumns": "taxyr,create_date,xmlname,batch_no,count_1095c,auth_trans,trans_type,receipt_id,transmit_date,irs_status,irs_status_date,utid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "acct4table",
    "PKColumns": "",
    "TableColumns": "acct,acctkeyup,accttitle",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "accttype",
    "PKColumns": "",
    "TableColumns": "acctnum,description",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "activtbl",
    "PKColumns": "",
    "TableColumns": "activity,description",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "actor",
    "PKColumns": "",
    "TableColumns": "row_id,uid,supervisor_id,lvl,super_flag,role_id,notify_type,alt_super_id,link_id,approval_group",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "adb_chart_config",
    "PKColumns": "id",
    "TableColumns": "id,uid,widget_id,user_id,chart_settings,selected_filters",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "adb_dashboard",
    "PKColumns": "id",
    "TableColumns": "id,uid,name,is_locked,copied_from_id,is_default",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "adb_data_source",
    "PKColumns": "id",
    "TableColumns": "id,uid,name,title,description",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "adb_migration",
    "PKColumns": "id",
    "TableColumns": "id,name,run_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "adb_user_dashboard",
    "PKColumns": "id",
    "TableColumns": "id,uid,user_id,dashboard_id,sequence",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "adb_widget",
    "PKColumns": "id",
    "TableColumns": "id,uid,widget_type_id,dashboard_id,data_source_id",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "adb_widget_type",
    "PKColumns": "id",
    "TableColumns": "id,uid,name,description",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "add_rate",
    "PKColumns": "",
    "TableColumns": "empl_no,indx,code,salary,fte,prorate",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "addempldetail",
    "PKColumns": "",
    "TableColumns": "row_id,proc_step,empl_no,complete,navigation,lastupddate,lastupdtime,lastupduid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "addemplroles",
    "PKColumns": "",
    "TableColumns": "row_id,title,groupheader,spidefined",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "addemplsec",
    "PKColumns": "",
    "TableColumns": "row_id,proc_step,usertype",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "addemplsteps",
    "PKColumns": "",
    "TableColumns": "proc_step,description,required,step_order,page_no,hrm_type",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "addemplusers",
    "PKColumns": "",
    "TableColumns": "row_id,uid,hrm_type,primry",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "addrbk",
    "PKColumns": "",
    "TableColumns": "user_id,uname,address",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "adjust_data",
    "PKColumns": "",
    "TableColumns": "empl_no,jobclass,sched,orig_paycd,step_b,range_b,step_a,range_a,chg_date,start_date,end_date,dailyrate_b,dailyrate_a,payrate_b,payrate_i,payrate_a,dockrate_b,dockrate_a,days_bef,hrs_bef,contractdays,newcontdays,cont_paid,num_rpays,hasretro,startpayrun,active",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "adv_pay",
    "PKColumns": "",
    "TableColumns": "empl_no,classify,last_run,check_no,num_adv",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "aesattend",
    "PKColumns": "",
    "TableColumns": "empl_no,pay_code,start_date,end_date,lv_hrs,remarks,check_date,status_flg,lv_code,pay_run,post_flag,sub_id,sub_pay_code,sub_pay_class,sub_hours,sub_pay_rate,sub_amt_paid,sub_loc,sub_tax_ind,sub_orgn,sub_acct,cal_val,aes_id,aes_post_flag,aes_run",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "aesmask",
    "PKColumns": "",
    "TableColumns": "pay_code,orgn,account",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "aespaytab",
    "PKColumns": "",
    "TableColumns": "aes_code,pei_code",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "alt_vend_addr",
    "PKColumns": "",
    "TableColumns": "alt_vend_no,vend_no,cre_date,ven_name,b_addr_1,b_addr_2,b_city,b_state,b_zip,fed_id,form_1099,track_orig,type_misc,ytd_misc,type_g,ytd_g,type_int,ytd_int,ytd_paid,ten99_ven_name,ten99_addr_1,ten99_addr_2,ten99_city,ten99_state,ten99_zip",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "alt_vnd_misc",
    "PKColumns": "",
    "TableColumns": "alt_vend_no,vend_no,bank_trans_code,bank_code,bank_acct_no,alt_email",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMApplicantCertType",
    "PKColumns": "Unique_Key",
    "TableColumns": "ApplicationID,CertificationType,CertificateNumber,ExpirationDate,IssueDate,RegistrationDate,ApplicantID,QuestionCategoryID,QuestionOrder,DocumentCount,PostingID,DocumentLink,HRVerifiedDate,HRVerifiedBy,HRExpirationDate,HRVerifyStatus,VerifyComments,Create_When,Create_Who,Update_When,Update_Who,Unique_Key,ExternalComments,ApplicantComments,CertificationArea,HighlyQualified,PrimaryCert,DisplayComments,DocumentID",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMApplicantDefinition",
    "PKColumns": "ApplicantID",
    "TableColumns": "ApplicantID,FirstName,LastName,MiddleName,Suffix,ApplicantStatus,EmployedStartDate,EmployedEndDate,AddressLine1,AddressLine2,Country,State,City,County,Zip,ZipExtension,EmailAddress1,EmailAddress2,EmailAddress3,PhoneType1,Phone1,Phone1Extension,PhoneType2,Phone2,Phone2Extension,PhoneType3,Phone3,Phone3Extension,SSN,LinkedInProfile,StateID,Create_When,Create_Who,Update_When,Update_Who,Unique_Key,EmployeeId,StatusExpirationDate,ApplicantNotes,EmployeeStatus,Rating",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMApplicantEducation",
    "PKColumns": "Unique_Key",
    "TableColumns": "ApplicationID,QuestionCategoryID,QuestionOrder,DocumentCount,DocumentLink,PostingID,Awarded,Credits,DegreeCode,GPA,InstitutionCode,InstitutionDesc,MajorCode,MajorDesc,MinorCode,MinorDesc,Notes,Pending,Miscellaneous1,Miscellaneous2,Miscellaneous3,Miscellaneous4,Miscellaneous5,UnitType,HRVerifiedDate,HRVerifiedBy,HRExpirationDate,HRVerifyStatus,VerifyComments,Create_When,Create_Who,Update_When,Update_Who,Unique_Key,ExternalComments,ApplicantComments,DisplayComments",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMApplicantEEO",
    "PKColumns": "Unique_Key",
    "TableColumns": "ApplicationID,QuestionOrder,DocumentCount,PostingID,Gender,Ethinicity,AfricanAmerican,AmericanIndian,Asian,OtherPacificIsland,White,Race6,Race7,Race8,Race9,Race10,Create_When,Create_Who,Update_When,Update_Who,Unique_Key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMApplicantEEOCodes",
    "PKColumns": "Unique_Key",
    "TableColumns": "ApplicationID,ApplicantID,CodeType,CodeValue,Create_When,Create_Who,Update_When,Update_Who,Unique_Key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMApplicantExperience",
    "PKColumns": "Unique_Key",
    "TableColumns": "ApplicationID,QuestionCategoryID,QuestionOrder,DocumentCount,DocumentLink,PostingID,AddTotal,AppliedDate,BeginDate,BeginDate1,DetailNote,EndDate,EndDate1,ExperienceCode,InhouseYear,ExperienceNotes,Value1,Value2,Value3,Value4,Value5,PreEmpYears,HRVerifiedDate,HRVerifiedBy,HRExpirationDate,HRVerifyStatus,VerifyComments,Create_When,Create_Who,Update_When,Update_Who,Unique_Key,ExternalComments,ApplicantComments,DisplayComments",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMApplicantGallupMaster",
    "PKColumns": "Unique_Key",
    "TableColumns": "ApplicantID,RequestClientID,RequestClientBusinessUnitID,RequestManagerKey,RequestInterviewCode,RequestAccessCode,RequestTransmitDate,RequestTransmitDateCTZ,ConfirmationStatus,ConfirmationStatusDetail,ConfirmationStatusDate,ConfirmationAssessmentLink,ConfirmationTransmitDateCTZ,AssessmentStatus,AssessmentStatusDate,AssessmentTransmitDateCTZ,AssessmentAttemptNumber,AssessmentInterviewCompCTZ,Create_When,Create_Who,Update_When,Update_Who,Unique_Key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMApplicantGallupResults",
    "PKColumns": "Unique_Key",
    "TableColumns": "GallupMasterUniqueKey,AssessmentProfile,AssessmentResult,AssessmentResultType,Create_When,Create_Who,Update_When,Update_Who,Unique_Key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMApplicantInterview",
    "PKColumns": "Unique_Key",
    "TableColumns": "ApplicationID,InterviewDate,Interviewer,Round,Score,Status,Comments,LinkId,Create_When,Create_Who,Update_When,Update_Who,Unique_Key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMApplicantReference",
    "PKColumns": "Unique_Key",
    "TableColumns": "ApplicationID,QuestionCategoryID,QuestionOrder,DocumentCount,DocumentLink,PostingID,EMail,EmailReceived,EmailSent,FirstName,LastName,PhoneExtension,PhoneNo,Relation,Title,YearsKnown,ReferenceNotes,ReferenceID,EReference,HRVerifiedDate,HRVerifiedBy,HRExpirationDate,HRVerifyStatus,VerifyComments,Create_When,Create_Who,Update_When,Update_Who,Unique_Key,ExternalComments,ApplicantComments,DisplayComments",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMApplicantSkill",
    "PKColumns": "Unique_Key",
    "TableColumns": "ApplicationID,QuestionCategoryID,QuestionOrder,DocumentCount,DocumentLink,PostingID,EducationSource,ExperienceSource,Skill,SkillNotes,HRVerifiedDate,HRVerifiedBy,HRExpirationDate,HRVerifyStatus,VerifyComments,Create_When,Create_Who,Update_When,Update_Who,Unique_Key,ExternalComments,ApplicantComments,DisplayComments",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMApplication",
    "PKColumns": "Unique_Key",
    "TableColumns": "ApplicationID,ApplicantID,PostingID,ApplicantType,Score,ApplicationStatus,Create_When,Create_Who,Update_When,Update_Who,Unique_Key,ApplicationCreateDate,RecommendedForHire,SelectedForInterview,DateSubmitted",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMApplicationCategory",
    "PKColumns": "ApplicationID,ApplicantID,PostingID,QuestionCategoryID",
    "TableColumns": "ApplicationID,ApplicantID,PostingID,QuestionCategoryID,JobType,ApplicationType,QuestionCategory,WorkFlowID,EmailTemplateID,Create_When,Create_Who,Update_When,Update_Who,Unique_Key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMApplicationChecklist",
    "PKColumns": "ApplicationID,ItemGUID",
    "TableColumns": "ApplicationID,ItemGUID,ApproveReject,CheckListDate,Unique_Key,Create_When,Create_Who,Update_When,Update_Who,Comment",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMApplicationDisposition",
    "PKColumns": "Unique_Key",
    "TableColumns": "ApplicationID,DispositionCode,Comments,Create_When,Create_Who,Update_When,Update_Who,Unique_Key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMApplicationHistory",
    "PKColumns": "ApplicationHistoryID",
    "TableColumns": "ApplicationHistoryID,ApplicationID,Action,ActionBy,ActionDate,Comments,Create_When,Create_Who,Update_When,Update_Who,Unique_Key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMApplicationNotes",
    "PKColumns": "ApplicationNotesID",
    "TableColumns": "ApplicationNotesID,ApplicationID,ApplicationNotes,Create_When,Create_Who,Update_When,Update_Who,Unique_Key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMApplicationResponses",
    "PKColumns": "ApplicationResponseID",
    "TableColumns": "ApplicationResponseID,ApplicationID,QuestionID,QuestionVersion,QuestionCategoryID,QuestionOrder,DocumentCount,DocumentLink,PostingID,OtherOrMain,ResponseID,Response,Score,HRVerifiedDate,HRVerifiedBy,HRExpirationDate,HRVerifyStatus,VerifyComments,Create_When,Create_Who,Update_When,Update_Who,Unique_Key,ExternalComments,ApplicantComments,DisplayComments",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMCodes",
    "PKColumns": "Unique_Key",
    "TableColumns": "CodeCategory,CodeValue,CodeFlag,CodeStatus,ShortDescription,LongDescription,Create_When,Create_Who,Update_When,Update_Who,Unique_Key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMEmailTemplate",
    "PKColumns": "EmailTemplateID",
    "TableColumns": "EmailTemplateID,Title,TemplateDescription,EmailFrom,ToList,CcList,BccList,Subject,EmailBody,Create_When,Create_Who,Update_When,Update_Who,Unique_Key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMGallup",
    "PKColumns": "GallupClientID",
    "TableColumns": "GallupClientID,ApplicationID,ApplicantAssessmentURL,InterviewName,Profile,CompletionDate,Result,TalentReportUrl,Create_When,Create_Who,Update_When,Update_Who,Unique_Key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMGallupHistory",
    "PKColumns": "Unique_Key",
    "TableColumns": "SSN,AssessmentProfile,AssessmentResult,AssessmentResultType,Unique_Key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMHAViewConfiguration",
    "PKColumns": "HAViewColumnID",
    "TableColumns": "HAViewColumnID,JobType,ColumnOrder,ColumnLabel,Create_When,Create_Who,Update_When,Update_Who,Unique_Key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMHireRecommendation",
    "PKColumns": "RecommendationID",
    "TableColumns": "RecommendationID,ApplicationID,Status,OfferExtended,OfferSentDate,OfferAccepted,OfferAcceptedDate,HireDate,FirstWorkDay,FirstPayDay,UseSalaryTable,SalarySchedule,SalaryRange,SalaryStep,EnterRate,HourlyRate,PeriodRate,DailyRate,AnnualRate,BargainingUnit,PayCycle,Entity,GenerateId,EmployeeID,Create_When,Create_Who,Update_When,Update_Who,Unique_Key,JobType,PCN,Position,CalculateBy,EmployeeType,AssignmentStatus,CreateQuickPay,ContractId,CalcOption,Calendar,LastPayDay,LastWorkDay,PeriodType,OfficialStart,OfficialStartDate",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMLicenseCertificate",
    "PKColumns": "Unique_Key",
    "TableColumns": "ApplicationID,QuestionCategoryID,QuestionOrder,DocumentCount,DocumentLink,PostingID,LicenseCertificateType,LicenseNo,RegistrationID,RegistrationState,ExpireDate,IssueDate,LicenseNotes,SpecialField1,SpecialField2,SpecialField3,HRVerifiedDate,HRVerifiedBy,HRExpirationDate,HRVerifyStatus,VerifyComments,Create_When,Create_Who,Update_When,Update_Who,Unique_Key,ExternalComments,ApplicantComments,DisplayComments",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "amort_sched",
    "PKColumns": "",
    "TableColumns": "bond_no,payment_dte,beg_bal,payment_amt,curr_bal,prin_amt,int_amt,amort_prem,amort_disc",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMPostAprv",
    "PKColumns": "posting_id,lvl,association_id",
    "TableColumns": "posting_id,lvl,association_id,association_seq,phase_no,app_empl_no,del_empl_no,act,action_date,comment,approved_by",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMPostAprvHist",
    "PKColumns": "row_id",
    "TableColumns": "row_id,hist_date,hist_time,posting_id,lvl,association_id,association_seq,phase_no,app_empl_no,del_empl_no,act,action_date,comment,approved_by,approval_level",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMPostingCertificates",
    "PKColumns": "Unique_Key",
    "TableColumns": "PostingID,Course_Group,Course_No,Core_Area,Create_When,Create_Who,Update_When,Update_Who,Unique_Key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMPostingDefinition",
    "PKColumns": "PostingID",
    "TableColumns": "PostingID,JobType,EntityID,FiscalYear,NumberOfPositions,NumberOfPositionsFilled,Location,PostingStatus,PostedDate,ClosingDate,Position,PositionTitle,Pcn,MinimumSalary,MaximumSalary,FTE,DaysPerYear,HoursPerDay,PeriodsPerYear,TentativeStartDate,ReasonCode,PostingType,PostingComments,InternalMessage,Create_When,Create_Who,Update_When,Update_Who,Unique_Key,CreationType,Postype,Department,BaseLocation,PCAsOfDate,HiringManager,Code1,Code2,Code3,Code4,FTEFilled,NextYearPosting,CopiedFromPostingID,CopyPostingSpecific,CopyDefaultQuestions,OpenUntilFilled,MonthsPerYear,ShiftType",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMPostingDistOrgn",
    "PKColumns": "Unique_Key",
    "TableColumns": "PostingID,Orgn,Acct,Prcnt,Source,Create_When,Create_Who,Update_When,Update_Who,Unique_Key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMPostingDistProj",
    "PKColumns": "Unique_Key",
    "TableColumns": "PostingID,Proj,Acct,Prcnt,Source,Create_When,Create_Who,Update_When,Update_Who,Unique_Key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMPostingDistribution",
    "PKColumns": "Unique_Key",
    "TableColumns": "PostingID,GlLedger,GlKey,GlObj,JlLedger,JlKey,JlObj,Percent,Fte,Amt,Source,Position,Pcn,AvailFTE,AvailAmt,Create_When,Create_Who,Update_When,Update_Who,Unique_Key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMPostingHistory",
    "PKColumns": "PostingHistoryID",
    "TableColumns": "PostingHistoryID,PostingID,Action,ActionBy,ActionDate,Comments,Create_When,Create_Who,Update_When,Update_Who,Unique_Key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMPostingNotifications",
    "PKColumns": "Unique_Key",
    "TableColumns": "ApplicantID,Classification,Value,Unique_Key,Description",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMPostingQuestionCategory",
    "PKColumns": "Unique_Key",
    "TableColumns": "QuestionCategoryID,PostingID,JobType,QuestionCategory,QuestionCategoryOrder,ExplanatoryComments,WorkFlowID,EmailTemplateID,Create_When,Create_Who,Update_When,Update_Who,Unique_Key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMPostingQuestionDefinition",
    "PKColumns": "PostingID,QuestionID",
    "TableColumns": "PostingID,QuestionID,QuestionType,QuestionText,IntroductionText,Description,ShortDescription,ExplanatoryComments,ResponseType,MinNumberOfResponses,ResponseRequired,OtherAnswerOptionlabel,IncludeOtherAnswerOption,IsMinimumReq,Create_When,Create_Who,Update_When,Update_Who,Unique_Key,DocumentUploadRequired,HRValidationRequired,QuestionVersion,RollAnswers,InternalQuestion,SyncQuestion,HideFromReview",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMPostingQuestionDetails",
    "PKColumns": "Unique_Key",
    "TableColumns": "QuestionCategoryID,QuestionID,HALabel,HAOrder,QuestionOrder,PostingID,Create_When,Create_Who,Update_When,Update_Who,Unique_Key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMPostingQuestionResponseDef",
    "PKColumns": "PostingID,QuestionID,ResponseID",
    "TableColumns": "PostingID,QuestionID,ResponseID,ResponseText,ResponseType,MeetsMinRequirement,Score,RequireOther,DocumentUpload,ResponseOrder,RequiresDispositionCode,Create_When,Create_Who,Update_When,Update_Who,Unique_Key,RequireHRVerification",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMPostingReasons",
    "PKColumns": "Unique_Key",
    "TableColumns": "PostingID,ReasonCode,Replacing,Comments,Create_When,Create_Who,Update_When,Update_Who,Unique_Key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMPostingSpecificQuestions",
    "PKColumns": "Unique_Key",
    "TableColumns": "QuestionID,PostingID,Selected,Unique_Key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMPostingTransfer",
    "PKColumns": "Unique_Key",
    "TableColumns": "PostingID,postype,position,pcn,GlLedger,GlKey,GlObj,JlLedger,JlKey,JlObj,AvailFte,AvailAmt,AvailApu,TransferFte,TransferAmt,TransferApu,PCUniqueKey,Create_When,Create_Who,Update_When,Update_Who,Unique_Key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMPostingTransferEFP",
    "PKColumns": "Unique_Key",
    "TableColumns": "PostingID,PCNFrom,PositionFrom,TransferFte,TransferbSalary,Create_When,Create_Who,Update_When,Update_Who,Unique_Key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMPostRequestEFP",
    "PKColumns": "posting_id",
    "TableColumns": "posting_id,posting_type,req_empl_no,appr_status,submit_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMQuestionCategory",
    "PKColumns": "QuestionCategoryID,JobType",
    "TableColumns": "QuestionCategoryID,JobType,ApplicationType,QuestionCategory,QuestionCategoryOrder,ExplanatoryComments,WorkFlowID,EmailTemplateID,Create_When,Create_Who,Update_When,Update_Who,Unique_Key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMQuestionDefinition",
    "PKColumns": "QuestionID",
    "TableColumns": "QuestionID,Description,ShortDescription,QuestionType,QuestionText,IntroductionText,ExplanatoryComments,ResponseType,MinNumberOfResponses,ResponseRequired,IsMinimumReq,IncludeOtherAnswerOption,OtherAnswerOptionlabel,Create_When,Create_Who,Update_When,Update_Who,Unique_Key,DocumentUploadRequired,HRValidationRequired,QuestionVersion,RollAnswers,InternalQuestion,SyncQuestion,HideFromReview",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMQuestionDetails",
    "PKColumns": "QuestionCategoryID,QuestionID",
    "TableColumns": "QuestionCategoryID,QuestionID,JobType,QuestionOrder,HALabel,HAOrder,Create_When,Create_Who,Update_When,Update_Who,Unique_Key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMQuestionResponseDefinition",
    "PKColumns": "ResponseID",
    "TableColumns": "ResponseID,ResponseText,ResponseType,MeetsMinRequirement,Score,RequireOther,DocumentUpload,ResponseOrder,RequiresDispositionCode,QuestionID,Create_When,Create_Who,Update_When,Update_Who,Unique_Key,RequireHRVerification",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMSetting",
    "PKColumns": "Unique_Key",
    "TableColumns": "SettingKey,SettingGroup,Text1,Text2,Text3,Text4,Text5,Num1,Num2,Num3,Date1,Date2,Date3,Decimal1,Decimal2,Decimal3,TextBlock,Unique_Key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMStaticCodes",
    "PKColumns": "StaticCodeListName,CodeValue",
    "TableColumns": "StaticCodeListName,CodeValue,CodeDescription,Create_When,Create_Who,Update_When,Update_Who,Unique_Key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMVerificationResponseHistory",
    "PKColumns": "VerificationResponseHistoryID",
    "TableColumns": "VerificationResponseHistoryID,ResponseTable,ResponseTableUniqueKey,ApplicationID,CommentType,Comments,CommentDate,Create_When,Create_Who,Unique_Key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AMWorkHistory",
    "PKColumns": "Unique_Key",
    "TableColumns": "ApplicationID,QuestionCategoryID,QuestionOrder,DocumentCount,DocumentLink,PostingID,Employer,BeginDate,EndDate,AnnualSalary,PartTime,JobDescription,LeaveReason,PositionHeld,Street,City,state,Zip,ZipExtension,PhoneNo,PhoneExtension,WorkHistoryNotes,Supervisor,WorkType,EmployerID,EmployerEmail,EEmployment,PEmployment,Verified,EmploymentComments,EmployerEmailReceived,EmployerEmailSent,WorkHistoryMisc1,WorkHistoryMisc2,WorkHistoryMisc3,WorkHistoryMisc4,HRVerifiedDate,HRVerifiedBy,HRExpirationDate,HRVerifyStatus,VerifyComments,Create_When,Create_Who,Update_When,Update_Who,Unique_Key,ExternalComments,ApplicantComments,DisplayComments",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "apacctappr",
    "PKColumns": "",
    "TableColumns": "trans_no,po_no,line_no,range_code,action_date,app_name,act,comment,payable_src,payable_id",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "apaprv",
    "PKColumns": "",
    "TableColumns": "trans_no,po_no,line_no,lvl,action_date,app_name,act,comment,payable_src,payable_id",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "app_certificate",
    "PKColumns": "",
    "TableColumns": "id,number,iss_date,exp_date,reg_date,c_type,c_area,primary_cert",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "app_def",
    "PKColumns": "",
    "TableColumns": "ln_type,indx,page_no,slabel,type_check,table_name,help_text,default_val,req,carryover,valid_if",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "app_degree",
    "PKColumns": "",
    "TableColumns": "id,dtype,highest,school,major,minor,deg_date,credits,gpa,user_1",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "app_misc",
    "PKColumns": "",
    "TableColumns": "id,job_no,responsib1,responsib2,responsib3,iss_state1,iss_state2,iss_state3,iss_state4,iss_state5,iss_state6,cc_license_no,cc_iss_state",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "app_races",
    "PKColumns": "",
    "TableColumns": "app_id,race_code,indx,race_order,race_prcnt",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "app_ref",
    "PKColumns": "",
    "TableColumns": "prefx,code,desc_x",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "app_reference",
    "PKColumns": "",
    "TableColumns": "id,ref1_f_name,ref1_l_name,ref1_addr1,ref1_addr2,ref1_city,ref1_state,ref1_zip,ref1_phone,ref1_fax,ref1_email,ref1_title,ref1_type,ref1_employer,ref2_f_name,ref2_l_name,ref2_addr1,ref2_addr2,ref2_city,ref2_state,ref2_zip,ref2_phone,ref2_fax,ref2_email,ref2_title,ref2_type,ref2_employer,ref3_f_name,ref3_l_name,ref3_addr1,ref3_addr2,ref3_city,ref3_state,ref3_zip,ref3_phone,ref3_fax,ref3_email,ref3_title,ref3_type,ref3_employer",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "app_supplement",
    "PKColumns": "",
    "TableColumns": "id,hdr_id,job_no,question,answer",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "applicant",
    "PKColumns": "",
    "TableColumns": "id,l_name,f_name,pres_addr1,pres_addr2,pres_city,pres_zip,pres_phone,perm_addr1,perm_addr2,perm_city,perm_zip,perm_phone,day_phone,birth_date,citizen,race,handicap,convict,marital,sex,eeo,eeo_group,maiden,ssn,vet_cd,hire_status,appl_date,renew_date,avail_date,active_empl,rehire,hire_date,part_time,home_orgn,base_loc,classify,hire_position,empl_no,category,rollover,teach_exp,admin_exp,couns_exp,yrs_district,yrs_state,yrs_total,skill1,skill2,skill3,skill4,skill5,ex_curr1,ex_curr2,ex_curr3,ex_curr4,ex_curr5,ex_curr6,event_date1,interviewer1,rating1,event_date2,interviewer2,rating2,event_date3,interviewer3,rating3,event_date4,interviewer4,rating4,event_date5,interviewer5,rating5,addn_comment1,addn_comment2,addn_comment3,addn_comment4,addn_comment5,addn_comment6,addn_comment7,addn_comment8,pres_state,perm_state,eeo_func,viewable,m_name,name_suffix,ethnic_code",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "appracct",
    "PKColumns": "",
    "TableColumns": "range_code,description,rlow_acct,rhigh_acct,rapprover,ralternate,ralternate2,plow_acct,phigh_acct,papprover,palternate,palternate2,apapprover,apalternate,apalternate2,aplow_acct,aphigh_acct,budapprover,budalternate,budalternate2,budlow_acct,budhigh_acct,chgapprover,chgalternate,chgalternate2,chglow_acct,chghigh_acct",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "apprdetl",
    "PKColumns": "",
    "TableColumns": "app_group,lvl,rapprover,ralternate,ralternate2,rrequired,rlow_amt,rhigh_amt,papprover,palternate,palternate2,prequired,plow_amt,phigh_amt,vrequired,apapprover,apalternate,apalternate2,aprequired,aplow_amt,aphigh_amt,budapprover,budalternate,budalternate2,budrequired,budlow_amt,budhigh_amt,chgapprover,chgalternate,chgalternate2,chgrequired,chglow_amt,chghigh_amt",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "approval",
    "PKColumns": "",
    "TableColumns": "app_group,description,app_chgord,notify_app,notify_req,notify_alt",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "appuser",
    "PKColumns": "",
    "TableColumns": "app_id,page_no,ftext1,ftext2,ftext3,ftext4,ftext5,ftext6,ftext7,ftext8,ftext9,ftext10,tcode1,tcode2,tcode3,tcode4,tcode5,tcode6,tcode7,tcode8,tcode9,tcode10,comment1,comment2",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "asntable",
    "PKColumns": "",
    "TableColumns": "code,desc_x,eeo,state_assign_num,hq_area,core_flag,fin_field1,fin_field2,fin_field3,fin_field4,fin_field5,user_1",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AspNetRoles",
    "PKColumns": "Id",
    "TableColumns": "Id,Name,NormalizedName,ConcurrencyStamp",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AspNetUserClaims",
    "PKColumns": "Id",
    "TableColumns": "Id,UserId,ClaimType,ClaimValue",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AspNetUserRoles",
    "PKColumns": "UserId,RoleId",
    "TableColumns": "UserId,RoleId,ApplicationRoleId",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "AspNetUsers",
    "PKColumns": "Id",
    "TableColumns": "Id,UserName,NormalizedUserName,Email,NormalizedEmail,EmailConfirmed,PasswordHash,SecurityStamp,ConcurrencyStamp,PhoneNumber,PhoneNumberConfirmed,TwoFactorEnabled,LockoutEnd,LockoutEnabled,AccessFailedCount,CreationDate,LastLogin,FirstName,LastName,JobTitle,IsActive,UserFax,ChangePassword",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "asset_fund_if",
    "PKColumns": "",
    "TableColumns": "assetid,improvement_num,des,dept,catcode,cat_class,accdep,initcost,post_flag",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "assetif",
    "PKColumns": "rec_no",
    "TableColumns": "acqdate,des,vendor,dept,po_no,line_no,unitsx,unitcost,initcost,recvd,commodity,check_no,rec_no,vend_no,invoice",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "assets",
    "PKColumns": "",
    "TableColumns": "tagno,improvement_num,acqdate,des,fund_source,vendor,insurer,mfr,model,serial_no,dept,loccode,grantx,catcode,cat_class,cond,po,checkno,unitsx,unitcost,initcost,salvage,insvalue,sale_amt,accdep,estlife,deplife,post_togl,invent,maint,retdate,stats,user_1,user_2,user_3,user_4,user_5,dep_flag,dep_method,curdep,depdate,dep_basis,last_post_date,prop_fund,cap_asset",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "assign_tbl",
    "PKColumns": "tbl_name",
    "TableColumns": "tbl_name,nxt_num",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "assignment",
    "PKColumns": "empl_no,indx",
    "TableColumns": "empl_no,asncode,perc_time,period,location,primary_asn,class_cd,position,hqarea,hqreason,num_classes,fin_field1,fin_field2,fin_field3,fin_field4,fin_field5,user_1,user_2,user_3,user_4,user_5,user_6,user_7,user_8,user_9,gradepk,gradekg,grade01,grade02,grade03,grade04,grade05,grade06,grade07,grade08,grade09,grade10,grade11,grade12,sif_job_class,sif_program_type,sif_funding_source,grade13,grade14,grade15,grade16,grade17,grade18,grade19,grade20,grade21,grade22,grade23,grade24,grade25,indx",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "assoc_approvers",
    "PKColumns": "association_id,approver_emp_id",
    "TableColumns": "association_id,approver_emp_id,approval_level,created_date,created_by,modified_by",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "assoc_rulegroups",
    "PKColumns": "association_id,rulegroup_id",
    "TableColumns": "association_id,rulegroup_id,created_date,created_by,modified_by",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "assoc_workflow",
    "PKColumns": "association_id",
    "TableColumns": "association_id,association_name,workflow_type,workflow_task,created_date,created_by,modified_by",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "at_permissions",
    "PKColumns": "",
    "TableColumns": "spiuser,access_time,at_flag",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "attach_detail",
    "PKColumns": "row_id",
    "TableColumns": "row_id,form_name,column_name,field_name,field_type,notes",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "attach_master",
    "PKColumns": "form_name",
    "TableColumns": "form_name,table_name,notes",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "attend",
    "PKColumns": "row_id",
    "TableColumns": "empl_no,pay_code,start_date,stop_date,lv_hrs,remarks,check_date,status_flg,lv_code,pay_run,post_flg,sub_id,sub_pay_code,sub_pay_class,sub_pay_rate,sub_amt_paid,sub_loc,sub_tax_ind,sub_orgn,sub_acct,cal_val,row_id,sub_start,sub_stop,sub_hrs,dataset_instance_id",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "audit1099",
    "PKColumns": "",
    "TableColumns": "userid,change_date,change_time,change_type,tax_yr,vend_no,field_changed,orig_data,new_data,form_1099,alt_vend_no,row_id",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "audit1099r",
    "PKColumns": "",
    "TableColumns": "userid,change_date,change_type,taxyr,employee,field_changed,orig_data,new_data",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "audittrails",
    "PKColumns": "id",
    "TableColumns": "id,affected_columns,create_datetime,newvalues,oldvalues,primarykey,type,userid,tablename",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "auto_check_no",
    "PKColumns": "",
    "TableColumns": "bankacct,doc_type,prefix,next_num",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "auto_num",
    "PKColumns": "",
    "TableColumns": "num_code,description,next_num",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "b_app_certificate",
    "PKColumns": "",
    "TableColumns": "id,number1,iss_state1,iss_date1,exp_date1,reg_date1,c_type1,c_area1,number2,iss_state2,iss_date2,exp_date2,reg_date2,c_type2,c_area2,number3,iss_state3,iss_date3,exp_date3,reg_date3,c_type3,c_area3,number4,iss_state4,iss_date4,exp_date4,reg_date4,c_type4,c_area4,number5,iss_state5,iss_date5,exp_date5,reg_date5,c_type5,c_area5,number6,iss_state6,iss_date6,exp_date6,reg_date6,c_type6,c_area6",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "b_app_degree",
    "PKColumns": "",
    "TableColumns": "id,dtype1,highest1,school1,major1,minor1,deg_date1,credits1,gpa1,otherschool1,otherdegree1,othermajor1,otherminor1,dtype2,highest2,school2,major2,minor2,deg_date2,credits2,gpa2,otherschool2,otherdegree2,othermajor2,otherminor2,dtype3,highest3,school3,major3,minor3,deg_date3,credits3,gpa3,otherschool3,otherdegree3,othermajor3,otherminor3",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "b_applicant",
    "PKColumns": "",
    "TableColumns": "id,l_name,f_name,pres_addr1,pres_addr2,pres_city,pres_zip,pres_phone,perm_addr1,perm_addr2,perm_city,perm_zip,perm_phone,day_phone,birth_date,citizen,race,handicap,convict,marital,sex,eeo,eeo_group,maiden,ssn,vet_cd,hire_status,appl_date,renew_date,avail_date,active_empl,rehire,hire_date,part_time,home_orgn,base_loc,classify,hire_position,empl_no,category,rollover,teach_exp,admin_exp,couns_exp,yrs_district,yrs_state,yrs_total,skill1,skill2,skill3,skill4,skill5,ex_curr1,ex_curr2,ex_curr3,ex_curr4,ex_curr5,ex_curr6,event_date1,interviewer1,rating1,event_date2,interviewer2,rating2,event_date3,interviewer3,rating3,event_date4,interviewer4,rating4,event_date5,interviewer5,rating5,addn_comment1,addn_comment2,addn_comment3,addn_comment4,addn_comment5,addn_comment6,addn_comment7,addn_comment8,pres_state,perm_state,eeo_func,viewable",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "b_asset",
    "PKColumns": "",
    "TableColumns": "batch_no,asset_id,improvement_num,locn,dept,catcode,status,entered_by",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "b_enr_contben",
    "PKColumns": "",
    "TableColumns": "eff_date,empl_no,ben_code,cont_info,enrollment_type,yr,posted",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "b_posnpref",
    "PKColumns": "",
    "TableColumns": "id,job_id",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "b_prevposn",
    "PKColumns": "",
    "TableColumns": "id,posn1,employer1,addr11,addr21,refer_ence1,phone1,start_date1,end_date1,st_salary1,end_salary1,leave_reason1,posn2,employer2,addr12,addr22,refer_ence2,phone2,start_date2,end_date2,st_salary2,end_salary2,leave_reason2,posn3,employer3,addr13,addr23,refer_ence3,phone3,start_date3,end_date3,st_salary3,end_salary3,leave_reason3",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "backord",
    "PKColumns": "",
    "TableColumns": "locn,ship_code,stock_no,req_no,req_line_no,quantity,trans_date,key_orgn,account,proj,proj_acct,person,remarks",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "backup_checksum",
    "PKColumns": "",
    "TableColumns": "tablename,package,rowarchive,timestamp",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "backup_log",
    "PKColumns": "",
    "TableColumns": "backupid,package,optype,username,requestdate,requesttime,tablecount,status",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bank_layout",
    "PKColumns": "",
    "TableColumns": "layout_cd,description,rec_type,file_pos,delimit,fld_name,fld_format,literal,pos_start,pos_stop,fld_length,batch_rec,cnt_sum,cnt_rec1,cnt_rec2,cnt_rec3,cnt_rec4,cnt_rec5,cnt_rec6,incl_decimal",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bankacct",
    "PKColumns": "",
    "TableColumns": "bankacct,key_orgn,account,feeflag,intflag",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bartable",
    "PKColumns": "",
    "TableColumns": "code,desc_x",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "batchpay",
    "PKColumns": "",
    "TableColumns": "classify,pos,empl_no,start_date,fte,yr",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bb_audit",
    "PKColumns": "",
    "TableColumns": "trans_no,chg_field,old_value,new_value,user_id,chg_date,chg_time",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bb_email",
    "PKColumns": "",
    "TableColumns": "email_addr,email_name,trans_no,order_id,req_no,email_msg,msg_date,msg_time",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bb_employee",
    "PKColumns": "",
    "TableColumns": "empl_no,link_empl_no",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bb_erp_orders",
    "PKColumns": "",
    "TableColumns": "trans_no,erp_check_out_id,erp_order_id,vendor_id,vendor_notes,requested_delivery,shopper_name,user_id,part_number,man_part_number,quantity,uom,unit_cost,description,ship_flag,ship_amt,org_id,account_id,approval_code,ship_to_code,commodity,edit_flag",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bb_notify",
    "PKColumns": "",
    "TableColumns": "location,email_addr,notify_name,notify_code",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bb_profile",
    "PKColumns": "",
    "TableColumns": "ship_flag,dist_flag,ship_percent,commod_flag,edit_flag,step1,step2,step3,default_email,default_name,phone_no,work_dir,bb_identity,shared_secret,billing_name,billing_addr1,billing_addr2,billing_addr3,billing_city,billing_state,billing_zip,bb_receiver,bb_user_id,bb_password",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bb_runtbl",
    "PKColumns": "",
    "TableColumns": "procname,runtime,userid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bb_transact",
    "PKColumns": "",
    "TableColumns": "trans_no,trans_date,trans_time,bb_check_out_id,bb_order_id,bb_user_id,bb_vend_id,bb_unit_cost,bb_quantity,bb_line_total,bb_uom,bb_part_number,bb_man_part_number,bb_ship_flag,bb_shipping_amt,bb_change_flag,spi_req_no,spi_req_line_no,spi_po_no,spi_po_line_no,spi_empl_no,spi_vend_no,spi_key_orgn,spi_account,spi_commodity,spi_status_flag,spi_error_flag,spi_sent_cnt",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bbenefici",
    "PKColumns": "",
    "TableColumns": "eff_date,empl_no,ben_code,d_ssn,b_ssn,l_name,f_name,bb_date,percnt,relation,enroll_flg,post_flg,operator,date_chg",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bbenefits",
    "PKColumns": "",
    "TableColumns": "eff_date,empl_no,d_ssn,ben_code,start_date,stop_date,notify_code,notify_date,coverage,ben_cost,other_ins,cov_level,cobra,enroll_flg,post_flg,operator,date_chg",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bchgstat",
    "PKColumns": "",
    "TableColumns": "eff_date,empl_no,status,post_flg",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bdedtable",
    "PKColumns": "ded_cd",
    "TableColumns": "batch_no,eff_date,ded_cd,title,ck_title,freq,arrears,emp_meth,rate,low_max,mid_rate,mid_max,high_rate,with_acct,frng_meth,frng_rate,frng_acct,fed_exp,sta_exp,fic_exp,loc_exp,fed_fexp,sta_fexp,fic_fexp,loc_fexp,max_meth,vend_no,vend_pay_freq,bond_flag,frng_dist,frng_orgn,frng_proj,max_ded,max_ben,caf_flag,encumber,enc_num_times,enc_remaining,use_gross_field,eac_whatif,mandatory_flag,child_sup_flag,copy_bank_info,calc_pr_add_with",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bdeduct",
    "PKColumns": "empl_no,ded_cd,enroll_flg",
    "TableColumns": "eff_date,empl_no,ded_cd,status,account,start_x,stop_x,beff_date,ded_amt,cont_amt,num_deds,max_amt,max_fringe,arrears,chk_ind,bank,bt_code,bank_acct,enroll_flg,post_flg,operator,date_chg,addl_ded_gross,addl_frng_gross,desc_x,bank_code",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bdemo",
    "PKColumns": "empl_no",
    "TableColumns": "eff_date,empl_no,ssn,l_name,f_name,addr1,addr2,city,zip,hire_date,home_orgn,birthdate,base_loc,state_id,orig_hire,prev_lname,email_addr,info_rlease,home_phone,work_phone,emer_cont,emer_phone,phys_name,phys_phone,spouse_name,spouse_phone,post_flg,operator,date_chg,email_voucher,personal_email,cell_phone,other_phone,emer_cell_phone,m_name,name_suffix,preferred_name,gender_identity,ethnicity",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bdependent",
    "PKColumns": "",
    "TableColumns": "eff_date,empl_no,d_ssn,l_name,f_name,addr_1,addr_2,zip,b_date,relation,sex,stat,post_flg,operator,date_chg",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bdist_orgn",
    "PKColumns": "",
    "TableColumns": "empl_no,rate_no,classify,pos,orgn,acct,prcent",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bdist_proj",
    "PKColumns": "",
    "TableColumns": "empl_no,rate_no,classify,pos,proj,acct,prcent",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bemp_course_costs",
    "PKColumns": "unique_key",
    "TableColumns": "eff_date,empl_no,course_key,cost_type_cd,cost_amt,post_flag,create_who,create_when,update_who,update_when,unique_id,unique_key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bemp_course_cred",
    "PKColumns": "unique_key",
    "TableColumns": "eff_date,empl_no,course_key,credit_cd,credits,credit_inst,credit_dt,post_flag,create_who,create_when,update_who,update_when,unique_id,unique_key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bemp_course_dtl",
    "PKColumns": "unique_key",
    "TableColumns": "eff_date,empl_no,course_type_cd,course_title,course_no,status,start_date,completion_date,expiration_date,internal,provider,seat_hrs,instructor_name,grade,fiscal_year,reimbursement_amt,reimbursement_date,notes,cert_code,post_flag,create_who,create_when,update_who,update_when,unique_id,unique_key,term_cd",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bemp_course_goal",
    "PKColumns": "unique_key",
    "TableColumns": "eff_date,empl_no,course_key,goal_cd,goal_comm,post_flag,create_who,create_when,update_who,update_when,unique_id,unique_key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bemp_course_misc",
    "PKColumns": "unique_key",
    "TableColumns": "eff_date,empl_no,course_key,misc_cd_order,misc_code_val,post_flag,create_who,create_when,update_who,update_when,unique_id,unique_key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bemp_course_topic",
    "PKColumns": "unique_key",
    "TableColumns": "eff_date,empl_no,course_key,area_cd,post_flag,create_who,create_when,update_who,update_when,unique_id,unique_key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bempact",
    "PKColumns": "",
    "TableColumns": "empl_no,date_chg,table_name,field_name,old_value,new_value,operator,pay_ded_code,pay_ded_desc,time_chg",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bempl_races",
    "PKColumns": "",
    "TableColumns": "empl_no,race_code,indx,race_order,race_prcnt",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ben_benefici",
    "PKColumns": "",
    "TableColumns": "row_id,empl_no,b_ssn,ben_code",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ben_benefits",
    "PKColumns": "",
    "TableColumns": "empl_no,ssn,start_date,ben_code,offer_code,safe_harbor",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ben_chrg_override",
    "PKColumns": "row_id",
    "TableColumns": "row_id,fund_bud_flag,yr,priority,ded_cd,empl_no,salary_orgn,salary_acct,charge_orgn,charge_acct",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ben_deduct",
    "PKColumns": "",
    "TableColumns": "ded_cd,sub1,sub2,ben_type,part_time,ded_inactive",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ben_dependent",
    "PKColumns": "",
    "TableColumns": "row_id,empl_no,d_ssn,real_ssn,active",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ben_emplinfo",
    "PKColumns": "",
    "TableColumns": "empl_no,depend_cnt",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "benclass",
    "PKColumns": "",
    "TableColumns": "ben_type,classify",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "benefici",
    "PKColumns": "",
    "TableColumns": "empl_no,ben_code,d_ssn,b_ssn,l_name,f_name,bb_date,percnt,relation",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "beneficiorg",
    "PKColumns": "",
    "TableColumns": "empl_no,ben_code,d_ssn,b_ssn,l_name,f_name,bb_date,percnt,relation",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "benefits",
    "PKColumns": "",
    "TableColumns": "empl_no,d_ssn,ben_code,start_date,stop_date,notify_code,notify_date,coverage,ben_cost,other_ins,cov_level,cobra",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "benefitsorg",
    "PKColumns": "",
    "TableColumns": "empl_no,d_ssn,ben_code,start_date,stop_date,notify_code,notify_date,coverage,ben_cost,other_ins,cov_level,cobra",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bentable",
    "PKColumns": "",
    "TableColumns": "ben_code,description,req_bene,group_no,policy_no,cobra_cost",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bentype_tb",
    "PKColumns": "",
    "TableColumns": "ben_type,title,flex_flg,min_amt,max_amt,no_deds,beff_date,priority",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bexpledgr",
    "PKColumns": "",
    "TableColumns": "yr,key_orgn,account,budget_orgn,budget_acct,freeze,bud3,act3,bud2,act2,bud1,act1,bud_curr,act_ytd,act_prop,dept_base,dept_new,rec_base,rec_new,app_base,app_new,year2,year3,year4,year5",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bfe2table",
    "PKColumns": "",
    "TableColumns": "batch_no,eff_date,pay_freq,marital,ear,amt,per,with_rate_sched_cd",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bfedtable",
    "PKColumns": "",
    "TableColumns": "batch_no,eff_date,pay_freq,marital,account,depend,supp_per,with_rate_sched_cd,pays_per_year,nonres_alien_adj1,nonres_alien_adj2,std_allowance",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bfictable",
    "PKColumns": "",
    "TableColumns": "batch_no,eff_date,fic_med,emp_per,emp_max,empr_per,empr_max,lia_acct,frg_acct,frng_dist,frng_orgn,encumber",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bid_class",
    "PKColumns": "",
    "TableColumns": "yr,bid_no,comm_cls",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bid_detl",
    "PKColumns": "",
    "TableColumns": "bid_no,line_no,cstatus,commodity,measure,quanity,vend_no,yr",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bid_hdr",
    "PKColumns": "",
    "TableColumns": "bid_no,bid_desc,bid_status,bid_date,bid_type,yr,close_reqs",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bid_preenc",
    "PKColumns": "",
    "TableColumns": "yr,key_orgn,account,preenc_amt",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bid_price",
    "PKColumns": "",
    "TableColumns": "commodity,last_price",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bid_template",
    "PKColumns": "",
    "TableColumns": "yr,bid_no,commodity,est_price",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bidchrg",
    "PKColumns": "",
    "TableColumns": "bid_no,commodity,key_orgn,account,proj,proj_acct,quanity,location,yr,price,requester,operator,chg_date,po_no,po_line",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bidtype",
    "PKColumns": "",
    "TableColumns": "code,description",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bk_adv_pay",
    "PKColumns": "",
    "TableColumns": "empl_no,classify,last_run,check_no,num_adv",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bk_assoc_approvers",
    "PKColumns": "association_id,approver_emp_id",
    "TableColumns": "association_id,approver_emp_id,approval_level,created_date,created_by,modified_by",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bk_assoc_rulegroup",
    "PKColumns": "association_id,rulegroup_id",
    "TableColumns": "association_id,rulegroup_id,created_date,created_by,modified_by",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bk_assoc_workflow",
    "PKColumns": "association_id",
    "TableColumns": "association_id,association_name,workflow_type,workflow_task,created_date,created_by,modified_by",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bk_attend",
    "PKColumns": "",
    "TableColumns": "empl_no,pay_code,start_date,stop_date,lv_hrs,remarks,check_date,status_flg,lv_code,pay_run,post_flg,sub_id,sub_pay_code,sub_pay_class,sub_pay_rate,sub_amt_paid,sub_loc,sub_tax_ind,sub_orgn,sub_acct,cal_val,row_id,sub_start,sub_stop,sub_hrs,dataset_instance_id",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bk_dedaddend",
    "PKColumns": "",
    "TableColumns": "empl_no,ded_cd,rec_no,case_no,order_date,amount,medical,fips_cd,terminated,arrears,notes",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bk_dedtable",
    "PKColumns": "",
    "TableColumns": "ded_cd,title,ck_title,freq,arrears,emp_meth,rate,low_max,mid_rate,mid_max,high_rate,with_acct,frng_meth,frng_rate,frng_acct,frng_dist,frng_orgn,frng_proj,fed_exp,sta_exp,fic_exp,loc_exp,fed_fexp,sta_fexp,fic_fexp,loc_fexp,max_meth,vend_no,vend_pay_freq,bond_flag,max_ded,max_ben,caf_flag,encumber,enc_num_times,enc_remaining,use_gross_field,eac_whatif,mandatory_flag,child_sup_flag,copy_bank_info,calc_pr_add_with",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bk_deduct",
    "PKColumns": "",
    "TableColumns": "empl_no,ded_cd,status,account,start_x,stop_x,beff_date,ded_amt,max_amt,max_fringe,arrears,cont_amt,num_deds,chk_ind,taken_c,taken_m,taken_q,taken_y,taken_i,taken_f,cont_c,cont_m,cont_q,cont_y,cont_i,cont_f,sal_c,sal_m,sal_q,sal_y,sal_f,bank,bt_code,bank_acct,enc_remaining,addl_ded_gross,addl_frng_gross",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bk_empuser",
    "PKColumns": "",
    "TableColumns": "empl_no,page_no,ftext1,ftext2,ftext3,ftext4,ftext5,ftext6,ftext7,ftext8,ftext9,ftext10,tcode1,tcode2,tcode3,tcode4,tcode5,tcode6,tcode7,tcode8,tcode9,tcode10,comment1,comment2",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bk_menu_applications",
    "PKColumns": "app_id",
    "TableColumns": "app_id,title,package,subpackage,func,spi_defined",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bk_menu_groups",
    "PKColumns": "app_id,tab_id,group_id",
    "TableColumns": "app_id,tab_id,group_id,title,package,subpackage,func,spi_defined",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bk_menu_options",
    "PKColumns": "app_id,tab_id,group_id,option_id",
    "TableColumns": "app_id,tab_id,group_id,option_id,title,progcall,callpath,package,subpackage,func,is_fglrun,is_sub_system,spi_defined",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bk_menu_tabs",
    "PKColumns": "tab_id",
    "TableColumns": "tab_id,title,package,subpackage,func,spi_defined",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bk_pay2file",
    "PKColumns": "",
    "TableColumns": "empl_no,ssn,l_name,f_name,chk_locn,addr1,addr2,addr3,zip,home_orgn,voucher,end_date,start_date,m_name,name_suffix",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bk_payaddend",
    "PKColumns": "",
    "TableColumns": "empl_no,ded_cd,rec_no,batch,pay_run,end_date,run_type,due_date,case_no,amount,medical,fips_cd,terminated,row_id,trans_no",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bk_paycode",
    "PKColumns": "",
    "TableColumns": "empl_no,pay_code,p_amt,p_hours,mtd_amt,mtd_hours,qtd_amt,ytd_amt,cal_cycle_units,cal_cycle_amt",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bk_payfile",
    "PKColumns": "",
    "TableColumns": "empl_no,home_orgn,pdf,code,amount,fringe,orgn,proj,acct,pacct,arrears,check_no,hours,classify,dedgross,frngross,tax_ind,bank,bt_code,bank_acct,pay_cycle,chk_ind,flsa_flg,payrate",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bk_paygroups",
    "PKColumns": "",
    "TableColumns": "group_x,def_hours,pay_run,end_date,cur_run,run_desc,proc_sumfisc,start_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bk_payrate",
    "PKColumns": "",
    "TableColumns": "empl_no,rate_no,primry,group_x,pay_hours,days_worked,hours_day,incl_dock,no_pays,fte,pay_method,pay_cycle,pay_cd,classify,occupied,cal_type,range,step_x,rate,dock_rate,cont_flg,cont_days,override,annl_sal,cont_lim,cont_bal,cont_paid,cont_start,cont_end,pay_start,pay_end,summer_pay,status_x,pyo_date,pyo_rem_pay,pyo_days,pyo_rate,pyo_amt,dock_arrears_amt,dock_pays_remain",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bk_payroll",
    "PKColumns": "",
    "TableColumns": "empl_no,pay_freq,card_requ,sp1_amt,sp1_cd,sp2_amt,sp2_cd,sp3_amt,sp3_cd,chk_locn,last_paid,fed_exempt,fed_marital,fed_dep,add_fed,sta_exempt,state_id,pr_state,sta_marital,sta_dep,add_state,loc_exempt,locl,pr_local,loc_marital,loc_dep,add_local,fic_exempt,earn_inc,lv_date,lv1_cd,lv1_bal,lv1_tak,lv1_ear,lv2_cd,lv2_bal,lv2_tak,lv2_ear,lv3_cd,lv3_bal,lv3_tak,lv3_ear,lv4_cd,lv4_bal,lv4_tak,lv4_ear,lv5_cd,lv5_bal,lv5_tak,lv5_ear,lv6_cd,lv6_bal,lv6_tak,lv6_ear,lv7_cd,lv7_bal,lv7_tak,lv7_ear,lv8_cd,lv8_bal,lv8_tak,lv8_ear,lv9_cd,lv9_bal,lv9_tak,lv9_ear,lv10_cd,lv10_bal,lv10_tak,lv10_ear,tearn_c,tearn_m,tearn_q,tearn_y,tearn_ft,ftearn_c,ftearn_m,ftearn_q,ftearn_y,ftearn_ft,fiearn_c,fiearn_m,fiearn_q,fiearn_y,fiearn_ft,mdearn_c,mdearn_m,mdearn_q,mdearn_y,mdearn_ft,stearn_c,stearn_m,stearn_q,stearn_y,stearn_ft,s2earn_c,s2earn_m,l2earn_y,s2earn_y,s2earn_ft,loearn_c,loearn_m,loearn_q,loearn_y,loearn_ft,allow_c,allow_m,allow_q,allow_y,allow_ft,nocash_c,nocash_m,nocash_q,nocash_y,nocash_ft,fedtax_c,fedtax_m,fedtax_q,fedtax_y,fedtax_ft,fictax_c,fictax_m,fictax_q,fictax_y,fictax_ft,medtax_c,medtax_m,medtax_q,medtax_y,medtax_ft,statax_c,statax_m,statax_q,statax_y,statax_ft,st2tax_c,st2tax_m,lt2tax_y,st2tax_y,st2tax_ft,loctax_c,loctax_m,loctax_q,loctax_y,loctax_ft,eic_c,eic_m,eic_q,eic_y,eic_ft,rfiearn_y,rfictax_y,rmdearn_y,rmedtax_y,flsa_cycle_y,flsa_cycle_hrs,flsa_hours,flsa_amount,rfiearn_c,rfiearn_m,rfiearn_q,rfiearn_ft,rfictax_c,rfictax_m,rfictax_q,rfictax_ft,rmdearn_c,rmdearn_m,rmdearn_q,rmdearn_ft,rmedtax_c,rmedtax_m,rmedtax_q,rmedtax_ft,fed_tax_calc_cd,w4_sub_date,non_res_alien,ann_other_inc,ann_deductions,ann_tax_credit,pays_per_year",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bk_position",
    "PKColumns": "",
    "TableColumns": "classify,pos,auth_fte,fill_fte,fte,locn,text1,text2,bsalary,asalary,psalary,yr",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bk_posn_data2",
    "PKColumns": "",
    "TableColumns": "yr,classify,pos,description,posn_days,posn_fte_open,bargain",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bk_posn_data3",
    "PKColumns": "",
    "TableColumns": "yr,classify,pos,job_type,job_descript,posting_fte,pend_transfer_fte",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bk_predist",
    "PKColumns": "",
    "TableColumns": "empl_no,orgn,account,amt,pay_cd,classify,hours,pay_run",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bk_rule_definition",
    "PKColumns": "rule_id",
    "TableColumns": "rule_id,area,field_name,operator,comparison_value,ending_value,exclude,grouping,notes,rulegroup_id,sequence,created_date,created_by,modified_by",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bk_rule_group",
    "PKColumns": "rulegroup_id",
    "TableColumns": "rulegroup_id,rulegroup_name,notes,created_date,created_by,modified_by",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bk_sumdetdist",
    "PKColumns": "",
    "TableColumns": "yr,empl_no,pay_run,check_no,classify,rec_type,code,orgn,acct,fund,liab_acct,amount",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bk_sumfiscdist",
    "PKColumns": "",
    "TableColumns": "yr,empl_no,classify,rec_type,code,orgn,acct,fund,liab_acct,accr_amt,liq_amt,bal_amt,accr_status,load_date,load_user,post_date,post_user,delete_date,delete_user,complete_date,complete_user,orig_sal_orgn,orig_sal_acct,prim_sal_orgn,prim_sal_acct",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bk_task_cond_val",
    "PKColumns": "",
    "TableColumns": "row_id,condition_id,condition_value",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bk_task_condition",
    "PKColumns": "",
    "TableColumns": "row_id,task_id,table_name,column_name",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bk_task_table",
    "PKColumns": "",
    "TableColumns": "task_id,task_name,spi_defined,workflow_type",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bk_timecard",
    "PKColumns": "",
    "TableColumns": "empl_no,pay_code,hours,payrate,amount,orgn,account,proj,pacct,classify,pay_cycle,tax_ind,pay_run,subtrack_id,reported,user_chg,date_chg,flsa_cycle,flsa_flg,flsa_carry_ovr,ret_pers_code,loctaxcd",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bk_wkrdept",
    "PKColumns": "",
    "TableColumns": "work_cd,orgn,reg_sal,ot_sal",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bk_wkrtable",
    "PKColumns": "",
    "TableColumns": "work_cd,title,rate,reg_sal,ot_sal,with_acct,fringe_acct,encumber",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bkup_assoc_apprvrs",
    "PKColumns": "",
    "TableColumns": "association_id,approver_emp_id,approval_level,created_date,created_by,modified_by,copied_by,copied_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bkup_assoc_rulegrp",
    "PKColumns": "",
    "TableColumns": "association_id,rulegroup_id,created_date,created_by,modified_by,copied_by,copied_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bkup_assoc_wkf",
    "PKColumns": "",
    "TableColumns": "association_id,association_name,workflow_type,workflow_task,created_date,created_by,modified_by,copied_by,copied_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bkup_rule_def",
    "PKColumns": "",
    "TableColumns": "rule_id,area,field_name,operator,comparison_value,ending_value,exclude,grouping,notes,rulegroup_id,sequence,created_date,created_by,modified_by,copied_by,copied_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bkup_rule_group",
    "PKColumns": "",
    "TableColumns": "rulegroup_id,rulegroup_name,notes,created_date,created_by,modified_by,copied_by,copied_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bkup_task_cond",
    "PKColumns": "",
    "TableColumns": "row_id,task_id,table_name,column_name,copied_by,copied_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bkup_task_cond_val",
    "PKColumns": "",
    "TableColumns": "row_id,condition_id,condition_value,copied_by,copied_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bkup_task_table",
    "PKColumns": "",
    "TableColumns": "task_id,task_name,spi_defined,workflow_type,copied_by,copied_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "blo2table",
    "PKColumns": "",
    "TableColumns": "batch_no,eff_date,location,pay_freq,marital,ear,amt,per",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "blo3table",
    "PKColumns": "",
    "TableColumns": "batch_no,eff_date,location,pay_freq,marital,cred",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bloctable",
    "PKColumns": "",
    "TableColumns": "batch_no,eff_date,location,description,pay_freq,marital,account,stan_rate,stan_min,stan_max,mar_exemp,depend,supp_per",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bnk_fld_name",
    "PKColumns": "",
    "TableColumns": "fld_code,description,tabl,col",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bnktable",
    "PKColumns": "",
    "TableColumns": "code,desc_x,ck_title,bank_code",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bond",
    "PKColumns": "",
    "TableColumns": "bond_no,description,maturity_dte,int_rate,payment_cyc,pay_amt,term,denomination,issue_dte,iss_purpose,auth_dte,resolution,page_no,book_no,sale_dte,sale_amt,premium,discount,accd_sold,payee_no,status,mat_bal",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bondinfo",
    "PKColumns": "",
    "TableColumns": "empl_no,ded_cd,lname,fname,addr1,addr2,addr3,zip,ssn,bond_amt,co_own_flg,co_own_name",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bpayrate",
    "PKColumns": "",
    "TableColumns": "eff_date,empl_no,classify,pay_cd,cal_type,cont_flg,cont_start,cont_end,pay_method,range,step_x,group_x,pay_hours,days_worked,hours_day,incl_dock,no_pays,fte,override,rate,dock_rate,annl_sal,cont_days,cont_lim,post_flg,dock_arrears_amt,dock_pays_remain",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bpctl_orgn",
    "PKColumns": "",
    "TableColumns": "classify,pos,orgn,acct,prcent,yr",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bpctl_proj",
    "PKColumns": "",
    "TableColumns": "classify,pos,proj,acct,prcent,yr",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bposition",
    "PKColumns": "",
    "TableColumns": "classify,pos,auth_fte,fill_fte,fte,locn,text1,text2,yr",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bposn_cert",
    "PKColumns": "",
    "TableColumns": "yr,classify,pos,cert_type,cert_area,cert_required",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bposn_data2",
    "PKColumns": "",
    "TableColumns": "yr,classify,pos,description,posn_days,posn_fte_open,bargain",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bposn_data3",
    "PKColumns": "",
    "TableColumns": "yr,classify,pos,job_type,job_descript",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bposn_qual",
    "PKColumns": "",
    "TableColumns": "yr,classify,pos,qual_code",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bposn_req",
    "PKColumns": "",
    "TableColumns": "yr,classify,pos,req_code",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bproj_title",
    "PKColumns": "",
    "TableColumns": "lvl,code,title",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bproledgr",
    "PKColumns": "",
    "TableColumns": "yr,key_orgn,account,freeze,bud3,act3,bud2,act2,bud1,act1,bud_curr,act_ytd,act_prop,dept_base,dept_new,rec_base,rec_new,app_base,app_new,year2,year3,year4,year5",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "brevledgr",
    "PKColumns": "",
    "TableColumns": "yr,key_orgn,account,freeze,bud3,act3,bud2,act2,bud1,act1,bud_curr,act_ytd,act_prop,dept_base,dept_new,rec_base,rec_new,app_base,app_new,year2,year3,year4,year5",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "brstable",
    "PKColumns": "",
    "TableColumns": "batch_no,eff_date,range,desc_x,step_1,pcnt_1,step_2,pcnt_2,step_3,pcnt_3,step_4,pcnt_4,step_5,pcnt_5,step_6,pcnt_6,step_7,pcnt_7,step_8,pcnt_8,step_9,pcnt_9,step_10,pcnt_10,step_11,pcnt_11,step_12,pcnt_12,step_13,pcnt_13,step_14,pcnt_14,step_15,pcnt_15,step_16,pcnt_16,step_17,pcnt_17,step_18,pcnt_18,step_19,pcnt_19,step_20,pcnt_20,step_21,pcnt_21,step_22,pcnt_22,step_23,pcnt_23,step_24,pcnt_24,step_25,pcnt_25,step_26,pcnt_26,step_27,pcnt_27,step_28,pcnt_28,step_29,pcnt_29,step_30,pcnt_30,step_31,pcnt_31,step_32,pcnt_32,step_33,pcnt_33,step_34,pcnt_34,step_35,pcnt_35,step_36,pcnt_36,step_37,pcnt_37,step_38,pcnt_38,step_39,pcnt_39,step_40,pcnt_40,step_41,pcnt_41,step_42,pcnt_42,step_43,pcnt_43,step_44,pcnt_44,step_45,pcnt_45,step_46,pcnt_46,step_47,pcnt_47,step_48,pcnt_48,step_49,pcnt_49,step_50,pcnt_50,step_51,pcnt_51,step_52,pcnt_52,step_53,pcnt_53,step_54,pcnt_54,step_55,pcnt_55,step_56,pcnt_56,step_57,pcnt_57,step_58,pcnt_58,step_59,pcnt_59,step_60,pcnt_60,step_61,pcnt_61,step_62,pcnt_62,step_63,pcnt_63,step_64,pcnt_64,step_65,pcnt_65,step_66,pcnt_66,step_67,pcnt_67,step_68,pcnt_68,step_69,pcnt_69,step_70,pcnt_70,step_71,pcnt_71,step_72,pcnt_72,step_73,pcnt_73,step_74,pcnt_74,step_75,pcnt_75,step_76,pcnt_76,step_77,pcnt_77,step_78,pcnt_78,step_79,pcnt_79,step_80,pcnt_80,step_81,pcnt_81,step_82,pcnt_82,step_83,pcnt_83,step_84,pcnt_84,step_85,pcnt_85,step_86,pcnt_86,step_87,pcnt_87,step_88,pcnt_88,step_89,pcnt_89,step_90,pcnt_90,step_91,pcnt_91,step_92,pcnt_92,step_93,pcnt_93,step_94,pcnt_94,step_95,pcnt_95,step_96,pcnt_96,step_97,pcnt_97,step_98,pcnt_98,step_99,pcnt_99",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bshdtable",
    "PKColumns": "",
    "TableColumns": "batch_no,eff_date,code,desc_x,hs_flag,max_step,num_ranges,days_worked,hours_day,bn_flag,state_hours_day",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bst2table",
    "PKColumns": "",
    "TableColumns": "batch_no,eff_date,state_id,pay_freq,marital,ear,amt,per",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bst3table",
    "PKColumns": "",
    "TableColumns": "batch_no,eff_date,state_id,pay_freq,marital,cred",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bsttable",
    "PKColumns": "",
    "TableColumns": "batch_no,eff_date,state_id,pay_freq,marital,account,stan_rate,stan_min,stan_max,mar_exemp,depend,supp_per",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "btaxinfo",
    "PKColumns": "empl_no",
    "TableColumns": "eff_date,empl_no,fed_exempt,fed_marital,fed_dep,add_fed,sta_exempt,sta_marital,sta_dep,state_id,add_state,loc_exempt,loc_marital,loc_dep,add_local,locl,earn_inc,post_flg,operator,date_chg,fed_tax_calc_cd,w4_sub_date,non_res_alien,ann_other_inc,ann_deductions,ann_tax_credit",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "btimecard",
    "PKColumns": "",
    "TableColumns": "empl_no,pay_code,card_date,hours,payrate,amount,orgn,account,proj,pacct,classify,pay_cycle,tax_ind,pay_run,load_date,load_user,post_flg,card_fyr,start_date,stop_date,lv_code,lv_hrs,remarks,check_date,status_flg,sub_id,sub_pay_code,sub_pay_class,sub_pay_rate,sub_amt_paid,sub_loc,sub_tax_ind,sub_orgn,sub_acct,cal_val,flsa_cycle,row_id",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "btrans_acct",
    "PKColumns": "",
    "TableColumns": "no_levels,orgn1b,orgn1e,orgn2b,orgn2e,orgn3b,orgn3e,orgn4b,orgn4e,orgn5b,orgn5e,orgn6b,orgn6e,orgn7b,orgn7e,orgn8b,orgn8e,orgn9b,orgn9e,orgn10b,orgn10e,acct1b,acct1e,acct2b,acct2e",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bubudacct",
    "PKColumns": "",
    "TableColumns": "yr,acct,sub_1_acct,sub_2_acct,sub_3_acct,title,pr_acct,pos,posit_per,curr_yr,dept_base,rec_base,yr2_per,yr3_per,yr4_per,yr5_per,month1,month2,month3,month4,month5,month6,month7,month8,month9,month10,month11,month12,month13,proll_flg,reqpur_flg,war_flg,local_use",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bubudorgn",
    "PKColumns": "",
    "TableColumns": "yr,key_orgn,lvl,fund,orgn1,orgn2,orgn3,orgn4,orgn5,orgn6,orgn7,orgn8,orgn9,title,enterprise,cash,budget,req_enc,disb_fund,total_rec,pr_orgn,curr_yr,dept_base,rec_base,yr2_per,yr3_per,yr4_per,yr5_per,proj_link,project,local_use",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bubudproj",
    "PKColumns": "",
    "TableColumns": "yr,key_proj,lvl,proj1,proj2,title,start_date,stop_date,funding,budget,closed,overhd1,overhd2,overhd3,overhd4,pr_proj,curr_yr,dept_base,rec_base,yr2_per,yr3_per,yr4_per,yr5_per,proj3,proj4,proj5,proj6,proj7,proj8",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bud_prof",
    "PKColumns": "",
    "TableColumns": "yr,sdate,edate,client,system,company,low_exp,hi_exp,low_rev,hi_rev,wbr,wpr,fund_title,orgn1_title,orgn2_title,orgn3_title,orgn4_title,orgn5_title,orgn6_title,orgn7_title,orgn8_title,orgn9_title,low_orgn,proj1_title,proj2_title,low_proj,e_full_acct,r_full_acct,proj3_title,proj4_title,proj5_title,proj6_title,proj7_title,proj8_title",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "budacctappr",
    "PKColumns": "",
    "TableColumns": "yr,period,key_orgn,account,batch,trn_no,trn_idx,type_flg,range_code,action_date,app_name,act,comment,trans_no",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "budactv",
    "PKColumns": "",
    "TableColumns": "empl_no,classify,pos,ded_cd,date_chg,table_name,field_name,old_value,new_value,operator",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "budaprv",
    "PKColumns": "",
    "TableColumns": "yr,period,key_orgn,account,batch,trn_no,trn_idx,type_flg,lvl,action_date,app_name,act,comment,trans_no",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "budaprvhist",
    "PKColumns": "",
    "TableColumns": "batch,yr,period,key_orgn,account,transfer_no,type_flg,chg_type,old_val,new_val,date_chg,time_chg,operator",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "buddist",
    "PKColumns": "",
    "TableColumns": "empl_no,classify,pos,rec_type,orgn_proj,acct,code,amount",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "budincr",
    "PKColumns": "",
    "TableColumns": "classify,eff_date,amt,prcent,c_b",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "budpayr",
    "PKColumns": "",
    "TableColumns": "classify,pos,freeze,empl_no,l_name,f_name,rate_no,primry,group_x,pay_hours,days_worked,hours_day,no_pays,fte,pay_method,pay_cd,cal_type,range,step_x,curr_rate,curr_sal,bud_dock,cont_flg,cont_days,override,cont_start,cont_end,summer_pay,sp1_cd,sp1_amt,sp2_cd,sp2_amt,sp3_cd,sp3_amt,prcnt_incr_a,amt_incr_a,bud_rate,bud_base,spec_base,incr_base,mdyr_incr_a,occupied,date_incr_a,date_incr_b,prcnt_incr_b,amt_incr_b,mdyr_incr_b,curr_date_a,curr_prcnt_a,curr_date_b,curr_prcnt_b",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "budposn",
    "PKColumns": "",
    "TableColumns": "yr,key_orgn,classify,account,title,curr_yr,dept_base,rec_base",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "budpost",
    "PKColumns": "",
    "TableColumns": "yr,key_orgn,classify,posn_no,typex,startdt,stopdt,bud_curr,act_ytd,act_prop,dept_base,dept_new,rec_base,rec_new,app_base,app_new",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bulk_sync_status",
    "PKColumns": "id",
    "TableColumns": "id,empl_no,empl_info_status,empl_leavebanks_status,process_tag",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "business_rule_entity",
    "PKColumns": "search_id,entity_type",
    "TableColumns": "search_id,entity_type,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "business_rule_hdr",
    "PKColumns": "search_id",
    "TableColumns": "search_id,search_type,rule_type,year,title,status,failure_message,if_grouping_mask,req_grouping_mask,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "business_rule_type",
    "PKColumns": "rule_type",
    "TableColumns": "rule_type,description,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "bvenclass",
    "PKColumns": "",
    "TableColumns": "vend_no,comm_cls",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "calendar",
    "PKColumns": "",
    "TableColumns": "cal_type,description,start_date,end_date,pay_start,pay_end,no_days",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "capital",
    "PKColumns": "",
    "TableColumns": "low_capital,hi_capital,min_value,max_value,cap_flag",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "cashbhis",
    "PKColumns": "",
    "TableColumns": "bond_no,h_date,h_type,check_no,ck_date,operator,vend_no,amount",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "cashbond",
    "PKColumns": "",
    "TableColumns": "bond_no,issued,bonddate,mindate,minrecv,case_no,defname,defadr1,defadr2,defcity,defstate,defzip,depname,depadr1,depadr2,depcity,depstate,depzip,defvend,depvend,asnvend,shfvend,othvend,user1,amount,balance",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "cashbpro",
    "PKColumns": "",
    "TableColumns": "title1,je_type,combine,bondfund,bondcash,bondliab,pstdrorgn,pstdracct,pstcrorgn,pstcracct,feedrorgn,feedracct,feecrorgn,feecracct,findrorgn,findracct,fincrorgn,fincracct,estdrorgn,estdracct,estcrorgn,estcracct",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "category",
    "PKColumns": "",
    "TableColumns": "catcode,cat_class,catdesc,accum_dep",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "cert_area",
    "PKColumns": "",
    "TableColumns": "code,desc_x,core_area",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "cert_type",
    "PKColumns": "",
    "TableColumns": "code,desc_x",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "chart_type",
    "PKColumns": "",
    "TableColumns": "chart_type,filename",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "check_ded",
    "PKColumns": "",
    "TableColumns": "empl_no,check_no,ded_cd,taken_y,taken_f,taken_i,cont_y,cont_f,cont_i,bank,bt_code",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "check_leave",
    "PKColumns": "",
    "TableColumns": "empl_no,check_no,lv_code,lv_bal,lv_tak,lv_ear,lv_nbr",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "check_paycode",
    "PKColumns": "",
    "TableColumns": "empl_no,check_no,pay_code,ytd_amt",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "check_record",
    "PKColumns": "",
    "TableColumns": "yr,period,disb_fund,fund,account,check_no,check_date,trans_date,vend_no,alt_vend_no,ven_name,amount,check_status,clear_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "check_ytd",
    "PKColumns": "",
    "TableColumns": "empl_no,check_no,chk_locn,email_voucher,fed_marital,fed_dep,add_fed,sta_marital,sta_dep,add_state,loc_marital,loc_dep,tearn_y,ftearn_y,tearn_ft,allow_y,nocash_y,dock_arrears_amt",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "checkhi2",
    "PKColumns": "",
    "TableColumns": "empl_no,check_no,earn_ded,code,amt,fringe,orgn,proj,acct,classify,hours,dedgross,frngross,flsa_flg,group_x,payrate",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "checkhis",
    "PKColumns": "",
    "TableColumns": "empl_no,check_no,iss_date,trans_date,dirdep,man_void,pay_run,status_cd,home_orgn,start_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "checkrec",
    "PKColumns": "",
    "TableColumns": "check_no,empl_no,iss_date,amount,bank,cleared,man_void",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "chgactap",
    "PKColumns": "",
    "TableColumns": "po_no,change,line_no,range_code,action_date,app_name,act,comment",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "chgactap_hist",
    "PKColumns": "",
    "TableColumns": "hist_date,hist_time,po_no,change,line_no,range_code,action_date,app_name,act,comment",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "chgaprv",
    "PKColumns": "",
    "TableColumns": "po_no,change,line_no,lvl,action_date,app_name,act,comment,apprvreqd",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "chgaprv_hist",
    "PKColumns": "",
    "TableColumns": "hist_date,hist_time,po_no,change,line_no,lvl,action_date,app_name,act,comment,apprvreqd",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "chgchrg",
    "PKColumns": "po_no,change,line_no,indx",
    "TableColumns": "po_no,change,line_no,key_orgn,account,proj,proj_acct,amount,encumber,indx,prcnt,service_order",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "chgcomm",
    "PKColumns": "",
    "TableColumns": "po_no,change,line_no,commodity,desc1,desc2,desc3,desc4,desc5,measure,quanity,unit_price,total_price,stock_no,sales_tax,use_tax,freight,tax_rate,dist_method,dist_key,apply_all,trade_in,prod_code,approval_req,item_status",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "chgcomnt",
    "PKColumns": "",
    "TableColumns": "po_no,change,seq,comment",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "chglinds",
    "PKColumns": "",
    "TableColumns": "po_no,change,line_no,seq,description",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "chgorder",
    "PKColumns": "po_no,change",
    "TableColumns": "po_no,change,vend_no,po_date,require,expiration,final,blanket,price_agree,confirming,terms,freight,buyer,ship_code,attention,issued,description,vend_seq,po_type,print_text,change_date,location",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "chgtaxes",
    "PKColumns": "",
    "TableColumns": "po_no,change,line_no,stax_rate,utax_rate",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "chkstat",
    "PKColumns": "rundate,disp_fund,check_no,chk_status",
    "TableColumns": "rundate,disp_fund,check_no,vend_no,vend_name,chk_status,amount,description",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "clsincr",
    "PKColumns": "",
    "TableColumns": "classify,amt,prcent",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "clstable",
    "PKColumns": "",
    "TableColumns": "class_cd,title,schedule,wkr_comp,civil_ser,union_cd,division,contract_title,cal_type,ded_cd1,ded_cd2,ded_cd3,ded_cd4,ded_cd5,ded_cd6,ded_cd7,ded_cd8,ded_cd9,ded_cd10,lv1_cd,lv2_cd,lv3_cd,lv4_cd,lv5_cd,lv6_cd,lv7_cd,lv8_cd,lv9_cd,lv10_cd,pay_cd,pay_method,group_x,bar_unit",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "clstable_data2",
    "PKColumns": "",
    "TableColumns": "class_cd,job_type,job_descript",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "cob_act",
    "PKColumns": "",
    "TableColumns": "empl_no,ben_code,d_ssn,date_paid,act,old_value,new_value,operator,chg_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "cob_his",
    "PKColumns": "",
    "TableColumns": "empl_no,ben_code,d_ssn,date_paid,amt_paid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "cobra",
    "PKColumns": "",
    "TableColumns": "empl_no,ben_code,d_ssn,stat,qual_code,qual_date,notify_code,notify_date,start_date,stop_date,due_current,due_date,due_delinq,date_delinq,last_paid,date_paid,bill_itd,paid_itd",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "code_crosswalk",
    "PKColumns": "",
    "TableColumns": "field_identifier,old_code,new_code",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "color_table",
    "PKColumns": "",
    "TableColumns": "color_name,color_code",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "comdesc",
    "PKColumns": "",
    "TableColumns": "code,seq,description",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "comhist",
    "PKColumns": "",
    "TableColumns": "code,vend_no,purch_date,price",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "commod",
    "PKColumns": "",
    "TableColumns": "code,status,stock_no,measure,bid_req,desc1,desc2,desc3,desc4,desc5,price1,date1,vend1,price2,date2,vend2,price3,date3,vend3,qual_prod_lim,com_account,buyer,taxable_flg,alpha_commod",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "comstkno",
    "PKColumns": "",
    "TableColumns": "code,stock_no",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "comtext",
    "PKColumns": "",
    "TableColumns": "com_code,rec_no,description",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "cont_misc_fields",
    "PKColumns": "col_friendly_name",
    "TableColumns": "col_friendly_name,db_table,db_column,future_yr",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "contract_adjust",
    "PKColumns": "",
    "TableColumns": "empl_no,pay_run,check_no,chk_ind,classify,adj_amt",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "contract_type_tbl",
    "PKColumns": "contract_type",
    "TableColumns": "contract_type,description",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "contract_type_tbl2",
    "PKColumns": "contract_type,class_cd",
    "TableColumns": "contract_type,class_cd",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "courthis",
    "PKColumns": "",
    "TableColumns": "case_no,h_date,h_type,check_no,ck_date,operator,vend_no,amount",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "courtpro",
    "PKColumns": "",
    "TableColumns": "title1,title2,je_type,combine,bondfund,bondcash,bondliab,pstdrorgn,pstdracct,pstcrorgn,pstcracct,feedrorgn,feedracct,feecrorgn,feecracct,next_ven_no",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "courtreg",
    "PKColumns": "",
    "TableColumns": "case_no,rec_date,dep_date,court_date,rec_no,plfname,plfadr1,plfadr2,plfcity,plfstate,plfzip,defname,defadr1,defadr2,defcity,defstate,defzip,plfvend,defvend,clkvend,othven1,othven2,othven3,othven4,othven5,user1,user2,amount,balance",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "crdc_bldmnt",
    "PKColumns": "code,rpt_yr",
    "TableColumns": "code,nces_schoolid,tot_fte,rpt_yr,freeze,cert_fte,nocert_fte,firstyr,secondyr,teach_curr,teach_prev,counsel_fte,officer_fte,guard_fte,nurse_fte,nurse_fte_lock,psych_fte,soc_fte,tenday_abs_fte,fte_teach_nofed,sal_teach_nofed,fte_aid_nofed,sal_aid_nofed,fte_sup_nofed,sal_sup_nofed,fte_adm_nofed,sal_adm_nofed,sal_tot_nofed,npe_nofed,sal_teach_wfed,fte_aid_wfed,sal_aid_wfed,fte_sup_wfed,sal_sup_wfed,fte_adm_wfed,sal_adm_wfed,sal_tot_wfed,npe_wfed,mathcert_fte,scicert_fte,eslcert_fte,spedcert_fte,teach_curr_hi_m,teach_curr_am_m,teach_curr_as_m,teach_curr_hp_m,teach_curr_bl_m,teach_curr_wh_m,teach_curr_tr_m,teach_curr_hi_f,teach_curr_am_f,teach_curr_as_f,teach_curr_hp_f,teach_curr_bl_f,teach_curr_wh_f,teach_curr_tr_f",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "crdc_cert_type",
    "PKColumns": "",
    "TableColumns": "code,exclude_cred",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "crdc_de_xwalk",
    "PKColumns": "dept_code",
    "TableColumns": "dept_code,position",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "crdc_distcfg",
    "PKColumns": "dist_id,yr",
    "TableColumns": "dist_id,nces_dist_id,yr,part1date,part2date,fed_lvl,bld_lvl,func_lvl,excluded_cred,pos_crit,fte_crit,hist_capt_yr",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "crdc_employee",
    "PKColumns": "empl_no,crdc_pos,locn,rpt_yr",
    "TableColumns": "empl_no,crdc_pos,part1_fte,locn,cert_yn,yrs_total,hire_date,tenday_abs,part2_fte_nofed,total_sal_nofed,part2_fte_wfed,total_sal_wfed,calc_date,calc_id,rpt_yr",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "crdc_fedfund",
    "PKColumns": "",
    "TableColumns": "fedcode",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "crdc_jp_xwalk",
    "PKColumns": "",
    "TableColumns": "position,job_class,pay_code,sel_type,default_fte",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "crdc_lastcalc",
    "PKColumns": "",
    "TableColumns": "part_ind,pos_crit,fte_crit,calc_date,calc_time,calc_id",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "crdc_levtable",
    "PKColumns": "",
    "TableColumns": "lv_code,unit_type,crdc_include",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "crdc_locn",
    "PKColumns": "",
    "TableColumns": "code,orgn_loc,nces_school_id",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "crdc_lv_hist",
    "PKColumns": "empl_no,yr,seq_no,reason_code",
    "TableColumns": "empl_no,yr,save_date,seq_no,lv1_cd,lv1_bal,lv1_tak,lv1_ear,lv2_cd,lv2_bal,lv2_tak,lv2_ear,lv3_cd,lv3_bal,lv3_tak,lv3_ear,lv4_cd,lv4_bal,lv4_tak,lv4_ear,lv5_cd,lv5_bal,lv5_tak,lv5_ear,lv6_cd,lv6_bal,lv6_tak,lv6_ear,lv7_cd,lv7_bal,lv7_tak,lv7_ear,lv8_cd,lv8_bal,lv8_tak,lv8_ear,lv9_cd,lv9_bal,lv9_tak,lv9_ear,lv10_cd,lv10_bal,lv10_tak,lv10_ear,reason_code",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "crn_cfg",
    "PKColumns": "",
    "TableColumns": "available,crn_version,crn_desc,crn_server,gateway_server,gateway_url,add_params,district,use_ssl,change_date_time,change_uid,dsn_name,cat_db_name,cat_server_info",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "crn_cfg_renamed",
    "PKColumns": "",
    "TableColumns": "available,crn_version,crn_desc,crn_server,gateway_server,gateway_url,add_params,dsn_name,use_ssl,district,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "cross_def",
    "PKColumns": "",
    "TableColumns": "location,ship_code",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ct3inter",
    "PKColumns": "",
    "TableColumns": "ind,orgn_proj,account,fringe,amount,ctrl_no,row_id,pay_run",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "cxbudacct",
    "PKColumns": "",
    "TableColumns": "yr,old_acct,new_acct,new_subtot1,new_subtot2,new_subtot3,new_title",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "cxbudorgn",
    "PKColumns": "",
    "TableColumns": "yr,old_keyorgn,total,lvl,new_keyorgn,new_title,new_fund,new_orgn1,new_orgn2,new_orgn3,new_orgn4,new_orgn5,new_orgn6,new_orgn7,new_orgn8,new_orgn9",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "dash_detail",
    "PKColumns": "",
    "TableColumns": "row_id,plus_user_id,groupid,sequence,enabled,batch_mode,batch_frequency,last_batch,next_batch,graph_title,description,x_legend,y_legend,db_name,low_range_1,high_range_1,pic_range_1,low_range_2,high_range_2,pic_range_2,low_range_3,high_range_3,pic_range_3,qry_text,qry_graph_url,drill_params",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "dash_detail_data",
    "PKColumns": "",
    "TableColumns": "row_id,dash_detail_qry_id,col_sequence,tablename,columnname,friendly_name,data_mask",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "dash_detail_qry",
    "PKColumns": "",
    "TableColumns": "row_id,parent_id,dash_detail_id,qry_level,qry_sequence,qry_desc,qry_label,qry_text,qry_graph_url,drill_params,report_node",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "dash_header",
    "PKColumns": "",
    "TableColumns": "plus_user_id,number_columns,col1_desc,col1_color,col2_desc,col2_color,col3_desc,col3_color,color_code_1,color_code_2,color_code_3,color_code_4,color_code_5,color_code_6,color_code_7,color_code_8,color_code_9,color_code_10,color_code_11,color_code_12,color_code_13,background_color",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "dash_master",
    "PKColumns": "",
    "TableColumns": "row_id,batch_mode,batch_frequency,graph_title,description,x_legend,y_legend,db_name,low_range_1,high_range_1,pic_range_1,low_range_2,high_range_2,pic_range_2,low_range_3,high_range_3,pic_range_3,qry_text,qry_graph_url,drill_params",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "dash_master_data",
    "PKColumns": "",
    "TableColumns": "row_id,dash_master_qry_id,col_sequence,tablename,columnname,friendly_name,data_mask",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "dash_master_qry",
    "PKColumns": "",
    "TableColumns": "row_id,parent_id,dash_master_id,qry_level,qry_sequence,qry_desc,qry_label,qry_text,qry_graph_url,drill_params,report_node",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "dash_run",
    "PKColumns": "",
    "TableColumns": "row_id,plus_user_id,rundate,qry_status,qry_text,qry_params,qry_result,dash_detail_id",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "data_mask",
    "PKColumns": "",
    "TableColumns": "code,mask_desc,data_mask",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "dcert_area",
    "PKColumns": "",
    "TableColumns": "code,desc_x,core_area",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "dcert_type",
    "PKColumns": "",
    "TableColumns": "code,desc_x",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "dclstable",
    "PKColumns": "",
    "TableColumns": "class_cd,title,schedule,wkr_comp,civil_ser,union_cd,division,contract_title,cal_type,ded_cd1,ded_cd2,ded_cd3,ded_cd4,ded_cd5,ded_cd6,ded_cd7,ded_cd8,ded_cd9,ded_cd10,lv1_cd,lv2_cd,lv3_cd,lv4_cd,lv5_cd,lv6_cd,lv7_cd,lv8_cd,lv9_cd,lv10_cd,pay_cd,pay_method,group_x,bar_unit",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ddegtable",
    "PKColumns": "",
    "TableColumns": "code,desc_x,deglvl,state_degree,lcredit,hcredit",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "dedaddend",
    "PKColumns": "",
    "TableColumns": "empl_no,ded_cd,rec_no,case_no,order_date,amount,medical,fips_cd,terminated,arrears,notes",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "dedfreqtable",
    "PKColumns": "",
    "TableColumns": "freq,title,no_times",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "dedtable",
    "PKColumns": "ded_cd",
    "TableColumns": "ded_cd,title,ck_title,freq,arrears,emp_meth,rate,low_max,mid_rate,mid_max,high_rate,with_acct,frng_meth,frng_rate,frng_acct,frng_dist,frng_orgn,frng_proj,fed_exp,sta_exp,fic_exp,loc_exp,fed_fexp,sta_fexp,fic_fexp,loc_fexp,max_meth,vend_no,vend_pay_freq,bond_flag,max_ded,max_ben,caf_flag,encumber,enc_num_times,enc_remaining,use_gross_field,eac_whatif,mandatory_flag,child_sup_flag,copy_bank_info,calc_pr_add_with",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "dedtbl_web",
    "PKColumns": "",
    "TableColumns": "ded_cd,link_ded,ded_txt,upd_flg,bnk_flg,dep_ben,fullnet_flg,inaccurate_flg",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "deduct",
    "PKColumns": "empl_no,ded_cd",
    "TableColumns": "empl_no,ded_cd,status,account,start_x,stop_x,beff_date,ded_amt,max_amt,max_fringe,arrears,cont_amt,num_deds,chk_ind,taken_c,taken_m,taken_q,taken_y,taken_i,taken_f,cont_c,cont_m,cont_q,cont_y,cont_i,cont_f,sal_c,sal_m,sal_q,sal_y,sal_f,bank,bt_code,bank_acct,enc_remaining,addl_ded_gross,addl_frng_gross",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "def_comp",
    "PKColumns": "",
    "TableColumns": "title,rec_type,outfldnum,fld_def,fld_len,start_pos,text1,text2,dec_fmt,date_fmt,yes_no",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "defined",
    "PKColumns": "",
    "TableColumns": "je_number,description,key_orgn,account,project,proj_acct,debit,credit,item_desc,row_id",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "deglevtable",
    "PKColumns": "",
    "TableColumns": "code,desc_x",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "degsubject",
    "PKColumns": "",
    "TableColumns": "subcode,subtype",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "degtable",
    "PKColumns": "",
    "TableColumns": "code,desc_x,deglvl,state_degree,lcredit,hcredit",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "dencumbr",
    "PKColumns": "",
    "TableColumns": "enc_no,line_no,vend_no,description,key_orgn,account,project,proj_acct,amount,date_enc,hold_flg,date_entered,entered_by,batch,yr,period,sales_tax,use_tax,where_created,row_id",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "department",
    "PKColumns": "",
    "TableColumns": "dept,dept_title",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "dependent",
    "PKColumns": "",
    "TableColumns": "empl_no,d_ssn,l_name,f_name,addr_1,addr_2,zip,b_date,relation,sex,stat",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "dependentorg",
    "PKColumns": "",
    "TableColumns": "empl_no,d_ssn,l_name,f_name,addr_1,addr_2,zip,b_date,relation,sex,stat",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "dephist",
    "PKColumns": "",
    "TableColumns": "fiscal_yr,tagno,improvement_num,fund_type,func_name,activity,dep_orgn,dep_acct,accum_dep_acct,dep_amt,post_mth,post_year,post_date,post_togl",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "dept",
    "PKColumns": "code",
    "TableColumns": "code,desc_x",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "detdist",
    "PKColumns": "rec_no",
    "TableColumns": "empl_no,pay_date,rec_type,orgn_proj,acct,offset,code,amount,check_no,paygroup,void_man,pay_run,redist,classify,rec_no",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "detdist_ben_ovrd",
    "PKColumns": "dd_rec_no",
    "TableColumns": "dd_rec_no,orig_sal_orgn,orig_sal_acct,prim_sal_orgn,prim_sal_acct",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "dexpledgr",
    "PKColumns": "",
    "TableColumns": "yr,period,key_orgn,account,description,amount,batch,trn_no,entered_by,type_flg,trn_idx,hold_flg,app_group,approve_required,approval_stat,hdr_desc",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "dinvrecom",
    "PKColumns": "",
    "TableColumns": "req_no,line_no,stock_no,key_orgn,account,quantity,price,proj,proj_acct",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "dinvreq",
    "PKColumns": "",
    "TableColumns": "batch_no,req_yr,req_no,locn,requested,require,ship_code,person,remarks",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "dinvtran",
    "PKColumns": "",
    "TableColumns": "batch_no,locn,stock_no,inv_date,inv_count,adj_orgn,adj_acct,entered_by",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "dist_cell",
    "PKColumns": "",
    "TableColumns": "fam_code,grd_code,chk_locn,dept,cell_no,low_amt,hi_amt,curr_amt,proj_amt",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "dist_orgn",
    "PKColumns": "",
    "TableColumns": "empl_no,rate_no,classify,pos,orgn,acct,prcent",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "dist_proj",
    "PKColumns": "",
    "TableColumns": "empl_no,rate_no,classify,pos,proj,acct,prcent",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "distdesc",
    "PKColumns": "",
    "TableColumns": "dist_key,descrip,dist_year,acct_info_only,yearend_roll",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "distdetl",
    "PKColumns": "",
    "TableColumns": "dist_key,dist_seq,dist_orgn,orgn_acct,dist_proj,proj_acct,dist_per,dist_year",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "district_entity",
    "PKColumns": "id",
    "TableColumns": "id,name,entity_type,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "djournal",
    "PKColumns": "",
    "TableColumns": "je_number,description,key_orgn,account,project,proj_acct,debit_amt,credit_amt,hold_flg,date_entered,entered_by,batch,yr,period,item_desc,row_id,status,source",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "djournal_override",
    "PKColumns": "",
    "TableColumns": "batch,je_number,override_flg,date_entered,entered_by,yr,period,source",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "djournal_setperiod",
    "PKColumns": "",
    "TableColumns": "batch,transaction_date,je_number",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "dlevtable",
    "PKColumns": "lv_code",
    "TableColumns": "lv_code,title,ck_title,acc_type,acc_rate,lwop_acct,max_acc,years,exc_meth,roll_lim,roll_code,max_earn,unused_pay_meth,unused_pay,lv_unit,emp_status,prt_flg",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "dmanchk",
    "PKColumns": "",
    "TableColumns": "check_no,cancel,ck_date,enc_no,line_no,p_f,key_orgn,account,project,proj_acct,vend_no,c_1099,gl_cash,invoice,trans_amt,description,hold_flg,date_entered,entered_by,batch,yr,period,qty_paid,qty_rec,disc_date,disc_amt,sales_tax,use_tax,alt_vend_no,row_id,stu_trans_no,disb_fund",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "dpayable",
    "PKColumns": "row_id",
    "TableColumns": "trans_no,enc_no,line_no,p_f,key_orgn,account,project,proj_acct,vend_no,c_1099,gl_cash,due_date,invoice,amount,description,single_ck,disc_date,disc_amt,voucher,hold_flg,date_entered,entered_by,batch,yr,period,qty_paid,qty_rec,sales_tax,use_tax,alt_vend_no,row_id,app_group,payable_src,disc_per,approve_required,approval_stat,stu_trans_no",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "dpayable_head",
    "PKColumns": "",
    "TableColumns": "batch,batch_status,batch_src",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "dpaytable",
    "PKColumns": "pay_code",
    "TableColumns": "pay_code,title,ck_title,pay_type,percent_x,account,fed_exempt,sta_exempt,fic_exempt,loc_exempt,ded1_exempt,ded2_exempt,ded3_exempt,ded4_exempt,ded5_exempt,ded6_exempt,ded7_exempt,ded8_exempt,ded9_exempt,ded10_exempt,lv_add,lv_sub,time_type,frequency,wkr_comp,encum,pc_track,flsa_calc_type,flsa_ovt,exc_retro,add_factor,time_flag,app_level,ded11_exempt,ded12_exempt,ded13_exempt,ded14_exempt,ded15_exempt,ded16_exempt,ded17_exempt,ded18_exempt,ded19_exempt,ded20_exempt,ded21_exempt,ded22_exempt,ded23_exempt,ded24_exempt,ded25_exempt,ded26_exempt,ded27_exempt,ded28_exempt,ded29_exempt,ded30_exempt,ded31_exempt,ded32_exempt,ded33_exempt,ded34_exempt,ded35_exempt,ded36_exempt,ded37_exempt,ded38_exempt,ded39_exempt,ded40_exempt,include_notif",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "dreceipt",
    "PKColumns": "",
    "TableColumns": "enc_no,gl_recv,key_orgn,account,project,proj_acct,vend_no,gl_cash,invoice,description,trans_amt,hold_flg,date_entered,entered_by,batch,yr,period,row_id,stu_trans_no",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "dreceive",
    "PKColumns": "",
    "TableColumns": "enc_no,key_orgn,account,project,proj_acct,gl_account,vend_no,amount,date_enc,description,hold_flg,date_entered,entered_by,batch,yr,period,row_id",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "dregtb_building",
    "PKColumns": "building",
    "TableColumns": "building,building_name,district_num,street,city,state_id,zip_code,phone,principal,calendar,building_node,dist_updated,change_date,change_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "dschool",
    "PKColumns": "",
    "TableColumns": "code,desc_x",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "dsubject",
    "PKColumns": "",
    "TableColumns": "code,desc_x",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "dt_levtable",
    "PKColumns": "lv_code,pay_code",
    "TableColumns": "lv_code,pay_code",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "dtytable",
    "PKColumns": "",
    "TableColumns": "code,desc_x,prcent,dollar",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "dvendor",
    "PKColumns": "",
    "TableColumns": "vend_no,ven_name,alpha_name,b_addr_1,b_addr_2,b_city,b_state,b_zip,b_contact,b_phone,b_fax,p_addr_1,p_addr_2,p_city,p_state,p_zip,p_contact,p_phone,p_fax,fed_id,date_last,paid_ytd,prev_misc,ordered_ytd,comm1,comm2,comm3,comm4,comm5,comm6,comm7,comm8,comm9,comm10,comm11,hold_flg,date_entered,entered_by,batch,form_1099,stax_rate,utax_rate,type_misc,empl_vend,empl_no,hold_trn_flg,min_check_amt,type_g,prev_g,type_int,prev_int,row_id,dba_name,web_url,inactive_flg,ten99_ven_name,ten99_addr_1,ten99_addr_2,ten99_city,ten99_state,ten99_zip",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "eac_deplink",
    "PKColumns": "",
    "TableColumns": "empl_no,d_ssn",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "eac_enr_benefici",
    "PKColumns": "",
    "TableColumns": "eff_date,empl_no,ben_code,d_ssn,b_ssn,l_name,f_name,bb_date,percnt,relation,enrollment_type,yr,posted",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "eac_enr_benefits",
    "PKColumns": "",
    "TableColumns": "eff_date,empl_no,d_ssn,ben_code,enrollment_type,yr,posted",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "eac_enr_confirm",
    "PKColumns": "",
    "TableColumns": "empl_no,enrollment_type,yr,conf_date,conf_time,posted",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "eac_enr_contben",
    "PKColumns": "",
    "TableColumns": "eff_date,empl_no,ben_code,cont_info,enrollment_type,yr,posted",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "eac_enr_deduct",
    "PKColumns": "",
    "TableColumns": "eff_date,empl_no,ben_type,ded_cd,enrollment_type,yr,posted,status,account,start_x,stop_x,beff_date,ded_amt,cont_amt,num_deds,max_amt,max_fringe,arrears,chk_ind,bank,bt_code,bank_acct,date_chg,post_flg",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "eac_enr_questions",
    "PKColumns": "",
    "TableColumns": "empl_no,ben_type,ded_cd,enrollment_type,yr,posted,question_no,question,answer",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "eac_enr_timestamp",
    "PKColumns": "",
    "TableColumns": "submit_date,submit_time,empl_no,enrollment_type,yr,posted",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "eac_linkdedquest",
    "PKColumns": "",
    "TableColumns": "ben_type,ded_cd,question_group",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "eac_nh_effdate",
    "PKColumns": "",
    "TableColumns": "ben_type,ded_cd,edoption,midyrflag",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "eac_questiongroups",
    "PKColumns": "",
    "TableColumns": "question_group,question_text,question_id",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ear_assetif",
    "PKColumns": "rec_no",
    "TableColumns": "rec_no,qty_rcvd,account_no",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ear_atrs_empr",
    "PKColumns": "",
    "TableColumns": "empr_cd,empr_name,addr1,addr2,city,state,zipcode",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ear_calenpay",
    "PKColumns": "",
    "TableColumns": "cal_type,pay_run,start_date,end_date,no_days",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ear_clstable",
    "PKColumns": "",
    "TableColumns": "class_cd,cls_type",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ear_cont_detail",
    "PKColumns": "",
    "TableColumns": "empl_no,classify,cont_type,field_name,field_no,field_value",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ear_dedtable",
    "PKColumns": "",
    "TableColumns": "ded_cd,ret_group,type,linked_cd,certified",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ear_emp_contract",
    "PKColumns": "",
    "TableColumns": "empl_no,classify,group_x,schedule,cont_type",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ear_fam_prof",
    "PKColumns": "",
    "TableColumns": "city_per,city_max,state_per,state_max,county_per,county_max,fund_bal_low,fund_bal_hi,cust1,cust2,cust3,cust4,cust5,cust6,cust7,cust8,cust9,cust10",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ear_health",
    "PKColumns": "",
    "TableColumns": "ded_cd,health_ins",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ear_hrm_chrg",
    "PKColumns": "",
    "TableColumns": "code",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ear_inv_prof",
    "PKColumns": "",
    "TableColumns": "charge_warn",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ear_levtable",
    "PKColumns": "",
    "TableColumns": "lv_code,cost_of_sub",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ear_old_limit",
    "PKColumns": "",
    "TableColumns": "yr,empl_no,rate_no,classify,cont_start,cont_end,cont_lim,cont_paid,retro_calc",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ear_pbsuser",
    "PKColumns": "",
    "TableColumns": "empl_no,cls_crt",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ear_purchase",
    "PKColumns": "po_no",
    "TableColumns": "po_no,approved_by",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ear_qtr_retire",
    "PKColumns": "",
    "TableColumns": "dist_no,trans_date,plan_opt,ssn,full_name,reg_salary_c,reg_salary_n,reg_cont,fed_cont,tot_cont,days_service,fed_salary_c,fed_salary_n,non_teach_sal,cls_type,err_msg,address,city,state,zip",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ear_retro_calc",
    "PKColumns": "",
    "TableColumns": "empl_no,l_name,f_name,m_name,group_x,classify,position,schedule,step_x,range,annl_sal,new_rate,new_dock,cont_limit,cont_paid,cont_retro,misc_retro,cont_per,misc_per",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ear_retro_class",
    "PKColumns": "",
    "TableColumns": "classify,pct_inc,amt_inc",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ear_retro_grps",
    "PKColumns": "",
    "TableColumns": "group_x,proc_flg",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ear_retro_rate",
    "PKColumns": "",
    "TableColumns": "yr,rec_no,empl_no,rate_no,primry,group_x,pay_hours,days_worked,hours_day,no_pays,fte,pay_method,pay_cycle,pay_cd,classify,cal_type,range,step_x,rate,dock_rate,cont_flg,cont_days,override,annl_sal,cont_lim,cont_bal,cont_paid,cont_start,cont_end,pay_start,pay_end,summer_pay,status_x,pyo_date,pyo_rem_pay,pyo_days,pyo_rate,pyo_amt",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ear_trs_data",
    "PKColumns": "",
    "TableColumns": "empr_cd,rpt_month,rpt_year,empl_no,rec_type,ssn,l_name,f_name,m_name,suffix,sex,addr1,addr2,home_phone,city,state,zip,birthdate,cont_flg,cont_days,cont_lim,empl_type,hire_date,cont_start,cont_end,home_orgn,part_time,class,summer_pay,atrs_status,apscn_status,disabled,qtd_serv_days,service_credit,term_code,term_date,days_worked,hours_day,aesd_exempt,start_x,stop_x,pay_cd,no_pays,rate,match_fed,match_reg,contrib_reg,contrib_fed,sal_reg,sal_fed,purchase,tot_grs,ded_cd,last_paid,pay_freq,amt_rate6,amt_rate12,suppl_date,arrears,service,rpt_date,tot_sal,ctrl_sal,err_msg",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ear_trs_load",
    "PKColumns": "",
    "TableColumns": "rpt_date,load_type,load_start,load_end,payrun1,payrun2,payrun3,payrun4,payrun5,payrun6,payrun7,payrun8,payrun9,payrun10,payrun11,payrun12,payrun13,payrun14,payrun15,payrun16,payrun17,payrun18,payrun19,payrun20,payrun21,payrun22,payrun23,payrun24,payrun25,payrun26,payrun27,payrun28,payrun29,payrun30,payrun31,payrun32,payrun33,payrun34,payrun35,payrun36,payrun37,payrun38,payrun39,payrun40,payrun41,payrun42,payrun43,payrun44,payrun45,payrun46,payrun47,payrun48,payrun49,payrun50,payrun51,payrun52,payrun53,payrun54,payrun55,payrun56,payrun57,payrun58,payrun59,payrun60,payrun61,payrun62,payrun63,payrun64,payrun65,payrun66,payrun67,payrun68,payrun69,payrun70,payrun71,payrun72,payrun73,payrun74,payrun75,payrun76,payrun77,payrun78,payrun79,payrun80",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ebd_count",
    "PKColumns": "",
    "TableColumns": "run_date,lea,empl_no,status,caf_ded_cd,caf_amt,cc_ded_cd,cc_amt",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ebd_daily",
    "PKColumns": "",
    "TableColumns": "lea,empl_no,status,caf_ded_cd,caf_amt,cc_ded_cd,cc_amt",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ebd_error",
    "PKColumns": "",
    "TableColumns": "lea,empl_no,status,caf_ded_cd,caf_amt,cc_ded_cd,cc_amt,ded_cd,error_desc",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "econtdat",
    "PKColumns": "dident,dschoolyr,dcontfld",
    "TableColumns": "dident,dschoolyr,dcontfld,dfriendtbl,dtbl,dfriendcol,dcol,change_uid,change_date_time",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "econtdef",
    "PKColumns": "",
    "TableColumns": "ident,descript,schoolyr,econtstat,sch_startdate,sch_enddate,cnt_startdate,cnt_enddate,show_date,signbydate,future_yr,primary_only,change_uid,change_date_time",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "econtempl",
    "PKColumns": "empl_no,ident,schoolyr",
    "TableColumns": "empl_no,ident,descript,schoolyr,esignature,sch_startdate,sch_enddate,cnt_startdate,cnt_enddate,show_date,signbydate,sigdate,sigstamp,batchid,create_datetime,change_uid,change_date_time",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "econtempldat",
    "PKColumns": "empl_no,dident,dschoolyr,dcontfld",
    "TableColumns": "empl_no,dident,dschoolyr,dcontfld,dtblcoldat,batchid,create_datetime,change_uid,change_date_time",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "econtprof",
    "PKColumns": "curr_schoolyr",
    "TableColumns": "curr_schoolyr,pdfattach,loc3pfls,change_uid,change_date_time",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "edgecustlinks",
    "PKColumns": "rec_no,prod_name",
    "TableColumns": "rec_no,title,url,field1,source1,prod_name",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "efp_profile",
    "PKColumns": "key_name",
    "TableColumns": "package,key_name,description,category,prof_type,state_id,custom,val,min_sw_version,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "eft_dest",
    "PKColumns": "",
    "TableColumns": "description,def_flag,eft_tax_id,eft_dest_name,eft_dest_bank_code,eft_trans_desc,eft_bank_debit,eft_site_bank_acct,fund,opt_trans_rec1,opt_trans_rec2,eft_file_format,eft_email_addr,email_subject,bcc_email_addr,email_body,eft_dest_num,imm_orig_num,imm_orig_name,company_id_hdr,company_id_ctrl,orig_dfi_id",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "eic2tabl",
    "PKColumns": "",
    "TableColumns": "pay_freq,marital,ear,amt,per",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "eictable",
    "PKColumns": "",
    "TableColumns": "pay_freq,marital,account,max_gross",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "emp_certificate",
    "PKColumns": "empl_no,indx",
    "TableColumns": "empl_no,number,iss_date,exp_date,reg_date,c_type,c_area,primary_cert,indx",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "emp_costtype_tbl",
    "PKColumns": "cost_type_cd",
    "TableColumns": "cost_type_cd,descx,create_who,create_when,update_who,update_when,unique_id,unique_key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "emp_course_costs",
    "PKColumns": "unique_key",
    "TableColumns": "empl_no,course_key,cost_type_cd,cost_amt,create_who,create_when,update_who,update_when,unique_id,unique_key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "emp_course_cred",
    "PKColumns": "unique_key",
    "TableColumns": "empl_no,course_key,credit_cd,credits,credit_inst,credit_dt,create_who,create_when,update_who,update_when,unique_id,unique_key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "emp_course_dtl",
    "PKColumns": "unique_key",
    "TableColumns": "empl_no,course_type_cd,course_title,course_no,status,start_date,completion_date,expiration_date,internal,provider,seat_hrs,instructor_name,grade,fiscal_year,reimbursement_amt,reimbursement_date,notes,cert_code,create_who,create_when,update_who,update_when,unique_id,unique_key,term_cd",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "emp_course_goal",
    "PKColumns": "unique_key",
    "TableColumns": "empl_no,course_key,goal_cd,goal_comm,create_who,create_when,update_who,update_when,unique_id,unique_key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "emp_course_misc",
    "PKColumns": "unique_key",
    "TableColumns": "empl_no,course_key,misc_cd_order,misc_code_val,create_who,create_when,update_who,update_when,unique_id,unique_key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "emp_course_topic",
    "PKColumns": "unique_key",
    "TableColumns": "empl_no,course_key,area_cd,create_who,create_when,update_who,update_when,unique_id,unique_key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "emp_credential",
    "PKColumns": "",
    "TableColumns": "empl_no,cred_code,eff_date,exp_date,exp_comp_date,misc_info",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "emp_crs_misc_lbl",
    "PKColumns": "unique_key",
    "TableColumns": "misc_cd_order,misc_cd_label,create_who,create_when,update_who,update_when,unique_id,unique_key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "emp_crs_stat_tbl",
    "PKColumns": "course_stat_cd",
    "TableColumns": "course_stat_cd,descx,create_who,create_when,update_who,update_when,unique_id,unique_key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "emp_crs_type_tbl",
    "PKColumns": "course_type_cd",
    "TableColumns": "course_type_cd,descx,create_who,create_when,update_who,update_when,unique_id,unique_key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "emp_degree",
    "PKColumns": "empl_no,indx",
    "TableColumns": "empl_no,dtype,highest,school,major,minor,deg_date,credits,gpa,user_1,indx",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "emp_license",
    "PKColumns": "",
    "TableColumns": "empl_no,license_number,lic_state,reg_id,license_type,issue_date,expiration_date,indx",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "emp_qual_notes",
    "PKColumns": "",
    "TableColumns": "empl_no,qual_code,eff_date,free_text",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "emp_qualify",
    "PKColumns": "",
    "TableColumns": "empl_no,qual_code,eff_date,exp_date,exp_comp_date,misc_info,qual_meth,qual_stat,active",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "emp_require",
    "PKColumns": "",
    "TableColumns": "empl_no,req_code,eff_date,exp_date,exp_comp_date,misc_info",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "empact",
    "PKColumns": "",
    "TableColumns": "empl_no,date_chg,table_name,field_name,old_value,new_value,operator,pay_ded_code,pay_ded_desc,time_chg",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "empl_privacy",
    "PKColumns": "empl_no",
    "TableColumns": "empl_no,share_home_phone,share_mobile_phone,share_home_email,update_who,update_when",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "empl_races",
    "PKColumns": "",
    "TableColumns": "empl_no,race_code,indx,race_order,race_prcnt",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "empl_staff",
    "PKColumns": "",
    "TableColumns": "empl_no,staff_state_id",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "emplinfo",
    "PKColumns": "",
    "TableColumns": "empl_no,marital,sex,depend_cov",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "employee",
    "PKColumns": "empl_no",
    "TableColumns": "empl_no,ssn,l_name,f_name,addr1,addr2,city,zip,hire_date,home_orgn,birthdate,base_loc,state_id,orig_hire,prev_lname,email_addr,info_rlease,email_voucher,uid,supervisor_id,personal_email,m_name,name_suffix,preferred_name",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "employee_renamed",
    "PKColumns": "empl_no",
    "TableColumns": "empl_no,ssn,l_name,f_name,m_name,addr1,addr2,city,zip,hire_date,home_orgn,birthdate,base_loc,state_id,orig_hire,prev_lname,email_addr,info_rlease,email_voucher,uid,supervisor_id,personal_email,name_suffix",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "employee_type",
    "PKColumns": "code",
    "TableColumns": "code,desc_x",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "emplsoundex",
    "PKColumns": "",
    "TableColumns": "soundcode,empl_no,l_name",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "empuser",
    "PKColumns": "empl_no,page_no",
    "TableColumns": "empl_no,page_no,ftext1,ftext2,ftext3,ftext4,ftext5,ftext6,ftext7,ftext8,ftext9,ftext10,tcode1,tcode2,tcode3,tcode4,tcode5,tcode6,tcode7,tcode8,tcode9,tcode10,comment1,comment2",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "empuser_snapshot",
    "PKColumns": "",
    "TableColumns": "add_date,uid,clear_code,month,qtr,year,empl_no,page_no,ftext1,ftext2,ftext3,ftext4,ftext5,ftext6,ftext7,ftext8,ftext9,ftext10,tcode1,tcode2,tcode3,tcode4,tcode5,tcode6,tcode7,tcode8,tcode9,tcode10,comment1,comment2",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "encdist",
    "PKColumns": "",
    "TableColumns": "empl_no,rate_no,rec_type,code,orgn_proj,acct,orig_enc,liq_amt,enc_amt,classify",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "encledgr",
    "PKColumns": "enc_no,line_no,yr,key_orgn,account,proj,proj_acct",
    "TableColumns": "enc_no,line_no,yr,key_orgn,account,proj,proj_acct,vend_no,orig_amt,change_bal,paymt_bal,date_enc,description,final,sales_tax,use_tax,where_created",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "enctaxes",
    "PKColumns": "enc_no,line_no",
    "TableColumns": "enc_no,line_no,stax_rate,utax_rate",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "enr_contben",
    "PKColumns": "",
    "TableColumns": "empl_no,ben_code,cont_info",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "enroll_confirm",
    "PKColumns": "",
    "TableColumns": "empl_no,ded_cd,confirm_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ent_allow_accounts",
    "PKColumns": "acct,entity_type",
    "TableColumns": "acct,entity_type,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ent_allow_budaccts",
    "PKColumns": "acct,yr,entity_type",
    "TableColumns": "acct,yr,entity_type,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ent_allow_budorgns",
    "PKColumns": "key_orgn,yr,entity_type",
    "TableColumns": "key_orgn,yr,entity_type,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ent_allow_orgns",
    "PKColumns": "key_orgn,yr,entity_type",
    "TableColumns": "key_orgn,yr,entity_type,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "entity_types",
    "PKColumns": "code",
    "TableColumns": "code,description",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "epay_banks",
    "PKColumns": "",
    "TableColumns": "epay_code,disb_fund,bank_acct",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "epay_format",
    "PKColumns": "",
    "TableColumns": "epay_code,format_descr,bank_trans_descr,check_char1,clear_vouchers,allow_email,seq_number,eaccount,lia_acct,addr1,addr2,city,state,zip,debit_credit,sec_code,filesource,shortname,expirydays,filesequence,cc_email,notes",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "epay_type",
    "PKColumns": "",
    "TableColumns": "vend_no,alt_vend_no,pay_type,payment_code",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "esc_employee",
    "PKColumns": "empl_no",
    "TableColumns": "empl_no,admin_flag,block_flag,inv_login_attempts,acct_locked_date_time",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "esc_prof",
    "PKColumns": "",
    "TableColumns": "site_logo,site_bgcolor,site_txtcolor,default_pg,email_server,email_port,admin_email,hr_email,payr_email,emplinfo_notify,benefits_notify,name_flg,addr_flg,email_flg,dates_flg,ssn_flg,pie_flg,fedfrm_name,stafrm_name,locfrm_name,fedtax_flg,statax_flg,loctax_flg,link_fed,link_sta,link_loc,instr_fed,instr_sta,instr_loc,leave_unit,leave_disclaim,cal_flg,cal_workday,cal_nonwork,cal_leave1,cal_leave2,cal_leave3,cal_leave4,cal_leave5,cal_leave6,cal_leave7,cal_leave8,cal_leave9,cal_leave10,enrol_disclaim,enrol_start,enrol_end,enrol_eff_date,upd_ben_flg,upd_dep_flg,degree_flg,certif_flg,certno_flg,certdate_flg,skills_flg,skills_title1,skills_title2,login_meth,payded_inact_flag,wphone_fmt_flag",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "esmfiscal",
    "PKColumns": "",
    "TableColumns": "begin_month,begin_day",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "esmpo",
    "PKColumns": "",
    "TableColumns": "tran_id,distid,po_id,req_no,po_no,userid,status,eft_flg,vend_manual,esm_po_no",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "esmpochrg",
    "PKColumns": "",
    "TableColumns": "po_id,req_no,po_no,itemid,item_no,indx,amount,save_amount,account_no,status,invoice,req_id",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "esmpoit",
    "PKColumns": "",
    "TableColumns": "po_id,req_no,po_no,itemid,item_no,status,save_received,received",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "esmreqchrg",
    "PKColumns": "",
    "TableColumns": "req_id,req_no,itemid,item_no,indx,amount,account_no,status,esm_req_no",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "esmrequ",
    "PKColumns": "",
    "TableColumns": "tran_id,req_id,dist_id,userid,req_no,status",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "et_crosswalk",
    "PKColumns": "",
    "TableColumns": "field_name,cur_value,new_value,group_cd",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ethnic_table",
    "PKColumns": "",
    "TableColumns": "ethnic_code,description",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ets_action_codes",
    "PKColumns": "",
    "TableColumns": "action_type,action_code,action_desc",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ets_actions",
    "PKColumns": "",
    "TableColumns": "empl_no,dept_code,pay_period,sup_date,sup_time,sup_empl_no,action_type,total_hours,action_code,action_desc",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ets_dist_depts",
    "PKColumns": "",
    "TableColumns": "dist_key,dept_code",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ets_distributions",
    "PKColumns": "",
    "TableColumns": "empl_no,dist_key,key_title,key_orgn,account,project,proj_acct,active,hidden,use_alt_account",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ets_except_list",
    "PKColumns": "",
    "TableColumns": "except_code,except_desc",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ets_notify",
    "PKColumns": "",
    "TableColumns": "empl_no,pay_period,dept_code",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ets_schdept",
    "PKColumns": "",
    "TableColumns": "sch_code,dept_code,include_linked,day1_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ets_sched_days",
    "PKColumns": "",
    "TableColumns": "sch_code,day_id,day_hrs",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ets_schedule",
    "PKColumns": "",
    "TableColumns": "sch_code,sch_desc,sch_default,sch_type",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "etx_clstable",
    "PKColumns": "",
    "TableColumns": "class_cd,accrual",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "etx_paytable",
    "PKColumns": "",
    "TableColumns": "pay_code,peims_cd,statmin_exempt,ret_exempt,pos_ovr",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ex_curricular",
    "PKColumns": "",
    "TableColumns": "code,desc_x",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "exceltasks",
    "PKColumns": "task_id",
    "TableColumns": "task_id,user_id,proc_id,report_name,file_name,start_date,end_date,task_status",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "expbudgt",
    "PKColumns": "yr,key_orgn,account",
    "TableColumns": "yr,key_orgn,account,bud1,exp1,enc1,bud2,exp2,enc2,bud3,exp3,enc3,bud4,exp4,enc4,bud5,exp5,enc5,bud6,exp6,enc6,bud7,exp7,enc7,bud8,exp8,enc8,bud9,exp9,enc9,bud10,exp10,enc10,bud11,exp11,enc11,bud12,exp12,enc12,bud13,exp13,enc13,inv_bal,req_bal,pay_encum,bud_adj",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "expense_AprvHist",
    "PKColumns": "row_id",
    "TableColumns": "row_id,hist_date,hist_time,expense_no,lvl,app_empl_no,del_empl_no,act,action_date,comment,approved_by,approval_level",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "expense_category",
    "PKColumns": "code",
    "TableColumns": "code,description,default_account,expense_type_code,unit_cost,advance_permitted,attachment_required",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "expense_detail",
    "PKColumns": "expense_no,line_no",
    "TableColumns": "expense_no,line_no,expense_date,expense_category,project,account,budget,estimated_cost,unit,unit_cost,line_cost,advance_flag,reimbursable_flag,comment,proj_acct",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "expense_header",
    "PKColumns": "expense_no",
    "TableColumns": "expense_no,empl_no,description,yr,expense_type,form_type,fiscal_year,start_date,end_date,city,state,status,po_no,reimbursable_amount,advance_amount,amount_owed,created_date,uid,comment,last_approved_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "expense_type",
    "PKColumns": "code",
    "TableColumns": "code,description,leave_request,leave_request_code,substitute_interface",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "expledgr",
    "PKColumns": "yr,key_orgn,account",
    "TableColumns": "yr,key_orgn,account,budget_orgn,budget_acct,bud1,exp1,enc1,bud2,exp2,enc2,bud3,exp3,enc3,bud4,exp4,enc4,bud5,exp5,enc5,bud6,exp6,enc6,bud7,exp7,enc7,bud8,exp8,enc8,bud9,exp9,enc9,bud10,exp10,enc10,bud11,exp11,enc11,bud12,exp12,enc12,bud13,exp13,enc13,pay_encum,active",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "expnotes",
    "PKColumns": "",
    "TableColumns": "yr,key_orgn,account,note,recno,amount",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "f_profact",
    "PKColumns": "",
    "TableColumns": "date_chg,table_name,field_name,old_value,new_value,operator",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "faaccount",
    "PKColumns": "",
    "TableColumns": "acct,sub_1_acct,sub_2_acct,sub_3_acct,title,proll_flg,reqpur_flg,war_flg,local_use",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "fam_grd",
    "PKColumns": "",
    "TableColumns": "fam_code,grd_code,description,min_sal,mid_sal,max_sal,new_date,new_min,new_mid,new_max,str_prct,prct_inc,flat_inc,curr_inc,new_incr,job_class,factor",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "fam_locn",
    "PKColumns": "",
    "TableColumns": "code,description,lev1_us1,lev1_us2,lev1_us3,lev2_us1,lev2_us2,lev2_us3,lev3_us1,lev3_us2,lev3_us3",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "fam_prof",
    "PKColumns": "",
    "TableColumns": "trans_date,period,yr,client,system,company,disb_fund,pay_fund,cash_account,pay_cash,a_p,fund_bal,exp_bud_control,rev_bud_control,res_for_enc,act_fund_bal,enc_control,pay_res_enc,pen_control,exp_control,rev_control,tax_payable,low_asset,hi_asset,low_lia,hi_lia,low_equ,hi_equ,low_exp,hi_exp,low_rev,hi_rev,enc_title,fund_title,orgn1_title,orgn2_title,orgn3_title,orgn4_title,orgn5_title,orgn6_title,orgn7_title,orgn8_title,orgn9_title,low_orgn,proj1_title,proj2_title,proj3_title,proj4_title,proj5_title,proj6_title,proj7_title,proj8_title,low_proj,user_req,next_reqno,user_po,next_pono,user_je,next_jeno,user_vendor,next_vndno,purch_encum,dup_invoice,high_lev,min_amount,purch,fixed_assets,inv_control,ven_bidding,check_sort,e_full_acct,r_full_acct,portrait,chk_frmt,det_sum,prior_year,sum_enc_flg,app_by_group,app_group,comm_mask,comm_used,pre_encum,city,state_id,zip,buyer,payb4recv,autobal,jetofrom,p_f,opay_warning,opay_type,opay_amount,opay_percent,sep_old_je,next_old_jeno,user_bt,next_btno,def_vnd_due,key_sum,sep_nyr_req,next_nyr_reqno,sep_nyr_po,next_nyr_pono,dist_method,len_reqno,len_pono,ap_pdf,po_pdf,deft_appgrp_pay,deft_appgrp_comm,deft_appgrp_load,ap_appr_po_pay,ap_appr_no_po,ap_appr_po_thres,purch_email,bud_approve,tax_freight,exceed_payroll_bud,apcheck_form,po_form,pyrl_venpay_cash,req_po_def,copy_req_notes,flag1,flag2,flag3,flag4,flag5,flag6,flag7,flag8,flag9,flag10,fisc_start_date,fisc_end_date,compl_req_only,prevnt_upd_cvt_req",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "fam_ref",
    "PKColumns": "",
    "TableColumns": "prefx,code,desc_x",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "famstate",
    "PKColumns": "",
    "TableColumns": "state1,state2,state3,state4,state5,state6,state7,state8,state9,state10,state11,state12,state13,state14,state15,state16,state17,state18,state19,state20,state21,state22,state23,state24,state25,state26,state27,state28,state29,state30,state31,state32,state33,state34,state35,state36,state37,state38,state39,state40,state41,state42,state43,state44,state45,state46,state47,state48,state49,state50,state51,state52,state53,state54,state55,state56,state57,state58,state59,state60,state61,state62,state63,state64,state65,state66,state67,state68,state69,state70,state71,state72,state73,state74,state75,state76,state77,state78,state79,state80,state81,state82,state83,state84,state85,state86,state87,state88,state89,state90,state91,state92,state93,state94,state95,state96,state97,state98,state99,state100,state101,state102",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "famwork_activities",
    "PKColumns": "",
    "TableColumns": "date_time,source_email,act_subject,act_status,act_notes,dest_uid,act_url,source_uid,activity_xml,row_id,wkf_instance_id,dest_email,workflow_id,delegate_item",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "famwork_notifyhist",
    "PKColumns": "",
    "TableColumns": "date_time,source_email,act_subject,act_status,act_notes,dest_uid,act_url,source_uid,activity_xml,row_id,wkf_instance_id,dest_email,workflow_id,delegate_item",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "famworkflow_guids",
    "PKColumns": "",
    "TableColumns": "row_id,guid,workflow_type,fk_table,fk_col1,fk_val1,fk_col2,fk_val2,fk_col3,fk_val3,fk_col4,fk_val4",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "famworkflow_log",
    "PKColumns": "",
    "TableColumns": "row_id,datetime_stamp,guid,workflow_type,event_type,workflow_event,parameters,info_string",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "faorgn",
    "PKColumns": "",
    "TableColumns": "yr,key_orgn,lvl,fund,orgn1,orgn2,orgn3,orgn4,orgn5,orgn6,orgn7,orgn8,orgn9,title,enterprise,cash,budget,req_enc,pr_orgn,disb_fund,total_rec,proj_link,project,local_use",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "faproject",
    "PKColumns": "",
    "TableColumns": "key_proj,lvl,proj1,proj2,title,start_date,stop_date,funding,budget,closed,overhd1,overhd2,overhd3,overhd4,proj3,proj4,proj5,proj6,proj7,proj8",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "faworkactivityhist",
    "PKColumns": "",
    "TableColumns": "date_time,source_email,act_subject,act_status,act_notes,dest_uid,act_url,source_uid,activity_xml,row_id,wkf_instance_id,dest_email,workflow_id,delegate_item",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "faworknotification",
    "PKColumns": "",
    "TableColumns": "date_time,source_email,act_subject,act_status,act_notes,dest_uid,act_url,source_uid,activity_xml,row_id,wkf_instance_id,dest_email,workflow_id,delegate_item",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "fe2table",
    "PKColumns": "",
    "TableColumns": "pay_freq,marital,ear,amt,per,with_rate_sched_cd",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "fed_race_codes",
    "PKColumns": "",
    "TableColumns": "fed_code,description",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "fed_tax_calc",
    "PKColumns": "code",
    "TableColumns": "code,description,active",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "fedtable",
    "PKColumns": "",
    "TableColumns": "pay_freq,marital,account,depend,supp_per,with_rate_sched_cd,pays_per_year,nonres_alien_adj1,nonres_alien_adj2,std_allowance",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "fictable",
    "PKColumns": "",
    "TableColumns": "fic_med,emp_per,emp_max,empr_per,empr_max,lia_acct,frg_acct,frng_dist,frng_orgn,encumber",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "filing_type",
    "PKColumns": "",
    "TableColumns": "type_cd,description",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "finauditlinks",
    "PKColumns": "audit_no,field_no",
    "TableColumns": "audit_no,field_no,char_id,num_id,date_id",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "finaudittrail",
    "PKColumns": "audit_no",
    "TableColumns": "pkg,change_date,change_time,change_type,change_note,tabname,colname,old_val,new_val,spiuser,audit_no",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "fincustom",
    "PKColumns": "",
    "TableColumns": "key_name,description,proj_no,install_date,install_programmer,orig_programmer,orig_flg,enable_flg,udf1,udf2,udf3,udf4,udf5",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "fips_codes",
    "PKColumns": "",
    "TableColumns": "code,desc_x,state_id",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "fix_def",
    "PKColumns": "",
    "TableColumns": "ln_type,indx,page_no,slabel,type_check,table_name,help_text,default_val,req,valid_if",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "fix_locn",
    "PKColumns": "",
    "TableColumns": "loccode,locdesc",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "fix_num",
    "PKColumns": "",
    "TableColumns": "next_asset",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "fix_prof",
    "PKColumns": "",
    "TableColumns": "client,system,company,user_1,user_2,user_3,user_4,user_5,low_capital,hi_capital,fix_min_amt,user_asset,next_asset,yr_start_date,fiscal_yr,cafr_yr_end",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "fix_ref",
    "PKColumns": "",
    "TableColumns": "prefx,code,desc_x",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "fixuser",
    "PKColumns": "",
    "TableColumns": "tagno,improvement_num,page_no,ftext1,ftext2,ftext3,ftext4,ftext5,ftext6,ftext7,ftext8,ftext9,ftext10,tcode1,tcode2,tcode3,tcode4,tcode5,tcode6,tcode7,tcode8,tcode9,tcode10,comment1,comment2",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "flsa_cycle_setup",
    "PKColumns": "",
    "TableColumns": "cycle_code,cycle_desc,cycle_calc,days_per_cycle,cycle_start_date,flsa_cycle_y,flsa_cycle_hrs",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "flsa_payroll",
    "PKColumns": "",
    "TableColumns": "empl_no,cycle_code",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "fm_format_defaults",
    "PKColumns": "user_id,format_id",
    "TableColumns": "user_id,format_id,format_default",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "fms_user_fields",
    "PKColumns": "screen_type,screen_number,field_number",
    "TableColumns": "screen_type,screen_number,field_number,field_label,field_order,required_field,field_type,data_type,number_type,data_length,field_scale,field_precision,default_value,default_table,default_column,validation_list,validation_table,code_column,description_column,spi_table,spi_column,spi_screen_number,spi_field_number,spi_field_type,sec_package,sec_subpackage,sec_feature,locked,visible,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "fms_user_rules",
    "PKColumns": "screen_type,screen_number,field_number,group_number,rule_number",
    "TableColumns": "screen_type,screen_number,field_number,group_number,rule_number,rule_operator,rule_value,rule_table,rule_column,rule_screen_number,rule_field_number,where_table,where_column,where_screen_num,where_field_number,where_operator,where_value,and_or_flag,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "fms_user_rules_messages",
    "PKColumns": "screen_type,screen_number,field_number,group_number",
    "TableColumns": "screen_type,screen_number,field_number,group_number,error_message,show_custom_message,show_both,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "fms_user_screen",
    "PKColumns": "screen_type,screen_number",
    "TableColumns": "screen_type,screen_number,form_type,list_type,columns,description,required_screen,sec_package,sec_subpackage,sec_feature,reserved,state_flag,wf_screen,wf_model_id,wf_model_version,dataset_id,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "fmsnxtno",
    "PKColumns": "tab_name",
    "TableColumns": "tab_name,next_no",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "functbl",
    "PKColumns": "",
    "TableColumns": "func_name,description",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "fundtable",
    "PKColumns": "",
    "TableColumns": "fund,fundkey,title",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "fxhist",
    "PKColumns": "",
    "TableColumns": "tagno,improvement_num,trans_date,trans_time,field_name,old_value,new_value,user_id",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "fxhistmult",
    "PKColumns": "",
    "TableColumns": "act,tagno,improvement_num,trans_date,trans_time,user_id,func_name,activity,deporgn,depacct,dep_pct",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "fxinv_upd",
    "PKColumns": "",
    "TableColumns": "controlno,tagno,rec_type,acqdate,des,fund_source,vendor,insurer,mfr,model,serial_no,dept,loccode,grantx,catcode,cond,unitsx,unitcost,initcost,salvage,insvalue,sale_amt,invent,maint,retdate,stats,user_1,user_2,user_3,user_4,user_5,dep_flag,dep_method,estlife,deplife,deporgn,depacct,accdep,curdep,dep_basis,last_post_date,post_togl,prop_fund,cap_asset,func_name,activity,multifunc,po,checkno",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "gasb_fx",
    "PKColumns": "",
    "TableColumns": "fiscal_yr,fund_type,func_name,activity,major_class,beg_bal,adj,additions,deletions,end_bal,accum_dep_bb,accum_dep_adj,accum_dep_add,accum_dep_del,accum_dep_end,change_time,change_date,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "gender_identity_tbl",
    "PKColumns": "",
    "TableColumns": "code,title,federal_code,state_code,report_1_code,report_2_code,report_3_code,report_4_code,report_5_code",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "genledgr",
    "PKColumns": "yr,fund,account",
    "TableColumns": "yr,fund,account,gl_bal1,gl_bal2,gl_bal3,gl_bal4,gl_bal5,gl_bal6,gl_bal7,gl_bal8,gl_bal9,gl_bal10,gl_bal11,gl_bal12,gl_bal13",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "global_search",
    "PKColumns": "search_type,search_id,sequence_num,search_id_type",
    "TableColumns": "search_type,search_id,sequence_num,and_or_flag,table_name,column_name,operator,search_value1,search_value2,notes,change_date_time,change_uid,search_id_type",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "global_user_sso_mapping",
    "PKColumns": "id",
    "TableColumns": "id,global_uid,employee_id,user_id",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "grplife",
    "PKColumns": "",
    "TableColumns": "age,premium",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "grplifew2",
    "PKColumns": "",
    "TableColumns": "empl_no,pay_run,p_m,cont_amt",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "hdeduct",
    "PKColumns": "",
    "TableColumns": "capture_date,empl_no,ded_cd,status,account,start_x,stop_x,beff_date,ded_amt,max_amt,max_fringe,arrears,cont_amt,num_deds,chk_ind,taken_c,taken_m,taken_q,taken_y,taken_i,taken_f,cont_c,cont_m,cont_q,cont_y,cont_i,cont_f,sal_c,sal_m,sal_q,sal_y,sal_f,bank,bt_code,bank_acct,enc_remaining,addl_ded_gross,addl_frng_gross",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "hemployee",
    "PKColumns": "",
    "TableColumns": "capture_date,empl_no,ssn,l_name,f_name,addr1,addr2,city,zip,hire_date,home_orgn,birthdate,base_loc,state_id,orig_hire,prev_lname,email_addr,info_rlease,email_voucher,uid,supervisor_id,personal_email,m_name,name_suffix,preferred_name",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "hemployee_renamed",
    "PKColumns": "",
    "TableColumns": "capture_date,empl_no,ssn,l_name,f_name,m_name,addr1,addr2,city,zip,hire_date,home_orgn,birthdate,base_loc,state_id,orig_hire,prev_lname,email_addr,info_rlease,email_voucher,uid,supervisor_id,personal_email,name_suffix",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "holiday",
    "PKColumns": "cal_type,h_date",
    "TableColumns": "cal_type,h_date,w_flag",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "home_fav_groups",
    "PKColumns": "fav_grp_id",
    "TableColumns": "fav_grp_id,fav_grp_title,user_id,is_display_menu_path",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "home_fav_items",
    "PKColumns": "fav_item_id",
    "TableColumns": "fav_item_id,fav_grp_id,fav_item_name,fav_item_order,callpath,progcall,is_fglrun,is_sub_system",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "home_panel_types",
    "PKColumns": "panel_type",
    "TableColumns": "panel_type,panel_name,panel_min_rows,panel_max_rows,panel_min_cols,panel_max_cols",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "home_session_docs",
    "PKColumns": "session_id,index_id",
    "TableColumns": "session_id,index_id,rpt_name,rpt_path,rpt_create_date,rpt_size,rpt_deleted",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "home_user_panel",
    "PKColumns": "tab_id,panel_order",
    "TableColumns": "tab_id,panel_order,user_id,panel_type,fav_grp_id,panel_title,panel_icon,panel_num_rows,panel_num_cols",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "home_user_ses_hist",
    "PKColumns": "",
    "TableColumns": "session_id,user_id,create_time,expire_time,process_id,client_ip,user_agent",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "home_user_session",
    "PKColumns": "session_id",
    "TableColumns": "session_id,user_id,create_time,process_id,client_ip,user_agent,rpt_status",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "home_user_tab",
    "PKColumns": "tab_id",
    "TableColumns": "tab_id,user_id,tab_order,tab_title",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "hpayrate",
    "PKColumns": "",
    "TableColumns": "capture_date,empl_no,rate_no,primry,group_x,pay_hours,days_worked,hours_day,incl_dock,no_pays,fte,pay_method,pay_cycle,pay_cd,classify,occupied,cal_type,range,step_x,rate,dock_rate,cont_flg,cont_days,override,annl_sal,cont_lim,cont_bal,cont_paid,cont_start,cont_end,pay_start,pay_end,summer_pay,status_x,pyo_date,pyo_rem_pay,pyo_days,pyo_rate,pyo_amt,dock_arrears_amt,dock_pays_remain",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "hpayroll",
    "PKColumns": "",
    "TableColumns": "capture_date,empl_no,pay_freq,card_requ,sp1_amt,sp1_cd,sp2_amt,sp2_cd,sp3_amt,sp3_cd,chk_locn,last_paid,fed_exempt,fed_marital,fed_dep,add_fed,sta_exempt,state_id,pr_state,sta_marital,sta_dep,add_state,loc_exempt,locl,pr_local,loc_marital,loc_dep,add_local,fic_exempt,earn_inc,lv_date,lv1_cd,lv1_bal,lv1_tak,lv1_ear,lv2_cd,lv2_bal,lv2_tak,lv2_ear,lv3_cd,lv3_bal,lv3_tak,lv3_ear,lv4_cd,lv4_bal,lv4_tak,lv4_ear,lv5_cd,lv5_bal,lv5_tak,lv5_ear,lv6_cd,lv6_bal,lv6_tak,lv6_ear,lv7_cd,lv7_bal,lv7_tak,lv7_ear,lv8_cd,lv8_bal,lv8_tak,lv8_ear,lv9_cd,lv9_bal,lv9_tak,lv9_ear,lv10_cd,lv10_bal,lv10_tak,lv10_ear,tearn_c,tearn_m,tearn_q,tearn_y,tearn_ft,ftearn_c,ftearn_m,ftearn_q,ftearn_y,ftearn_ft,fiearn_c,fiearn_m,fiearn_q,fiearn_y,fiearn_ft,mdearn_c,mdearn_m,mdearn_q,mdearn_y,mdearn_ft,stearn_c,stearn_m,stearn_q,stearn_y,stearn_ft,s2earn_c,s2earn_m,l2earn_y,s2earn_y,s2earn_ft,loearn_c,loearn_m,loearn_q,loearn_y,loearn_ft,allow_c,allow_m,allow_q,allow_y,allow_ft,nocash_c,nocash_m,nocash_q,nocash_y,nocash_ft,fedtax_c,fedtax_m,fedtax_q,fedtax_y,fedtax_ft,fictax_c,fictax_m,fictax_q,fictax_y,fictax_ft,medtax_c,medtax_m,medtax_q,medtax_y,medtax_ft,statax_c,statax_m,statax_q,statax_y,statax_ft,st2tax_c,st2tax_m,lt2tax_y,st2tax_y,st2tax_ft,loctax_c,loctax_m,loctax_q,loctax_y,loctax_ft,eic_c,eic_m,eic_q,eic_y,eic_ft,rfiearn_y,rfictax_y,rmdearn_y,rmedtax_y,flsa_cycle_y,flsa_cycle_hrs,flsa_hours,flsa_amount,rfiearn_c,rfiearn_m,rfiearn_q,rfiearn_ft,rfictax_c,rfictax_m,rfictax_q,rfictax_ft,rmdearn_c,rmdearn_m,rmdearn_q,rmdearn_ft,rmedtax_c,rmedtax_m,rmedtax_q,rmedtax_ft,fed_tax_calc_cd,w4_sub_date,non_res_alien,ann_other_inc,ann_deductions,ann_tax_credit,pays_per_year",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "hq_credential",
    "PKColumns": "",
    "TableColumns": "cred_code,cred_desc",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "hq_method",
    "PKColumns": "",
    "TableColumns": "meth_code,meth_desc",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "hq_qualify",
    "PKColumns": "",
    "TableColumns": "qual_code,qual_desc",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "hq_require",
    "PKColumns": "",
    "TableColumns": "req_code,req_desc",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "hq_status",
    "PKColumns": "",
    "TableColumns": "stat_code,stat_desc",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "hrm_aca_audit",
    "PKColumns": "",
    "TableColumns": "user_id,change_date,change_time,change_type,empl_no,classify,pay_code,start_date,check_no,field_changed,orig_data,new_data,row_id",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "hrm_aca_hours",
    "PKColumns": "",
    "TableColumns": "empl_no,pay_run,check_no,empl_type,group_x,classify,pay_code,cal_type,start_date,end_date,work_hours,aca_status,row_id",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "hrm_locn",
    "PKColumns": "",
    "TableColumns": "code,desc_x,addr1,addr2,city,state_id,zip,sch_numb,sch_annx,enroll,pk,kg,g1,g2,g3,g4,g5,g6,g7,g8,g9,g10,g11,g12,un,se,has_prin,full_pt,gender,teach,race,sch_building,state_locn_code,sis_code",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "hrm_prof",
    "PKColumns": "",
    "TableColumns": "trans_date,client,system,company,payroll,personnel,pos_cont,insure,applicant,fundacct,low_orgn_title,low_proj_title,tc_attn,journ_srt,wkrcomp,netpay,np_acct,cr_vend_paymnts,fedtax_id,immdest,dest_name,trans_desc,bank_db,bank_acct,bank_code,emp_name,emp_add,emp_city,emp_state,emp_zip,rpt_year,site_code,misc1,misc2,school_yr,dist_id,add_rte,dollar_rnd,default_ssn,ratnposhst,print_net,tc_sec_check,eeo_def,client_type,p_dedvend,imm_orig_num,opt_trans_rec1,opt_trans_rec2,assign_empl,empl_start,empl_incre,assign_appl,appl_start,appl_incre,print_ytd_ded,leave_processing,retro_dock_code,lien_wage_code,retro_pay_code,ssn_mask_method,paycheck_form,from_addr,bcc_addr,email_subject,attach_pdf,email_body,imm_orig_name,company_id_hdr,company_id_ctrl,orig_dfi_id,dept_location,paycd_list,flag1,flag2,flag3,flag4,flag5,flag6,flag7,flag8,flag9,flag10,print_dirdep,sum_fisc_accr,disable_dock,child_support,adjust_neg_gross",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "hrm_user_employee",
    "PKColumns": "empl_no,screen_number,list_sequence,field_number",
    "TableColumns": "empl_no,screen_number,list_sequence,field_number,field_value,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "hrmstate",
    "PKColumns": "",
    "TableColumns": "state1,state2,state3,state4,state5,state6,state7,state8,state9,state10,state11,state12,state13,state14,state15,state16,state17,state18,state19,state20,state21,state22,state23,state24,state25,state26,state27,state28,state29,state30,state31,state32,state33,state34,state35,state36,state37,state38,state39,state40,state41,state42,state43,state44,state45,state46,state47,state48,state49,state50,state51,state52,state53,state54,state55,state56,state57,state58,state59,state60",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "hrmstate2",
    "PKColumns": "",
    "TableColumns": "state1,state2,state3,state4,state5,state6,state7,state8,state9,state10,state11,state12,state13,state14,state15,state16,state17,state18,state19,state20",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "hrmwork_activities",
    "PKColumns": "",
    "TableColumns": "date_time,source_email,act_subject,act_status,act_notes,dest_uid,act_url,source_uid,activity_xml,row_id,wkf_instance_id,dest_email,workflow_id,delegate_item",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "hrmwork_notifyhist",
    "PKColumns": "",
    "TableColumns": "date_time,source_email,act_subject,act_status,act_notes,dest_uid,act_url,source_uid,activity_xml,row_id,wkf_instance_id,dest_email,workflow_id,delegate_item",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "hrmworkflow_guids",
    "PKColumns": "",
    "TableColumns": "row_id,guid,workflow_type,fk_table,fk_col1,fk_val1,fk_col2,fk_val2,fk_col3,fk_val3,fk_col4,fk_val4",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "hrmworkflow_log",
    "PKColumns": "",
    "TableColumns": "row_id,datetime_stamp,guid,workflow_type,event_type,workflow_event,parameters,info_string",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "hrworkactivityhist",
    "PKColumns": "",
    "TableColumns": "date_time,source_email,act_subject,act_status,act_notes,dest_uid,act_url,source_uid,activity_xml,row_id,wkf_instance_id,dest_email,workflow_id,delegate_item",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "hrworknotification",
    "PKColumns": "",
    "TableColumns": "date_time,source_email,act_subject,act_status,act_notes,dest_uid,act_url,source_uid,activity_xml,row_id,wkf_instance_id,dest_email,workflow_id,delegate_item",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "icalendar",
    "PKColumns": "",
    "TableColumns": "cal_type,description,start_date,end_date,pay_start,pay_end,contract_months,cal_date,date_type,paid_flag",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "icma_date",
    "PKColumns": "",
    "TableColumns": "end_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "icma_setup",
    "PKColumns": "",
    "TableColumns": "plan_code,plan_no,plan_name,irs_no,ded_codes,bar_units,empl_ctr,empr_ctr,loan_flag,date_type",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "import_empuser",
    "PKColumns": "",
    "TableColumns": "empl_no,page_no,import_table,import_rowid,ftext1,ftext2,ftext3,ftext4,ftext5,ftext6,ftext7,ftext8,ftext9,ftext10,tcode1,tcode2,tcode3,tcode4,tcode5,tcode6,tcode7,tcode8,tcode9,tcode10,comment1,comment2",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "importmapdetail",
    "PKColumns": "",
    "TableColumns": "row_id,header_id,columnname,importcolno,importcoltitle",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "importmapheader",
    "PKColumns": "",
    "TableColumns": "row_id,mapname,importname,spiuser,ispublic,restrict_yn,change_uid,change_date,change_time",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "importmapstatic",
    "PKColumns": "",
    "TableColumns": "row_id,header_id,columnname,value",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "infunds",
    "PKColumns": "",
    "TableColumns": "invest_id,dist_itm,project,key_orgn,rev_orgn,proj_acct,amount,invest_value,purch_recv,accrued_int,amort_left",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "inhistdtl",
    "PKColumns": "",
    "TableColumns": "rec_no,itm,acct_type,invest_id,amount,key_orgn,rev_orgn,acct,project,proj_acct,creddeb",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "inhistory",
    "PKColumns": "",
    "TableColumns": "rec_no,journal_no,invest_id,trans_dte,trans_type,trans_meth,vend_no,descript,totamt,date_entered,batch_no,operator,upd_flg,int_flg,period,yr,int_rate",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "inprofile",
    "PKColumns": "",
    "TableColumns": "client,system,company,user_1,user_2,user_3,user_4,user_5,intf,cash,invest_acct,receive,gain_acct,revenue,prem_acct,je_prefix,je_num",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ins_user",
    "PKColumns": "",
    "TableColumns": "invest_id,screen_num,fld01,fld02,fld03,fld04,fld05,fld06,fld07,fld08,fld09,fld10,fld11,fld12,fld13,fld14,fld15,fld16,fld17,fld18,fld19,fld20,fld21,fld22,fld23,fld24,change_date,change_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "instb_screen",
    "PKColumns": "",
    "TableColumns": "screen_num,screen_name,required_screen,pei_restricted,change_date,change_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "instb_screen_spec",
    "PKColumns": "",
    "TableColumns": "screen_num,fld_num,description,help_text,data_type,data_length,default_val,table_check,allow_nulls,valid_if,change_date,change_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "intacct",
    "PKColumns": "",
    "TableColumns": "fund,int_acct",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "integration_errors",
    "PKColumns": "index_id",
    "TableColumns": "index_id,message_id,time_stamp,request,response,integration_type,source_product,status,empl_id,job_number,location",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "integration_errors_renamed",
    "PKColumns": "index_id",
    "TableColumns": "index_id,message_id,time_stamp,request,response,empl_id,integration_type,source_product,status,job_number,location",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "integration_fields",
    "PKColumns": "table_name,field_name",
    "TableColumns": "table_name,field_name",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "interface_setup",
    "PKColumns": "",
    "TableColumns": "interface_name,option_name,option_value",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "interfund_bal_walk",
    "PKColumns": "yr,from_fund_1,to_fund_2",
    "TableColumns": "yr,from_fund_1,to_fund_2,due_to_f2_acct,due_from_f1_acct,due_to_f1_acct,due_from_f2_acct,from_fund_bal_acct,to_fund_bal_acct",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "interviewer",
    "PKColumns": "",
    "TableColumns": "code,desc_x",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "intransact",
    "PKColumns": "",
    "TableColumns": "rec_no,invest_id,trans_dte,trans_type,trans_meth,vend_no,descript,totamt,date_entered,batch_no,operator,upd_flg,int_flg,period,yr,int_rate",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "intransdtl",
    "PKColumns": "",
    "TableColumns": "rec_no,itm,acct_type,invest_id,amount,key_orgn,rev_orgn,acct,project,proj_acct,creddeb,dist_itm",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "intranstyp",
    "PKColumns": "",
    "TableColumns": "trans_type,description",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "inuse_check_no",
    "PKColumns": "disb_gl_key_orgn,check_no",
    "TableColumns": "disb_gl_key_orgn,check_no,gl_cash,operator",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "inuse_no",
    "PKColumns": "",
    "TableColumns": "iname,num",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "inuse_payable",
    "PKColumns": "row_id",
    "TableColumns": "row_id,trans_no,operator,process_date_time",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "inv_prof",
    "PKColumns": "",
    "TableColumns": "client,system,company,period,yr,auto_req,next_req,prof_acct,inter_acct,fill_id,appv_req,start_date,end_date,title1,title2,title3,title4,title5,disc_stock,low_acct,high_acct,require_valid_po,recv_in_war_flg",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "invaudit",
    "PKColumns": "",
    "TableColumns": "invest_id,descript_o,descript_c,mature_dte_o,mature_dte_c,inv_type_o,inv_type_c,pool_no_o,pool_no_c,units_o,units_c,unitcost_o,unitcost_c,amort_left_o,amort_left_c,amort_method_o,amort_method_c,vend_no_o,vend_no_c,face_value_o,face_value_c,purch_dte_o,purch_dte_c,purch_amt_o,purch_amt_c,int_rate_o,int_rate_c,int_period_o,int_period_c,reinvest_o,reinvest_c,effective_int_o,effective_int_c,market_val_o,market_val_c,market_dte_o,market_dte_c,compound_freq_o,compound_freq_c,pay_freq_o,pay_freq_c,user1_o,user1_c,user2_o,user2_c,user3_o,user3_c,user4_o,user4_c,user5_o,user5_c,recved_dte_o,recved_dte_c,recved_int_o,recved_int_c,accrued_dte_o,accrued_dte_c,accrued_int_o,accrued_int_c,reinvest_dte_o,reinvest_dte_c,reinvest_amt_o,reinvest_amt_c,sale_dte_o,sale_dte_c,sale_amt_o,sale_amt_c,invest_acct_o,invest_acct_c,gain_acct_o,gain_acct_c,cash_o,cash_c,receive_o,receive_c,revenue_o,revenue_c,intf_o,intf_c,prem_acct_o,prem_acct_c,purch_recv_o,purch_recv_c,purch_value_o,purch_value_c,int_flg_o,int_flg_c,mature_flg_o,mature_flg_c,annual_rate_o,annual_rate_c,pf_type_o,pf_type_c,stampid,stampdate,stamptime,opt",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "invcomm",
    "PKColumns": "",
    "TableColumns": "stock_no,measure,desc1,desc2,desc3,desc4,desc5,category,allow_bo,ord_iss,lead_time,cr_acct,dr_acct,price1,date1,vend1,ven_nam1,price2,date2,vend2,ven_nam2,price3,date3,vend3,ven_nam3,markup,rev_acct,auto_price",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "investment",
    "PKColumns": "",
    "TableColumns": "invest_id,descript,mature_dte,inv_type,pool_no,units,unitcost,amort_left,amort_method,vend_no,face_value,purch_dte,purch_amt,int_rate,int_period,reinvest,effective_int,market_val,market_dte,compound_freq,pay_freq,user1,user2,user3,user4,user5,recved_dte,recved_int,accrued_dte,accrued_int,reinvest_dte,reinvest_amt,sale_dte,sale_amt,invest_acct,gain_acct,cash,receive,revenue,intf,prem_acct,purch_recv,purch_value,int_flg,mature_flg,annual_rate,pf_type",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "invlocn",
    "PKColumns": "",
    "TableColumns": "locn,address1,address2,address3,address4,person,key_orgn,adj_orgn,adj_acct",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "invrecom",
    "PKColumns": "",
    "TableColumns": "req_no,line_no,stock_no,quantity,back_order,price,amount,filled,fill_date,key_orgn,proj,account,proj_acct,rstatus,ar_date,markup,cost",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "invreq",
    "PKColumns": "",
    "TableColumns": "req_no,locn,requested,require,printed,ship_code,person,remarks,req_yr",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "invtory",
    "PKColumns": "locn,stock_no",
    "TableColumns": "locn,stock_no,ro_point,safe_point,ro_quantity,price,cost,on_hand,requested,back_order,on_order,deliv_date,discontinued,ytd_use,ytd_pur,last_ord,last_issued,last_recv,user1,user2,user3,user4,user5,l_po_no,l_po_line,w_area,aisle,bin_shelf,cr_acct,dr_acct,markup,rev_acct",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "invtran",
    "PKColumns": "",
    "TableColumns": "locn,stock_no,req_no,req_line_no,vend_no,price,quantity,trans_amt,trans_date,tran_type,key_orgn,account,proj,proj_acct,billed,person,remarks,po_no,po_line_no,operator,fill_id,ship_code,pur_qty,yr,bill_per,lyr_use,cost",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "invtype",
    "PKColumns": "",
    "TableColumns": "inv_type,descript",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "invuse",
    "PKColumns": "",
    "TableColumns": "locn,stock_no,yr,ship_code,yr_iss,issue1,issue2,issue3,issue4,issue5,issue6,issue7,issue8,issue9,issue10,issue11,issue12",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "irs_country_codes",
    "PKColumns": "",
    "TableColumns": "country_cd,country_name,addr_format",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ischedule",
    "PKColumns": "",
    "TableColumns": "batch_no,eff_date,schedule,desc_x,hs_flag,days_worked,hours_day,bn_flag,state_hours_day,step,range_01,range_02,range_03,range_04,range_05,range_06,range_07,range_08,range_09,range_10,range_11,range_12,range_13,range_14,range_15,range_16,range_17,range_18,range_19,range_20,range_21,range_22,range_23,range_24,range_25,range_26,range_27,range_28,range_29,range_30,range_31,range_32,range_33,range_34,range_35,range_36,range_37,range_38,range_39,range_40,range_41,range_42,range_43,range_44,range_45,range_46,range_47,range_48,range_49,range_50,range_51,range_52,range_53,range_54,range_55,range_56,range_57,range_58,range_59,range_60,range_61,range_62,range_63,range_64,range_65,range_66,range_67,range_68,range_69,range_70,range_71,range_72,range_73,range_74,range_75,range_76,range_77,range_78,range_79,range_80,range_81,range_82,range_83,range_84,range_85,range_86,range_87,range_88,range_89,range_90,range_91,range_92,range_93,range_94,range_95,range_96,range_97,range_98,range_99",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "it_audit",
    "PKColumns": "",
    "TableColumns": "yr,stampid,stampdate,stamptime,std_phase,iteration,key_orgn,act,ledger",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "it_expledgr",
    "PKColumns": "",
    "TableColumns": "yr,iteration,key_orgn,account,base_amt,new_amt,freeze,stampid,stampdate,stamptime",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "it_phase",
    "PKColumns": "",
    "TableColumns": "yr,phase_id,description,label_1,label_2,final_exp,final_rev,final_proj",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "it_proledgr",
    "PKColumns": "",
    "TableColumns": "yr,iteration,key_orgn,account,base_amt,new_amt,freeze,stampid,stampdate,stamptime",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "it_psavdist",
    "PKColumns": "",
    "TableColumns": "orgn_proj,acct,rec_type,iteration,yr",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "it_revledgr",
    "PKColumns": "",
    "TableColumns": "yr,iteration,key_orgn,account,base_amt,new_amt,freeze,stampid,stampdate,stamptime",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "it_stat",
    "PKColumns": "",
    "TableColumns": "yr,std_phase,key_orgn,iteration,saved,ledger,stampid,stampdate,stamptime",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "iteration",
    "PKColumns": "",
    "TableColumns": "yr,iteration,phase_id,description,label_1,label_2",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "iternote",
    "PKColumns": "",
    "TableColumns": "yr,iteration,line_no,note",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "itimecard",
    "PKColumns": "",
    "TableColumns": "row_id,empl_no,pay_run,classify,pay_code,hours,payrate,amount,orgn,account,proj,pacct,tax_ind,pay_cycle,flsa_cycle,post_flg,status_flg,start_date,stop_date,lv_code,lv_hrs,remarks,check_date,sub_id,sub_pay_code,sub_pay_class,sub_pay_rate,sub_amt_paid,sub_loc,sub_tax_ind,sub_orgn,sub_acct,sub_start,sub_stop,sub_hrs,load_date,load_user,change_date,change_user",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "jac_employee",
    "PKColumns": "",
    "TableColumns": "empl_no,admin_flag,viewer_flag,super_flag",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "je_nums",
    "PKColumns": "",
    "TableColumns": "code,je_number,yr",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "jeaprv_hist",
    "PKColumns": "row_id",
    "TableColumns": "row_id,yr,je_number,control_no,action,comment,action_date,lvl,approved_by,approval_level,app_empl_no,del_empl_no,action_time,assigned_date,assigned_time",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "jenote",
    "PKColumns": "",
    "TableColumns": "je_number,lino,description",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "job_data",
    "PKColumns": "row_id",
    "TableColumns": "job_no,key_value1,key_value2,key_value3,key_value4,key_value5,key_value6,key_value7,key_value8,key_value9,status,create_when,create_who,update_when,update_who,row_id",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "job_inv",
    "PKColumns": "",
    "TableColumns": "empl_no,orgn,classify,contract_salary",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "job_master",
    "PKColumns": "job_no",
    "TableColumns": "job_no,userid,job_type,job_status,job_desc,start_dt,end_dt,job_progress,job_progress_dt,doc_id,create_when,create_who,update_when,update_who,row_id,output",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "job_tabl",
    "PKColumns": "",
    "TableColumns": "job_code,job_type,sub_type,job_desc,pay_code,pay_type,units_day,pay_rate,job_class,orgn,account",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "jobcategory",
    "PKColumns": "",
    "TableColumns": "category,title,ref_link,certpage_flag",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "jobopening",
    "PKColumns": "",
    "TableColumns": "job_class,category,job_no,filled,job_title,certificate,post_date,deadline,eeo_category,responsibility,requirement,userdef1,userdef1text,userdef2,userdef2text,userdef3,userdef3text,userdef4,userdef4text,userdef5,userdef5text,userdef6,userdef6text,userdef7,userdef7text,userdef8,userdef8text,userdef9,userdef9text,userdef10,userdef10text,info_link,eeo_group",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "jobtable",
    "PKColumns": "",
    "TableColumns": "code,desc_x",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "kpi_criteria",
    "PKColumns": "tab_id,panel_order,key_value,key_criteria",
    "TableColumns": "tab_id,panel_order,key_value,key_criteria",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "kpi_expbudact",
    "PKColumns": "key_orgn,account",
    "TableColumns": "key_orgn,account,fund,orgn1,orgn2,orgn3,orgn4,orgn5,orgn6,orgn7,orgn8,orgn9,key_title,acct_title,bud,per,enc,exp,act,bal,create_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "lastcalc",
    "PKColumns": "",
    "TableColumns": "pay_run,indicator,calc_date,calc_time,calc_id",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "leaveaprv",
    "PKColumns": "request_id,lvl,association_id",
    "TableColumns": "request_id,lvl,association_id,association_seq,app_empl_no,del_empl_no,spec_leave_flag,act,action_date,comment,approved_by",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "leaveaprv_hist",
    "PKColumns": "row_id",
    "TableColumns": "row_id,hist_date,hist_time,request_id,lvl,association_id,association_seq,app_empl_no,del_empl_no,spec_leave_flag,act,action_date,comment,approved_by,approval_level",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "leaverequest",
    "PKColumns": "request_id",
    "TableColumns": "request_id,empl_no,pay_code,leave_code,from_date,to_date,leave_units,notes,leave_status,request_date,attend_rowid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "levtable",
    "PKColumns": "lv_code",
    "TableColumns": "lv_code,title,ck_title,acc_type,acc_rate,lwop_acct,max_acc,years,exc_meth,roll_lim,roll_code,max_earn,unused_pay_meth,unused_pay,lv_unit,emp_status,prt_flg",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "libattachstatus",
    "PKColumns": "",
    "TableColumns": "group_desc,key_field1,key_field2,key_field3,key_field4,key_field5,num_attach",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "libcolcheck",
    "PKColumns": "colcheckno",
    "TableColumns": "colcheckno,coltable,colcolumn,colcheckprop,colchecksql1,colerrorif1,colerrormsg1,colchecksql2,colerrorif2,colerrormsg2,colchecksql3,colerrorif3,colerrormsg3,colcheckval,colerrorifv,colerrormsgv,coldefaultsql,coldefaultval,colchecknull",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "librefcolumns",
    "PKColumns": "refcolumn",
    "TableColumns": "refcolumn,refcolumnname,refcolumndisplay,reftable,createuserid,createstamp,changeuserid,changestamp",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "libreftables",
    "PKColumns": "reftable",
    "TableColumns": "reftable,reftablename,reftabledisplay,reftabledesc,reftablegrp,createuserid,createstamp,changeuserid,changestamp",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "lo2table",
    "PKColumns": "",
    "TableColumns": "location,pay_freq,marital,ear,amt,per",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "lo3table",
    "PKColumns": "",
    "TableColumns": "location,pay_freq,marital,cred",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "loc_cross",
    "PKColumns": "",
    "TableColumns": "yr,bid_no,location,ship_code",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "location",
    "PKColumns": "",
    "TableColumns": "loccode,locdesc",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "loctable",
    "PKColumns": "location,pay_freq,marital",
    "TableColumns": "location,description,pay_freq,marital,account,stan_rate,stan_min,stan_max,mar_exemp,depend,supp_per",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "log_detail",
    "PKColumns": "",
    "TableColumns": "log_id,rec_type,empl_no,edu_id,f_name,l_name,m_name,source,code,descr,action,message",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "log_header",
    "PKColumns": "log_id",
    "TableColumns": "log_id,task_his_id,file_info,total_cnt,succeed_cnt,failed_cnt,change_uid,info",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "lts_tabl",
    "PKColumns": "",
    "TableColumns": "pay_code,beg_day1,pay_cd1,pay_rate1,retro_cd1,retro1,beg_day2,pay_cd2,pay_rate2,retro_cd2,retro2,beg_day3,pay_cd3,pay_rate3,retro_cd3,retro3,beg_day4,pay_cd4,pay_rate4,retro_cd4,retro4,beg_day5,pay_cd5,pay_rate5,retro_cd5,retro5",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mailmess",
    "PKColumns": "",
    "TableColumns": "message_no,user_id,message_date,message",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "majmin",
    "PKColumns": "",
    "TableColumns": "empl_no,dtype,school,deg_date,seq,major,maj_flg,minor,min_flg",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mapckhld",
    "PKColumns": "",
    "TableColumns": "vend_no,check_no,check_dt,disb_fund",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mapckhst",
    "PKColumns": "",
    "TableColumns": "user_id,old_chk_no,new_chk_bo,prt_date,disb_fund",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mchkhist",
    "PKColumns": "",
    "TableColumns": "user_id,old_chkno,new_chkno,prt_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mchkhld",
    "PKColumns": "",
    "TableColumns": "srt_no,check_no,iss_date,empl_no",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "menu_applications",
    "PKColumns": "app_id",
    "TableColumns": "app_id,title,package,subpackage,func,spi_defined",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "menu_custom_opts",
    "PKColumns": "base_progcall,base_callpath",
    "TableColumns": "base_progcall,base_callpath,cust_progcall,cust_callpath,enable_flg,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "menu_groups",
    "PKColumns": "app_id,tab_id,group_id",
    "TableColumns": "app_id,tab_id,group_id,title,package,subpackage,func,spi_defined",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "menu_options",
    "PKColumns": "app_id,tab_id,group_id,option_id",
    "TableColumns": "app_id,tab_id,group_id,option_id,title,progcall,callpath,package,subpackage,func,is_fglrun,is_sub_system,spi_defined",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "menu_options_lic",
    "PKColumns": "id",
    "TableColumns": "id,app_id,app_title,app_package,app_subpackage,app_func,app_spi_defined,tab_id,tab_title,tab_package,tab_subpackage,tab_func,tab_spi_defined,group_id,group_title,group_package,group_subpackage,group_func,group_spi_defined,option_id,option_title,progcall,callpath,package,subpackage,func,is_fglrun,is_sub_system,spi_defined,sectb_license_id,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "menu_persnl_grps",
    "PKColumns": "",
    "TableColumns": "grp_num,grp_title,uid,package,exe_location",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "menu_persnl_opts",
    "PKColumns": "",
    "TableColumns": "grp_num,uid,opt_num,option_name,callpath,progcall,desk_icon,package,btn_num",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "menu_tabs",
    "PKColumns": "tab_id",
    "TableColumns": "tab_id,title,package,subpackage,func,spi_defined",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "menutb_activity",
    "PKColumns": "",
    "TableColumns": "userid,menu_path,choice,choicedesc,package,subpack,func,stampdate,stamptime",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "menutb_cfg",
    "PKColumns": "",
    "TableColumns": "customer,change_date,change_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "menutb_items",
    "PKColumns": "",
    "TableColumns": "menu_path,choice,choicedesc,progcall,callpath,run_command,package,subpack,func,change_date,change_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "menutb_lock",
    "PKColumns": "",
    "TableColumns": "package,subpack,func,num_users",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "menutb_printers",
    "PKColumns": "",
    "TableColumns": "building,description,pr_command,quiet_mode,copies_opt,change_date,change_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "menutb_rebuild",
    "PKColumns": "",
    "TableColumns": "spiuser,package,subpack,func",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "menutb_termtype",
    "PKColumns": "",
    "TableColumns": "term_type,seq_132,seq_80",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "menutb_titles",
    "PKColumns": "",
    "TableColumns": "menu_path,title,menuid,change_date,change_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "menutool",
    "PKColumns": "choice",
    "TableColumns": "choice,group_id,choiceparent,action_index,action_name,description,image,comment,item_type,showtoolitem",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "menutool_groups",
    "PKColumns": "group_id",
    "TableColumns": "group_id,group_type,group_name,parent_group_id,gdc_order,gwc_order,gdc_title,gwc_title,group_orientation",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "menutool_items",
    "PKColumns": "item_id",
    "TableColumns": "item_id,gdc_group_id,gwc_group_id,item_type,action_name,action_desc,gdc_order,gwc_order,gdc_image,gwc_image,gdc_showtoolitem,gwc_showtoolitem,gwc_toolbar_order,item_orientation,tooltiptext",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "migration",
    "PKColumns": "id",
    "TableColumns": "id,name,project_name,run_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mmax_bpayrate",
    "PKColumns": "",
    "TableColumns": "eff_date,empl_no,classify,fam_code,grd_code,cont_cyc",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mmax_budpr",
    "PKColumns": "",
    "TableColumns": "empl_no,rate_no,pos,fam_code,grd_code,bud_incr,amt_incr,prct_inc,tea_amt,curr_days,curr_hours,status_x,cont_cyc,incl_dock",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mmax_hpayrate",
    "PKColumns": "",
    "TableColumns": "capture_date,empl_no,rate_no,fam_code,grd_code,cont_cyc",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mmax_payrate",
    "PKColumns": "",
    "TableColumns": "empl_no,rate_no,fam_code,grd_code,cont_cyc",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mmax_prct",
    "PKColumns": "",
    "TableColumns": "mid_pct,max_pct,incr_method",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mncknote",
    "PKColumns": "",
    "TableColumns": "check_no,lino,description",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrapcrdetail",
    "PKColumns": "",
    "TableColumns": "apcredt_no,itemno,cust_no,servcode,inv_no,trx_type,total_pd,tot_paid,tot_taxpaid,rcpsyst_number",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrapcrdistrb",
    "PKColumns": "",
    "TableColumns": "apcredt_no,itemno,seq_no,servcode,inv_no,fund,account,debit_amount,credit_amount",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrapcrhead",
    "PKColumns": "",
    "TableColumns": "apcredt_no,batch_no,rec_stat,rec_source,trx_source,cust_no,crd_date,amt_app,amt_tax,amt_nontax,acomments,post_date,fa_intf_date,stmt_date,ent_operator,ent_date,upd_operator,upd_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrbillitem",
    "PKColumns": "",
    "TableColumns": "itemcode,itemdesc,catcode,servcode,unitprice,unitname,salestax,penalty,interest,rev_orgn,rev_account,ent_operator,ent_date,upd_operator,upd_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrbinvdetl",
    "PKColumns": "",
    "TableColumns": "servcode,inv_no,itemno,itemtype,itemcode,itemdesc,unitname,qty,unitprice,tot_price,distrtype,salestax,taxamount",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrbinvdistrb",
    "PKColumns": "",
    "TableColumns": "servcode,inv_no,itemno,seq_no,rev_orgn,rev_acct,proj,proj_rev_acct,prcnt,distr_amount,tax_amount,tax_code,taxfund,taxliaacct,taxrcvacct,taxcshacct,distr_fund,receivable_acct,cash_acct",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrbinvhead",
    "PKColumns": "",
    "TableColumns": "servcode,inv_no,trx_source,trx_type,inv_stat,inv_date,cust_no,s_addrcode,po_number,termcode,due_date,icomments,tot_invoice,tot_tax,tot_due,prntddate,postddate,intfdate,stmtdate,batch_no,iv_source,ent_operator,ent_date,upd_operator,upd_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrbrefund",
    "PKColumns": "",
    "TableColumns": "refund_no,cust_no,ref_date,ref_stat,refr_no,ref_amt,rcomments,unapp_orgn,unapp_acct,ref_orgn,ref_acct,vend_no,batch_no,ref_source,post_date,fa_intf_date,stmnt_date,ent_operator,ent_date,upd_operator,upd_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrcategory",
    "PKColumns": "",
    "TableColumns": "catcode,catdesc,ent_operator,ent_date,upd_operator,upd_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrclnttype",
    "PKColumns": "",
    "TableColumns": "typecode,typedesc,ent_operator,ent_date,upd_operator,upd_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrcustaddr",
    "PKColumns": "",
    "TableColumns": "cust_no,s_addrcode,s_custname1,s_custname2,s_addr1,s_addr2,s_city,s_state,s_zipcode,s_zipext,taxcode",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrcustbill",
    "PKColumns": "",
    "TableColumns": "cust_no,unapplcredit,total_due,pastdue1,pastdue2,pastdue3,pastdue4,ftd_charges,ftd_payments,cur_billdue,cur_taxdue,cur_pendue,cur_intdue,del_billdue,del_taxdue,del_pendue,del_intdue,lst_billedte,lst_paydte,lst_adjust,lst_agedte,lst_deldte,lst_intdte,lst_statdte,tot_writeoff,tot_taxwriteoff,lst_wroffdate",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrcustomer",
    "PKColumns": "",
    "TableColumns": "cust_no,stat,b_custname1,b_custname2,sortname,fin,pid,b_addr1,b_addr2,b_city,b_state,b_zipcode,b_zipext,s_addrcode,phone1,contact1,phone2,contact2,faxnumber,clnttype,taxcode,pen_code,int_code,termcode,invmessage,rcpmessage,state_ind,state_type,duncode,vend_no,cycle,ent_operator,ent_date,upd_operator,upd_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrcustservice",
    "PKColumns": "",
    "TableColumns": "cust_no,servcode,stat,beg_date,end_date,pen_code,int_code,user_chr01,user_chr02,user_chr03,user_chr04,user_chr05,user_dte01,user_dte02,user_dte03,user_dte04,user_dte05,user_dec01,user_dec02,user_dec03,user_dec04,user_dec05,total_due,pastdue1,pastdue2,pastdue3,pastdue4,ftd_charges,ftd_payments,cur_billdue,cur_taxdue,cur_pendue,cur_intdue,del_billdue,del_taxdue,del_pendue,del_intdue,lst_billdte,lst_paydte,lst_adjust,lst_agedte,lst_deldte,lst_intdte,tot_writeoff,tot_taxwriteoff,lst_wroffdate",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrdfltcust",
    "PKColumns": "",
    "TableColumns": "stat,auto_address,auto_service,b_city,b_state,b_zipcode,b_zipext,phone1,phone2,faxnumber,clnttype,taxcode,pen_code,int_code,termcode,invmessage,rcpmessage,state_ind,state_type,duncode,cycle,ent_operator,ent_date,upd_operator,upd_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrdfltform",
    "PKColumns": "",
    "TableColumns": "company1,company2,addr1,addr2,city,state,zipcode,zipext,phone1,faxnumber,iprntaddr,iprntlbls,sprntaddr,sprntlbls,ent_operator,ent_date,upd_operator,upd_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrdistdesc",
    "PKColumns": "",
    "TableColumns": "dist_key,discrip",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrdistdetl",
    "PKColumns": "",
    "TableColumns": "dist_key,dist_seq,dist_orgn,orgn_acct,dist_proj,proj_acct,dist_per,taxfund,taxliaacct,taxrcvacct,taxcshacct,distr_fund,receivable_acct,cash_acct",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrdtnote",
    "PKColumns": "",
    "TableColumns": "note_no,seq_no,note_message",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrdunning",
    "PKColumns": "",
    "TableColumns": "duncode,dunmess1,dunmess2,duncurr1,duncurr2,dun1_1,dun1_2,dun2_1,dun2_2,dun3_1,dun3_2,dun4_1,dun4_2,ent_operator,ent_date,upd_operator,upd_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrhdnote",
    "PKColumns": "",
    "TableColumns": "cust_no,note_date,note_no,memocode,reminddate,ref,refnumber,ent_operator,ent_date,upd_operator,upd_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrhistory",
    "PKColumns": "",
    "TableColumns": "seq_no,cust_no,jrnl,jrnl_date,servcode,jrnl_ref,item_no,total_amount",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrinterest",
    "PKColumns": "",
    "TableColumns": "int_code,int_basis,int_pct,int_dayinyear,int_minimum,int_least,int_account,int_recv,int_cash,ent_operator,ent_date,upd_operator,upd_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrjournal",
    "PKColumns": "",
    "TableColumns": "seq_no,jrnl,jrnl_date,servcode,jrnl_ref,batch_no,fund,key_orgn,account,project,proj_acct,debit_amount,credit_amount,fa_post_date,fa_jrnl,fa_post_oper,fa_batch_no",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrminvdetl",
    "PKColumns": "",
    "TableColumns": "servcode,minv_no,itemno,itemtype,itemcode,itemdesc,qtytype,qty,unitprice,salestax,distrtype",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrminvdistrb",
    "PKColumns": "",
    "TableColumns": "servcode,minv_no,itemno,seq_no,rev_orgn,rev_acct,proj,proj_acct,prcnt,taxfund,taxliaacct,taxrcvacct,taxcshacct,distr_fund,rec_acct,cash_acct",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrminvhead",
    "PKColumns": "",
    "TableColumns": "servcode,minv_no,minv_stat,bill_cycle,start_date,end_date,termcode,minv_date,mdue_date,icomments,ent_operator,ent_date,upd_operator,upd_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrnxtnum",
    "PKColumns": "",
    "TableColumns": "servcode,ref,refnumber",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrobajdetl",
    "PKColumns": "",
    "TableColumns": "servcode,biladj_no,itemno,itemtype,qty,unitprice,tot_price,salestax,taxamount,newqty,newunitprice,newtot_price,newsalestax,newtaxamount,adjqty,adjunitprice,adjtot_price,adjsalestax,adjtaxamount",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrobajdistrb",
    "PKColumns": "",
    "TableColumns": "servcode,biladj_no,invitemno,invseq_no,inv_no,rev_orgn,rev_acct,proj,proj_rev_acct,distr_amount,tax_amount,taxfund,taxliaacct,taxrcvacct,distr_fund,receivable_acct",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrobajhead",
    "PKColumns": "",
    "TableColumns": "servcode,biladj_no,trx_source,trx_type,adj_stat,adj_date,inv_no,cust_no,bcomments,tot_invoice,tot_tax,tot_due,newtot_invoice,newtot_tax,newtot_due,adjtot_invoice,adjtot_tax,adjtot_due,prntddate,postddate,intfdate,stmtdate,batch_no,iv_source,ent_operator,ent_date,upd_operator,upd_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mroinvdetl",
    "PKColumns": "",
    "TableColumns": "servcode,inv_no,itemno,itemtype,itemcode,itemdesc,unitname,qty,unitprice,tot_price,distrtype,salestax,taxamount",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mroinvdistrb",
    "PKColumns": "",
    "TableColumns": "servcode,inv_no,itemno,seq_no,rev_orgn,rev_acct,proj,proj_rev_acct,prcnt,distr_amount,tax_amount,tax_code,taxfund,taxliaacct,taxrcvacct,taxcshacct,distr_fund,receivable_acct,cash_acct",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mroinvhead",
    "PKColumns": "",
    "TableColumns": "servcode,inv_no,trx_source,trx_type,inv_stat,inv_date,cust_no,s_addrcode,po_number,termcode,due_date,icomments,tot_invoice,tot_tax,tot_due,prntddate,postddate,intfdate,stmtdate,batch_no,iv_source,ent_operator,ent_date,upd_operator,upd_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mropdistrb",
    "PKColumns": "",
    "TableColumns": "inv_no,itemno,seq_no,billdue,taxdue,bill_paid,tax_paid,bill_adj,taxbill_adj,pay_adj,taxpay_adj,wof_adj,taxwof_adj",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mropenitem",
    "PKColumns": "",
    "TableColumns": "servcode,inv_no,trx_type,inv_date,cust_no,due_date,total_due,tot_billed,tot_taxbilled,tot_paid,tot_taxpaid,lst_paiddate,tot_billadjust,tot_taxbilladjust,lst_badjdate,tot_payadjust,tot_taxpayadjust,lst_padjdate,tot_writeoff,tot_taxwriteoff,writeoffdate,pen_code,int_code",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrowofdetail",
    "PKColumns": "",
    "TableColumns": "wofadj_no,itemno,cust_no,servcode,inv_no,trx_type,total_wo,tot_wof,tot_taxwof",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrowofdistrb",
    "PKColumns": "",
    "TableColumns": "wofadj_no,itemno,seq_no,servcode,inv_no,fund,key_orgn,account,proj,proj_acct,debit_amount,credit_amount",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrowofhead",
    "PKColumns": "",
    "TableColumns": "wofadj_no,batch_no,wof_stat,wof_source,trx_source,cust_no,wof_date,wof_ref,amt_wof,amt_tax,amt_nontax,rcomments,post_date,fa_intf_date,stmt_date,ent_operator,ent_date,upd_operator,upd_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrpadjdetail",
    "PKColumns": "",
    "TableColumns": "payadj_no,itemno,cust_no,servcode,inv_no,trx_type,total_pd,tot_paid,tot_taxpaid,newtotal_pd,newtot_paid,newtot_taxpaid,adjtotal_pd,adjtot_paid,adjtot_taxpaid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrpadjdistrb",
    "PKColumns": "",
    "TableColumns": "payadj_no,itemno,seq_no,servcode,inv_no,fund,account,debit_amount,credit_amount",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrpadjhead",
    "PKColumns": "",
    "TableColumns": "payadj_no,batch_no,adj_stat,adj_source,trx_source,receipt_no,cust_no,adj_date,crd_card_code,amt_rec,amt_app,amt_unapp,amt_tax,amt_nontax,new_rec,new_app,new_unapp,new_tax,new_nontax,adj_rec,adj_app,adj_unapp,adj_tax,adj_nontax,acomments,post_date,fa_intf_date,stmt_date,ent_operator,ent_date,upd_operator,upd_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrpenalty",
    "PKColumns": "",
    "TableColumns": "pen_code,pen_type,pen_amount,pen_pct,pen_minimum,pen_least,pen_account,pen_recv,pen_cash,ent_operator,ent_date,upd_operator,upd_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrprofile",
    "PKColumns": "",
    "TableColumns": "client,system,vers,company,credit_orgn,credit_account,auto_invoice,auto_customer,maxinvlines,aging_1st,aging_2nd,aging_3rd,aging_4th,lastaging,laststatement,lastpurge,logaccess,default_serv,ent_operator,ent_date,upd_operator,upd_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrrcpbatch",
    "PKColumns": "",
    "TableColumns": "rcp_number,rcp_line,rcp_date,scan_line,rev_code,bill_sys,intfce,cust_id,inv_number,inv_line,item_code,dist_line,rcpfund,rcpcash,recv_no,recv_acct,crd_orgn,crd_acct,project,proj_acct,serv_order,dtl_amount,intf_date,intf_operator,intf_batch",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrrcpbdetail",
    "PKColumns": "",
    "TableColumns": "receipt_no,itemno,cust_no,servcode,inv_no,trx_type,total_pd,tot_paid,tot_taxpaid,rcpsyst_number",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrrcpbhead",
    "PKColumns": "",
    "TableColumns": "receipt_no,batch_no,rec_stat,rec_source,trx_source,cust_no,rec_date,pay_type,pay_ref,crd_card_code,amt_rec,amt_app,amt_unapp,amt_tax,amt_nontax,rcomments,post_date,fa_intf_date,stmt_date,ent_operator,ent_date,upd_operator,upd_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrrcpidetail",
    "PKColumns": "",
    "TableColumns": "receipt_no,itemno,cust_no,servcode,inv_no,trx_type,total_pd,tot_paid,tot_taxpaid,rcpsyst_number",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrrcpihead",
    "PKColumns": "",
    "TableColumns": "receipt_no,batch_no,rec_stat,rec_source,trx_source,cust_no,rec_date,pay_type,pay_ref,crd_card_code,amt_rec,amt_app,amt_unapp,amt_tax,amt_nontax,rcomments,post_date,fa_intf_date,stmt_date,ent_operator,ent_date,upd_operator,upd_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrrcptdetail",
    "PKColumns": "",
    "TableColumns": "receipt_no,itemno,cust_no,servcode,inv_no,trx_type,total_pd,tot_paid,tot_taxpaid,rcpsyst_number",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrrcptdistrb",
    "PKColumns": "",
    "TableColumns": "receipt_no,itemno,seq_no,servcode,inv_no,fund,account,debit_amount,credit_amount",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrrcpthead",
    "PKColumns": "",
    "TableColumns": "receipt_no,batch_no,rec_stat,rec_source,trx_source,cust_no,rec_date,pay_type,pay_ref,crd_card_code,amt_rec,amt_app,amt_unapp,amt_tax,amt_nontax,rcomments,post_date,fa_intf_date,stmt_date,ent_operator,ent_date,upd_operator,upd_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrrefund",
    "PKColumns": "",
    "TableColumns": "refund_no,cust_no,ref_date,ref_stat,refr_no,ref_amt,rcomments,unapp_orgn,unapp_acct,ref_orgn,ref_acct,vend_no,batch_no,ref_source,post_date,fa_intf_date,stmnt_date,ent_operator,ent_date,upd_operator,upd_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrrinvdetl",
    "PKColumns": "",
    "TableColumns": "servcode,rinv_no,itemno,itemtype,itemcode,itemdesc,unitname,qty,unitprice,tot_price,distrtype,salestax,taxamount",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrrinvdistrb",
    "PKColumns": "",
    "TableColumns": "servcode,rinv_no,itemno,seq_no,rev_orgn,rev_acct,proj,proj_rev_acct,prcnt,distr_amount,tax_amount,tax_code,taxfund,taxliaacct,taxrcvacct,taxcshacct,distr_fund,receivable_acct,cash_acct",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrrinvhead",
    "PKColumns": "",
    "TableColumns": "servcode,rinv_no,trx_source,trx_type,rinv_stat,start_dte,end_dte,bill_cycle,no_of_inv,inv_to_date,lst_billdte,nxt_billdte,dayinmonth,clnttype,cust_no,s_addrcode,po_number,termcode,icomments,tot_invoice,tot_tax,tot_due,iv_source,ent_operator,ent_date,upd_operator,upd_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrsalestax",
    "PKColumns": "",
    "TableColumns": "taxcode,taxdesc,taxname,taxaddress1,taxaddress2,taxcity,taxstate,taxzip,taxext,phone1,taxpct,tax_fund,tax_account,ent_operator,ent_date,upd_operator,upd_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrservice",
    "PKColumns": "",
    "TableColumns": "servcode,servdesc,stat,labl_fld01,labl_fld02,labl_fld03,labl_fld04,labl_fld05,labl_dte01,labl_dte02,labl_dte03,labl_dte04,labl_dte05,labl_dec01,labl_dec02,labl_dec03,labl_dec04,labl_dec05,dist_fund,rec_account,cash_account,rev_orgn,rev_account,tax_account,proj,proj_acct,pen_code,pen_account,pen_recv,pen_cash,int_code,int_account,int_recv,int_cash,writeoff_acct,ent_operator,ent_date,upd_operator,upd_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "mrterms",
    "PKColumns": "",
    "TableColumns": "termcode,termdesc,termdays,ent_operator,ent_date,upd_operator,upd_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "multiasset",
    "PKColumns": "",
    "TableColumns": "tagno,improvement_num,func_name,activity,deporgn,depacct,dep_pct",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "netdist",
    "PKColumns": "",
    "TableColumns": "vend_no,due_date,fund_grp,pay_run,amountx,tran_type,hold_flg",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "netdist2",
    "PKColumns": "",
    "TableColumns": "fund,gross,tax_deds,ret_deds,oth_deds,fringe",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "newhire",
    "PKColumns": "request_id",
    "TableColumns": "request_id,req_empl_no,appl_id,f_name,m_name,l_name,name_suffix,addr1,addr2,city,state,zip_code,zip_suffix,hire_date,part_time,empl_type,classify,pos,status,home_orgn,base_loc,pay_method,days_worked,hours_day,no_pays,range,step_x,rate,annl_sal,notes,submit_date,appr_status,verf_status",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "newhire_data2",
    "PKColumns": "request_id",
    "TableColumns": "request_id,unique_key,application_id,applicant_id,posting_id,employee_flag,empl_no,fte",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "newhireaprv",
    "PKColumns": "request_id,lvl,association_id",
    "TableColumns": "request_id,lvl,association_id,association_seq,app_empl_no,del_empl_no,act,action_date,comment,approved_by",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "newhireaprv_hist",
    "PKColumns": "row_id",
    "TableColumns": "row_id,hist_date,hist_time,request_id,lvl,association_id,association_seq,app_empl_no,del_empl_no,act,action_date,comment,approved_by",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "newhirenotf",
    "PKColumns": "request_id",
    "TableColumns": "request_id,empl_no,submit_date,update_status,req_empl_no",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "newhireupdt",
    "PKColumns": "request_id,lvl,association_id",
    "TableColumns": "request_id,lvl,association_id,association_seq,app_empl_no,del_empl_no,act,action_date,comment,approved_by",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "newhireverf",
    "PKColumns": "request_id,lvl,association_id",
    "TableColumns": "request_id,lvl,association_id,association_seq,app_empl_no,del_empl_no,act,result,action_date,comment,verified_by",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "non_work",
    "PKColumns": "cal_type,n_date",
    "TableColumns": "cal_type,n_date,w_flag",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "note_pad",
    "PKColumns": "",
    "TableColumns": "module_code,note_id,line_no,note_text",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "notificationcert",
    "PKColumns": "pnr_id,c_type",
    "TableColumns": "pnr_id,tstamp,lastuser,c_type,shortmessage,longmessage,longmessageremote,day_checkpt1,day_checkpt2,day_checkpt3",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "notifier",
    "PKColumns": "",
    "TableColumns": "requestid,userid,reqtype,title,inactive,runhour,frequency,dow,dom,oncedate,location,currlast,period,perstart,perend,days,amount,abs_code,abs_totcon,anv_event,enc_op,bud_account,sql_desc,sql_sql,vnd_comm,lastrun,nextrun,running,bud_keyorgn,reqdappr,lowerappr",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "notify_templates",
    "PKColumns": "template_id",
    "TableColumns": "template_id,template_source,dataset_id,title,description,email_from,to_list,cc_list,bcc_list,subject,body,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "notify_type",
    "PKColumns": "",
    "TableColumns": "notify_code,description",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "nyr_fund",
    "PKColumns": "",
    "TableColumns": "cur_fund,new_fund",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "obj_table",
    "PKColumns": "",
    "TableColumns": "base_object,base_key,obj_desc,obj_type,obj_filename",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "obj_type",
    "PKColumns": "",
    "TableColumns": "type,type_desc,type_path,type_exec_path",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ojournal",
    "PKColumns": "",
    "TableColumns": "je_number,description,key_orgn,account,project,proj_acct,debit_amt,credit_amt,hold_flg,date_entered,entered_by,batch,yr,period,item_desc",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "old_activity",
    "PKColumns": "",
    "TableColumns": "activity_code,activity_title,function_code,function_title,prior_begin_amt,prior_yr_adds,prior_yr_deds,cur_begin_amt,cur_yr_adds,cur_yr_deds",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "old_assets",
    "PKColumns": "",
    "TableColumns": "tagno,improvement_num,dept,catcode,func_name,activity,deporgn,depacct,multifunc",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "old_department",
    "PKColumns": "",
    "TableColumns": "dept,dept_title,catcode,activity_code,prior_yr_amt,cur_yr_amt",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "old_multiftbl",
    "PKColumns": "",
    "TableColumns": "multifunc,description,function1,percent1,function2,percent2,function3,percent3,function4,percent4,function5,percent5,function6,percent6,function7,percent7,function8,percent8,function9,percent9,function10,percent10",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "old_source",
    "PKColumns": "",
    "TableColumns": "fund_source,fund_source_desc,prior_yr_amt,cur_yr_amt",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "opayable",
    "PKColumns": "",
    "TableColumns": "trans_no,enc_no,line_no,p_f,key_orgn,account,project,proj_acct,vend_no,c_1099,gl_cash,due_date,invoice,amount,description,single_ck,disc_date,disc_amt,voucher,hold_flg,date_entered,entered_by,batch,yr,period,qty_paid,qty_rec,sales_tax,use_tax,alt_vend_no",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "optio_manager",
    "PKColumns": "",
    "TableColumns": "format_id,format_name,active_format,site_code,district_code,format_code,format_type,printer,address_1,address_1_v,address_1_h,address_2,address_2_v,address_2_h,address_3,address_3_v,address_3_h,address_4,address_4_v,address_4_h,address_5,address_5_v,address_5_h,voucher_text,voucher_text_v,voucher_text_h,check_text,check_text_v,check_text_h,return_address_1,return_address_1_v,return_address_1_h,return_address_2,return_address_2_v,return_address_2_h,return_address_3,return_address_3_v,return_address_3_h,return_address_4,return_address_4_v,return_address_4_h,logo,logo_v,logo_h,logo_file,signature_1,signature_1_v,signature_1_h,signature_1_file,title_1,title_1_v,title_1_h,signature_2,signature_2_v,signature_2_h,signature_2_file,title_2,title_2_v,title_2_h,signature_3,signature_3_v,signature_3_h,signature_3_file,title_3,title_3_v,title_3_h,bank_address_1,bank_address_1_v,bank_address_1_h,bank_address_2,bank_address_2_v,bank_address_2_h,bank_address_3,bank_address_3_v,bank_address_3_h,bank_address_4,bank_address_4_v,bank_address_4_h,bank_address_5,bank_address_5_v,bank_address_5_h,fraction,fraction_v,fraction_h,micr_prefix,micr_prefix_v,micr_prefix_h,micr_routing,micr_routing_v,micr_routing_h,micr_account,micr_account_v,micr_account_h,top_text_1,top_text_1_v,top_text_1_h,top_text_2,top_text_2_v,top_text_2_h,bottom_text_1,bottom_text_1_v,bottom_text_1_h,bottom_text_2,bottom_text_2_v,bottom_text_2_h,bottom_text_3,bottom_text_3_v,bottom_text_3_h,bottom_text_4,bottom_text_4_v,bottom_text_4_h,bottom_text_5,bottom_text_5_v,bottom_text_5_h,bottom_text_6,bottom_text_6_v,bottom_text_6_h,bottom_text_7,bottom_text_7_v,bottom_text_7_h,bottom_text_8,bottom_text_8_v,bottom_text_8_h,bottom_text_9,bottom_text_9_v,bottom_text_9_h,bottom_text_10,bottom_text_10_v,bottom_text_10_h,bottom_text_11,bottom_text_11_v,bottom_text_11_h,bottom_text_12,bottom_text_12_v,bottom_text_12_h,bottom_text_13,bottom_text_13_v,bottom_text_13_h,bottom_text_14,bottom_text_14_v,bottom_text_14_h,bottom_text_15,bottom_text_15_v,bottom_text_15_h,copy_1_name,copy_1_name_v,copy_1_name_h,copy_2_name,copy_2_name_v,copy_2_name_h,copy_3_name,copy_3_name_v,copy_3_name_h,copy_4_name,copy_4_name_v,copy_4_name_h,copy_5_name,copy_5_name_v,copy_5_name_h,num_copies,change_date,change_time,change_uid,check_number_v,check_number_h,check_date_v,check_date_h,check_date_label_v,check_date_label_h,po_watermark,from_email_address,email_subject,email_body",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "oreceipt",
    "PKColumns": "",
    "TableColumns": "enc_no,gl_recv,key_orgn,account,project,proj_acct,vend_no,gl_cash,invoice,description,trans_amt,hold_flg,date_entered,entered_by,batch,yr,period",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "oreceive",
    "PKColumns": "",
    "TableColumns": "enc_no,key_orgn,account,project,proj_acct,gl_account,vend_no,amount,date_enc,description,hold_flg,date_entered,entered_by,batch,yr,period",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "orgbudexp",
    "PKColumns": "",
    "TableColumns": "yr,fund,key_orgn,acct,amount",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "orgbudrev",
    "PKColumns": "",
    "TableColumns": "yr,fund,key_orgn,acct,amount",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "orgn1table",
    "PKColumns": "",
    "TableColumns": "orgn1,orgn1keyup,orgn1key,title",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "orgn2table",
    "PKColumns": "",
    "TableColumns": "orgn2,orgn2keyup,orgn2key,title",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "orgn3table",
    "PKColumns": "",
    "TableColumns": "orgn3,orgn3keyup,orgn3key,title",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "orgn4table",
    "PKColumns": "",
    "TableColumns": "orgn4,orgn4keyup,orgn4key,title",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "orgn5table",
    "PKColumns": "",
    "TableColumns": "orgn5,orgn5keyup,orgn5key,title",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "orgn6table",
    "PKColumns": "",
    "TableColumns": "orgn6,orgn6keyup,orgn6key,title",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "orgn7table",
    "PKColumns": "",
    "TableColumns": "orgn7,orgn7keyup,orgn7key,title",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "orgn8table",
    "PKColumns": "",
    "TableColumns": "orgn8,orgn8keyup,orgn8key,title",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "orgn9table",
    "PKColumns": "",
    "TableColumns": "orgn9,orgn9keyup,keyorgn,title",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "otherins",
    "PKColumns": "",
    "TableColumns": "empl_no,ben_code,d_ssn,ins_code,eff_date,policy_hold,relation,dep_cov,ee_cov,employer,company,addr1,addr2,zip,contact,group_no,policy_no,cob_rule",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "output_detail",
    "PKColumns": "",
    "TableColumns": "output_id,sort_no,type,level,output,row_id",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "output_master",
    "PKColumns": "output_id",
    "TableColumns": "output_id,output_type,output_desc,create_who,create_when,row_id",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ovendor",
    "PKColumns": "",
    "TableColumns": "vend_no,ven_name,alpha_name,b_addr_1,b_addr_2,b_city,b_state,b_zip,b_contact,b_phone,b_fax,p_addr_1,p_addr_2,p_city,p_state,p_zip,p_contact,p_phone,p_fax,fed_id,date_last,paid_ytd,prev_misc,ordered_ytd,comm1,comm2,comm3,comm4,comm5,comm6,comm7,comm8,comm9,comm10,comm11,hold_flg,date_entered,entered_by,batch,form_1099,stax_rate,utax_rate,type_misc,empl_vend,empl_no,hold_trn_flg,min_check_amt,type_g,prev_g,type_int,prev_int",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "P360_NotificationLink",
    "PKColumns": "PNL_ID",
    "TableColumns": "PNL_ID,PNL_TStamp,PNL_LastUser,PNL_District,PNL_PNR_ID,PNL_SessionVariableNumber,PNL_SessionVariableName",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "P360_NotificationResultSet",
    "PKColumns": "PNRS_ID",
    "TableColumns": "PNRS_ID,PNRS_TStamp,PNRS_LastUser,PNRS_District,PNRS_PNR_ID,PNRS_PNRU_ID,PNRS_PNR_Subquery_ID,PNRS_SentToPOD,PNRS_Category,PNRS_ShortMessage,PNRS_LongMessage,PNRS_LongMessageRemote,PNRS_Value01,PNRS_Value02,PNRS_Value03,PNRS_Value04,PNRS_Value05,PNRS_Value06,PNRS_Value07,PNRS_Value08,PNRS_Value09,PNRS_Value10,PNRS_Value11,PNRS_Value12,PNRS_Value13,PNRS_Value14,PNRS_Value15,PNRS_Value16",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "P360_NotificationResultSetUser",
    "PKColumns": "PNRSU_ID",
    "TableColumns": "PNRSU_ID,PNRSU_TStamp,PNRSU_LastUser,PNRSU_District,PNRSU_PNRS_ID,PNRSU_UserId,PNRSU_UserApplication,PNRSU_EmailAddress,PNRSU_DeliveryMethod,PNRSU_InstantAlert",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "P360_NotificationRule",
    "PKColumns": "PNR_ID",
    "TableColumns": "PNR_ID,PNR_TStamp,PNR_LastUser,PNR_District,PNR_Name,PNR_Description,PNR_SourceApplication,PNR_RemoteSecurityApplication,PNR_RemoteSecurityType,PNR_RequiredSecurity,PNR_RuleType,PNR_Rule,PNR_Category,PNR_FilterSQL,PNR_HighestRequiredLevel,PNR_ShortMessage,PNR_LongMessage,PNR_LongMessageRemote,PNR_LinkToPageTitle,PNR_LinkToPageURL,PNR_LinkToPageMethod,PNR_AlertEveryTime,PNR_Subquery,PNR_Subquery_ID,PNR_Active",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "P360_NotificationRuleKey",
    "PKColumns": "PNRK_ID",
    "TableColumns": "PNRK_ID,PNRK_TStamp,PNRK_LastUser,PNRK_District,PNRK_PNR_ID,PNRK_KeyName,PNRK_ResultValueID",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "P360_NotificationRuleUser",
    "PKColumns": "PNRU_ID",
    "TableColumns": "PNRU_ID,PNRU_TStamp,PNRU_LastUser,PNRU_District,PNRU_PNR_ID,PNRU_Level,PNRU_Actor,PNRU_SubscribeStatus,PNRU_DeliveryMethod,PNRU_InstantAlert,PNRU_Active",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "P360_NotificationSchedule",
    "PKColumns": "PNS_ID",
    "TableColumns": "PNS_ID,PNS_TStamp,PNS_LastUser,PNS_District,PNS_PNRU_ID,PNS_PNRS_ID,PNS_Minute,PNS_Hour,PNS_DayOfMonth,PNS_Month,PNS_DayOfWeek,PNS_TaskType,PNS_AssignedToTask",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "P360_NotificationTasks",
    "PKColumns": "PNT_ID",
    "TableColumns": "PNT_ID,PNT_PNS_ID,PNT_AgentPriority,PNT_StartDateTime,PNT_Status,PNT_TaskType",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "P360_NotificationUserCriteria",
    "PKColumns": "PNUC_ID",
    "TableColumns": "PNUC_ID,PNUC_TStamp,PNUC_LastUser,PNUC_District,PNUC_PNR_ID,PNUC_PNRU_ID,PNUC_CriteriaType,PNUC_CriteriaVariable,PNUC_CriteriaValue",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "padd_rate",
    "PKColumns": "",
    "TableColumns": "empl_no,classify,pos,indx,code,salary,fte",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "password_requests",
    "PKColumns": "session_id,user_id,request_date",
    "TableColumns": "session_id,user_id,request_date,is_active",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pat_act",
    "PKColumns": "sit_id",
    "TableColumns": "sit_id,empl_no,sit_type,sit_st_dat,sit_end_dat,sit_desc,sit_data1,sit_data2,sit_data3,sit_data4,sit_data5,sit_data6,sit_data7,sit_data8,sit_data9,sit_data10,sit_data11,sit_data12,sit_data13,sit_data14,sit_data15,sit_data16,sit_data17,sit_data18,sit_data19,sit_data20,free_text",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pat_sit",
    "PKColumns": "",
    "TableColumns": "sit_type,secure_type,lv_cd_ref,udef1_name,udef1_type,udef1_len,udef1_tab_ref,udef2_name,udef2_type,udef2_len,udef2_tab_ref,udef3_name,udef3_type,udef3_len,udef3_tab_ref,udef4_name,udef4_type,udef4_len,udef4_tab_ref,udef5_name,udef5_type,udef5_len,udef5_tab_ref,udef6_name,udef6_type,udef6_len,udef6_tab_ref,udef7_name,udef7_type,udef7_len,udef7_tab_ref,udef8_name,udef8_type,udef8_len,udef8_tab_ref,udef9_name,udef9_type,udef9_len,udef9_tab_ref,udef10_name,udef10_type,udef10_len,udef10_tab_ref,udef11_name,udef11_type,udef11_len,udef11_tab_ref,udef12_name,udef12_type,udef12_len,udef12_tab_ref,udef13_name,udef13_type,udef13_len,udef13_tab_ref,udef14_name,udef14_type,udef14_len,udef14_tab_ref,udef15_name,udef15_type,udef15_len,udef15_tab_ref,udef16_name,udef16_type,udef16_len,udef16_tab_ref,udef17_name,udef17_type,udef17_len,udef17_tab_ref,udef18_name,udef18_type,udef18_len,udef18_tab_ref,udef19_name,udef19_type,udef19_len,udef19_tab_ref,udef20_name,udef20_type,udef20_len,udef20_tab_ref,short_sit_type",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pay_code",
    "PKColumns": "",
    "TableColumns": "screen_no,scr_desc,pay_code1,fy1,pay_code2,fy2,pay_code3,fy3,pay_code4,fy4,pay_code5,fy5,pay_code6,fy6,pay_code7,fy7,pay_code8,fy8,pay_code9,fy9,pay_code10,fy10",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pay_freq",
    "PKColumns": "",
    "TableColumns": "vend_pay_freq,pay_run,due_date,period,yr",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pay_log",
    "PKColumns": "",
    "TableColumns": "pay_run,uid,chg_date,chg_time",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pay_runf",
    "PKColumns": "",
    "TableColumns": "pay_run,pay_cycle,freq_type,freq_code,adv_pay",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pay_stax",
    "PKColumns": "",
    "TableColumns": "pay_run,pay_cycle,s_fed_tax,s_sta_tax,s_loc_tax",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pay2file",
    "PKColumns": "",
    "TableColumns": "empl_no,ssn,l_name,f_name,chk_locn,addr1,addr2,addr3,zip,home_orgn,voucher,end_date,start_date,m_name,name_suffix",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "payab_asset",
    "PKColumns": "",
    "TableColumns": "payab_src,row_id,rec_no",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "payable",
    "PKColumns": "row_id",
    "TableColumns": "key_orgn,account,project,proj_acct,trans_date,enc_no,amount,vend_no,invoice,due_date,disc_date,disc_amt,disc_per,description,trans_no,disc_dt_or,hold_flg,sales_tax,use_tax,batch,row_id",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "payaddend",
    "PKColumns": "",
    "TableColumns": "empl_no,ded_cd,rec_no,batch,pay_run,end_date,run_type,due_date,case_no,amount,medical,fips_cd,terminated,row_id,trans_no",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "paybnote",
    "PKColumns": "",
    "TableColumns": "rec_no,vend_no,trans_date,lino,description",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "paychk_sel",
    "PKColumns": "",
    "TableColumns": "pay_run,selection_type,data_type,begin_chknum,lastgood_chknum,restart_chknum,iss_date,sort_ord,begin_evchnum,msg_line1,msg_line2,run_date,run_time,run_user,format_id",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "paycode",
    "PKColumns": "",
    "TableColumns": "empl_no,pay_code,p_amt,p_hours,mtd_amt,mtd_hours,qtd_amt,ytd_amt,cal_cycle_units,cal_cycle_amt",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "payee",
    "PKColumns": "",
    "TableColumns": "payee_no,payee_name,alpha_name,address_1,address_2,address_3,zip_code,phone,fax",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "payer",
    "PKColumns": "",
    "TableColumns": "vend_no,ven_name,alpha_name,b_addr_1,b_addr_2,b_addr_3,b_zip,b_phone,date_last,receivables,payments",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "payf_cp",
    "PKColumns": "",
    "TableColumns": "empl_no,home_orgn,pdf,code,amount,fringe,orgn,proj,acct,pacct,arrears,check_no,hours,classify,dedgross,frngross,tax_ind,bank,bt_code,bank_acct,pay_cycle,chk_ind,flsa_flg,payrate",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "payfile",
    "PKColumns": "",
    "TableColumns": "empl_no,home_orgn,pdf,code,amount,fringe,orgn,proj,acct,pacct,arrears,check_no,hours,classify,dedgross,frngross,tax_ind,bank,bt_code,bank_acct,pay_cycle,chk_ind,flsa_flg,payrate",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "paygroups",
    "PKColumns": "",
    "TableColumns": "group_x,def_hours,pay_run,end_date,cur_run,run_desc,proc_sumfisc,start_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "paygrp_defdays",
    "PKColumns": "",
    "TableColumns": "group_x,def_days,pay_run",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "payrate",
    "PKColumns": "empl_no,rate_no",
    "TableColumns": "empl_no,rate_no,primry,group_x,pay_hours,days_worked,hours_day,incl_dock,no_pays,fte,pay_method,pay_cycle,pay_cd,classify,occupied,cal_type,range,step_x,rate,dock_rate,cont_flg,cont_days,override,annl_sal,cont_lim,cont_bal,cont_paid,cont_start,cont_end,pay_start,pay_end,summer_pay,status_x,pyo_date,pyo_rem_pay,pyo_days,pyo_rate,pyo_amt,dock_arrears_amt,dock_pays_remain",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "payrhist",
    "PKColumns": "",
    "TableColumns": "empl_no,classify,pos,rangex,stepx,ratex,annl_sal,eff_date,operator_id,group_x,cont_days,days_worked,fte,cont_lim,cont_paid,cont_bal,hours_day,pay_hours,pay_cd,remain_pay,cal_type,pay_method,dock_rate,dock_units,dock_amt,ext_lv_units,ext_lv_amt,dock_arrears_amt,dock_pays_remain",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "payroll",
    "PKColumns": "empl_no",
    "TableColumns": "empl_no,pay_freq,card_requ,sp1_amt,sp1_cd,sp2_amt,sp2_cd,sp3_amt,sp3_cd,chk_locn,last_paid,fed_exempt,fed_marital,fed_dep,add_fed,sta_exempt,state_id,pr_state,sta_marital,sta_dep,add_state,loc_exempt,locl,pr_local,loc_marital,loc_dep,add_local,fic_exempt,earn_inc,lv_date,lv1_cd,lv1_bal,lv1_tak,lv1_ear,lv2_cd,lv2_bal,lv2_tak,lv2_ear,lv3_cd,lv3_bal,lv3_tak,lv3_ear,lv4_cd,lv4_bal,lv4_tak,lv4_ear,lv5_cd,lv5_bal,lv5_tak,lv5_ear,lv6_cd,lv6_bal,lv6_tak,lv6_ear,lv7_cd,lv7_bal,lv7_tak,lv7_ear,lv8_cd,lv8_bal,lv8_tak,lv8_ear,lv9_cd,lv9_bal,lv9_tak,lv9_ear,lv10_cd,lv10_bal,lv10_tak,lv10_ear,tearn_c,tearn_m,tearn_q,tearn_y,tearn_ft,ftearn_c,ftearn_m,ftearn_q,ftearn_y,ftearn_ft,fiearn_c,fiearn_m,fiearn_q,fiearn_y,fiearn_ft,mdearn_c,mdearn_m,mdearn_q,mdearn_y,mdearn_ft,stearn_c,stearn_m,stearn_q,stearn_y,stearn_ft,s2earn_c,s2earn_m,l2earn_y,s2earn_y,s2earn_ft,loearn_c,loearn_m,loearn_q,loearn_y,loearn_ft,allow_c,allow_m,allow_q,allow_y,allow_ft,nocash_c,nocash_m,nocash_q,nocash_y,nocash_ft,fedtax_c,fedtax_m,fedtax_q,fedtax_y,fedtax_ft,fictax_c,fictax_m,fictax_q,fictax_y,fictax_ft,medtax_c,medtax_m,medtax_q,medtax_y,medtax_ft,statax_c,statax_m,statax_q,statax_y,statax_ft,st2tax_c,st2tax_m,lt2tax_y,st2tax_y,st2tax_ft,loctax_c,loctax_m,loctax_q,loctax_y,loctax_ft,eic_c,eic_m,eic_q,eic_y,eic_ft,rfiearn_y,rfictax_y,rmdearn_y,rmedtax_y,flsa_cycle_y,flsa_cycle_hrs,flsa_hours,flsa_amount,rfiearn_c,rfiearn_m,rfiearn_q,rfiearn_ft,rfictax_c,rfictax_m,rfictax_q,rfictax_ft,rmdearn_c,rmdearn_m,rmdearn_q,rmdearn_ft,rmedtax_c,rmedtax_m,rmedtax_q,rmedtax_ft,fed_tax_calc_cd,w4_sub_date,non_res_alien,ann_other_inc,ann_deductions,ann_tax_credit,pays_per_year",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "paytab_activity",
    "PKColumns": "",
    "TableColumns": "table_name,key_field,field_name,old_value,new_value,operator,date_chg,time_chg",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "paytable",
    "PKColumns": "pay_code",
    "TableColumns": "pay_code,title,ck_title,pay_type,percent_x,account,fed_exempt,sta_exempt,fic_exempt,loc_exempt,ded1_exempt,ded2_exempt,ded3_exempt,ded4_exempt,ded5_exempt,ded6_exempt,ded7_exempt,ded8_exempt,ded9_exempt,ded10_exempt,lv_add,lv_sub,time_type,frequency,wkr_comp,encum,pc_track,flsa_calc_type,flsa_ovt,exc_retro,add_factor,time_flag,app_level,ded11_exempt,ded12_exempt,ded13_exempt,ded14_exempt,ded15_exempt,ded16_exempt,ded17_exempt,ded18_exempt,ded19_exempt,ded20_exempt,ded21_exempt,ded22_exempt,ded23_exempt,ded24_exempt,ded25_exempt,ded26_exempt,ded27_exempt,ded28_exempt,ded29_exempt,ded30_exempt,ded31_exempt,ded32_exempt,ded33_exempt,ded34_exempt,ded35_exempt,ded36_exempt,ded37_exempt,ded38_exempt,ded39_exempt,ded40_exempt,include_notif",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pb_audit",
    "PKColumns": "",
    "TableColumns": "yr,iteration,act,stampid,stampdate,stamptime",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pb_iteration",
    "PKColumns": "",
    "TableColumns": "yr,iteration,description,active,saved",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pb_iternote",
    "PKColumns": "",
    "TableColumns": "yr,iteration,line_no,note",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pbi_budactv",
    "PKColumns": "",
    "TableColumns": "iteration,yr,empl_no,classify,pos,ded_cd,date_chg,table_name,field_name,old_value,new_value,operator",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pbi_buddist",
    "PKColumns": "",
    "TableColumns": "iteration,yr,empl_no,classify,pos,rec_type,orgn_proj,acct,code,amount",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pbi_budincr",
    "PKColumns": "",
    "TableColumns": "iteration,yr,classify,eff_date,amt,prcent,c_b",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pbi_budpayr",
    "PKColumns": "",
    "TableColumns": "iteration,yr,classify,pos,freeze,empl_no,l_name,f_name,rate_no,primry,group_x,pay_hours,days_worked,hours_day,no_pays,fte,pay_method,pay_cd,cal_type,range,step_x,curr_rate,curr_sal,bud_dock,cont_flg,cont_days,override,cont_start,cont_end,summer_pay,sp1_cd,sp1_amt,sp2_cd,sp2_amt,sp3_cd,sp3_amt,prcnt_incr_a,amt_incr_a,bud_rate,bud_base,spec_base,incr_base,mdyr_incr_a,occupied,date_incr_a,date_incr_b,prcnt_incr_b,amt_incr_b,mdyr_incr_b,curr_date_a,curr_prcnt_a,curr_date_b,curr_prcnt_b",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pbi_mmax_budpr",
    "PKColumns": "",
    "TableColumns": "iteration,yr,empl_no,rate_no,pos,fam_code,grd_code,bud_incr,amt_incr,prct_inc,tea_amt,curr_days,curr_hours,status_x,cont_cyc,incl_dock",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pbi_padd_rate",
    "PKColumns": "",
    "TableColumns": "iteration,yr,empl_no,classify,pos,indx,code,salary,fte",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pbi_pclstable",
    "PKColumns": "",
    "TableColumns": "iteration,yr,class_cd,title,schedule,wkr_comp,cal_type,ded_cd1,ded_cd2,ded_cd3,ded_cd4,ded_cd5,ded_cd6,ded_cd7,ded_cd8,ded_cd9,ded_cd10,pay_cd,pay_method,group_x,range,step_x,av_an_sal,hours_day,days_worked,no_pays,bud_rate,pos_ctrl,bar_unit,anniv_incr",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pbi_pdedtable",
    "PKColumns": "",
    "TableColumns": "iteration,yr,ded_cd,title,no_pays,frng_meth,frng_rate,frng_acct,fic_fexp,frng_dist,frng_orgn,frng_proj,use_gross_field",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pbi_pdeduct",
    "PKColumns": "",
    "TableColumns": "iteration,yr,classify,pos,empl_no,ded_cd,cont_amt,max_fringe,bud_amt,freeze,addl_frng_gross",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pbi_pdist_orgn",
    "PKColumns": "",
    "TableColumns": "iteration,yr,empl_no,rate_no,classify,pos,orgn,acct,prcent",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pbi_pdist_proj",
    "PKColumns": "",
    "TableColumns": "iteration,yr,empl_no,rate_no,classify,pos,proj,acct,prcent",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pbi_pdtytable",
    "PKColumns": "",
    "TableColumns": "iteration,yr,code,desc_x,prcent,dollar",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pbi_pfictable",
    "PKColumns": "",
    "TableColumns": "iteration,yr,fic_med,empr_per,empr_max,frg_acct,frng_dist,frng_orgn",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pbi_ppaytable",
    "PKColumns": "",
    "TableColumns": "iteration,yr,pay_code,title,pay_type,percent_x,account,fic_exempt,wkr_comp,ded1_exempt,ded2_exempt,ded3_exempt,ded4_exempt,ded5_exempt,ded6_exempt,ded7_exempt,ded8_exempt,ded9_exempt,ded10_exempt,no_pays,ded11_exempt,ded12_exempt,ded13_exempt,ded14_exempt,ded15_exempt,ded16_exempt,ded17_exempt,ded18_exempt,ded19_exempt,ded20_exempt,ded21_exempt,ded22_exempt,ded23_exempt,ded24_exempt,ded25_exempt,ded26_exempt,ded27_exempt,ded28_exempt,ded29_exempt,ded30_exempt,ded31_exempt,ded32_exempt,ded33_exempt,ded34_exempt,ded35_exempt,ded36_exempt,ded37_exempt,ded38_exempt,ded39_exempt,ded40_exempt",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pbi_ppctl_orgn",
    "PKColumns": "",
    "TableColumns": "iteration,yr,classify,pos,orgn,acct,prcent",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pbi_ppctl_proj",
    "PKColumns": "",
    "TableColumns": "iteration,yr,classify,pos,proj,acct,prcent",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pbi_pposition",
    "PKColumns": "",
    "TableColumns": "iteration,yr,classify,pos,auth_fte,fill_fte,fte,locn,text1,text2,bsalary",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pbi_pposn_data2",
    "PKColumns": "",
    "TableColumns": "iteration,yr,classify,pos,description,posn_days,posn_fte_open,bargain",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pbi_pposprate",
    "PKColumns": "",
    "TableColumns": "iteration,yr,empl_no,classify,pos,fte",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pbi_pwkrtable",
    "PKColumns": "",
    "TableColumns": "iteration,yr,work_cd,title,rate,fringe_acct",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pbs_state",
    "PKColumns": "",
    "TableColumns": "empl_no,amount1",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pcash_acctmask",
    "PKColumns": "",
    "TableColumns": "mask_acct",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pcash_funds",
    "PKColumns": "",
    "TableColumns": "fund,account",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pcash_header",
    "PKColumns": "",
    "TableColumns": "receipt_acct,receipt_desc,journal_acct,journal_desc,check_acct,check_desc,payroll_acct,payroll_desc,default_acct",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pcd_cards",
    "PKColumns": "",
    "TableColumns": "pcard_no,pcard_layout,card_limit,monthly_limit,daily_limit,trans_limit",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pcd_crosswalk",
    "PKColumns": "",
    "TableColumns": "pcard_layout,old_pcard_no,new_pcard_no",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pcd_data_items",
    "PKColumns": "",
    "TableColumns": "item_code,item_name,item_desc,headeryn,detailyn,traileryn",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pcd_dist",
    "PKColumns": "",
    "TableColumns": "trans_no,entry_no,line_no,dpay_row_id,pay_row_id,key_orgn,account,project,proj_acct,amount,c_1099,description,row_id,enc_no",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pcd_enc_no",
    "PKColumns": "",
    "TableColumns": "prefix,next_enc_no",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pcd_entry",
    "PKColumns": "",
    "TableColumns": "entry_no,pcard_no,pcard_layout,empl_no,trans_date,vend_no,reference_no,invoice_no,trans_amt,commodity,summary_desc,detail_desc,entry_empl_no,entry_date,enc_no,yr",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pcd_fld_formats",
    "PKColumns": "",
    "TableColumns": "format_code,format_desc",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pcd_layout_flds",
    "PKColumns": "",
    "TableColumns": "pcard_layout,line_type,line_no,data_desc,line_position,data_item,field_format,type_value,start_position,stop_position,has_decimal",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pcd_layout_hdr",
    "PKColumns": "",
    "TableColumns": "pcard_layout,layout_name,default_file,use_dates,date_prompt,file_delimiter,vend_no,fhintot,fhinbat,ftintot,ftinbat,bhintot,bhinbat,btintot,btinbat",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pcd_profile",
    "PKColumns": "",
    "TableColumns": "userentry,encumflag,datematch,purchmatch,p_f",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pcd_trans",
    "PKColumns": "",
    "TableColumns": "trans_no,pcard_no,pcard_layout,trans_id,trans_date,purchase_date,merch_id,user_id,amount,sales_tax,use_tax,description,commodity,vend_no,empl_no,enc_no,yr,entry_no,status_flag,user1,user2,user3,user4,user5",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pcd_transact",
    "PKColumns": "",
    "TableColumns": "trans_no,pcd_vend_no",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pcd_users",
    "PKColumns": "",
    "TableColumns": "empl_no,pcard_no,pcard_layout,user_id,monthly_limit,daily_limit,trans_limit,user_flag",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pcd_vendors",
    "PKColumns": "",
    "TableColumns": "pcard_layout,merch_id,vend_no,merch_name,address1,address2,city,state,zip",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pclstable",
    "PKColumns": "",
    "TableColumns": "class_cd,title,schedule,wkr_comp,cal_type,ded_cd1,ded_cd2,ded_cd3,ded_cd4,ded_cd5,ded_cd6,ded_cd7,ded_cd8,ded_cd9,ded_cd10,pay_cd,pay_method,group_x,range,step_x,av_an_sal,hours_day,days_worked,no_pays,bud_rate,pos_ctrl,bar_unit,anniv_incr",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pclstable_data2",
    "PKColumns": "",
    "TableColumns": "class_cd,job_type,job_descript",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pctl_orgn",
    "PKColumns": "",
    "TableColumns": "classify,pos,orgn,acct,prcent,yr",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pctl_proj",
    "PKColumns": "",
    "TableColumns": "classify,pos,proj,acct,prcent,yr",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pd_area_dtl",
    "PKColumns": "unique_key",
    "TableColumns": "course_id,area_cd,create_who,create_when,update_who,update_when,unique_id,unique_key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pd_area_mstr",
    "PKColumns": "area_cd",
    "TableColumns": "area_cd,area_desc,create_who,create_when,update_who,update_when,unique_id,unique_key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pd_attend_dtl",
    "PKColumns": "unique_key",
    "TableColumns": "class_uid,part_pe_id,part_pedb_cd,attend_comm,create_who,create_when,update_who,update_when,unique_id,unique_key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pd_catg_mstr",
    "PKColumns": "req_catg",
    "TableColumns": "req_catg,req_desc,create_who,create_when,update_who,update_when,unique_id,unique_key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pd_class_dtl",
    "PKColumns": "class_uid",
    "TableColumns": "course_id,class_uid,class_dttm,class_duration,class_alt_lctn,inst_pe_id,inst_pedb_cd,create_who,create_when,update_who,update_when,unique_id,unique_key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pd_cost_dtl",
    "PKColumns": "unique_key",
    "TableColumns": "course_id,cost_cd,cost_amt,cost_comm,cost_gr,cost_key,cost_obj,cost_jlgr,cost_jlkey,cost_jlobj,create_who,create_when,update_who,update_when,unique_id,unique_key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pd_cost_mstr",
    "PKColumns": "cost_cd",
    "TableColumns": "cost_cd,cost_desc,create_who,create_when,update_who,update_when,unique_id,unique_key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pd_course_emp_type",
    "PKColumns": "unique_key",
    "TableColumns": "entity_id,employee_type,pd_course_type,create_who,create_when,update_who,update_when,unique_id,unique_key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pd_course_mstr",
    "PKColumns": "course_id",
    "TableColumns": "course_id,course_name,course_title,course_desc,course_stat_cd,inst_pe_id,inst_pedb_cd,start_dt,end_dt,sched,lctn_cd,room,materials,prereqs,max_part,min_part,part_cost,seat_hrs,require_eval,course_gr,course_key,course_obj,course_jlgr,course_jlkey,course_jlobj,term,retake,course_part_type,post_dt,grade_type,external_postdt,fiscalyr,hr_integration,require_grade,allow_credittype,ext_cost,course_type,create_who,create_when,update_who,update_when,unique_id,unique_key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pd_coursemisc_dtl",
    "PKColumns": "unique_key",
    "TableColumns": "course_id,misc_type,misc_code,comments,create_who,create_when,update_who,update_when,unique_id,unique_key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pd_coursetype_mstr",
    "PKColumns": "unique_key",
    "TableColumns": "course_type,descx,create_who,create_when,update_who,update_when,unique_id,unique_key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pd_credit_dtl",
    "PKColumns": "unique_key",
    "TableColumns": "course_id,part_pe_id,credit_type,partial_credits,create_who,create_when,update_who,update_when,unique_id,unique_key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pd_credit_table",
    "PKColumns": "unique_key",
    "TableColumns": "credit_type,descx,create_who,create_when,update_who,update_when,unique_id,unique_key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pd_credittype_mstr",
    "PKColumns": "unique_key",
    "TableColumns": "course_id,credit_type,credits,credit_dt,credit_inst,create_who,create_when,update_who,update_when,unique_id,unique_key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pd_eval_dtl",
    "PKColumns": "eval_uid",
    "TableColumns": "course_id,eval_id,eval_uid,eval_sort_order,create_who,create_when,update_who,update_when,unique_id,unique_key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pd_eval_mstr",
    "PKColumns": "eval_id",
    "TableColumns": "eval_id,eval_text,eval_resp_type,eval_low_num,eval_high_num,default_response,create_who,create_when,update_who,update_when,unique_id,unique_key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pd_grade_type_dtl",
    "PKColumns": "unique_key",
    "TableColumns": "grade_type,grade_code,grade_descx,success_comp,create_who,create_when,update_who,update_when,unique_id,unique_key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pd_grade_type_mstr",
    "PKColumns": "unique_key",
    "TableColumns": "grade_type,descx,create_who,create_when,update_who,update_when,unique_id,unique_key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pd_inst_part_mstr",
    "PKColumns": "unique_key",
    "TableColumns": "inst_part_id,l_name,f_name,addr1,addr2,city,state_id,zip,zip_ext,phone,phone_ext,work_phone,work_phone_ext,cell_phone,cell_phone_ext,other_phone,other_phone_ext,email_addr,email2_addr,district_location,inst_flg,part_flg,ssn,inst_part_status,create_who,create_when,update_who,update_when,unique_id,unique_key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pd_location",
    "PKColumns": "unique_key",
    "TableColumns": "lctn_code,descx,create_who,create_when,update_who,update_when,unique_id,unique_key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pd_location_room",
    "PKColumns": "unique_key",
    "TableColumns": "lctn_cd,room,room_desc,create_who,create_when,update_who,update_when,unique_id,unique_key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pd_misc_mstr",
    "PKColumns": "unique_key",
    "TableColumns": "misc_type,misc_code,misc_desc,create_who,create_when,update_who,update_when,unique_id,unique_key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pd_misc_type_mstr",
    "PKColumns": "unique_key",
    "TableColumns": "misc_type,misc_desc,create_who,create_when,update_who,update_when,unique_id,unique_key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pd_prereq_dtl",
    "PKColumns": "unique_key",
    "TableColumns": "course_id,course_name,create_who,create_when,update_who,update_when,unique_id,unique_key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pd_reg_dtl",
    "PKColumns": "unique_key",
    "TableColumns": "course_id,part_pe_id,part_pedb_cd,reg_comm,part_grade,reg_dttm,reg_confirm,pay_method,cc_number,cc_exp,cc_sec_code,course_paid,eval_complete,cert_avail,cert_print_dttm,drop_dttm,drop_confirm,reg_stat_cd,part_credit_type,create_who,create_when,update_who,update_when,unique_id,unique_key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pd_req_dtl",
    "PKColumns": "unique_key",
    "TableColumns": "course_id,req_cd,req_comm,create_who,create_when,update_who,update_when,unique_id,unique_key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pd_req_mstr",
    "PKColumns": "req_cd",
    "TableColumns": "req_cd,req_desc,req_catg,create_who,create_when,update_who,update_when,unique_id,unique_key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pd_resp_dtl",
    "PKColumns": "unique_key",
    "TableColumns": "eval_uid,eval_yn_resp,eval_num_resp,eval_comm_resp,part_pe_id,part_pedb_cd,create_who,create_when,update_who,update_when,unique_id,unique_key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pd_term_mstr",
    "PKColumns": "unique_key",
    "TableColumns": "term_cd,descx,create_who,create_when,update_who,update_when,unique_id,unique_key",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pdedtable",
    "PKColumns": "",
    "TableColumns": "ded_cd,title,no_pays,frng_meth,frng_rate,frng_acct,fic_fexp,frng_dist,frng_orgn,frng_proj,use_gross_field",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pdeduct",
    "PKColumns": "",
    "TableColumns": "classify,pos,empl_no,ded_cd,cont_amt,max_fringe,bud_amt,freeze,addl_frng_gross",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pdist_orgn",
    "PKColumns": "",
    "TableColumns": "empl_no,rate_no,classify,pos,orgn,acct,prcent",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pdist_proj",
    "PKColumns": "",
    "TableColumns": "empl_no,rate_no,classify,pos,proj,acct,prcent",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pdtytable",
    "PKColumns": "",
    "TableColumns": "code,desc_x,prcent,dollar",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pei_background",
    "PKColumns": "",
    "TableColumns": "run_number,program_name,userid,delete_flag,building,output_file,status_log,order_by,sel_from,sel_crit,other_params,change_date,change_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pers_history",
    "PKColumns": "",
    "TableColumns": "empl_no,pay_date,emplr_cd,office_cd,rpt_serv_mnth,rpt_serv_year,rpt_serv_code,unit_code,ssn,l_name,f_init,m_init,cov_group,frng_rate,serv_mnth,serv_year,serv_code,pay_code,pay_rate,memb_earn,rate,empl_code,empl_contr,suvr_contr,sched_code,emplr_code,emplr_contr,emplr_paid,tape_date,iss_date,ent_source,ent_operator,ent_date,upd_operator,upd_date,pay_run,reg_hours,assigned_no",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "person",
    "PKColumns": "empl_no",
    "TableColumns": "empl_no,home_phone,listed,work_phone,emer_cont,emer_phone,phys_name,phys_phone,yrs_district,yrs_state,yrs_total,last_tb,tenure_date,senior_date,empl_type,location,sex,race,eeo,eeo_group,part_time,status,stat_date,hand,job_1,job_2,job_3,job_4,job_5,bargain,comp_code,term_date,term_code,ex_curr1,ex_curr2,ex_curr3,ex_curr4,ex_curr5,ex_curr6,curr_date,prior_class,prior_date,prior2_class,prior2_date,incr_per,incr_date,incr2_per,incr2_date,incr3_per,incr3_date,eeo_func,lastday_worked,cell_phone,other_phone,emer_cell_phone,ethnic_code,staff_state_id,inc_sum_fisc_accr,gender_identity",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "person_cont_type",
    "PKColumns": "empl_no,contract_type",
    "TableColumns": "empl_no,contract_type,board_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pfictable",
    "PKColumns": "",
    "TableColumns": "fic_med,empr_per,empr_max,frg_acct,frng_dist,frng_orgn",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pk_problems",
    "PKColumns": "",
    "TableColumns": "tabname,rundate,value1,value2,value3,value4,value5,value6,value7,value8,value9,value10,value11,value12,value13,value14,value15,value16,value17,value18,value19,value20",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "poacctap",
    "PKColumns": "",
    "TableColumns": "po_no,line_no,range_code,action_date,app_name,act,comment",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "poacctap_hist",
    "PKColumns": "",
    "TableColumns": "hist_date,hist_time,po_no,line_no,range_code,action_date,app_name,act,comment",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "poaprv",
    "PKColumns": "po_no,line_no,lvl",
    "TableColumns": "po_no,line_no,lvl,action_date,app_name,act,comment,apprvreqd",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "poaprv_hist",
    "PKColumns": "",
    "TableColumns": "hist_date,hist_time,po_no,line_no,lvl,action_date,app_name,act,comment,apprvreqd,approval_level",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pocomnt",
    "PKColumns": "",
    "TableColumns": "po_no,seq,comment",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "polinds",
    "PKColumns": "",
    "TableColumns": "po_no,line_no,seq,description",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "portfolio",
    "PKColumns": "",
    "TableColumns": "pf_type,pf_descri,perform_yld,perform2,perform3,perform4,perform5",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "posdeg_link",
    "PKColumns": "",
    "TableColumns": "pos_code,deg_lev,sub_type1,sub_type2,sub_type3,sub_type4,sub_type5,sub_type6,sub_type7,sub_type8,sub_type9,sub_type10,alt_deg1,alt_sub1,alt_deg2,alt_sub2,alt_deg3,alt_sub3,alt_deg4,alt_sub4,alt_deg5,alt_sub5,alt_deg6,alt_sub6,alt_deg7,alt_sub7,alt_deg8,alt_sub8,alt_deg9,alt_sub9,alt_deg10,alt_sub10",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "positiondata",
    "PKColumns": "classify,pos",
    "TableColumns": "classify,pos,auth_fte,fill_fte,fte,locn,text1,text2,bsalary,asalary,psalary,yr",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "posn_cert",
    "PKColumns": "",
    "TableColumns": "yr,classify,pos,cert_type,cert_area,cert_required",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "posn_data2",
    "PKColumns": "",
    "TableColumns": "yr,classify,pos,description,posn_days,posn_fte_open,bargain",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "posn_data3",
    "PKColumns": "",
    "TableColumns": "yr,classify,pos,job_type,job_descript,posting_fte,pend_transfer_fte",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "posn_qual",
    "PKColumns": "",
    "TableColumns": "yr,classify,pos,qual_code",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "posn_req",
    "PKColumns": "",
    "TableColumns": "yr,classify,pos,req_code",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "posnhist",
    "PKColumns": "",
    "TableColumns": "empl_no,classify,pos,pay_code,startdate,enddate,status,mjr_budget,mjr_acct,posn_fte,posn_locn,promo_reason,exempt,eeo_status,supervisor,dept,eff_date,operator_id,yr",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "posnpref",
    "PKColumns": "",
    "TableColumns": "appl_id,posn_pref,site1,site2,site3,site4,site5,site6,site7,site8,site9,site10,site11,site12,site13,site14,site15,site16,site17,site18,site19,site20,site21,site22,site23,site24,site25",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "posprate",
    "PKColumns": "empl_no,classify,pos",
    "TableColumns": "empl_no,classify,pos,fte,yr",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "potext",
    "PKColumns": "po_no,change,req_no,recno",
    "TableColumns": "po_no,change,req_no,recno,description",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "potype",
    "PKColumns": "",
    "TableColumns": "code,descrip",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ppaytable",
    "PKColumns": "",
    "TableColumns": "pay_code,title,pay_type,percent_x,account,fic_exempt,wkr_comp,ded1_exempt,ded2_exempt,ded3_exempt,ded4_exempt,ded5_exempt,ded6_exempt,ded7_exempt,ded8_exempt,ded9_exempt,ded10_exempt,no_pays,ded11_exempt,ded12_exempt,ded13_exempt,ded14_exempt,ded15_exempt,ded16_exempt,ded17_exempt,ded18_exempt,ded19_exempt,ded20_exempt,ded21_exempt,ded22_exempt,ded23_exempt,ded24_exempt,ded25_exempt,ded26_exempt,ded27_exempt,ded28_exempt,ded29_exempt,ded30_exempt,ded31_exempt,ded32_exempt,ded33_exempt,ded34_exempt,ded35_exempt,ded36_exempt,ded37_exempt,ded38_exempt,ded39_exempt,ded40_exempt",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ppctl_orgn",
    "PKColumns": "",
    "TableColumns": "classify,pos,orgn,acct,prcent",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ppctl_proj",
    "PKColumns": "",
    "TableColumns": "classify,pos,proj,acct,prcent",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pposition",
    "PKColumns": "",
    "TableColumns": "classify,pos,auth_fte,fill_fte,fte,locn,text1,text2,bsalary",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pposn_data2",
    "PKColumns": "",
    "TableColumns": "yr,classify,pos,description,posn_days,posn_fte_open,bargain",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pposn_data3",
    "PKColumns": "",
    "TableColumns": "yr,classify,pos,job_type,job_descript",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pposprate",
    "PKColumns": "",
    "TableColumns": "empl_no,classify,pos,fte",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "predist",
    "PKColumns": "",
    "TableColumns": "empl_no,orgn,account,amt,pay_cd,classify,hours,pay_run",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "prevposn",
    "PKColumns": "",
    "TableColumns": "id,posn,employer,addr1,addr2,refer_ence,phone,start_date,end_date,st_salary,end_salary,leave_reason",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "proc_detail",
    "PKColumns": "",
    "TableColumns": "proc_type,proc_step,proc_def,complete,navigation",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "proc_header",
    "PKColumns": "",
    "TableColumns": "proc_type,proc_step,description,required,step_order",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "proj_def",
    "PKColumns": "",
    "TableColumns": "ln_type,indx,page_no,slabel,type_check,table_name,help_text,default_val,req,valid_if",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "proj_title",
    "PKColumns": "",
    "TableColumns": "lvl,code,title",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "projuser",
    "PKColumns": "",
    "TableColumns": "key_proj,lvl,page_no,ftext1,ftext2,ftext3,ftext4,ftext5,ftext6,ftext7,ftext8,ftext9,ftext10,tcode1,tcode2,tcode3,tcode4,tcode5,tcode6,tcode7,tcode8,tcode9,tcode10,comment1,comment2",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "proledgr",
    "PKColumns": "yr,key_proj,account",
    "TableColumns": "yr,key_proj,account,bud1,exp1,enc1,bud2,exp2,enc2,bud3,exp3,enc3,bud4,exp4,enc4,bud5,exp5,enc5,bud6,exp6,enc6,bud7,exp7,enc7,bud8,exp8,enc8,bud9,exp9,enc9,bud10,exp10,enc10,bud11,exp11,enc11,bud12,exp12,enc12,bud13,exp13,enc13,pay_encum",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pronotes",
    "PKColumns": "",
    "TableColumns": "yr,key_orgn,account,note,recno,amount",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "psavdist",
    "PKColumns": "",
    "TableColumns": "orgn_proj,acct,projection,rec_type",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ptr_ctrl",
    "PKColumns": "",
    "TableColumns": "package,command",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "publish_to_entities",
    "PKColumns": "id",
    "TableColumns": "id,yr,rec_type,key_orgn,acct,rec_stat,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "publish_to_entities_log",
    "PKColumns": "",
    "TableColumns": "batch_no,record_id,district_id,dbname,result,descript,change_date,change_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pur_app_defaults",
    "PKColumns": "user_id,app_group",
    "TableColumns": "user_id,app_group,app_default",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pur_ship_defaults",
    "PKColumns": "user_id,ship_code",
    "TableColumns": "user_id,ship_code,ship_default",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "purchase",
    "PKColumns": "po_no",
    "TableColumns": "po_no,req_no,vend_no,po_date,require,expiration,final,blanket,price_agree,confirming,terms,freight,buyer,ship_code,attention,issued,description,yr,location,vend_seq,po_type,agreement,print_text,purch_encum,requestor",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "purchase_approvals",
    "PKColumns": "",
    "TableColumns": "po_no,date_stamp,time_stamp,spiuser",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "purchrg",
    "PKColumns": "po_no,line_no,indx",
    "TableColumns": "po_no,line_no,key_orgn,account,proj,proj_acct,amount,encumber,indx,prcnt,service_order",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "purcomm",
    "PKColumns": "po_no,line_no",
    "TableColumns": "po_no,line_no,commodity,desc1,desc2,desc3,desc4,desc5,asset,stock_no,measure,quanity,unit_price,total_price,received,rec_date,qty_paid,req_no,req_line,final,sales_tax,use_tax,user_id,discpct,freight,tax_rate,dist_method,dist_key,cur_received,trade_in,prod_code,item_status,approval_req",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "purcvhis",
    "PKColumns": "",
    "TableColumns": "po_no,line_no,seq,recv_date,recv_by,recv_amt,ship_code",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "purcvnot",
    "PKColumns": "",
    "TableColumns": "po_no,line_no,seq,notes",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "purge_add_rate",
    "PKColumns": "",
    "TableColumns": "empl_no,indx,code,salary,fte,prorate,purge_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "purge_dist_orgn",
    "PKColumns": "",
    "TableColumns": "empl_no,rate_no,classify,pos,orgn,acct,prcent,purge_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "purge_dist_proj",
    "PKColumns": "",
    "TableColumns": "empl_no,rate_no,classify,pos,proj,acct,prcent,purge_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "purge_elig_payrate",
    "PKColumns": "",
    "TableColumns": "empl_no,rate_no,elig_date,purge_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "purge_empuser",
    "PKColumns": "",
    "TableColumns": "empl_no,page_no,ftext1,ftext2,ftext3,ftext4,ftext5,ftext6,ftext7,ftext8,ftext9,ftext10,tcode1,tcode2,tcode3,tcode4,tcode5,tcode6,tcode7,tcode8,tcode9,tcode10,comment1,comment2,purge_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "purge_memsrstabl",
    "PKColumns": "",
    "TableColumns": "empl_no,classify,start_date,exp_ftime,exp_weeks,status_cd,position_cd,remarks,mtd_hours,cur_hours,mtd_loc_comp,cur_loc_comp,mtd_fed_comp,cur_fed_comp,mtd_emp_cont,cur_emp_cont,fte_cont_stip,transaction_type,purge_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "purge_mmax_payrate",
    "PKColumns": "",
    "TableColumns": "empl_no,rate_no,fam_code,grd_code,cont_cyc,purge_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "purge_payrate",
    "PKColumns": "",
    "TableColumns": "empl_no,rate_no,primry,group_x,pay_hours,days_worked,hours_day,incl_dock,no_pays,fte,pay_method,pay_cycle,pay_cd,classify,occupied,cal_type,range,step_x,rate,dock_rate,cont_flg,cont_days,override,annl_sal,cont_lim,cont_bal,cont_paid,cont_start,cont_end,pay_start,pay_end,summer_pay,status_x,pyo_date,pyo_rem_pay,pyo_days,pyo_rate,pyo_amt,purge_date,dock_arrears_amt,dock_pays_remain",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "purge_posprate",
    "PKColumns": "",
    "TableColumns": "empl_no,classify,pos,fte,yr,purge_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "purtaxes",
    "PKColumns": "",
    "TableColumns": "po_no,line_no,stax_rate,utax_rate",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "pwkrtable",
    "PKColumns": "",
    "TableColumns": "work_cd,title,rate,fringe_acct",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "qual_type",
    "PKColumns": "",
    "TableColumns": "qual_code,description",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "racetable",
    "PKColumns": "",
    "TableColumns": "race,description,race_fed,race_state,sis_code",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "recdeposit",
    "PKColumns": "",
    "TableColumns": "row_id,deposit_num,deposit_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "recledgr",
    "PKColumns": "",
    "TableColumns": "rec_no,yr,key_orgn,account,proj,proj_acct,gl_account,vend_no,orig_amt,change_bal,paymt_bal,date_enc,description",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "recon_adjust",
    "PKColumns": "",
    "TableColumns": "bankacct,end_date,debit_amt,credit_amt,date_entered,entered_by,description,corrected,date_corrected,trans_no",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "recon_deposit",
    "PKColumns": "",
    "TableColumns": "bankacct,end_date,cleared,disc_date,warrant,trans_date,invoice,trans_amt,description,batch",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "recon_hdr",
    "PKColumns": "",
    "TableColumns": "bankacct,begin_date,end_date,begin_bal,end_bal,trans_date,period,yr,interest_amt,fee_amt,complete,gl_fiscal_yr,gl_fiscal_period",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "recon_je",
    "PKColumns": "",
    "TableColumns": "bankacct,end_date,cleared,trans_date,je_number,trans_amt,description,batch,je_desc",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "recon_payment",
    "PKColumns": "",
    "TableColumns": "bankacct,end_date,cleared,t_c,ck_date,check_no,vend_no,trans_amt,clear_date,void_date,yr,period,disb_fund,gl_cash",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "recon_payroll",
    "PKColumns": "row_id",
    "TableColumns": "row_id,bankacct,end_date,cleared,ck_date,check_no,empl_no,pay_amt,clear_date,void_date,pay_gl_key_orgn,pay_cash,pay_run,check_type",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "recon_raw",
    "PKColumns": "",
    "TableColumns": "full_line",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "recon_setup",
    "PKColumns": "",
    "TableColumns": "tape_type,fund_or_pay,zero_filled,bank_name,beg_chkno,len_chkno,put_zro,beg_chkamt,len_chkamt,imp_dec,beg_issdate,len_issdate,date_format,beg_clrdate,len_clrdate,jul_date,beg_acctnum,len_acctnum,acctnum",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "reconcile",
    "PKColumns": "",
    "TableColumns": "acct_num,acct_type,rec_type,clear_date,check_num,iss_date,amount",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "recvnote",
    "PKColumns": "",
    "TableColumns": "rec_no,lino,description",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "reftb_collateral",
    "PKColumns": "",
    "TableColumns": "code,description,change_date,change_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "regtb_building",
    "PKColumns": "building",
    "TableColumns": "building,building_name,district_num,street,city,state_id,zip_code,phone,principal,calendar,building_node,dist_updated,change_date,change_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "req_autoconvert",
    "PKColumns": "row_id",
    "TableColumns": "row_id,req_no,yr,req_guid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "reqaprv",
    "PKColumns": "",
    "TableColumns": "req_no,line_no,lvl,action_date,app_name,act,comment,apprvreqd",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "reqaprv_hist",
    "PKColumns": "",
    "TableColumns": "hist_date,hist_time,req_no,line_no,lvl,action_date,app_name,act,comment,apprvreqd,approval_level",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "reqchrg",
    "PKColumns": "req_no,line_no,indx",
    "TableColumns": "req_no,line_no,key_orgn,account,proj,proj_acct,amount,encumber,indx,prcnt,service_order",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "reqcomm",
    "PKColumns": "req_no,line_no",
    "TableColumns": "req_no,line_no,commodity,desc1,desc2,desc3,desc4,desc5,asset,stock_no,quanity,measure,unit_price,est_amt,rstatus,ar_date,po_no,po_line,sales_tax,use_tax,bid_no,bid_line,is_bid_item,discpct,freight,tax_rate,dist_method,dist_key,trade_in,prod_code,approval_req,vend_no,vend_seq",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "reqcomnt",
    "PKColumns": "",
    "TableColumns": "req_no,seq,comment",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "reqlinds",
    "PKColumns": "",
    "TableColumns": "req_no,line_no,seq,description",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "reqtaxes",
    "PKColumns": "",
    "TableColumns": "req_no,line_no,stax_rate,utax_rate",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "requisit",
    "PKColumns": "req_no",
    "TableColumns": "req_no,location,po_no,requested,require,printed,ship_code,rec_vend,freight,buyer,comment_1,comment_2,comment_3,attention,yr,agreement,descr,print_text,vend_seq,requestor",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "requisit_approvals",
    "PKColumns": "",
    "TableColumns": "req_no,date_stamp,time_stamp,spiuser",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "retclass",
    "PKColumns": "",
    "TableColumns": "classify,start_date,end_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "retro_log",
    "PKColumns": "",
    "TableColumns": "empl_no,jobclass,primry,retrotype,sched,orig_paycd,step_b,range_b,step_a,range_a,sched_date,payout_type,num_rpays,startpayrun,retro_paycd_1,retro_amt_1,hist_start_1,hist_end_1,num_pays_1,retro_paycd_2,retro_amt_2,hist_start_2,hist_end_2,num_pays_2,perpay_amt,active",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "retro_paycodes",
    "PKColumns": "",
    "TableColumns": "type_x,code,desc_x",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "rev_deduct",
    "PKColumns": "",
    "TableColumns": "yr,key_orgn,fund,account,prcnt",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "revledgr",
    "PKColumns": "yr,key_orgn,account",
    "TableColumns": "yr,key_orgn,account,bud1,exp1,enc1,bud2,exp2,enc2,bud3,exp3,enc3,bud4,exp4,enc4,bud5,exp5,enc5,bud6,exp6,enc6,bud7,exp7,enc7,bud8,exp8,enc8,bud9,exp9,enc9,bud10,exp10,enc10,bud11,exp11,enc11,bud12,exp12,enc12,bud13,exp13,enc13",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "revnotes",
    "PKColumns": "",
    "TableColumns": "yr,key_orgn,account,note,recno,amount",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "role_assign",
    "PKColumns": "",
    "TableColumns": "row_id,role_id,uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "role_dept",
    "PKColumns": "",
    "TableColumns": "role_assign_id,dept_type,dept_bld_val",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "rpt_head",
    "PKColumns": "",
    "TableColumns": "rpt_id,yr,title_text",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "rptcol",
    "PKColumns": "",
    "TableColumns": "rpt_id,yr,column_no,head1,head2,column_type,whole_dollar,total_column,fund,orgn1,orgn2,orgn3,orgn4,orgn5,orgn6,orgn7,orgn8,orgn9,acct,where_part,ledger_yr,start_per,end_per,where_type",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "rptlayout",
    "PKColumns": "",
    "TableColumns": "rpt_id,yr,reclen,header,whole,hdr1o,hdr1c,hdr1l,cdo,cdc,cdl,txt1o,txt1c,txt1l,txt2o,txt2c,txt2l,txt3o,txt3c,txt3l,txt4o,txt4c,txt4l,txt5o,txt5c,txt5l,txt6o,txt6c,txt6l,txt7o,txt7c,txt7l,txt8o,txt8c,txt8l,txt9o,txt9c,txt9l,col1o,col1c,col1l,col2o,col2c,col2l,col3o,col3c,col3l,col4o,col4c,col4l,col5o,col5c,col5l,col6o,col6c,col6l,col7o,col7c,col7l,headrec,trailer",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "rptline",
    "PKColumns": "",
    "TableColumns": "rpt_id,yr,line_no,line_desc,code,text1,text2,text3,text4,text5,text6,text7,text8,text9,total_line,fund,orgn1,orgn2,orgn3,orgn4,orgn5,orgn6,orgn7,orgn8,orgn9,acct,where_part,gl_where_part,where_type",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "rptmaint",
    "PKColumns": "",
    "TableColumns": "rpt_id,yr,line_no,line_desc,code,text1,text2,text3,text4,text5,text6,text7,text8,text9,col1,col2,col3,col4,col5,col6,col7",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "rqacctap",
    "PKColumns": "",
    "TableColumns": "req_no,line_no,range_code,action_date,app_name,act,comment",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "rqacctap_hist",
    "PKColumns": "",
    "TableColumns": "hist_date,hist_time,req_no,line_no,range_code,action_date,app_name,act,comment",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "rsn_tabl",
    "PKColumns": "",
    "TableColumns": "rsn_code,rsn_desc,pay_code,pay_type,units_day,orgn,account",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "rstable",
    "PKColumns": "",
    "TableColumns": "range,desc_x,step_1,pcnt_1,step_2,pcnt_2,step_3,pcnt_3,step_4,pcnt_4,step_5,pcnt_5,step_6,pcnt_6,step_7,pcnt_7,step_8,pcnt_8,step_9,pcnt_9,step_10,pcnt_10,step_11,pcnt_11,step_12,pcnt_12,step_13,pcnt_13,step_14,pcnt_14,step_15,pcnt_15,step_16,pcnt_16,step_17,pcnt_17,step_18,pcnt_18,step_19,pcnt_19,step_20,pcnt_20,step_21,pcnt_21,step_22,pcnt_22,step_23,pcnt_23,step_24,pcnt_24,step_25,pcnt_25,step_26,pcnt_26,step_27,pcnt_27,step_28,pcnt_28,step_29,pcnt_29,step_30,pcnt_30,step_31,pcnt_31,step_32,pcnt_32,step_33,pcnt_33,step_34,pcnt_34,step_35,pcnt_35,step_36,pcnt_36,step_37,pcnt_37,step_38,pcnt_38,step_39,pcnt_39,step_40,pcnt_40,step_41,pcnt_41,step_42,pcnt_42,step_43,pcnt_43,step_44,pcnt_44,step_45,pcnt_45,step_46,pcnt_46,step_47,pcnt_47,step_48,pcnt_48,step_49,pcnt_49,step_50,pcnt_50,step_51,pcnt_51,step_52,pcnt_52,step_53,pcnt_53,step_54,pcnt_54,step_55,pcnt_55,step_56,pcnt_56,step_57,pcnt_57,step_58,pcnt_58,step_59,pcnt_59,step_60,pcnt_60,step_61,pcnt_61,step_62,pcnt_62,step_63,pcnt_63,step_64,pcnt_64,step_65,pcnt_65,step_66,pcnt_66,step_67,pcnt_67,step_68,pcnt_68,step_69,pcnt_69,step_70,pcnt_70,step_71,pcnt_71,step_72,pcnt_72,step_73,pcnt_73,step_74,pcnt_74,step_75,pcnt_75,step_76,pcnt_76,step_77,pcnt_77,step_78,pcnt_78,step_79,pcnt_79,step_80,pcnt_80,step_81,pcnt_81,step_82,pcnt_82,step_83,pcnt_83,step_84,pcnt_84,step_85,pcnt_85,step_86,pcnt_86,step_87,pcnt_87,step_88,pcnt_88,step_89,pcnt_89,step_90,pcnt_90,step_91,pcnt_91,step_92,pcnt_92,step_93,pcnt_93,step_94,pcnt_94,step_95,pcnt_95,step_96,pcnt_96,step_97,pcnt_97,step_98,pcnt_98,step_99,pcnt_99",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "rule_definitions",
    "PKColumns": "rule_id",
    "TableColumns": "rule_id,area,field_name,operator,comparison_value,ending_value,exclude,grouping,notes,rulegroup_id,sequence,created_date,created_by,modified_by",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "rule_group",
    "PKColumns": "rulegroup_id",
    "TableColumns": "rulegroup_id,rulegroup_name,notes,created_date,created_by,modified_by",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "rule_groupdata2",
    "PKColumns": "rulegroup_id",
    "TableColumns": "rulegroup_id,rulegroup_source",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sal_inc",
    "PKColumns": "",
    "TableColumns": "empl_no,rate_no,dock_rate,rate,duty_amt,fam_code,grd_code,dept,chk_locn,rate_type,orig_cell,proj_cell,days_work,orig_sal,proj_sal,mid_sal,max_sal,orig_max,proj_max",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "salsch_code",
    "PKColumns": "",
    "TableColumns": "lea,fy,code",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "school",
    "PKColumns": "",
    "TableColumns": "code,desc_x",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "screen_attr_additions",
    "PKColumns": "",
    "TableColumns": "group_id,field_id,CB_table,CB_value,CB_description,CB_where",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "screen_attr_tbl",
    "PKColumns": "",
    "TableColumns": "group_id,client_type,state_id,site_id,key_name,field_id,field_type,field_style,field_label,comments,field_hidden,field_noentry",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "screen_desc",
    "PKColumns": "",
    "TableColumns": "rpt_type,rpt_option,rpt_description1,rpt_description2,rpt_description3,rpt_description4,rpt_description5,rpt_description6,rpt_description7,rpt_description8,rpt_description9,rpt_description10",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "search_detail",
    "PKColumns": "",
    "TableColumns": "searchid,line_no,intab,incol,inoperation,inval,hival,ingroup,injoin",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "search_groupkeys",
    "PKColumns": "",
    "TableColumns": "grpname,tabname,collist",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "search_groups",
    "PKColumns": "grpname,tabname",
    "TableColumns": "grpname,tabname,join_type",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "search_header",
    "PKColumns": "",
    "TableColumns": "searchid,grpname,ownername,searchname,searchdesc,is_public",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "search_keys",
    "PKColumns": "tabname,joinalias",
    "TableColumns": "tabname,keyname,joinalias",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "search_nxtno",
    "PKColumns": "",
    "TableColumns": "tab_name,next_no",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sec_user_menu_cache",
    "PKColumns": "login_id",
    "TableColumns": "login_id,menu,reset,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sectb_access",
    "PKColumns": "",
    "TableColumns": "uid,usertype,stampid,stampdate,stamptime",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sectb_action_feature",
    "PKColumns": "area,controller,action,feature_id",
    "TableColumns": "area,controller,action,feature_id,read_access_resource,write_access_resource,description,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sectb_action_resource",
    "PKColumns": "area,controller,action",
    "TableColumns": "area,controller,action,read_access_resource,write_access_resource,description,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sectb_adgroups",
    "PKColumns": "",
    "TableColumns": "group_name",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sectb_attachaccess",
    "PKColumns": "",
    "TableColumns": "attach_id,sec_type,usertype,stampid,stampdate,stamptime",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sectb_crosswalk",
    "PKColumns": "spiuser",
    "TableColumns": "spiuser,windomain,winuser",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sectb_delegate",
    "PKColumns": "row_id",
    "TableColumns": "spiuser,workflow_type_id,task_id,start_date,end_date,delegate_uid,row_id",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sectb_license",
    "PKColumns": "id",
    "TableColumns": "id,uid,name,description,active,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sectb_package",
    "PKColumns": "",
    "TableColumns": "package,descript,stampid,stampdate,stamptime",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sectb_privilege",
    "PKColumns": "",
    "TableColumns": "priv_code,descript,stampid,stampdate,stamptime",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sectb_profile",
    "PKColumns": "",
    "TableColumns": "sec_attach,ad_integrate,ad_val_groups,ad_limit_adgroups,ad_synch_time",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sectb_resource",
    "PKColumns": "",
    "TableColumns": "usertype,package,subpack,func,priv_code,descript,stampid,stampdate,stamptime",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sectb_roleaccess",
    "PKColumns": "",
    "TableColumns": "role_id,usertype,stampid,stampdate,stamptime",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sectb_roles",
    "PKColumns": "",
    "TableColumns": "role_id,role_descript,ad_group,role_status,stampid,stampdate,stamptime",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sectb_roleusers",
    "PKColumns": "",
    "TableColumns": "role_id,spiuser,stampid,stampdate,stamptime",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sectb_subpack",
    "PKColumns": "",
    "TableColumns": "subpack,descript,stampid,stampdate,stamptime",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sectb_user",
    "PKColumns": "",
    "TableColumns": "uid,lname,fname,email,building,bld_group,dept,fund,orgn,project,user_dba,qwarn,qlimit,stampid,stampdate,stamptime",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sectb_usrviw",
    "PKColumns": "",
    "TableColumns": "user_id,viewcode,view_txt,ent_date,ent_operator,upd_date,upd_operator",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "secure_elements",
    "PKColumns": "field_name",
    "TableColumns": "field_name,secure_id,secure_name,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "senior",
    "PKColumns": "",
    "TableColumns": "empl_no,union_cd,division,classify,sen_date,prob_date,dist_yrs,pos_yrs,serv_yrs,upd_yrs_f",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "setup_g",
    "PKColumns": "",
    "TableColumns": "tax_yr,typ1,amt1,typ2,amt2,typ5,amt5,typ6,amt6,typ7,amt7,typ9,amt9",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "setup_int",
    "PKColumns": "",
    "TableColumns": "tax_yr,typ1,amt1,typ2,amt2,typ3,amt3,typ5n,amt5n,typ5,amt5,typ8,amt8,typ9,amt9",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "setup_misc",
    "PKColumns": "",
    "TableColumns": "tax_yr,typ1,amt1,typ2,amt2,typ3,amt3,typ5,amt5,typ6,amt6,typ7,amt7,typ8,amt8,typ10,amt10,typ13,amt13,typ14,amt14,typ15a,amt15a,typ15b,amt15b,inc1,inc2,inc3,inc5,inc6,inc7,inc8,inc10,inc13,inc14,inc15a,inc15b,typ11,amt11,inc11",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "setup1099",
    "PKColumns": "",
    "TableColumns": "tax_yr,contact,payer_name,payer_address,payer_city,payer_state,payer_zip,payer_phone,payer_ein,payer_name_control,trans_code,fs_filer,state_number,prt_detail,media_code,email,op_type,flg_print,p_name,comp_name",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sfattend",
    "PKColumns": "",
    "TableColumns": "empl_no,pay_code,start_date,end_date,lv_hrs,remarks,check_date,status_flg,lv_code,pay_run,post_flag,sub_id,sub_pay_code,sub_pay_class,sub_hours,sub_pay_rate,sub_amt_paid,sub_loc,sub_tax_ind,sub_orgn,sub_acct,cal_val,sf_id,sf_post_flag,sf_run",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sfe_accountmask",
    "PKColumns": "id",
    "TableColumns": "id,job_number,account_mask,orgn,acct,prcent,row_id,absence_type,lv_status",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sfe_business_rules",
    "PKColumns": "rule_id",
    "TableColumns": "priority,rule_id,rule_title,rule_role,start_date,end_date,budget_code,reason_code,units_to_pay,work_unit,wrk_hrs_or_prcnt,timecard,account_mask,islongtermsubstitute,consecutive_days,job_class,pay_code,pay_rate",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sfe_classification_mapping",
    "PKColumns": "sfe_class_cd",
    "TableColumns": "sfe_class_cd,description,emp_job_class,sub_job_class,sub_pay_code",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sfe_criteria_mapping",
    "PKColumns": "criteria_id",
    "TableColumns": "criteria_id,rule_id,table_name,table_code",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sfe_crosswalk",
    "PKColumns": "id",
    "TableColumns": "id,job_class,pay_code,empl_type",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sfe_location_crosswalk",
    "PKColumns": "id",
    "TableColumns": "id,building_location,personnel_location",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sfe_rule_history",
    "PKColumns": "history_id",
    "TableColumns": "history_id,rule_id,date_chg,table_name,field_name,operator,old_value,new_value,time_chg",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sfe_rule_match_hist",
    "PKColumns": "id",
    "TableColumns": "id,row_id,rule_id,is_emp_or_sub,emp_sub_id",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sfe_sub_vacancy_table",
    "PKColumns": "row_id",
    "TableColumns": "row_id,sub_empl_no,pay_code,sub_job_class,job_number,start_date,end_date,status,sub_hrs,pay_rate,amount,location,tax,budget_unit,account,post_flg",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sfe_sub_vacancy_table_renamed",
    "PKColumns": "row_id",
    "TableColumns": "row_id,sub_empl_no,pay_code,sub_job_class,job_number,start_date,end_date,status,sub_hrs,pay_rate,amount,location,tax,budget_unit,account,post_flg,account_mask",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sfe_work_hours",
    "PKColumns": "work_id",
    "TableColumns": "work_id,rule_id,custom_from,custom_to,hours_or_days",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sftimecrd",
    "PKColumns": "",
    "TableColumns": "empl_no,pay_code,hours,payrate,amount,orgn,account,proj,pacct,classify,pay_cycle,tax_ind,pay_run,subtrack_id,reported,user_chg,date_chg,flsa_cycle,flsa_flg,flsa_carry_ovr,post_flag,sf_id,job_date,posted",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "shared_info",
    "PKColumns": "empl_no",
    "TableColumns": "empl_no,password,uid,chg_pwd,user_dcid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "shared_info_hist",
    "PKColumns": "empl_no,change_date_time",
    "TableColumns": "empl_no,password,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "shdtable",
    "PKColumns": "",
    "TableColumns": "code,desc_x,hs_flag,max_step,num_ranges,days_worked,hours_day,bn_flag,state_hours_day",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "shipping",
    "PKColumns": "",
    "TableColumns": "code,address1,address2,address3,address4,city,state_id,zip",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sif_assignment",
    "PKColumns": "",
    "TableColumns": "asncode,func_code,description",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sif_event_det",
    "PKColumns": "transaction_id,column_name",
    "TableColumns": "transaction_id,column_name,new_value,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sif_event_hdr",
    "PKColumns": "transaction_id,sif_event",
    "TableColumns": "transaction_id,sif_event,action_type,summer_school,sif_message,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sif_guid_emp",
    "PKColumns": "empl_no",
    "TableColumns": "empl_no,object_guid,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sif_guid_empasgn",
    "PKColumns": "empl_no,asncode",
    "TableColumns": "empl_no,asncode,object_guid,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sif_guid_loc",
    "PKColumns": "code",
    "TableColumns": "code,object_guid,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sif_guid_staff",
    "PKColumns": "empl_no",
    "TableColumns": "empl_no,object_guid,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sif_guid_staffasgn",
    "PKColumns": "empl_no,asncode",
    "TableColumns": "empl_no,asncode,object_guid,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sif_publish",
    "PKColumns": "agent_id,sif_event",
    "TableColumns": "agent_id,sif_event,message_id,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sif_subscribe",
    "PKColumns": "agent_id,sif_event",
    "TableColumns": "agent_id,sif_event,message_id,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sis_staffrules",
    "PKColumns": "sequence",
    "TableColumns": "area,field_name,operator,comparison_value,ending_value,exclude,grouping,notes,sequence,created_date,created_by",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "site_info",
    "PKColumns": "",
    "TableColumns": "site_code,type,name,state_id,optional1,optional2,sub_site_code,sw_version,district_type",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sjournal",
    "PKColumns": "",
    "TableColumns": "je_number,description,key_orgn,account,project,proj_acct,debit_amt,credit_amt,hold_flg,date_entered,entered_by,batch,item_desc,row_id",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "source",
    "PKColumns": "",
    "TableColumns": "fund_source,fund_source_desc",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sourceamt",
    "PKColumns": "",
    "TableColumns": "fiscal_yr,fund_source,fund_type,amount,change_time,change_date,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "spayable",
    "PKColumns": "",
    "TableColumns": "enc_no,line_no,p_f,key_orgn,account,project,proj_acct,vend_no,c_1099,gl_cash,due_date,invoice,amount,description,single_ck,disc_date,disc_amt,voucher,hold_flg,date_entered,entered_by,batch,sales_tax,use_tax,row_id,app_group",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "spi_code_in_use",
    "PKColumns": "table_name,column_name,foreign_key_table_name,foreign_key_column_name",
    "TableColumns": "table_name,column_name,foreign_key_table_name,foreign_key_column_name,use_env_district,use_env_school_year,use_env_summer_school,criteria,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "spi_code_in_use_filter",
    "PKColumns": "table_name,column_name,foreign_key_table_name,foreign_key_column_name,filter_column_name",
    "TableColumns": "table_name,column_name,foreign_key_table_name,foreign_key_column_name,filter_column_name,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "spi_column_control",
    "PKColumns": "columncontrolid",
    "TableColumns": "columncontrolid,tablename,columnname,controltypeid,reserved,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "spi_column_info",
    "PKColumns": "table_name,column_name",
    "TableColumns": "table_name,column_name,ui_control_type,val_list,val_list_disp,val_tbl_name,val_col_code,val_col_desc,val_sql_where,val_order_by_code,val_disp_format,sec_package,sec_subpackage,column_width,change_date_time,change_uid,sec_feature",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "spi_column_names",
    "PKColumns": "table_name,column_name,culture_code",
    "TableColumns": "table_name,column_name,culture_code,column_description,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "spi_column_validation",
    "PKColumns": "table_name,column_name",
    "TableColumns": "table_name,column_name,val_list,val_list_disp,val_tbl_name,val_col_code,val_col_desc,val_sql_where,reserved,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "spi_conv_codes",
    "PKColumns": "",
    "TableColumns": "type,code",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "SPI_INTEGRATION_DET",
    "PKColumns": "DISTRICT,PRODUCT,OPTION_NAME",
    "TableColumns": "DISTRICT,PRODUCT,OPTION_NAME,OPTION_VALUE",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "SPI_INTEGRATION_HDR",
    "PKColumns": "DISTRICT,PRODUCT",
    "TableColumns": "DISTRICT,PRODUCT,DESCRIPTION,PACKAGE,SUBPACKAGE,FEATURE",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "SPI_INTEGRATION_LOGIN",
    "PKColumns": "DISTRICT,PRODUCT,LOGIN_ID",
    "TableColumns": "DISTRICT,PRODUCT,LOGIN_ID,OTHER_LOGIN_ID",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "SPI_INTEGRATION_SESSION_DET",
    "PKColumns": "SESSION_GUID,VARIABLE_NAME",
    "TableColumns": "SESSION_GUID,VARIABLE_NAME,VARIABLE_VALUE",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "SPI_INTEGRATION_SESSION_HDR",
    "PKColumns": "SESSION_GUID",
    "TableColumns": "SESSION_GUID,TSTAMP",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "spi_option_column_nullable",
    "PKColumns": "search_type,table_name,column_name",
    "TableColumns": "search_type,table_name,column_name,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "spi_option_excld",
    "PKColumns": "search_type,table_name,column_name",
    "TableColumns": "search_type,table_name,column_name,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "spi_option_list_field",
    "PKColumns": "search_type,table_name,column_name",
    "TableColumns": "search_type,table_name,column_name,display_order,is_hidden,formatter,navigation_param,column_label,is_sec_building_col,column_width,reserved,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "spi_option_name",
    "PKColumns": "search_type",
    "TableColumns": "search_type,option_name,navigate_to,btn_new_navigate,user_def_scr_type,use_programs,target_table,delete_table,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "spi_option_simple_search",
    "PKColumns": "search_type,table_name,column_name,environment",
    "TableColumns": "search_type,table_name,column_name,environment,display_order,operator,override_label,reserved,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "spi_option_table",
    "PKColumns": "search_type,table_name",
    "TableColumns": "search_type,table_name,sequence_num,sec_package,sec_subpackage,sec_feature,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "spi_option_update",
    "PKColumns": "search_type,table_name,column_name",
    "TableColumns": "search_type,table_name,column_name,ui_control_type,is_required,entry_filter,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "spi_search_fav",
    "PKColumns": "login_id,search_type,search_number",
    "TableColumns": "login_id,search_type,search_number,search_name,description,last_search,grouping_mask,category,publish,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "spi_search_fav_subscribe",
    "PKColumns": "login_id,pub_login_id,pub_search_type,pub_search_number",
    "TableColumns": "login_id,pub_login_id,pub_search_type,pub_search_number,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "spi_table_join",
    "PKColumns": "source_table,target_table,sequence_number",
    "TableColumns": "source_table,target_table,sequence_number,join_table_1,join_column_1,join_table_2,join_column_2,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "spi_table_names",
    "PKColumns": "table_name",
    "TableColumns": "table_name,table_description,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "spi_user_search",
    "PKColumns": "login_id,search_type,search_number,sequence_num",
    "TableColumns": "login_id,search_type,search_number,sequence_num,and_or_flag,table_name,screen_type,screen_number,program_id,column_name,field_number,operator,search_value1,search_value2,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "spi_user_search_list_field",
    "PKColumns": "login_id,search_type,search_number,sequence_num",
    "TableColumns": "login_id,search_type,search_number,sequence_num,table_name,screen_type,screen_number,program_id,column_name,field_number,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "spi_user_sort",
    "PKColumns": "login_id,sort_type,sort_number,sequence_num",
    "TableColumns": "login_id,sort_type,sort_number,sequence_num,table_name,screen_type,screen_number,program_id,column_name,field_number,sort_order,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "spi_validation_tables",
    "PKColumns": "package,table_name,user_defined,reserved",
    "TableColumns": "package,table_name,table_descr,user_defined,custom_code,reserved,active,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "spilicense",
    "PKColumns": "",
    "TableColumns": "package,subpackage,option_name,username,description,install_date,enabled,license_key,checksum,expiration_date,user_count",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "spitb_search_fav_category",
    "PKColumns": "district,code",
    "TableColumns": "district,code,description,active,reserved,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "st2table",
    "PKColumns": "",
    "TableColumns": "state_id,pay_freq,marital,ear,amt,per",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "st3table",
    "PKColumns": "",
    "TableColumns": "state_id,pay_freq,marital,cred",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "state_clstable",
    "PKColumns": "",
    "TableColumns": "class_cd,nh_stoprule_exempt,certi_req,check3",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "state_levtable",
    "PKColumns": "lv_code",
    "TableColumns": "lv_code,check1,check2,check3,check4,check5,check6,check7,check8,check9,check10,check11,check12,check13,check14,check15,char1,char2,decimal1,decimal2,date1,date2",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "state_list_bucket",
    "PKColumns": "",
    "TableColumns": "ID,item_code,description",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "state_list_item",
    "PKColumns": "",
    "TableColumns": "item_id,item_value",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "state_paytable",
    "PKColumns": "pay_code",
    "TableColumns": "pay_code,check1,check2,check3,check4,check5,check6,check7,check8,check9,check10,check11,check12,check13,check14,check15,char1,char2,decimal1,decimal2,date1,date2,cb001,cb002",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "states",
    "PKColumns": "code",
    "TableColumns": "code,desc_x,code1",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "stathist",
    "PKColumns": "",
    "TableColumns": "empl_no,stat,statdt",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "statustb",
    "PKColumns": "code",
    "TableColumns": "code,desc_x",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sttable",
    "PKColumns": "",
    "TableColumns": "state_id,pay_freq,marital,account,stan_rate,stan_min,stan_max,mar_exemp,depend,supp_per",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "stu_course",
    "PKColumns": "",
    "TableColumns": "school_year,building,course,course_section,summer_school,state_course,description",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "stu_qualif",
    "PKColumns": "",
    "TableColumns": "school_year,building,course,course_section,summer_school,qual_code_crse,is_required",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "stu_staff",
    "PKColumns": "",
    "TableColumns": "school_year,building,course,course_section,course_session,summer_school,empl_no,primary_staff,student_count",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "stuact_code",
    "PKColumns": "code",
    "TableColumns": "code,description,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "stuact_ledger",
    "PKColumns": "yr,locn_act_code,account",
    "TableColumns": "yr,locn_act_code,account,bud1,bud2,bud3,bud4,bud5,bud6,bud7,bud8,bud9,bud10,bud11,bud12,bud13,exp1,exp2,exp3,exp4,exp5,exp6,exp7,exp8,exp9,exp10,exp11,exp12,exp13,enc1,enc2,enc3,enc4,enc5,enc6,enc7,enc8,enc9,enc10,enc11,enc12,enc13,pay_encum,inv_bal,req_bal,bud_adj,prior_yr_actual,prior_yr_budget,active,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "stuact_locn_act",
    "PKColumns": "locn_act_code",
    "TableColumns": "locn_act_code,locn_act_desc,locn,act_code,start_date,end_date,bank_acct,fund,cash_account,liability_account,exp_budget_code,exp_account,rev_budget_code,rev_account,budget_required,beginning_cash_bal,check_act_bud_bal,sponsor_id,chk_pend_cash_bal,posted_deposit_tot,posted_payment_tot,unposted_trans_tot,enc_bal,change_date_time,change_uid,ap_chk_format_id,po_chk_format_id",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "stuact_sponsor",
    "PKColumns": "locn_act_code,sponsor_id",
    "TableColumns": "locn_act_code,sponsor_id,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "stuact_sponsr_perm",
    "PKColumns": "locn_act_code,sponsor_id,resource_code",
    "TableColumns": "locn_act_code,sponsor_id,resource_code,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "stuact_trans_audit",
    "PKColumns": "stu_trans_no",
    "TableColumns": "stu_trans_no,adjust_no,orig_key_orgn,new_key_orgn,orig_account,new_account,orig_desc,new_desc,orig_amount,new_amount,adj_je_no,change_date_time,changed_by",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "stuact_trans_notes",
    "PKColumns": "stu_trans_no,line_no",
    "TableColumns": "locn_act,stu_trans_no,id_no,note_type,line_no,vend_no,description,change_date_time,changed_by",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "stuact_transact",
    "PKColumns": "stu_trans_no",
    "TableColumns": "stu_trans_no,yr,period,t_c,fund,locn_act_code,trans_date,key_orgn,account,gl_cash,gl_liability,enc_no,line_no,je_number,check_no,ck_date,cleared,trans_amt,liquid,vend_no,payer_no,invoice,p_f,c_1099,cancel,due_date,disc_date,disc_amt,description,date_entered,operator,batch,je_desc,qty_paid,qty_rec,split_link_no,bnk_code,sales_tax,clear_date,alt_vend_no,fam_trans_no,deposit_no,reconciled,use_tax,disb_gl_key_orgn",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sub_classes",
    "PKColumns": "",
    "TableColumns": "emp_class,sub_class,sub_paycode,sub_payrate",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sub1table",
    "PKColumns": "",
    "TableColumns": "sub_1_acct,sub1key,sub1title",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sub2table",
    "PKColumns": "",
    "TableColumns": "sub_2_acct,sub2keyup,sub2key,sub2title",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sub3table",
    "PKColumns": "",
    "TableColumns": "sub_3_acct,sub3keyup,sub3key,sub3title",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "subject",
    "PKColumns": "",
    "TableColumns": "code,desc_x",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "subtypetable",
    "PKColumns": "",
    "TableColumns": "code,desc_x",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "suffix_table",
    "PKColumns": "",
    "TableColumns": "suffix_code",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sumdetdist",
    "PKColumns": "",
    "TableColumns": "yr,empl_no,pay_run,check_no,classify,rec_type,code,orgn,acct,fund,liab_acct,amount",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sumfiscdist",
    "PKColumns": "",
    "TableColumns": "yr,empl_no,classify,rec_type,code,orgn,acct,fund,liab_acct,accr_amt,liq_amt,bal_amt,accr_status,load_date,load_user,post_date,post_user,delete_date,delete_user,complete_date,complete_user,orig_sal_orgn,orig_sal_acct,prim_sal_orgn,prim_sal_acct",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sumfiscliab",
    "PKColumns": "",
    "TableColumns": "exp_type,code_val,orgn_mask,liab_mask,fund",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sv_search_detail",
    "PKColumns": "row_id",
    "TableColumns": "row_id,search_id,field_name,value",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "sv_search_master",
    "PKColumns": "search_id",
    "TableColumns": "search_id,form_name,uid,pgm_run_cmd",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "systb_columns",
    "PKColumns": "tabname,colname",
    "TableColumns": "tabname,colname,descript1,descript2,descript3,descript4,change_date,change_time,change_uid,table_help,friendly_name",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "systb_tables",
    "PKColumns": "tabname",
    "TableColumns": "tabname,package,subpack,customer,descript1,descript2,descript3,descript4,change_date,change_time,change_uid,friendly_name",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "system_void_chk",
    "PKColumns": "",
    "TableColumns": "disb_fund,check_no,vend_no,ven_name,status,amount,description,int_check_no,operator",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "t_app_time",
    "PKColumns": "",
    "TableColumns": "empl_no,dept_code,week_starting,app_level,sup_empl_no,pay_run,date_posted",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "t_applicant",
    "PKColumns": "",
    "TableColumns": "id,passwd,ssn,f_name,l_name,email_addr",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "t_dept",
    "PKColumns": "",
    "TableColumns": "dept_code,dept_desc,dept_level,use_subs",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "t_detail",
    "PKColumns": "",
    "TableColumns": "empl_no,dept_code,week_starting,pay_lve_cd,code_type,hrs_1,hrs_2,hrs_3,hrs_4,hrs_5,hrs_6,hrs_7",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "t_detnotes",
    "PKColumns": "",
    "TableColumns": "empl_no,week_starting,line_no,note_text",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "t_employee",
    "PKColumns": "",
    "TableColumns": "empl_no,password,dept_code,super_flag",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "t_help",
    "PKColumns": "",
    "TableColumns": "help_code,help_desc",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "t_levtable",
    "PKColumns": "lv_code,pay_code",
    "TableColumns": "lv_code,pay_code",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "t_profile",
    "PKColumns": "",
    "TableColumns": "start_day,max_day,max_day_flag,max_week,max_week_flag,min_pass_len,max_pass_len,unapp_flag,sched_flag,leave_flag,default_sort",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "t_schdept",
    "PKColumns": "",
    "TableColumns": "sch_code,dept_code",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "t_schedule",
    "PKColumns": "",
    "TableColumns": "sch_code,sch_desc,sch_default,mon_y_n,tue_y_n,wed_y_n,thu_y_n,fri_y_n,sat_y_n,sun_y_n",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "t_subdept",
    "PKColumns": "",
    "TableColumns": "dept_code,sub_dept_code",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "t_super",
    "PKColumns": "",
    "TableColumns": "empl_no,dept_code,app_level",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "t_unapp_codes",
    "PKColumns": "",
    "TableColumns": "unapp_code,reason_1,reason_2",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "t_unapprove",
    "PKColumns": "",
    "TableColumns": "empl_no,dept_code,week_starting,unapp_date,sup_empl_no,unapp_code,reason_1,reason_2",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "t1099",
    "PKColumns": "",
    "TableColumns": "form_1099,code,descrip,row_id",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "t99rmain",
    "PKColumns": "",
    "TableColumns": "taxyr,ename,addr1,addr2,city,state_id,zip,zipext,phone,eid,stid,flg_name,flg_ein,flg_sid,flg_control,flg_form,term_code,comp_name,flg_media,density,notify,pnc_1099,transco_1099,fs_file_1099,prt_detail_1099,prt_empdept_1099,contact,pid,faxno,email,flg_print,p_name",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "task_access",
    "PKColumns": "",
    "TableColumns": "task_id,usertype",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "task_condition",
    "PKColumns": "",
    "TableColumns": "row_id,task_id,table_name,column_name",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "task_condition_val",
    "PKColumns": "",
    "TableColumns": "row_id,condition_id,condition_value",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "task_role",
    "PKColumns": "",
    "TableColumns": "task_id,role_id",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "task_table",
    "PKColumns": "task_id",
    "TableColumns": "task_id,task_name,spi_defined,workflow_type",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "taxrate",
    "PKColumns": "",
    "TableColumns": "code,rate,description",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "tb_title",
    "PKColumns": "",
    "TableColumns": "menu_path,title,menuid,change_date,change_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "tcdc_employee",
    "PKColumns": "talend_cdc_subscribers_name",
    "TableColumns": "talend_cdc_subscribers_name,talend_cdc_state,talend_cdc_type,talend_cdc_creation_date,empl_no",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "tcdc_referencetable",
    "PKColumns": "talend_cdc_subscribers_name",
    "TableColumns": "talend_cdc_subscribers_name,talend_cdc_state,talend_cdc_type,talend_cdc_creation_date,column_cd,column_name,table_name",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "te_employee",
    "PKColumns": "",
    "TableColumns": "empl_no,pay_run,cycle_end_date,cycle_hrshol,cycle_hrslwp,cycle_hrssic,cycle_hrsvac,cycle_hrsreg,cycle_hrsovt,cycle_hrsoth,cycle_post_flag",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "te_payroll",
    "PKColumns": "",
    "TableColumns": "empl_no,cycle_end_date,cycle_days",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "telquote",
    "PKColumns": "",
    "TableColumns": "req_no,line_no,vend_no,vend_seq,prod_code,resp_date,measure,price,response,response2,response3,quanity,est_amt",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "temp_items",
    "PKColumns": "",
    "TableColumns": "menu_path,choice,choicedesc,progcall,callpath,run_command,package,subpack,func,change_date,change_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "temp_titl",
    "PKColumns": "",
    "TableColumns": "menu_path,title,menuid,change_date,change_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "termaprv",
    "PKColumns": "request_id,lvl,association_id",
    "TableColumns": "request_id,lvl,association_id,association_seq,app_empl_no,del_empl_no,act,action_date,comment,approved_by",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "termaprv_hist",
    "PKColumns": "row_id",
    "TableColumns": "row_id,request_id,hist_date,hist_time,lvl,association_id,association_seq,app_empl_no,del_empl_no,act,action_date,comment,approved_by,approval_level",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "termchrg",
    "PKColumns": "",
    "TableColumns": "agree_no,seq,key_orgn,account,project,proj_acct,service_order,percentage",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "termcmnt",
    "PKColumns": "",
    "TableColumns": "agree_no,seq,comment",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "termcomm",
    "PKColumns": "",
    "TableColumns": "agree_no,line_no,commodity,prod_code,measure,quanity,ordered,unit_price",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "termcont",
    "PKColumns": "",
    "TableColumns": "agree_no,descrip,established,expires,dollar_cap,dollar_todate,vend_no,vend_seq,ship_code,discount,items_only,stand_dist,print_type",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "termempl",
    "PKColumns": "request_id",
    "TableColumns": "request_id,empl_no,term_code,status,term_date,lastday_worked,notes,submit_date,appr_status,req_empl_no",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "termlinds",
    "PKColumns": "",
    "TableColumns": "agree_no,line_no,seq,description",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "termnote",
    "PKColumns": "",
    "TableColumns": "agree_no,seq,note",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "tertable",
    "PKColumns": "code",
    "TableColumns": "code,desc_x,state_term_code",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "time_att",
    "PKColumns": "",
    "TableColumns": "empl_no,pay_run,pay_column,start_date,stop_date,lv_hrs",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "time_oth",
    "PKColumns": "",
    "TableColumns": "empl_no,pay_run,class_cd,pay_code,start_date,stop_date,hours,payrate,amount,cycle_end_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "timecard",
    "PKColumns": "",
    "TableColumns": "empl_no,pay_code,hours,payrate,amount,orgn,account,proj,pacct,classify,pay_cycle,tax_ind,pay_run,subtrack_id,reported,user_chg,date_chg,flsa_cycle,flsa_flg,flsa_carry_ovr,ret_pers_code,loctaxcd",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "timecode",
    "PKColumns": "",
    "TableColumns": "home_orgn,class_cd,reg,hol,ovt,lwp,sic,vac",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "timedist",
    "PKColumns": "",
    "TableColumns": "empl_no,pay_run,pay_column,orgn,account,proj,pacct,hours,cycle_end_date,class_cd,pay_code",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "timeeasy",
    "PKColumns": "",
    "TableColumns": "empl_no,pay_run,hrshol,hrslwp,hrssic,hrsvac,hrsreg,hrsovt,post_flg,row_id",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "timetable",
    "PKColumns": "",
    "TableColumns": "year,period",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "tpayfile",
    "PKColumns": "",
    "TableColumns": "empl_no,seq_no,home_orgn,pdf,code,amount,fringe,orgn,proj,acct,pacct,arrears,check_no,hours,classify,dedgross,frngross,tax_ind,bank,bt_code,bank_acct,pay_cycle,chk_ind,flsa_flg,payrate",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "tr_apportab",
    "PKColumns": "",
    "TableColumns": "fund,account,int_fund,int_acct,cash_acct",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "tr_apportwk",
    "PKColumns": "",
    "TableColumns": "fund,account,cash_date,int_fund,int_acct,cash_acct,cash_bal",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "tr_balance",
    "PKColumns": "",
    "TableColumns": "fund,account,cash_date,cash_bal",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "tr_cleared",
    "PKColumns": "",
    "TableColumns": "disb_fund,warrant_no,date_issued,amount,date_paid,item_no,row_id",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "tr_djournal",
    "PKColumns": "",
    "TableColumns": "je_number,description,key_orgn,account,project,proj_acct,debit_amt,credit_amt,hold_flg,date_entered,entered_by,batch,yr,period,item_desc,row_id",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "tr_dreceipt",
    "PKColumns": "",
    "TableColumns": "enc_no,gl_recv,key_orgn,account,project,proj_acct,vend_no,gl_cash,invoice,description,trans_amt,hold_flg,date_entered,entered_by,batch,yr,period,row_id",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "tr_genledgr",
    "PKColumns": "",
    "TableColumns": "yr,fund,account,gl_bal1,gl_bal2,gl_bal3,gl_bal4,gl_bal5,gl_bal6,gl_bal7,gl_bal8,gl_bal9,gl_bal10,gl_bal11,gl_bal12,gl_bal13",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "tr_profile",
    "PKColumns": "",
    "TableColumns": "warrants,cash_pre,journ_cash,audit_name,treas_name,close_yr,acct_meth,warr_len,allow_je",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "tr_recsetup",
    "PKColumns": "",
    "TableColumns": "tape_type,fund_or_pay,zero_filled,bank_name,beg_chkno,len_chkno,beg_chkamt,len_chkamt,imp_dec,beg_issdate,len_issdate,date_format,beg_clrdate,len_clrdate,beg_acctnum,len_acctnum,acctnum,beg_disb,len_disb",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "tr_transact",
    "PKColumns": "",
    "TableColumns": "trans_no,yr,period,t_c,fund,disb_fund,key_orgn,account,project,proj_acct,gl_recv,gl_cash,trans_date,enc_no,je_number,trans_amt,vend_no,invoice,reported,description,date_entered,operator,je_desc",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "tr_warhist",
    "PKColumns": "",
    "TableColumns": "batch,disb_fund,fund,warrant_no,date_issued,amount,cash_acct",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "tr_warrants",
    "PKColumns": "",
    "TableColumns": "disb_fund,fund,warrant_no,cash_acct,date_issued,cancel,amount,date_paid,item_no,origin",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "trans_acct",
    "PKColumns": "",
    "TableColumns": "no_levels,orgn1b,orgn1e,orgn2b,orgn2e,orgn3b,orgn3e,orgn4b,orgn4e,orgn5b,orgn5e,orgn6b,orgn6e,orgn7b,orgn7e,orgn8b,orgn8e,orgn9b,orgn9e,orgn10b,orgn10e,acct1b,acct1e,acct2b,acct2e,default_struct",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "transact",
    "PKColumns": "",
    "TableColumns": "trans_no,yr,period,t_c,fund,disb_fund,key_orgn,account,project,proj_acct,gl_recv,gl_cash,trans_date,enc_no,je_number,check_no,ck_date,cleared,trans_amt,liquid,vend_no,invoice,p_f,c_1099,cancel,due_date,disc_date,disc_amt,disc_per,reported,description,date_entered,operator,batch,je_desc,qty_paid,qty_rec,line_no,warrant,bnk_code,sales_tax,use_tax,clear_date,alt_vend_no,row_id",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "transledgr",
    "PKColumns": "",
    "TableColumns": "yr,keyorgn,account,per,trans_type,bud,exp,enc",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "transnotes",
    "PKColumns": "",
    "TableColumns": "id_number,note_type,lino,vend_no,trans_date,description",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "tsattend",
    "PKColumns": "",
    "TableColumns": "empl_no,pay_code,start_date,end_date,lv_hrs,remarks,check_date,status_flg,lv_code,pay_run,post_flag,sub_id,sub_pay_code,sub_pay_class,sub_hours,sub_pay_rate,sub_amt_paid,sub_loc,sub_tax_ind,sub_orgn,sub_acct,cal_val,ts_id,ts_post_flag,start_time,end_time,empl_class,ts_run",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "tsortaddend",
    "PKColumns": "",
    "TableColumns": "empl_no,seq_no,dedaddend_arr_idx,order_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "tss_emp",
    "PKColumns": "",
    "TableColumns": "empl_no,phone,l_name,f_name,base_location,class1,class2,class3,cal_type,addr1,addr2,city,state_id,zip,race,sex,status,yrs_district,hire_date,birthdate,action,accessed",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "tss_sub",
    "PKColumns": "",
    "TableColumns": "empl_no,phone,l_name,f_name,base_location,class1,class2,class3,cal_type,addr1,addr2,city,state_id,zip,race,sex,action,accessed",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "tssi_class",
    "PKColumns": "",
    "TableColumns": "tssi_class,site_class",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "tssi_loc",
    "PKColumns": "",
    "TableColumns": "tssi_loc,site_loc",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "tx_budtstat",
    "PKColumns": "",
    "TableColumns": "tbl_type,key_orgn,account,ins_flg",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "upload_detail",
    "PKColumns": "",
    "TableColumns": "template_name,column_name,column_number",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "upload_header",
    "PKColumns": "",
    "TableColumns": "template_name,template_type,template_format",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "user_def",
    "PKColumns": "ln_type,indx,page_no",
    "TableColumns": "ln_type,indx,page_no,slabel,type_check,table_name,help_text,default_val,req,valid_if",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "user_passthru",
    "PKColumns": "guid",
    "TableColumns": "guid,empl_no,uid,winuser,timestamp",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "user_profile",
    "PKColumns": "user_id",
    "TableColumns": "user_id,combo_type,impromptu_exe,upfront_exe,webcenter_exe,excel_exe,browser_exe,building,pr_command,use_tab_pur,excel_opt,keyboard_map,mouse_control,notify_type,screen_height,screen_width,document_sort,pref_dashboard",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "user_ref",
    "PKColumns": "prefx,code",
    "TableColumns": "prefx,code,desc_x",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "user_sso_mapping",
    "PKColumns": "id",
    "TableColumns": "id,global_uid,user_id",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "ut_integration_fields",
    "PKColumns": "table_name,field_name",
    "TableColumns": "table_name,field_name",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "uvadminusers",
    "PKColumns": "",
    "TableColumns": "row_id,spiuser",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "uvprofile",
    "PKColumns": "",
    "TableColumns": "wave_id,district_name",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "vac_content",
    "PKColumns": "row_id",
    "TableColumns": "row_id,content_type,content_page,content_text",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "vac_invoice",
    "PKColumns": "row_id",
    "TableColumns": "row_id,vend_no,invoice,invoice_date,amount,due_date,enc_no,inv_status,inv_comment,upload_date,upload_user,change_date,change_user",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "vac_profile",
    "PKColumns": "row_id",
    "TableColumns": "row_id,setting_key,setting_value",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "vac_vendor",
    "PKColumns": "row_id",
    "TableColumns": "row_id,vend_no,trans_type,ven_name,dba_name,fed_id,web_url,w9attach_yn,b_addr1,b_addr2,b_city,b_state,b_zip,b_contact,b_phone,b_fax,po_email,p_addr1,p_addr2,p_city,p_state,p_zip,p_contact,p_phone,p_fax,ap_email,bank_routing,bank_acct_no,bank_trans_code,bank_name,user_name,user_title,login_name,user_phone,user_email,entry_date,entry_time,appr_status,appr_date,appr_uid,appr_comment,ten99_ven_name,ten99_addr1,ten99_addr2,ten99_city,ten99_state,ten99_zip,user_password,user_fax,is_primary_user,ssn_id",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "vbs_prof",
    "PKColumns": "",
    "TableColumns": "award_rec,min_cvt_amt,user_bid,next_bidno,preencum_bid,high_lev,min_bid_amt,alt_awrd,format_commod",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "veh_user",
    "PKColumns": "",
    "TableColumns": "id_no,screen_num,fld01,fld02,fld03,fld04,fld05,fld06,fld07,fld08,fld09,fld10,fld11,fld12,fld13,fld14,fld15,fld16,fld17,fld18,fld19,fld20,fld21,fld22,fld23,fld24,change_date,change_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "vehtb_screen",
    "PKColumns": "",
    "TableColumns": "screen_num,screen_name,required_screen,pei_restricted,change_date,change_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "vehtb_screen_spec",
    "PKColumns": "",
    "TableColumns": "screen_num,fld_num,description,help_text,data_type,data_length,default_val,table_check,allow_nulls,valid_if,change_date,change_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "vem_def",
    "PKColumns": "",
    "TableColumns": "ln_type,indx,page_no,slabel,type_check,table_name,help_text,default_val,req,valid_if",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "vem_prof",
    "PKColumns": "",
    "TableColumns": "client,system,company,auto_ser,next_ser,due_acct,user_1,user_2,user_3,user_4,user_5,ns_exp_acct,ns_clr_orgn,ns_clr_acct",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "vem_ref",
    "PKColumns": "",
    "TableColumns": "prefx,code,desc_x",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "vemhist",
    "PKColumns": "",
    "TableColumns": "ser_no,id_no,trans_date,trans_time,classify,tp,description,amount,item_no,quantity,unit_price,mileage,key_orgn,account,proj,proj_acct,stk",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "veminvtran",
    "PKColumns": "",
    "TableColumns": "locn,stock_no,req_no,req_line_no,vend_no,price,quantity,trans_amt,trans_date,tran_type,key_orgn,account,proj,proj_acct,billed,person,remarks,po_no,po_line_no,operator,fill_id,ship_code,pur_qty,yr,bill_per,lyr_use",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "vemlabor",
    "PKColumns": "",
    "TableColumns": "classify,description,rate,cr_account,dr_account",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "vemlocn",
    "PKColumns": "",
    "TableColumns": "locn,key_orgn",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "vemmaincode",
    "PKColumns": "",
    "TableColumns": "tp,description,day_int,mile_int",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "vemmaindet",
    "PKColumns": "",
    "TableColumns": "tp,line_no,classify,stock_no,quantity",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "vemmaint",
    "PKColumns": "",
    "TableColumns": "id_no,tp,serv_date,mileage",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "vemninvtran",
    "PKColumns": "",
    "TableColumns": "locn,stock_no,req_no,req_line_no,vend_no,cost,price,quantity,trans_amt,trans_date,tran_type,key_orgn,account,proj,proj_acct,billed,misc_desc,operator,yr,bill_per,actual_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "vemsernotes",
    "PKColumns": "",
    "TableColumns": "ser_no,lino,note_txt",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "vemservord",
    "PKColumns": "",
    "TableColumns": "ser_no,srv_time,id_no,dept,trans_date,mileage,locn,complt_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "vemtrans",
    "PKColumns": "",
    "TableColumns": "locn,classify,req_no,req_line_no,cost,quantity,trans_amt,trans_date,tran_type,key_orgn,account,proj,proj_acct,billed,person,remarks,operator,ship_code,yr,actual_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "vemuser",
    "PKColumns": "",
    "TableColumns": "id_no,page_no,ftext1,ftext2,ftext3,ftext4,ftext5,ftext6,ftext7,ftext8,ftext9,ftext10,tcode1,tcode2,tcode3,tcode4,tcode5,tcode6,tcode7,tcode8,tcode9,tcode10,comment1,comment2",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "vemvehicle",
    "PKColumns": "",
    "TableColumns": "id_no,description,dept_no,proj,serial_no,date_purchased,price,mileage,srv_time,asset_flg,asset_id,imp_num,next_date,next_desc,user1,user2,user3,user4,user5",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "venact",
    "PKColumns": "",
    "TableColumns": "vend_no,date_chg,time_chg,field_no,field_name,old_value,new_value,operator,op_type",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "venbid_alt",
    "PKColumns": "",
    "TableColumns": "bid_no,vend_no,commodity,seq_no,measure,quanity,unit_price,alt_commod,description,comments1,comments2,comments3,comments4,comments5,awarded,consider,yr",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "venbid_det",
    "PKColumns": "",
    "TableColumns": "bid_no,vend_no,commodity,measure,quanity,unit_price,comments1,comments2,comments3,comments4,comments5,awarded,alt_item,yr",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "venbid_hdr",
    "PKColumns": "",
    "TableColumns": "bid_no,vend_no,yr",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "venchk_proc_tbl",
    "PKColumns": "",
    "TableColumns": "trans_no,gl_key_orgn,fund,disb_gl_key_orgn,disb_fund,gl_cash_key_orgn,gl_cash,key_orgn,account,check_no,ck_date,enc_no,amount,vend_no,alt_vend_no,ven_name,alpha_name,b_addr_1,b_addr_2,b_city,b_state,b_zip,invoice,description,disc_dt_or,c_1099,is_eft,int_check_no,bank_trans_code,bank_code,bank_acct_no,email_me,email_addr,pcd_flag,pcd_merch_no,pcd_merch_name,disc_amt,disc_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "venclass",
    "PKColumns": "",
    "TableColumns": "vend_no,comm_cls",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "vendaddr",
    "PKColumns": "",
    "TableColumns": "vend_no,vend_seq,s_addr_1,s_addr_2,s_city,s_state,s_zip,contact,cont_phone,comm_desc,fax_no,po_print",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "vendaddr_misc",
    "PKColumns": "",
    "TableColumns": "vend_no,email",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "vendnote",
    "PKColumns": "",
    "TableColumns": "vend_no,seq,note",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "vendor",
    "PKColumns": "vend_no",
    "TableColumns": "vend_no,ven_name,alpha_name,b_addr_1,b_addr_2,b_city,b_state,b_zip,b_contact,b_phone,b_fax,p_addr_1,p_addr_2,p_city,p_state,p_zip,p_contact,p_phone,p_fax,fed_id,date_last,paid_ytd,ytd_misc,ordered_ytd,prev_ytd,prev_misc,prev_bal,comm1,comm2,comm3,comm4,comm5,comm6,comm7,comm8,comm9,comm10,comm11,form_1099,disc_ind,discount,disc_days,net_days,stax_rate,utax_rate,empl_vend,empl_no,type_misc,hold_flg,min_check_amt,type_g,ytd_g,prev_g,type_int,ytd_int,prev_int,bid_only,tax_code,dba_name,web_url,inactive_flg,ten99_ven_name,ten99_addr_1,ten99_addr_2,ten99_city,ten99_state,ten99_zip",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "viewid",
    "PKColumns": "",
    "TableColumns": "view_id",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "vnd_def",
    "PKColumns": "",
    "TableColumns": "ln_type,indx,page_no,slabel,type_check,table_name,help_text,default_val,req,valid_if",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "vnd_misc",
    "PKColumns": "",
    "TableColumns": "vend_no,bank_trans_code,bank_code,bank_acct_no,bank_routing,ap_email,po_email,eft_flag,link_vend_no,vend_acct,po_flag,use_hrm_bank",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "vnd_ssn",
    "PKColumns": "vend_no",
    "TableColumns": "vend_no,ssn,same_flag",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "vndasoundex",
    "PKColumns": "",
    "TableColumns": "soundcode,vend_no,alpha_name",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "vndnsoundex",
    "PKColumns": "",
    "TableColumns": "soundcode,vend_no,ven_name",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "vnduser",
    "PKColumns": "",
    "TableColumns": "vend_no,page_no,ftext1,ftext2,ftext3,ftext4,ftext5,ftext6,ftext7,ftext8,ftext9,ftext10,tcode1,tcode2,tcode3,tcode4,tcode5,tcode6,tcode7,tcode8,tcode9,tcode10,comment1,comment2",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "vpayhist",
    "PKColumns": "",
    "TableColumns": "enc_no,trans_no,yr",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "w2box12",
    "PKColumns": "",
    "TableColumns": "label,dbp_code,code1,code2,code3,code4,code5,code6,code7,code8,code9,code10,code11,code12,code13,code14,code15,code16,code17,code18,code19,code20,code21,code22,code23,code24,code25,code26,code27,code28,code29,code30,code31,code32,code33,code34,code35,code36,code37,code38,code39,code40",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "w2box13",
    "PKColumns": "",
    "TableColumns": "label,dbp_code,code1,code2,code3,code4,code5,code6,code7,code8,code9,code10",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "w2box14",
    "PKColumns": "",
    "TableColumns": "label,dbp_code,code1,code2,code3,code4,code5,code6,code7,code8,code9,code10,code11,code12,code13,code14,code15,code16,code17,code18,code19,code20,code21,code22,code23,code24,code25,code26,code27,code28,code29,code30,code31,code32,code33,code34,code35,code36,code37,code38,code39,code40",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "w2cemp",
    "PKColumns": "",
    "TableColumns": "orig_correction,row_id,orig_row_id,taxyr,batch_no,empl_no,empl_type,seq_no,ssn,fname,lname,street,street2,city,state_id,zip,zipext,ind_statute,ind_deceased,ind_pension,ind_legal,ind_defcomp,ind_void,ind_3psick,alloctips,eic,fedtax,fedwages,ficatax,ficawage,soctips,medwage,medtax,b17a,amt_b17a,b17b,amt_b17b,b17c,amt_b17c,b17d,amt_b17d,b18a,amt_b18a,b18b,amt_b18b,b18c,amt_b18c,depcare,fringe,amt_457,amt_not457,statetax,statewage,statename,stat2tax,stat2wage,stat2name,localtax,localwage,localname,loca2name,loca2tax,loca2wage,chk_locn,f_state,f_postal,country,b18d,amt_b18d,b18e,amt_b18e,m_name,name_suffix,ind_corrected,ind_ssn_name_change",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "w2cemployee",
    "PKColumns": "",
    "TableColumns": "empl_no,empl_type,seq_no,chk_locn,yr_corrected,form_corrected,empl_ssn,emplr_use,emplr_ssa_num,emplr_fed_ein,emplr_state_id,empl_ssn_bad,empl_name_bad,empl_corrected,empl_name,empl_addr,empl_addr2,empl_addr3,emplr_corrected,emplr_name,emplr_addr,emplr_addr2,emplr_addr3,ind_void,ind_p_statute,ind_p_deceased,ind_p_pension,ind_p_legal,ind_p_defcomp,ind_p_ira_sep,ind_c_statute,ind_c_deceased,ind_c_pension,ind_c_legal,ind_c_defcomp,ind_c_ira_sep,label_16a,label_16b,label_16c,p_fedtax,p_fedwages,p_sstax,p_sswages,p_sstips,p_medwages,p_medtax,p_16a,p_16b,p_16c,p_alloctips,p_statetax,p_statewages,p_localtax,p_localwages,c_fedtax,c_fedwages,c_sstax,c_sswages,c_sstips,c_medwages,c_medtax,c_16a,c_16b,c_16c,c_alloctips,c_statetax,c_statewages,c_localtax,c_localwages",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "w2employee",
    "PKColumns": "taxyr,batch_no,empl_no,seq_no",
    "TableColumns": "taxyr,batch_no,empl_no,empl_type,seq_no,ssn,fname,lname,street,street2,city,state_id,zip,zipext,ind_statute,ind_deceased,ind_pension,ind_legal,ind_defcomp,ind_void,ind_3psick,alloctips,eic,fedtax,fedwages,ficatax,ficawage,soctips,medwage,medtax,b17a,amt_b17a,b17b,amt_b17b,b17c,amt_b17c,b17d,amt_b17d,b18a,amt_b18a,b18b,amt_b18b,b18c,amt_b18c,depcare,fringe,amt_457,amt_not457,statetax,statewage,statename,stat2tax,stat2wage,stat2name,localtax,localwage,localname,loca2name,loca2tax,loca2wage,chk_locn,f_state,f_postal,country,b18d,amt_b18d,b18e,amt_b18e,m_name,name_suffix,ind_corrected",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "w2labels",
    "PKColumns": "",
    "TableColumns": "code,desc_x,code1",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "w2load",
    "PKColumns": "",
    "TableColumns": "taxyr,batch_no,paygrp01,paygrp02,paygrp03,paygrp04,paygrp05,paygrp06,paygrp07,paygrp08,paygrp09,paygrp10,paygrp11,paygrp12,paygrp13,paygrp14,paygrp15,paygrp16,paygrp17,paygrp18,paygrp19,paygrp20,paygrp21,paygrp22,paygrp23,paygrp24,depflg,dp01,dp02,dp03,dp04,dp05,dp06,dp07,dp08,dp09,dp10,pp01,pp02,pp03,pp04,pp05,pp06,pp07,pp08,pp09,pp10,pp11,pp12,pp13,pp14,pp15,pp16,pp17,pp18,pp19,pp20,pp21,pp22,pp23,pp24,pp25,pp26,pp27,pp28,pp29,pp30,ytdflg",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "w2loctx",
    "PKColumns": "",
    "TableColumns": "loclbl,loccod1",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "w4lockin",
    "PKColumns": "empl_no",
    "TableColumns": "empl_no,active,letter_date,lifted_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wartran",
    "PKColumns": "",
    "TableColumns": "yr,jeno,key_orgn,account,project,proj_acct,trans_date,description,amount",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wbassign_chg",
    "PKColumns": "",
    "TableColumns": "empl_no,change_type,orig_class,orig_position,new_class,new_position,entered_by,entered_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wbassign_num",
    "PKColumns": "",
    "TableColumns": "iname,nxt_num",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wbentrydtl",
    "PKColumns": "",
    "TableColumns": "entry_type,field_indx,slabel,field_acct,type_check,help_text,default_val,req,valid_if",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wbentryhdr",
    "PKColumns": "",
    "TableColumns": "entry_type,description,account",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wbposappr",
    "PKColumns": "",
    "TableColumns": "yr,req_num,lvl,approver,appr_date,appr_status,appr_fte,appr_fill_date,appr_salary",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wbposition",
    "PKColumns": "",
    "TableColumns": "yr,classify,pos,new_flag,orig_vacant_fte,request_fte",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wbposreq",
    "PKColumns": "",
    "TableColumns": "yr,req_num,req_status,req_orgn,entry_type,classify,pos,requested_by,fill_date,locn,request_rank,fte,entered_by,entered_date,updated_by,updated_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wbud_only",
    "PKColumns": "",
    "TableColumns": "yr,key_orgn,account",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wbud_prof",
    "PKColumns": "",
    "TableColumns": "rev_offset_acct,rev_offset_perc,auto_approve,require_notes",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wbudreqappr",
    "PKColumns": "",
    "TableColumns": "yr,req_num,req_seq,lvl,approver,appr_date,appr_status,appr_qty,appr_cost,appr_total",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wbudreqnote",
    "PKColumns": "",
    "TableColumns": "yr,req_num,req_seq,note_type,note",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wbudrequest",
    "PKColumns": "",
    "TableColumns": "yr,req_num,req_seq,req_status,req_orgn,key_orgn,account,project,proj_acct,entry_type,description,requested_by,quantity,unit_cost,total_cost,proposed_date,request_rank,pos_req_num,entered_by,entered_date,updated_by,updated_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wbuduser",
    "PKColumns": "",
    "TableColumns": "yr,req_num,req_seq,field_indx,field_txt",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wbudvacnote",
    "PKColumns": "",
    "TableColumns": "yr,req_num,note_type,note",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wea_prof",
    "PKColumns": "",
    "TableColumns": "company_name,logo,eeo_req,eeo_statement,crimecheckreq,crimecheck,crimedl_flg,crimebd_flg,admin_email,login_comment,edu_comment,exp_comment,ref_comment,cert_comment",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wea_supplement",
    "PKColumns": "",
    "TableColumns": "company_name,use_flag,question1,question2,question3,question4,question5,question6,question7,question8,question9,question10,question11,question12,job_no",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "web_admin",
    "PKColumns": "",
    "TableColumns": "empl_no,prod_name,descript,val",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "web_admin_options",
    "PKColumns": "",
    "TableColumns": "prod_name,descript,long_descript,opt_type,category",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "web_disclaim",
    "PKColumns": "",
    "TableColumns": "prod_name,id,descript,disclaim,long_descript",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "web_link",
    "PKColumns": "row_id",
    "TableColumns": "prod_name,row_id,sort_order,link_url,link_description,update_who,update_when",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "web_news",
    "PKColumns": "row_id",
    "TableColumns": "prod_name,row_id,headline,news_text,effective_date,expiration_date,update_who,update_when",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "web_num",
    "PKColumns": "",
    "TableColumns": "name,next_num",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "web_prof_cat",
    "PKColumns": "category",
    "TableColumns": "category,descript",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "web_prof_type",
    "PKColumns": "row_id",
    "TableColumns": "prod_name,row_id,prof_type,title,item_type,input_format,is_required,validation,selected_val,deselected_val,descript",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "web_profile",
    "PKColumns": "",
    "TableColumns": "prod_name,id,descript,val,long_descript,prof_type,category",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "web_sec_quest",
    "PKColumns": "question_id",
    "TableColumns": "question_id,question_text",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "web_sec_resp",
    "PKColumns": "empl_no,question_id",
    "TableColumns": "empl_no,question_id,question_response",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "weekend_work",
    "PKColumns": "cal_type,w_date",
    "TableColumns": "cal_type,w_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wet_anomalies",
    "PKColumns": "empl_no,dept_code,pay_period,anom_code",
    "TableColumns": "empl_no,dept_code,pay_period,anom_code",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wet_app_time",
    "PKColumns": "empl_no,dept_code,pay_period,app_level",
    "TableColumns": "empl_no,dept_code,pay_period,app_level,sup_empl_no,pay_run,date_posted",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wet_clock_time",
    "PKColumns": "empl_no,dept_code,pay_period,clock_date,clock_flag,date_stamp,time_stamp,dist_key,chg_empl_no,time_key",
    "TableColumns": "empl_no,dept_code,pay_period,clock_date,clock_time,clock_flag,date_stamp,time_stamp,dist_key,pay_code,chg_empl_no,time_key,classify,notes",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wet_clock_time_renamed",
    "PKColumns": "empl_no,dept_code,pay_period,clock_date,clock_flag,date_stamp,time_stamp,dist_key,chg_empl_no,time_key",
    "TableColumns": "empl_no,dept_code,pay_period,clock_date,clock_time,clock_flag,date_stamp,time_stamp,dist_key,pay_code,chg_empl_no,time_key,notes,classify",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wet_comp_time",
    "PKColumns": "empl_no",
    "TableColumns": "empl_no,comp_earned,comp_taken",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wet_compot_dist",
    "PKColumns": "empl_no,dept_code,pay_period",
    "TableColumns": "empl_no,dept_code,pay_period,ot_hours,comp_hours,carryover_hours",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wet_correct",
    "PKColumns": "empl_no,dept_code,pay_period,hours,new_old_record",
    "TableColumns": "empl_no,dept_code,pay_period,pay_code,hours,key_orgn,account,project,proj_acct,chg_user,new_old_record",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wet_dept",
    "PKColumns": "dept_code",
    "TableColumns": "dept_code,dept_desc,dept_link,use_overrides,entry_type_flag,ot_flag,ot_hours_start,default_ot_code,let_super_submit,number_of_dists,allow_clock_chg,allow_entry_chg",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wet_detail",
    "PKColumns": "row_id",
    "TableColumns": "empl_no,dept_code,pay_period,pay_code,pay_period_day,hours,dist_key,date_stamp,time_stamp,chg_empl_no,classify,row_id,leave_request_id,dataset_instance_id",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wet_dist_key",
    "PKColumns": "empl_no,dist_key,pay_period",
    "TableColumns": "empl_no,dist_key,key_orgn,account,project,proj_acct,pay_period,dist_percent",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wet_empl_dept",
    "PKColumns": "empl_no,dept_code,primary_dept",
    "TableColumns": "empl_no,dept_code,primary_dept",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wet_employee",
    "PKColumns": "empl_no",
    "TableColumns": "empl_no,super_flag,block_flag",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wet_input_days",
    "PKColumns": "empl_no,dept_code,pay_period,pay_code,pay_period_day,classify",
    "TableColumns": "empl_no,dept_code,pay_period,pay_code,pay_period_day,date_stamp,time_stamp,chg_empl_no,classify",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wet_notes",
    "PKColumns": "empl_no,dept_code,pay_period",
    "TableColumns": "empl_no,dept_code,pay_period,entered_notes",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wet_notify",
    "PKColumns": "empl_no,pay_period",
    "TableColumns": "empl_no,pay_period",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wet_pay_link",
    "PKColumns": "pay_code,dept_code",
    "TableColumns": "pay_code,dept_code",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wet_pay_setup",
    "PKColumns": "pay_period",
    "TableColumns": "pay_period,dept_code,start_date,start_time,end_date,end_time,pay_per_hours",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wet_paytable",
    "PKColumns": "pay_code",
    "TableColumns": "pay_code,wet_comp_pay_code,wet_use_for_calc,wet_description",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wet_profile",
    "PKColumns": "",
    "TableColumns": "entry_type_flag,hourly_rate_flag,dock_rate_flag,hours_per_day_flag,hours_per_pay_flag,bargain_unit_flag,pay_title_desc,app_type,allow_app_changes,allow_clock_chg,allow_comp_time,allow_hist_chgs,allow_2nd_chk,unapp_flag,show_charge_flag,show_paycd_flag,show_leave_flag,show_activities,ot_flag,ot_hours_start,default_ot_code,hours_exceed_wrn,hours_short_wrn,wet_lock,admin_email,min_pass_len,max_pass_len,number_of_dists,std_template,site_bgcolor,site_txtcolor,site_logo,header_type,banner_url,dept_title,submit_title,submit_disclaim,leave_disclaim,ot_dist_disclaim,lock_disclaim,orgn_limit,orgn_start,orgn_end,combine_rates,orgn_chars,orgn_index,proj_chars,proj_index",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wet_schdept",
    "PKColumns": "",
    "TableColumns": "sch_code,dept_code,include_linked",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wet_schedule",
    "PKColumns": "sch_code",
    "TableColumns": "sch_code,sch_desc,sch_default,mon_y_n,tue_y_n,wed_y_n,thu_y_n,fri_y_n,sat_y_n,sun_y_n",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wet_super",
    "PKColumns": "empl_no,dept_code",
    "TableColumns": "empl_no,dept_code,app_level,app_linked_depts",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wet_unapp_codes",
    "PKColumns": "reason_code",
    "TableColumns": "reason_code,reason_desc",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wet_unapprove",
    "PKColumns": "empl_no,dept_code,pay_period",
    "TableColumns": "empl_no,dept_code,pay_period,unapp_date,sup_empl_no,reason_code,reason_desc",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wf_app_task",
    "PKColumns": "wf_app_task_id",
    "TableColumns": "wf_app_task_id,dataset_id,task_name,fk_val1,fk_val2,fk_val3,fk_val4,change_uid,change_date_time",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wf_app_task_approvers",
    "PKColumns": "wf_app_task_id,role_id",
    "TableColumns": "wf_app_task_id,role_id",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wf_application",
    "PKColumns": "id",
    "TableColumns": "id,name,dataset_id,status",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wf_auditTrails",
    "PKColumns": "row_id",
    "TableColumns": "row_id,wf_type,fk_val1,fk_val2,fk_val3,fk_val4,column_name,field_name,old_value,new_value,updated_date,updated_by",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wf_dataset",
    "PKColumns": "dataset_id",
    "TableColumns": "dataset_id,title,search_type,key_table,key_fields,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wf_delegates",
    "PKColumns": "actor_id,role_id,start_date,delegate_actor_id",
    "TableColumns": "actor_id,role_id,start_date,end_date,delegate_actor_id,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wf_emails",
    "PKColumns": "row_id",
    "TableColumns": "guid,type,firstName,lastName,employeeNo,key_value1,key_value2,key_value3,key_value4,key_value5,key_value6,key_value7,key_value8,key_value9,app_group,amount,dest,url,act,notified,created_on,row_id,description",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wf_groups",
    "PKColumns": "group_id",
    "TableColumns": "group_id,title,description,dataset_id,change_date_time,change_uid,grouping_mask,status",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wf_instance",
    "PKColumns": "instance_id",
    "TableColumns": "instance_id,model_id,model_version,launch_type,launch_object,reminder_date_time,processing_host,dataset_instance_id,requestor_id,create_date_time,completed_date_time,status,description,expiration_date_time,database_name,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wf_instance_email_notify",
    "PKColumns": "notify_id",
    "TableColumns": "notify_id,instance_id,node_id,actor_id,is_delegate,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wf_instance_event",
    "PKColumns": "event_id",
    "TableColumns": "event_id,instance_id,node_id,type,status,start_date_time,completed_date_time,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wf_instance_event_detail",
    "PKColumns": "detail_id",
    "TableColumns": "detail_id,event_id,status,group_id,role_id,actor_id,delegate_actor_id,start_date_time,completed_date_time,comments,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wf_instance_event_notify",
    "PKColumns": "event_notify_id",
    "TableColumns": "event_notify_id,instance_id,node_id,event_id,role_id,actor_id,action,status,processing_host,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wf_launch_types",
    "PKColumns": "launch_type",
    "TableColumns": "launch_type,title,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wf_model",
    "PKColumns": "model_id,model_version",
    "TableColumns": "model_id,model_version,status,title,description,launch_type,dataset_id,allow_cancel,notify_cancel,cancel_template,notify_final_approval,final_approval_template,notify_needs_correction,needs_correction_template,needs_correction_interval,needs_correction_units,expiration_days,xaml,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wf_model_node",
    "PKColumns": "node_id",
    "TableColumns": "model_id,model_version,node_id,title,type,required,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wf_model_node_detail",
    "PKColumns": "node_id,key_id,value_id",
    "TableColumns": "node_id,key_id,value_id,value,next_key_id,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wf_model_node_role_groups",
    "PKColumns": "node_id,role_id,group_id",
    "TableColumns": "node_id,role_id,group_id,row_num,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wf_model_node_transition",
    "PKColumns": "transition_id",
    "TableColumns": "node_id,transition_id,order_num,title,condition,next_node_id,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wf_queue",
    "PKColumns": "queue_id",
    "TableColumns": "queue_id,launch_type,launch_object,dataset_instance_id,requestor_id,status,processing_host,database_name,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wf_role_members",
    "PKColumns": "role_id,actor_id",
    "TableColumns": "role_id,actor_id,primary_alternate,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wf_roles",
    "PKColumns": "role_id",
    "TableColumns": "role_id,title,status,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wf_stage_emails",
    "PKColumns": "row_id",
    "TableColumns": "row_id,type,empl_no,key_value1,key_value2,key_value3,key_value4,key_value5,key_value6,key_value7,key_value8,key_value9,key_value10,description,amount,app_group,app_type,app_action,url,notified,send_date,reminder_send_date",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wf_task",
    "PKColumns": "id",
    "TableColumns": "id,name,appid,status,default_groupid,approval_required,udf_required",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wf_task_queue",
    "PKColumns": "id",
    "TableColumns": "id,wf_type,request_id,requester_id,status,message,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wf_task_rule_group",
    "PKColumns": "row_num",
    "TableColumns": "row_num,task_id,group_id,rule_id,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wf_udf_emp_mapping",
    "PKColumns": "emplno,ln_type,indx,page_no",
    "TableColumns": "emplno,ln_type,indx,page_no,completion_date,status,update_date,updated_by",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wf_udf_task_mapping",
    "PKColumns": "taskid,ln_type,indx,page_no",
    "TableColumns": "taskid,ln_type,indx,page_no,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wf_user_defined",
    "PKColumns": "dataset_instance_id,screen_number,list_sequence,field_number",
    "TableColumns": "dataset_instance_id,screen_number,list_sequence,field_number,field_value,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wf_user_defined_hdr",
    "PKColumns": "dataset_instance_id",
    "TableColumns": "dataset_instance_id,dataset_id,key_fields,screen_number,status,validation_flag,create_date_time,change_date_time,change_uid",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "with_rate_sched",
    "PKColumns": "code",
    "TableColumns": "code,description,active",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wkrdept",
    "PKColumns": "",
    "TableColumns": "work_cd,orgn,reg_sal,ot_sal",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wkrtable",
    "PKColumns": "",
    "TableColumns": "work_cd,title,rate,reg_sal,ot_sal,with_acct,fringe_acct,encumber",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "work_activities",
    "PKColumns": "row_id",
    "TableColumns": "date_time,source_email,act_subject,act_status,act_notes,dest_uid,act_url,source_uid,activity_xml,row_id,wkf_instance_id,dest_email,workflow_id,delegate_item",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "work_activity_hist",
    "PKColumns": "",
    "TableColumns": "date_time,source_email,act_subject,act_status,act_notes,dest_uid,act_url,source_uid,activity_xml,row_id,wkf_instance_id,dest_email,workflow_id,delegate_item",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "work_app_request",
    "PKColumns": "",
    "TableColumns": "datetime_stamp,uid,empl_no,start_date,end_date,lv_code,lv_status,lv_units,lv_units_desc",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "work_notifications",
    "PKColumns": "row_id",
    "TableColumns": "date_time,source_email,act_subject,act_status,act_notes,dest_uid,act_url,source_uid,activity_xml,row_id,wkf_instance_id,dest_email,workflow_id,delegate_item",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "work_notify_hist",
    "PKColumns": "",
    "TableColumns": "date_time,source_email,act_subject,act_status,act_notes,dest_uid,act_url,source_uid,activity_xml,row_id,wkf_instance_id,dest_email,workflow_id,delegate_item",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "workactor",
    "PKColumns": "",
    "TableColumns": "row_id,empl_no,super_empl_no,organ_level,alt_super_no,approval_level,role_id,notify_type,uid,email",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "workflow_codes",
    "PKColumns": "workflow_type_id",
    "TableColumns": "workflow_type_id,workflow_name,package",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "workflow_config",
    "PKColumns": "row_id",
    "TableColumns": "row_id,spisystem,workflow_service,subgroup,setting_key,setting_value,field_type,field_values,field_length,field_label,field_tooltip",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "workflow_correct",
    "PKColumns": "",
    "TableColumns": "row_id,guid,workflow_type,fk_table,fk_col1,fk_val1,fk_col2,fk_val2,fk_col3,fk_val3,fk_col4,fk_val4",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "workflow_guids",
    "PKColumns": "row_id",
    "TableColumns": "row_id,guid,workflow_type,fk_table,fk_col1,fk_val1,fk_col2,fk_val2,fk_col3,fk_val3,fk_col4,fk_val4",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "workflow_log",
    "PKColumns": "row_id",
    "TableColumns": "row_id,datetime_stamp,guid,workflow_type,event_type,workflow_event,parameters,info_string",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "workflow_profile",
    "PKColumns": "id",
    "TableColumns": "id,var_name,var_value,create_date,update_date,created_by,updated_by",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wrk1099g",
    "PKColumns": "",
    "TableColumns": "tax_yr,vend_no,alt_vend_no,fed_id,ven_name,address1,address2,city,state_id,zip,acct_num,box1,box2,box3,box4,box5,box6,box7,box8,box9,box10a,box10b,box11,dba_name,tin_notice2",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wrk1099i",
    "PKColumns": "",
    "TableColumns": "tax_yr,vend_no,alt_vend_no,fed_id,ven_name,address1,address2,city,state_id,zip,acct_num,tin_notice2,box1,box2,box3,box4,box5n,box5,box6,box8,box9,box10,box11,box12,box13,dba_name",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wrk1099m",
    "PKColumns": "",
    "TableColumns": "tax_yr,vend_no,fed_id,alt_vend_no,ven_name,address1,address2,city,state_id,zip,acct_num,tin_notice2,box1,box2,box3,box4,box5,box6,box7,box8,box9,box10,box11,box12,box13,box14,box15,box16,box17,box18,box15a,box15b,forgn_sw,f_state,f_postal,country,dba_name",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wrk1099n",
    "PKColumns": "",
    "TableColumns": "tax_yr,vend_no,fed_id,alt_vend_no,ven_name,address1,address2,city,state_id,zip,acct_num,tin_notice2,box1,box2,box4,box5,box6,box7,forgn_sw,f_state,f_postal,country,dba_name,alt_ven_name",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wrk1099r",
    "PKColumns": "",
    "TableColumns": "taxyr,empl_no,group_x,home_orgn,ssn,l_name,f_name,addr1,addr2,city,state_id,zip,zipext,acct_num,box1,box2a,box2b1,box2b2,box3,box4,box5,box6,box7,box7a,box8,box8_per,box9,box9b,tstate,box10,box12,box13,state_dist,loc_dist,m_name,name_suffix,paydate",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wrkdeduct",
    "PKColumns": "",
    "TableColumns": "taxyr,empl_no,ded_cd,taken_y,cont_y,sal_y",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wrkemployee",
    "PKColumns": "",
    "TableColumns": "taxyr,empl_no,group_x,fic_ext1,fic_ext2,ssn,l_name,f_name,addr1,addr2,mail_city,mail_state,zip,zipext,home_orgn,term_code,state_id,pr_state,locl,pr_local,tearn_y,ftearn_y,fiearn_y,stearn_y,s2earn_y,loearn_y,l2earn_y,allow_y,nocash_y,fedtax_y,fictax_y,statax_y,st2tax_y,loctax_y,lt2tax_y,eic_y,ficaern1,ficatax1,medearn1,medatax1,ficaern2,ficatax2,medearn2,medatax2,chk_locn,fed_marital,fed_dep,add_fed,sta_marital,sta_dep,add_state,loc_marital,loc_dep,add_local,m_name,name_suffix",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wrkemployer",
    "PKColumns": "",
    "TableColumns": "taxyr,batch_no,eid,stid,ename,street,city,state_id,zip,zipext,state2,stid2,state3,stid3,state4,stid4,state5,stid5,street2",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wrkfica",
    "PKColumns": "",
    "TableColumns": "taxyr,fic_med,emp_per,emp_max,empr_per,empr_max",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wrkmain",
    "PKColumns": "",
    "TableColumns": "taxyr,ename,addr1,addr2,city,state_id,zip,zipext,phone,eid,stid,flg_name,flg_ein,flg_sid,flg_control,flg_form,term_code,comp_name,flg_media,density,notify,pnc_1099,transco_1099,fs_file_1099,prt_detail_1099,prt_empdept_1099,contact,pid,faxno,email",
    "TableHasChangeDT": ""
  },
  {
    "db": "eFin",
    "name": "wrkpaycode",
    "PKColumns": "",
    "TableColumns": "taxyr,empl_no,pay_code,sal_y",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "_tblStateCourses",
    "PKColumns": "",
    "TableColumns": "code,descr,core",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "API_AUTH_LOG",
    "PKColumns": "AUTH_LOG_ID",
    "TableColumns": "AUTH_LOG_ID,CALLER_ID,NONCE,AUTH_SUCCESS,CHANGE_DATE_TIME",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "API_CALLER_CFG",
    "PKColumns": "CALLER_ID",
    "TableColumns": "CALLER_ID,DISTRICT,SUMMER_SCHOOL,CALLER_NAME,AUTH_TOKEN,LOG_LEVEL,MIN_DELTA_CALC_MINUTES,INCLUDE_OUT_OF_DISTRICT_BLDGS,INCLUDE_PREREG_STUDENTS,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID,SIGNATURE_METHOD,AUTHENTICATION_METHOD,USE_DELTA_FILTER",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "API_CALLER_CFG_OPTIONS",
    "PKColumns": "CALLER_ID,OPTION_NAME",
    "TableColumns": "CALLER_ID,OPTION_NAME,OPTION_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "API_CALLER_SECURE_DET",
    "PKColumns": "CALLER_ID,RULE_ID,JSON_LABEL",
    "TableColumns": "CALLER_ID,RULE_ID,JSON_LABEL,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "API_CALLER_SUBSCRIBE",
    "PKColumns": "CALLER_ID,RULE_ID,SCOPE",
    "TableColumns": "CALLER_ID,RULE_ID,ADDITIONAL_SQL_JOINS,ADDITIONAL_SQL_WHERE,LAST_SINCE_DATETIME,DELTA_MINUTES,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID,SCOPE",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "API_DELTA_CACHE",
    "PKColumns": "DELTA_ID",
    "TableColumns": "DELTA_ID,RULE_ID,CALLER_ID,ROW_CHECKSUM,ROW_UNIQUE_ID,RECORD_STATUS,CHANGE_DATE_TIME",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "API_DISTRICT_DEFINED",
    "PKColumns": "DISTRICT,CALLER_ID,RULE_ID,SCREEN_TYPE,SCREEN_NUMBER,FIELD_NUMBER",
    "TableColumns": "DISTRICT,CALLER_ID,RULE_ID,SCREEN_TYPE,SCREEN_NUMBER,FIELD_NUMBER,DISPLAY_ORDER,JSON_LABEL,FORMAT_TYPE,FORMAT_MASK,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "API_GUID_GB_ASMT",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,ASMT_NUMBER",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,ASMT_NUMBER,API_REFID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "API_GUID_GB_SCORE",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,ASMT_NUMBER,STUDENT_ID",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,ASMT_NUMBER,STUDENT_ID,API_REFID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "API_LOG",
    "PKColumns": "LOG_GUID",
    "TableColumns": "LOG_GUID,CALLER_ID,RULE_ID,MESSAGE_ACTION,MESSAGE_STATUS,REQUEST_QUERYSTRING,MESSAGE_DATA,MESSAGE_HEADER,ERROR_MESSAGE,ADDITIONAL_INFO,TOTAL_RECORDS,RECORDS_THIS_PAGE,FILTER_LIMIT,FILTER_OFFSET,CHANGE_DATE_TIME",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "API_PROGRAMS",
    "PKColumns": "DISTRICT,CALLER_ID,PROGRAM_ID,HTTP_METHOD",
    "TableColumns": "DISTRICT,CALLER_ID,PROGRAM_ID,HTTP_METHOD,DO_NOT_TRACK_BEFORE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "API_RULE_DET",
    "PKColumns": "RULE_ID,JSON_LABEL",
    "TableColumns": "RULE_ID,JSON_LABEL,DESCRIPTION,DATA_ORDER,DB_COLUMN,IS_KEY,SUBQUERY_RULE_ID,FORMAT_TYPE,FORMAT_MASK,LITERAL_VALUE,IS_SECURED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "API_RULE_HDR",
    "PKColumns": "RULE_ID,USE_SUMMER_SCHOOL",
    "TableColumns": "RULE_ID,DISTRICT,API_VERSION,USE_SUMMER_SCHOOL,RULE_CONTROLLER,RULE_NAME,DESCRIPTION,SQL_VIEW,SQL_ORDER_BY,IS_SUBQUERY,USER_SCREEN_TYPE,SUNGARD_RESERVED,ACTIVE,ACCESS_TYPE,HTTP_METHOD,CUSTOM_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "API_RULE_SUBQUERY_JOIN",
    "PKColumns": "PARENT_RULE_ID,PARENT_JSON_LABEL,SUBQUERY_RULE_ID,LINK_SUBQUERY_DB_COLUMN",
    "TableColumns": "PARENT_RULE_ID,PARENT_JSON_LABEL,SUBQUERY_RULE_ID,LINK_SUBQUERY_DB_COLUMN,LINK_PARENT_JSON_LABEL",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "AR_CLASS_DOWN",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,FISCAL_YEAR,CYCLE,SCHOOL_LEA,COURSE_NUM,COURSE_SECT,STAFF_SSN",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,FISCAL_YEAR,CYCLE,SCHOOL_LEA,COURSE_NUM,COURSE_SECT,COURSE_DESC,COURSE_CREDIT,DIST_LEARN,SPEC_ED,COLL_CREDIT,INSTITUTION,STAFF_SSN,STAFF_STATE_ID,HIGH_QUAL,ALT_ENVN,COURSE_MIN,KG_OVERFLG,LEA_OUT_DIST,MARK_PERIOD,DIST_LEARN_PROV,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "AR_DOWN_ALE_DAYS",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,FISCAL_YEAR,CYCLE,SCHOOL_LEA,STUDENT_ID,START_DATE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,FISCAL_YEAR,CYCLE,SCHOOL_LEA,SSN,STUDENT_ID,STUDENT_STATE_ID,START_DATE,QUARTER1_ALE,QUARTER2_ALE,QUARTER3_ALE,QUARTER4_ALE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "AR_DOWN_ATTEND",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,FY,CYCLE,LEA,STUDENT_ID,START_DATE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,FY,CYCLE,LEA,SSN,STUDENT_ID,STUDENT_STATE_ID,TRAVEL_CODE,TRANS_STATUS,MIN_TO_MAJ,MAGNET,START_DATE,DAYS_PRS_QTR1,DAYS_ABS_QTR1,DAYS_PRS_QTR2,DAYS_ABS_QTR2,DAYS_PRS_QTR3,DAYS_ABS_QTR3,DAYS_PRS_QTR4,DAYS_ABS_QTR4,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "AR_DOWN_CAL",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,FISCAL_YEAR,CYCLE,LEA,CAL_DATE,QUARTER,SEMESTER",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,FISCAL_YEAR,CYCLE,LEA,CAL_DATE,MEMBERSHIP_DAY,CALENDAR_NUMBER,MEMBERSHIP_NUMBER,QUARTER,SEMESTER,DAY_TYPE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "AR_DOWN_DISCIPLINE",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,FISCAL_YEAR,CYCLE,LEA,STUDENT_ID,INCIDENT_ID,INFRACTION,ACTION_TAKEN",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,FISCAL_YEAR,CYCLE,LEA,STUDENT_ID,SSN,STUDENT_STATE_ID,INCIDENT_ID,DISCIPLINE_DATE,INFRACTION,ACTION_TAKEN,SUSPENSION_DAYS,SHORT_EXPUL,ALT_PLACE,STUDENT_STATUS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "AR_DOWN_DISTRICT",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,FY,CYCLE,LEA",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,FY,CYCLE,LEA,WEBSITE_ADDR,MAIL_ADDR,MAIL_CITY,MAIL_STATE,MAIL_ZIP,MAIL_ZIP4,SHIP_ADDR,SHIP_CITY,SHIP_STATE,SHIP_ZIP,SHIP_ZIP4,PHONE_AREA,PHONE_PREFIX,PHONE_SUFFIX,PHONE_EXT,FAX_AREA,FAX_PREFIX,FAX_SUFFIX,FAX_EXT,SMS_PASSWORD,AFR_PASSWORD,COOP_LEA,SCHBD_COUNT,SCHOOL_CHOICE,TRANSFER_AGREEMENT,BUS_SAFETY,MILES_ATH,MILES_NONATH,INSUR_COM,INSUR_PREM,DI_SQU_MILES,MILLAGE_1,MILLAGE_MO_1,MILLAGE_CURREXP_1,MILLAGE_DEBTSRV_1,MILLAGE_FOR_1,MILLAGE_AGAINST_1,MILLAGE_2,MILLAGE_MO_2,MILLAGE_CURREXP_2,MILLAGE_DEBTSRV_2,MILLAGE_FOR_2,MILLAGE_AGAINST_2,MILLAGE_3,MILLAGE_MO_3,MILLAGE_CURREXP_3,MILLAGE_DEBTSRV_3,MILLAGE_FOR_3,MILLAGE_AGAINST_3,FIREDR_SFTY,FIREDR_INSPCT1,FIREDR_INSPCT2,ACT609_TRANSP,ACT214_TRANSP,SPED_TRANSP,NONPUB_TRANSP,DIST_PRIVSCH,CYCLE1_DATE,CYCLE2_DATE,CYCLE3_DATE,CYCLE4_DATE,CYCLE5_DATE,CYCLE6_DATE,CYCLE7_DATE,CYCLE8_DATE,CYCLE9_DATE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "AR_DOWN_EC",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,FISCAL_YEAR,CYCLE,DISTRICT_LEA,STUDENT_ID",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,FISCAL_YEAR,CYCLE,DISTRICT_LEA,SSN,STUDENT_ID,STUDENT_STATE_ID,FIRST_NAME,MIDDLE_NAME,LAST_NAME,RACE,GENDER,BIRTH_DATE,TEMP_STUDENT,RESIDENT_LEA,PRIMARY_DISABILITY,EDU_ENVIRONMENT,PROGRAM_TYPE,ELL_STATUS,ENTRY_DATE,TRANS_CONF_DATE,TRANS_CODE,CONF_LEA,EXIT_STATUS,EXIT_DATE,ENTRY_ASSESS_DATE,ENTRY_SOCIAL_SCORE,ENTRY_SKIL_SCORE,ENTRY_SELF_SCORE,EXIT_ASSESS_DATE,EXIT_SOC_SCORE,EXIT_SKIL_SCORE,EXIT_SELF_SCORE,EXIT_SOC_IMPRV,EXIT_SKIL_IMPRV,EXIT_SELF_IMPRV,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "AR_DOWN_EIS1",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,FISCAL_YEAR,CYCLE,DISTRICT_LEA,STUDENT_ID,ENTRY_DATE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,FISCAL_YEAR,CYCLE,DISTRICT_LEA,SSN,STUDENT_ID,STUDENT_STATE_ID,FIRST_NAME,MIDDLE_NAME,LAST_NAME,BIRTHDATE,RACE,GENDER,GRADE,ELL,RES_LEA,ENTRY_DATE,WITHDRAWAL_DATE,WITHDRAWAL_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "AR_DOWN_EIS2",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,FISCAL_YEAR,CYCLE,DISTRICT_LEA,STUDENT_ID,SERVICE_TYPE,START_DATE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,FISCAL_YEAR,CYCLE,DISTRICT_LEA,SSN,STUDENT_ID,STUDENT_STATE_ID,SERVICE_TYPE,OTHER_SERVICES,START_DATE,END_DATE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "AR_DOWN_EMPLOYEE",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,FISCAL_YEAR,CYCLE,LEA,SSN,STAFF_ID",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,FISCAL_YEAR,CYCLE,LEA,SSN,TEACH_ID,STAFF_ID,FNAME,MNAME,LNAME,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "AR_DOWN_GRADUATE",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,FY,CYCLE,LEA,STUDENT_ID",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,FY,CYCLE,LEA,STUDENT_ID,SSN,STUDENT_STATE_ID,RACE,GENDER,BIRTH_DATE,GRADUATION_DATE,CLASS_RANK,GRADUATION_AGE,STUDENT_DATA,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "AR_DOWN_HEARING",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,FY,CYCLE,LEA,STUDENT_ID,GRADE_LEVEL,SCREEN_DATE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,FY,CYCLE,LEA,STUDENT_ID,GRADE_LEVEL,SCREEN_DATE,SSN,STUDENT_STATE_ID,RIGHT_EAR,LEFT_EAR,REFERRAL,FOLLOW_UP,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "AR_DOWN_JOBASSIGN",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,FY,CYCLE,LEA,SSN,UNIQ_EMP_ID,JOB_CODE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,FY,CYCLE,LEA,SSN,UNIQ_EMP_ID,JOB_CODE,PARAPROF_QUAL,FTE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "AR_DOWN_REFERRAL",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,FISCAL_YEAR,CYCLE,DISTRICT_LEA,STUDENT_ID,REFERRAL_ID",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,FISCAL_YEAR,CYCLE,DISTRICT_LEA,STUDENT_ID,REFERRAL_ID,SSN,STUDENT_STATE_ID,FIRST_NAME,MIDDLE_NAME,LAST_NAME,BIRTH_DATE,ETHNIC_CODE,RACE,GENDER,GRADE_LEVEL,ELL_STATUS,RESIDENT_LEA,PRIVATE_SCHOOL,PRIVATE_SCHOOL_NAME,BUILDING_CODE,PART_C_TO_B,PART_C_AND_B,REFERRAL_DATE,PAR_CONS_EVAL_DATE,EVAL_DATE,REAS_EVAL_EXC_60,OTHER_EVAL_REAS,ELIGB_DET_DATE,REAS_EDD_EXC_90,OTHER_EDD_REAS,REAS_EDD_EXC_3RD,OTHER_3RD_EDD_REAS,TEMP_IEP_SVC,SPED_PLACE,EARLY_INTER_SVC,PAR_CONS_SPED_DATE,REFER_COMPLETE,REAS_COMPLETE,OTHER_COMPLETE_REAS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "AR_DOWN_REGISTER",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,FISCAL_YEAR,CYCLE,SCHOOL_LEA,COURSE_SECTION,STUDENT_ID",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,STATE_DISTRICT,FISCAL_YEAR,CYCLE,SCHOOL_LEA,STATE_SCHOOL_LEA,COURSE_NUMBER,STATE_COURSE_NUMBER,COURSE_SECTION,SSN,STUDENT_ID,STUDENT_STATE_ID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "AR_DOWN_SCHL_AGE",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,FY,CYCLE,LEA,STUDENT_ID",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,FY,CYCLE,LEA,SSN,STUDENT_ID,STUDENT_STATE_ID,FNAME,MNAME,LNAME,RACE_ETHNIC,GENDER,BIRTH_DATE,TEMP_STUDENT,GRADE,NON_GRADED,ALT_PORT,CHARTER_SCH,BLDG_CODE,ELL,SCH_CHOICE,SCHIMPRV_OUTDIST,RES_LEA,PRDS_CD,FEDPL_CD,PRIV_PRO,RESID_LEA,PRIVPROV_LEA,STP_DATE,SPED_EXIT,FEDPL_PRYR,EXIT_DATE,ENTRY_DATE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "AR_DOWN_SCHOOL",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,FY,CYCLE,LEA",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,FY,CYCLE,LEA,WEB_ADDR,MAIL_ADDR,MAIL_CITY,MAIL_STATE,MAIL_ZIP,MAIL_ZIP4,SHIP_ADDR,SHIP_CITY,SHIP_STATE,SHIP_ZIP,SHIP_ZIP4,PHONE_AREA,PHONE_PREFIX,PHONE_SUFFIX,PHONE_EXT,FAX_AREA,FAX_PREFIX,FAX_SUFFIX,FAX_EXT,ACCRED_NCENTRAL,BLOCK_SCHEDULE,MINUTES_DAY,PRDS_PER_DAY,MAGNET,ALTERNATIVE,SCH_YRROUND,SCH_4DAY,SCH_NIGHT,SERV_LEARN,SERV_PROJ,SCH_WIDE,SCH_FEDPGM,SCH_LEVEL,SITE_USE,STAFFDEV_HOUS,LIB_VOLUMES,QTR1_BEG,QTR1_END,QTR1_DAYS,QTR2_BEG,QTR2_END,QTR2_DAYS,QTR3_BEG,QTR3_END,QTR3_DAYS,QTR4_BEG,QTR4_END,QTR4_DAYS,FIREDR_MARSHPGM,FIREDR_EVPLAN,FIREDR_BLDGCK,PRESCH_CLSRM,HEAD_START,ABC,HIPPY,PRIV_PRESCH,DIST_FUND,EARLY_CHILD_SPED,YOUNG_PRESCH,OLD_PRESCH,BEFORE_SCH,AFTER_SCH_PRG,WK_END_PRG,SUM_SCH_PRG,SAFE_SCH,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "AR_DOWN_SCOLIOSIS",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,FY,CYCLE,LEA,STUDENT_ID,GRADE_LEVEL,SCREEN_DATE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,FY,CYCLE,LEA,STUDENT_ID,GRADE_LEVEL,SCREEN_DATE,SSN,STUDENT_STATE_ID,REFERRAL,FOLLOW_UP,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "AR_DOWN_SE_STAFF",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,FY,CYCLE,LEA,SSN,TEACH_ID,SVPR_CD,SPED_GRD,BLDG_CODE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,FY,CYCLE,LEA,SSN,TEACH_ID,SVPR_CD,SPED_GRD,BLDG_CODE,FNAME,MNAME,LNAME,TECERT_CD,SPED_AIDE,INST_HRS,PRDS_CD,PER_RANGE,CASE_CNT,LIC_END,ST_COURSE,OT_COURSE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "AR_DOWN_STU",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,FISCAL_YEAR,CYCLE,LEA,STUDENT_ID",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,FISCAL_YEAR,CYCLE,LEA,SSN,STUDENT_ID,STUDENT_STATE_ID,FIRST_NAME,MIDDLE_NAME,LAST_NAME,RACE,GENDER,BIRTHDATE,DIST_RESIDENCE,RESIDENT,GRADE_LEVEL,PRESCHOOL,CCLC_21,ENTRY_CODE,ENTRY_DATE,GPA,SMART_CODE_WAIV,CONSOLIDATED_LEA,SCHOOL_CHOICE,CHOICE_DIST,CHOICE_OUTSIDE_DIST,CHOICE_1st_TIME,CHOICE_LEA,TUITION,TUITION_AGREEMENT,SERVICE_SCHOOL,LEA_SENDRECEIVE,SUPP_SERVICE,SUPP_SERV_PROVIDER,DISPLACE_DIST,DISPLACE_STATE,MEAL_STATUS,TITLE1_STATUS,GIFTED_STATUS,SPEC_ED_STATUS,HANDICAP_STATUS,FORMER_ELL,ELL_ENTRY_DATE,ELL_EXIT_DATE,ESL_WAIVE_DATE,MIGRANT_STATUS,MARITAL_STATUS,HOMELESS_YOUTH,HOMELESS_STATUS,ORPHAN_STATUS,FOSTER_CHILD,ELL_STATUS,PRIMARY_LANGUAGE,RETENTION,MOBILITY,DROPOUT,ENROLLMENT_STATUS,DROPOUT_CODE,DROPOUT_DATE,M_TO_M,PARENT_FNAME,PARENT_MNAME,PARENT_LNAME,MAILING_ADDRESS,MAILING_CITY,MAILING_STATE,MAILING_ZIP,PHY_ADDRESS,PHY_CITY,PHY_STATE,PHY_ZIP,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "AR_DOWN_STU_ID",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,FISCAL_YEAR,CYCLE,LEA,STUDENT_ID",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,FISCAL_YEAR,CYCLE,LEA,STUDENT_ID,STUDENT_STATE_ID,ID_CHANGEDATE,PREVIOUS_ID,NEW_ID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "AR_DOWN_STUDENT_GRADES",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,FY,CYCLE,LEA,STUDENT_ID,SECTION_KEY",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,FY,CYCLE,LEA,STUDENT_ID,SSN,STUDENT_STATE_ID,SECTION_KEY,COURSE,SECTION,DESCRIPTION,SEM1_GRADE,SEM2_GRADE,SEM3_GRADE,SEM4_GRADE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "AR_DOWN_VISION",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,FY,CYCLE,LEA,STUDENT_ID,GRADE_LEVEL,SCREEN_DATE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,FY,CYCLE,LEA,SSN,STUDENT_ID,STUDENT_STATE_ID,GRADE_LEVEL,SCREEN_DATE,EXT_EXAM,VISION20,COLORBLIND,FUSION_FAR,FUSION,LAT_MB,LATERAL_FAR,VERT_MB,PLUS2_LEN,REFERRAL,FOLLOW_UP,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ARTB_21CCLC",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ARTB_DIST_LEARN",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ARTB_DIST_LRNPROV",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ARTB_DISTRICTS",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ARTB_EC_ANTIC_SVC",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ARTB_EC_DISAB",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ARTB_EC_RELATE_SVC",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ARTB_INSTITUTIONS",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ARTB_LEPMONITORED",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ARTB_OTHERDISTRICT",
    "PKColumns": "DISTRICT,NAME",
    "TableColumns": "DISTRICT,NAME,STATE_CODE_EQUIV,STATE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ARTB_OUT_DIST",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ARTB_RESIDENT",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ARTB_RPT_PERIODS",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,END_DATE,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ARTB_SA_ANTIC_SVC",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ARTB_SA_DISAB",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ARTB_SA_RELATE_SVC",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ARTB_SCHOOL_GRADE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ARTB_SE_CERT_STAT",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ARTB_SE_DEV_NEEDS",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ARTB_SE_EDD_3RD",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ARTB_SE_EDD_REASON",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ARTB_SE_EDU_ENVIRN",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ARTB_SE_EDU_NEEDS",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ARTB_SE_EDU_PLACE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ARTB_SE_EVAL_CODE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ARTB_SE_EVL_EXCEED",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ARTB_SE_FUNC_IMP",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ARTB_SE_FUNC_SCORE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ARTB_SE_GRADE_LVL",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ARTB_SE_INT_SERV",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ARTB_SE_PROG_TYPE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ARTB_SE_REASON_NOT_ACCESSED",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ARTB_SE_REFERRAL",
    "PKColumns": "DISTRICT,REFERRAL_ID",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,STUDENT_ID,REFERRAL_ID,BUILDING,RESIDENT_LEA,PRIVATE_SCHOOL,PRIVATE_SCHOOL_NAME,ELL,TRANS_PART_C,PART_C_B_CONCURRENT,REFERRAL_DATE,PARENT_EVAL_DATE,EVAL_DATE,EVAL_REASON,EVAL_OT_REASON,ELIGIBILITY_DET_DATE,EDD_30_DAY_CODE,EDD_OT_REASON,EDD_3RD_DOB_CODE,EDD3_OT_REASON,TEMP_IEP_3RD_BDAY,SPED_PLACEMENT,EARLY_INTERV_SERV,PARENT_PLACE_DATE,RFC_REASON,CMP_OTHER,REF_COMPLETE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ARTB_SE_RFC_REASON",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "artb_se_staf_disab",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,SENSITIVE,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ARTB_SE_TITLE_CODE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ARTB_SE_TRANS_CODE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ARTB_TUITION",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATT_AUDIT_TRAIL",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,ATTENDANCE_DATE,STUDENT_ID,ATTENDANCE_PERIOD,SEQUENCE_NUM,ENTRY_ORDER_NUM,SOURCE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,ATTENDANCE_DATE,STUDENT_ID,ATTENDANCE_PERIOD,SEQUENCE_NUM,ENTRY_ORDER_NUM,SOURCE,ATTENDANCE_CODE,DISMISS_TIME,ARRIVE_TIME,MINUTES_ABSENT,BOTTOMLINE,ENTRY_DATE_TIME,ENTRY_USER,ATT_COMMENT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATT_BOTTOMLINE",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,STUDENT_ID,ATTENDANCE_DATE,ATTENDANCE_PERIOD,SEQUENCE_NUM",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,STUDENT_ID,ATTENDANCE_DATE,ATTENDANCE_PERIOD,SEQUENCE_NUM,SOURCE,ATTENDANCE_CODE,DISMISS_TIME,ARRIVE_TIME,MINUTES_ABSENT,ATT_COMMENT,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATT_CFG",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,PERIOD_TYPE,USE_TIMETABLE,BOTTOM_LINE_TYPE,POSITIVE_ATND,AUDIT_TYPE,DEFAULT_ABS_CODE,DEFAULT_TAR_CODE,DEFAULT_PRE_CODE,USE_LANG_TEMPLATE,DATA_SOURCE_FILE,PROGRAM_SCREEN,REG_USER_SCREEN,NOTIFY_DWNLD_PATH,EMAIL_OPTION,RETURN_EMAIL,RET_EMAIL_MISSUB,TWS_TAKE_ATT,TWS_ALT_ABS,TWS_NUM_VIEW_DAYS,TWS_NUM_MNT_DAYS,TWS_ATT_STU_SUMM,DEF_TAC_ABS_CODE,DEF_TAC_TAR_CODE,DEF_TAC_PRES_CODE,ATT_LOCK_DATE,CODE_LIST_TEACH_SUBST,SIF_VIEW,CHANGE_DATE_TIME,CHANGE_UID,ATT_CHECK_IN",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATT_CFG_CODES",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,ATTENDANCE_CODE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,ATTENDANCE_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATT_CFG_MISS_SUB",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,LOGIN_ID",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,LOGIN_ID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATT_CFG_PERIODS",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,ATTENDANCE_PERIOD",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,ATTENDANCE_PERIOD,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATT_CODE",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,ATTENDANCE_CODE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,ATTENDANCE_CODE,DESCRIPTION,COLOR,USE_DISMISS_TIME,USE_ARRIVE_TIME,DISTRICT_GROUP,STATE_GROUP,SIF_TYPE,SIF_STATUS,SIF_PRECEDENCE,INCLUDE_PERFPLUS,ALT_ATTENDANCE_CODE,STATE_CODE_EQUIV,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATT_CODE_BUILDING",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,ATTENDANCE_CODE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,ATTENDANCE_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATT_CONFIG_PERCENT",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,VIEW_TYPE,ATND_INTERVAL",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,VIEW_TYPE,ATND_INTERVAL,DISPLAY_ORDER,TITLE,DECIMAL_PRECISION,DISPLAY_DETAIL,MINUTES_AS_HOURS,COMBINE_BUILDING,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATT_COURSE_SEATING",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,GRID_MODE,GRID_COLS,GRID_ROWS,WIDTH,HEIGHT,BACKGROUND,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATT_EMERGENCY",
    "PKColumns": "DISTRICT,BUILDING,STUDENT_ID",
    "TableColumns": "DISTRICT,BUILDING,STUDENT_ID,STAFF_ID,ROOM,ABSENT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATT_EMERGENCY_CFG",
    "PKColumns": "DISTRICT,BUILDING",
    "TableColumns": "DISTRICT,BUILDING,EMERGENCY_ATT,STUDENT_CELL_TYPE,CONTACT_TYPE1,PHONE1_TYPE1,PHONE1_TYPE2,CONTACT_TYPE2,PHONE2_TYPE1,PHONE2_TYPE2,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATT_HRM_SEATING",
    "PKColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,SUMMER_SCHOOL,HOMEROOM_TYPE,HOMEROOM",
    "TableColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,SUMMER_SCHOOL,HOMEROOM_TYPE,HOMEROOM,GRID_MODE,GRID_COLS,GRID_ROWS,WIDTH,HEIGHT,BACKGROUND,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATT_INTERVAL",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,SUMMER_SCHOOL,ATND_INTERVAL",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,SUMMER_SCHOOL,ATND_INTERVAL,DESCRIPTION,ATT_INTERVAL_ORDER,INTERVAL_TYPE,BEGIN_SPAN,END_SPAN,SUM_BY_ATT_CODE,SUM_BY_DISTR_GRP,SUM_BY_STATE_GRP,STATE_CODE_EQUIV,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATT_LOCK_DATE",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,TRACK",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,TRACK,LOCK_DATE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATT_NOTIFY_CRIT",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,NOTIFY_CRITERIA",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,NOTIFY_CRITERIA,DESCRIPTION,NOTIFICATION_ORDER,NOTIFY_GROUP,EMAIL_STAFF,REPORT_CYCLE_TYPE,INTERVAL_TYPE,SUNDAY,MONDAY,TUESDAY,WEDNESDAY,THURSDAY,FRIDAY,SATURDAY,EVALUATION_TYPE,EVALUATION_SOURCE,EVAL_VIEW_TYPE,DETAIL_DATE_RANGE,DATE_ORDER,SEND_LETTER,MIN_ABS_TYPE,MAX_ABS_TYPE,MIN_OVERALL_ABS,MAX_OVERALL_ABS,OVERALL_ABS_BY,MIN_ABSENCE,MAX_ABSENCE,ABSENCE_PATTERN,MIN_DAY,MAX_DAY,DAY_PATTERN,MIN_PERCENT_DAY,MAX_PERCENT_DAY,CALC_SELECTION,USE_ELIGIBILITY,ELIG_INCLUDE_PRIOR,ELIGIBILITY_CODE,ELIG_DURATION,ELIG_DURATION_DAYS,MAX_LETTER,USE_DISCIPLINE,IS_STUDENT,PERSON_ID,INCIDENT_CODE,ACTION_CODE,INCLUDE_FINE,USE_AT_RISK,AT_RISK_REASON,AT_RISK_DURATION,AT_RISK_DAYS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATT_NOTIFY_CRIT_CD",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,NOTIFY_CRITERIA,EVALUATION_CODE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,NOTIFY_CRITERIA,EVALUATION_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATT_NOTIFY_CRIT_PD",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,NOTIFY_CRITERIA,ATTENDANCE_PERIOD",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,NOTIFY_CRITERIA,ATTENDANCE_PERIOD,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATT_NOTIFY_ELIG_CD",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,NOTIFY_CRITERIA,SEQUENCE_ORDER,CURRENT_ELIG_STAT",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,NOTIFY_CRITERIA,SEQUENCE_ORDER,CURRENT_ELIG_STAT,ELIGIBILITY_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATT_NOTIFY_GROUP",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,NOTIFY_GROUP",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,NOTIFY_GROUP,DESCRIPTION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATT_NOTIFY_LANG",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,LANGUAGE_CODE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,LANGUAGE_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATT_NOTIFY_STU_DET",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,STUDENT_ID,NOTIFY_CRITERIA,REPORT_CYCLE_DATE,TRIGGER_DATE,ATTENDANCE_DATE,ATTENDANCE_PERIOD,SEQUENCE_NUM",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,STUDENT_ID,NOTIFY_CRITERIA,REPORT_CYCLE_DATE,TRIGGER_DATE,ATTENDANCE_DATE,ATTENDANCE_PERIOD,SEQUENCE_NUM,EVALUATION_CODE,INVALID_NOTIFY,ATTENDANCE_COUNT,ABSENCE_TYPE,ABSENCE_VALUE,SECTION_KEY,INCIDENT_ID,ACTION_NUMBER,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATT_NOTIFY_STU_HDR",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,STUDENT_ID,NOTIFY_CRITERIA,REPORT_CYCLE_DATE,TRIGGER_DATE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,STUDENT_ID,NOTIFY_CRITERIA,REPORT_CYCLE_DATE,TRIGGER_DATE,EVALUATION_CODE,PUBLISHED,INVALID_NOTIFY,CHANGE_DATE_TIME,CHANGE_UID,PUBLISHED_NOTIFICATION",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATT_PERIOD",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,ATTENDANCE_PERIOD",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,ATTENDANCE_PERIOD,DESCRIPTION,ATT_PERIOD_ORDER,PERIOD_VALUE,START_TIME,END_TIME,INC_IN_ATT_VIEW,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATT_STU_AT_RISK",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,STUDENT_ID,NOTIFY_CRITERIA,REPORT_CYCLE_DATE,TRIGGER_DATE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,STUDENT_ID,NOTIFY_CRITERIA,REPORT_CYCLE_DATE,TRIGGER_DATE,AT_RISK_REASON,EFFECTIVE_DATE,EXPIRATION_DATE,PLAN_NUM,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATT_STU_CHECK_IN",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,STUDENT_ID,ATTENDANCE_DATE,ATTENDANCE_KEY,CHECKIN_DATE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,STUDENT_ID,ATTENDANCE_DATE,ATTENDANCE_KEY,SOURCE,CHECKIN_DATE,VIRTUAL_MEET_ID,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATT_STU_COURSE_SEAT",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,STUDENT_ID",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,STUDENT_ID,HAS_SEAT,SEAT_NUMBER,POSITION_X,POSITION_Y,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATT_STU_DAY_TOT_LAST",
    "PKColumns": "DISTRICT,VIEW_TYPE,STUDENT_ID,BUILDING,LAST_CALC_DATE",
    "TableColumns": "DISTRICT,VIEW_TYPE,STUDENT_ID,BUILDING,LAST_CALC_DATE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATT_STU_DAY_TOTALS",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,SUMMER_SCHOOL,STUDENT_ID,ATTENDANCE_DATE,VIEW_TYPE,CRITERIA",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,SUMMER_SCHOOL,STUDENT_ID,ATTENDANCE_DATE,VIEW_TYPE,CRITERIA,ATTENDANCE_CODE,ATT_CODE_VALUE,TOTAL_DAY_TIME,STUDENT_SCHD_TIME,STU_UNSCHD_TIME,PRESENT_TIME,ABSENT_TIME,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID,LOCATION_TYPE,MAX_DAY_TIME",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATT_STU_DAY_TOTALS_CALC",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,SUMMER_SCHOOL,STUDENT_ID,ATTENDANCE_DATE,VIEW_TYPE,CRITERIA",
    "TableColumns": "DISTRICT,PARAM_KEY,SCHOOL_YEAR,BUILDING,SUMMER_SCHOOL,STUDENT_ID,ATTENDANCE_DATE,VIEW_TYPE,CRITERIA",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "ATT_STU_ELIGIBLE",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,STUDENT_ID,NOTIFY_CRITERIA,REPORT_CYCLE_DATE,TRIGGER_DATE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,STUDENT_ID,NOTIFY_CRITERIA,REPORT_CYCLE_DATE,TRIGGER_DATE,ELIGIBILITY_CODE,EFFECTIVE_DATE,EXPIRATION_DATE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATT_STU_EMAIL_MAP",
    "PKColumns": "DISTRICT,STUDENT_ID,EMAIL",
    "TableColumns": "DISTRICT,STUDENT_ID,EMAIL,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATT_STU_HRM_SEAT",
    "PKColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,SUMMER_SCHOOL,HOMEROOM_TYPE,HOMEROOM,STUDENT_ID",
    "TableColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,SUMMER_SCHOOL,HOMEROOM_TYPE,HOMEROOM,STUDENT_ID,HAS_SEAT,SEAT_NUMBER,POSITION_X,POSITION_Y,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATT_STU_INT_CRIT",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,SUMMER_SCHOOL,STUDENT_ID,VIEW_TYPE,CRITERIA,ATND_INTERVAL",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,SUMMER_SCHOOL,STUDENT_ID,VIEW_TYPE,CRITERIA,ATND_INTERVAL,TOTAL_DAY_TIME,STUDENT_SCHD_TIME,STU_UNSCHD_TIME,PRESENT_TIME,ABSENT_TIME,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATT_STU_INT_GROUP",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,SUMMER_SCHOOL,STUDENT_ID,VIEW_TYPE,ATND_INTERVAL,INTERVAL_TYPE,INTERVAL_CODE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,SUMMER_SCHOOL,STUDENT_ID,VIEW_TYPE,ATND_INTERVAL,INTERVAL_TYPE,INTERVAL_CODE,ATT_CODE_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATT_STU_INT_MEMB",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,SUMMER_SCHOOL,STUDENT_ID,ATND_INTERVAL",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,SUMMER_SCHOOL,STUDENT_ID,ATND_INTERVAL,TOTAL_MEMBERSHIP,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATT_TWS_TAKEN",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,ATTENDANCE_DATE,PERIOD_KEY,ATTENDANCE_PERIOD",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,ATTENDANCE_DATE,PERIOD_KEY,ATTENDANCE_PERIOD,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATT_VIEW_ABS",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,VIEW_TYPE,CRITERIA,ATTENDANCE_CODE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,VIEW_TYPE,CRITERIA,ATTENDANCE_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATT_VIEW_CYC",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,VIEW_TYPE,CRITERIA,CYCLE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,VIEW_TYPE,CRITERIA,CYCLE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATT_VIEW_DET",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,VIEW_TYPE,CRITERIA",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,VIEW_TYPE,CRITERIA,CALENDAR,MIN_OCCURRENCE,MAX_OCCURRENCE,CONSECUTIVE_ABS,SAME_ABS,ATT_CODE_CONVERT,ATT_CODE_VALUE,PERCENT_ABSENT,USE_SCHD_PERIODS,USE_ALL_PERIODS,CHANGE_DATE_TIME,CHANGE_UID,LOCATION_TYPE",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATT_VIEW_HDR",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,VIEW_TYPE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,VIEW_TYPE,DESCRIPTION,CRITERIA_TYPE,LAST_DAY_CALCED,ATT_TOTALS_UNITS,DAY_UNITS,INCLUDE_PERFPLUS,INCLD_PASSING_TIME,MAX_PASSING_TIME,SEPARATE_BUILDINGS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATT_VIEW_INT",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,VIEW_TYPE,ATT_INTERVAL",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,VIEW_TYPE,ATT_INTERVAL,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATT_VIEW_MSE_BLDG",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,VIEW_TYPE,MSE_BUILDING",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,VIEW_TYPE,MSE_BUILDING,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATT_VIEW_PER",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,VIEW_TYPE,CRITERIA,ATTENDANCE_PERIOD",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,VIEW_TYPE,CRITERIA,ATTENDANCE_PERIOD,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATT_VIRTUAL_MEETING_LINKS",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,ATTENDANCE_KEY",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,ATTENDANCE_KEY,VIRTUAL_MEETING_LINK,CHANGE_DATE_TIME,CHANGE_UID,RECORD_TYPE",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATT_VIRTUAL_MEETING_LOG",
    "PKColumns": "DISTRICT,ATTENDANCE_KEY,ATT_DATE",
    "TableColumns": "DISTRICT,ATTENDANCE_KEY,STAFF_LOGIN_ID,ATTENDANCE_STATUS,ATT_DATE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATT_VIRTUAL_MEETING_UNMAPPED_STUDENTS",
    "PKColumns": "DISTRICT,ATTENDANCE_KEY,UNMAPPED_EMAIL,ATT_DATE",
    "TableColumns": "DISTRICT,ATTENDANCE_KEY,VIRTUAL_MEETING_LINK,UNMAPPED_EMAIL,ATT_DATE,CHECKIN_DATE,STUDENT_NAME,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATT_YREND_RUN",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,RUN_KEY",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,RUN_KEY,BUILDING_LIST,RUN_DATE,RUN_STATUS,PURGE_BLDG_YEAR,PURGE_DETAIL_YEAR,PURGE_STU_NOT_YEAR,PURGE_STU_DAY_YEAR,PURGE_STU_INT_YEAR,RESTORE_KEY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATTTB_DISTRICT_GRP",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATTTB_INELIGIBLE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATTTB_SIF_STATUS",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATTTB_SIF_TYPE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ATTTB_STATE_GRP",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "BOOK_ALT_LOCATION",
    "PKColumns": "DISTRICT,BUILDING,HOUSE_TEAM",
    "TableColumns": "DISTRICT,BUILDING,HOUSE_TEAM,ALT_BUILDING,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "BOOK_ASSIGN",
    "PKColumns": "DISTRICT,BAR_CODE",
    "TableColumns": "DISTRICT,BAR_CODE,ISBN_CODE,BOOK_TYPE,BUILDING,ASSIGNED_TO,DATE_ASSIGNED,WHO_HAS_BOOK,PENDING_TRANSFER,STATUS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "BOOK_BLDG_CFG",
    "PKColumns": "DISTRICT,BUILDING",
    "TableColumns": "DISTRICT,BUILDING,USE_SCHD_CALC,FROM_STU_TO_STU,FROM_STU_TO_TEA,FROM_STU_TO_BLDG,FROM_TEA_TO_STU,FROM_TEA_TO_TEA,FROM_TEA_TO_BLDG,FROM_BLDG_TO_STU,FROM_BLDG_TO_TEA,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "BOOK_BOOKMASTER",
    "PKColumns": "DISTRICT,ISBN_CODE,BUILDING,BOOK_TYPE",
    "TableColumns": "DISTRICT,ISBN_CODE,BUILDING,BOOK_TYPE,USABLE_ON_HAND,WORN_OUT,PAID_FOR,AMOUNT_FINES,REPORTED_SURPLUS,BOOKS_ON_ORDER,ALLOCATED,PURCHASE_ORDER,REQUESTS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "BOOK_CFG",
    "PKColumns": "DISTRICT",
    "TableColumns": "DISTRICT,USE_WAREHOUSE,BUILDING,USE_TRANS_LOG,USE_STU_TRACK,REQ_MAX_LINES,AUTO_UPDATE_RECV,FROM_STU_TO_STU,FROM_STU_TO_TEA,FROM_STU_TO_BLDG,FROM_STU_TO_WARE,FROM_TEA_TO_STU,FROM_TEA_TO_TEA,FROM_TEA_TO_BLDG,FROM_TEA_TO_WARE,FROM_BLDG_TO_STU,FROM_BLDG_TO_TEA,FROM_BLDG_TO_BLDG,FROM_BLDG_TO_WARE,FROM_WARE_TO_STU,FROM_WARE_TO_TEA,FROM_WARE_TO_BLDG,PRT_DOC_TEXT,PRT_DOC_NAME,PRT_DOC_TITLE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "BOOK_DIST",
    "PKColumns": "DISTRICT,BUILDING,ISBN_CODE,BOOK_TYPE",
    "TableColumns": "DISTRICT,BUILDING,ISBN_CODE,BOOK_TYPE,BAR_CODE_START,BAR_CODE_END,CREATED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "BOOK_ENROLL",
    "PKColumns": "DISTRICT,BUILDING,MLC_CODE",
    "TableColumns": "DISTRICT,BUILDING,MLC_CODE,DESCRIPTION,STU_MEMBERSHIP,TEA_MEMBERSHIP,HIGH_ENROLL,OLD_VALUE,CHANGE_FLAG,STU_HIGH_ENROLL,HIGH_ENROLL_TEA,TEA_HIGH_ENROLL,STU_HIGH_ENR_LOCK,TEA_HIGH_ENR_LOCK,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "BOOK_GRADES",
    "PKColumns": "DISTRICT,ISBN_CODE,BOOK_TYPE",
    "TableColumns": "DISTRICT,ISBN_CODE,BOOK_TYPE,GRADE_LEVEL,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "BOOK_MLC_COURSE",
    "PKColumns": "DISTRICT,COURSE,MLC_CODE",
    "TableColumns": "DISTRICT,COURSE,MLC_CODE,STATE_COURSE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "BOOK_REQ_DET",
    "PKColumns": "DISTRICT,ORDER_NUMBER,LINE_NUMBER",
    "TableColumns": "DISTRICT,ORDER_NUMBER,LINE_NUMBER,ISBN_CODE,BOOK_TYPE,ORDERED,SHIPPED,SHIPPED_TO_DATE,RECEIVED,RECEIVED_TO_DATE,LAST_DATE_SHIPPED,LAST_DATE_RECEIVED,LAST_QTY_SHIPPED,LAST_QTY_RECEIVED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "BOOK_REQ_HDR",
    "PKColumns": "DISTRICT,ORDER_NUMBER",
    "TableColumns": "DISTRICT,ORDER_NUMBER,REQUESTOR,BUILDING,DATE_ENTERED,DATE_PRINTED,DATE_SENT,STATUS,LAST_SHIPPED,LAST_RECEIVED,DATE_CLOSED,SCREEN_ENTRY,NOTES,TRANSFER_FROM,NEXT_YEAR_REQ,REF_ORDER_NUMBER,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "BOOK_STU_BOOKS",
    "PKColumns": "DISTRICT,BAR_CODE",
    "TableColumns": "DISTRICT,BAR_CODE,STUDENT_ID,LAST_TRANS_DATE,BUILDING,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "BOOK_TEXTBOOK",
    "PKColumns": "DISTRICT,ISBN_CODE,BOOK_TYPE",
    "TableColumns": "DISTRICT,ISBN_CODE,BOOK_TYPE,MLC_CODE,BOOK_TITLE,AUTHOR,PUBLISHER_CODE,COPYRIGHT_YEAR,UNIT_COST,ADOPTION_YEAR,EXPIRATION_YEAR,ADOPTION_STATUS,QUOTA_PERCENT,USABLE_ON_HAND,WORN_OUT,PAID_FOR,AMOUNT_FINES,REPORTED_SURPLUS,BOOKS_ON_ORDER,ISBN_CODE_OTHER,DEPOSITORY_CODE,BOOK_TYPE_RELATED,BOOKS_ON_PURCHASE,SUBJECT_DESC,ST_ADOPTION_CODE,GRADE_LEVEL,ACTIVE,OK_TO_ORDER,LOCAL_FLAG,EXTENDED_DESC,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "BOOK_TRANS",
    "PKColumns": "DISTRICT,TRANS_NUMBER",
    "TableColumns": "DISTRICT,TRANS_NUMBER,ISBN_CODE,BOOK_TYPE,TRANSACTION_DATE,TRANSACTION_CODE,DESCRIPTION,USABLE_ON_HAND,WORN_OUT,PAID_FOR,AMOUNT_FINES,REPORTED_SURPLUS,NUMBER_BOOKS,PREVIOUS_BLDG,NEW_BUILDING,NEW_BOOK_CODE,TRANSFER_CONTROL,ORDERED_BOOKS,ADJ_COMMENT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "BOOK_WAREALTLOC",
    "PKColumns": "DISTRICT,ISBN_CODE,BUILDING,BOOK_TYPE,ALT_LOCATION",
    "TableColumns": "DISTRICT,ISBN_CODE,BUILDING,BOOK_TYPE,ALT_LOCATION,DISPLAY_ORDER,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "BOOKTB_ADJ_COMMENT",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "BOOKTB_ADOPTION",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "BOOKTB_DEPOSITORY",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "BOOKTB_MLC",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "BOOKTB_PUBLISHER",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "BOOKTB_TYPE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "COTB_REPORT_PERIOD",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,COLLECTION_PERIOD,START_DATE,END_DATE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,COLLECTION_PERIOD,DESCRIPTION,START_DATE,END_DATE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "CP_CFG",
    "PKColumns": "DISTRICT,BUILDING",
    "TableColumns": "DISTRICT,BUILDING,BLDG_HANDBOOK_LINK,STUDENT_PLAN_TEXT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "CP_GRADPLAN_COURSE",
    "PKColumns": "DISTRICT,REQ_GROUP,STU_GRAD_YEAR,GRADE,BUILDING,COURSE_OR_GROUP",
    "TableColumns": "DISTRICT,REQ_GROUP,STU_GRAD_YEAR,GRADE,BUILDING,COURSE_OR_GROUP,CRS_GROUP_FLAG,IS_REQUIRED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "CP_GRADPLAN_GD",
    "PKColumns": "DISTRICT,REQ_GROUP,STU_GRAD_YEAR,GRADE",
    "TableColumns": "DISTRICT,REQ_GROUP,STU_GRAD_YEAR,GRADE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "CP_GRADPLAN_HDR",
    "PKColumns": "DISTRICT,REQ_GROUP,STU_GRAD_YEAR",
    "TableColumns": "DISTRICT,REQ_GROUP,STU_GRAD_YEAR,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "CP_GRADPLAN_SUBJ",
    "PKColumns": "DISTRICT,REQ_GROUP,STU_GRAD_YEAR,GRADE,SUBJECT_AREA",
    "TableColumns": "DISTRICT,REQ_GROUP,STU_GRAD_YEAR,GRADE,SUBJECT_AREA,CREDIT,CRS_GROUP_FLAG,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "CP_STU_COURSE_OVR",
    "PKColumns": "DISTRICT,STUDENT_ID,BUILDING,COURSE",
    "TableColumns": "DISTRICT,STUDENT_ID,BUILDING,COURSE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "CP_STU_FUTURE_REQ",
    "PKColumns": "DISTRICT,STUDENT_ID,PLAN_MODE,SCHOOL_YEAR,BUILDING,REQ_GROUP,COURSE,REQUIRE_CODE",
    "TableColumns": "DISTRICT,STUDENT_ID,PLAN_MODE,SCHOOL_YEAR,BUILDING,REQ_GROUP,COURSE,REQUIRE_CODE,CODE_OVERRIDE,SUBJ_AREA_CREDIT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "CP_STU_GRAD",
    "PKColumns": "DISTRICT,STUDENT_ID,PLAN_MODE,REQ_GROUP,REQUIRE_CODE",
    "TableColumns": "DISTRICT,STUDENT_ID,PLAN_MODE,REQ_GROUP,REQUIRE_CODE,SUBJ_AREA_CREDIT,CUR_ATT_CREDITS,CUR_EARN_CREDITS,CP_SCHD_CREDITS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "CP_STU_GRAD_AREA",
    "PKColumns": "DISTRICT,STUDENT_ID,SECTION_KEY,COURSE_SESSION,PLAN_MODE,REQ_GROUP,REQUIRE_CODE",
    "TableColumns": "DISTRICT,STUDENT_ID,SECTION_KEY,COURSE_SESSION,PLAN_MODE,REQ_GROUP,REQUIRE_CODE,CODE_OVERRIDE,SUBJ_AREA_CREDIT,CREDIT_OVERRIDE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "CP_STU_PLAN_ALERT",
    "PKColumns": "DISTRICT,STUDENT_ID,REQ_GROUP,ALERT_CODE,REQUIRE_CODE,BUILDING,COURSE",
    "TableColumns": "DISTRICT,STUDENT_ID,REQ_GROUP,ALERT_CODE,REQUIRE_CODE,BUILDING,COURSE,CREDIT,CREDIT_NEEDED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "CP_VIEW_HDR",
    "PKColumns": "DISTRICT,BUILDING,STU_GRAD_YEAR,VIEW_TYPE",
    "TableColumns": "DISTRICT,BUILDING,STU_GRAD_YEAR,VIEW_TYPE,SHOW_CRS_DESCR,SHOW_CRS_NUMBER,SHOW_CRS_SECTION,SHOW_ATT_CREDIT,SHOW_EARN_CREDIT,SHOW_SUBJ_CREDIT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "CP_VIEW_LTDB",
    "PKColumns": "DISTRICT,BUILDING,STU_GRAD_YEAR,VIEW_TYPE,VIEW_ORDER",
    "TableColumns": "DISTRICT,BUILDING,STU_GRAD_YEAR,VIEW_TYPE,VIEW_ORDER,LABEL,TEST_CODE,TEST_LEVEL,TEST_FORM,SUBTEST,SCORE_CODE,PRINT_TYPE,PRINT_NUMBER,PRINT_BLANK,GROUP_SCORES,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "CP_VIEW_MARKS",
    "PKColumns": "DISTRICT,BUILDING,STU_GRAD_YEAR,VIEW_TYPE,VIEW_SEQUENCE",
    "TableColumns": "DISTRICT,BUILDING,STU_GRAD_YEAR,VIEW_TYPE,VIEW_SEQUENCE,VIEW_ORDER,TITLE,MARK_TYPE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "CP_VIEW_MARKS_MP",
    "PKColumns": "DISTRICT,BUILDING,STU_GRAD_YEAR,VIEW_TYPE,VIEW_SEQUENCE,MARKING_PERIOD",
    "TableColumns": "DISTRICT,BUILDING,STU_GRAD_YEAR,VIEW_TYPE,VIEW_SEQUENCE,MARKING_PERIOD,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "CP_VIEW_WORKSHEET",
    "PKColumns": "DISTRICT,BUILDING,STU_GRAD_YEAR,VIEW_TYPE",
    "TableColumns": "DISTRICT,BUILDING,STU_GRAD_YEAR,VIEW_TYPE,POST_GRAD_PLANS,GRAD_REQS_LIST,SUPP_REQS_LIST,STU_CAREER_PLAN,STU_SUPP_PLAN,SIGNATURE_LINES,UNASSIGNED_COURSES,HEADER_TEXT,FOOTER_TEXT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "CRN_CFG",
    "PKColumns": "DISTRICT",
    "TableColumns": "DISTRICT,CRN_SERVER,GATEWAY_SERVER,GATEWAY_URL,AVAILABLE,CRN_VERSION,CRN_DESCRIPTION,ADD_PARAMS,USE_SSL,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISC_ACT_USER",
    "PKColumns": "INCIDENT_ID,ACTION_NUMBER,SCREEN_TYPE,OFF_VIC_WIT_ID,SCREEN_NUMBER,FIELD_NUMBER",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,INCIDENT_ID,ACTION_NUMBER,SCREEN_TYPE,OFF_VIC_WIT_ID,SCREEN_NUMBER,FIELD_NUMBER,FIELD_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISC_ATT_NOTIFY",
    "PKColumns": "DISTRICT,STUDENT_ID,NOTIFY_CRITERIA,REPORT_CYCLE_DATE,TRIGGER_DATE,INCIDENT_ID",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,STUDENT_ID,NOTIFY_CRITERIA,REPORT_CYCLE_DATE,TRIGGER_DATE,INCIDENT_ID,INVALID_NOTIFY,PUBLISHED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISC_CFG",
    "PKColumns": "DISTRICT,BUILDING",
    "TableColumns": "DISTRICT,BUILDING,FORM_LTR_FILENAME,USE_MULTI_LANGUAGE,PROGRAM_SCREEN,REG_USER_SCREEN,NOTIFY_DWNLD_PATH,EMAIL_OPTION,RETURN_EMAIL,MAGISTRATE_NUMBER,REFERRAL_RPT_HEADER,REFERRAL_RPT_FOOTER,ENABLE_ATTENDANCE,CHANGE_DATE_TIME,CHANGE_UID,EDIT_REFERRALS",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISC_CFG_LANG",
    "PKColumns": "DISTRICT,BUILDING,LANGUAGE_CODE",
    "TableColumns": "DISTRICT,BUILDING,LANGUAGE_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISC_DIST_CFG_AUTO_ACTION",
    "PKColumns": "DISTRICT,ACTION_CODE",
    "TableColumns": "DISTRICT,ACTION_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISC_DIST_OFF_TOT",
    "PKColumns": "DISTRICT,ACT_SUFFIX,ACT_CODE",
    "TableColumns": "DISTRICT,ACT_SUFFIX,ACT_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISC_DISTRICT_ACT",
    "PKColumns": "DISTRICT,TOTAL_CODE,ACTION_CODE",
    "TableColumns": "DISTRICT,TOTAL_CODE,ACTION_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISC_DISTRICT_CFG",
    "PKColumns": "DISTRICT",
    "TableColumns": "DISTRICT,PRIVATE_NOTES,TRACK_OCCURRENCES,MULTIPLE_OFFENSES,CURRENT_YEAR_SUM,OFFENSE_ACT_TOTALS,OFF_ACT_PREV_LST,OFF_ACT_PREV_DET,OFF_ACT_TOTAL_CNT,INCIDENT_LOCKING,ENFORCE_ACT_LEVELS,RESPONSIBLE_ADMIN,RESP_ADMIN_REQ,AUTOCALC_END_DATE,DEFAULT_SCHEDULED_DURATION,USE_LONG_DESCRIPTION,DEFAULT_INCIDENT_DATE,LIMIT_OFFENDER_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISC_DISTRICT_CFG_DETAIL",
    "PKColumns": "DISTRICT,PAGE,PAGE_SECTION",
    "TableColumns": "DISTRICT,PAGE,PAGE_SECTION,QUICKVIEW,DISPLAY_ORDER,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISC_DISTRICT_CFG_SUMMARY",
    "PKColumns": "DISTRICT,SECTION,DISPLAY_ORDER",
    "TableColumns": "DISTRICT,SECTION,DISPLAY_ORDER,SCREEN_NUMBER,FIELD,LABEL,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISC_DISTRICT_COST",
    "PKColumns": "DISTRICT,COST_CODE",
    "TableColumns": "DISTRICT,COST_CODE,COST_LABEL,COST_AMOUNT,PREPRINTED,STATE_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISC_DISTRICT_FINE",
    "PKColumns": "DISTRICT,FINE_CODE,FINE_ORDER",
    "TableColumns": "DISTRICT,FINE_CODE,FINE_ORDER,FINE_LABEL,FINE_AMOUNT,TIMES_USED,FINE_TYPE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISC_DISTRICT_TOT",
    "PKColumns": "DISTRICT,TOTAL_CODE",
    "TableColumns": "DISTRICT,TOTAL_CODE,TOTAL_LABEL,TOTAL_SUFFIX,WARNING_THRESHOLD,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISC_INCIDENT",
    "PKColumns": "DISTRICT,INCIDENT_ID",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,INCIDENT_ID,INCIDENT_CODE,INCIDENT_SUBCODE,INCIDENT_DATE,INCIDENT_TIME,INCIDENT_TIME_FRAME,LOCATION,IS_STUDENT,PERSON_ID,REPORTED_TO,GANG_RELATED,POLICE_NOTIFIED,POLICE_NOTIFY_DATE,POLICE_DEPARTMENT,COMPLAINT_NUMBER,OFFICER_NAME,BADGE_NUMBER,COMMENTS,LONG_COMMENT,INCIDENT_GUID,INCIDENT_LOCKED,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISC_INCIDENT_CODE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,LEVEL_MIN,LEVEL_MAX,STATE_CODE_EQUIV,SEVERITY_ORDER,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISC_LINK_ISSUE",
    "PKColumns": "DISTRICT,INCIDENT_ID,ISSUE_ID",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,INCIDENT_ID,ISSUE_ID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISC_LTR_CRIT",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,CRITERION",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,CRITERION,DESCRIPTION,OFFENSE_COUNT_MIN,OFFENSE_COUNT_MAX,ACTION_COUNT_MIN,ACTION_COUNT_MAX,LETTER_COUNT_TYPE,MAXIMUM_LETTERS,RESET_COUNT,LINES_OF_DETAIL,INCIDENTS_TO_PRINT,USE_ELIGIBILITY,ELIG_INCLUDE_PRIOR,ELIGIBILITY_CODE,ELIG_DURATION,ELIG_DURATION_DAYS,USE_AT_RISK,AT_RISK_REASON,AT_RISK_DURATION,AT_RISK_DAYS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISC_LTR_CRIT_ACT",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,CRITERION,ACTION_CODE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,CRITERION,ACTION_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISC_LTR_CRIT_ELIG",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,CRITERION,SEQUENCE_ORDER,CURRENT_ELIG_STATUS",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,CRITERION,SEQUENCE_ORDER,CURRENT_ELIG_STATUS,ELIGIBILITY_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISC_LTR_CRIT_OFF",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,CRITERION,OFFENSE_CODE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,CRITERION,OFFENSE_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISC_LTR_DETAIL",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,DATE_RUN,RUN_NUMBER,STUDENT_ID,CRITERION,LETTER_RESET",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,DATE_RUN,RUN_NUMBER,STUDENT_ID,CRITERION,LETTER_RESET,OFFENSE_COUNT,ACTION_COUNT,PRINT_DONE,CHANGE_DATE_TIME,CHANGE_UID,NOTIFICATION_SENT",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISC_LTR_HEADER",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,DATE_RUN,RUN_NUMBER",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,DATE_RUN,RUN_NUMBER,DATE_FROM,DATE_THRU,DATE_PRINTED,LETTER_COUNT,CHANGE_DATE_TIME,CHANGE_UID,DATE_NOTIFICATION_SENT",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISC_MSG_ACTIONCODE",
    "PKColumns": "DISTRICT,BUILDING,ACTION_CODE",
    "TableColumns": "DISTRICT,BUILDING,ACTION_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISC_NON_STU_RACES",
    "PKColumns": "DISTRICT,NON_STUDENT_ID,RACE_CODE",
    "TableColumns": "DISTRICT,NON_STUDENT_ID,RACE_CODE,RACE_ORDER,PERCENTAGE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISC_NON_STUDENT",
    "PKColumns": "DISTRICT,NON_STUDENT_ID",
    "TableColumns": "DISTRICT,NON_STUDENT_ID,FIRST_NAME,MIDDLE_NAME,LAST_NAME,GENERATION,APARTMENT,COMPLEX,STREET_NUMBER,STREET_NAME,CITY,STATE,ZIP,PHONE,PHONE_EXTENSION,BIRTHDATE,GRADE,GENDER,ETHNIC_CODE,HISPANIC,FED_RACE_ETHNIC,CLASSIFICATION,STAFF_MEMBER,BUILDING,PERSON_DIST_CODE,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISC_NOTES",
    "PKColumns": "DISTRICT,INCIDENT_ID,NOTE_TYPE,OFF_VIC_WIT_ID,PAGE_NUMBER",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,INCIDENT_ID,NOTE_TYPE,OFF_VIC_WIT_ID,PAGE_NUMBER,NOTE_TEXT,PRIVATE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISC_OCCURRENCE",
    "PKColumns": "DISTRICT,INCIDENT_ID,OFFENDER,ACTION_NUMBER,OCCURRENCE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,INCIDENT_ID,OFFENDER,ACTION_NUMBER,OCCURRENCE,SCHD_START_DATE,ACTUAL_START_DATE,SCHD_START_TIME,SCHD_END_TIME,ACTUAL_START_TIME,ACTUAL_END_TIME,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISC_OFF_ACTION",
    "PKColumns": "DISTRICT,INCIDENT_ID,OFFENDER,ACTION_NUMBER",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,INCIDENT_ID,OFFENDER,ACTION_NUMBER,ACTION_CODE,SCHD_DURATION,ACTUAL_DURATION,REASON_CODE,DISPOSITION_CODE,START_DATE,END_DATE,TOTAL_OCCURRENCES,RESP_BUILDING,ASSIGN_BUILDING,DATE_DETERMINED,ACTION_OUTCOME,YEAREND_CARRY_OVER,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISC_OFF_CHARGE",
    "PKColumns": "DISTRICT,INCIDENT_ID,OFFENDER,CHARGE_CODE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,INCIDENT_ID,OFFENDER,CHARGE_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISC_OFF_CODE",
    "PKColumns": "DISTRICT,INCIDENT_ID,OFFENDER,OFFENSE_CODE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,INCIDENT_ID,OFFENDER,OFFENSE_CODE,OFFENSE_COMMENT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISC_OFF_CONVICT",
    "PKColumns": "DISTRICT,INCIDENT_ID,OFFENDER,CONVICTION_CODE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,INCIDENT_ID,OFFENDER,CONVICTION_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISC_OFF_DRUG",
    "PKColumns": "DISTRICT,INCIDENT_ID,OFFENDER,DRUG_CODE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,INCIDENT_ID,OFFENDER,DRUG_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISC_OFF_FINE",
    "PKColumns": "DISTRICT,INCIDENT_ID,OFFENDER,ACTION_NUMBER",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,INCIDENT_ID,OFFENDER,ACTION_NUMBER,PERSON_ID,IS_STUDENT,FINE_CODE,ISSUED_DATE,FINE_AMOUNT,PAID_DATE,COST,CITATION_NUMBER,STU_CITATION_NUM,MAGISTRATE_NUMBER,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISC_OFF_SUBCODE",
    "PKColumns": "DISTRICT,INCIDENT_ID,OFFENDER,OFFENSE_SUBCODE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,INCIDENT_ID,OFFENDER,OFFENSE_SUBCODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISC_OFF_WEAPON",
    "PKColumns": "DISTRICT,INCIDENT_ID,OFFENDER,WEAPON_CODE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,INCIDENT_ID,OFFENDER,WEAPON_CODE,WEAPON_COUNT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISC_OFFENDER",
    "PKColumns": "DISTRICT,INCIDENT_ID,OFFENDER",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,INCIDENT_ID,OFFENDER,IS_STUDENT,PERSON_ID,GUARDIAN_NOTIFIED,NOTIFY_DATE,HOW_NOTIFIED,REFERRED_TO,POLICE_ACTION,CHARGES_FILED_BY,CHARGES_FILED_WITH,RESP_ADMIN,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISC_PRINT_CITATION",
    "PKColumns": "DISTRICT,PRINT_RUN,SEQUENCE_NUMBER",
    "TableColumns": "DISTRICT,PRINT_RUN,SEQUENCE_NUMBER,CITATION_NUMBER,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,MAGISTRATE_NUMBER,INCIDENT_ID,DEFENDANT_ID,STUDENT_ID,UNLAWFUL_DATES,FINE,COSTS,TOTAL_DUE,CITY_TOWN_BORO,LOCATION,COUNTY_CODE,DATE_FILED,STATION_ADDRESS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISC_STU_AT_RISK",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,DATE_RUN,RUN_NUMBER,STUDENT_ID,CRITERION",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,DATE_RUN,RUN_NUMBER,STUDENT_ID,CRITERION,AT_RISK_REASON,EFFECTIVE_DATE,EXPIRATION_DATE,PLAN_NUM,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISC_STU_ELIGIBLE",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,DATE_RUN,RUN_NUMBER,STUDENT_ID,CRITERION",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,DATE_RUN,RUN_NUMBER,STUDENT_ID,CRITERION,ELIGIBILITY_CODE,EFFECTIVE_DATE,EXPIRATION_DATE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISC_STU_ROLLOVER",
    "PKColumns": "DISTRICT,STUDENT_ID",
    "TableColumns": "DISTRICT,STUDENT_ID,FIRST_NAME,MIDDLE_NAME,LAST_NAME,GENERATION,APARTMENT,COMPLEX,STREET_NUMBER,STREET_NAME,CITY,STATE,ZIP,PHONE,PHONE_EXTENSION,BIRTHDATE,GRADE,GENDER,ETHNIC_CODE,HISPANIC,FED_RACE_ETHNIC,CLASSIFICATION,STAFF_MEMBER,BUILDING,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISC_USER",
    "PKColumns": "INCIDENT_ID,SCREEN_TYPE,OFF_VIC_WIT_ID,SCREEN_NUMBER,FIELD_NUMBER",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,INCIDENT_ID,SCREEN_TYPE,OFF_VIC_WIT_ID,SCREEN_NUMBER,FIELD_NUMBER,FIELD_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISC_VICTIM",
    "PKColumns": "DISTRICT,INCIDENT_ID,VICTIM",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,INCIDENT_ID,VICTIM,VICTIM_CODE,VICTIM_SUBCODE,IS_STUDENT,PERSON_ID,HOSPITAL_CODE,DOCTOR,GUARDIAN_NOTIFIED,NOTIFY_DATE,HOW_NOTIFIED,REFERRED_TO,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISC_VICTIM_ACTION",
    "PKColumns": "DISTRICT,INCIDENT_ID,VICTIM,ACTION_NUMBER",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,INCIDENT_ID,VICTIM,ACTION_NUMBER,ACTION_CODE,SCHD_DURATION,ACTUAL_DURATION,REASON_CODE,DISPOSITION_CODE,START_DATE,END_DATE,RESP_BUILDING,DATE_DETERMINED,ACTION_OUTCOME,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISC_VICTIM_INJURY",
    "PKColumns": "DISTRICT,INCIDENT_ID,VICTIM,INJURY_CODE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,INCIDENT_ID,VICTIM,INJURY_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISC_WITNESS",
    "PKColumns": "DISTRICT,INCIDENT_ID,WITNESS",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,INCIDENT_ID,WITNESS,WITNESS_CODE,WITNESS_SUBCODE,IS_STUDENT,PERSON_ID,GUARDIAN_NOTIFIED,NOTIFY_DATE,HOW_NOTIFIED,REFERRED_TO,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISC_YEAREND_RUN",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,RUN_KEY",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,RUN_KEY,RUN_DATE,RUN_STATUS,CLEAN_DISC_DATA,COPYCARRY,BUILDING_LIST,PURGE_BLD_YEAR,PURGE_INCIDENTS_YR,PURGE_LETTERS_YEAR,RESTORE_KEY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISCTB_ACT_OUTCOME",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISCTB_CHARGE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISCTB_CONVICTION",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISCTB_DISPOSITION",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISCTB_DRUG",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISCTB_INC_SUBCODE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISCTB_INJURY",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISCTB_LOCATION",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISCTB_MAGISTRATE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,NAME,STREET1,STREET2,CITY,STATE,ZIP,PHONE,FINE_BOTH,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISCTB_NOTIFIED",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISCTB_OFF_ACTION",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,LEVEL_NUMBER,ATTENDANCE_CODE,CARRYOVER,STATE_CODE_EQUIV,ACTIVE,SEVERITY_LEVEL,SIF_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISCTB_OFF_SUBCODE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISCTB_POLICE_ACT",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,STATE_CODE_EQUIV,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISCTB_REASON",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISCTB_REFERRAL",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID,STATE_CODE_EQUIV",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISCTB_TIMEFRAME",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISCTB_VIC_ACTION",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISCTB_VIC_CODE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISCTB_VIC_DISP",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISCTB_VIC_REASON",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISCTB_VIC_SUBCODE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISCTB_WEAPON",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,SEVERITY_ORDER,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISCTB_WIT_CODE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "DISCTB_WIT_SUBCODE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ESP_MENU_FAVORITES",
    "PKColumns": "DISTRICT,LOGIN_ID,FAVORITE_ID",
    "TableColumns": "DISTRICT,LOGIN_ID,FAVORITE_ID,FAVORITE_TYPE,FOLDER_ID,FAVORITE_ORDER,DESCRIPTION,AREA,CONTROLLER,ACTION,PAGEURL,QUERY_STRING,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ESP_MENU_ITEMS",
    "PKColumns": "DISTRICT,MENU_ID,MENU_TYPE",
    "TableColumns": "DISTRICT,MENU_ID,MENU_TYPE,PARENT_ID,PARENT_TYPE,TITLE,DESCRIPTION,ICONURL,SEQUENCE,DISPLAY_COLUMN,AREA,CONTROLLER,ACTION,PAGEURL,TARGET,QUERY_STRING,TAC_ACCESS,RESERVED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ESP_PRSG_SCRIPT_HASH",
    "PKColumns": "SCRIPT_FOLDER,SCRIPT_NAME",
    "TableColumns": "SCRIPT_FOLDER,SCRIPT_NAME,SCRIPT_HASH,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "FEE_CFG",
    "PKColumns": "DISTRICT,BUILDING",
    "TableColumns": "DISTRICT,BUILDING,SCHD_PRO_RATE,PRORATE_LAST_CALC,BILL_STMT_HDR,BILL_STMT_FOOTER,PRORATE_RESOLVES,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "FEE_CFG_PRO_RATE",
    "PKColumns": "DISTRICT,BUILDING,COURSE_WEEKS,ADD_DROP_INDICATOR,SEQUENCE_ORDER",
    "TableColumns": "DISTRICT,BUILDING,COURSE_WEEKS,ADD_DROP_INDICATOR,SEQUENCE_ORDER,NUMBER_OF_DAYS,PERCENT_DISCOUNT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "FEE_CFG_REDUCED",
    "PKColumns": "DISTRICT,BUILDING,FEE_TYPE,SEQUENCE_ORDER",
    "TableColumns": "DISTRICT,BUILDING,FEE_TYPE,SEQUENCE_ORDER,RATE,TABLE_NAME,SCREEN_NUMBER,COLUMN_NAME,FIELD_NUMBER,REDUCED_VALUE,FEE_SUB_CATEGORY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "FEE_GROUP_CRIT",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,FEE_GROUP_CODE,SEQUENCE_NUM",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,FEE_GROUP_CODE,SEQUENCE_NUM,AND_OR_FLAG,TABLE_NAME,SCREEN_TYPE,SCREEN_NUMBER,COLUMN_NAME,FIELD_NUMBER,OPERATOR,SEARCH_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "FEE_GROUP_DET",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,FEE_GROUP_CODE,SEQUENCE_ORDER",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,FEE_GROUP_CODE,SEQUENCE_ORDER,ITEM_CODE,TEXTBOOK_CODE,DESCRIPTION,QUANTITY,UNIT_COST,CAN_PRORATE,STAFF_ID_RESTR,CRS_SECTION_RESTR,COMMENT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "FEE_GROUP_HDR",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,FEE_GROUP_CODE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,FEE_GROUP_CODE,DESCRIPTION,FEE_TYPE,REDUCED_RATE,FREQUENCY,COURSE_OR_ACTIVITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "FEE_ITEM",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,ITEM_CODE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,ITEM_CODE,FEE_TYPE,DESCRIPTION,UNIT_COST,UNIT_DESCR_CODE,PRIORITY,CAN_PRORATE,FEE_CATEGORY,FEE_SUB_CATEGORY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "FEE_STU_AUDIT",
    "PKColumns": "DISTRICT,AUDIT_NUMBER",
    "TableColumns": "DISTRICT,AUDIT_NUMBER,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,STUDENT_ID,DATE_CREATED,TRACKING_NUMBER,ACTION_CODE,PAYMENT_ID,QUANTITY,UNIT_COST,COST_AMOUNT,CREDIT_AMOUNT,COMMENT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "FEE_STU_GROUP",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,FEE_GROUP_CODE,STUDENT_ID",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,FEE_GROUP_CODE,STUDENT_ID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "FEE_STU_ITEM",
    "PKColumns": "DISTRICT,TRACKING_NUMBER",
    "TableColumns": "DISTRICT,TRACKING_NUMBER,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,STUDENT_ID,DATE_CREATED,ITEM_CODE,TRACKING_NUMBER_DISPLAY,TEXTBOOK_CODE,DESCRIPTION,FEE_GROUP_CODE,SEQUENCE_ORDER,QUANTITY,UNIT_COST,UNIT_COST_OVR,TOTAL_PAID,TOTAL_CREDIT_APPLY,TOTAL_REFUND,BALANCE,REFUND_PRT_CHECK,PRORATED_ADD,PRORATED_DROP,PRORATED_RESOLVED,PRORATED_CLEAR,FEE_SUB_CATEGORY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "FEE_STU_PAYMENT",
    "PKColumns": "DISTRICT,PAYMENT_ID",
    "TableColumns": "DISTRICT,PAYMENT_ID,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,STUDENT_ID,PAYMENT_ID_DISPLAY,PAYMENT_DATE,REVERSE_FLAG,PAYMENT_TYPE_CODE,REFERENCE_NUMBER,COMMENT,TOTAL_PAID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "FEE_TEXTBOOK",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,TEXTBOOK_CODE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,TEXTBOOK_CODE,DEPARTMENT,DESCRIPTION,UNIT_COST,ISBN,PUBLISHER,COMMENT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "FEE_TEXTBOOK_CRS",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,TEXTBOOK_CODE,COURSE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,TEXTBOOK_CODE,COURSE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "FEE_TEXTBOOK_TEA",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,TEXTBOOK_CODE,STAFF_ID",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,TEXTBOOK_CODE,STAFF_ID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "FEE_YREND_RUN",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,RUN_KEY",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,RUN_KEY,RUN_DATE,RUN_STATUS,CLEAN_FEE_DATA,BUILDING_LIST,PURGE_FEE_YEAR,PURGE_STU_YEAR,RESTORE_KEY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "FEETB_CATEGORY",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,CODE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,CODE,DESCRIPTION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "FEETB_PAYMENT",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,CODE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,CODE,DESCRIPTION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "FEETB_STU_STATUS",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,CODE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,CODE,DESCRIPTION,THRESHOLD_AMOUNT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "FEETB_SUB_CATEGORY",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,CODE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,CODE,DESCRIPTION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "FEETB_UNIT_DESCR",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,CODE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,CODE,DESCRIPTION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "GDBK_POST_CLS",
    "PKColumns": "DISTRICT,BUILDING,STUDENT_ID,COURSE,COURSE_SECTION,COURSE_SESSION,ABSENCE_DATE,SOURCE",
    "TableColumns": "DISTRICT,BUILDING,STUDENT_ID,COURSE,COURSE_SECTION,COURSE_SESSION,ABSENCE_DATE,ATTENDANCE_CODE,SOURCE,ARRIVE_TIME,DISMISS_TIME,ATT_COMMENT",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "GDBK_POST_DAT",
    "PKColumns": "DISTRICT,BUILDING,STUDENT_ID,ABSENCE_DATE",
    "TableColumns": "DISTRICT,BUILDING,STUDENT_ID,ABSENCE_DATE,ATTENDANCE_CODE,AM_OR_PM,ARRIVE_TIME,DISMISS_TIME,ATT_COMMENT",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "GDBK_POST_IPR_COMM",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,STUDENT_ID,IPR_DATE,COMMENT_TYPE",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,STUDENT_ID,IPR_DATE,COMMENT_TYPE,COMMENT",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "GDBK_POST_IPR_MARK",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,STUDENT_ID,IPR_DATE,MARK_TYPE",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,STUDENT_ID,IPR_DATE,MARK_TYPE,MARK_VALUE",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "GDBK_POST_RC",
    "PKColumns": "DISTRICT,BUILDING,STUDENT_ID,COURSE,COURSE_SECTION,COURSE_SESSION",
    "TableColumns": "DISTRICT,BUILDING,STUDENT_ID,COURSE,COURSE_SECTION,COURSE_SESSION,FINAL_GRADE,MARKING_PERIOD,GRADE1,GRADE2,GRADE3,ABSENCES1,ABSENCES2,ABSENCES3,COMMENT1,COMMENT2,COMMENT4,COMMENT5",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "GDBK_POST_RC_ABS",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,STUDENT_ID,RC_DATE,ABS_TYPE",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,STUDENT_ID,RC_DATE,ABS_TYPE,ABS_VALUE",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "GDBK_POST_RC_COMM",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,STUDENT_ID,RC_DATE,COMMENT_TYPE",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,STUDENT_ID,RC_DATE,COMMENT_TYPE,COMMENT",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "GDBK_POST_RC_MARK",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,STUDENT_ID,RC_DATE,MARK_TYPE",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,STUDENT_ID,RC_DATE,MARK_TYPE,MARK_VALUE",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "HAC_BUILDING_ALERT",
    "PKColumns": "DISTRICT,BUILDING,ALERT_TYPE",
    "TableColumns": "DISTRICT,BUILDING,ALERT_TYPE,SEND_TO_GUARDIANS,SEND_TO_STUDENTS,SEND_TO_TEACHERS,SCHEDULE_TYPE,TASK_OWNER,ALERT_DATE,INCLUDE_PRIOR_DAYS,SCHD_TIME,SCHD_DATE,SCHD_INTERVAL,SCHD_DOW,PARAM_KEY,LAST_RUN_DATE,FROM_EMAIL,SUBJECT_LINE,HEADER_TEXT,FOOTER_TEXT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "HAC_BUILDING_ALERT_MARK_TYPE",
    "PKColumns": "DISTRICT,BUILDING,ALERT_TYPE,AVG_MARK_TYPE",
    "TableColumns": "DISTRICT,BUILDING,ALERT_TYPE,AVG_MARK_TYPE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "HAC_Building_Cfg",
    "PKColumns": "DISTRICT,BUILDING,CONFIG_TYPE",
    "TableColumns": "DISTRICT,BUILDING,CONFIG_TYPE,ENABLE_HAC,BUILDING_LOGO,LOGO_HEADER_COLOR,LOGO_TEXT_COLOR,FIRST_PAGE,SHOW_PERSONAL,UPD_EMAIL,UPD_PHONE,SHOW_EMERGENCY,UPD_EMERGENCY,SHOW_CONTACT,SHOW_FERPA,UPD_FERPA,FERPA_EXPLANATION,SHOW_TRANSPORT,SHOW_SCHEDULE,SHOW_SCHD_GRID,SHOW_DROPPED_CRS,SHOW_REQUESTS,SHOW_ATTENDANCE,SHOW_DISCIPLINE,CURRENT_YEAR_DISC_ONLY,SHOW_ASSIGN,AVG_MARK_TYPE,INC_UNPUB_AVG,SHOW_CLASS_AVG,SHOW_ATTACHMENTS,DEF_CLASSWORK_VIEW,SHOW_IPR,SHOW_RC,SHOW_STU_COMP,SHOW_CRS_COMP,SHOW_LTDB,SHOW_EMAIL,SHOW_TRANSCRIPT,SHOW_CAREER_PLANNER,REQUEST_BY,REQUEST_YEAR,REQUEST_INTERVAL,PREREQ_CHK_REQ,SHOW_SUCCESS_PLAN,SHOW_SENS_PLAN,SHOW_SENS_INT,SHOW_SENS_INT_COMM,UPD_SSP_PARENT_GOAL,UPD_SSP_STUDENT_GOAL,SHOW_HONOR_ROLL_CREDIT,SHOW_HONOR_ROLL_GPA,SHOW_HONOR_MESSAGE,SHOW_REQUEST_ENTRY,MIN_CREDIT_REQ,MAX_CREDIT_REQ,SHOW_RC_ATTENDANCE,RC_HOLD_MESSAGE,SHOW_EO,SHOW_PERFORMANCEPLUS,SHOW_AVG_INHDR,HDR_AVG_MARKTYPE,SHOW_LAST_UPDDT,HDR_SHORT_DESC,AVG_TOOLTIP_DESC,HIDE_PERCENTAGE,HIDE_OVERALL_AVG,HIDE_COMP_SCORE,SHOW_SDE,SHOW_FEES,ENABLE_ONLINE_PAYMENT,SHOW_CALENDAR,AVG_ON_HOME_PAGE,HELP_URL,SHOW_IEP,SHOW_GIFTED,SHOW_504PLAN,SHOW_IEP_INVITATION,SHOW_EVAL_RPT,SHOW_IEP_PROGRESS,IEP_LIVING_WITH_ONLY,SHOW_WEEK_VIEW,SHOW_WEEK_VIEW_DISC,SHOW_WEEK_VIEW_FEES,SHOW_WEEK_VIEW_ATT,SHOW_WEEK_VIEW_CRS,SHOW_WEEK_VIEW_COMP,SHOW_REQUEST_ALTERNATE,AVERAGE_DISPLAY_TYPE,SHOW_RC_PRINT,SHOW_GENDER,SHOW_STUDENT_ID,SHOW_HOMEROOM,SHOW_HOMEROOM_TEACHER,SHOW_COUNSELOR,SHOW_HOUSE_TEAM,SHOW_LOCKER_NO,SHOW_LOCKER_COMBO,CHANGE_DATE_TIME,CHANGE_UID,SHOW_LEARNING_LOCATION,SHOW_MEETING_LINK,SHOW_MANUAL_CHECKIN,SHOW_FILE_UPLOAD,SHOW_STUDENT_SSID,VIEW_ADDITIONAL_EMAIL,UPD_ADDITIONAL_EMAIL",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "HAC_BUILDING_CFG_ATTACHMENT",
    "PKColumns": "DISTRICT,BUILDING,CONFIG_TYPE,UPLOAD_TYPE",
    "TableColumns": "DISTRICT,BUILDING,CONFIG_TYPE,UPLOAD_TYPE,ALLOWABLE_FILE_TYPES,USER_INSTRUCTION,CATEGORY,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID,SORT_ORDER",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "HAC_BUILDING_CFG_AUX",
    "PKColumns": "DISTRICT,BUILDING,CONFIG_TYPE",
    "TableColumns": "DISTRICT,BUILDING,CONFIG_TYPE,DISPLAY_REG_YEAR,DISPLAY_REG_YEAR_SPECIFY,DISPLAY_SUM_YEAR,DISPLAY_SUM_YEAR_SPECIFY,RESTRICT_CALENDAR,CLASSWORK_VIEW,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "HAC_BUILDING_CFG_CONTACTS",
    "PKColumns": "DISTRICT,BUILDING,CONFIG_TYPE",
    "TableColumns": "DISTRICT,BUILDING,CONFIG_TYPE,SHOW_GUARDIANS,SHOW_EMERGENCY,SHOW_OTHER,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "HAC_BUILDING_CFG_DISC",
    "PKColumns": "DISTRICT,BUILDING,CONFIG_TYPE,INCIDENT_CODE",
    "TableColumns": "DISTRICT,BUILDING,CONFIG_TYPE,INCIDENT_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "HAC_BUILDING_CFG_HDR_RRK",
    "PKColumns": "DISTRICT,BUILDING",
    "TableColumns": "DISTRICT,BUILDING,LABEL,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "HAC_BUILDING_CFG_INTER",
    "PKColumns": "DISTRICT,BUILDING,CONFIG_TYPE",
    "TableColumns": "DISTRICT,BUILDING,CONFIG_TYPE,SHOW_INTERVENTION_MARK,SHOW_INTERVENTION_COMMENT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "HAC_BUILDING_CFG_RRK",
    "PKColumns": "DISTRICT,BUILDING,LOGIN_TYPE,SORT_ORDER",
    "TableColumns": "DISTRICT,BUILDING,LOGIN_TYPE,SORT_ORDER,SCREEN_NUMBER,FIELD_NUMBER,FIELD_LABEL,FIELD_ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "HAC_CHALLENGE_QUES",
    "PKColumns": "DISTRICT,CONTACT_ID,SEQ_NBR",
    "TableColumns": "DISTRICT,CONTACT_ID,SEQ_NBR,QUESTION,ANSWER,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "HAC_DIST_CFG_LDAP",
    "PKColumns": "DISTRICT,LDAP_ID",
    "TableColumns": "DISTRICT,LDAP_ID,DISTINGUISHED_NAME,DOMAIN_NAME,SUB_SEARCH,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "HAC_DIST_CFG_ONLINE_PAYMT",
    "PKColumns": "DISTRICT",
    "TableColumns": "DISTRICT,USE_FRONTSTREAM,FRONTSTREAM_URL,PAYMENT_TYPE_CODE,FRONTSTREAM_STATUS_URL,FRONTSTREAM_MERCHANT_TOKEN,POLL_TASK_OWNER,POLL_DAYS,POLL_START_TIME,POLL_END_TIME,POLL_FREQ_MIN,KEEP_LOG_DAYS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "HAC_DIST_CFG_PWD",
    "PKColumns": "DISTRICT",
    "TableColumns": "DISTRICT,USE_ENCRYPTION,HAC_ENCRYPTION_TYPE,PWD_MIN_LIMIT_ENABLED,PWD_MIN_LIMIT,PWD_MAX_LIMIT_ENABLED,PWD_MAX_LIMIT,PWD_COMP_RULE,PWD_CHNG_REQ,PWD_CHNG_REQ_ENABLED,PWD_LK_ACC,PWD_LK_ACC_MODE,PWD_LOCK_TOL_AUTO_TIMES,PWD_LOCK_TOL_AUTO_DUR,PWD_LOCK_TOL_AUTO_TIMES_HOLD,PWD_LOCK_TOL_AUTO_TIMES_LIMIT,PWD_LOCK_TOL_AUTO_TIMES_LIM_DUR,PWD_LOCK_TOL_MAN_ATTEMPT,PWD_LOCK_TOL_MAN_TIMES,PWD_LOCK_TOL_MAN_DUR,CHALLENGE_NO_QUESTIONS,CHALLENGE_ANSWER_QUESTIONS,PWD_UNSUCCESS_MSG,CONFIRMATION_MESSAGE,EMAIL_MESSAGE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "HAC_District_Cfg",
    "PKColumns": "DISTRICT,CONFIG_TYPE",
    "TableColumns": "DISTRICT,CONFIG_TYPE,ENABLE_HAC,ENABLE_HAC_TRANSLATION,HAC_TRANS_LANGUAGE,DISTRICT_LOGO,ALLOW_REG,REGISTER_STMT,CHANGE_PASSWORDS,PRIVACY_STMT,TERMS_OF_USE_STMT,LOGIN_VAL,SHOW_USERVOICE,LOGO_HEADER_COLOR,LOGO_TEXT_COLOR,HELP_URL,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "HAC_FAILED_LOGIN_ATTEMPTS",
    "PKColumns": "DISTRICT,CONTACT_ID,FAILURE_DATE_TIME",
    "TableColumns": "DISTRICT,CONTACT_ID,FAILURE_DATE_TIME,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "HAC_LINK",
    "PKColumns": "DISTRICT,BUILDING,LOGIN_TYPE,SORT_ORDER",
    "TableColumns": "DISTRICT,BUILDING,LOGIN_TYPE,SORT_ORDER,LINK_URL,LINK_DESCRIPTION,NEW_UNTIL,SHOW_IN,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "HAC_LINK_MACRO",
    "PKColumns": "DISTRICT,BUILDING,MACRO_NAME",
    "TableColumns": "DISTRICT,BUILDING,MACRO_NAME,MACRO_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "HAC_MENU_LINKED_PAGES",
    "PKColumns": "DISTRICT,PARENT_CODE,CODE",
    "TableColumns": "DISTRICT,PARENT_CODE,CODE,DESCRIPTION,RESERVED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "HAC_MENULIST",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,RESERVED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "HAC_OLD_USER",
    "PKColumns": "DISTRICT,STUDENT_ID,OLD_PASSWORD",
    "TableColumns": "DISTRICT,STUDENT_ID,OLD_PASSWORD,CONTACT_ID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "HAC_ONLINE_PAYMENT",
    "PKColumns": "DISTRICT,PAYMENT_ID",
    "TableColumns": "DISTRICT,PAYMENT_ID,LOGIN_ID,STUDENT_ID,BUILDING,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "HAC_TRANSLATION",
    "PKColumns": "DISTRICT,LANG,PAGE,CONTROL_ID",
    "TableColumns": "DISTRICT,LANG,PAGE,CONTROL_ID,ROW_NUM,TEXT_TRANSLATION,RESERVED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "IEP_STUDENT_FILES",
    "PKColumns": "DISTRICT,STUDENT_ID,FILE_TYPE",
    "TableColumns": "DISTRICT,STUDENT_ID,FILE_TYPE,FILE_NAME",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "LSM_CFASSOCIATIONS",
    "PKColumns": "DISTRICT,IDENTIFIER,ORIGIN_IDENTIFIER,DESTINATION_IDENTIFIER",
    "TableColumns": "DISTRICT,IDENTIFIER,ORIGIN_IDENTIFIER,DESTINATION_IDENTIFIER,ASSOCIATION_TYPE,CHANGE_DATE_TIME,CHANGE_UID,DOCUMENT_IDENTIFIER,SEQUENCE_NUM",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "LSM_CFDOCUMENTS",
    "PKColumns": "DISTRICT,IDENTIFIER",
    "TableColumns": "DISTRICT,IDENTIFIER,TITLE,SUBJECT,HUMAN_CODING_SCHEME,STATUS,CHANGE_DATE_TIME,CHANGE_UID,CREATOR,FROM_ESP",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "LSM_CFITEMS",
    "PKColumns": "DISTRICT,IDENTIFIER",
    "TableColumns": "DISTRICT,IDENTIFIER,PARENT_IDENTIFIER,ITEM_TYPE,HUMAN_CODING_SCHEME,LIST_ENUMERATION,GRADE_LEVEL,FULL_STATEMENT,ABBREV_STATEMENT,STATUS,CHANGE_DATE_TIME,CHANGE_UID,SUBJECT",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "LTDB_DASHBOARD",
    "PKColumns": "DISTRICT,TEST_CODE,TEST_LEVEL,TEST_FORM,TEST_DATE,SUBTEST,SCORE_CODE",
    "TableColumns": "DISTRICT,TEST_CODE,TEST_LEVEL,TEST_FORM,TEST_KEY,TEST_DATE,SUBTEST,SCORE_CODE,SCORE_TOTAL,NUMBER_SCORES,RANGE1_COUNT,RANGE2_COUNT,RANGE3_COUNT",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "ltdb_group_det",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,GROUP_CODE,SECTION_KEY",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,GROUP_CODE,SECTION_KEY,MARKING_PERIOD,MARK_TYPE,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "ltdb_group_hdr",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,GROUP_CODE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,GROUP_CODE,DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "LTDB_IMPORT_DEF",
    "PKColumns": "district,interface_id",
    "TableColumns": "district,interface_id,description,change_date_time,change_uid",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "LTDB_IMPORT_DET",
    "PKColumns": "DISTRICT,INTERFACE_ID,TEST_KEY,FIELD_ID",
    "TableColumns": "DISTRICT,INTERFACE_ID,TEST_CODE,TEST_LEVEL,TEST_FORM,TEST_KEY,FIELD_ID,FIELD_ORDER,TABLE_NAME,COLUMN_NAME,SUBTEST,SCORE_CODE,FORMAT_STRING,START_POSITION,END_POSITION,MAP_FIELD,MAP_SCORE,FIELD_LENGTH,VALIDATION_TABLE,CODE_COLUMN,VALIDATION_LIST,ERROR_MESSAGE,EXTERNAL_TABLE,EXTERNAL_COL_IN,EXTERNAL_COL_OUT,LITERAL,SKIP_BLANK_VALUES,SKIP_SPECIFIC_VALUES,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "LTDB_IMPORT_HDR",
    "PKColumns": "district,interface_id,test_key",
    "TableColumns": "district,interface_id,description,test_code,test_level,test_form,test_key,filename,last_run_date,delimit_char,additional_sql,change_date_time,change_uid",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "LTDB_IMPORT_TRN",
    "PKColumns": "district,interface_id,test_key,field_id,translation_id",
    "TableColumns": "district,interface_id,description,test_code,test_level,test_form,test_key,field_id,translation_id,old_value,new_value,change_date_time,change_uid",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "LTDB_INTERFACE_DEF",
    "PKColumns": "DISTRICT,INTERFACE_ID",
    "TableColumns": "DISTRICT,INTERFACE_ID,DESCRIPTION,UPLOAD_DOWNLOAD,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "LTDB_INTERFACE_DET",
    "PKColumns": "DISTRICT,INTERFACE_ID,HEADER_ID,FIELD_ID",
    "TableColumns": "DISTRICT,INTERFACE_ID,HEADER_ID,FIELD_ID,FIELD_ORDER,TABLE_NAME,TABLE_ALIAS,COLUMN_NAME,SCREEN_TYPE,SCREEN_NUMBER,FORMAT_STRING,START_POSITION,END_POSITION,FIELD_LENGTH,VALIDATION_TABLE,CODE_COLUMN,VALIDATION_LIST,ERROR_MESSAGE,EXTERNAL_TABLE,EXTERNAL_COL_IN,EXTERNAL_COL_OUT,LITERAL,COLUMN_OVERRIDE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "LTDB_INTERFACE_HDR",
    "PKColumns": "DISTRICT,INTERFACE_ID,HEADER_ID",
    "TableColumns": "DISTRICT,INTERFACE_ID,HEADER_ID,HEADER_ORDER,DESCRIPTION,FILENAME,LAST_RUN_DATE,DELIMIT_CHAR,USE_CHANGE_FLAG,TABLE_AFFECTED,ADDITIONAL_SQL,COLUMN_HEADERS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "LTDB_INTERFACE_STU",
    "PKColumns": "DISTRICT,INTERFACE_ID,STUDENT_ID",
    "TableColumns": "DISTRICT,INTERFACE_ID,STUDENT_ID,DATE_ADDED,DATE_DELETED,DATE_CHANGED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "LTDB_INTERFACE_TRN",
    "PKColumns": "DISTRICT,INTERFACE_ID,HEADER_ID,FIELD_ID,TRANSLATION_ID",
    "TableColumns": "DISTRICT,INTERFACE_ID,HEADER_ID,FIELD_ID,TRANSLATION_ID,OLD_VALUE,NEW_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "LTDB_SCORE_HAC",
    "PKColumns": "DISTRICT,TEST_CODE,TEST_LEVEL,TEST_FORM,SUBTEST,SCORE_CODE",
    "TableColumns": "DISTRICT,TEST_CODE,TEST_LEVEL,TEST_FORM,TEST_KEY,SUBTEST,SCORE_CODE,DISPLAY_PARENT,DISPLAY_STUDENT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "LTDB_STU_AT_RISK",
    "PKColumns": "DISTRICT,TEST_CODE,TEST_LEVEL,TEST_FORM,STUDENT_ID,TEST_DATE,SUBTEST,SCORE_CODE",
    "TableColumns": "DISTRICT,TEST_CODE,TEST_LEVEL,TEST_FORM,TEST_KEY,STUDENT_ID,TEST_DATE,SUBTEST,SCORE_CODE,SCORE,QUALIFICATION,QUAL_REASON,TEST_CODE2,TEST_LEVEL2,TEST_FORM2,TEST_KEY2,TEST_DATE2,SUBTEST2,SCORE_CODE2,SCORE2,BUILDING,GRADE,AT_RISK,START_DATE,END_DATE,PLAN_NUM,PLAN_DATE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "LTDB_STU_SUBTEST",
    "PKColumns": "DISTRICT,TEST_CODE,TEST_LEVEL,TEST_FORM,STUDENT_ID,TEST_DATE,SUBTEST,SCORE_CODE",
    "TableColumns": "DISTRICT,TEST_CODE,TEST_LEVEL,TEST_FORM,TEST_KEY,STUDENT_ID,TEST_DATE,SUBTEST,SCORE_CODE,SCORE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "LTDB_STU_TEST",
    "PKColumns": "DISTRICT,TEST_CODE,TEST_LEVEL,TEST_FORM,STUDENT_ID,TEST_DATE",
    "TableColumns": "DISTRICT,TEST_CODE,TEST_LEVEL,TEST_FORM,TEST_KEY,STUDENT_ID,TEST_DATE,TRANSCRIPT_PRINT,BUILDING,GRADE,AGE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "LTDB_STU_TRACKING",
    "PKColumns": "DISTRICT,TEST_CODE,TEST_LEVEL,TEST_FORM,FIELD_NUMBER",
    "TableColumns": "DISTRICT,TEST_CODE,TEST_LEVEL,TEST_FORM,TEST_KEY,FIELD_NUMBER,FIELD_ORDER,SOURCE,PROGRAM_FIELD,EXTERNAL_CODE,FIELD_LABEL,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "LTDB_STU_TRK_DATA",
    "PKColumns": "DISTRICT,TEST_CODE,TEST_LEVEL,TEST_FORM,STUDENT_ID,TEST_DATE,FIELD_NUMBER",
    "TableColumns": "DISTRICT,TEST_CODE,TEST_LEVEL,TEST_FORM,TEST_KEY,STUDENT_ID,TEST_DATE,FIELD_NUMBER,FIELD_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "LTDB_SUBTEST",
    "PKColumns": "DISTRICT,TEST_CODE,TEST_LEVEL,TEST_FORM,SUBTEST",
    "TableColumns": "DISTRICT,TEST_CODE,TEST_LEVEL,TEST_FORM,TEST_KEY,SUBTEST,DESCRIPTION,SUBTEST_ORDER,DISPLAY,STATE_CODE_EQUIV,PESC_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "LTDB_SUBTEST_HAC",
    "PKColumns": "DISTRICT,TEST_CODE,TEST_LEVEL,TEST_FORM,SUBTEST",
    "TableColumns": "DISTRICT,TEST_CODE,TEST_LEVEL,TEST_FORM,TEST_KEY,SUBTEST,DISPLAY_PARENT,DISPLAY_STUDENT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "LTDB_SUBTEST_SCORE",
    "PKColumns": "DISTRICT,TEST_CODE,TEST_LEVEL,TEST_FORM,SUBTEST,SCORE_CODE",
    "TableColumns": "DISTRICT,TEST_CODE,TEST_LEVEL,TEST_FORM,TEST_KEY,SUBTEST,SCORE_CODE,SCORE_ORDER,SCORE_LABEL,REQUIRED,FIELD_TYPE,DATA_TYPE,NUMBER_TYPE,DATA_LENGTH,FIELD_SCALE,FIELD_PRECISION,DEFAULT_VALUE,VALIDATION_LIST,VALIDATION_TABLE,CODE_COLUMN,DESCRIPTION_COLUMN,DISPLAY,INCLUDE_DASHBOARD,MONTHS_TO_INCLUDE,RANGE1_HIGH_LIMIT,RANGE2_HIGH_LIMIT,STATE_CODE_EQUIV,SCORE_TYPE,PERFPLUS_GROUP,PESC_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "LTDB_TEST",
    "PKColumns": "DISTRICT,TEST_CODE,TEST_LEVEL,TEST_FORM",
    "TableColumns": "DISTRICT,TEST_CODE,TEST_LEVEL,TEST_FORM,TEST_KEY,DESCRIPTION,DISPLAY,SEC_PACKAGE,SEC_SUBPACKAGE,SEC_FEATURE,TEACHER_DISPLAY,SUB_DISPLAY,INCLUDE_PERFPLUS,PESC_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "LTDB_TEST_BUILDING",
    "PKColumns": "DISTRICT,TEST_CODE,TEST_LEVEL,TEST_FORM,BUILDING",
    "TableColumns": "DISTRICT,TEST_CODE,TEST_LEVEL,TEST_FORM,TEST_KEY,BUILDING,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "LTDB_TEST_HAC",
    "PKColumns": "DISTRICT,TEST_CODE,TEST_LEVEL,TEST_FORM",
    "TableColumns": "DISTRICT,TEST_CODE,TEST_LEVEL,TEST_FORM,TEST_KEY,DISPLAY_PARENT,DISPLAY_STUDENT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "LTDB_TEST_TRACKING",
    "PKColumns": "DISTRICT,TEST_CODE,TEST_LEVEL,TEST_FORM,FIELD_NUMBER",
    "TableColumns": "DISTRICT,TEST_CODE,TEST_LEVEL,TEST_FORM,TEST_KEY,FIELD_NUMBER,FIELD_ORDER,FIELD_LABEL,FIELD_DATA,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "LTDB_USER_TEST",
    "PKColumns": "DISTRICT,TEST_CODE,TEST_LEVEL,TEST_FORM,SCREEN_NUMBER,FIELD_NUMBER,LIST_SEQUENCE",
    "TableColumns": "DISTRICT,TEST_CODE,TEST_LEVEL,TEST_FORM,TEST_KEY,SCREEN_NUMBER,FIELD_NUMBER,LIST_SEQUENCE,FIELD_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "LTDB_VIEW_DET",
    "PKColumns": "DISTRICT,VIEW_CODE,TEST_CODE,TEST_LEVEL,TEST_FORM,TEST_KEY,SUBTEST,SCORE_CODE",
    "TableColumns": "DISTRICT,VIEW_CODE,TEST_CODE,TEST_LEVEL,TEST_FORM,TEST_KEY,SUBTEST,SCORE_CODE,SCORE_ORDER,SCORE_LABEL,SCORE_SELECT,RANGE1_HIGH_LIMIT,RANGE2_HIGH_LIMIT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "LTDB_VIEW_HDR",
    "PKColumns": "DISTRICT,VIEW_CODE",
    "TableColumns": "DISTRICT,VIEW_CODE,DESCRIPTION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "LTDB_YEAREND_RUN",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,RUN_KEY",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,RUN_KEY,RUN_DATE,RUN_STATUS,CLEAN_LTDB_DATA,PURGE_STU_YEAR,RESTORE_KEY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "LTDBTB_SCORE_PESC_CODE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "LTDBTB_SCORE_TYPE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "LTDBTB_SUBTEST_PESC_CODE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "LTDBTB_TEST_PESC_CODE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "LTI_CLIENT",
    "PKColumns": "DISTRICT,CLIENT_CODE",
    "TableColumns": "DISTRICT,CLIENT_CODE,CHANGE_DATE_TIME,CHANGE_UID,DESCRIPTION,ACTIVE",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "LTI_CLIENT_TOOL",
    "PKColumns": "DISTRICT,CLIENT_CODE,TOOL_ID",
    "TableColumns": "DISTRICT,CLIENT_CODE,TOOL_ID,CHANGE_DATE_TIME,CHANGE_UID,ACTIVE",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "LTI_NONCE_LOG",
    "PKColumns": "ID",
    "TableColumns": "ID,CONSUMER_KEY,NONCE,CHANGE_DATE_TIME",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "LTI_TOOL",
    "PKColumns": "DISTRICT,TOOL_ID",
    "TableColumns": "DISTRICT,TOOL_ID,CHANGE_DATE_TIME,CHANGE_UID,DESCRIPTION,API_SCOPE,APP_URL",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MD_ATTENDANCE_DOWN",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUBMISSION_NUMBER,Building,Student_ID",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUBMISSION_NUMBER,Building,State_Report_ID,Student_ID,Last_Name,First_Name,Middle_Initial,Generation_Suffix,Date_Birth,Grade,Gender,New_Ethnicity,New_Race,SSN,Title_1,Free_Reduced_Lunch,Migrant,Foreign_Exchange_Student,Special_Education,Special_Ed_End_Date,Special_Ed_Certificate,ELL,ELL_Begin_Date,ELL_End_Date,Submission_Date,Entry_Status,Entry_Code,Entry_Date,Days_Attending,Days_Absent,Days_Not_Belonging,Withdrawal_Status,Withdrawal_Code,Withdrawal_Date,Promotion_Code,TAS,Homeless,Homeless_Primary_Nighttime_Residence,Homeless_Served_Mckinney,Homeless_Served_Other,Homeless_Unaccompanied_Youth_Status,Immigrant,PREK_FULL_STATUS,STATE_AID_ELIG,EH_STUDENT,EH_NUM_COURSES,PT_STUDENT,PT_NUM_COURSES,OPT_OUT,OVERRIDE_DOWNLOAD,RECORD_EDITED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MD_LEVEL_MARKS",
    "PKColumns": "DISTRICT,BUILDING,MARK",
    "TableColumns": "DISTRICT,BUILDING,MARK,PERCENT_MINIMUM,PERCENT_MAXIMUM,COMPLETION_STATUS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MD_PROCESS_SECTION",
    "PKColumns": "RUN_ID,SECTION_KEY",
    "TableColumns": "RUN_ID,SECTION_KEY",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "MD_PROCESS_STUDENT",
    "PKColumns": "RUN_ID,STUDENT_ID",
    "TableColumns": "RUN_ID,STUDENT_ID",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "MD_RUN",
    "PKColumns": "RUN_ID",
    "TableColumns": "RUN_ID,TASK_ID,LOGIN_ID,SCHOOL_YEAR,START_DATE,END_DATE,RUN_TYPE,SUBMISSION_NUMBER,BUILDINGS,CUSTOM_TASK_NAME,DEBUG,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MD_SCGT_BLDG_ATT_VIEW_TYPE",
    "PKColumns": "DISTRICT,BUILDING,VIEW_TYPE",
    "TableColumns": "DISTRICT,BUILDING,VIEW_TYPE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MD_SCGT_BLDG_CFG",
    "PKColumns": "DISTRICT,BUILDING",
    "TableColumns": "DISTRICT,BUILDING,LEVEL_NUMBER,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MD_SCGT_BLDG_MARK_TYPE",
    "PKColumns": "DISTRICT,BUILDING,MARK_TYPE",
    "TableColumns": "DISTRICT,BUILDING,MARK_TYPE,MARK_ORDER,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MD_SCGT_DOWN",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,SCHOOL_YEAR,SUBMISSION_NUMBER,STUDENT_ID,SUBMISSION_DATE",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,SCHOOL_YEAR,SUBMISSION_NUMBER,STUDENT_ID,SCHOOL_NUMBER,SUBMISSION_DATE,COURSE_CODE,COURSE_TITLE,SECTION_NUMBER,SECTION_TITLE,CLASS_PERIOD,COURSE_BEGIN_DATE,COURSE_END_DATE,MSDE_SUBJECT_CODE,CATALOGUE_COURSE_CREDITS,STATEWIDE_IDENTIFIER,LOCAL_STUDENT_ID,STUDENT_SSN,STUDENT_LAST_NAME,STUDENT_FIRST_NAME,STUDENT_MIDDLE_NAME,STUDENT_GENERATIONAL_SUFFIX,STUDENT_BIRTH_DATE,STUDENT_GRADE,STUDENT_GENDER,STUDENT_HISPANIC,STUDENT_RACE,TITLE1,TAS,FARMS,SPEC_ED_504,LIMITED_ENGLISH_PROFICIENCY,COURSE_CREDITS_EARNED,COMPLETION_STATUS,COURSE_DAYS_ABSENT,COURSE_SEMESTER_TERM,COURSE_GRADE_ALPHA,COURSE_GRADE_PERCENT_MINIMUM,COURSE_GRADE_PERCENT_MAXIMUM,GRADE_POINT_EQUIVALENT,INSTRUCTION_OUTSIDE_SCHOOL,AP_HONORS,INTERNATIONAL_BACCALAUREATE,HSA_PRE_REQ,READING_MATH_CLASS,MULTIPLE_TEACHER_COURSE,TEACHER_STATE_ID,TEACHER_LOCAL_ID,TEACHER_LAST_NAME,TEACHER_FIRST_NAME,TEACHER_MIDDLE_NAME,TEACHER_GENERATIONAL_SUFFIX,TEACHER_MAIDEN_LAST_NAME,TEACHER_BIRTH_DATE,TEACHER_GENDER,TEACHER_RACE,TEACHER_HISPANIC,TEACHER_SSN,SECONDARY_TEACHER_STATE_ID,SECONDARY_TEACHER_LOCAL_ID,SECONDARY_TEACHER_LAST_NAME,SECONDARY_TEACHER_FIRST_NAME,SECONDARY_TEACHER_MIDDLE_NAME,SECONDARY_TEACHER_GENERATION,SECONDARY_TEACHER_MAIDEN_NAME,SECONDARY_TEACHER_BIRTHDATE,SECONDARY_TEACHER_GENDER,SECONDARY_TEACHER_SSN,TERTIARY_TEACHER_STATE_ID,TERTIARY_TEACHER_LOCAL_ID,TERTIARY_TEACHER_LAST_NAME,TERTIARY_TEACHER_FIRST_NAME,TERTIARY_TEACHER_MIDDLE_NAME,TERTIARY_TEACHER_GENERATION,TERTIARY_TEACHER_MAIDEN_NAME,TERTIARY_TEACHER_BIRTHDATE,TERTIARY_TEACHER_GENDER,TERTIARY_TEACHER_SSN,OVERRIDE_DOWNLOAD,RECORD_EDITED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MDTB_CLASS_OF_RECORD",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MDTB_COURSE_COMPLETION_STATUS",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MDTB_CRS_PLACEMENT",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MDTB_HSA_SUBJECT",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MED_CFG",
    "PKColumns": "DISTRICT,BUILDING",
    "TableColumns": "DISTRICT,BUILDING,AUTO_CREATE,CALL_MAINT,RESET_COUNT,PRT_LTR_MER_FILE,OTHER_LANGUAGE,USER_SCREEN,MED_SCREEN,USE_MONTH_YEAR,USE_WARNING_STATUS,PRIOR_DAYS_UPDATE,ALLOW_NOTES_UPDATE,EXAM_PRI_DAYS_UPD,USE_LAST,NOTIFY_DWNLD_PATH,EMAIL_OPTION,RETURN_EMAIL,USE_HOME_ROOM,USE_OUTCOME,VALID_NURSE_INIT,INIT_OTH_NURSE_LOG,USE_VALIDATE_SAVE,DEFAULT_TO_SAVE,USE_IMMUN_ALERTS,IMM_GRACE_PERIOD,GRACE_ENTRY_DATE,CLEAR_EXP_DATE,IMM_PARENT_ALERTS,IMM_INT_EMAILS,SUBJECT_LINE,FROM_EMAIL,HEADER_TEXT,FOOTER_TEXT,DEFAULT_MARGIN_ERR,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MED_CFG_LANG",
    "PKColumns": "DISTRICT,BUILDING,LANGUAGE_CODE",
    "TableColumns": "DISTRICT,BUILDING,LANGUAGE_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MED_CUSTOM_EXAM_COLUMN",
    "PKColumns": "COLUMN_ID",
    "TableColumns": "COLUMN_ID,EXAM_TYPE_ID,COLUMN_NAME,COLUMN_ORDER,IS_BASE",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "MED_CUSTOM_EXAM_ELEMENT",
    "PKColumns": "FIELD_ID",
    "TableColumns": "FIELD_ID,DISTRICT,EXAM_ID,COLUMN_ID,COLUMN_VALUE",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "MED_CUSTOM_EXAM_KEY",
    "PKColumns": "EXAM_ID",
    "TableColumns": "EXAM_ID,DISTRICT,STUDENT_ID,EXAM_TYPE_ID,TEST_DATE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MED_CUSTOM_EXAM_TYPE",
    "PKColumns": "EXAM_TYPE_ID",
    "TableColumns": "EXAM_TYPE_ID,EXAM_SYMBOL,DESCRIPTION",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "MED_DENTAL",
    "PKColumns": "DISTRICT,STUDENT_ID,TEST_DATE",
    "TableColumns": "DISTRICT,STUDENT_ID,TEST_DATE,GRADE,LOCATION,STATUS,INITIALS,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MED_DENTAL_COLS",
    "PKColumns": "DISTRICT,STUDENT_ID,TEST_DATE",
    "TableColumns": "DISTRICT,STUDENT_ID,TEST_DATE,DENTAL_SEALANTS,CARIES_EXP,UNTREATED_CARIES,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MED_DISTRICT_CFG",
    "PKColumns": "DISTRICT",
    "TableColumns": "DISTRICT,USE_GRACE_PERIOD,YEAR_START_DATE,USE_REG_DATE,GRACE_PROC_TYPE,GRACE_CALENDAR,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MED_GENERAL",
    "PKColumns": "DISTRICT,STUDENT_ID",
    "TableColumns": "DISTRICT,STUDENT_ID,IMMUNE_STATUS,IMMUNE_EXEMPT,CALC_DATE,OVERRIDE,GROUP_CODE,GRACE_PERIOD_DATE,COMMENT,IMM_ALERT,ALERT_END_DATE,ALERT_OVERRIDE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MED_GRACE_SCHD",
    "PKColumns": "DISTRICT,SERIES_SCHD,YEAR_IN_DISTRICT,UP_TO_DAY",
    "TableColumns": "DISTRICT,SERIES_SCHD,YEAR_IN_DISTRICT,UP_TO_DAY,MIN_DOSES,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MED_GROWTH",
    "PKColumns": "DISTRICT,STUDENT_ID,TEST_DATE",
    "TableColumns": "DISTRICT,STUDENT_ID,TEST_DATE,GRADE,LOCATION,HEIGHT,PERCENT_HEIGHT,WEIGHT,PERCENT_WEIGHT,BMI,PERCENT_BMI,AN_READING,BLOOD_PRESSURE_DIA,BLOOD_PRESSURE_SYS_AN,BLOOD_PRESSURE_DIA_AN,BLOOD_PRESSURE_SYS,INITIALS,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MED_GROWTH_ARK",
    "PKColumns": "DISTRICT,STUDENT_ID,TEST_DATE",
    "TableColumns": "DISTRICT,STUDENT_ID,TEST_DATE,REASON_NOT_ACCESSED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MED_GROWTH_BMI_ARK",
    "PKColumns": "DISTRICT,STUDENT_ID,TEST_DATE",
    "TableColumns": "DISTRICT,STUDENT_ID,TEST_DATE,BMI,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MED_HEARING",
    "PKColumns": "DISTRICT,STUDENT_ID,TEST_DATE",
    "TableColumns": "DISTRICT,STUDENT_ID,TEST_DATE,GRADE,LOCATION,RIGHT_EAR,LEFT_EAR,INITIALS,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MED_HEARING_COLS",
    "PKColumns": "DISTRICT,STUDENT_ID,TEST_DATE",
    "TableColumns": "DISTRICT,STUDENT_ID,TEST_DATE,SCREENING_TYPE,KNOWN_CASE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MED_HEARING_DET",
    "PKColumns": "DISTRICT,STUDENT_ID,TEST_DATE,DECIBEL,FREQUENCY",
    "TableColumns": "DISTRICT,STUDENT_ID,TEST_DATE,DECIBEL,FREQUENCY,RIGHT_EAR,LEFT_EAR,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MED_IMM_CRIT",
    "PKColumns": "DISTRICT,CRITERIA_NUMBER",
    "TableColumns": "DISTRICT,CRITERIA_NUMBER,DESCRIPTION,MAX_LETTERS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MED_IMM_CRIT_GRP",
    "PKColumns": "DISTRICT,CRITERIA_NUMBER,SEQUENCE_NUM",
    "TableColumns": "DISTRICT,CRITERIA_NUMBER,SEQUENCE_NUM,GROUP_TYPE,GROUP_MIN,GROUP_MAX,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "med_imm_crit_grp_SD091114",
    "PKColumns": "",
    "TableColumns": "DISTRICT,CRITERIA_NUMBER,SEQUENCE_NUM,GROUP_TYPE,GROUP_MIN,GROUP_MAX,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "med_imm_crit_SD091114",
    "PKColumns": "",
    "TableColumns": "DISTRICT,CRITERIA_NUMBER,DESCRIPTION,MAX_LETTERS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MED_IMM_CRIT_SHOTS",
    "PKColumns": "DISTRICT,CRITERIA_NUMBER,SERIES_CODE,SERIES_CODE_ORDER",
    "TableColumns": "DISTRICT,CRITERIA_NUMBER,SERIES_CODE,SERIES_CODE_ORDER,SERIES_SCHEDULE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "med_imm_crit_shots_SD091114",
    "PKColumns": "",
    "TableColumns": "DISTRICT,CRITERIA_NUMBER,SERIES_CODE,SERIES_CODE_ORDER,SERIES_SCHEDULE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MED_ISSUED",
    "PKColumns": "DISTRICT,STUDENT_ID,ISSUED,MED_CODE,DOSE_NUMBER",
    "TableColumns": "DISTRICT,STUDENT_ID,ISSUED,MED_CODE,DOSE_NUMBER,EVENT_TYPE,COMMENT,INITIALS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MED_NOTES",
    "PKColumns": "DISTRICT,STUDENT_ID,EVENT_TYPE,EVENT_DATE",
    "TableColumns": "DISTRICT,STUDENT_ID,EVENT_TYPE,EVENT_DATE,NOTE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MED_OFFICE",
    "PKColumns": "DISTRICT,STUDENT_ID,OFFICE_DATE_IN",
    "TableColumns": "DISTRICT,STUDENT_ID,OFFICE_DATE_IN,OFFICE_DATE_OUT,ROOM_ID,COMMENT,INITIALS,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MED_OFFICE_DET",
    "PKColumns": "DISTRICT,STUDENT_ID,OFFICE_DATE_IN,SEQUENCE_NUM",
    "TableColumns": "DISTRICT,STUDENT_ID,OFFICE_DATE_IN,SEQUENCE_NUM,VISIT_REASON,TREATMENT_CODE,OUTCOME,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MED_OFFICE_SCHD",
    "PKColumns": "DISTRICT,STUDENT_ID,START_DATE,END_DATE,SCHEDULED_TIME,SEQUENCE_NUMBER",
    "TableColumns": "DISTRICT,STUDENT_ID,START_DATE,END_DATE,SCHEDULED_TIME,SEQUENCE_NUMBER,VISIT_REASON,TREATMENT_CODE,OUTCOME,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MED_PHYSICAL",
    "PKColumns": "DISTRICT,STUDENT_ID,TEST_DATE",
    "TableColumns": "DISTRICT,STUDENT_ID,TEST_DATE,GRADE,LOCATION,PULSE,BLOOD_PRESSURE_SYS,BLOOD_PRESSURE_DIA,ATHLETIC_STATUS,CLEARED_STATUS,INITIALS,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MED_PHYSICAL_EXAM",
    "PKColumns": "DISTRICT,STUDENT_ID,TEST_DATE,TEST_TYPE",
    "TableColumns": "DISTRICT,STUDENT_ID,TEST_DATE,TEST_TYPE,TEST_RESULT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MED_REFERRAL",
    "PKColumns": "DISTRICT,STUDENT_ID,TEST_TYPE,TEST_DATE,SEQUENCE_NUMBER",
    "TableColumns": "DISTRICT,STUDENT_ID,TEST_TYPE,TEST_DATE,SEQUENCE_NUMBER,REFERRAL_CODE,REFERRAL_DATE,FOLLOW_UP_CODE,FOLLOW_UP_DATE,DOCTOR_NAME,COMMENT,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MED_REQUIRED",
    "PKColumns": "DISTRICT,STUDENT_ID,MED_CODE,START_DATE,DOSE_NUMBER",
    "TableColumns": "DISTRICT,STUDENT_ID,MED_CODE,START_DATE,END_DATE,DOSE_NUMBER,DOSE_TIME,PHYSICIAN_NAME,DOSE_COMMENT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MED_SCOLIOSIS",
    "PKColumns": "DISTRICT,STUDENT_ID,TEST_DATE",
    "TableColumns": "DISTRICT,STUDENT_ID,TEST_DATE,GRADE,LOCATION,STATUS,INITIALS,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MED_SCREENING",
    "PKColumns": "DISTRICT,STUDENT_ID,EXAM_CODE,TEST_DATE",
    "TableColumns": "DISTRICT,STUDENT_ID,EXAM_CODE,TEST_DATE,GRADE,LOCATION,STATUS,INITIALS,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MED_SERIES",
    "PKColumns": "DISTRICT,STUDENT_ID,SERIES_CODE",
    "TableColumns": "DISTRICT,STUDENT_ID,SERIES_CODE,SERIES_EXEMPTION,TOTAL_DOSES,SERIES_STATUS,CALC_DATE,OVERRIDE,COMMENT,NUMBER_LETTERS,HAD_DISEASE,DISEASE_DATE,CHANGE_DATE_TIME,CHANGE_UID,NUMBER_NOTIFICATIONS",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MED_SERIES_DET",
    "PKColumns": "DISTRICT,STUDENT_ID,SERIES_CODE,SERIES_DATE",
    "TableColumns": "DISTRICT,STUDENT_ID,SERIES_CODE,SERIES_DATE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MED_SERIES_SCHD_BOOSTER",
    "PKColumns": "DISTRICT,SERIES_SCHEDULE,BOOSTER_NUMBER,SHOT_TYPE",
    "TableColumns": "DISTRICT,SERIES_SCHEDULE,BOOSTER_NUMBER,SHOT_TYPE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MED_SERIES_SCHD_HDR",
    "PKColumns": "DISTRICT,SERIES_SCHEDULE",
    "TableColumns": "DISTRICT,SERIES_SCHEDULE,EXPIRES_AFTER,EXPIRES_UNITS,EXPIRES_CODE,NUM_REQUIRED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "med_series_schd_hdr_SD091114",
    "PKColumns": "",
    "TableColumns": "DISTRICT,SERIES_SCHEDULE,EXPIRES_AFTER,EXPIRES_UNITS,EXPIRES_CODE,NUM_REQUIRED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MED_SERIES_SCHD_TYPES",
    "PKColumns": "DISTRICT,SERIES_SCHEDULE,SHOT_TYPE",
    "TableColumns": "DISTRICT,SERIES_SCHEDULE,SHOT_TYPE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MED_SERIES_SCHED",
    "PKColumns": "DISTRICT,SERIES_SCHEDULE,DOSE_NUMBER",
    "TableColumns": "DISTRICT,SERIES_SCHEDULE,DOSE_NUMBER,DESCRIPTION,SERIES_CODE,EVENT_DOSE,TIME_EVENTS,TIME_EVENTS_UNITS,OVERDUE_MS,OVERDUE_MS_UNITS,TIME_BIRTH,UNITS_TIME_BIRTH,OVERDUE_RS,OVERDUE_RS_UNITS,NOT_BEFORE,NOT_BEFORE_UNITS,EXCEPTIONS,EXCEPTIONS_DOSE,GIVEN_AFTER,GIVEN_AFTER_UNITS,EXPIRES_AFTER,EXPIRES_UNITS,EXPIRES_CODE,NOT_UNTIL_DOSE,NOT_UNTIL_TIME,NOT_UNTIL_UNITS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "med_series_sched_SD091114",
    "PKColumns": "",
    "TableColumns": "DISTRICT,SERIES_SCHEDULE,DOSE_NUMBER,DESCRIPTION,SERIES_CODE,EVENT_DOSE,TIME_EVENTS,TIME_EVENTS_UNITS,OVERDUE_MS,OVERDUE_MS_UNITS,TIME_BIRTH,UNITS_TIME_BIRTH,OVERDUE_RS,OVERDUE_RS_UNITS,NOT_BEFORE,NOT_BEFORE_UNITS,EXCEPTIONS,EXCEPTIONS_DOSE,GIVEN_AFTER,GIVEN_AFTER_UNITS,EXPIRES_AFTER,EXPIRES_UNITS,EXPIRES_CODE,NOT_UNTIL_DOSE,NOT_UNTIL_TIME,NOT_UNTIL_UNITS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MED_SHOT",
    "PKColumns": "DISTRICT,STUDENT_ID,SHOT_CODE",
    "TableColumns": "DISTRICT,STUDENT_ID,SHOT_CODE,EXEMPT,COMMENT,OVERRIDE,HAD_DISEASE,DISEASE_DATE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MED_SHOT_DET",
    "PKColumns": "DISTRICT,STUDENT_ID,SHOT_CODE,SHOT_DATE",
    "TableColumns": "DISTRICT,STUDENT_ID,SHOT_CODE,SHOT_DATE,SHOT_ORDER,SOURCE_DOC,SIGNED_DOC,WARNING_STATUS,OVERRIDE,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MED_STU_LETTER",
    "PKColumns": "DISTRICT,STUDENT_ID,CRIT_NUMBER,CALC_DATE,SERIES_CODE",
    "TableColumns": "DISTRICT,STUDENT_ID,CRIT_NUMBER,CALC_DATE,SERIES_CODE,DATE_PRINTED,NOTIFICATION_DATE,SERIES_REASON,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MED_USER",
    "PKColumns": "DISTRICT,STUDENT_ID,SCREEN_NUMBER,FIELD_NUMBER",
    "TableColumns": "DISTRICT,STUDENT_ID,SCREEN_NUMBER,FIELD_NUMBER,FIELD_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MED_VISION",
    "PKColumns": "DISTRICT,STUDENT_ID,TEST_DATE",
    "TableColumns": "DISTRICT,STUDENT_ID,TEST_DATE,GRADE,LOCATION,LENS,RIGHT_EYE,LEFT_EYE,MUSCLE,MUSCLE_LEFT,COLOR_BLIND,PLUS_LENS,BINOC,INITIALS,TEST_TYPE,STEREOPSIS,NEAR_FAR_TYPE,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MED_VISION_COLS",
    "PKColumns": "DISTRICT,STUDENT_ID,TEST_DATE",
    "TableColumns": "DISTRICT,STUDENT_ID,TEST_DATE,SCREENING_TYPE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MED_VITALS",
    "PKColumns": "ROW_IDENTITY",
    "TableColumns": "ROW_IDENTITY,MED_OFFICE_ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID,TIME_VITALS_TAKEN,BLOOD_PRESSURE_SYS,BLOOD_PRESSURE_DIA,PULSE,TEMPERATURE,TEMPERATURE_METHOD,RESPIRATION,PULSE_OXIMETER",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MED_YEAREND_RUN",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,RUN_KEY",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,RUN_KEY,RUN_DATE,RUN_STATUS,CLEAN_MED_DATA,PURGE_STU_YEAR,PURGE_LETTERS_DATE,RESTORE_KEY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MEDTB_ALT_DOSE",
    "PKColumns": "DISTRICT,SERIES_CODE,ALT_NUMBER",
    "TableColumns": "DISTRICT,SERIES_CODE,ALT_NUMBER,DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MEDTB_ALT_DOSE_DET",
    "PKColumns": "DISTRICT,SERIES_CODE,ALT_NUMBER,SEQ_NUMBER",
    "TableColumns": "DISTRICT,SERIES_CODE,ALT_NUMBER,SEQ_NUMBER,ALT_DOSE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MEDTB_BMI_STATUS",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,MIN_BMI,MAX_BMI,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MEDTB_CDC_LMS",
    "PKColumns": "DISTRICT,GENDER,AGE,CHART_TYPE",
    "TableColumns": "DISTRICT,GENDER,AGE,CHART_TYPE,L,M,S",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "MEDTB_DECIBEL",
    "PKColumns": "DISTRICT,DECIBEL_LEVEL",
    "TableColumns": "DISTRICT,DECIBEL_LEVEL,SEQUENCE_NUMBER,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MEDTB_EVENT",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MEDTB_EXAM",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE_NORMAL,ACTIVE_ATHLETIC,SEQ_NUMBER,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MEDTB_EXEMPT",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MEDTB_FOLLOWUP",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,DENTAL,GROWTH,HEARING,IMMUN,OFFICE,OTHER,PHYSICAL,SCOLIOSIS,VISION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MEDTB_FREQUENCY",
    "PKColumns": "DISTRICT,FREQUENCY_LEVEL",
    "TableColumns": "DISTRICT,FREQUENCY_LEVEL,SEQUENCE_NUMBER,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MEDTB_LENS",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MEDTB_LOCATION",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MEDTB_MEDICINE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,PRN,MEDICAID_CODE,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MEDTB_OUTCOME",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MEDTB_PERCENTS",
    "PKColumns": "DISTRICT,AGE,GENDER,PERCENTILE",
    "TableColumns": "DISTRICT,AGE,GENDER,PERCENTILE,HEIGHT,WEIGHT,BMI,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MEDTB_PERCENTS_ARK",
    "PKColumns": "DISTRICT,AGE,GENDER,PERCENTILE",
    "TableColumns": "DISTRICT,AGE,GENDER,PERCENTILE,HEIGHT,WEIGHT,BMI,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MEDTB_REFER",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,DENTAL,GROWTH,HEARING,IMMUN,OFFICE,OTHER,PHYSICAL,SCOLIOSIS,VISION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MEDTB_SCREENING",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MEDTB_SHOT",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,SHOT_ORDER,AUTO_GENERATE,LIVE_VIRUS,SHOT_REQUIREMENT,SERIES_FLAG,LICENSING_DATE,STATE_CODE_EQUIV,PESC_CODE,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MEDTB_SOURCE_DOC",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MEDTB_STATUS",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MEDTB_TEMP_METHOD",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "CHANGE_DATE_TIME,CHANGE_UID,DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MEDTB_TREATMENT",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,MEDICAID_CODE,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MEDTB_VACCINATION_PESC_CODE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "medtb_vis_exam_ark",
    "PKColumns": "DISTRICT,FOLLOWUP_CODE",
    "TableColumns": "DISTRICT,FOLLOWUP_CODE,DESCRIPTION,CONFIRMED_NORMAL,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MEDTB_VISION_EXAM_TYPE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MEDTB_VISIT",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MENU_ITEMS",
    "PKColumns": "DISTRICT,PARENT_MENU,SEQUENCE",
    "TableColumns": "DISTRICT,PARENT_MENU,SEQUENCE,MENU_ID,DESCRIPTION,TARGET,PAGE,SEC_PACKAGE,SEC_SUBPACKAGE,SEC_FEATURE,RESERVED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_ABSENCE_TYPES",
    "PKColumns": "DISTRICT,BUILDING,ABSENCE_TYPE",
    "TableColumns": "DISTRICT,BUILDING,ABSENCE_TYPE,ABSENCE_ORDER,ABSENCE_WHEN,DESCRIPTION,SUM_TO_YEARLY,YEARLY_TYPE,ACTIVE,TWS_ACCESS,MULTI_PERIOD_RULE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_ABSENCE_VALID",
    "PKColumns": "DISTRICT,BUILDING,ABSENCE_TYPE,ATTENDANCE_CODE",
    "TableColumns": "DISTRICT,BUILDING,ABSENCE_TYPE,ATTENDANCE_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_ALT_LANG_CFG",
    "PKColumns": "DISTRICT,LANGUAGE,LABEL",
    "TableColumns": "DISTRICT,LANGUAGE,LABEL,ALTERNATE_LABEL,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_AVERAGE_CALC",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,AVERAGE_ID,AVERAGE_SEQUENCE,CALC_TYPE,MARK_TYPE,MARK_TYPE_MP",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,AVERAGE_ID,AVERAGE_SEQUENCE,CALC_TYPE,MARK_TYPE,MARK_TYPE_MP,PERCENT_WEIGHT,EXEMPT_STATUS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_AVERAGE_SETUP",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,AVERAGE_ID,AVERAGE_SEQUENCE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,AVERAGE_TYPE,AVERAGE_ID,AVERAGE_SEQUENCE,MARK_TYPE,DURATION,MARK_TYPE_MP,CALC_AT_MP,USE_GRADEBOOK,USE_STATUS_T,USE_STATUS_O,COURSE_ENDED,BLANK_MARKS,AVERAGE_PASS_FAIL,AVERAGE_REGULAR,STATE_CRS_EQUIV,USE_RAW_AVERAGES,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_CFG",
    "PKColumns": "DISTRICT,BUILDING",
    "TableColumns": "DISTRICT,BUILDING,CURRENT_RC_RUN,INCLUDE_XFER_IN_RC,DISPLAY_MBS_BLDG,MAINTAIN_ATTEND,PROCESS_IPR,USE_LANG_TEMPLATE,DATA_SOURCE_FILE,PROGRAM_SCREEN,REG_USER_SCREEN,NOTIFY_DWNLD_PATH,EMAIL_OPTION,RETURN_EMAIL,RET_EMAIL_MISSUB,TEA_IPR_MNT,SUB_IPR_MNT,TEA_IPR_STU_SUMM,SUB_IPR_STU_SUMM,TEA_RC_MNT,SUB_RC_MNT,TEA_RC_STU_SUMM,SUB_RC_STU_SUMM,TEA_SC_MNT,SUB_SC_MNT,TEA_SC_STU_SUMM,SUB_SC_STU_SUMM,TEA_GB_DEFINE,TEA_GB_SCORE,SUB_GB_DEFINE,SUB_GB_SCORE,PROCESS_SC,SC_COMMENT_LINES,GB_ENTRY_B4_ENRLMT,TAC_CHANGE_CREDIT,GB_ALLOW_TEA_SCALE,GB_LIMIT_CATEGORIES,GB_LIMIT_DROP_SCORE,GB_LIMIT_MISS_MARKS,GB_ALLOW_OVR_WEIGHT,GB_ALLOW_TRUNC_RND,ASMT_DATE_VAL,VALIDATE_TRANSFER,MP_CRS_CREDIT_OVR,TEA_GB_VIEW,SUB_GB_VIEW,TEA_PRINT_RC,SUB_PRINT_RC,TEA_TRANSCRIPT,SUB_TRANSCRIPT,TEA_GB_SUM_VIEW,SUB_GB_SUM_VIEW,USE_RC_HOLD,STATUS_REASON,OVERALL_BALANCE,OVERALL_BAL_REASON,COURSE_BALANCE,COURSE_BAL_REASON,STUDENT_BALANCE,STUDENT_BAL_REASON,ACTIVITY_BALANCE,ACTIVITY_BAL_REASON,ALLOW_COURSE_FREE_TEXT,MAX_COURSE_FREE_TEXT_CHARACTERS,SECONDARY_TEACHER_ACCESS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "mr_cfg_hold_fee",
    "PKColumns": "DISTRICT,BUILDING,ITEM_OR_CAT,CODE",
    "TableColumns": "DISTRICT,BUILDING,ITEM_OR_CAT,CODE,BALANCE,REASON,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "mr_cfg_hold_status",
    "PKColumns": "DISTRICT,BUILDING,FEE_STATUS",
    "TableColumns": "DISTRICT,BUILDING,FEE_STATUS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_CFG_LANG",
    "PKColumns": "DISTRICT,BUILDING,LANGUAGE_CODE",
    "TableColumns": "DISTRICT,BUILDING,LANGUAGE_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_CFG_MISS_SUB",
    "PKColumns": "DISTRICT,BUILDING,LOGIN_ID",
    "TableColumns": "DISTRICT,BUILDING,LOGIN_ID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_CLASS_SIZE",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,GPA_TYPE,RUN_TERM_YEAR,BUILDING,GRADE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,GPA_TYPE,RUN_TERM_YEAR,BUILDING,GRADE,CLASS_SIZE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_COMMENT_TYPES",
    "PKColumns": "DISTRICT,BUILDING,COMMENT_TYPE",
    "TableColumns": "DISTRICT,BUILDING,COMMENT_TYPE,COMMENT_ORDER,DESCRIPTION,ACTIVE,REQUIRED,USAGE,RC_USAGE,IPR_USAGE,SC_USAGE,TWS_ACCESS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_COMMENT_VALID",
    "PKColumns": "DISTRICT,BUILDING,COMMENT_TYPE,CODE",
    "TableColumns": "DISTRICT,BUILDING,COMMENT_TYPE,CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_COMMENTS",
    "PKColumns": "DISTRICT,BUILDING,CODE",
    "TableColumns": "DISTRICT,BUILDING,CODE,IPR_USAGE,SC_USAGE,RC_USAGE,FT_USAGE,DESCRIPTION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_COMMENTS_ALT_LANG",
    "PKColumns": "DISTRICT,BUILDING,CODE,LANGUAGE",
    "TableColumns": "DISTRICT,BUILDING,CODE,LANGUAGE,DESCRIPTION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_CRDOVR_REASON",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_CREDIT_SETUP",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,USE_STATUS_T,USE_STATUS_O,COURSE_ENDED,LIMIT_STU_GRADE,LIMIT_CRS_GRADE,ISSUE_PARTIAL,USE_CRS_AVG_RULE,AVG_MARK_TYPE,AVG_PASS_RULE,MIN_FAILING_MARK,CHECK_ABSENCES,ABS_TYPE,ABS_TOTAL,ABS_CRDOVR_REASON,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_CREDIT_SETUP_AB",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,ABS_TYPE,ABS_TOTAL",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,ABS_TYPE,ABS_TOTAL,PER_MP_TERM_YR,REVOKE_TERM_COURSE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_CREDIT_SETUP_GD",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,GRADE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,GRADE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_CREDIT_SETUP_MK",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,MARK_TYPE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,MARK_TYPE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_CRSEQU_DET",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,STATE_ID,COURSE,COURSE_SECTION",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,STATE_ID,COURSE,COURSE_SECTION,EQUIV_PARTS,EQUIV_SEQUENCE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_CRSEQU_HDR",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,STATE_CODE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,STATE_CODE,NEEDS_RECALC,ERROR_REASON,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_CRSEQU_SETUP",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,CRSEQU_FULL_YEAR,CRSEQU_TWO_PART,CRSEQU_THREE_PART,CRSEQU_FOUR_PART,RETAKE_RULE,RETAKE_LEVEL,CALC_GRAD_REQ,CALC_CREDIT,RC_WAREHOUSE,TRN_WAREHOUSE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_CRSEQU_SETUP_AB",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,ABSENCE_TYPE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,ABSENCE_TYPE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_CRSEQU_SETUP_MK",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,MARK_TYPE_STATE,MARK_TYPE_LOCAL",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,MARK_TYPE_STATE,MARK_TYPE_LOCAL,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GB_ACCUMULATED_AVG",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,COMPETENCY_GROUP,COMPETENCY_NUMBER,MARKING_PERIOD,STUDENT_ID",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,COMPETENCY_GROUP,COMPETENCY_NUMBER,MARKING_PERIOD,STUDENT_ID,OVERRIDE_AVERAGE,AVG_OR_RC_VALUE,RC_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GB_ALPHA_MARKS",
    "PKColumns": "DISTRICT,BUILDING,CODE",
    "TableColumns": "DISTRICT,BUILDING,CODE,DESCRIPTION,EXCLUDE,PERCENT_VALUE,CHANGE_DATE_TIME,CHANGE_UID,SGY_EQUIV,IMS_EQUIV",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GB_ASMT",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,ASMT_NUMBER",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,ASMT_NUMBER,CRS_ASMT_NUMBER,CATEGORY,EXTRA_CREDIT,ASSIGN_DATE,DUE_DATE,DESCRIPTION,DESC_DETAIL,POINTS,WEIGHT,PUBLISH_ASMT,PUBLISH_SCORES,RUBRIC_NUMBER,USE_RUBRIC,CANNOT_DROP,HIGHLIGHT_POINTS,POINTS_THRESHOLD,HIGHLIGHT_PURPLE,UC_STUDENT_WORK_TYPE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GB_ASMT_COMP",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,ASMT_NUMBER,COMPETENCY_GROUP,COMPETENCY_NUMBER,CRITERIA_NUMBER",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,ASMT_NUMBER,COMPETENCY_GROUP,COMPETENCY_NUMBER,RUBRIC_NUMBER,CRITERIA_NUMBER,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GB_ASMT_STU_COMP",
    "PKColumns": "DISTRICT,BUILDING,COMPETENCY_GROUP,STAFF_ID,ASMT_NUMBER",
    "TableColumns": "DISTRICT,BUILDING,COMPETENCY_GROUP,STAFF_ID,ASMT_NUMBER,CATEGORY,EXTRA_CREDIT,ASSIGN_DATE,DUE_DATE,DESCRIPTION,DESC_DETAIL,POINTS,WEIGHT,PUBLISH_ASMT,PUBLISH_SCORES,RUBRIC_NUMBER,USE_RUBRIC,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GB_ASMT_STU_COMP_ATTACH",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,COMPETENCY_GROUP,BUILDING,STAFF_ID,ASMT_NUMBER,ATTACHMENT_NAME",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,COMPETENCY_GROUP,BUILDING,STAFF_ID,ASMT_NUMBER,ATTACHMENT_NAME,ATTACHMENT_DATA,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GB_ASMT_STU_COMP_COMP",
    "PKColumns": "DISTRICT,BUILDING,STAFF_ID,ASMT_NUMBER,COMPETENCY_GROUP,COMPETENCY_NUMBER,CRITERIA_NUMBER",
    "TableColumns": "DISTRICT,BUILDING,STAFF_ID,ASMT_NUMBER,COMPETENCY_GROUP,COMPETENCY_NUMBER,RUBRIC_NUMBER,CRITERIA_NUMBER,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GB_AVG_CALC",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,AVERAGE_ID,AVERAGE_SEQUENCE,CALC_TYPE,MARK_TYPE,MARK_TYPE_MP",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,AVERAGE_ID,AVERAGE_SEQUENCE,CALC_TYPE,MARK_TYPE,MARK_TYPE_MP,PERCENT_WEIGHT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GB_CAT_AVG",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,CATEGORY,MARKING_PERIOD,STUDENT_ID",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,CATEGORY,MARKING_PERIOD,STUDENT_ID,OVERRIDE_AVERAGE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GB_CAT_BLD",
    "PKColumns": "DISTRICT,BUILDING,CODE",
    "TableColumns": "DISTRICT,BUILDING,CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GB_CAT_SESS_MARK",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,MARK_TYPE,MARKING_PERIOD,CATEGORY",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,MARK_TYPE,MARKING_PERIOD,CATEGORY,CATEGORY_WEIGHT,DROP_LOWEST,EXCLUDE_MISSING,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GB_CAT_SESSION",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,CATEGORY,MARKING_PERIOD",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,CATEGORY,MARKING_PERIOD,CATEGORY_WEIGHT,DROP_LOWEST,EXCLUDE_MISSING,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GB_CAT_STU_COMP",
    "PKColumns": "DISTRICT,BUILDING,COMPETENCY_GROUP,STAFF_ID,CATEGORY",
    "TableColumns": "DISTRICT,BUILDING,COMPETENCY_GROUP,STAFF_ID,CATEGORY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GB_CATEGORY_TYPE_DET",
    "PKColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,DURATION_TYPE,CATEGORY_TYPE,CATEGORY,MARK_TYPE,MARKING_PERIODS",
    "TableColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,DURATION_TYPE,CATEGORY_TYPE,CATEGORY,MARK_TYPE,MARKING_PERIODS,CATEGORY_WEIGHT,DROP_LOWEST,EXCLUDE_MISSING,CALCULATION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GB_CATEGORY_TYPE_HDR",
    "PKColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,DURATION_TYPE,CATEGORY_TYPE",
    "TableColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,DURATION_TYPE,CATEGORY_TYPE,DESCRIPTION,USE_TOTAL_POINTS,ROUND_TRUNC,DEFAULT_SCALE,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GB_COMMENT",
    "PKColumns": "DISTRICT,BUILDING,CODE",
    "TableColumns": "DISTRICT,BUILDING,CODE,DESCRIPTION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GB_IPR_AVG",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,MARK_TYPE,IPR_DATE,MARKING_PERIOD,STUDENT_ID",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,MARK_TYPE,IPR_DATE,MARKING_PERIOD,STUDENT_ID,OVERRIDE_AVERAGE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GB_LOAD_AVG_ERR",
    "PKColumns": "RUN_KEY,STUDENT_ID,SECTION_KEY,COURSE_SESSION,MARK_TYPE,ERROR_SEQ",
    "TableColumns": "RUN_KEY,STUDENT_ID,SECTION_KEY,COURSE_SESSION,MARK_TYPE,ERROR_SEQ,ERROR_MESSAGE",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "MR_GB_MARK_AVG",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,MARK_TYPE,MARKING_PERIOD,STUDENT_ID",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,MARK_TYPE,MARKING_PERIOD,STUDENT_ID,OVERRIDE_AVERAGE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GB_MP_MARK",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,MARK_TYPE,MARKING_PERIOD",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,MARK_TYPE,MARKING_PERIOD,OVERRIDE,ROUND_TRUNC,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GB_RUBRIC_CRIT",
    "PKColumns": "DISTRICT,RUBRIC_NUMBER,CRITERIA_NUMBER",
    "TableColumns": "DISTRICT,RUBRIC_NUMBER,CRITERIA_NUMBER,DESCRIPTION,CRITERIA_ORDER,COMPETENCY_GROUP,COMPETENCY_NUMBER,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GB_RUBRIC_DET",
    "PKColumns": "DISTRICT,RUBRIC_NUMBER,CRITERIA_NUMBER,PERF_LVL_NUMBER",
    "TableColumns": "DISTRICT,RUBRIC_NUMBER,CRITERIA_NUMBER,PERF_LVL_NUMBER,DESCRIPTION,MAX_POINTS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GB_RUBRIC_HDR",
    "PKColumns": "DISTRICT,RUBRIC_NUMBER,DESCRIPTION",
    "TableColumns": "DISTRICT,RUBRIC_NUMBER,DESCRIPTION,NUMBER_OF_CRITERIA,NUMBER_OF_PERF_LEVEL,RUBRIC_TYPE,RUBRIC_STYLE,RUBRIC_MODE,AUTHOR,DESC_DETAIL,TEMPLATE,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GB_RUBRIC_PERF_LVL",
    "PKColumns": "DISTRICT,RUBRIC_NUMBER,PERF_LVL_NUMBER",
    "TableColumns": "DISTRICT,RUBRIC_NUMBER,PERF_LVL_NUMBER,DESCRIPTION,PERF_LVL_ORDER,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GB_SCALE",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,SCALE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,SCALE,DESCRIPTION,LONG_DESCRIPTION,DEFAULT_SCALE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GB_SCALE_DET",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,SCALE,MARK",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,SCALE,MARK,CUTOFF,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GB_SESSION_PROP",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,USE_TOTAL_POINTS,USE_CAT_WEIGHT,ROUND_TRUNC,DEFAULT_SCALE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GB_STU_ALIAS",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,STUDENT_ID",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,STUDENT_ID,ALIAS_NAME,DISPLAY_ORDER,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GB_STU_ASMT_CMT",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,ASMT_NUMBER,STUDENT_ID",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,ASMT_NUMBER,STUDENT_ID,COMMENT_CODE,COMMENT_TEXT,PUBLISH,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GB_STU_COMP_ACCUMULATED_AVG",
    "PKColumns": "DISTRICT,BUILDING,COMPETENCY_GROUP,STAFF_ID,COMPETENCY_NUMBER,MARKING_PERIOD,STUDENT_ID",
    "TableColumns": "DISTRICT,BUILDING,COMPETENCY_GROUP,STAFF_ID,COMPETENCY_NUMBER,MARKING_PERIOD,STUDENT_ID,OVERRIDE_AVERAGE,AVG_OR_RC_VALUE,RC_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GB_STU_COMP_CAT_AVG",
    "PKColumns": "DISTRICT,BUILDING,COMPETENCY_GROUP,STAFF_ID,CATEGORY,MARKING_PERIOD,STUDENT_ID",
    "TableColumns": "DISTRICT,BUILDING,COMPETENCY_GROUP,STAFF_ID,CATEGORY,MARKING_PERIOD,STUDENT_ID,OVERRIDE_AVERAGE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GB_STU_COMP_STU_SCORE",
    "PKColumns": "DISTRICT,BUILDING,STAFF_ID,COMPETENCY_GROUP,ASMT_NUMBER,STUDENT_ID",
    "TableColumns": "DISTRICT,BUILDING,STAFF_ID,COMPETENCY_GROUP,ASMT_NUMBER,STUDENT_ID,ASMT_SCORE,ASMT_EXCEPTION,ASMT_ALPHA_MARK,EXCLUDE_LOWEST,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GB_STU_COMP_STU_SCORE_HIST",
    "PKColumns": "DISTRICT,BUILDING,STAFF_ID,COMPETENCY_GROUP,ASMT_NUMBER,STUDENT_ID,SCORE_CHANGED_DATE",
    "TableColumns": "DISTRICT,BUILDING,STAFF_ID,COMPETENCY_GROUP,ASMT_NUMBER,STUDENT_ID,SCORE_CHANGED_DATE,OLD_VALUE,NEW_VALUE,CHANGE_TYPE,PRIVATE_NOTES,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GB_STU_COMPS_ALIAS",
    "PKColumns": "DISTRICT,BUILDING,COMPETENCY_GROUP,STAFF_ID,STUDENT_ID",
    "TableColumns": "DISTRICT,BUILDING,COMPETENCY_GROUP,STAFF_ID,STUDENT_ID,ALIAS_NAME,DISPLAY_ORDER,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GB_STU_COMPS_STU_ASMT_CMT",
    "PKColumns": "DISTRICT,BUILDING,COMPETENCY_GROUP,STAFF_ID,ASMT_NUMBER,STUDENT_ID",
    "TableColumns": "DISTRICT,BUILDING,COMPETENCY_GROUP,STAFF_ID,ASMT_NUMBER,STUDENT_ID,COMMENT_CODE,COMMENT_TEXT,PUBLISH,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GB_STU_COMPS_STU_NOTES",
    "PKColumns": "DISTRICT,BUILDING,COMPETENCY_GROUP,STAFF_ID,STUDENT_ID,NOTE_DATE",
    "TableColumns": "DISTRICT,BUILDING,COMPETENCY_GROUP,STAFF_ID,STUDENT_ID,NOTE_DATE,STU_NOTES,PUBLISH_NOTE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GB_STU_NOTES",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,STUDENT_ID,NOTE_DATE",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,STUDENT_ID,NOTE_DATE,STU_NOTES,PUBLISH_NOTE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GB_STU_SCALE",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,MARKING_PERIOD,STUDENT_ID",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,MARKING_PERIOD,STUDENT_ID,SCALE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GB_STU_SCORE",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,ASMT_NUMBER,STUDENT_ID",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,ASMT_NUMBER,STUDENT_ID,ASMT_SCORE,ASMT_EXCEPTION,ASMT_ALPHA_MARK,EXCLUDE_LOWEST,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GB_STU_SCORE_HIST",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,ASMT_NUMBER,STUDENT_ID,SCORE_CHANGED_DATE",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,ASMT_NUMBER,STUDENT_ID,SCORE_CHANGED_DATE,OLD_VALUE,NEW_VALUE,CHANGE_TYPE,PRIVATE_NOTES,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GPA_SETUP",
    "PKColumns": "DISTRICT,GPA_TYPE",
    "TableColumns": "DISTRICT,GPA_TYPE,DESCRIPTION,ISSUE_GPA,ATT_CREDIT_TO_USE,USE_PARTIAL,COURSE_NOT_ENDED,BLANK_MARKS,INCLUDE_AS_DEFAULT,ACTIVE,GPA_PRECISION,RANK_INACTIVES,STATE_CRS_EQUIV,ADD_ON_POINTS,DISTRICT_WIDE_RANK,INCLUDE_PERFPLUS,DISPLAY_RANK,DISPLAY_PERCENTILE,DISPLAY_DECILE,DISPLAY_QUARTILE,DISPLAY_QUINTILE,RANK_ON_GPA,PERCENTILE_MODE,PERCENTILE_RANK_TYPE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GPA_SETUP_BLDG",
    "PKColumns": "DISTRICT,GPA_TYPE,BLDG_TYPE",
    "TableColumns": "DISTRICT,GPA_TYPE,BLDG_TYPE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GPA_SETUP_EXCL",
    "PKColumns": "DISTRICT,GPA_TYPE,WITH_CODE",
    "TableColumns": "DISTRICT,GPA_TYPE,WITH_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GPA_SETUP_GD",
    "PKColumns": "DISTRICT,GPA_TYPE,GRADE",
    "TableColumns": "DISTRICT,GPA_TYPE,GRADE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GPA_SETUP_MK_GD",
    "PKColumns": "DISTRICT,GPA_TYPE,MARK_ORDER,GRADE",
    "TableColumns": "DISTRICT,GPA_TYPE,MARK_ORDER,GRADE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GPA_SETUP_MRK",
    "PKColumns": "DISTRICT,GPA_TYPE,MARK_TYPE,MARK_ORDER",
    "TableColumns": "DISTRICT,GPA_TYPE,MARK_TYPE,MARK_ORDER,GROUP_MARKS,GROUP_ORDER,WEIGHT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GRAD_REQ_DET",
    "PKColumns": "DISTRICT,REQ_GROUP,STU_GRAD_YEAR,REQUIRE_CODE",
    "TableColumns": "DISTRICT,REQ_GROUP,STU_GRAD_YEAR,REQUIRE_CODE,REQ_ORDER,CREDIT,MIN_MARK_VALUE,REQ_VALUE,REQ_UNITS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GRAD_REQ_FOCUS",
    "PKColumns": "DISTRICT,REQ_GROUP,STU_GRAD_YEAR,REQUIRE_CODE,MAJOR_CRITERIA,MINOR_CRITERIA",
    "TableColumns": "DISTRICT,REQ_GROUP,STU_GRAD_YEAR,REQUIRE_CODE,MAJOR_CRITERIA,MINOR_CRITERIA,CREDIT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GRAD_REQ_HDR",
    "PKColumns": "DISTRICT,REQ_GROUP,STU_GRAD_YEAR",
    "TableColumns": "DISTRICT,REQ_GROUP,STU_GRAD_YEAR,RETAKE_COURSE_RULE,WAIVED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GRAD_REQ_MRK_TYPE",
    "PKColumns": "DISTRICT,REQ_GROUP,STU_GRAD_YEAR,MARK_TYPE",
    "TableColumns": "DISTRICT,REQ_GROUP,STU_GRAD_YEAR,MARK_TYPE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_GRAD_REQ_TAG_RULES",
    "PKColumns": "DISTRICT,REQ_GROUP,STU_GRAD_YEAR,REQUIRE_CODE,OPTION_NUMBER,SEQUENCE_NUM",
    "TableColumns": "DISTRICT,REQ_GROUP,STU_GRAD_YEAR,REQUIRE_CODE,OPTION_NUMBER,SEQUENCE_NUM,AND_OR_FLAG,TAG,CREDIT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_HONOR_ELIG_CD",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,HONOR_TYPE,SEQUENCE_ORDER,CURRENT_ELIG_STAT",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,HONOR_TYPE,SEQUENCE_ORDER,CURRENT_ELIG_STAT,ELIGIBILITY_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_HONOR_SETUP",
    "PKColumns": "DISTRICT,BUILDING,HONOR_TYPE",
    "TableColumns": "DISTRICT,BUILDING,HONOR_TYPE,DESCRIPTION,HONOR_GROUP,PROCESSING_ORDER,PROCESS_GPA,CURRENT_OR_YTD_GPA,MINIMUM_GPA,MAXIMUM_GPA,GPA_PRECISION,MINIMUM_COURSES,INCLUDE_NOT_ENDED,INCLUDE_NON_HR_CRS,MINIMUM_ERN_CREDIT,MINIMUM_ATT_CREDIT,ATT_CREDIT_TO_USE,USE_PARTIAL_CREDIT,INCLUDE_NON_HR_CRD,INCLUDE_BLANK_MARK,DISQUAL_BLANK_MARK,MAX_BLANK_MARK,INCLUDE_AS_DEFAULT,HONOR_MESSAGE,ACTIVE,ELIG_INCLUDE_PRIOR,ELIGIBILITY_CODE,ELIG_DURATION,ELIG_DURATION_DAYS,AT_RISK_REASON,AT_RISK_RESET_NUM,AT_RISK_RESET_TYPE,OPTION_TYPE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_HONOR_SETUP_ABS",
    "PKColumns": "DISTRICT,BUILDING,HONOR_TYPE,ABSENCE_TYPE",
    "TableColumns": "DISTRICT,BUILDING,HONOR_TYPE,ABSENCE_TYPE,MAXIMUM_ABSENCES,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_HONOR_SETUP_ALT_LANG",
    "PKColumns": "DISTRICT,BUILDING,HONOR_TYPE,LANGUAGE",
    "TableColumns": "DISTRICT,BUILDING,HONOR_TYPE,LANGUAGE,HONOR_MESSAGE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_HONOR_SETUP_COM",
    "PKColumns": "DISTRICT,BUILDING,HONOR_TYPE,HONOR_COMMENT",
    "TableColumns": "DISTRICT,BUILDING,HONOR_TYPE,HONOR_COMMENT,NUM_COMMENTS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_HONOR_SETUP_GD",
    "PKColumns": "DISTRICT,BUILDING,HONOR_TYPE,GRADE",
    "TableColumns": "DISTRICT,BUILDING,HONOR_TYPE,GRADE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_HONOR_SETUP_MKS",
    "PKColumns": "DISTRICT,BUILDING,HONOR_TYPE,MARK_TYPE,MARK_ORDER",
    "TableColumns": "DISTRICT,BUILDING,HONOR_TYPE,MARK_TYPE,MARK_ORDER,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_HONOR_SETUP_Q_D",
    "PKColumns": "DISTRICT,BUILDING,HONOR_TYPE,QUALIFY_DISQUALIFY,SEQUENCE_NUM",
    "TableColumns": "DISTRICT,BUILDING,HONOR_TYPE,QUALIFY_DISQUALIFY,SEQUENCE_NUM,NUMBER_OF_MARKS,MINIMUM_MARK,MAXIMUM_MARK,COURSE_LEVEL,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_IMPORT_STU_CRS_DET",
    "PKColumns": "DISTRICT,STUDENT_ID,SESSION_SEQ,COURSE_SEQ",
    "TableColumns": "DISTRICT,STUDENT_ID,SESSION_SEQ,COURSE_SEQ,DESCRIPTION,STATE_CODE,ABBREVIATION,SEMESTER,CLASS_PERIOD,SEMESTER_SEQ,DEPARTMENT,WITHDRAW_GRADE,GRADE_AVERAGE,EARNED_CREDIT,PASS_FAIL_CREDIT,EXPLANATION,COURSE_TEACHER,CREDIT_CAMPUS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_IMPORT_STU_CRS_GRADES",
    "PKColumns": "DISTRICT,STUDENT_ID,SESSION_SEQ,COURSE_SEQ,GRADE_SEQ",
    "TableColumns": "DISTRICT,STUDENT_ID,SESSION_SEQ,COURSE_SEQ,GRADE_SEQ,COURSE_GRADE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_IMPORT_STU_CRS_HDR",
    "PKColumns": "DISTRICT,STUDENT_ID,SESSION_SEQ",
    "TableColumns": "DISTRICT,STUDENT_ID,SESSION_SEQ,SCHOOL_YEAR,GRADE,SESSION_TYPE,GPA,CLASS_SIZE,CLASS_RANK,RANK_CALC_DATE,RANK_QUARTILE,COLLEGE_CAMPUS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_IPR_ELIG_CD",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,ELIG_TYPE,SEQUENCE_ORDER,CURRENT_ELIG_STATUS",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,ELIG_TYPE,SEQUENCE_ORDER,CURRENT_ELIG_STATUS,ELIGIBILITY_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_IPR_ELIG_SETUP",
    "PKColumns": "DISTRICT,BUILDING,ELIG_TYPE",
    "TableColumns": "DISTRICT,BUILDING,ELIG_TYPE,DESCRIPTION,PROCESSING_ORDER,MINIMUM_COURSES,INCLUDE_NOT_ENDED,INCLUDE_BLANK_MARK,DISQUAL_BLANK_MARK,MAX_BLANK_MARK,ACTIVE,ELIG_INCLUDE_PRIOR,ELIGIBILITY_CODE,ELIG_DURATION,ELIG_DURATION_DAYS,USE_AT_RISK,AT_RISK_REASON,AT_RISK_DURATION,AT_RISK_DAYS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_IPR_ELIG_SETUP_ABS",
    "PKColumns": "DISTRICT,BUILDING,ELIG_TYPE,ABSENCE_TYPE",
    "TableColumns": "DISTRICT,BUILDING,ELIG_TYPE,ABSENCE_TYPE,MAXIMUM_ABSENCES,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_IPR_ELIG_SETUP_COM",
    "PKColumns": "DISTRICT,BUILDING,ELIG_TYPE,ELIG_COMMENT",
    "TableColumns": "DISTRICT,BUILDING,ELIG_TYPE,ELIG_COMMENT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_IPR_ELIG_SETUP_GD",
    "PKColumns": "DISTRICT,BUILDING,ELIG_TYPE,GRADE",
    "TableColumns": "DISTRICT,BUILDING,ELIG_TYPE,GRADE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_IPR_ELIG_SETUP_MKS",
    "PKColumns": "DISTRICT,BUILDING,ELIG_TYPE,MARK_TYPE,MARK_ORDER",
    "TableColumns": "DISTRICT,BUILDING,ELIG_TYPE,MARK_TYPE,MARK_ORDER,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_IPR_ELIG_SETUP_Q_D",
    "PKColumns": "DISTRICT,BUILDING,ELIG_TYPE,QUALIFY_DISQUALIFY,SEQUENCE_NUM",
    "TableColumns": "DISTRICT,BUILDING,ELIG_TYPE,QUALIFY_DISQUALIFY,SEQUENCE_NUM,NUMBER_OF_MARKS,MINIMUM_MARK,MAXIMUM_MARK,COURSE_LEVEL,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_IPR_PRINT_HDR",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,IPR_DATE,GRADE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,IPR_DATE,GRADE,RUN_DATE,HEADER_TEXT,FOOTER_TEXT,DATA_TITLE_01,DATA_TITLE_02,DATA_TITLE_03,DATA_TITLE_04,DATA_TITLE_05,DATA_TITLE_06,DATA_TITLE_07,DATA_TITLE_08,DATA_TITLE_09,DATA_TITLE_10,DATA_TITLE_11,DATA_TITLE_12,DATA_TITLE_13,DATA_TITLE_14,DATA_TITLE_15,DATA_TITLE_16,DATA_TITLE_17,DATA_TITLE_18,DATA_TITLE_19,DATA_TITLE_20,DATA_TITLE_21,DATA_TITLE_22,DATA_TITLE_23,DATA_TITLE_24,DATA_TITLE_25,DATA_TITLE_26,DATA_TITLE_27,DATA_TITLE_28,DATA_TITLE_29,DATA_TITLE_30,IPR_PRINT_KEY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_IPR_PRT_STU_COM",
    "PKColumns": "IPR_PRINT_KEY,STUDENT_ID,SECTION_KEY,COURSE_SESSION",
    "TableColumns": "IPR_PRINT_KEY,STUDENT_ID,SECTION_KEY,COURSE_SESSION,IPR_DATA_DESCR_01,IPR_DATA_DESCR_02,IPR_DATA_DESCR_03,IPR_DATA_DESCR_04,IPR_DATA_DESCR_05,IPR_DATA_DESCR_06,IPR_DATA_DESCR_07,IPR_DATA_DESCR_08,IPR_DATA_DESCR_09,IPR_DATA_DESCR_10,IPR_DATA_DESCR_11,IPR_DATA_DESCR_12,IPR_DATA_DESCR_13,IPR_DATA_DESCR_14,IPR_DATA_DESCR_15,IPR_DATA_DESCR_16,IPR_DATA_DESCR_17,IPR_DATA_DESCR_18,IPR_DATA_DESCR_19,IPR_DATA_DESCR_20,IPR_DATA_DESCR_21,IPR_DATA_DESCR_22,IPR_DATA_DESCR_23,IPR_DATA_DESCR_24,IPR_DATA_DESCR_25,IPR_DATA_DESCR_26,IPR_DATA_DESCR_27,IPR_DATA_DESCR_28,IPR_DATA_DESCR_29,IPR_DATA_DESCR_30,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_IPR_PRT_STU_DET",
    "PKColumns": "IPR_PRINT_KEY,STUDENT_ID,SECTION_KEY,COURSE_SESSION",
    "TableColumns": "IPR_PRINT_KEY,STUDENT_ID,SECTION_KEY,COURSE_BUILDING,COURSE,COURSE_SECTION,COURSE_SESSION,DESCRIPTION,CRS_PERIOD,PRIMARY_STAFF_ID,STAFF_NAME,ROOM_ID,IPR_DATA_VALUE_01,IPR_DATA_VALUE_02,IPR_DATA_VALUE_03,IPR_DATA_VALUE_04,IPR_DATA_VALUE_05,IPR_DATA_VALUE_06,IPR_DATA_VALUE_07,IPR_DATA_VALUE_08,IPR_DATA_VALUE_09,IPR_DATA_VALUE_10,IPR_DATA_VALUE_11,IPR_DATA_VALUE_12,IPR_DATA_VALUE_13,IPR_DATA_VALUE_14,IPR_DATA_VALUE_15,IPR_DATA_VALUE_16,IPR_DATA_VALUE_17,IPR_DATA_VALUE_18,IPR_DATA_VALUE_19,IPR_DATA_VALUE_20,IPR_DATA_VALUE_21,IPR_DATA_VALUE_22,IPR_DATA_VALUE_23,IPR_DATA_VALUE_24,IPR_DATA_VALUE_25,IPR_DATA_VALUE_26,IPR_DATA_VALUE_27,IPR_DATA_VALUE_28,IPR_DATA_VALUE_29,IPR_DATA_VALUE_30,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_IPR_PRT_STU_HDR",
    "PKColumns": "IPR_PRINT_KEY,STUDENT_ID",
    "TableColumns": "IPR_PRINT_KEY,STUDENT_ID,STUDENT_NAME,BUILDING,GRADE,TRACK,COUNSELOR,HOUSE_TEAM,HOMEROOM_PRIMARY,DAILY_ATT_DESCR_01,DAILY_ATT_DESCR_02,DAILY_ATT_DESCR_03,DAILY_ATT_DESCR_04,DAILY_ATT_DESCR_05,DAILY_ATT_DESCR_06,DAILY_ATT_DESCR_07,DAILY_ATT_DESCR_08,DAILY_ATT_DESCR_09,DAILY_ATT_DESCR_10,DAILY_ATT_CURR_01,DAILY_ATT_CURR_02,DAILY_ATT_CURR_03,DAILY_ATT_CURR_04,DAILY_ATT_CURR_05,DAILY_ATT_CURR_06,DAILY_ATT_CURR_07,DAILY_ATT_CURR_08,DAILY_ATT_CURR_09,DAILY_ATT_CURR_10,DAILY_ATT_YTD_01,DAILY_ATT_YTD_02,DAILY_ATT_YTD_03,DAILY_ATT_YTD_04,DAILY_ATT_YTD_05,DAILY_ATT_YTD_06,DAILY_ATT_YTD_07,DAILY_ATT_YTD_08,DAILY_ATT_YTD_09,DAILY_ATT_YTD_10,REPORT_TEMPLATE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_IPR_PRT_STU_MSG",
    "PKColumns": "IPR_PRINT_KEY,STUDENT_ID,SECTION_KEY,COURSE_SESSION",
    "TableColumns": "IPR_PRINT_KEY,STUDENT_ID,SECTION_KEY,COURSE_SESSION,IPR_MESSAGE_01,IPR_MESSAGE_02,IPR_MESSAGE_03,IPR_MESSAGE_04,IPR_MESSAGE_05,IPR_MESSAGE_06,IPR_MESSAGE_07,IPR_MESSAGE_08,IPR_MESSAGE_09,IPR_MESSAGE_10,IPR_MESSAGE_11,IPR_MESSAGE_12,IPR_MESSAGE_13,IPR_MESSAGE_14,IPR_MESSAGE_15,IPR_MESSAGE_16,IPR_MESSAGE_17,IPR_MESSAGE_18,IPR_MESSAGE_19,IPR_MESSAGE_20,IPR_MESSAGE_21,IPR_MESSAGE_22,IPR_MESSAGE_23,IPR_MESSAGE_24,IPR_MESSAGE_25,IPR_MESSAGE_26,IPR_MESSAGE_27,IPR_MESSAGE_28,IPR_MESSAGE_29,IPR_MESSAGE_30,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_IPR_RUN",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,TRACK,RUN_DATE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,TRACK,RUN_DATE,ELIGIBILITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_IPR_STU_ABS",
    "PKColumns": "DISTRICT,STUDENT_ID,SECTION_KEY,COURSE_SESSION,IPR_DATE,ABSENCE_TYPE",
    "TableColumns": "DISTRICT,STUDENT_ID,SECTION_KEY,COURSE_SESSION,IPR_DATE,ABSENCE_TYPE,ABSENCE_VALUE,OVERRIDE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_IPR_STU_AT_RISK",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,STUDENT_ID,IPR_DATE,AT_RISK_TYPE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,STUDENT_ID,IPR_DATE,AT_RISK_TYPE,DISQUAL_REASON,AT_RISK_REASON,EFFECTIVE_DATE,EXPIRATION_DATE,PLAN_NUM,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_IPR_STU_COM",
    "PKColumns": "DISTRICT,STUDENT_ID,SECTION_KEY,COURSE_SESSION,IPR_DATE,COMMENT_TYPE",
    "TableColumns": "DISTRICT,STUDENT_ID,SECTION_KEY,COURSE_SESSION,IPR_DATE,COMMENT_TYPE,COMMENT_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_IPR_STU_ELIGIBLE",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,STUDENT_ID,IPR_DATE,ELIG_TYPE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,STUDENT_ID,IPR_DATE,DISQUAL_REASON,ELIG_TYPE,ELIGIBILITY_CODE,EFFECTIVE_DATE,EXPIRATION_DATE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_IPR_STU_HDR",
    "PKColumns": "DISTRICT,STUDENT_ID,SECTION_KEY,COURSE_SESSION,IPR_DATE",
    "TableColumns": "DISTRICT,STUDENT_ID,SECTION_KEY,COURSE_SESSION,IPR_DATE,INDIVIDUAL_IPR,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_IPR_STU_MARKS",
    "PKColumns": "DISTRICT,STUDENT_ID,SECTION_KEY,COURSE_SESSION,IPR_DATE,MARK_TYPE",
    "TableColumns": "DISTRICT,STUDENT_ID,SECTION_KEY,COURSE_SESSION,IPR_DATE,MARK_TYPE,MARK_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_IPR_STU_MESSAGE",
    "PKColumns": "DISTRICT,STUDENT_ID,SECTION_KEY,COURSE_SESSION,IPR_DATE,MESSAGE_ORDER",
    "TableColumns": "DISTRICT,STUDENT_ID,SECTION_KEY,COURSE_SESSION,IPR_DATE,MESSAGE_ORDER,MESSAGE_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_IPR_TAKEN",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,RUN_DATE",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,RUN_DATE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_IPR_VIEW_ATT",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,VIEW_TYPE,GRADE,VIEW_ORDER",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,VIEW_TYPE,GRADE,ATT_VIEW_TYPE,VIEW_ORDER,ATT_TITLE,ATT_VIEW_INTERVAL,ATT_VIEW_SUM_BY,ATT_VIEW_CODE_GRP,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_IPR_VIEW_ATT_IT",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,VIEW_TYPE,GRADE,VIEW_ORDER,ATT_VIEW_INTERVAL",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,VIEW_TYPE,GRADE,VIEW_ORDER,ATT_VIEW_INTERVAL,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_IPR_VIEW_DET",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,VIEW_TYPE,GRADE,VIEW_SEQUENCE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,VIEW_TYPE,GRADE,VIEW_SEQUENCE,VIEW_ORDER,SLOT_TYPE,SLOT_CODE,TITLE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_IPR_VIEW_HDR",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,VIEW_TYPE,GRADE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,VIEW_TYPE,GRADE,REPORT_TEMPLATE,PRINT_DROPPED_CRS,PRINT_LEGEND,PRINT_MBS,HEADER_TEXT,FOOTER_TEXT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_LEVEL_DET",
    "PKColumns": "DISTRICT,BUILDING,LEVEL_NUMBER,MARK",
    "TableColumns": "DISTRICT,BUILDING,LEVEL_NUMBER,MARK,NUMERIC_VALUE,POINT_VALUE,PASSING_MARK,RC_PRINT_VALUE,TRN_PRINT_VALUE,IPR_PRINT_VALUE,ADDON_POINTS,WEIGHT_BY_CRED,AVERAGE_USAGE,STATE_CODE_EQUIV,COLOR_LEVEL,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_LEVEL_GPA",
    "PKColumns": "DISTRICT,BUILDING,LEVEL_NUMBER,MARK,GPA_TYPE",
    "TableColumns": "DISTRICT,BUILDING,LEVEL_NUMBER,MARK,GPA_TYPE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_LEVEL_HDR",
    "PKColumns": "DISTRICT,BUILDING,LEVEL_NUMBER",
    "TableColumns": "DISTRICT,BUILDING,LEVEL_NUMBER,DESCRIPTION,ACTIVE,PESC_CODE,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_LEVEL_HONOR",
    "PKColumns": "DISTRICT,BUILDING,LEVEL_NUMBER,MARK,HONOR_TYPE",
    "TableColumns": "DISTRICT,BUILDING,LEVEL_NUMBER,MARK,HONOR_TYPE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_LEVEL_MARKS",
    "PKColumns": "DISTRICT,BUILDING,MARK",
    "TableColumns": "DISTRICT,BUILDING,MARK,DISPLAY_ORDER,ACTIVE,STATE_CODE_EQUIV,COURSE_COMPLETED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_LTDB_MARK_DTL",
    "PKColumns": "DISTRICT,CODE,LOW_VALUE",
    "TableColumns": "DISTRICT,CODE,LOW_VALUE,HIGH_VALUE,EQUIVALENT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_LTDB_MARK_HDR",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_MARK_ISSUED_AT",
    "PKColumns": "DISTRICT,BUILDING,MARK_TYPE,MARKING_PERIOD",
    "TableColumns": "DISTRICT,BUILDING,MARK_TYPE,MARKING_PERIOD,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_MARK_SUBS",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,LOW_RANGE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,LOW_RANGE,HIGH_RANGE,REPLACE_MARK,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_MARK_TYPES",
    "PKColumns": "DISTRICT,BUILDING,MARK_TYPE",
    "TableColumns": "DISTRICT,BUILDING,MARK_TYPE,MARK_ORDER,MARK_WHEN,DESCRIPTION,INCLUDE_AS_DEFAULT,REQUIRED,ACTIVE,TWS_ACCESS,RECEIVE_GB_RESULT,INCLUDE_PERFPLUS,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID,STATE_CODE_EQUIV",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_MARK_TYPES_LMS_MAP",
    "PKColumns": "DISTRICT,BUILDING,MARK_TYPE",
    "TableColumns": "DISTRICT,BUILDING,MARK_TYPE,MARK_TYPE_EQUIV,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_MARK_VALID",
    "PKColumns": "DISTRICT,BUILDING,MARK_TYPE,MARK",
    "TableColumns": "DISTRICT,BUILDING,MARK_TYPE,MARK,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_PRINT_GD_SCALE",
    "PKColumns": "MR_PRINT_KEY,STUDENT_ID,GRADING_SCALE_TYPE",
    "TableColumns": "MR_PRINT_KEY,STUDENT_ID,PRINT_ORDER,GRADING_SCALE_TYPE,GRADING_SCALE_DESC,MARK_01,MARK_02,MARK_03,MARK_04,MARK_05,MARK_06,MARK_07,MARK_08,MARK_09,MARK_10,MARK_11,MARK_12,MARK_13,MARK_14,MARK_15,MARK_16,MARK_17,MARK_18,MARK_19,MARK_20,MARK_21,MARK_22,MARK_23,MARK_24,MARK_25,MARK_26,MARK_27,MARK_28,MARK_29,MARK_30,MARK_DESCR_01,MARK_DESCR_02,MARK_DESCR_03,MARK_DESCR_04,MARK_DESCR_05,MARK_DESCR_06,MARK_DESCR_07,MARK_DESCR_08,MARK_DESCR_09,MARK_DESCR_10,MARK_DESCR_11,MARK_DESCR_12,MARK_DESCR_13,MARK_DESCR_14,MARK_DESCR_15,MARK_DESCR_16,MARK_DESCR_17,MARK_DESCR_18,MARK_DESCR_19,MARK_DESCR_20,MARK_DESCR_21,MARK_DESCR_22,MARK_DESCR_23,MARK_DESCR_24,MARK_DESCR_25,MARK_DESCR_26,MARK_DESCR_27,MARK_DESCR_28,MARK_DESCR_29,MARK_DESCR_30,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_PRINT_HDR",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,RC_RUN,GRADE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,RC_RUN,GRADE,AS_OF_DATE,RUN_DATE,HEADER_TEXT,FOOTER_TEXT,MR_DATA_TITLE_01,MR_DATA_TITLE_02,MR_DATA_TITLE_03,MR_DATA_TITLE_04,MR_DATA_TITLE_05,MR_DATA_TITLE_06,MR_DATA_TITLE_07,MR_DATA_TITLE_08,MR_DATA_TITLE_09,MR_DATA_TITLE_10,MR_DATA_TITLE_11,MR_DATA_TITLE_12,MR_DATA_TITLE_13,MR_DATA_TITLE_14,MR_DATA_TITLE_15,MR_DATA_TITLE_16,MR_DATA_TITLE_17,MR_DATA_TITLE_18,MR_DATA_TITLE_19,MR_DATA_TITLE_20,MR_DATA_TITLE_21,MR_DATA_TITLE_22,MR_DATA_TITLE_23,MR_DATA_TITLE_24,MR_DATA_TITLE_25,MR_DATA_TITLE_26,MR_DATA_TITLE_27,MR_DATA_TITLE_28,MR_DATA_TITLE_29,MR_DATA_TITLE_30,MR_SC_TITLE_01,MR_SC_TITLE_02,MR_SC_TITLE_03,MR_SC_TITLE_04,MR_SC_TITLE_05,MR_SC_TITLE_06,MR_SC_TITLE_07,MR_SC_TITLE_08,MR_SC_TITLE_09,MR_SC_TITLE_10,MR_SC_TITLE_11,MR_SC_TITLE_12,MR_SC_TITLE_13,MR_SC_TITLE_14,MR_SC_TITLE_15,MR_SC_TITLE_16,MR_SC_TITLE_17,MR_SC_TITLE_18,MR_SC_TITLE_19,MR_SC_TITLE_20,MR_SC_TITLE_21,MR_SC_TITLE_22,MR_SC_TITLE_23,MR_SC_TITLE_24,MR_SC_TITLE_25,MR_SC_TITLE_26,MR_SC_TITLE_27,MR_SC_TITLE_28,MR_SC_TITLE_29,MR_SC_TITLE_30,PROGRAM_TITLE_01,PROGRAM_TITLE_02,PROGRAM_TITLE_03,PROGRAM_TITLE_04,PROGRAM_TITLE_05,PROGRAM_TITLE_06,PROGRAM_TITLE_07,PROGRAM_TITLE_08,PROGRAM_TITLE_09,PROGRAM_TITLE_10,PROGRAM_TITLE_11,PROGRAM_TITLE_12,MR_PRINT_KEY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_PRINT_KEY",
    "PKColumns": "DISTRICT,KEY_TYPE",
    "TableColumns": "DISTRICT,KEY_TYPE,PRINT_KEY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_PRINT_STU_COMM",
    "PKColumns": "MR_PRINT_KEY,STUDENT_ID,SECTION_KEY,COURSE_SESSION",
    "TableColumns": "MR_PRINT_KEY,STUDENT_ID,SECTION_KEY,COURSE_SESSION,MR_DATA_DESCR_01,MR_DATA_DESCR_02,MR_DATA_DESCR_03,MR_DATA_DESCR_04,MR_DATA_DESCR_05,MR_DATA_DESCR_06,MR_DATA_DESCR_07,MR_DATA_DESCR_08,MR_DATA_DESCR_09,MR_DATA_DESCR_10,MR_DATA_DESCR_11,MR_DATA_DESCR_12,MR_DATA_DESCR_13,MR_DATA_DESCR_14,MR_DATA_DESCR_15,MR_DATA_DESCR_16,MR_DATA_DESCR_17,MR_DATA_DESCR_18,MR_DATA_DESCR_19,MR_DATA_DESCR_20,MR_DATA_DESCR_21,MR_DATA_DESCR_22,MR_DATA_DESCR_23,MR_DATA_DESCR_24,MR_DATA_DESCR_25,MR_DATA_DESCR_26,MR_DATA_DESCR_27,MR_DATA_DESCR_28,MR_DATA_DESCR_29,MR_DATA_DESCR_30,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_PRINT_STU_CRSCP",
    "PKColumns": "MR_PRINT_KEY,STUDENT_ID,COURSE_BUILDING,COURSE,COMPETENCY_GROUP,COMPETENCY_NUMBER",
    "TableColumns": "MR_PRINT_KEY,STUDENT_ID,COURSE_BUILDING,COURSE,COMPETENCY_GROUP,COMPETENCY_NUMBER,SEQUENCE_NUMBER,DESCRIPTION,FORMAT_LEVEL,HEADING_ONLY,SC_DATA_VALUE_01,SC_DATA_VALUE_02,SC_DATA_VALUE_03,SC_DATA_VALUE_04,SC_DATA_VALUE_05,SC_DATA_VALUE_06,SC_DATA_VALUE_07,SC_DATA_VALUE_08,SC_DATA_VALUE_09,SC_DATA_VALUE_10,SC_DATA_VALUE_11,SC_DATA_VALUE_12,SC_DATA_VALUE_13,SC_DATA_VALUE_14,SC_DATA_VALUE_15,SC_DATA_VALUE_16,SC_DATA_VALUE_17,SC_DATA_VALUE_18,SC_DATA_VALUE_19,SC_DATA_VALUE_20,SC_DATA_VALUE_21,SC_DATA_VALUE_22,SC_DATA_VALUE_23,SC_DATA_VALUE_24,SC_DATA_VALUE_25,SC_DATA_VALUE_26,SC_DATA_VALUE_27,SC_DATA_VALUE_28,SC_DATA_VALUE_29,SC_DATA_VALUE_30,SC_COMM_DESCR_01,SC_COMM_DESCR_02,SC_COMM_DESCR_03,SC_COMM_DESCR_04,SC_COMM_DESCR_05,SC_COMM_DESCR_06,SC_COMM_DESCR_07,SC_COMM_DESCR_08,SC_COMM_DESCR_09,SC_COMM_DESCR_10,SC_COMM_DESCR_11,SC_COMM_DESCR_12,SC_COMM_DESCR_13,SC_COMM_DESCR_14,SC_COMM_DESCR_15,SC_COMM_DESCR_16,SC_COMM_DESCR_17,SC_COMM_DESCR_18,SC_COMM_DESCR_19,SC_COMM_DESCR_20,SC_COMM_DESCR_21,SC_COMM_DESCR_22,SC_COMM_DESCR_23,SC_COMM_DESCR_24,SC_COMM_DESCR_25,SC_COMM_DESCR_26,SC_COMM_DESCR_27,SC_COMM_DESCR_28,SC_COMM_DESCR_29,SC_COMM_DESCR_30,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_PRINT_STU_CRSTXT",
    "PKColumns": "MR_PRINT_KEY,STUDENT_ID,MARKING_PERIOD",
    "TableColumns": "MR_PRINT_KEY,STUDENT_ID,MARKING_PERIOD,SECTION_KEY_01,SECTION_KEY_02,SECTION_KEY_03,SECTION_KEY_04,SECTION_KEY_05,SECTION_KEY_06,SECTION_KEY_07,SECTION_KEY_08,SECTION_KEY_09,SECTION_KEY_10,SECTION_KEY_11,SECTION_KEY_12,SECTION_KEY_13,SECTION_KEY_14,SECTION_KEY_15,STAFF_ID_01,STAFF_ID_02,STAFF_ID_03,STAFF_ID_04,STAFF_ID_05,STAFF_ID_06,STAFF_ID_07,STAFF_ID_08,STAFF_ID_09,STAFF_ID_10,STAFF_ID_11,STAFF_ID_12,STAFF_ID_13,STAFF_ID_14,STAFF_ID_15,STAFF_NAME_01,STAFF_NAME_02,STAFF_NAME_03,STAFF_NAME_04,STAFF_NAME_05,STAFF_NAME_06,STAFF_NAME_07,STAFF_NAME_08,STAFF_NAME_09,STAFF_NAME_10,STAFF_NAME_11,STAFF_NAME_12,STAFF_NAME_13,STAFF_NAME_14,STAFF_NAME_15,COURSE_COMMENT_01,COURSE_COMMENT_02,COURSE_COMMENT_03,COURSE_COMMENT_04,COURSE_COMMENT_05,COURSE_COMMENT_06,COURSE_COMMENT_07,COURSE_COMMENT_08,COURSE_COMMENT_09,COURSE_COMMENT_10,COURSE_COMMENT_11,COURSE_COMMENT_12,COURSE_COMMENT_13,COURSE_COMMENT_14,COURSE_COMMENT_15,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_PRINT_STU_DET",
    "PKColumns": "MR_PRINT_KEY,STUDENT_ID,SECTION_KEY,COURSE_SESSION",
    "TableColumns": "MR_PRINT_KEY,STUDENT_ID,SECTION_KEY,COURSE_BUILDING,COURSE,COURSE_SECTION,COURSE_SESSION,DESCRIPTION,CRS_PERIOD,PRIMARY_STAFF_ID,STAFF_NAME,ROOM_ID,ATTEMPTED_CREDIT,ATT_OVERRIDE,ATT_OVR_REASON,EARNED_CREDIT,EARN_OVERRIDE,EARN_OVR_REASON,MR_DATA_VALUE_01,MR_DATA_VALUE_02,MR_DATA_VALUE_03,MR_DATA_VALUE_04,MR_DATA_VALUE_05,MR_DATA_VALUE_06,MR_DATA_VALUE_07,MR_DATA_VALUE_08,MR_DATA_VALUE_09,MR_DATA_VALUE_10,MR_DATA_VALUE_11,MR_DATA_VALUE_12,MR_DATA_VALUE_13,MR_DATA_VALUE_14,MR_DATA_VALUE_15,MR_DATA_VALUE_16,MR_DATA_VALUE_17,MR_DATA_VALUE_18,MR_DATA_VALUE_19,MR_DATA_VALUE_20,MR_DATA_VALUE_21,MR_DATA_VALUE_22,MR_DATA_VALUE_23,MR_DATA_VALUE_24,MR_DATA_VALUE_25,MR_DATA_VALUE_26,MR_DATA_VALUE_27,MR_DATA_VALUE_28,MR_DATA_VALUE_29,MR_DATA_VALUE_30,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_PRINT_STU_GPA",
    "PKColumns": "MR_PRINT_KEY,STUDENT_ID,GPA_ORDER",
    "TableColumns": "MR_PRINT_KEY,STUDENT_ID,GPA_ORDER,GPA_TYPE,GPA_TITLE,GPA_TERM01,GPA_TERM02,GPA_TERM03,GPA_TERM04,GPA_TERM05,GPA_TERM06,GPA_TERM07,GPA_TERM08,GPA_TERM09,GPA_TERM10,GPA_CURR01,GPA_CURR02,GPA_CURR03,GPA_CURR04,GPA_CURR05,GPA_CURR06,GPA_CURR07,GPA_CURR08,GPA_CURR09,GPA_CURR10,GPA_CUM01,GPA_CUM02,GPA_CUM03,GPA_CUM04,GPA_CUM05,GPA_CUM06,GPA_CUM07,GPA_CUM08,GPA_CUM09,GPA_CUM10,RANK_NUM_CURR01,RANK_NUM_CURR02,RANK_NUM_CURR03,RANK_NUM_CURR04,RANK_NUM_CURR05,RANK_NUM_CURR06,RANK_NUM_CURR07,RANK_NUM_CURR08,RANK_NUM_CURR09,RANK_NUM_CURR10,RANK_NUM_CUM01,RANK_NUM_CUM02,RANK_NUM_CUM03,RANK_NUM_CUM04,RANK_NUM_CUM05,RANK_NUM_CUM06,RANK_NUM_CUM07,RANK_NUM_CUM08,RANK_NUM_CUM09,RANK_NUM_CUM10,RANK_OUT_OF01,RANK_OUT_OF02,RANK_OUT_OF03,RANK_OUT_OF04,RANK_OUT_OF05,RANK_OUT_OF06,RANK_OUT_OF07,RANK_OUT_OF08,RANK_OUT_OF09,RANK_OUT_OF10,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_PRINT_STU_HDR",
    "PKColumns": "MR_PRINT_KEY,STUDENT_ID",
    "TableColumns": "MR_PRINT_KEY,STUDENT_ID,STUDENT_NAME,BUILDING,GRADE,TRACK,COUNSELOR,HOUSE_TEAM,HOMEROOM_PRIMARY,RANK_NUM_CURR,RANK_NUM_CUM,RANK_OUT_OF,DAILY_ATT_DESCR_01,DAILY_ATT_DESCR_02,DAILY_ATT_DESCR_03,DAILY_ATT_DESCR_04,DAILY_ATT_DESCR_05,DAILY_ATT_DESCR_06,DAILY_ATT_DESCR_07,DAILY_ATT_DESCR_08,DAILY_ATT_DESCR_09,DAILY_ATT_DESCR_10,DAILY_ATT_CURR_01,DAILY_ATT_CURR_02,DAILY_ATT_CURR_03,DAILY_ATT_CURR_04,DAILY_ATT_CURR_05,DAILY_ATT_CURR_06,DAILY_ATT_CURR_07,DAILY_ATT_CURR_08,DAILY_ATT_CURR_09,DAILY_ATT_CURR_10,DAILY_ATT_YTD_01,DAILY_ATT_YTD_02,DAILY_ATT_YTD_03,DAILY_ATT_YTD_04,DAILY_ATT_YTD_05,DAILY_ATT_YTD_06,DAILY_ATT_YTD_07,DAILY_ATT_YTD_08,DAILY_ATT_YTD_09,DAILY_ATT_YTD_10,CREDIT_HONOR,CREDIT_SEM,CREDIT_CUM,CREDIT_ATT_CUR,CREDIT_ATT_SEM,CREDIT_ATT_CUM,GPA_HONOR,GPA_SEM,GPA_CUM,HONOR_TYPE_01,HONOR_TYPE_02,HONOR_TYPE_03,HONOR_TYPE_04,HONOR_TYPE_05,HONOR_TYPE_06,HONOR_TYPE_07,HONOR_TYPE_08,HONOR_TYPE_09,HONOR_TYPE_10,HONOR_MSG_01,HONOR_MSG_02,HONOR_MSG_03,HONOR_MSG_04,HONOR_MSG_05,HONOR_MSG_06,HONOR_MSG_07,HONOR_MSG_08,HONOR_MSG_09,HONOR_MSG_10,HONOR_GPA_01,HONOR_GPA_02,HONOR_GPA_03,HONOR_GPA_04,HONOR_GPA_05,HONOR_GPA_06,HONOR_GPA_07,HONOR_GPA_08,HONOR_GPA_09,HONOR_GPA_10,HONOR_CREDIT_01,HONOR_CREDIT_02,HONOR_CREDIT_03,HONOR_CREDIT_04,HONOR_CREDIT_05,HONOR_CREDIT_06,HONOR_CREDIT_07,HONOR_CREDIT_08,HONOR_CREDIT_09,HONOR_CREDIT_10,HONOR_QUALIFIED_01,HONOR_QUALIFIED_02,HONOR_QUALIFIED_03,HONOR_QUALIFIED_04,HONOR_QUALIFIED_05,HONOR_QUALIFIED_06,HONOR_QUALIFIED_07,HONOR_QUALIFIED_08,HONOR_QUALIFIED_09,HONOR_QUALIFIED_10,REPORT_TEMPLATE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_PRINT_STU_HNR",
    "PKColumns": "MR_PRINT_KEY,STUDENT_ID,HONOR_ORDER",
    "TableColumns": "MR_PRINT_KEY,STUDENT_ID,HONOR_ORDER,HONOR_TYPE,HONOR_TITLE,HONOR_RUN01,HONOR_RUN02,HONOR_RUN03,HONOR_RUN04,HONOR_RUN05,HONOR_RUN06,HONOR_RUN07,HONOR_RUN08,HONOR_RUN09,HONOR_RUN10,HONOR_GPA01,HONOR_GPA02,HONOR_GPA03,HONOR_GPA04,HONOR_GPA05,HONOR_GPA06,HONOR_GPA07,HONOR_GPA08,HONOR_GPA09,HONOR_GPA10,HONOR_QUAL01,HONOR_QUAL02,HONOR_QUAL03,HONOR_QUAL04,HONOR_QUAL05,HONOR_QUAL06,HONOR_QUAL07,HONOR_QUAL08,HONOR_QUAL09,HONOR_QUAL10,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "mr_print_stu_hold",
    "PKColumns": "MR_PRINT_KEY,STUDENT_ID",
    "TableColumns": "MR_PRINT_KEY,STUDENT_ID,REPORT_CARD_HOLD,STATUS_HOLD,FEE_STATUS,STATUS_DESCRIPTION,OVERALL_HOLD,OVERALL_THRESHOLD,OVERALL_BALANCE,COURSE_HOLD,COURSE_THRESHOLD,COURSE_BALANCE,STUDENT_HOLD,STUDENT_THRESHOLD,STUDENT_BALANCE,ACTIVITY_HOLD,ACTIVITY_THRESHOLD,ACTIVITY_BALANCE,REASON1,REASON2,REASON3,REASON4,REASON5,REASON6,REASON7,REASON8,REASON9,REASON10,REASON_DESC1,REASON_DESC2,REASON_DESC3,REASON_DESC4,REASON_DESC5,REASON_DESC6,REASON_DESC7,REASON_DESC8,REASON_DESC9,REASON_DESC10,HOLD_HEADER_TEXT,HOLD_FOOTER_TEXT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "mr_print_stu_item",
    "PKColumns": "MR_PRINT_KEY,STUDENT_ID,TRACKING_NUMBER",
    "TableColumns": "MR_PRINT_KEY,STUDENT_ID,TRACKING_NUMBER,ITEM_DATE,ITEM,DESCRIPTION,BALANCE,HOLD_ITEM,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_PRINT_STU_LTDB",
    "PKColumns": "MR_PRINT_KEY,STUDENT_ID",
    "TableColumns": "MR_PRINT_KEY,STUDENT_ID,LTDB_TITLE_01,LTDB_TITLE_02,LTDB_TITLE_03,LTDB_TITLE_04,LTDB_TITLE_05,LTDB_TITLE_06,LTDB_TITLE_07,LTDB_TITLE_08,LTDB_TITLE_09,LTDB_TITLE_10,LTDB_TITLE_11,LTDB_TITLE_12,LTDB_TITLE_13,LTDB_TITLE_14,LTDB_TITLE_15,LTDB_TITLE_16,LTDB_TITLE_17,LTDB_TITLE_18,LTDB_TITLE_19,LTDB_TITLE_20,LTDB_TITLE_21,LTDB_TITLE_22,LTDB_TITLE_23,LTDB_TITLE_24,LTDB_TITLE_25,LTDB_TITLE_26,LTDB_TITLE_27,LTDB_TITLE_28,LTDB_TITLE_29,LTDB_TITLE_30,SCORE_01,SCORE_02,SCORE_03,SCORE_04,SCORE_05,SCORE_06,SCORE_07,SCORE_08,SCORE_09,SCORE_10,SCORE_11,SCORE_12,SCORE_13,SCORE_14,SCORE_15,SCORE_16,SCORE_17,SCORE_18,SCORE_19,SCORE_20,SCORE_21,SCORE_22,SCORE_23,SCORE_24,SCORE_25,SCORE_26,SCORE_27,SCORE_28,SCORE_29,SCORE_30,TEST_DATE_01,TEST_DATE_02,TEST_DATE_03,TEST_DATE_04,TEST_DATE_05,TEST_DATE_06,TEST_DATE_07,TEST_DATE_08,TEST_DATE_09,TEST_DATE_10,TEST_DATE_11,TEST_DATE_12,TEST_DATE_13,TEST_DATE_14,TEST_DATE_15,TEST_DATE_16,TEST_DATE_17,TEST_DATE_18,TEST_DATE_19,TEST_DATE_20,TEST_DATE_21,TEST_DATE_22,TEST_DATE_23,TEST_DATE_24,TEST_DATE_25,TEST_DATE_26,TEST_DATE_27,TEST_DATE_28,TEST_DATE_29,TEST_DATE_30,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_PRINT_STU_PROG",
    "PKColumns": "MR_PRINT_KEY,STUDENT_ID,PROGRAM_ID,FIELD_NUMBER",
    "TableColumns": "MR_PRINT_KEY,STUDENT_ID,PROGRAM_ID,FIELD_NUMBER,VIEW_ORDER,PROGRAM_LABEL,PROGRAM_VALUE_01,PROGRAM_VALUE_02,PROGRAM_VALUE_03,PROGRAM_VALUE_04,PROGRAM_VALUE_05,PROGRAM_VALUE_06,PROGRAM_VALUE_07,PROGRAM_VALUE_08,PROGRAM_VALUE_09,PROGRAM_VALUE_10,PROGRAM_VALUE_11,PROGRAM_VALUE_12,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_PRINT_STU_SCTXT",
    "PKColumns": "MR_PRINT_KEY,STUDENT_ID,MARKING_PERIOD",
    "TableColumns": "MR_PRINT_KEY,STUDENT_ID,MARKING_PERIOD,STAFF_01,STAFF_02,STAFF_03,STAFF_04,STAFF_05,STAFF_06,STAFF_07,STAFF_08,STAFF_09,STAFF_10,STAFF_NAME_01,STAFF_NAME_02,STAFF_NAME_03,STAFF_NAME_04,STAFF_NAME_05,STAFF_NAME_06,STAFF_NAME_07,STAFF_NAME_08,STAFF_NAME_09,STAFF_NAME_10,STAFF_COMMENT_01,STAFF_COMMENT_02,STAFF_COMMENT_03,STAFF_COMMENT_04,STAFF_COMMENT_05,STAFF_COMMENT_06,STAFF_COMMENT_07,STAFF_COMMENT_08,STAFF_COMMENT_09,STAFF_COMMENT_10,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_PRINT_STU_SEC_TEACHER",
    "PKColumns": "MR_PRINT_KEY,STUDENT_ID,SECTION_KEY,COURSE_SESSION",
    "TableColumns": "MR_PRINT_KEY,STUDENT_ID,SECTION_KEY,COURSE_SESSION,SEC_STAFF_ID_01,SEC_STAFF_NAME_01,SEC_STAFF_ID_02,SEC_STAFF_NAME_02,SEC_STAFF_ID_03,SEC_STAFF_NAME_03,SEC_STAFF_ID_04,SEC_STAFF_NAME_04,SEC_STAFF_ID_05,SEC_STAFF_NAME_05,SEC_STAFF_ID_06,SEC_STAFF_NAME_06,SEC_STAFF_ID_07,SEC_STAFF_NAME_07,SEC_STAFF_ID_08,SEC_STAFF_NAME_08,SEC_STAFF_ID_09,SEC_STAFF_NAME_09,SEC_STAFF_ID_10,SEC_STAFF_NAME_10,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_PRINT_STU_STUCP",
    "PKColumns": "MR_PRINT_KEY,STUDENT_ID,COMP_BUILDING,COMPETENCY_GROUP,COMPETENCY_NUMBER",
    "TableColumns": "MR_PRINT_KEY,STUDENT_ID,COMP_BUILDING,COMPETENCY_GROUP,GROUP_DESCRIPTION,GROUP_SEQUENCE,COMPETENCY_NUMBER,COMP_SEQUENCE,DESCRIPTION,STAFF_ID,STAFF_NAME,FORMAT_LEVEL,HEADING_ONLY,SC_DATA_VALUE_01,SC_DATA_VALUE_02,SC_DATA_VALUE_03,SC_DATA_VALUE_04,SC_DATA_VALUE_05,SC_DATA_VALUE_06,SC_DATA_VALUE_07,SC_DATA_VALUE_08,SC_DATA_VALUE_09,SC_DATA_VALUE_10,SC_DATA_VALUE_11,SC_DATA_VALUE_12,SC_DATA_VALUE_13,SC_DATA_VALUE_14,SC_DATA_VALUE_15,SC_DATA_VALUE_16,SC_DATA_VALUE_17,SC_DATA_VALUE_18,SC_DATA_VALUE_19,SC_DATA_VALUE_20,SC_DATA_VALUE_21,SC_DATA_VALUE_22,SC_DATA_VALUE_23,SC_DATA_VALUE_24,SC_DATA_VALUE_25,SC_DATA_VALUE_26,SC_DATA_VALUE_27,SC_DATA_VALUE_28,SC_DATA_VALUE_29,SC_DATA_VALUE_30,SC_COMM_DESCR_01,SC_COMM_DESCR_02,SC_COMM_DESCR_03,SC_COMM_DESCR_04,SC_COMM_DESCR_05,SC_COMM_DESCR_06,SC_COMM_DESCR_07,SC_COMM_DESCR_08,SC_COMM_DESCR_09,SC_COMM_DESCR_10,SC_COMM_DESCR_11,SC_COMM_DESCR_12,SC_COMM_DESCR_13,SC_COMM_DESCR_14,SC_COMM_DESCR_15,SC_COMM_DESCR_16,SC_COMM_DESCR_17,SC_COMM_DESCR_18,SC_COMM_DESCR_19,SC_COMM_DESCR_20,SC_COMM_DESCR_21,SC_COMM_DESCR_22,SC_COMM_DESCR_23,SC_COMM_DESCR_24,SC_COMM_DESCR_25,SC_COMM_DESCR_26,SC_COMM_DESCR_27,SC_COMM_DESCR_28,SC_COMM_DESCR_29,SC_COMM_DESCR_30,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_RC_STU_AT_RISK",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,STUDENT_ID,HONOR_TYPE,RC_RUN",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,STUDENT_ID,HONOR_TYPE,RC_RUN,AT_RISK_REASON,EXPIRE_YEAR,EXPIRE_RUN_TERM,CHANGE_DATE_TIME,CHANGE_UID,PLAN_NUM",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_RC_STU_ATT_VIEW",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,STUDENT_ID,VIEW_TYPE,RC_RUN",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,STUDENT_ID,VIEW_TYPE,RC_RUN,ABSENCE_VALUE_TOT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_RC_STU_ELIGIBLE",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,STUDENT_ID,HONOR_TYPE,RC_RUN",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,STUDENT_ID,HONOR_TYPE,RC_RUN,ELIGIBILITY_CODE,EFFECTIVE_DATE,EXPIRATION_DATE,DISQUAL_REASON,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_RC_TAKEN",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,MARKING_PERIOD",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,MARKING_PERIOD,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_RC_VIEW_ALT_LANG",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,VIEW_TYPE,RC_RUN,GRADE,LANGUAGE,LABEL_TYPE,VIEW_ORDER",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,VIEW_TYPE,RC_RUN,GRADE,LANGUAGE,LABEL_TYPE,VIEW_ORDER,DESCRIPTION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_RC_VIEW_ATT",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,VIEW_TYPE,RC_RUN,GRADE,VIEW_ORDER",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,VIEW_TYPE,RC_RUN,GRADE,ATT_VIEW_TYPE,VIEW_ORDER,ATT_TITLE,ATT_VIEW_INTERVAL,ATT_VIEW_SUM_BY,ATT_VIEW_CODE_GRP,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_RC_VIEW_ATT_INT",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,VIEW_TYPE,RC_RUN,GRADE,VIEW_ORDER,ATT_VIEW_INTERVAL",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,VIEW_TYPE,RC_RUN,GRADE,VIEW_ORDER,ATT_VIEW_INTERVAL,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_RC_VIEW_DET",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,VIEW_TYPE,RC_RUN,GRADE,VIEW_SEQUENCE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,VIEW_TYPE,RC_RUN,GRADE,VIEW_SEQUENCE,VIEW_ORDER,TITLE,SLOT_TYPE,SLOT_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_RC_VIEW_GPA",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,VIEW_TYPE,RC_RUN,GRADE,VIEW_SEQUENCE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,VIEW_TYPE,RC_RUN,GRADE,VIEW_SEQUENCE,GPA_TYPE,GPA_TITLE,PRINT_CLASS_RANK,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_RC_VIEW_GRD_SC",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,VIEW_TYPE,RC_RUN,GRADE,VIEW_ORDER",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,VIEW_TYPE,RC_RUN,GRADE,VIEW_ORDER,LABEL,GRADING_SCALE_TYPE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_RC_VIEW_HDR",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,VIEW_TYPE,RC_RUN,GRADE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,VIEW_TYPE,RC_RUN,GRADE,REPORT_TEMPLATE,RANK_GPA_TYPE,PRINT_CLASS_RANK,PRINT_HONOR_MSG,PRINT_DROPPED_CRS,PRINT_LEGEND,PRINT_MBS,HEADER_TEXT,FOOTER_TEXT,CREDIT_TO_PRINT,USE_RC_HOLD,HOLD_HEADER_TEXT,HOLD_FOOTER_TEXT,CURRENT_GPA,SEMESTER_GPA,CUMULATIVE_GPA,CURRENT_CREDIT,SEMESTER_CREDIT,CUMULATIVE_CREDIT,ALT_CURRENT_LBL,ALT_SEMESTER_LBL,ALT_CUMULATIVE_LBL,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_RC_VIEW_HONOR",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,VIEW_TYPE,RC_RUN,GRADE,HONOR_SEQUENCE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,VIEW_TYPE,RC_RUN,GRADE,HONOR_SEQUENCE,HONOR_GPA_TYPE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_RC_VIEW_LTDB",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,VIEW_TYPE,RC_RUN,GRADE,VIEW_ORDER",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,VIEW_TYPE,RC_RUN,GRADE,VIEW_ORDER,LABEL,TEST_CODE,TEST_LEVEL,TEST_FORM,SUBTEST,SCORE_CODE,PRINT_TYPE,PRINT_NUMBER,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_RC_VIEW_MPS",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,VIEW_TYPE,RC_RUN,GRADE,VIEW_SEQUENCE,MARKING_PERIOD",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,VIEW_TYPE,RC_RUN,GRADE,VIEW_SEQUENCE,MARKING_PERIOD,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_RC_VIEW_SC_MP",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,VIEW_TYPE,RC_RUN,GRADE,VIEW_SEQUENCE,MARKING_PERIOD",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,VIEW_TYPE,RC_RUN,GRADE,VIEW_SEQUENCE,MARKING_PERIOD,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_RC_VIEW_SP",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,VIEW_TYPE,RC_RUN,GRADE,VIEW_ORDER",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,VIEW_TYPE,RC_RUN,GRADE,VIEW_ORDER,LABEL,PROGRAM_ID,FIELD_NUMBER,PRINT_TYPE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_RC_VIEW_SP_COLS",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,VIEW_TYPE,RC_RUN,GRADE,COLUMN_NUMBER",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,VIEW_TYPE,RC_RUN,GRADE,COLUMN_NUMBER,TITLE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_RC_VIEW_SP_MP",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,VIEW_TYPE,RC_RUN,GRADE,PROGRAM_ID,FIELD_NUMBER,COLUMN_NUMBER,SEARCH_MP",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,VIEW_TYPE,RC_RUN,GRADE,PROGRAM_ID,FIELD_NUMBER,COLUMN_NUMBER,SEARCH_MP,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_RC_VIEW_STUCMP",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,VIEW_TYPE,RC_RUN,GRADE,VIEW_SEQUENCE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,VIEW_TYPE,RC_RUN,GRADE,VIEW_SEQUENCE,VIEW_ORDER,TITLE,SLOT_TYPE,SLOT_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_REQ_AREAS",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,AREA_TYPE,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_SC_COMP_COMS",
    "PKColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,COMPETENCY_GROUP,COMPETENCY_NUMBER,COMMENT_TYPE",
    "TableColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,COMPETENCY_GROUP,COMPETENCY_NUMBER,COMMENT_TYPE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_SC_COMP_CRS",
    "PKColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,COMPETENCY_GROUP,COURSE_BUILDING,COURSE",
    "TableColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,COMPETENCY_GROUP,COURSE_BUILDING,COURSE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_SC_COMP_DET",
    "PKColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,COMPETENCY_GROUP,COMPETENCY_NUMBER",
    "TableColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,COMPETENCY_GROUP,COMPETENCY_NUMBER,DESCRIPTION,SEQUENCE_NUMBER,FORMAT_LEVEL,HEADING_ONLY,GRADING_SCALE,USE_DEFAULT_MARK,STATE_STANDARD_NUM,ACCUMULATOR_TYPE,CHANGE_DATE_TIME,CHANGE_UID,LSM_IDENTIFIER",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_SC_COMP_DET_ALT_LANG",
    "PKColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,COMPETENCY_GROUP,COMPETENCY_NUMBER,LANGUAGE",
    "TableColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,COMPETENCY_GROUP,COMPETENCY_NUMBER,LANGUAGE,DESCRIPTION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_SC_COMP_HDR",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,DISTR_OR_BLDG,COMPETENCY_GROUP,BUILDING,BUILDING_TYPE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,DISTR_OR_BLDG,COMPETENCY_GROUP,BUILDING,BUILDING_TYPE,DESCRIPTION,SEQUENCE_ORDER,COMPETENCY_TYPE,CHANGE_DATE_TIME,CHANGE_UID,LSM_IDENTIFIER",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_SC_COMP_MRKS",
    "PKColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,COMPETENCY_GROUP,COMPETENCY_NUMBER,MARK_TYPE",
    "TableColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,COMPETENCY_GROUP,COMPETENCY_NUMBER,MARK_TYPE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_SC_COMP_STU",
    "PKColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,COMPETENCY_GROUP,SEQUENCE_NUMBER",
    "TableColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,COMPETENCY_GROUP,SEQUENCE_NUMBER,AND_OR_FLAG,TABLE_NAME,SCREEN_TYPE,SCREEN_NUMBER,COLUMN_NAME,FIELD_NUMBER,OPERATOR,SEARCH_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_SC_CRS_TAKEN",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,COMPETENCY_GROUP,MARKING_PERIOD",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,COMPETENCY_GROUP,MARKING_PERIOD,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_SC_CRSSTU_TAKEN",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,COMPETENCY_GROUP,MARKING_PERIOD,STUDENT_ID",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,COMPETENCY_GROUP,MARKING_PERIOD,STUDENT_ID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_SC_DISTR_FORMAT",
    "PKColumns": "DISTRICT,SC_LEVEL",
    "TableColumns": "DISTRICT,SC_LEVEL,FONT_TYPE,FONT_SIZE,COLOR,FORMAT_BOLD,FORMAT_UNDERLINE,FORMAT_ITALICS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_SC_GD_SCALE_ALT_LANG",
    "PKColumns": "DISTRICT,BUILDING,GRADING_SCALE_TYPE,DISPLAY_ORDER,LANGUAGE",
    "TableColumns": "DISTRICT,BUILDING,GRADING_SCALE_TYPE,DISPLAY_ORDER,LANGUAGE,DESCRIPTION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_SC_GD_SCALE_DET",
    "PKColumns": "DISTRICT,BUILDING,GRADING_SCALE_TYPE,DISPLAY_ORDER",
    "TableColumns": "DISTRICT,BUILDING,GRADING_SCALE_TYPE,DISPLAY_ORDER,MARK,DESCRIPTION,POINT_VALUE,PASSING_MARK,ACTIVE,AVERAGE,COLOR_LEVEL,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_SC_GD_SCALE_HDR",
    "PKColumns": "DISTRICT,BUILDING,GRADING_SCALE_TYPE",
    "TableColumns": "DISTRICT,BUILDING,GRADING_SCALE_TYPE,DESCRIPTION,DEFAULT_MARK,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_SC_ST_STANDARD",
    "PKColumns": "DISTRICT,STATE,DOCUMENT_NAME,SUBJECT,SCHOOL_YEAR,GRADE,GUID",
    "TableColumns": "DISTRICT,STATE,DOCUMENT_NAME,SUBJECT,SCHOOL_YEAR,GRADE,GUID,STATE_STANDARD_NUM,LEVEL_NUMBER,NUM_OF_CHILDREN,LABEL,TITLE,DESCRIPTION,PARENT_GUID,LOW_GRADE,HIGH_GRADE,AB_GUID,PP_GUID,PP_PARENT_GUID,PP_ID,PP_PARENT_ID,RESERVED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_SC_STU_COMMENT",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,STUDENT_ID,COMPETENCY_GROUP,COMPETENCY_NUMBER,MARKING_PERIOD,COMMENT_TYPE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,STUDENT_ID,COMPETENCY_GROUP,COMPETENCY_NUMBER,MARKING_PERIOD,BUILDING,COMMENT_TYPE,CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_SC_STU_COMP",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,STUDENT_ID,COMPETENCY_GROUP,COMPETENCY_NUMBER,MARKING_PERIOD,MARK_TYPE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,STUDENT_ID,COMPETENCY_GROUP,COMPETENCY_NUMBER,MARKING_PERIOD,BUILDING,MARK_TYPE,MARK_VALUE,MARK_OVERRIDE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_SC_STU_CRS_COMM",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,STUDENT_ID,BUILDING,COURSE,COMPETENCY_GROUP,COMPETENCY_NUMBER,MARKING_PERIOD,COMMENT_TYPE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,STUDENT_ID,BUILDING,COURSE,COMPETENCY_GROUP,COMPETENCY_NUMBER,MARKING_PERIOD,COMMENT_TYPE,CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_SC_STU_CRS_COMP",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,STUDENT_ID,BUILDING,COURSE,COMPETENCY_GROUP,COMPETENCY_NUMBER,MARKING_PERIOD,MARK_TYPE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,STUDENT_ID,BUILDING,COURSE,COMPETENCY_GROUP,COMPETENCY_NUMBER,MARKING_PERIOD,MARK_TYPE,MARK_VALUE,MARK_OVERRIDE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_SC_STU_TAKEN",
    "PKColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,COMPETENCY_GROUP,STAFF_ID,MARKING_PERIOD",
    "TableColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,COMPETENCY_GROUP,STAFF_ID,MARKING_PERIOD,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_SC_STU_TEA",
    "PKColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,STUDENT_ID,COMPETENCY_GROUP",
    "TableColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,STUDENT_ID,COMPETENCY_GROUP,STAFF_ID,OVERRIDE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_SC_STU_TEA_XREF",
    "PKColumns": "",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,STUDENT_ID,COMPETENCY_GROUP,STAFF_ID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_SC_STU_TEXT",
    "PKColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,STUDENT_ID,STAFF_ID,MARKING_PERIOD",
    "TableColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,STUDENT_ID,STAFF_ID,MARKING_PERIOD,STUDENT_TEXT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_SC_STUSTU_TAKEN",
    "PKColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,COMPETENCY_GROUP,STAFF_ID,MARKING_PERIOD,STUDENT_ID",
    "TableColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,COMPETENCY_GROUP,STAFF_ID,MARKING_PERIOD,STUDENT_ID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_SC_TEA_COMP",
    "PKColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,COMPETENCY_GROUP,DEFAULT_ASSIGNMENT,STAFF_ID",
    "TableColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,COMPETENCY_GROUP,DEFAULT_ASSIGNMENT,STAFF_ID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_STATE_COURSES",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,STATE_CODE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,STATE_CODE,DESCRIPTION,ABBREV_COURSE_NAME,FLAG_01,FLAG_02,FLAG_03,FLAG_04,FLAG_05,FLAG_06,FLAG_07,FLAG_08,FLAG_09,FLAG_10,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_STU_ABSENCES",
    "PKColumns": "DISTRICT,STUDENT_ID,SECTION_KEY,COURSE_SESSION,MARKING_PERIOD,ABSENCE_TYPE",
    "TableColumns": "DISTRICT,STUDENT_ID,SECTION_KEY,COURSE_SESSION,MARKING_PERIOD,ABSENCE_TYPE,ABSENCE_VALUE,OVERRIDE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_STU_BLDG_TYPE",
    "PKColumns": "DISTRICT,STUDENT_ID,SECTION_KEY,COURSE_SESSION,BLDG_TYPE",
    "TableColumns": "DISTRICT,STUDENT_ID,SECTION_KEY,COURSE_SESSION,BLDG_TYPE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_STU_COMMENTS",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,STUDENT_ID,SEQUENCE_NUM",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,STUDENT_ID,SEQUENCE_NUM,TRN_COMMENT,EXCLUDE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_STU_CRS_DATES",
    "PKColumns": "DISTRICT,STUDENT_ID,SECTION_KEY,COURSE_SESSION,START_DATE",
    "TableColumns": "DISTRICT,STUDENT_ID,SECTION_KEY,COURSE_SESSION,START_DATE,END_DATE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_STU_CRSEQU_ABS",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,STUDENT_ID,STATE_ID,SECTION_KEY,COURSE_SESSION,ABSENCE_TYPE,MARKING_PERIOD",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,STUDENT_ID,STATE_ID,SECTION_KEY,COURSE_SESSION,ABSENCE_TYPE,MARKING_PERIOD,ABSENCE_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_STU_CRSEQU_CRD",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,STUDENT_ID,STATE_ID,SECTION_KEY,COURSE_SESSION",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,STUDENT_ID,STATE_ID,SECTION_KEY,COURSE_SESSION,EQUIV_SEQUENCE,ATT_CREDIT,EARN_OVERRIDE,EARN_CREDIT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_STU_CRSEQU_MARK",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,STUDENT_ID,STATE_ID,SECTION_KEY,COURSE_SESSION,DEST_MARK_TYPE,DESTINATION_MP",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,STUDENT_ID,STATE_ID,SECTION_KEY,COURSE_SESSION,DEST_MARK_TYPE,DESTINATION_MP,SOURCE_MARK_TYPE,SOURCE_MP,MARK_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_STU_EXCLUDE_BUILDING_TYPE",
    "PKColumns": "DISTRICT,STUDENT_ID,SECTION_KEY,COURSE_SESSION,BLDG_TYPE",
    "TableColumns": "DISTRICT,STUDENT_ID,SECTION_KEY,COURSE_SESSION,BLDG_TYPE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_STU_GPA",
    "PKColumns": "DISTRICT,STUDENT_ID,GPA_TYPE,SCHOOL_YEAR,RUN_TERM_YEAR",
    "TableColumns": "DISTRICT,STUDENT_ID,GPA_TYPE,SCHOOL_YEAR,RUN_TERM_YEAR,BUILDING,GRADE,NEEDS_RECALC,OVERRIDE,CUR_GPA_CALC_DATE,CUR_GPA,CUR_QUALITY_POINTS,CUR_ADD_ON_POINTS,CUR_ATT_CREDIT,CUR_EARN_CREDIT,CUR_RNK_CALC_DATE,CUR_RANK,CUR_PERCENTILE,CUR_DECILE,CUR_QUINTILE,CUR_QUARTILE,CUR_RANK_GPA,CUM_GPA_CALC_DATE,CUM_GPA,CUM_QUALITY_POINTS,CUM_ADD_ON_POINTS,CUM_ATT_CREDIT,CUM_EARN_CREDIT,CUM_RNK_CALC_DATE,CUM_RANK,CUM_PERCENTILE,CUM_DECILE,CUM_QUINTILE,CUM_QUARTILE,CUM_RANK_GPA,CUR_RANK_QUAL_PTS,CUM_RANK_QUAL_PTS,BLDG_OVERRIDE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_STU_GRAD",
    "PKColumns": "DISTRICT,STUDENT_ID,REQUIRE_CODE",
    "TableColumns": "DISTRICT,STUDENT_ID,REQUIRE_CODE,SUBJ_AREA_CREDIT,CUR_ATT_CREDITS,CUR_EARN_CREDITS,SUBJ_AREA_CRD_WAV,CUR_ATT_CRD_WAV,CUR_EARN_CRD_WAV,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_STU_GRAD_AREA",
    "PKColumns": "DISTRICT,STUDENT_ID,SECTION_KEY,COURSE_SESSION,REQUIRE_CODE",
    "TableColumns": "DISTRICT,STUDENT_ID,SECTION_KEY,COURSE_SESSION,REQUIRE_CODE,CODE_OVERRIDE,SUBJ_AREA_CREDIT,CREDIT_OVERRIDE,WAIVED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_STU_GRAD_VALUE",
    "PKColumns": "DISTRICT,STUDENT_ID,REQUIRE_CODE",
    "TableColumns": "DISTRICT,STUDENT_ID,REQUIRE_CODE,VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_STU_HDR",
    "PKColumns": "DISTRICT,STUDENT_ID,SECTION_KEY,COURSE_SESSION",
    "TableColumns": "DISTRICT,STUDENT_ID,SECTION_KEY,COURSE_SESSION,RC_STATUS,ATT_CREDIT,ATT_OVERRIDE,ATT_OVR_REASON,EARN_CREDIT,EARN_OVERRIDE,ERN_OVR_REASON,STATE_CRS_EQUIV,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_STU_HDR_SUBJ",
    "PKColumns": "DISTRICT,STUDENT_ID,SECTION_KEY,COURSE_SESSION,SUBJECT_AREA",
    "TableColumns": "DISTRICT,STUDENT_ID,SECTION_KEY,COURSE_SESSION,SUBJECT_AREA,VALUE,OVERRIDE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_STU_HONOR",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,STUDENT_ID,HONOR_TYPE,RC_RUN",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,STUDENT_ID,HONOR_TYPE,RC_RUN,QUALIFIED,DISQUAL_REASON,HONOR_GPA,HONOR_CREDIT,HONOR_POINTS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_STU_MARKS",
    "PKColumns": "DISTRICT,STUDENT_ID,SECTION_KEY,COURSE_SESSION,MARKING_PERIOD,MARK_TYPE",
    "TableColumns": "DISTRICT,STUDENT_ID,SECTION_KEY,COURSE_SESSION,MARKING_PERIOD,MARK_TYPE,MARK_VALUE,OVERRIDE,RAW_MARK_VALUE,OVERRIDE_REASON,OVERRIDE_NOTES,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_STU_MP",
    "PKColumns": "DISTRICT,STUDENT_ID,SECTION_KEY,COURSE_SESSION,MARKING_PERIOD",
    "TableColumns": "DISTRICT,STUDENT_ID,SECTION_KEY,COURSE_SESSION,MARKING_PERIOD,ATT_CREDIT,ATT_OVERRIDE,ATT_OVR_REASON,EARN_CREDIT,EARN_OVERRIDE,ERN_OVR_REASON,TRAIL_FLAG,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_STU_MP_COMMENTS",
    "PKColumns": "DISTRICT,STUDENT_ID,SECTION_KEY,COURSE_SESSION,MARKING_PERIOD,COMMENT_TYPE",
    "TableColumns": "DISTRICT,STUDENT_ID,SECTION_KEY,COURSE_SESSION,MARKING_PERIOD,COMMENT_TYPE,CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_STU_OUT_COURSE",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,STUDENT_ID,TRANSFER_SEQUENCE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,STUDENT_ID,BUILDING,TRANSFER_SEQUENCE,STATE_BUILDING,BUILDING_NAME,OUTSIDE_COURSE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_STU_RUBRIC_COMP_SCORE",
    "PKColumns": "DISTRICT,RUBRIC_NUMBER,BUILDING,COMPETENCY_GROUP,STAFF_ID,ASMT_NUMBER,CRITERIA_NUMBER,STUDENT_ID",
    "TableColumns": "DISTRICT,RUBRIC_NUMBER,BUILDING,COMPETENCY_GROUP,STAFF_ID,ASMT_NUMBER,CRITERIA_NUMBER,STUDENT_ID,RUBRIC_SCORE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_STU_RUBRIC_COMP_SCORE_HIST",
    "PKColumns": "DISTRICT,RUBRIC_NUMBER,BUILDING,COMPETENCY_GROUP,STAFF_ID,ASMT_NUMBER,CRITERIA_NUMBER,STUDENT_ID,SCORE_CHANGED_DATE",
    "TableColumns": "DISTRICT,RUBRIC_NUMBER,BUILDING,COMPETENCY_GROUP,STAFF_ID,ASMT_NUMBER,CRITERIA_NUMBER,STUDENT_ID,SCORE_CHANGED_DATE,OLD_VALUE,NEW_VALUE,CHANGE_TYPE,PRIVATE_NOTES,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_STU_RUBRIC_SCORE",
    "PKColumns": "DISTRICT,RUBRIC_NUMBER,SECTION_KEY,COURSE_SESSION,ASMT_NUMBER,CRITERIA_NUMBER,STUDENT_ID",
    "TableColumns": "DISTRICT,RUBRIC_NUMBER,SECTION_KEY,COURSE_SESSION,ASMT_NUMBER,CRITERIA_NUMBER,STUDENT_ID,RUBRIC_SCORE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_STU_RUBRIC_SCORE_HIST",
    "PKColumns": "DISTRICT,RUBRIC_NUMBER,SECTION_KEY,COURSE_SESSION,ASMT_NUMBER,CRITERIA_NUMBER,STUDENT_ID,SCORE_CHANGED_DATE",
    "TableColumns": "DISTRICT,RUBRIC_NUMBER,SECTION_KEY,COURSE_SESSION,ASMT_NUMBER,CRITERIA_NUMBER,STUDENT_ID,SCORE_CHANGED_DATE,OLD_VALUE,NEW_VALUE,CHANGE_TYPE,PRIVATE_NOTES,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_STU_TAG_ALERT",
    "PKColumns": "DISTRICT,STUDENT_ID,REQ_GROUP,REQUIRE_CODE",
    "TableColumns": "DISTRICT,STUDENT_ID,REQ_GROUP,REQUIRE_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_STU_TEXT",
    "PKColumns": "DISTRICT,STUDENT_ID,SECTION_KEY,COURSE_SESSION,MARKING_PERIOD",
    "TableColumns": "DISTRICT,BUILDING,STUDENT_ID,SCHOOL_YEAR,SECTION_KEY,COURSE_SESSION,STAFF_ID,MARKING_PERIOD,COMMENT_TEXT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_STU_USER",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,STUDENT_ID,SCREEN_NUMBER,FIELD_NUMBER",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,STUDENT_ID,SCREEN_NUMBER,FIELD_NUMBER,FIELD_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_STU_XFER_BLDGS",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,STUDENT_ID,TRANSFER_SEQUENCE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,STUDENT_ID,BUILDING,TRANSFER_SEQUENCE,STATE_BUILDING,BUILDING_NAME,GRADE,ABBREVIATION,STREET1,STREET2,CITY,STATE,ZIP_CODE,COUNTRY,PHONE,FAX,PRINCIPAL,BUILDING_TYPE,TRANSFER_COMMENT,STATE_CODE_EQUIV,ENTRY_DATE,WITHDRAWAL_DATE,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_STU_XFER_RUNS",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,STUDENT_ID,TRANSFER_SEQUENCE,RC_RUN",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,STUDENT_ID,TRANSFER_SEQUENCE,RC_RUN,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_TRN_PRINT_HDR",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,GROUP_BY,GRADE,RUN_TERM_YEAR",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,GROUP_BY,GRADE,RUN_TERM_YEAR,RUN_DATE,TRN_PRINT_KEY,BLDG_NAME,STREET1,STREET2,CITY,STATE,ZIP,PRINCIPAL,PHONE,CEEB_NUMBER,HEADER_TEXT,FOOTER_TEXT,DATA_TITLE_01,DATA_TITLE_02,DATA_TITLE_03,DATA_TITLE_04,DATA_TITLE_05,DATA_TITLE_06,DATA_TITLE_07,DATA_TITLE_08,DATA_TITLE_09,DATA_TITLE_10,DATA_TITLE_11,DATA_TITLE_12,DATA_TITLE_13,DATA_TITLE_14,DATA_TITLE_15,DATA_TITLE_16,DATA_TITLE_17,DATA_TITLE_18,DATA_TITLE_19,DATA_TITLE_20,DATA_TITLE_21,DATA_TITLE_22,DATA_TITLE_23,DATA_TITLE_24,DATA_TITLE_25,DATA_TITLE_26,DATA_TITLE_27,DATA_TITLE_28,DATA_TITLE_29,DATA_TITLE_30,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_TRN_PRT_CRS_UD",
    "PKColumns": "DISTRICT,MR_TRN_PRINT_KEY,SECTION_KEY",
    "TableColumns": "DISTRICT,MR_TRN_PRINT_KEY,SECTION_KEY,FIELD_LABEL01,FIELD_LABEL02,FIELD_LABEL03,FIELD_LABEL04,FIELD_LABEL05,FIELD_LABEL06,FIELD_LABEL07,FIELD_LABEL08,FIELD_LABEL09,FIELD_LABEL10,FIELD_VALUE01,FIELD_VALUE02,FIELD_VALUE03,FIELD_VALUE04,FIELD_VALUE05,FIELD_VALUE06,FIELD_VALUE07,FIELD_VALUE08,FIELD_VALUE09,FIELD_VALUE10,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_TRN_PRT_STU_ACT",
    "PKColumns": "DISTRICT,MR_TRN_PRINT_KEY,STUDENT_ID",
    "TableColumns": "DISTRICT,MR_TRN_PRINT_KEY,STUDENT_ID,ACTIVITY01,ACTIVITY02,ACTIVITY03,ACTIVITY04,ACTIVITY05,ACTIVITY06,ACTIVITY07,ACTIVITY08,ACTIVITY09,ACTIVITY10,ACTIVITY11,ACTIVITY12,ACTIVITY13,ACTIVITY14,ACTIVITY15,ACTIVITY16,ACTIVITY17,ACTIVITY18,ACTIVITY19,ACTIVITY20,ACTIVITY21,ACTIVITY22,ACTIVITY23,ACTIVITY24,ACTIVITY25,ACTIVITY26,ACTIVITY27,ACTIVITY28,ACTIVITY29,ACTIVITY30,ACTIVITY_YEARS01,ACTIVITY_YEARS02,ACTIVITY_YEARS03,ACTIVITY_YEARS04,ACTIVITY_YEARS05,ACTIVITY_YEARS06,ACTIVITY_YEARS07,ACTIVITY_YEARS08,ACTIVITY_YEARS09,ACTIVITY_YEARS10,ACTIVITY_YEARS11,ACTIVITY_YEARS12,ACTIVITY_YEARS13,ACTIVITY_YEARS14,ACTIVITY_YEARS15,ACTIVITY_YEARS16,ACTIVITY_YEARS17,ACTIVITY_YEARS18,ACTIVITY_YEARS19,ACTIVITY_YEARS20,ACTIVITY_YEARS21,ACTIVITY_YEARS22,ACTIVITY_YEARS23,ACTIVITY_YEARS24,ACTIVITY_YEARS25,ACTIVITY_YEARS26,ACTIVITY_YEARS27,ACTIVITY_YEARS28,ACTIVITY_YEARS29,ACTIVITY_YEARS30,ACTIVITY_COMMENTS01,ACTIVITY_COMMENTS02,ACTIVITY_COMMENTS03,ACTIVITY_COMMENTS04,ACTIVITY_COMMENTS05,ACTIVITY_COMMENTS06,ACTIVITY_COMMENTS07,ACTIVITY_COMMENTS08,ACTIVITY_COMMENTS09,ACTIVITY_COMMENTS10,ACTIVITY_COMMENTS11,ACTIVITY_COMMENTS12,ACTIVITY_COMMENTS13,ACTIVITY_COMMENTS14,ACTIVITY_COMMENTS15,ACTIVITY_COMMENTS16,ACTIVITY_COMMENTS17,ACTIVITY_COMMENTS18,ACTIVITY_COMMENTS19,ACTIVITY_COMMENTS20,ACTIVITY_COMMENTS21,ACTIVITY_COMMENTS22,ACTIVITY_COMMENTS23,ACTIVITY_COMMENTS24,ACTIVITY_COMMENTS25,ACTIVITY_COMMENTS26,ACTIVITY_COMMENTS27,ACTIVITY_COMMENTS28,ACTIVITY_COMMENTS29,ACTIVITY_COMMENTS30,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_TRN_PRT_STU_BRK",
    "PKColumns": "DISTRICT,MR_TRN_PRINT_KEY,STUDENT_ID,SCHOOL_YEAR,RUN_TERM_YEAR",
    "TableColumns": "DISTRICT,MR_TRN_PRINT_KEY,STUDENT_ID,SCHOOL_YEAR,RUN_TERM_YEAR,DISPLAY_YEAR,STUDENT_GRADE,CUR_GPA,CUM_GPA,BUILDING,BLDG_NAME,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_TRN_PRT_STU_COM",
    "PKColumns": "DISTRICT,MR_TRN_PRINT_KEY,STUDENT_ID",
    "TableColumns": "DISTRICT,MR_TRN_PRINT_KEY,STUDENT_ID,COMMENT01,COMMENT02,COMMENT03,COMMENT04,COMMENT05,COMMENT06,COMMENT07,COMMENT08,COMMENT09,COMMENT10,COMMENT11,COMMENT12,COMMENT13,COMMENT14,COMMENT15,COMMENT16,COMMENT17,COMMENT18,COMMENT19,COMMENT20,COMMENT21,COMMENT22,COMMENT23,COMMENT24,COMMENT25,COMMENT26,COMMENT27,COMMENT28,COMMENT29,COMMENT30,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_TRN_PRT_STU_DET",
    "PKColumns": "DISTRICT,MR_TRN_PRINT_KEY,STUDENT_ID,SECTION_KEY,COURSE_SESSION,RUN_TERM_YEAR",
    "TableColumns": "DISTRICT,MR_TRN_PRINT_KEY,STUDENT_ID,SECTION_KEY,COURSE_BUILDING,COURSE,COURSE_SECTION,COURSE_SESSION,RUN_TERM_YEAR,SCHOOL_YEAR,STUDENT_GRADE,DESCRIPTION,CRS_PERIOD,COURSE_LEVEL,PRIMARY_STAFF_ID,STAFF_NAME,ROOM_ID,ATTEMPTED_CREDIT,EARNED_CREDIT,DEPARTMENT,DEPT_DESCR,TRN_DATA_VALUE_01,TRN_DATA_VALUE_02,TRN_DATA_VALUE_03,TRN_DATA_VALUE_04,TRN_DATA_VALUE_05,TRN_DATA_VALUE_06,TRN_DATA_VALUE_07,TRN_DATA_VALUE_08,TRN_DATA_VALUE_09,TRN_DATA_VALUE_10,TRN_DATA_VALUE_11,TRN_DATA_VALUE_12,TRN_DATA_VALUE_13,TRN_DATA_VALUE_14,TRN_DATA_VALUE_15,TRN_DATA_VALUE_16,TRN_DATA_VALUE_17,TRN_DATA_VALUE_18,TRN_DATA_VALUE_19,TRN_DATA_VALUE_20,TRN_DATA_VALUE_21,TRN_DATA_VALUE_22,TRN_DATA_VALUE_23,TRN_DATA_VALUE_24,TRN_DATA_VALUE_25,TRN_DATA_VALUE_26,TRN_DATA_VALUE_27,TRN_DATA_VALUE_28,TRN_DATA_VALUE_29,TRN_DATA_VALUE_30,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_TRN_PRT_STU_HDR",
    "PKColumns": "DISTRICT,TRN_PRINT_KEY,STUDENT_ID",
    "TableColumns": "DISTRICT,TRN_PRINT_KEY,STUDENT_ID,STUDENT_NAME,BUILDING,GRADE,TRACK,COUNSELOR,HOUSE_TEAM,HOMEROOM_PRIMARY,BIRTHDATE,GRADUATION_YEAR,GRADUATION_DATE,GENDER,GUARDIAN_NAME,PHONE,APARTMENT,COMPLEX,STREET_NUMBER,STREET_PREFIX,STREET_NAME,STREET_SUFFIX,STREET_TYPE,CITY,STATE,ZIP,DAILY_ATT_DESCR_01,DAILY_ATT_DESCR_02,DAILY_ATT_DESCR_03,DAILY_ATT_DESCR_04,DAILY_ATT_DESCR_05,DAILY_ATT_DESCR_06,DAILY_ATT_DESCR_07,DAILY_ATT_DESCR_08,DAILY_ATT_DESCR_09,DAILY_ATT_DESCR_10,DAILY_ATT_TOT_01,DAILY_ATT_TOT_02,DAILY_ATT_TOT_03,DAILY_ATT_TOT_04,DAILY_ATT_TOT_05,DAILY_ATT_TOT_06,DAILY_ATT_TOT_07,DAILY_ATT_TOT_08,DAILY_ATT_TOT_09,DAILY_ATT_TOT_10,GPA_TYPE_01,GPA_TYPE_02,GPA_TYPE_03,GPA_TYPE_04,GPA_TYPE_05,GPA_TYPE_06,GPA_TYPE_07,GPA_TYPE_08,GPA_TYPE_09,GPA_TYPE_10,GPA_DESCR_01,GPA_DESCR_02,GPA_DESCR_03,GPA_DESCR_04,GPA_DESCR_05,GPA_DESCR_06,GPA_DESCR_07,GPA_DESCR_08,GPA_DESCR_09,GPA_DESCR_10,GPA_CUM_01,GPA_CUM_02,GPA_CUM_03,GPA_CUM_04,GPA_CUM_05,GPA_CUM_06,GPA_CUM_07,GPA_CUM_08,GPA_CUM_09,GPA_CUM_10,GPA_RANK_01,GPA_RANK_02,GPA_RANK_03,GPA_RANK_04,GPA_RANK_05,GPA_RANK_06,GPA_RANK_07,GPA_RANK_08,GPA_RANK_09,GPA_RANK_10,GPA_PERCENTILE_01,GPA_PERCENTILE_02,GPA_PERCENTILE_03,GPA_PERCENTILE_04,GPA_PERCENTILE_05,GPA_PERCENTILE_06,GPA_PERCENTILE_07,GPA_PERCENTILE_08,GPA_PERCENTILE_09,GPA_PERCENTILE_10,GPA_DECILE_01,GPA_DECILE_02,GPA_DECILE_03,GPA_DECILE_04,GPA_DECILE_05,GPA_DECILE_06,GPA_DECILE_07,GPA_DECILE_08,GPA_DECILE_09,GPA_DECILE_10,GPA_QUARTILE_01,GPA_QUARTILE_02,GPA_QUARTILE_03,GPA_QUARTILE_04,GPA_QUARTILE_05,GPA_QUARTILE_06,GPA_QUARTILE_07,GPA_QUARTILE_08,GPA_QUARTILE_09,GPA_QUARTILE_10,GPA_QUINTILE_01,GPA_QUINTILE_02,GPA_QUINTILE_03,GPA_QUINTILE_04,GPA_QUINTILE_05,GPA_QUINTILE_06,GPA_QUINTILE_07,GPA_QUINTILE_08,GPA_QUINTILE_09,GPA_QUINTILE_10,GPA_CLASS_SIZE_01,GPA_CLASS_SIZE_02,GPA_CLASS_SIZE_03,GPA_CLASS_SIZE_04,GPA_CLASS_SIZE_05,GPA_CLASS_SIZE_06,GPA_CLASS_SIZE_07,GPA_CLASS_SIZE_08,GPA_CLASS_SIZE_09,GPA_CLASS_SIZE_10,REPORT_TEMPLATE,GENDER_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_TRN_PRT_STU_LTD",
    "PKColumns": "DISTRICT,MR_TRN_PRINT_KEY,STUDENT_ID,TEST_CODE,TEST_DATE",
    "TableColumns": "DISTRICT,MR_TRN_PRINT_KEY,STUDENT_ID,TEST_CODE,TEST_DATE,LTDB_TITLE_01,LTDB_TITLE_02,LTDB_TITLE_03,LTDB_TITLE_04,LTDB_TITLE_05,LTDB_TITLE_06,LTDB_TITLE_07,LTDB_TITLE_08,LTDB_TITLE_09,LTDB_TITLE_10,LTDB_TITLE_11,LTDB_TITLE_12,LTDB_TITLE_13,LTDB_TITLE_14,LTDB_TITLE_15,LTDB_TITLE_16,LTDB_TITLE_17,LTDB_TITLE_18,LTDB_TITLE_19,LTDB_TITLE_20,LTDB_TITLE_21,LTDB_TITLE_22,LTDB_TITLE_23,LTDB_TITLE_24,LTDB_TITLE_25,LTDB_TITLE_26,LTDB_TITLE_27,LTDB_TITLE_28,LTDB_TITLE_29,LTDB_TITLE_30,SCORE01,SCORE02,SCORE03,SCORE04,SCORE05,SCORE06,SCORE07,SCORE08,SCORE09,SCORE10,SCORE11,SCORE12,SCORE13,SCORE14,SCORE15,SCORE16,SCORE17,SCORE18,SCORE19,SCORE20,SCORE21,SCORE22,SCORE23,SCORE24,SCORE25,SCORE26,SCORE27,SCORE28,SCORE29,SCORE30,TEST_DATE01,TEST_DATE02,TEST_DATE03,TEST_DATE04,TEST_DATE05,TEST_DATE06,TEST_DATE07,TEST_DATE08,TEST_DATE09,TEST_DATE10,TEST_DATE11,TEST_DATE12,TEST_DATE13,TEST_DATE14,TEST_DATE15,TEST_DATE16,TEST_DATE17,TEST_DATE18,TEST_DATE19,TEST_DATE20,TEST_DATE21,TEST_DATE22,TEST_DATE23,TEST_DATE24,TEST_DATE25,TEST_DATE26,TEST_DATE27,TEST_DATE28,TEST_DATE29,TEST_DATE30,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_TRN_PRT_STU_MED",
    "PKColumns": "DISTRICT,MR_TRN_PRINT_KEY,STUDENT_ID,SHOT_ORDER,SHOT_CODE",
    "TableColumns": "DISTRICT,MR_TRN_PRINT_KEY,STUDENT_ID,SHOT_ORDER,SHOT_CODE,SHOT_TITLE,EXEMPT,HAD_DISEASE,SHOT_DATE_01,SHOT_DATE_02,SHOT_DATE_03,SHOT_DATE_04,SHOT_DATE_05,SHOT_DATE_06,SHOT_DATE_07,SHOT_DATE_08,SHOT_DATE_09,SHOT_DATE_10,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_TRN_PRT_STU_REQ",
    "PKColumns": "DISTRICT,MR_TRN_PRINT_KEY,STUDENT_ID",
    "TableColumns": "DISTRICT,MR_TRN_PRINT_KEY,STUDENT_ID,REQ_GROUP,GRADUATION_YEAR,REQUIRE_CODE01,REQUIRE_CODE02,REQUIRE_CODE03,REQUIRE_CODE04,REQUIRE_CODE05,REQUIRE_CODE06,REQUIRE_CODE07,REQUIRE_CODE08,REQUIRE_CODE09,REQUIRE_CODE10,REQUIRE_CODE11,REQUIRE_CODE12,REQUIRE_CODE13,REQUIRE_CODE14,REQUIRE_CODE15,REQUIRE_CODE16,REQUIRE_CODE17,REQUIRE_CODE18,REQUIRE_CODE19,REQUIRE_CODE20,REQUIRE_CODE21,REQUIRE_CODE22,REQUIRE_CODE23,REQUIRE_CODE24,REQUIRE_CODE25,REQUIRE_CODE26,REQUIRE_CODE27,REQUIRE_CODE28,REQUIRE_CODE29,REQUIRE_CODE30,REQUIRE_DESC01,REQUIRE_DESC02,REQUIRE_DESC03,REQUIRE_DESC04,REQUIRE_DESC05,REQUIRE_DESC06,REQUIRE_DESC07,REQUIRE_DESC08,REQUIRE_DESC09,REQUIRE_DESC10,REQUIRE_DESC11,REQUIRE_DESC12,REQUIRE_DESC13,REQUIRE_DESC14,REQUIRE_DESC15,REQUIRE_DESC16,REQUIRE_DESC17,REQUIRE_DESC18,REQUIRE_DESC19,REQUIRE_DESC20,REQUIRE_DESC21,REQUIRE_DESC22,REQUIRE_DESC23,REQUIRE_DESC24,REQUIRE_DESC25,REQUIRE_DESC26,REQUIRE_DESC27,REQUIRE_DESC28,REQUIRE_DESC29,REQUIRE_DESC30,SUBJ_AREA_CREDIT01,SUBJ_AREA_CREDIT02,SUBJ_AREA_CREDIT03,SUBJ_AREA_CREDIT04,SUBJ_AREA_CREDIT05,SUBJ_AREA_CREDIT06,SUBJ_AREA_CREDIT07,SUBJ_AREA_CREDIT08,SUBJ_AREA_CREDIT09,SUBJ_AREA_CREDIT10,SUBJ_AREA_CREDIT11,SUBJ_AREA_CREDIT12,SUBJ_AREA_CREDIT13,SUBJ_AREA_CREDIT14,SUBJ_AREA_CREDIT15,SUBJ_AREA_CREDIT16,SUBJ_AREA_CREDIT17,SUBJ_AREA_CREDIT18,SUBJ_AREA_CREDIT19,SUBJ_AREA_CREDIT20,SUBJ_AREA_CREDIT21,SUBJ_AREA_CREDIT22,SUBJ_AREA_CREDIT23,SUBJ_AREA_CREDIT24,SUBJ_AREA_CREDIT25,SUBJ_AREA_CREDIT26,SUBJ_AREA_CREDIT27,SUBJ_AREA_CREDIT28,SUBJ_AREA_CREDIT29,SUBJ_AREA_CREDIT30,CUR_ATT_CREDITS01,CUR_ATT_CREDITS02,CUR_ATT_CREDITS03,CUR_ATT_CREDITS04,CUR_ATT_CREDITS05,CUR_ATT_CREDITS06,CUR_ATT_CREDITS07,CUR_ATT_CREDITS08,CUR_ATT_CREDITS09,CUR_ATT_CREDITS10,CUR_ATT_CREDITS11,CUR_ATT_CREDITS12,CUR_ATT_CREDITS13,CUR_ATT_CREDITS14,CUR_ATT_CREDITS15,CUR_ATT_CREDITS16,CUR_ATT_CREDITS17,CUR_ATT_CREDITS18,CUR_ATT_CREDITS19,CUR_ATT_CREDITS20,CUR_ATT_CREDITS21,CUR_ATT_CREDITS22,CUR_ATT_CREDITS23,CUR_ATT_CREDITS24,CUR_ATT_CREDITS25,CUR_ATT_CREDITS26,CUR_ATT_CREDITS27,CUR_ATT_CREDITS28,CUR_ATT_CREDITS29,CUR_ATT_CREDITS30,CUR_EARN_CREDITS01,CUR_EARN_CREDITS02,CUR_EARN_CREDITS03,CUR_EARN_CREDITS04,CUR_EARN_CREDITS05,CUR_EARN_CREDITS06,CUR_EARN_CREDITS07,CUR_EARN_CREDITS08,CUR_EARN_CREDITS09,CUR_EARN_CREDITS10,CUR_EARN_CREDITS11,CUR_EARN_CREDITS12,CUR_EARN_CREDITS13,CUR_EARN_CREDITS14,CUR_EARN_CREDITS15,CUR_EARN_CREDITS16,CUR_EARN_CREDITS17,CUR_EARN_CREDITS18,CUR_EARN_CREDITS19,CUR_EARN_CREDITS20,CUR_EARN_CREDITS21,CUR_EARN_CREDITS22,CUR_EARN_CREDITS23,CUR_EARN_CREDITS24,CUR_EARN_CREDITS25,CUR_EARN_CREDITS26,CUR_EARN_CREDITS27,CUR_EARN_CREDITS28,CUR_EARN_CREDITS29,CUR_EARN_CREDITS30,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_TRN_VIEW_ATT",
    "PKColumns": "DISTRICT,BUILDING,TYPE,GRADE,GROUP_BY,VIEW_ORDER",
    "TableColumns": "DISTRICT,BUILDING,TYPE,GRADE,GROUP_BY,ATT_VIEW_TYPE,VIEW_ORDER,ATT_TITLE,ATT_VIEW_INTERVAL,ATT_VIEW_SUM_BY,ATT_VIEW_CODE_GRP,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_TRN_VIEW_BLDTYP",
    "PKColumns": "DISTRICT,BUILDING,TYPE,GRADE,GROUP_BY,BLDG_TYPE",
    "TableColumns": "DISTRICT,BUILDING,TYPE,GRADE,GROUP_BY,BLDG_TYPE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_TRN_VIEW_DET",
    "PKColumns": "DISTRICT,BUILDING,TYPE,GRADE,GROUP_BY,RUN_TERM_YEAR,VIEW_SEQUENCE",
    "TableColumns": "DISTRICT,BUILDING,TYPE,GRADE,GROUP_BY,RUN_TERM_YEAR,VIEW_SEQUENCE,TITLE,VIEW_ORDER,SLOT_TYPE,SLOT_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_TRN_VIEW_GPA",
    "PKColumns": "DISTRICT,BUILDING,TYPE,GRADE,GROUP_BY,GPA_TYPE",
    "TableColumns": "DISTRICT,BUILDING,TYPE,GRADE,GROUP_BY,GPA_TYPE,VIEW_ORDER,GPA_TITLE,INCLUDE_RANK,INCLUDE_PERCENTILE,INCLUDE_DECILE,INCLUDE_QUARTILE,INCLUDE_QUINTILE,GPA_LEVEL,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_TRN_VIEW_HDR",
    "PKColumns": "DISTRICT,BUILDING,TYPE,GRADE,GROUP_BY",
    "TableColumns": "DISTRICT,BUILDING,TYPE,GRADE,GROUP_BY,DISPLAY_ATTCREDIT,DISPLAY_ERNCREDIT,DISPLAY_CRSLEVEL,DISPLAY_CRSTYPE,STU_ADDRESS_TYPE,PRINT_BLDG_INFO,PRINT_STU_DATA,PRINT_CREDIT_SUM,CRS_AREA_GPA,PRINT_CLASS_RANK,PRINT_COMMENTS,PRINT_ACTIVITIES,PRINT_GRAD_REQ,CEEB_NUMBER,HEADER_TEXT,FOOTER_TEXT,REPORT_TEMPLATE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_TRN_VIEW_LTDB",
    "PKColumns": "DISTRICT,BUILDING,TYPE,GRADE,GROUP_BY,VIEW_ORDER",
    "TableColumns": "DISTRICT,BUILDING,TYPE,GRADE,GROUP_BY,VIEW_ORDER,LABEL,TEST_CODE,TEST_LEVEL,TEST_FORM,SUBTEST,SCORE_CODE,PRINT_TYPE,PRINT_NUMBER,PRINT_BLANK,GROUP_SCORES,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_TRN_VIEW_MED",
    "PKColumns": "DISTRICT,BUILDING,TYPE,GRADE,GROUP_BY,SERIES_SHOT",
    "TableColumns": "DISTRICT,BUILDING,TYPE,GRADE,GROUP_BY,SERIES_SHOT,VIEW_ORDER,SHOT_TITLE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_TRN_VIEW_MPS",
    "PKColumns": "DISTRICT,BUILDING,TYPE,GRADE,GROUP_BY,RUN_TERM_YEAR,VIEW_SEQUENCE,MARKING_PERIOD",
    "TableColumns": "DISTRICT,BUILDING,TYPE,GRADE,GROUP_BY,RUN_TERM_YEAR,VIEW_SEQUENCE,MARKING_PERIOD,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_TRN_VIEW_MS",
    "PKColumns": "DISTRICT,BUILDING,GRADE,VIEW_ID",
    "TableColumns": "DISTRICT,BUILDING,GRADE,VIEW_ID,VIEW_ORDER,TABLE_NAME,COLUMN_NAME,SCREEN_NUMBER,FIELD_NUMBER,DEFAULT_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_TRN_VIEW_UD",
    "PKColumns": "DISTRICT,BUILDING,TYPE,GRADE,GROUP_BY,RUN_TERM_YEAR,SCREEN_TYPE,SCREEN_NUMBER,FIELD_NUMBER",
    "TableColumns": "DISTRICT,BUILDING,TYPE,GRADE,GROUP_BY,RUN_TERM_YEAR,SCREEN_TYPE,SCREEN_NUMBER,FIELD_NUMBER,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_TX_CREDIT_SETUP",
    "PKColumns": "DISTRICT,BUILDING,SCHOOL_YEAR",
    "TableColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,PROCESS_EOC,EOC_MARK,INCOMPLETE_EOC,EOC_MARKTYPE_PROC,EOC_ALT_MARK,MIN_COHORT_YEAR,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MR_YEAREND_RUN",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,RUN_KEY",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,RUN_KEY,RUN_DATE,RUN_STATUS,CLEAN_MR_DATA,BUILDING_LIST,PURGE_BLD_YEAR,PURGE_STU_YEAR,PURGE_IPR_YEAR,PURGE_GB_ASMT_YEAR,PURGE_GB_SCORE_YEAR,RESTORE_KEY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MRTB_DISQUALIFY_REASON",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MRTB_GB_CATEGORY",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,CATEGORY_ID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MRTB_GB_EXCEPTION",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,EXCLUDE_AVERAGE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MRTB_LEVEL_HDR_PESC_CODE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MRTB_MARKOVR_REASON",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MRTB_ST_CRS_FLAGS",
    "PKColumns": "DISTRICT,FLAG",
    "TableColumns": "DISTRICT,FLAG,LABEL,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MRTB_SUBJ_AREA_SUB",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MSG_BUILDING_SETUP",
    "PKColumns": "DISTRICT,BUILDING,EVENT_CODE",
    "TableColumns": "DISTRICT,BUILDING,EVENT_CODE,EVENT_AVAILABILITY,ALLOW_ESP,ALLOW_TAC,ALLOW_HAC,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MSG_BUILDING_SETUP_ENABLE",
    "PKColumns": "DISTRICT,BUILDING,EVENT_PACKAGE",
    "TableColumns": "DISTRICT,BUILDING,EVENT_PACKAGE,IS_ENABLED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MSG_BUILDING_SETUP_VALUES",
    "PKColumns": "DISTRICT,BUILDING,EVENT_CODE,WORKFLOW_VALUE",
    "TableColumns": "DISTRICT,BUILDING,EVENT_CODE,WORKFLOW_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MSG_DISTRICT_SETUP",
    "PKColumns": "DISTRICT,EVENT_CODE",
    "TableColumns": "DISTRICT,EVENT_CODE,EVENT_AVAILABILITY,ALLOW_ESP,ALLOW_TAC,ALLOW_HAC,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MSG_DISTRICT_SETUP_ENABLE",
    "PKColumns": "DISTRICT,EVENT_PACKAGE",
    "TableColumns": "DISTRICT,EVENT_PACKAGE,IS_ENABLED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MSG_DISTRICT_SETUP_VALUES",
    "PKColumns": "DISTRICT,EVENT_CODE,WORKFLOW_VALUE",
    "TableColumns": "DISTRICT,EVENT_CODE,WORKFLOW_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MSG_EVENT",
    "PKColumns": "DISTRICT,EVENT_CODE",
    "TableColumns": "DISTRICT,EVENT_CODE,EVENT_DESCRIPTION,EVENT_PACKAGE,EVENT_ORDER,ESP_SEC_PACKAGE,ESP_SEC_SUBPACKAGE,ESP_SEC_FEATURE,USE_ESP,USE_TAC,USE_HAC,USE_WATCHLIST,SCHEDULE_POPUP,RESERVED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MSG_IEP_AUDIENCE",
    "PKColumns": "DISTRICT,EVENT_CODE,AUDIENCE",
    "TableColumns": "DISTRICT,EVENT_CODE,AUDIENCE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MSG_SCHEDULE",
    "PKColumns": "DISTRICT,BUILDING,EVENT_CODE",
    "TableColumns": "DISTRICT,BUILDING,EVENT_CODE,TASK_OWNER,SCHEDULE_TYPE,SCHD_TIME,SCHD_DATE,SCHD_INTERVAL,SCHD_DOW,PARAM_KEY,LAST_RUN_DATE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MSG_SUB_EVENT",
    "PKColumns": "DISTRICT,EVENT_CODE,EVENT_SUB_CODE",
    "TableColumns": "DISTRICT,EVENT_CODE,EVENT_SUB_CODE,PNRS_SHORTMESSAGE,PNRS_LONGMESSAGE,PNRS_LONGMESSAGEREMOTE,RESERVED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MSG_USER_PREFERENCE_DET",
    "PKColumns": "DISTRICT,APPLICATION_TYPE,LOGIN_ID,EVENT_CODE",
    "TableColumns": "DISTRICT,APPLICATION_TYPE,LOGIN_ID,EVENT_CODE,SEND_EMAIL,WATCH_NAME,HOME_BUILDING_ONLY,SEND_HIGH_PRIORITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MSG_USER_PREFERENCE_HDR",
    "PKColumns": "DISTRICT,APPLICATION_TYPE,LOGIN_ID",
    "TableColumns": "DISTRICT,APPLICATION_TYPE,LOGIN_ID,DAILY_DIGEST,NO_IEP_LOGIN,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "MSG_VALUE_SPECIFICATION",
    "PKColumns": "DISTRICT,EVENT_CODE",
    "TableColumns": "DISTRICT,EVENT_CODE,VALUE_LABEL,DATA_TYPE,VALIDATION_TABLE,VALIDATION_CODE_COLUMN,VALIDATION_DESCRIPTION_COLUMN,USE_SUBSCRIPTION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "NSE_ADDRESS",
    "PKColumns": "ADDRESS_ID",
    "TableColumns": "ADDRESS_ID,NSE_ID,APARTMENT,COMPLEX,HOUSE_NUMBER,STREET_NAME,STREET_TYPE,DEVELOPMENT,CITY,ADDR_STATE,ZIP,ISMAILING,ISSTUDENT,CONTACT_TYPE,HOUSENO,LASTMODIFIEDBY,LASTMODIFIEDDATE,STREET_PREFIX,STREET_SUFFIX,EFFECTIVEDATE,VERIFY_DATE",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "NSE_ADMIN_DOCUMENTS",
    "PKColumns": "ADMIN_DOCUMENT_ID",
    "TableColumns": "ADMIN_DOCUMENT_ID,FILE_NAME,TITLE,APPLICATIONID,FILEID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "NSE_ADMIN_DOCUMENTS_FOR_GRADE",
    "PKColumns": "ADMIN_DOCUMENT_ID,GRADE",
    "TableColumns": "ADMIN_DOCUMENT_ID,GRADE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "NSE_ADMIN_SETTINGS",
    "PKColumns": "SETTING_ID",
    "TableColumns": "SETTING_ID,THEME_ID,FILEID,FILE_NAME,HELP_URL,ALLOW_ALERT,ALERT_TYPE,ALERT_TIME,ALERT_DAY,TIMEINTERVAL,PARENT_FROMEMAIL,PARENT_DISPLAYNAME,PARENT_CCEMAIL,PARENT_SMTPSERVERNAME,REG_FROMEMAIL,REG_DISPLAYNAME,REG_CCEMAIL,REG_SMTPSERVERNAME,LASTMODIFIEDBY,LASTMODIFIEDDATE,DEBUG_EMAIL,PRE_REG_BUILDING,ENGLISH_LANGUAGE_CODE,HELP_URL_UPDATE_FORM,REG_UPDATE_MAX_ENTRIES,REG_NEW_MAX_ENTRIES,WARN_BLANK_UPDT,ALERT_STU_MATCH,DISPLAY_MATCH_CONTACT",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "NSE_APPLICATION",
    "PKColumns": "APPLICATION_ID",
    "TableColumns": "APPLICATION_ID,APPLICATION_NAME,SHOW_MEDICAL,SHOW_HISPANIC_UNANSWERED,PREFERRED_BUILDING_COUNT,ALLOW_MULTIPLE_RACE,APPLICATION_STATUS,LASTMODIFIEDBY,LASTMODIFIEDDATE,DESCRIPTION,IS_DEFAULT,SHOW_EXISTING_DATA_VACCINATION,AUTO_ACCEPT,SHOW_STUDENT,SHOW_ADDRESS,SHOW_CONTACT,SHOW_BUILDING,SHOW_UPLOAD,FORMTYPE,BUILDING_TO_BE_EXCLUDED,LIMIT_CONTACT_TYPES,CONTACT_TYPES_ALLOWED,DEFAULT_SCHOOL_YEAR,DEFAULT_ENTRY_DATE,USE_NEXT_PREV,USE_SECT_COMPL,HIGHLIGHT_FAILD_VALID,DISPLAY_TOOL_ICON",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "NSE_APPLICATION_DETAILS",
    "PKColumns": "",
    "TableColumns": "APPLICATION_ID,FIELD_ID,IS_VISIBLE,IS_REQUIRED,LASTMODIFIEDBY,LASTMODIFIEDDATE,SHOWEXISTINGDATA,CONFIGFIELD,DONOTALLOWCHANGE,IS_CAPITALIZE",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "NSE_APPLICATION_RELATIONSHIP",
    "PKColumns": "APPLICATION_ID",
    "TableColumns": "APPLICATION_ID,SIGNATURE_ID,DISCLAIMER_ID,LASTMODIFIEDBY,LASTMODIFIEDDATE",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "NSE_APPLICATION_STUDENT",
    "PKColumns": "APPLICATION_ID,NSE_ID",
    "TableColumns": "APPLICATION_ID,NSE_ID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "NSE_APPLICATION_TRANSLATION",
    "PKColumns": "APPLICATION_ID,LANGCODE",
    "TableColumns": "RECID,APPLICATION_ID,NAMETRANSLATION,DESCRIPTIONTRANSLATION,LANGCODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "NSE_BUILDING",
    "PKColumns": "BUILDING_ID",
    "TableColumns": "BUILDING_ID,NSE_ID,SUGGESTEDBUILDING,PREFERREDBUILDING1,PREFERREDBUILDING2,PREFERREDBUILDING3,PREFERREDBUILDING4,PREFERREDBUILDING5,SELECTEDBUILDING,OVERRIDE_BUILDING,OVERRIDE_REASON,TRACK,CALENDAR,ENTRYTYPE,ENTRYCODE,ENTRYDATE,PLANAREANUMBER,LASTMODIFIEDBY,LASTMODIFIEDDATE,NEXTYEARSUGGESTEDBUILDING",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "NSE_CONFIGURABLE_FIELDS",
    "PKColumns": "FIELD_ID",
    "TableColumns": "FIELD_ID,TAB_ID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "NSE_CONTACT",
    "PKColumns": "CONTACT_ID",
    "TableColumns": "CONTACT_ID,NSE_ID,ADDRESS_ID,TITLE,FIRSTNAME,MIDDLENAME,LASTNAME,GENERATION,RELATIONSHIP,WORKPHONE,WORKPHONEEXT,HOME_LANGUAGE,LANGUAGE_OF_CORRESPONDENCE,USE_LANGUAGE_FOR_MAILING,EMAIL_ID,USE_EMAIL_FOR_MAILING,EDUCATION_LEVEL,COPYADDRESSFLAG,REGISTRATIONLABELSFLAG,ATTENDANCENOTIFICATIONSFLAG,DISCIPLINELETTERSFLAG,SCHEDULESFLAG,SUCCESSPLANFLAG,IPRLETTERSFLAG,REPORTCARDSFLAG,MEDICALLETTERSFLAG,STUDENTFEESFLAG,ESCHOOL_CONTACT_ID,ISEXISTING_ESCHOOL_CONTACT_ID,CONTACT_TYPE,LIVINGWITH,LASTMODIFIEDBY,LASTMODIFIEDDATE,IS_COPIED_FROM_NSE,COPIED_FROM_ID,CONTACT_STATUS",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "NSE_CONTACT_PHONE",
    "PKColumns": "NSE_ID,CONTACT_ID,PHONE_TYPE",
    "TableColumns": "NSE_ID,DISTRICT,CONTACT_ID,PHONE_TYPE,PHONE_LISTING,PHONE,PHONE_EXTENSION,SIF_REFID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "NSE_CONTACT_VERIFY",
    "PKColumns": "NSE_ID,CONTACT_ID",
    "TableColumns": "NSE_ID,DISTRICT,CONTACT_ID,VERIFY_DATE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "NSE_CONTACTMATCH_LOG",
    "PKColumns": "CONTACT_ID",
    "TableColumns": "CONTACT_ID,NSE_ID,ADDRESS_ID,TITLE,FIRSTNAME,MIDDLENAME,LASTNAME,GENERATION,RELATIONSHIP,WORKPHONE,WORKPHONEEXT,HOME_LANGUAGE,LANGUAGE_OF_CORRESPONDENCE,USE_LANGUAGE_FOR_MAILING,EMAIL_ID,USE_EMAIL_FOR_MAILING,EDUCATION_LEVEL,COPYADDRESSFLAG,REGISTRATIONLABELSFLAG,ATTENDANCENOTIFICATIONSFLAG,DISCIPLINELETTERSFLAG,SCHEDULESFLAG,SUCCESSPLANFLAG,IPRLETTERSFLAG,REPORTCARDSFLAG,MEDICALLETTERSFLAG,STUDENTFEESFLAG,ESCHOOL_CONTACT_ID,ISEXISTING_ESCHOOL_CONTACT_ID,CONTACT_TYPE,LIVINGWITH,LASTMODIFIEDBY,LASTMODIFIEDDATE",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "NSE_CONTROLSLIST",
    "PKColumns": "CONTROL_ID",
    "TableColumns": "CONTROL_ID,CONTROL_TYPE,CONTROL_NAME,DEFAULT_TRANSLATION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "NSE_CONTROLTRANSLATION",
    "PKColumns": "TRANSLATION_ID",
    "TableColumns": "TRANSLATION_ID,CONTROL_ID,LANGUAGE_ID,TRANSLATION,LASTMODIFIEDBY,LASTMODIFIEDDATE",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "NSE_DISCLAIMER",
    "PKColumns": "DISCLAIMER_ID",
    "TableColumns": "DISCLAIMER_ID,TITLE,RESOURCE_ID,LASTMODIFIEDBY,LASTMODIFIEDDATE",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "NSE_DYNAMIC_FIELDS_APPLICATION",
    "PKColumns": "DYNAMIC_FIELD_ID",
    "TableColumns": "DYNAMIC_FIELD_ID,RESOURCE_ID,TAB_ID,APPLICATION_ID,FIELD_ORDER,FIELD_REQUIRED,FIELD_REQUIRED_REGISTRAR,DEFAULT_VALUE,FIELD_TYPE,FIELD_TABLE,FIELD_COLUMN,FIELD_SHOW_ON_APPLICATION,CONTROL_TYPE,DATA_TYPE,FIELD_LENGTH,LASTMODIFIEDBY,LASTMODIFIEDDATE",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "NSE_DYNAMIC_FIELDS_GRADE",
    "PKColumns": "DYNAMIC_FIELD_ID,GRADE",
    "TableColumns": "DYNAMIC_FIELD_ID,GRADE,LASTMODIFIEDBY,LASTMODIFIEDDATE",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "NSE_DYNAMIC_FIELDS_GROUP",
    "PKColumns": "APPLICATION_ID,TAB_ID,DYNAMIC_FIELD_ID",
    "TableColumns": "APPLICATION_ID,TAB_ID,DYNAMIC_FIELD_ID,GROUP_TITLE,GROUP_HEADER_TEXT,LASTMODIFIEDBY,LASTMODIFIEDDATE",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "NSE_DYNAMIC_FIELDS_TOOLTIP",
    "PKColumns": "TOOLTIP_ID",
    "TableColumns": "TOOLTIP_ID,RESOURCE_ID,DYNAMIC_FIELD_ID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "NSE_EOCONTACT",
    "PKColumns": "NSE_ID,CONTACT_ID",
    "TableColumns": "NSE_ID,ESP_CONTACT_ID,CONTACT_STATUS,DISTRICT,CONTACT_ID,TITLE,SALUTATION,FIRST_NAME,MIDDLE_NAME,LAST_NAME,GENERATION,LANGUAGE,HOME_LANGUAGE,USE_FOR_MAILING,EMPLOYER,DEVELOPMENT,APARTMENT,COMPLEX,STREET_NUMBER,STREET_PREFIX,STREET_NAME,STREET_SUFFIX,STREET_TYPE,CITY,STATE,ZIP,PLAN_AREA_NUMBER,HOME_BUILDING_TYPE,EMAIL,EMAIL_PREFERENCE,DELIVERY_POINT,LOGIN_ID,WEB_PASSWORD,PWD_CHG_DATE_TIME,LAST_LOGIN_DATE,EDUCATION_LEVEL,SIF_REFID,CHANGE_DATE_TIME,CHANGE_UID,HAC_LDAP_FLAG,MATCHED_CONTACT",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "NSE_FIELDS",
    "PKColumns": "FIELD_ID",
    "TableColumns": "FIELD_ID,RESOURCE_ID,FIELD_TYPE,DB_FIELD_NAME,TAB_ID,LASTMODIFIEDBY,LASTMODIFIEDDATE",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "NSE_HAC_ACCESS",
    "PKColumns": "NSE_GUID,LOGIN_ID",
    "TableColumns": "NSE_GUID,LOGIN_ID,WEB_PASSWORD,STUDENT_ID,PREFERRED_LANG,ACCESSED_TIME,NSE_ID",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "NSE_LANGUAGE",
    "PKColumns": "LANGUAGEID",
    "TableColumns": "LANGUAGEID,LANGUAGENAME,ISSUPPORTED,LASTMODIFIEDBY,LASTMODIFIEDDATE,LANGUAGECODE",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "NSE_MEDICAL",
    "PKColumns": "MEDICAL_ID",
    "TableColumns": "MEDICAL_ID,NSE_ID,VACCINATION,EXEMPTION,DATE1,DATE2,DATE3,DATE4,DATE5,DATE6,LASTMODIFIEDBY,LASTMODIFIEDDATE",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "NSE_PHONENUMBERS",
    "PKColumns": "ID",
    "TableColumns": "ID,NSE_ID,CONTACT_ID,PHONE_TYPE,PHONE_NUMBER,EXT,LISTING_STATUS,LASTMODIFIEDBY,LASTMODIFIEDDATE",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "NSE_REG_USER",
    "PKColumns": "NSE_ID,DYNAMIC_FIELD_ID",
    "TableColumns": "NSE_ID,DYNAMIC_FIELD_ID,FIELD_VALUE,LASTMODIFIEDBY,LASTMODIFIEDDATE",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "NSE_RESOURCE",
    "PKColumns": "RESOURCE_ID",
    "TableColumns": "RESOURCE_ID,RESOURCE_VALUE,RESOURCE_TYPE_ID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "NSE_RESOURCE_TYPE",
    "PKColumns": "RESOURCE_TYPE_ID",
    "TableColumns": "RESOURCE_TYPE_ID,RESOURCE_TYPE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "NSE_SECTION_COMPLETE",
    "PKColumns": "NSE_ID,TAB_ID",
    "TableColumns": "NSE_ID,TAB_ID,SECTION_COMPLETE,LASTMODIFIEDBY,LASTMODIFIEDDATE",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "NSE_SIGNATURE",
    "PKColumns": "SIGNATURE_ID",
    "TableColumns": "SIGNATURE_ID,TITLE,RESOURCE_ID,LASTMODIFIEDBY,LASTMODIFIEDDATE",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "NSE_STU_CONTACT",
    "PKColumns": "NSE_ID,CONTACT_ID,CONTACT_TYPE",
    "TableColumns": "NSE_ID,DISTRICT,CONTACT_ID,ESP_CONTACT_TYPE,CONTACT_TYPE,CONTACT_PRIORITY,RELATION_CODE,LIVING_WITH,WEB_ACCESS,COMMENTS,TRANSPORT_TO,TRANSPORT_FROM,MAIL_ATT,MAIL_DISC,MAIL_FEES,MAIL_IPR,MAIL_MED,MAIL_RC,MAIL_REG,MAIL_SCHD,MAIL_SSP,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "NSE_STUDENT",
    "PKColumns": "NSE_ID",
    "TableColumns": "NSE_ID,STUDENT_ID,ADDRESS_ID,GRADE,FIRSTNAME,MIDDLENAME,LASTNAME,GENERATION,NICKNAME,GENDER,BIRTHDATE,SSN,HISPANIC_LATINO_ETHNICITY,RACE,NATIVE_LANGUAGE,HOME_LANGUAGE,LANGUAGE_OF_CORRESPONDENCE,USE_LANGUAGE_FOR_MAILING,EMAIL_ID,USE_EMAIL_FOR_MAILING,WEB_ACCESS,LOGIN_ID,STUDENT_PASSWORD,PARENT_ID,STUDENT_STATUS,LASTMODIFIEDBY,LASTMODIFIEDDATE,ENTRYTYPE,ENTRYDATE,FEDERALCODE,FAMILYCENSUSNUMBER,NOTES,ISEXISTING_ESCHOOL_ID,REASON,COPIEDFROM,BIRTH_VERIFY,HISPANIC_CODE,BIRTHCOUNTRY,ENTRYYEAR,USER_KEY",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "NSE_STUDENT_RACE",
    "PKColumns": "NSE_ID,RACE",
    "TableColumns": "NSE_ID,RACE,RACE_ORDER,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "NSE_TABS",
    "PKColumns": "TAB_ID",
    "TableColumns": "TAB_ID,RESOURCE_ID,TAB_ORDER,APPLICATION_ID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "NSE_TOOLTIP",
    "PKColumns": "TOOLTIP_ID",
    "TableColumns": "TOOLTIP_ID,RESOURCE_ID,FIELD_ID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "NSE_TRANSLATION",
    "PKColumns": "TRANS_ID,LANGUAGE_ID,RESOURCE_ID",
    "TableColumns": "TRANS_ID,LANGUAGE_ID,RESOURCE_ID,TRANSLATION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "NSE_UPLOAD_DOCUMENTS",
    "PKColumns": "UPLOAD_DOCUMENT_ID",
    "TableColumns": "UPLOAD_DOCUMENT_ID,NSE_ID,FILE_NAME,FILEID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "NSE_UPLOADFILES",
    "PKColumns": "FILE_ID",
    "TableColumns": "FILE_ID,FILE_CONTENT,LASTMODIFIEDBY,LASTMODIFIEDDATE",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "NSE_USER",
    "PKColumns": "USERID",
    "TableColumns": "USERID,LOGINID,USER_PASSWORD,ROLEID,LASTMODIFIEDDATE,CHANGE_UID,USER_KEY",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "NSE_USERDETAIL",
    "PKColumns": "USERID",
    "TableColumns": "USERID,FIRSTNAME,LASTNAME,PHONE,STREET,CITY,USER_STATE,STREET_TYPE,ZIPCODE,PREFERREDLANGUAGE,LASTMODIFIEDBY,LASTMODIFIEDDATE,EMAIL,APARTMENT,HOUSE_NUMBER,STREET_PREFIX,STREET_SUFFIX",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "NSE_VACCINATION_CONFIGURATION",
    "PKColumns": "APPLICATION_ID,VACCINATION_CODE",
    "TableColumns": "APPLICATION_ID,VACCINATION_CODE,LASTMODIFIEDBY,LASTMODIFIEDDATE",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "P360_NotificationLink",
    "PKColumns": "PNL_ID",
    "TableColumns": "PNL_ID,PNL_TStamp,PNL_LastUser,PNL_District,PNL_PNR_ID,PNL_SessionVariableNumber,PNL_SessionVariableName",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "P360_NotificationResultSet",
    "PKColumns": "PNRS_ID",
    "TableColumns": "PNRS_ID,PNRS_TStamp,PNRS_LastUser,PNRS_District,PNRS_PNR_ID,PNRS_PNRU_ID,PNRS_PNR_Subquery_ID,PNRS_SentToPOD,PNRS_Category,PNRS_ShortMessage,PNRS_LongMessage,PNRS_LongMessageRemote,PNRS_Value01,PNRS_Value02,PNRS_Value03,PNRS_Value04,PNRS_Value05,PNRS_Value06,PNRS_Value07,PNRS_Value08,PNRS_Value09,PNRS_Value10,PNRS_Value11,PNRS_Value12,PNRS_Value13,PNRS_Value14,PNRS_Value15,PNRS_Value16",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "P360_NotificationResultSetUser",
    "PKColumns": "PNRSU_ID",
    "TableColumns": "PNRSU_ID,PNRSU_TStamp,PNRSU_LastUser,PNRSU_District,PNRSU_PNRS_ID,PNRSU_UserId,PNRSU_UserApplication,PNRSU_EmailAddress,PNRSU_DeliveryMethod,PNRSU_InstantAlert",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "P360_NotificationRule",
    "PKColumns": "PNR_ID",
    "TableColumns": "PNR_ID,PNR_TStamp,PNR_LastUser,PNR_District,PNR_Name,PNR_Description,PNR_SourceApplication,PNR_RemoteSecurityApplication,PNR_RemoteSecurityType,PNR_RequiredSecurity,PNR_RuleType,PNR_Rule,PNR_Category,PNR_FilterSQL,PNR_HighestRequiredLevel,PNR_ShortMessage,PNR_LongMessage,PNR_LongMessageRemote,PNR_LinkToPageTitle,PNR_LinkToPageURL,PNR_LinkToPageMethod,PNR_AlertEveryTime,PNR_Subquery,PNR_Subquery_ID,PNR_Active",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "P360_NotificationRuleKey",
    "PKColumns": "PNRK_ID",
    "TableColumns": "PNRK_ID,PNRK_TStamp,PNRK_LastUser,PNRK_District,PNRK_PNR_ID,PNRK_KeyName,PNRK_ResultValueID",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "P360_NotificationRuleUser",
    "PKColumns": "PNRU_ID",
    "TableColumns": "PNRU_ID,PNRU_TStamp,PNRU_LastUser,PNRU_District,PNRU_PNR_ID,PNRU_Level,PNRU_Actor,PNRU_SubscribeStatus,PNRU_DeliveryMethod,PNRU_InstantAlert,PNRU_Active",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "P360_NotificationSchedule",
    "PKColumns": "PNS_ID",
    "TableColumns": "PNS_ID,PNS_TStamp,PNS_LastUser,PNS_District,PNS_PNRU_ID,PNS_PNRS_ID,PNS_Minute,PNS_Hour,PNS_DayOfMonth,PNS_Month,PNS_DayOfWeek,PNS_TaskType,PNS_AssignedToTask",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "P360_NotificationTasks",
    "PKColumns": "PNT_ID",
    "TableColumns": "PNT_ID,PNT_PNS_ID,PNT_AgentPriority,PNT_StartDateTime,PNT_Status,PNT_TaskType",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "P360_NotificationUserCriteria",
    "PKColumns": "PNUC_ID",
    "TableColumns": "PNUC_ID,PNUC_TStamp,PNUC_LastUser,PNUC_District,PNUC_PNR_ID,PNUC_PNRU_ID,PNUC_CriteriaType,PNUC_CriteriaVariable,PNUC_CriteriaValue",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "PESC_SUBTEST_CODE",
    "PKColumns": "DISTRICT,SUBTEST_CODE",
    "TableColumns": "DISTRICT,SUBTEST_CODE,SUBTEST_NAME,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "PESC_TEST_CODE",
    "PKColumns": "DISTRICT,TEST_CODE",
    "TableColumns": "DISTRICT,TEST_CODE,TEST_NAME,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "PESCTB_DIPLO_XWALK",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,ACADEMICAWARDLEVEL,DIPLOMATYPE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "PESCTB_GEND_XWALK",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,PESCCODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "PESCTB_GPA_XWALK",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,PESCCODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "PESCTB_GRADE_XWALK",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,PESCCODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "PESCTB_SCORE_XWALK",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,PESCCODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "PESCTB_SHOT_XWALK",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,PESCCODE,PESC_DESC_HELP,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "PESCTB_STU_STATUS",
    "PKColumns": "DISTRICT,STUDENT_ID,REPORT_ID,DATASET_ID",
    "TableColumns": "DISTRICT,STUDENT_ID,REPORT_ID,DATASET_ID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "PESCTB_SUFFIX_XWALK",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,PESCCODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "PESCTB_TERM_XWALK",
    "PKColumns": "DISTRICT,BUILDING,RUNTERMYEAR",
    "TableColumns": "DISTRICT,BUILDING,RUNTERMYEAR,PESCCODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "PP_CFG",
    "PKColumns": "DISTRICT",
    "TableColumns": "DISTRICT,TM1_HOST,TM1_SERVER,TM1_ADMIN,TM1_PWD,TM1_WEB_URL,TM1_INSTALL_SERVER,TM1_INSTALL_PATH,TM1_DSN,REFRESH_MONTHS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "PP_DISTDEF_MAP",
    "PKColumns": "DISTRICT,SCREEN_NUMBER,FIELD_NUMBER",
    "TableColumns": "DISTRICT,SCREEN_NUMBER,FIELD_NUMBER,FIELD_LABEL,DEFAULT_VALUE,DEFAULT_FORMATTED,PROGRAM_ID,DATA_TYPE,NUMBER_TYPE,DATA_LENGTH,CUBE_ORDER,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "PP_MONTH_DAYS",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,CALENDAR_YEAR,CALENDAR_MONTH,BUILDING,TRACK",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,CALENDAR_YEAR,CALENDAR_MONTH,BUILDING,TRACK,CALENDAR,DAYS_IN_MONTH,FIRST_DAY_OF_MONTH,LAST_DAY_OF_MONTH,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "PP_REBUILD_HISTORY",
    "PKColumns": "DISTRICT,CUBE_NAME",
    "TableColumns": "DISTRICT,CUBE_NAME,NEEDS_REBUILD,CURRENT_RUN_TIME,LAST_RUN_TIME,LAST_UPDATE_TYPE,LAST_STATUS,LAST_CALC_ID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "PP_SECURITY",
    "PKColumns": "DISTRICT,CUBE_NAME,ITEM_TYPE,ITEM_NAME",
    "TableColumns": "DISTRICT,CUBE_NAME,ITEM_TYPE,ITEM_NAME,PACKAGE,SUBPACKAGE,FEATURE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "PP_STUDENT_CACHE",
    "PKColumns": "DISTRICT,START_DATE,END_DATE,STUDENT_ID",
    "TableColumns": "DISTRICT,START_DATE,END_DATE,SCHOOL_YEAR,BUILDING,SUMMER_SCHOOL,STUDENT_GUID,STUDENT_ID,STUDENT_NAME,ETHNIC_CODE,GENDER,GRADE,HOUSE_TEAM,MEAL_STATUS,CURRICULUM,GRADUATION_YEAR,TRACK,CALENDAR,RESIDENCY_CODE,CITIZEN_STATUS,AT_RISK,MIGRANT,HAS_IEP,SECTION_504_PLAN,HOMELESS_STATUS,ESL,DIPLOMA_TYPE,DISTDEF_01,DISTDEF_02,DISTDEF_03,DISTDEF_04,DISTDEF_05,DISTDEF_06,DISTDEF_07,DISTDEF_08,DISTDEF_09,DISTDEF_10,DISTDEF_11,DISTDEF_12,DISTDEF_13,DISTDEF_14,DISTDEF_15,DISTDEF_16,DISTDEF_17,DISTDEF_18,DISTDEF_19,DISTDEF_20,DISTDEF_21,DISTDEF_22,DISTDEF_23,DISTDEF_24,DISTDEF_25,IS_DIRTY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "PP_STUDENT_MONTH",
    "PKColumns": "DISTRICT,STUDENT_ID,START_DATE",
    "TableColumns": "DISTRICT,STUDENT_ID,START_DATE,DAYS_IN_MONTH,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "PP_STUDENT_MONTH_ABS",
    "PKColumns": "DISTRICT,STUDENT_ID,START_DATE,VIEW_TYPE,ATT_BUILDING",
    "TableColumns": "DISTRICT,STUDENT_ID,START_DATE,VIEW_TYPE,ATT_BUILDING,PRESENT_TIME,TOTAL_DAY_TIME,MEMBERSHIP_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "PP_STUDENT_TEMP",
    "PKColumns": "DISTRICT,SCHOOL_DAY,SCHOOL_YEAR,BUILDING,STUDENT_ID",
    "TableColumns": "DISTRICT,SCHOOL_DAY,SCHOOL_YEAR,BUILDING,STUDENT_ID,SUMMER_SCHOOL,ETHNIC_CODE,GRADE,HOUSE_TEAM,MEAL_STATUS,CURRICULUM,GRADUATION_YEAR,TRACK,CALENDAR,RESIDENCY_CODE,CITIZEN_STATUS,AT_RISK,MIGRANT,HAS_IEP,SECTION_504_PLAN,HOMELESS_STATUS,ESL,DIPLOMA_TYPE,DISTDEF_01,DISTDEF_02,DISTDEF_03,DISTDEF_04,DISTDEF_05,DISTDEF_06,DISTDEF_07,DISTDEF_08,DISTDEF_09,DISTDEF_10,DISTDEF_11,DISTDEF_12,DISTDEF_13,DISTDEF_14,DISTDEF_15,DISTDEF_16,DISTDEF_17,DISTDEF_18,DISTDEF_19,DISTDEF_20,DISTDEF_21,DISTDEF_22,DISTDEF_23,DISTDEF_24,DISTDEF_25",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "PRCH_STU_STATUS",
    "PKColumns": "DISTRICT,STUDENT_ID",
    "TableColumns": "DISTRICT,STUDENT_ID,PESC_FILE_LOC,PENDING_UPLOAD,LAST_UPLOAD_ATT,LAST_UPLOAD_SUC,UPLOAD_RESPONSE,UPLOAD_MESSAGE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "PS_SPECIAL_ED_PHONE_TYPE_MAP",
    "PKColumns": "SPECIAL_ED_PHONE_TYPE",
    "TableColumns": "DISTRICT,SPECIAL_ED_PHONE_TYPE,ESCHOOLPLUS_PHONE_TYPE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG",
    "PKColumns": "DISTRICT,STUDENT_ID",
    "TableColumns": "DISTRICT,STUDENT_ID,FIRST_NAME,MIDDLE_NAME,LAST_NAME,GENERATION,BUILDING,HOME_BUILDING,BUILDING_OVERRIDE,BUILDING_REASON,GRADE,GENDER,LANGUAGE,NATIVE_LANGUAGE,CALENDAR,TRACK,CURRENT_STATUS,SUMMER_STATUS,COUNSELOR,HOUSE_TEAM,HOMEROOM_PRIMARY,HOMEROOM_SECONDARY,BIRTHDATE,FAMILY_CENSUS,ALT_BUILDING,ALT_DISTRICT,NICKNAME,HOME_DISTRICT,ATTENDING_DISTRICT,ALT_BLDG_ACCT,DIST_ENROLL_DATE,STATE_ENROLL_DATE,US_ENROLL_DATE,STUDENT_GUID,RES_COUNTY_CODE,STATE_RES_BUILDING,GRADE_9_DATE,GENDER_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID,HOME_DISTRICT_OVERRIDE",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_ACADEMIC",
    "PKColumns": "DISTRICT,STUDENT_ID",
    "TableColumns": "DISTRICT,STUDENT_ID,GRADUATION_YEAR,GRADUATION_DATE,PROMOTION,CURRICULUM,SCHD_PRIORITY,GRADUATE_REQ_GROUP,MODELED_GRAD_PLAN,PENDING_GRAD_PLAN,EXP_GRAD_PLAN,ACT_GRAD_PLAN,DIPLOMA_TYPE,ELIG_STATUS,ELIG_REASON,ELIG_EFFECTIVE_DTE,ELIG_EXPIRES_DATE,HOLD_REPORT_CARD,RC_HOLD_OVERRIDE,VOTEC,ADVISOR,DISCIPLINARIAN,FEDERAL_GRAD_YEAR,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_ACADEMIC_SUPP",
    "PKColumns": "DISTRICT,STUDENT_ID,SUPP_TYPE,SUPP_REQ_GROUP",
    "TableColumns": "DISTRICT,STUDENT_ID,SUPP_TYPE,SUPP_REQ_GROUP,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_ACT_PREREQ",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,ACTIVITY_CODE,SEQUENCE_NUM",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,ACTIVITY_CODE,SEQUENCE_NUM,AND_OR_FLAG,TABLE_NAME,COLUMN_NAME,OPERATOR,LOW_VALUE,HIGH_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_ACTIVITY_ADV",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,ACTIVITY_CODE,STAFF_ID",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,ACTIVITY_CODE,STAFF_ID,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_ACTIVITY_DET",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,ACTIVITY_CODE,STUDENT_ID",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,ACTIVITY_CODE,STUDENT_ID,ACTIVITY_STATUS,INELIGIBLE,OVERRIDE,START_DATE,END_DATE,DURATION,ACTIVITY_COMMENT,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_ACTIVITY_ELIG",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,STUDENT_ID,ELIG_EFFECTIVE_DTE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,STUDENT_ID,ELIG_EFFECTIVE_DTE,ELIG_STATUS,ELIG_REASON,ELIG_EXPIRES_DATE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_ACTIVITY_HDR",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,ACTIVITY_CODE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,ACTIVITY_CODE,DESCRIPTION,MODERATOR,MAX_ENROLLMENT,CURRENT_ENROLLMENT,EXCEED_MAXIMUM,STATE_CODE_EQUIV,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_ACTIVITY_INEL",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,STUDENT_ID,ACTIVITY_CODE,NOTIFICATION_DATE,TRIGGER_EVENT,ATTENDANCE_DATE,ATTENDANCE_PERIOD",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,STUDENT_ID,ACTIVITY_CODE,NOTIFICATION_DATE,TRIGGER_EVENT,ATTENDANCE_DATE,ATTENDANCE_PERIOD,INELIGIBILITY_CODE,SOURCE,INVALID_EVENT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_ACTIVITY_MP",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,ACTIVITY_CODE,MARKING_PERIOD",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,ACTIVITY_CODE,MARKING_PERIOD,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_APPOINTMENT",
    "PKColumns": "DISTRICT,APPOINTMENT_ID",
    "TableColumns": "DISTRICT,APPOINTMENT_ID,BUILDING,STUDENT_ID,DATE_ENTERED,ENTRY_UID,APPT_START_TIME,APPT_END_TIME,APPT_TYPE,APPT_REASON,STAFF_ID,PERIOD,KEPT_APPT,INCLUDE_STUDENT_NOTE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_APPT_SHARE",
    "PKColumns": "DISTRICT,STAFF_ID,LOGIN_ID",
    "TableColumns": "DISTRICT,STAFF_ID,LOGIN_ID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_AT_RISK_FACTOR",
    "PKColumns": "DISTRICT,FACTOR_CODE",
    "TableColumns": "DISTRICT,FACTOR_CODE,DESCRIPTION,ACTIVE,DISPLAY_ORDER,FACTOR_TYPE,TABLE_NAME,COLUMN_NAME,SCREEN_NUMBER,FIELD_NUMBER,UPDATE_OVERALL,ALLOW_FORMER_STATUS,CALC_REQ_REASONS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_AT_RISK_FACTOR_REASON",
    "PKColumns": "DISTRICT,FACTOR_CODE,FACTOR_REASON",
    "TableColumns": "DISTRICT,FACTOR_CODE,FACTOR_REASON,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_BUILDING",
    "PKColumns": "DISTRICT,BUILDING",
    "TableColumns": "DISTRICT,BUILDING,NAME,TRANSFER_BUILDING,ABBREVIATION,STREET1,STREET2,CITY,STATE,ZIP,PHONE,FAX,PRINCIPAL,CALENDAR,BUILDING_TYPE,DEFAULT_ZIP,STATE_CODE_EQUIV,COUNTY_CODE,OUT_OF_DISTRICT,PESC_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_BUILDING_GRADE",
    "PKColumns": "DISTRICT,BUILDING,GRADE",
    "TableColumns": "DISTRICT,BUILDING,GRADE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_CAL_DAYS",
    "PKColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,SUMMER_SCHOOL,TRACK,CALENDAR,CAL_DATE",
    "TableColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,SUMMER_SCHOOL,TRACK,CALENDAR,CAL_DATE,CYCLE_FLAG,CYCLE_CODE,MEMBERSHIP_DAY,MEMBERSHIP_VALUE,TAKE_ATTENDANCE,INCLUDE_TOTALS,DAY_TYPE,DAY_NUMBER,DAY_IN_MEMBERSHIP,ALTERNATE_CYCLE,WEEK_NUMBER,INSTRUCT_TIME,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_CAL_DAYS_LEARNING_LOC",
    "PKColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,SUMMER_SCHOOL,TRACK,CALENDAR,CAL_DATE,LEARNING_LOCATION",
    "TableColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,SUMMER_SCHOOL,TRACK,CALENDAR,CAL_DATE,LEARNING_LOCATION,CHANGE_DATE_TIME,CHANGE_UID,ROW_IDENTITY,LOCATION_TYPE",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_CAL_DAYS_LL_PDS",
    "PKColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,SUMMER_SCHOOL,TRACK,CALENDAR,CAL_DATE,LEARNING_LOCATION,LOCATION_TYPE,ATT_PERIOD",
    "TableColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,SUMMER_SCHOOL,TRACK,CALENDAR,CAL_DATE,LEARNING_LOCATION,LOCATION_TYPE,ATT_PERIOD,CHANGE_DATE_TIME,CHANGE_UID,ROW_IDENTITY",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_CALENDAR",
    "PKColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,SUMMER_SCHOOL,TRACK,CALENDAR",
    "TableColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,SUMMER_SCHOOL,TRACK,CALENDAR,DESCRIPTION,DEF_MEM_VALUE,FIRST_DAY,LAST_DAY,SUNDAY,MONDAY,TUESDAY,WEDNESDAY,THURSDAY,FRIDAY,SATURDAY,DAYS_IN_CYCLE,FIRST_DAY_CYCLE,DAYS_IN_CALENDAR,DAYS_IN_MEMBERSHIP,STATE_CODE_EQUIV,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_CFG",
    "PKColumns": "DISTRICT,BUILDING,SCHOOL_YEAR",
    "TableColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,AUTO_ASSIGN,OVERIDE_AUTO_ASSGN,STARTING_ID,MAX_ID_ALLOWED,HIGHEST_ID_USED,DEFAULT_ENTRY_CODE,DEFAULT_ENTRY_DATE,YEAREND_WD_CODE,YEAREND_ENTRY_CODE,DROP_OUT_CODE,EMAIL,YEAR_ROUND,PHOTO_PATH,PHOTO_EXTENSION,ST_ID_PREFIX,ST_STARTING_ID,ST_MAX_ID_ALLOWED,ST_HIGHEST_ID_USED,ST_AUTO_ASSIGN_OV,TEA_PERS_STU_SUMM,SUB_PERS_STU_SUMM,TEA_EMERG_STU_SUMM,SUB_EMERG_STU_SUMM,TEA_STUDENT_SEARCH,SUB_STUDENT_SEARCH,TEA_VIEW_IEP,SUB_VIEW_IEP,TEA_VIEW_GIFTED,SUB_VIEW_GIFTED,TEA_VIEW_504,SUB_VIEW_504,LOCKER_ASSIGN,AUTO_LOCKER_ASSIGN,REGISTRAR_EMAIL,MAX_WITH_BACKDATE,MSG_NEW_STUD,MSG_NEW_PR_STUD,MSG_PRIM_HOMEROOM,MSG_SEC_HOMEROOM,MSG_STU_COUNS,MSG_SUMMER_COUNS,MSG_EW_REENTRY,MSG_EW_CHG_BLDG,CHANGE_DATE_TIME,CHANGE_UID,PHOTO_DIRECTORY",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_CFG_ALERT",
    "PKColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,ALERT_TYPE",
    "TableColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,ALERT_TYPE,VISIBLE_TO_TEACHER,VISIBLE_TO_SUB,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_CFG_ALERT_CODE",
    "PKColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,ALERT_TYPE,CODE",
    "TableColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,ALERT_TYPE,CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_CFG_ALERT_DEF_CRIT",
    "PKColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,CRIT_ORDER,SEQUENCE_NUM",
    "TableColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,CRIT_ORDER,SEQUENCE_NUM,AND_OR_FLAG,TABLE_NAME,COLUMN_NAME,OPERATOR,CRITERIA_VALUE1,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_CFG_ALERT_DEFINED",
    "PKColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,CRIT_ORDER",
    "TableColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,CRIT_ORDER,TITLE,VISIBLE_TO_TEACHER,VISIBLE_TO_SUB,ACTIVE,CRIT_STRING1,CRIT_STRING2,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_CFG_ALERT_UDS_CRIT_KTY",
    "PKColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,CRIT_ORDER,SEQUENCE_NUM",
    "TableColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,CRIT_ORDER,SEQUENCE_NUM,AND_OR_FLAG,SCREEN_NUMBER,FIELD_NUMBER,OPERATOR,CRITERIA_VALUE1,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_CFG_ALERT_UDS_KTY",
    "PKColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,CRIT_ORDER",
    "TableColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,CRIT_ORDER,TITLE,VISIBLE_TO_TEACHER,VISIBLE_TO_SUB,ACTIVE,ALERT_LETTER,CRITERIA_STRING,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_CFG_ALERT_USER",
    "PKColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,SCREEN_NUMBER,FIELD_NUMBER",
    "TableColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,SCREEN_NUMBER,FIELD_NUMBER,ALERT_TEXT,DISPLAY_VALUE,DISPLAY_DESC,LIST_DISPLAY,VISIBLE_TO_TEACHER,VISIBLE_TO_SUB,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_CFG_EW_APPLY",
    "PKColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,CRITERIA_NUMBER,APPLIES_TO_CODE",
    "TableColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,CRITERIA_NUMBER,APPLIES_TO_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_CFG_EW_COMBO",
    "PKColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,CRITERIA_NUMBER",
    "TableColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,CRITERIA_NUMBER,TYPE,CONDITION,DEFAULT_ENTRY_CODE,DATE_GAP,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_CFG_EW_COND",
    "PKColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,CRITERIA_NUMBER,PRECEDING_CODE",
    "TableColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,CRITERIA_NUMBER,PRECEDING_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_CFG_EW_REQ_ENT",
    "PKColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,CRITERIA_NUMBER,ENTRY_CODE",
    "TableColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,CRITERIA_NUMBER,ENTRY_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_CFG_EW_REQ_FLD",
    "PKColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,CRITERIA_NUMBER,PROGRAM_ID,FIELD_NUMBER",
    "TableColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,CRITERIA_NUMBER,PROGRAM_ID,FIELD_NUMBER,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_CFG_EW_REQ_WD",
    "PKColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,CRITERIA_NUMBER,WITHDRAWAL_CODE",
    "TableColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,CRITERIA_NUMBER,WITHDRAWAL_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_CFG_EW_REQUIRE",
    "PKColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,CRITERIA_NUMBER",
    "TableColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,CRITERIA_NUMBER,COMMENT_REQUIRED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_CLASSIFICATION",
    "PKColumns": "DISTRICT,STUDENT_ID,CLASSIFICATION_CODE",
    "TableColumns": "DISTRICT,STUDENT_ID,CLASSIFICATION_CODE,CLASSIFICATION_ORDER,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_CLASSIFICATION_EVA",
    "PKColumns": "DISTRICT,STUDENT_ID,CLASSIFICATION_CODE",
    "TableColumns": "DISTRICT,STUDENT_ID,CLASSIFICATION_CODE,CLASSIFICATION_ORDER,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_CONTACT",
    "PKColumns": "DISTRICT,CONTACT_ID",
    "TableColumns": "DISTRICT,CONTACT_ID,TITLE,SALUTATION,FIRST_NAME,MIDDLE_NAME,LAST_NAME,GENERATION,LANGUAGE,HOME_LANGUAGE,USE_FOR_MAILING,EMPLOYER,DEVELOPMENT,APARTMENT,COMPLEX,STREET_NUMBER,STREET_PREFIX,STREET_NAME,STREET_SUFFIX,STREET_TYPE,CITY,STATE,ZIP,PLAN_AREA_NUMBER,HOME_BUILDING_TYPE,EMAIL,EMAIL_PREFERENCE,DELIVERY_POINT,LOGIN_ID,WEB_PASSWORD,PWD_CHG_DATE_TIME,LAST_LOGIN_DATE,EDUCATION_LEVEL,SIF_REFID,HAC_LDAP_FLAG,ACCT_LOCKED,ACCT_LOCKED_DATE_TIME,CHG_PW_NEXT_LOGIN,ONBOARD_TOKEN,ONBOARD_TOKEN_USED,ROW_IDENTITY,KEY_USED,CONTACT_KEY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_CONTACT_ADDITIONAL_EMAIL",
    "PKColumns": "DISTRICT,CONTACT_ID,EMAIL",
    "TableColumns": "DISTRICT,CONTACT_ID,EMAIL,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_CONTACT_HIST",
    "PKColumns": "DISTRICT,STUDENT_ID,ADDRESS_TYPE,CONTACT_ID,CHANGE_DATE_TIME",
    "TableColumns": "DISTRICT,STUDENT_ID,ADDRESS_TYPE,CONTACT_ID,DEVELOPMENT,APARTMENT,COMPLEX,STREET_NUMBER,STREET_PREFIX,STREET_NAME,STREET_SUFFIX,STREET_TYPE,CITY,STATE,ZIP,DELIVERY_POINT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_CONTACT_HIST_TMP",
    "PKColumns": "DISTRICT,STUDENT_ID,ADDRESS_TYPE,CONTACT_ID,CHANGE_DATE_TIME",
    "TableColumns": "DISTRICT,STUDENT_ID,ADDRESS_TYPE,CONTACT_ID,DEVELOPMENT,APARTMENT,COMPLEX,STREET_NUMBER,STREET_PREFIX,STREET_NAME,STREET_SUFFIX,STREET_TYPE,CITY,STATE,ZIP,DELIVERY_POINT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_CONTACT_LANGUAGE_INTERPRETER",
    "PKColumns": "DISTRICT,CONTACT_ID,LANGUAGE_INTERPRETER",
    "TableColumns": "DISTRICT,CONTACT_ID,LANGUAGE_INTERPRETER,INTERPRETER,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_CONTACT_PHONE",
    "PKColumns": "DISTRICT,CONTACT_ID,PHONE_TYPE",
    "TableColumns": "DISTRICT,CONTACT_ID,PHONE_TYPE,PHONE_LISTING,PHONE,PHONE_EXTENSION,SIF_REFID,PHONE_PRIORITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_CYCLE",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,CODE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,CYCLE_ORDER,CODE,DESCRIPTION,ALTERNATE_CYCLE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_DISABILITY",
    "PKColumns": "DISTRICT,STUDENT_ID,DISABILITY,SEQUENCE_NUM",
    "TableColumns": "DISTRICT,STUDENT_ID,DISABILITY,SEQUENCE_NUM,DISABILITY_ORDER,START_DATE,END_DATE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_DISTRICT",
    "PKColumns": "DISTRICT",
    "TableColumns": "DISTRICT,NAME,VALIDATION_ONLY,SCHOOL_YEAR,SUMMER_SCHOOL_YEAR,ADDRESS_FORMAT,STREET1,STREET2,CITY,STATE,ZIP,PHONE,SUPERINTENDENT,EMAIL,ALPHANUMERIC_IDS,STUDENT_ID_LENGTH,ZERO_FILL_IDS,AUTO_ASSIGN,OVERIDE_AUTO_ASSGN,STARTING_ID,HIGHEST_ID_USED,SHOW_SSN,TRANSPORT_STUDENT,ST_ID_REQUIRED,ST_ID_LABEL,ST_ID_LENGTH,ST_ID_ENFORCE_LEN,CHANGE_ID_IN_PRIOR,ID_ON_STATE_REPORT,ST_AUTO_ASSIGN,ST_ID_PREFIX,ST_STARTING_ID,ST_MAX_ID_ALLOWED,ST_HIGHEST_ID_USED,ST_ID_INCLUDE,ST_AUTO_ASSIGN_OV,FMS_DEPARTMENT,FMS_HOME_ORGN,FMS_PROGRAM,AGGREGATE,LIST_MAX,ETHNICITY_REQUIRED,USE_ETHNIC_PERCENT,USE_DIS_DATES,USE_ALERT_DATES,STATE_CODE_EQUIV,AUDIT_UPDATES,AUDIT_DELETE_ONLY,AUDIT_CLEAR_INT,LANGUAGE_REQUIRED,SPECIAL_ED_TABLE,SPECIAL_ED_SCR_NUM,SPECIAL_ED_COLUMN,IEPPLUS_INTEGRATION,PARAM_KEY,CRN_FROM_TAC,SHOW_RES_BLDG,ALT_ATTENDANCE_AGE,ALT_ATT_GRADES,CUTOFF_DATE,EW_MEMBERSHIP,ROLL_ENTRY_RULE,ROLL_WD_RULE,USE_RANK_CLASS_SIZE_EXCLUDE,INCLUDE_IEP,INCLUDE_GIFTED,INCLUDE_504,MIN_AGE_CITATION,LOCKOUT_USERS,DISABLE_SCHEDULED_TASKS,FIRSTWAVE_ID,SHOW_USERVOICE,EMAIL_DELIMITER,ALLOW_USERS_TO_SET_THEMES,AUTO_GENERATE_FAMILY_NUMBER,LOG_HAC_LOGINS,LOG_TAC_LOGINS,LOG_TAC_PUBLISH_EVENTS,MULTIPLE_CLASSIFICATIONS,CURRENT_KEY,PREVIOUS_KEY,COMPROMISED,CHANGE_DATE_TIME,CHANGE_UID,HIDE_GENDER_IDENTITY,HOME_PHONE_TYPE,MOBILE_PHONE_TYPE,GAINSIGHTS_ENABLED,ALLOW_MULTIPLE_STUDENT_EMAIL,ALLOW_MULTIPLE_CONTACT_EMAIL,ADDITIONAL_GENDERS",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_DISTRICT_ATTACHMENT",
    "PKColumns": "DISTRICT",
    "TableColumns": "DISTRICT,ALLOW_ATTACHMENTS,MAX_FILES,MAX_KB_SIZE,ATTACHMENT_FILE_TYPES,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_DISTRICT_SMTP",
    "PKColumns": "DISTRICT",
    "TableColumns": "DISTRICT,USE_LOCALHOST,SERVER_ADDRESS,SERVER_PORT,USE_SSL,LOGIN_ID,LOGIN_DOMAIN,PASSWORD,USE_GENERIC_FROM,GENERIC_FROM_ADDRESS,GENERIC_FROM_NAME,GENERIC_REPLY_ALLOWED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_DURATION",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,CODE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,CODE,DESCRIPTION,SUMMER_SCHOOL,NUMBER_WEEKS,NUMBER_IN_YEAR,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_EMERGENCY",
    "PKColumns": "DISTRICT,STUDENT_ID",
    "TableColumns": "DISTRICT,STUDENT_ID,DOCTOR_NAME,DOCTOR_PHONE,DOCTOR_EXTENSION,HOSPITAL_CODE,INSURANCE_COMPANY,INSURANCE_ID,INSURANCE_GROUP,INSURANCE_GRP_NAME,INSURANCE_SUBSCR,CHANGE_DATE_TIME,CHANGE_UID,DENTIST,DENTIST_PHONE,DENTIST_EXT",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_ENTRY_WITH",
    "PKColumns": "DISTRICT,STUDENT_ID,ENTRY_WD_TYPE,SCHOOL_YEAR,ENTRY_DATE",
    "TableColumns": "DISTRICT,STUDENT_ID,ENTRY_WD_TYPE,SCHOOL_YEAR,ENTRY_DATE,ENTRY_CODE,BUILDING,GRADE,TRACK,CALENDAR,WITHDRAWAL_DATE,WITHDRAWAL_CODE,COMMENTS,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_ETHNICITY",
    "PKColumns": "DISTRICT,STUDENT_ID,ETHNIC_CODE",
    "TableColumns": "DISTRICT,STUDENT_ID,ETHNIC_CODE,ETHNICITY_ORDER,PERCENTAGE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_EVENT",
    "PKColumns": "DISTRICT,EVENT_ID",
    "TableColumns": "DISTRICT,EVENT_ID,PUBLISH_EVENT,SUBJECT,MESSAGE_BODY,START_DATE_TIME,END_DATE_TIME,ALL_DAY_EVENT,LOCATION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_EVENT_ACTIVITY",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,ACTIVITY_CODE,EVENT_ID",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,ACTIVITY_CODE,EVENT_ID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_EVENT_COMP",
    "PKColumns": "DISTRICT,BUILDING,COMPETENCY_GROUP,STAFF_ID,EVENT_ID",
    "TableColumns": "DISTRICT,BUILDING,COMPETENCY_GROUP,STAFF_ID,EVENT_ID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_EVENT_HRM",
    "PKColumns": "DISTRICT,BUILDING,ROOM_ID,EVENT_ID",
    "TableColumns": "DISTRICT,BUILDING,ROOM_ID,EVENT_ID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_EVENT_MS",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,EVENT_ID",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,EVENT_ID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_EXCLUDE_HONOR",
    "PKColumns": "DISTRICT,STUDENT_ID,HONOR_TYPE",
    "TableColumns": "DISTRICT,STUDENT_ID,HONOR_TYPE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_EXCLUDE_IPR",
    "PKColumns": "DISTRICT,STUDENT_ID,ELIG_TYPE",
    "TableColumns": "DISTRICT,STUDENT_ID,ELIG_TYPE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_EXCLUDE_RANK",
    "PKColumns": "DISTRICT,STUDENT_ID,RANK_TYPE",
    "TableColumns": "DISTRICT,STUDENT_ID,RANK_TYPE,INCLUDE_CLASS_SIZE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_GEO_CFG",
    "PKColumns": "DISTRICT",
    "TableColumns": "DISTRICT,USE_GEO_CODE,USE_ZONES,SHARE_PLANS,ADDRESS_REQUIRED,ALLOW_OVERLAP,USE_PREFIX_SUFFIX,NEXT_ASSIGN_YEAR,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_GEO_CFG_DATES",
    "PKColumns": "DISTRICT",
    "TableColumns": "DISTRICT,USE_DATE_RANGE,REQUIRE_OVR_REASON,DISPLAY_DATE_MESSAGE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_GEO_PLAN_AREA",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,PLAN_AREA_NUMBER",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,PLAN_AREA_NUMBER,ZONE_NUMBER,DEVELOPMENT,STREET_PREFIX,STREET_NAME,STREET_TYPE,STREET_SUFFIX,COMPLEX,APARTMENT_REQ,ODD_START_ST_NUM,ODD_END_ST_NUM,EVEN_START_ST_NUM,EVEN_END_ST_NUM,CITY,STATE,ODD_ZIP,ODD_ZIP_PLUS4,EVEN_ZIP,EVEN_ZIP_PLUS4,START_LATITUDE,START_LONGITUDE,END_LATITUDE,END_LONGITUDE,HOME_DISTRICT,EXTERNAL_ID_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_GEO_STU_PLAN",
    "PKColumns": "DISTRICT,STUDENT_ID",
    "TableColumns": "DISTRICT,STUDENT_ID,PLAN_AREA_NUMBER,BUILDING,NEXT_BUILDING,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_GEO_ZONE_DATES",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,ZONE_NUMBER,BUILDING,HOME_BUILDING_TYPE,GRADE,START_DATE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,ZONE_NUMBER,BUILDING,HOME_BUILDING_TYPE,GRADE,START_DATE,END_DATE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_GEO_ZONE_DET",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,ZONE_NUMBER,BUILDING,HOME_BUILDING_TYPE,GRADE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,ZONE_NUMBER,BUILDING,HOME_BUILDING_TYPE,GRADE,HOME_BUILDING,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_GEO_ZONE_HDR",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,ZONE_NUMBER",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,ZONE_NUMBER,DESCRIPTION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_GRADE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,NEXT_GRADE,YEARS_TILL_GRAD,STATE_CODE_EQUIV,FEDERAL_CODE_EQUIV,ACTIVE,SIF_CODE,SIF2_CODE,PESC_CODE,GRADE_ORDER,GRAD_PLAN_LABEL,CHANGE_DATE_TIME,CHANGE_UID,CEDS_CODE",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_GROUP_HDR",
    "PKColumns": "DISTRICT,GROUP_CODE",
    "TableColumns": "DISTRICT,GROUP_CODE,DESCRIPTION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_GROUP_USED_FOR",
    "PKColumns": "DISTRICT,GROUP_CODE,USED_FOR_CODE",
    "TableColumns": "DISTRICT,GROUP_CODE,USED_FOR_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_HISPANIC",
    "PKColumns": "DISTRICT,STUDENT_ID,HISPANIC_CODE",
    "TableColumns": "DISTRICT,STUDENT_ID,HISPANIC_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_HISTORY_CFG",
    "PKColumns": "DISTRICT",
    "TableColumns": "DISTRICT,USE_ADDRESS_HISTORY,HIST_CONTACT_TYPE,HIST_RELATIONSHIP,HIST_LIVING_WITH,HIST_TRANSPORT_TO,HIST_TRANSPORT_FROM,HIST_DEVELOPMENT,HIST_APARTMENT,HIST_COMPLEX,HIST_STREET_NUMBER,HIST_STREET_PREFIX,HIST_STREET_NAME,HIST_STREET_SUFFIX,HIST_STREET_TYPE,HIST_CITY,HIST_STATE,HIST_ZIP,HIST_DELIVERY_POINT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_HOLD",
    "PKColumns": "DISTRICT,STUDENT_ID,ENTRY_WD_TYPE",
    "TableColumns": "DISTRICT,STUDENT_ID,FIRST_NAME,MIDDLE_NAME,LAST_NAME,GENERATION,BUILDING,GRADE,GENDER,LANGUAGE,COUNSELOR,HOUSE_TEAM,HOMEROOM_PRIMARY,HOMEROOM_SECONDARY,BIRTHDATE,NICKNAME,ENTRY_WD_TYPE,SIF_REFID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "reg_hold_calc_detail",
    "PKColumns": "DISTRICT,STUDENT_ID,HOLD_TYPE,ITEM_OR_CAT,CODE",
    "TableColumns": "DISTRICT,STUDENT_ID,HOLD_TYPE,ITEM_OR_CAT,CODE,CODE_OR_BALANCE,THRESHOLD,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_HOLD_RC_STATUS",
    "PKColumns": "DISTRICT,STUDENT_ID,CODE",
    "TableColumns": "DISTRICT,STUDENT_ID,CODE,FREE_TEXT,CALCULATED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_IEP_SETUP",
    "PKColumns": "DISTRICT",
    "TableColumns": "DISTRICT,SECURITY_TOKEN,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_IEP_STATUS",
    "PKColumns": "ID",
    "TableColumns": "ID,DISTRICT,STUDENT_ID,IEPPLUS_ID,STATUS_DESCRIPTION,START_DATE,EXIT_DATE,EXIT_REASON",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "REG_IMMUNIZATION",
    "PKColumns": "DISTRICT,STUDENT_ID,CODE",
    "TableColumns": "DISTRICT,STUDENT_ID,CODE,STATUS_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_IMPORT",
    "PKColumns": "DISTRICT,STUDENT_ID",
    "TableColumns": "DISTRICT,STUDENT_ID,FIRST_NAME,MIDDLE_NAME,LAST_NAME,GENERATION,STATE_REPORT_ID,PRIOR_STATE_ID,GENDER,ETHNIC_CODE,BIRTHDATE,LANGUAGE,MIGRANT,HOMELESS_STATUS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_IMPORT_CONTACT",
    "PKColumns": "DISTRICT,STUDENT_ID,CONTACT_SEQ",
    "TableColumns": "DISTRICT,STUDENT_ID,CONTACT_SEQ,FIRST_NAME,MIDDLE_NAME,LAST_NAME,GENERATION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_IMPORT_PROGRAM",
    "PKColumns": "DISTRICT,STUDENT_ID,PROGRAM_NAME",
    "TableColumns": "DISTRICT,STUDENT_ID,PROGRAM_NAME,PROGRAM_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_KEY_CONTACT_ID",
    "PKColumns": "DISTRICT,CONTACT_ID",
    "TableColumns": "DISTRICT,CONTACT_ID,WRAPPED,MAX_VALUE,EXTERNAL_VALUE,LAST_CMD,CMD_VALUE,CMD_DATE_TIME,CMD_UID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_LEGAL_INFO",
    "PKColumns": "DISTRICT,STUDENT_ID",
    "TableColumns": "DISTRICT,STUDENT_ID,LEGAL_FIRST_NAME,LEGAL_MIDDLE_NAME,LEGAL_LAST_NAME,LEGAL_GENERATION,LEGAL_GENDER,CHANGE_REASON,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_LOCKER",
    "PKColumns": "DISTRICT,BUILDING,LOCKER_ID",
    "TableColumns": "DISTRICT,BUILDING,LOCKER_ID,LOCKER_DESC,SERIAL_NUM,LOCATION,IS_LOCKED,MAX_ASSIGNED,HOMEROOM,GRADE,GENDER,HOUSE_TEAM,IN_SERVICE,CURRENT_COMBO,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_LOCKER_COMBO",
    "PKColumns": "DISTRICT,BUILDING,LOCKER_ID,COMBO_SEQUENCE",
    "TableColumns": "DISTRICT,BUILDING,LOCKER_ID,COMBO_SEQUENCE,COMBINATION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_MAP_STU_GEOCODE",
    "PKColumns": "DISTRICT,STUDENT_ID",
    "TableColumns": "DISTRICT,STUDENT_ID,LATITUDE,LONGITUDE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_MED_ALERTS",
    "PKColumns": "DISTRICT,STUDENT_ID,MED_ALERT_CODE,SEQUENCE_NUM",
    "TableColumns": "DISTRICT,STUDENT_ID,MED_ALERT_CODE,SEQUENCE_NUM,MED_ALERT_COMMENT,START_DATE,END_DATE,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_MED_PROCEDURE",
    "PKColumns": "DISTRICT,STUDENT_ID,CODE,PROCEDURE_DATE",
    "TableColumns": "DISTRICT,STUDENT_ID,CODE,PROCEDURE_DATE,STATUS_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_MP_DATES",
    "PKColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,TRACK,MARKING_PERIOD",
    "TableColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,TRACK,MARKING_PERIOD,START_DATE,END_DATE,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_MP_WEEKS",
    "PKColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,MARKING_PERIOD",
    "TableColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,MARKING_PERIOD,MP_ORDER,DURATION_TYPE,DESCRIPTION,START_WEEK_NUMBER,END_WEEK_NUMBER,SCHD_INTERVAL,TERM,RC_RUN,STATE_CODE_EQUIV,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_NEXT_YEAR",
    "PKColumns": "DISTRICT,STUDENT_ID",
    "TableColumns": "DISTRICT,STUDENT_ID,BUILDING,HOME_BUILDING,BUILDING_OVERRIDE,BUILDING_REASON,GRADE,COUNSELOR,HOMEROOM_PRIMARY,HOMEROOM_SECONDARY,HOUSE_TEAM,TRACK,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_NOTES",
    "PKColumns": "DISTRICT,STUDENT_ID,NOTE_TYPE,ENTRY_DATE_TIME",
    "TableColumns": "DISTRICT,STUDENT_ID,NOTE_TYPE,ENTRY_DATE_TIME,ENTRY_UID,NOTE_TEXT,SENSITIVE,PRIVATE_FLAG,PUBLISH_TO_WEB,APPOINTMENT_ID,CHANGE_DATE_TIME,CHANGE_UID,STUDENT_ALERT_TYPE",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_PERSONAL",
    "PKColumns": "DISTRICT,STUDENT_ID",
    "TableColumns": "DISTRICT,STUDENT_ID,SSN,BIRTH_CITY,BIRTH_STATE,BIRTH_COUNTRY,MEAL_STATUS,CLASSIFICATION,LOCKER_NUMBER,LOCKER_COMBINATION,COMMENTS,ETHNIC_CODE,HISPANIC,FED_RACE_ETHNIC,RESIDENCY_CODE,STATE_REPORT_ID,PREVIOUS_ID,PREVIOUS_ID_ASOF,SHOW_ALERTS,MIGRANT,AT_RISK,ESL,HAS_IEP,IEP_STATUS,SECTION_504_PLAN,HOMELESS_STATUS,MIGRANT_ID,CITIZEN_STATUS,MOTHER_MAIDEN_NAME,FEE_STATUS,FEE_STATUS_OVR,FEE_BALANCE,FERPA_NAME,FERPA_ADDRESS,FERPA_PHONE,FERPA_PHOTO,TRANSFER_BLDG_FROM,ACADEMIC_DIS,HAS_SSP,IEP_INTEGRATION,FOSTER_CARE,ORIGIN_COUNTRY,ELL_YEARS,IMMIGRANT,AT_RISK_CALC_OVR,AT_RISK_LAST_CALC,PRIVATE_MILITARY,PRIVATE_COLLEGE,PRIVATE_COMPANY,PRIVATE_ORGANIZATIONS,PRIVATE_INDIVIDUAL,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_PHONE_HIST",
    "PKColumns": "DISTRICT,CONTACT_ID,PHONE_TYPE,STUDENT_ID,ADDRESS_TYPE,CHANGE_DATE_TIME",
    "TableColumns": "DISTRICT,CONTACT_ID,PHONE_TYPE,STUDENT_ID,ADDRESS_TYPE,PHONE_LISTING,PHONE,PHONE_EXTENSION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_PHONE_HISTORY_CFG",
    "PKColumns": "DISTRICT",
    "TableColumns": "DISTRICT,USE_PHONE_HISTORY,HIST_STU_NUMBER,HIST_STU_EXT,HIST_STU_LISTING,HIST_CONTACT_NUM,HIST_CONTACT_EXT,HIST_CONTACT_LISTING,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_PROG_SETUP_BLD",
    "PKColumns": "DISTRICT,PROGRAM_ID,BUILDING",
    "TableColumns": "DISTRICT,PROGRAM_ID,BUILDING,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_PROGRAM_COLUMN",
    "PKColumns": "DISTRICT,PROGRAM_ID,FIELD_NUMBER",
    "TableColumns": "DISTRICT,PROGRAM_ID,FIELD_NUMBER,FIELD_ORDER,FIELD_LEVEL,TABLE_NAME,SCREEN_NUMBER,COLUMN_NAME,LINK_DATES_TO,LINK_TYPE,LABEL,SCREEN_TYPE,DATA_TYPE,DATA_SIZE,ADD_DEFAULT,VALIDATION_LIST,VALIDATION_TABLE,CODE_COLUMN,DESCRIPTION_COLUMN,STATE_CODE_EQUIV,USE_REASONS,USE_OVERRIDE,YREND_INACTIVES,INACTIVE_SRC_RESET,INACTIVE_WD_CODE,YREND_ACTIVES,ACTIVE_SRC_RESET,ACTIVE_WD_CODE,YREND_ENTRY_DATE,YREND_ACTPRES,SEC_PACKAGE,SEC_SUBPACKAGE,SEC_FEATURE,YREND_LOCKED,CHANGE_DATE_TIME,CHANGE_UID,ROW_IDENTITY",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_PROGRAM_SETUP",
    "PKColumns": "DISTRICT,PROGRAM_ID",
    "TableColumns": "DISTRICT,PROGRAM_ID,DESCRIPTION,SEC_PACKAGE,SEC_SUBPACKAGE,SEC_FEATURE,START_DATE,END_DATE,INSTRUCT_HOURS,INSTRUCT_HOUR_UNIT,RESERVED,RULES_LOCKED,CHANGE_DATE_TIME,CHANGE_UID,ROW_IDENTITY",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_PROGRAM_USER",
    "PKColumns": "DISTRICT,PROGRAM_ID,SCREEN_NUMBER,FIELD_NUMBER,LIST_SEQUENCE",
    "TableColumns": "DISTRICT,PROGRAM_ID,SCREEN_NUMBER,FIELD_NUMBER,LIST_SEQUENCE,FIELD_VALUE,CHANGE_DATE_TIME,CHANGE_UID,ROW_IDENTITY",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_PROGRAMS",
    "PKColumns": "DISTRICT,PROGRAM_ID,FIELD_NUMBER,STUDENT_ID,START_DATE,SUMMER_SCHOOL",
    "TableColumns": "DISTRICT,PROGRAM_ID,FIELD_NUMBER,STUDENT_ID,START_DATE,SUMMER_SCHOOL,ENTRY_REASON,PROGRAM_VALUE,END_DATE,WITHDRAWAL_REASON,PROGRAM_OVERRIDE,CHANGE_DATE_TIME,CHANGE_UID,ROW_IDENTITY",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_PRT_FLG_DFLT",
    "PKColumns": "DISTRICT,CONTACT_TYPE",
    "TableColumns": "DISTRICT,CONTACT_TYPE,MAIL_ATT,MAIL_DISC,MAIL_FEES,MAIL_IPR,MAIL_MED,MAIL_RC,MAIL_REG,MAIL_SCHD,MAIL_SSP,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_ROOM",
    "PKColumns": "DISTRICT,BUILDING,ROOM_ID",
    "TableColumns": "DISTRICT,BUILDING,ROOM_ID,DESCRIPTION,ROOM_TYPE,MAX_STUDENTS,ROOM_AVAILABLE,HANDICAPPED_ACCESS,COMPUTERS_COUNT,PHONE,PHONE_EXTENSION,COMMENTS,GROUP_CODE,REGULAR_YEAR,SUMMER_SCHOOL,STATE_CODE_EQUIV,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_ROOM_AIN",
    "PKColumns": "DISTRICT,BUILDING,ROOM_ID",
    "TableColumns": "DISTRICT,BUILDING,ROOM_ID,IS_HRM_SCHD_PRIMARY_HOMEROOM,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_STAFF",
    "PKColumns": "DISTRICT,STAFF_ID",
    "TableColumns": "DISTRICT,STAFF_ID,FIRST_NAME,MIDDLE_NAME,LAST_NAME,MAIDEN_NAME,TITLE_CODE,EMAIL,SSN,FMS_DEPARTMENT,FMS_EMPL_NUMBER,FMS_LOCATION,TEACHER_LOAD,LOGIN_ID,SUB_LOGIN_ID,SUB_EXPIRATION,GENDER,PRIM_ETHNIC_CODE,HISPANIC,FED_RACE_ETHNIC,BIRTHDATE,STAFF_STATE_ID,ESP_LOGIN_ID,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID,GENDER_IDENTITY,CLASSLINK_ID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_STAFF_ADDRESS",
    "PKColumns": "DISTRICT,STAFF_ID",
    "TableColumns": "DISTRICT,STAFF_ID,APARTMENT,COMPLEX,STREET_NUMBER,STREET_PREFIX,STREET_NAME,STREET_SUFFIX,STREET_TYPE,CITY,STATE,ZIP,DELIVERY_POINT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_STAFF_BLDGS",
    "PKColumns": "DISTRICT,BUILDING,STAFF_ID",
    "TableColumns": "DISTRICT,BUILDING,STAFF_ID,STAFF_NAME,INITIALS,IS_COUNSELOR,IS_TEACHER,IS_ADVISOR,HOMEROOM_PRIMARY,HOMEROOM_SECONDARY,ROOM,HOUSE_TEAM,DEPARTMENT,PHONE,PHONE_EXTENSION,ACTIVE,IS_PRIMARY_BLDG,GROUP_CODE,MAXIMUM_CONTIGUOUS,MAXIMUM_PER_DAY,ALLOW_OVERRIDE,REGULAR_YEAR,SUMMER_SCHOOL,TAKE_LUNCH_COUNTS,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_STAFF_BLDGS_ELEM_AIN",
    "PKColumns": "DISTRICT,BUILDING,STAFF_ID",
    "TableColumns": "DISTRICT,BUILDING,STAFF_ID,ELEM_NEXT_HOMEROOM_PRIMARY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_STAFF_BLDGS_HRM_AIN",
    "PKColumns": "DISTRICT,BUILDING,STAFF_ID",
    "TableColumns": "DISTRICT,BUILDING,STAFF_ID,NEXT_YEAR_PRIMARY_HRM,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_STAFF_ETHNIC",
    "PKColumns": "DISTRICT,STAFF_ID,ETHNIC_CODE",
    "TableColumns": "DISTRICT,STAFF_ID,ETHNIC_CODE,ETHNICITY_ORDER,PERCENTAGE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_STAFF_HISPANIC",
    "PKColumns": "DISTRICT,STAFF_ID,HISPANIC_CODE",
    "TableColumns": "DISTRICT,STAFF_ID,HISPANIC_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_STAFF_PHOTO_CFG",
    "PKColumns": "DISTRICT",
    "TableColumns": "DISTRICT,PHOTO_PATH,PHOTO_DIRECTORY,PHOTO_NAME,PHOTO_EXTENSION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_STAFF_QUALIFY",
    "PKColumns": "DISTRICT,STAFF_ID,QUALIFICATION",
    "TableColumns": "DISTRICT,STAFF_ID,QUALIFICATION,EXPIRATION_DATE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_STAFF_SIGNATURE",
    "PKColumns": "DISTRICT,STAFF_ID",
    "TableColumns": "DISTRICT,STAFF_ID,TRANSCRIPT_SIGNATUR,TRANSCRIPT_TITLE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_STAFF_SIGNATURE_CFG",
    "PKColumns": "DISTRICT",
    "TableColumns": "DISTRICT,SIGNATURE_PATH,SIGNATURE_DIRECTOR,SIGNATURE_NAME,SIGNATURE_EXTENSIO,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_STATE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STU_WITHDRAW_RULE,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_STU_AT_RISK",
    "PKColumns": "DISTRICT,STUDENT_ID,FACTOR_CODE",
    "TableColumns": "DISTRICT,STUDENT_ID,FACTOR_CODE,FACTOR_STATUS,STATUS_OVR,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_STU_AT_RISK_CALC",
    "PKColumns": "DISTRICT,STUDENT_ID",
    "TableColumns": "DISTRICT,STUDENT_ID,LTDB_CALC_DATE,ATT_CALC_DATE,REG_CALC_DATE,MR_CALC_DATE,DISC_CALC_DATE,IPR_CALC_DATE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_STU_CONT_HIST",
    "PKColumns": "DISTRICT,STUDENT_ID,CONTACT_ID,CONTACT_TYPE,LIVING_WITH,TRANSPORT_TO,TRANSPORT_FROM,CHANGE_DATE_TIME,CHANGE_UID",
    "TableColumns": "DISTRICT,STUDENT_ID,CONTACT_ID,CONTACT_TYPE,RELATION_CODE,LIVING_WITH,TRANSPORT_TO,TRANSPORT_FROM,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_STU_CONTACT",
    "PKColumns": "DISTRICT,STUDENT_ID,CONTACT_ID,CONTACT_TYPE",
    "TableColumns": "DISTRICT,STUDENT_ID,CONTACT_ID,CONTACT_TYPE,CONTACT_PRIORITY,RELATION_CODE,LIVING_WITH,WEB_ACCESS,COMMENTS,TRANSPORT_TO,TRANSPORT_FROM,MAIL_ATT,MAIL_DISC,MAIL_FEES,MAIL_IPR,MAIL_MED,MAIL_RC,MAIL_REG,MAIL_SCHD,MAIL_SSP,LEGAL_GUARD,CUST_GUARD,UPD_STU_EO_INFO,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_STU_CONTACT_ALERT",
    "PKColumns": "DISTRICT,STUDENT_ID,CONTACT_ID,ALERT_TYPE",
    "TableColumns": "DISTRICT,STUDENT_ID,CONTACT_ID,ALERT_TYPE,SIGNUP_DATE,LAST_ALERT_DATE,NEXT_ALERT_DATE,SCHEDULE_TYPE,SCHD_INTERVAL,SCHD_DOW,NOTIFICATION_TYPE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_STU_CONTACT_ALERT_ATT",
    "PKColumns": "DISTRICT,STUDENT_ID,CONTACT_ID,ATTENDANCE_CODE",
    "TableColumns": "DISTRICT,STUDENT_ID,CONTACT_ID,ATTENDANCE_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_STU_CONTACT_ALERT_AVG",
    "PKColumns": "DISTRICT,STUDENT_ID,CONTACT_ID",
    "TableColumns": "DISTRICT,STUDENT_ID,CONTACT_ID,MIN_AVG,MAX_AVG,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_STU_CONTACT_ALERT_DISC",
    "PKColumns": "DISTRICT,STUDENT_ID,CONTACT_ID,CODE",
    "TableColumns": "DISTRICT,STUDENT_ID,CONTACT_ID,CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_STU_CONTACT_ALERT_GB",
    "PKColumns": "DISTRICT,STUDENT_ID,CONTACT_ID",
    "TableColumns": "DISTRICT,STUDENT_ID,CONTACT_ID,MIN_AVG,MAX_AVG,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_SUMMER_SCHOOL",
    "PKColumns": "DISTRICT,STUDENT_ID",
    "TableColumns": "DISTRICT,STUDENT_ID,BUILDING,GRADE,TRACK,CALENDAR,COUNSELOR,HOUSE_TEAM,HOMEROOM_PRIMARY,HOMEROOM_SECONDARY,CHANGE_DATE_TIME,CHANGE_UID,ROW_IDENTITY",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_TRACK",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,CODE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,CODE,DESCRIPTION,START_DATE,END_DATE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_TRAVEL",
    "PKColumns": "DISTRICT,STUDENT_ID,TRAVEL_DIRECTION,TRAVEL_TRIP,TRAVEL_SEGMENT",
    "TableColumns": "DISTRICT,STUDENT_ID,TRAVEL_DIRECTION,TRAVEL_TRIP,START_DATE,END_DATE,TRAVEL_SEGMENT,SUNDAY,MONDAY,TUESDAY,WEDNESDAY,THURSDAY,FRIDAY,SATURDAY,TRAVEL_TYPE,TRANSPORT_DISTANCE,BUS_NUMBER,BUS_ROUTE,STOP_NUMBER,STOP_TIME,STOP_DESCRIPTION,SHUTTLE_STOP,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_USER",
    "PKColumns": "DISTRICT,STUDENT_ID,SCREEN_NUMBER,FIELD_NUMBER,LIST_SEQUENCE",
    "TableColumns": "DISTRICT,STUDENT_ID,SCREEN_NUMBER,FIELD_NUMBER,LIST_SEQUENCE,FIELD_VALUE,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_USER_BUILDING",
    "PKColumns": "DISTRICT,BUILDING,SCREEN_NUMBER,FIELD_NUMBER,LIST_SEQUENCE",
    "TableColumns": "DISTRICT,BUILDING,SCREEN_NUMBER,FIELD_NUMBER,LIST_SEQUENCE,FIELD_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_USER_DISTRICT",
    "PKColumns": "DISTRICT,SCREEN_NUMBER,FIELD_NUMBER,LIST_SEQUENCE",
    "TableColumns": "DISTRICT,SCREEN_NUMBER,FIELD_NUMBER,LIST_SEQUENCE,FIELD_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_USER_PLAN_AREA",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,PLAN_AREA_NUMBER,SCREEN_NUMBER,FIELD_NUMBER",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,PLAN_AREA_NUMBER,SCREEN_NUMBER,FIELD_NUMBER,FIELD_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_USER_STAFF",
    "PKColumns": "DISTRICT,STAFF_ID,SCREEN_NUMBER,LIST_SEQUENCE,FIELD_NUMBER",
    "TableColumns": "DISTRICT,STAFF_ID,SCREEN_NUMBER,LIST_SEQUENCE,FIELD_NUMBER,FIELD_VALUE,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_USER_STAFF_BLD",
    "PKColumns": "DISTRICT,BUILDING,STAFF_ID,SCREEN_NUMBER,LIST_SEQUENCE,FIELD_NUMBER",
    "TableColumns": "DISTRICT,BUILDING,STAFF_ID,SCREEN_NUMBER,LIST_SEQUENCE,FIELD_NUMBER,FIELD_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_YREND_CRITERIA",
    "PKColumns": "DISTRICT,RUN_PROCESS,CRITERION",
    "TableColumns": "DISTRICT,RUN_PROCESS,CRITERION,SEQUENCE,DESCRIPTION,STUDENT_STATUS,ROLLOVER_ENTRY,ROLLOVER_WITH,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_YREND_RUN",
    "PKColumns": "DISTRICT,RUN_KEY",
    "TableColumns": "DISTRICT,RUN_KEY,SCHOOL_YEAR,SUMMER_SCHOOL,RUN_STATUS,CALENDAR_SELECT,CRITERIA_SELECT,PURGE_APPT_DATE,PURGE_TAC_MSG_DATE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_YREND_RUN_CAL",
    "PKColumns": "DISTRICT,RUN_KEY,BUILDING,CALENDAR",
    "TableColumns": "DISTRICT,RUN_KEY,BUILDING,CALENDAR,SCHOOL_YEAR,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_YREND_RUN_CRIT",
    "PKColumns": "DISTRICT,RUN_KEY,CRITERION",
    "TableColumns": "DISTRICT,RUN_KEY,CRITERION,SCHOOL_YEAR,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_YREND_SELECT",
    "PKColumns": "DISTRICT,RUN_PROCESS,CRITERION,LINE_NUMBER",
    "TableColumns": "DISTRICT,RUN_PROCESS,CRITERION,LINE_NUMBER,AND_OR_FLAG,TABLE_NAME,COLUMN_NAME,OPERATOR,SEARCH_VALUE1,SEARCH_VALUE2,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_YREND_STUDENTS",
    "PKColumns": "DISTRICT,STUDENT_ID,RUN_PROCESS",
    "TableColumns": "DISTRICT,STUDENT_ID,RUN_PROCESS,SCHOOL_YEAR,REG_ROLLOVER,REG_CRITERION,WAS_PREREG,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REG_YREND_UPDATE",
    "PKColumns": "DISTRICT,RUN_PROCESS,CRITERION,LINE_NUMBER",
    "TableColumns": "DISTRICT,RUN_PROCESS,CRITERION,LINE_NUMBER,TABLE_NAME,COLUMN_NAME,NEW_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGPROG_YREND_RUN",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,RUN_KEY",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,RUN_KEY,RUN_DATE,RUN_STATUS,RESTORE_KEY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGPROG_YREND_TABS",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,RUN_KEY,TABLE_NAME",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,RUN_KEY,TABLE_NAME,RESTORE_ORDER,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_ACADEMIC_DIS",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_ACCDIST",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_ALT_PORTFOLIO",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,SIF_CODE,SIF2_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_APPT_TYPE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,LINK_PATH,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_AR_ACT641",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_AR_ANTICSVCE",
    "PKColumns": "DISTRICT,code",
    "TableColumns": "DISTRICT,code,description,ACTIVE,change_date_time,change_uid",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_AR_BARRIER",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_AR_BIRTHVER",
    "PKColumns": "DISTRICT,code",
    "TableColumns": "DISTRICT,code,description,ACTIVE,change_date_time,change_uid",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_AR_CNTYRESID",
    "PKColumns": "DISTRICT,code",
    "TableColumns": "DISTRICT,code,description,ACTIVE,change_date_time,change_uid",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_AR_COOPS",
    "PKColumns": "DISTRICT,code",
    "TableColumns": "DISTRICT,code,description,ACTIVE,change_date_time,change_uid",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_AR_CORECONT",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_AR_DEVICE_ACC",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_AR_ELDPROG",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_AR_ELL_MONI",
    "PKColumns": "DISTRICT,code",
    "TableColumns": "DISTRICT,code,description,ACTIVE,change_date_time,change_uid",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_AR_FACTYPE",
    "PKColumns": "DISTRICT,code",
    "TableColumns": "DISTRICT,code,description,ACTIVE,change_date_time,change_uid",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_AR_HOMELESS",
    "PKColumns": "DISTRICT,code",
    "TableColumns": "DISTRICT,code,description,ACTIVE,change_date_time,change_uid",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_AR_IMMSTATUS",
    "PKColumns": "district,code",
    "TableColumns": "district,code,description,ACTIVE,change_date_time,change_uid",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_AR_INS_CARRI",
    "PKColumns": "DISTRICT,code",
    "TableColumns": "DISTRICT,code,description,ACTIVE,change_date_time,change_uid",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_AR_LEARNDVC",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_AR_MILITARYDEPEND",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_AR_NETPRFRM",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_AR_NETTYPE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_AR_PRESCHOOL",
    "PKColumns": "DISTRICT,code",
    "TableColumns": "DISTRICT,code,description,ACTIVE,change_date_time,change_uid",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_AR_RAEL",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_AR_SCH_LEA",
    "PKColumns": "DISTRICT,code",
    "TableColumns": "DISTRICT,code,description,ACTIVE,change_date_time,change_uid",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_AR_SEND_LEA",
    "PKColumns": "DISTRICT,code",
    "TableColumns": "DISTRICT,code,description,ACTIVE,change_date_time,change_uid",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_AR_SHAREDDVC",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_AR_STU_INSTRUCT",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_AR_SUP_SVC",
    "PKColumns": "DISTRICT,code",
    "TableColumns": "DISTRICT,code,description,ACTIVE,change_date_time,change_uid",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_AT_RISK_REASON",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,USE_SSP,USE_AT_RISK,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_ATTACHMENT_CATEGORY",
    "PKColumns": "DISTRICT,ATTACHMENT_CATEGORY",
    "TableColumns": "DISTRICT,ATTACHMENT_CATEGORY,DESCRIPTION,SEC_PACKAGE,SEC_SUBPACKAGE,SEC_FEATURE,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_BLDG_REASON",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,SIF_CODE,SIF2_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_BLDG_TYPES",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_CC_BLDG_TYPE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,SCHOOL_TYPE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_CC_MARK_TYPE",
    "PKColumns": "DISTRICT,MARK_NO",
    "TableColumns": "DISTRICT,MARK_NO,MARK_TYPE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_CITIZENSHIP",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_CLASSIFY",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,SCHEDULING_WEIGHT,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_COMPLEX",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,TYPE,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_COMPLEX_TYPE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_COUNTRY",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_COUNTY",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_CURR_CODE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_DAY_TYPE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_DEPARTMENT",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,DEPT_ORDER,STATE_CODE_EQUIV,PERF_PLUS_CODE,ACTIVE,SIF_CODE,SIF2_CODE,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_DIPLOMAS",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,TRANSCRIPT_DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_DISABILITY",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,SENSITIVE,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_EDU_LEVEL",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_ELIG_REASON",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,PRIORITY,ELIGIBLE_FLAG,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_ELIG_STATUS",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,PRIORITY,ELIGIBLE_FLAG,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_ENTRY",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,SIF_CODE,SIF2_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_ETHNICITY",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,FEDERAL_CODE_EQUIV,ACTIVE,SIF_CODE,SIF2_CODE,CHANGE_DATE_TIME,CHANGE_UID,PREVIOUSLY_REPORTED_AS",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_GENDER",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,FEDERAL_CODE_EQUIV,SIF_CODE,SIF2_CODE,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_GENDER_IDENTITY",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV_01,STATE_CODE_EQUIV_02,STATE_CODE_EQUIV_03,STATE_CODE_EQUIV_04,STATE_CODE_EQUIV_05,STATE_CODE_EQUIV_06,STATE_CODE_EQUIV_07,STATE_CODE_EQUIV_08,STATE_CODE_EQUIV_09,STATE_CODE_EQUIV_10,FED_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_GENERATION",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_GRAD_PLANS",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,EXPECTED,ACTUAL,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_GRADE_CEDS_CODE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_GRADE_PESC_CODE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_GROUP_USED_FOR",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_HISPANIC",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID,PREVIOUSLY_REPORTED_AS",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_HOLD_RC_CODE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_HOME_BLDG_TYPE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_HOMELESS",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,SIF2_CODE,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_HOSPITAL",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_HOUSE_TEAM",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_IEP_STATUS",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_IMMUN_STATUS",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_IMMUNS",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_LANGUAGE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,ALTERNATE_LANGUAGE,HAC_LANGUAGE,SIF_CODE,SIF2_CODE,CHANGE_DATE_TIME,CHANGE_UID,USE_IN_HOME,USE_IN_NATIVE",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "regtb_language_SD091114",
    "PKColumns": "",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,ALTERNATE_LANGUAGE,HAC_LANGUAGE,SIF_CODE,SIF2_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_LEARNING_LOCATION",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID,ROW_IDENTITY",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_MEAL_STATUS",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,SIF_CODE,SIF2_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_MED_PROC",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_MEDIC_ALERT",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,SENSITIVE,ACTIVE,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_NAME_CHGRSN ",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_NOTE_TYPE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,SENSITIVE,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID,STATE_CODE_EQUIV",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_PESC_CODE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_PHONE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,STATE_CODE_EQUIV,SIF_CODE,SIF2_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_PROC_STATUS",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_PROG_ENTRY",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_PROG_WITH",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_QUALIFY",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_RELATION",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,SIF_CODE,SIF2_CODE,PESC_CODE,CHANGE_DATE_TIME,CHANGE_UID,IMS_EQUIV",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_RELATION_PESC_CODE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_REQ_GROUP",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,IMAGE_FILE_NAME,GRAD_OR_SUPP,STATE_CODE_EQUIV,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_RESIDENCY",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,SIF_CODE,SIF2_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_ROOM_TYPE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_SCHOOL",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_SCHOOL_YEAR",
    "PKColumns": "DISTRICT,SCHOOL_YEAR",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,DISPLAY_YEAR,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_SIF_AUTH_MAP",
    "PKColumns": "DISTRICT,SIF_REFID_TYPE,SYSTEM_TYPE,SYSTEM_VALUE,ELEMENT_NAME",
    "TableColumns": "DISTRICT,SIF_REFID_TYPE,SYSTEM_TYPE,SYSTEM_VALUE,ELEMENT_NAME,TO_TABLE,TO_COLUMN,TO_USER_SCREEN,TO_USER_FIELD,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_SIF_JOBCLASS",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,IS_COUNSELOR,IS_TEACHER,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_ST_PREFIX",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_ST_SUFFIX",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_ST_TYPE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_STATE_BLDG",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID,LOCAL_BUILDING",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_TITLE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_TRANSPORT_CODE",
    "PKColumns": "DISTRICT,CODE,STATE_CODE_EQUIV",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_TRAVEL",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,SIF_CODE,SIF2_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "REGTB_WITHDRAWAL",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,SIF_CODE,SIF2_CODE,DROPOUT_CODE,STUDENT_EXIT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_ALLOCATION",
    "PKColumns": "DISTRICT,BUILDING,GROUP_TYPE,GROUP_CODE,PERIOD,MARKING_PERIOD,CYCLE",
    "TableColumns": "DISTRICT,BUILDING,GROUP_TYPE,GROUP_CODE,PERIOD,MARKING_PERIOD,CYCLE,ALLOCATIONS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_CFG",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,MAXIMUM_TIMESLOTS,DEF_ADD_DATE_CODE,DEFAULT_ADD_DATE,CURRENT_INTERVAL,DATE_CHECK,IN_PROGRESS,DISPLAY_MSE_BLDG,OUTPUT_FILE_PATH,MAX_SCAN_GUID,TRAIL_MARKS,MULTIPLE_BELL_SCHD,DEFAULT_DURATION,DEFAULT_MAX_SEATS,DEFAULT_MARKS_ARE,TEA_SCHD_STU_SUMM,SUB_SCHD_STU_SUMM,TEA_SCHD_STU_REC,SUB_SCHD_STU_REC,TAC_LIMIT_REC_NUM,TAC_LIMIT_REC_DEPT,PREREQ_CRS_BLDG,PREREQ_CHK_REQ,PREREQ_CHK_SCHD,PREREQ_CRS_TOOK,DEFAULT_NOMARKS_FIRST_DAYS,DEFAULT_UNGRADED_LAST_DAYS,DEFAULT_FIRST_NEXT,DEFAULT_LAST_PREVIOUS,LAST_ISSUED_BY,USE_UNGRADED,USE_FOCUS,MAX_FOCUS_PERCENT,REQ_CRS_STAFF_DATE_ENTRY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_CFG_DISC_OFF",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,OFFENSE_CODE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,OFFENSE_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_CFG_ELEM_AIN",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,USE_ELEM_SCHD,CHANGE_DATE_TIME,CHANGE_UID",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,USE_ELEM_SCHD,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_CFG_FOCUS_CRT",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,SEQUENCE_NUM",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,SEQUENCE_NUM,AND_OR_FLAG,SCREEN_TYPE,TABLE_NAME,FIELD_NUMBER,SCREEN_NUMBER,COLUMN_NAME,PROGRAM_ID,OPERATOR,SEARCH_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_CFG_HOUSETEAM",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,HOUSE_TEAM",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,HOUSE_TEAM,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_CFG_HRM_AIN",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,SCHD_BY_PRIMARY_HRM,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_CFG_INTERVAL",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,SCHD_INTERVAL",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,SCHD_INTERVAL,DESCRIPTION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_CNFLCT_MATRIX",
    "PKColumns": "DISTRICT,BUILDING,MATRIX_TYPE,SCHD_INTERVAL,COURSE1,COURSE2",
    "TableColumns": "DISTRICT,BUILDING,MATRIX_TYPE,SCHD_INTERVAL,COURSE1,COURSE2,NUMBER_CONFLICTS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_COURSE",
    "PKColumns": "DISTRICT,BUILDING,COURSE",
    "TableColumns": "DISTRICT,BUILDING,COURSE,BUILDING_TYPE,DIST_LEVEL,DESCRIPTION,LONG_DESCRIPTION,DEPARTMENT,HOUSE_TEAM,STUDY_HALL,REGULAR_SCHOOL,SUMMER_SCHOOL,VOTEC,ACTIVE_STATUS,SIMPLE_TALLY,CONFLICT_MATRIX,GENDER_RESTRICTION,ALTERNATE_COURSE,CREDIT,FEE,PRIORITY,SEMESTER_WEIGHT,BLOCK_TYPE,SCAN_COURSE,TAKE_ATTENDANCE,RECEIVE_MARK,COURSE_LEVEL,SUBJ_AREA_CREDIT,REC_NEXT_COURSE,REQUEST_FROM_HAC,SAME_TEACHER,INCLD_PASSING_TIME,COURSE_CREDIT_BASIS,NCES_CODE,INCLD_CURRICULUM_CONNECTOR,MIN_GRADE,MAX_GRADE,CLASSIFY_STUS_MAX,CLASSIFY_NUM_OR_PER,SIF_CREDIT_TYPE,SIF_INSTRUCTIONAL_LEVEL,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_COURSE_BLOCK",
    "PKColumns": "DISTRICT,BUILDING,BLOCK_COURSE,BLOCKETTE_COURSE",
    "TableColumns": "DISTRICT,BUILDING,BLOCK_COURSE,BLOCKETTE_COURSE,SAME_SECTION,MANDATORY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_COURSE_GPA",
    "PKColumns": "DISTRICT,BUILDING,COURSE,GPA_TYPE",
    "TableColumns": "DISTRICT,BUILDING,COURSE,GPA_TYPE,GPA_LEVEL,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_COURSE_GRADE",
    "PKColumns": "DISTRICT,BUILDING,COURSE,RESTRICT_GRADE",
    "TableColumns": "DISTRICT,BUILDING,COURSE,RESTRICT_GRADE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_COURSE_HONORS",
    "PKColumns": "DISTRICT,BUILDING,COURSE,HONOR_TYPE",
    "TableColumns": "DISTRICT,BUILDING,COURSE,HONOR_TYPE,HONOR_LEVEL,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_COURSE_QUALIFY",
    "PKColumns": "DISTRICT,BUILDING,COURSE,QUALIFICATION",
    "TableColumns": "DISTRICT,BUILDING,COURSE,QUALIFICATION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_COURSE_SEQ",
    "PKColumns": "DISTRICT,BUILDING,COURSE_OR_GROUP_A,SEQUENCE_A,COURSE_OR_GROUP_B,SEQUENCE_B",
    "TableColumns": "DISTRICT,BUILDING,SEQUENCE_NUM,COURSE_OR_GROUP_A,SEQUENCE_A,SEQUENCE_TYPE,COURSE_OR_GROUP_B,SEQUENCE_B,IS_VALID,ERROR_MESSAGE,PREREQ_MIN_MARK,PREREQ_MARK_TYPE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_COURSE_SUBJ",
    "PKColumns": "DISTRICT,BUILDING,COURSE,SUBJECT_AREA",
    "TableColumns": "DISTRICT,BUILDING,COURSE,SUBJECT_AREA,SUBJ_ORDER,SUB_AREA,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_COURSE_SUBJ_TAG",
    "PKColumns": "DISTRICT,BUILDING,COURSE,SUBJECT_AREA,TAG",
    "TableColumns": "DISTRICT,BUILDING,COURSE,SUBJECT_AREA,TAG,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_COURSE_USER",
    "PKColumns": "DISTRICT,BUILDING,COURSE,SCREEN_NUMBER,FIELD_NUMBER,LIST_SEQUENCE",
    "TableColumns": "DISTRICT,BUILDING,COURSE,SCREEN_NUMBER,FIELD_NUMBER,LIST_SEQUENCE,FIELD_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_CRS_BLDG_TYPE",
    "PKColumns": "DISTRICT,BUILDING,COURSE,BLDG_TYPE",
    "TableColumns": "DISTRICT,BUILDING,COURSE,BLDG_TYPE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_CRS_GROUP_DET",
    "PKColumns": "DISTRICT,BUILDING,COURSE_GROUP,COURSE_BUILDING,COURSE",
    "TableColumns": "DISTRICT,BUILDING,COURSE_GROUP,COURSE_BUILDING,COURSE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_CRS_GROUP_HDR",
    "PKColumns": "DISTRICT,BUILDING,COURSE_GROUP",
    "TableColumns": "DISTRICT,BUILDING,COURSE_GROUP,DESCRIPTION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_CRS_MARK_TYPE",
    "PKColumns": "DISTRICT,BUILDING,COURSE,MARK_TYPE",
    "TableColumns": "DISTRICT,BUILDING,COURSE,MARK_TYPE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_CRS_MSB_COMBO",
    "PKColumns": "DISTRICT,BUILDING,COMBINATION_NUMBER,COMBINATION_COURSE",
    "TableColumns": "DISTRICT,BUILDING,COMBINATION_NUMBER,COMBINATION_COURSE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_CRS_MSB_DET",
    "PKColumns": "DISTRICT,BUILDING,COURSE,COURSE_SECTION",
    "TableColumns": "DISTRICT,BUILDING,COURSE,COURSE_SECTION,MEETING_CODE,STAFF_TYPE,STAFF_RESOURCE,ROOM_TYPE,ROOM_RESOURCE,MAXIMUM_SEATS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_CRS_MSB_HDR",
    "PKColumns": "DISTRICT,BUILDING,COURSE",
    "TableColumns": "DISTRICT,BUILDING,COURSE,NUMBER_REQUESTS,AVERAGE_CLASS_SIZE,NUMBER_SECTIONS,SECTIONS_SAME,COURSE_LENGTH,DURATION_TYPE,SPAN,SAME_TEACHER,SAME_PERIOD,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_CRS_MSB_PATRN",
    "PKColumns": "DISTRICT,BUILDING,COURSE,COURSE_SECTION,SEM_OR_MP",
    "TableColumns": "DISTRICT,BUILDING,COURSE,COURSE_SECTION,SEM_OR_MP,PATTERN,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_CRSSEQ_MARKTYPE",
    "PKColumns": "DISTRICT,BUILDING,COURSE_OR_GROUP_A,SEQUENCE_A,COURSE_OR_GROUP_B,SEQUENCE_B,PREREQ_MARK_TYPE",
    "TableColumns": "DISTRICT,BUILDING,COURSE_OR_GROUP_A,SEQUENCE_A,COURSE_OR_GROUP_B,SEQUENCE_B,PREREQ_MARK_TYPE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_DISTCRS_BLDG_TYPES",
    "PKColumns": "DISTRICT,BUILDING,COURSE,BUILDING_TYPE",
    "TableColumns": "DISTRICT,BUILDING,COURSE,BUILDING_TYPE,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_DISTCRS_SECTIONS_OVERRIDE",
    "PKColumns": "DISTRICT,BUILDING,COURSE,PAGE_SECTION",
    "TableColumns": "DISTRICT,BUILDING,COURSE,PAGE_SECTION,BLDG_OVERRIDDEN,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_DISTRICT_CFG",
    "PKColumns": "DISTRICT",
    "TableColumns": "DISTRICT,USE_DIST_CRS_CAT,BLDGS_UPD_CRS_CAT,BLDGS_ADD_CRS_CAT,CLASSIFY_STUS_MAX,CLASSIFY_NUM_OR_PER,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_DISTRICT_CFG_UPD",
    "PKColumns": "DISTRICT,PAGE_SECTION",
    "TableColumns": "DISTRICT,PAGE_SECTION,CAN_UPDATE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_LUNCH_CODE",
    "PKColumns": "DISTRICT,BUILDING,LUNCH_CODE",
    "TableColumns": "DISTRICT,BUILDING,LUNCH_CODE,START_TIME,END_TIME,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_MS",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,COURSE,COURSE_SECTION",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,COURSE,COURSE_SECTION,SECTION_KEY,DESCRIPTION,STUDY_HALL,MAXIMUM_SEATS,DEPARTMENT,VOTEC,FEE,GENDER_RESTRICTION,BLOCK_TYPE,TRACK,DURATION_TYPE,SUBJ_AREA_CREDIT,AVERAGE_TYPE,STATE_CRS_EQUIV,SAME_TEACHER,LOCK,COURSE_CREDIT_BASIS,NCES_CODE,CATEGORY_TYPE,CLASSIFY_STUS_MAX,CLASSIFY_NUM_OR_PER,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_MS_ALT_LANG",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,LANGUAGE",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,LANGUAGE,DESCRIPTION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_MS_BLDG_TYPE",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,BLDG_TYPE",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,BLDG_TYPE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_MS_BLOCK",
    "PKColumns": "DISTRICT,BLOCK_SECTION,COURSE",
    "TableColumns": "DISTRICT,BLOCK_SECTION,COURSE,BLOCKETTE_SECTION,MANDATORY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_MS_CYCLE",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,CYCLE_CODE",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,CYCLE_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_MS_GPA",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,GPA_TYPE",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,GPA_TYPE,GPA_LEVEL,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_MS_GRADE",
    "PKColumns": "DISTRICT,SECTION_KEY,RESTRICT_GRADE",
    "TableColumns": "DISTRICT,SECTION_KEY,RESTRICT_GRADE,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_MS_HONORS",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,HONOR_TYPE",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,HONOR_TYPE,HONOR_LEVEL,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_MS_HOUSE_TEAM",
    "PKColumns": "DISTRICT,SECTION_KEY,HOUSE_TEAM",
    "TableColumns": "DISTRICT,SECTION_KEY,HOUSE_TEAM,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_MS_HRM_AIN",
    "PKColumns": "DISTRICT,SECTION_KEY",
    "TableColumns": "DISTRICT,SECTION_KEY,HRM_SCHD_PRIMARY_HOMEROOM,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_MS_KEY",
    "PKColumns": "DISTRICT,SECTION_KEY",
    "TableColumns": "DISTRICT,SECTION_KEY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_MS_LUNCH",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,CYCLE_DAY,START_DATE",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,CYCLE_DAY,LUNCH_CODE,START_DATE,END_DATE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_MS_MARK_TYPES",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,MARK_TYPE",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,MARK_TYPE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_MS_MP",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,MARKING_PERIOD",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,MARKING_PERIOD,USED_SEATS,CLASSIFICATION_WEIGHT,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_MS_QUALIFY",
    "PKColumns": "DISTRICT,SECTION_KEY,QUALIFICATION",
    "TableColumns": "DISTRICT,SECTION_KEY,QUALIFICATION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_MS_SCHEDULE",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,COURSE,COURSE_SECTION,COURSE_SESSION",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,COURSE,COURSE_SECTION,SECTION_KEY,DESCRIPTION,STUDY_HALL,TRACK,COURSE_SESSION,SESSION_DESCRIPTION,START_PERIOD,END_PERIOD,TAKE_ATTENDANCE,RECEIVE_MARK,PRIMARY_STAFF_ID,ROOM_ID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_MS_SESSION",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,DESCRIPTION,START_PERIOD,END_PERIOD,TAKE_ATTENDANCE,RECEIVE_MARK,CREDIT,PRIMARY_STAFF_ID,ROOM_ID,COURSE_LEVEL,INCLD_PASSING_TIME,USE_FOCUS,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_MS_STAFF",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,STAFF_ID",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,STAFF_ID,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_MS_STAFF_DATE",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,STAFF_ID,START_DATE,SEQUENCE",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,STAFF_ID,START_DATE,SEQUENCE,END_DATE,PRIMARY_SECONDARY,COTEACHER,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_MS_STAFF_STUDENT",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,STAFF_ID,STUDENT_ID,START_DATE,SEQUENCE,STAFF_STUDENT_KEY",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,STAFF_ID,STUDENT_ID,START_DATE,SEQUENCE,STAFF_STUDENT_KEY,MINUTES,STUSTARTDATE,STUENDDATE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_MS_STAFF_STUDENT_pa",
    "PKColumns": "",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,STAFF_ID,START_DATE,STUDENT_ID,MINUTES,STUSTARTDATE,STUENDDATE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_MS_STAFF_USER",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,STAFF_ID,FIELD_NUMBER,START_DATE,SEQUENCE",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,STAFF_ID,FIELD_NUMBER,START_DATE,SEQUENCE,END_DATE,FIELD_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_MS_STU_FILTER",
    "PKColumns": "DISTRICT,PARAM_KEY,FILTER_NUMBER,STUDENT_ID",
    "TableColumns": "DISTRICT,PARAM_KEY,FILTER_NUMBER,STUDENT_ID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_MS_STUDY_SEAT",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,MARKING_PERIOD,CYCLE_CODE",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,MARKING_PERIOD,CYCLE_CODE,USED_SEATS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_MS_SUBJ",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,SUBJECT_AREA",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,SUBJECT_AREA,SUBJ_ORDER,SUB_AREA,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_MS_SUBJ_TAG",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,SUBJECT_AREA,TAG",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,SUBJECT_AREA,TAG,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_MS_USER",
    "PKColumns": "DISTRICT,SECTION_KEY,SCREEN_NUMBER,FIELD_NUMBER,LIST_SEQUENCE",
    "TableColumns": "DISTRICT,SECTION_KEY,SCREEN_NUMBER,FIELD_NUMBER,LIST_SEQUENCE,FIELD_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_MSB_MEET_CYC",
    "PKColumns": "DISTRICT,MEETING_KEY,SEQUENCE_NUM,CYCLE_CODE",
    "TableColumns": "DISTRICT,MEETING_KEY,SEQUENCE_NUM,CYCLE_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_MSB_MEET_DET",
    "PKColumns": "DISTRICT,MEETING_KEY,SEQUENCE_NUM",
    "TableColumns": "DISTRICT,MEETING_KEY,SEQUENCE_NUM,JOIN_CONDITION,CYCLES_SELECTED,PERIODS_SELECTED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_MSB_MEET_HDR",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,MEETING_CODE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,MEETING_CODE,MEETING_KEY,DESCRIPTION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_MSB_MEET_PER",
    "PKColumns": "DISTRICT,MEETING_KEY,SEQUENCE_NUM,PERIOD",
    "TableColumns": "DISTRICT,MEETING_KEY,SEQUENCE_NUM,PERIOD,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_PARAMS",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,OVERRIDE_SEATS,OVERRIDE_HOUSETEAM,IGNORED_PRIORITIES,STUDENT_ALT,COURSE_ALT,STUDENT_COURSE_ALT,SCHD_INTERVAL,PRESERVE_SCHEDULE,BALANCE_CRITERIA,MAXIMUM_TRIES,USE_BALANCING,MAXIMUM_IMBALANCE,MAXIMUM_RESHUFFLE,MAXIMUM_RESCHEDULE,SECONDS_TIMEOUT,MATCH_PERIODS_ONLY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_PARAMS_SORT",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,SORT_ORDER",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,SORT_ORDER,ORDER_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_PERIOD",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,CODE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,CODE,DESCRIPTION,PERIOD_ORDER,STANDARD_PERIOD,STATE_CODE_EQUIV,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_PREREQ_COURSE_ERR",
    "PKColumns": "DISTRICT,STUDENT_ID,BUILDING,COURSE,ERROR_CODE",
    "TableColumns": "DISTRICT,STUDENT_ID,BUILDING,COURSE,ERROR_CODE,PREREQ_BUILDING,PREREQ_COURSE,PREREQ_COURSE_OR_GROUP,PREREQ_MARK_TYPE,PREREQ_MIN_MARK,PREREQ_ACTUAL_MARK,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_REC_TAKEN",
    "PKColumns": "DISTRICT,SECTION_KEY,LOGIN_ID",
    "TableColumns": "DISTRICT,SECTION_KEY,LOGIN_ID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_RESOURCE",
    "PKColumns": "DISTRICT,BUILDING,GROUP_TYPE,GROUP_CODE",
    "TableColumns": "DISTRICT,BUILDING,GROUP_TYPE,GROUP_CODE,GROUP_DESCRIPTION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_RESTRICTION",
    "PKColumns": "DISTRICT,BUILDING,GROUP_TYPE,RESOURCE_ID,PERIOD,MARKING_PERIOD,CYCLE",
    "TableColumns": "DISTRICT,BUILDING,GROUP_TYPE,RESOURCE_ID,PERIOD,MARKING_PERIOD,CYCLE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_RUN",
    "PKColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,RUN_KEY",
    "TableColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,RUN_KEY,RUN_LABEL,RUN_STATUS,RUN_DATE_TIME,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_RUN_TABLE",
    "PKColumns": "DISTRICT,TABLE_NAME",
    "TableColumns": "DISTRICT,TABLE_NAME,DELETE_VIA_TRIGGER,HAS_BUILDING,HAS_SCHOOL_YEAR,CROSS_TABLE,KEY_COLUMN",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "SCHD_SCAN_REQUEST",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,COURSE,GRADE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,SCAN_GUID,COURSE,GRADE,SEQUENCE_NUMBER,PAGE_NUMBER,LINE_NUMBER,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_STU_CONF_CYC",
    "PKColumns": "DISTRICT,STUDENT_ID,SECTION_KEY,MODELED,DATE_RANGE_KEY,COURSE_SESSION,CYCLE_CODE",
    "TableColumns": "DISTRICT,STUDENT_ID,SECTION_KEY,MODELED,DATE_RANGE_KEY,COURSE_SESSION,CYCLE_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_STU_CONF_MP",
    "PKColumns": "DISTRICT,STUDENT_ID,SECTION_KEY,MODELED,DATE_RANGE_KEY,COURSE_SESSION,MARKING_PERIOD",
    "TableColumns": "DISTRICT,STUDENT_ID,SECTION_KEY,MODELED,DATE_RANGE_KEY,COURSE_SESSION,MARKING_PERIOD,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_STU_COURSE",
    "PKColumns": "DISTRICT,STUDENT_ID,SECTION_KEY,MODELED",
    "TableColumns": "DISTRICT,STUDENT_ID,SECTION_KEY,MODELED,COURSE_STATUS,MODEL_VAL_TYPE,RETAKE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_STU_CRS_DATES",
    "PKColumns": "DISTRICT,STUDENT_ID,SECTION_KEY,MODELED,DATE_RANGE_KEY",
    "TableColumns": "DISTRICT,STUDENT_ID,SECTION_KEY,MODELED,DATE_RANGE_KEY,DATE_ADDED,DATE_DROPPED,RESOLVED_CONFLICT,MR_UNGRADED,MR_FIRST_MP,MR_LAST_MP,MR_LAST_MARK_BY,FROM_SECTION_KEY,FROM_RANGE_KEY,TO_SECTION_KEY,TO_RANGE_KEY,ROW_IDENTITY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_STU_PREREQOVER",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,STUDENT_ID,COURSE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,STUDENT_ID,COURSE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_STU_RECOMMEND",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,STUDENT_ID,COURSE,STAFF_ID,SECTION_KEY",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,STUDENT_ID,COURSE,STAFF_ID,SECTION_KEY,PRIORITY,ENROLL_COURSE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_STU_REQ",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,STUDENT_ID,SCHD_INTERVAL,COURSE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,STUDENT_ID,SCHD_INTERVAL,COURSE,COURSE_SECTION,TEACHER_OVERLOAD,REQUEST_TYPE,IS_LOCKED,ALT_TO_REQUEST,ALTERNATE_SEQUENCE,RETAKE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_STU_REQ_MP",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,STUDENT_ID,SCHD_INTERVAL,COURSE,MARKING_PERIOD",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,STUDENT_ID,SCHD_INTERVAL,COURSE,MARKING_PERIOD,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_STU_STAFF_USER",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,STAFF_ID,STUDENT_ID,START_DATE,STAFF_STUDENT_KEY,FIELD_NUMBER",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,STAFF_ID,STUDENT_ID,START_DATE,SEQUENCE,STAFF_STUDENT_KEY,FIELD_NUMBER,LIST_SEQUENCE,FIELD_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_STU_STATUS",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,STUDENT_ID,SCHD_INTERVAL",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,STUDENT_ID,SCHD_INTERVAL,SCHEDULE_STATUS,REQUEST_STATUS,NUMBER_SINGLETONS,NUMBER_DOUBLETONS,NUMBER_MULTISESS,NUMBER_BLOCKS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_STU_USER",
    "PKColumns": "DISTRICT,SECTION_KEY,DATE_RANGE_KEY,STUDENT_ID,SCREEN_NUMBER,FIELD_NUMBER",
    "TableColumns": "DISTRICT,SECTION_KEY,DATE_RANGE_KEY,STUDENT_ID,SCREEN_NUMBER,FIELD_NUMBER,FIELD_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_TIMETABLE",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,BELL_SCHD,TIMESLOT,CYCLE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,BELL_SCHD,TIMESLOT,CYCLE,START_TIME,END_TIME,PERIOD,PARENT_CYCLE_DAY,LUNCH_TIME,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_TIMETABLE_HDR",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,BELL_SCHD,HOUSE_TEAM",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,BELL_SCHD,HOUSE_TEAM,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_TMP_STU_REQ_LIST",
    "PKColumns": "DISTRICT,LOGIN_ID,COURSE",
    "TableColumns": "DISTRICT,LOGIN_ID,COURSE,ISOTHERCOURSE,PAGE_NO,ROW_NO,REQUEST_TYPE,SCHD_INTERVAL,IS_LOCKED,COURSE_DESC,ALT_TO_REQUEST,ALTERNATE_SEQUENCE,PREREQUISITE_OVERRIDE,RETAKE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_UNSCANNED",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,SCAN_GUID,STUDENT_ID,PAGE_NUMBER",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,SCAN_GUID,STUDENT_ID,GRADE,POSTED,PAGE_NUMBER,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHD_YREND_RUN",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,RUN_KEY",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,RUN_KEY,RUN_DATE,RUN_STATUS,CLEANSCHDDATA,BUILDING_LIST,PURGE_CC,PURGE_BI_YEAR,PURGE_MS_YEAR,PURGE_SS_YEAR,PURGE_SR_YEAR,RESTORE_KEY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHDTB_AR_ALETYPE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHDTB_AR_DIG_LRN",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHDTB_AR_DIST_PRO",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHDTB_AR_HQT",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHDTB_AR_INST",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHDTB_AR_JOBCODE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHDTB_AR_LEARN",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHDTB_AR_LIC_EX",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHDTB_AR_TRANSVEN",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHDTB_AR_VOCLEA",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHDTB_COURSE_NCES_CODE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHDTB_CREDIT_BASIS",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,PESC_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHDTB_CREDIT_BASIS_PESC_CODE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHDTB_SIF_CREDIT_TYPE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHDTB_SIF_INSTRUCTIONAL_LEVEL",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,STATE_CODE_EQUIV,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHDTB_STU_COURSE_TRIGGER",
    "PKColumns": "DISTRICT,MS_SCREEN_NUMBER,MS_FIELD_NUMBER,SC_SCREEN_NUMBER,SC_FIELD_NUMBER",
    "TableColumns": "DISTRICT,STATE_ABR,MS_SCREEN_NUMBER,MS_FIELD_NUMBER,SC_SCREEN_NUMBER,SC_FIELD_NUMBER,FIELD_LABEL,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHOOLOGY_ASMT_XREF",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,ESP_ASMT_NUMBER",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,ESP_ASMT_NUMBER,SCHOOLOGY_ASMT_ID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SCHOOLOGY_INTF_DET",
    "PKColumns": "DISTRICT,JOB_GUID,PAGE_NUM",
    "TableColumns": "DISTRICT,JOB_GUID,PAGE_NUM,RETURN_STRING",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "SCHOOLOGY_INTF_HDR",
    "PKColumns": "DISTRICT,JOB_GUID",
    "TableColumns": "DISTRICT,JOB_GUID,CALL_TYPE,CALL_DATE_TIME,PER_PAGE,PAGE_TOTAL",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "SDE_CAMPUS",
    "PKColumns": "INSTITUTE_ID,CAMPUS_ID",
    "TableColumns": "INSTITUTE_ID,CAMPUS_ID,NAME,CITY,CAMPUS_STATE,COUNTRY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SDE_CERT",
    "PKColumns": "DISTRICT",
    "TableColumns": "DISTRICT,SERIAL_NUMBER",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "SDE_DIST_CFG",
    "PKColumns": "DISTRICT,INSTITUTION_ID",
    "TableColumns": "DISTRICT,INSTITUTION_ID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SDE_INSTITUTION",
    "PKColumns": "INSTITUTION_ID",
    "TableColumns": "INSTITUTION_ID,NAME,CITY,INSTITUTE_STATE,COUNTRY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SDE_IPP_TRANSACTIONS_DATA",
    "PKColumns": "PROCESS_ID",
    "TableColumns": "PROCESS_ID,CURRENT_STATUS,INITIATED_DATE,INITIATED_BY,IDENTITY_VERIFIED_DATE,DATA_AVAILABLE_DATE,COMPLETED_DATE,RECEIVING_INSTITUTION_ID,RECEIVING_CAMPUS_ID,SENDING_INSTITUTION_ID,SENDING_CAMPUS_ID,STUDENT_FIRST_NAME,STUDENT_MIDDLE_NAME,STUDENT_LAST_NAME,STUDENT_BIRTHDATE,STUDENT_GENDER,OLD_LOCAL_STUDENT_ID,OLD_STATE_STUDENT_ID,NEW_LOCAL_STUDENT_ID,NEW_STATE_STUDENT_ID,RECEIVER_NOTES,SENDER_NOTES,CHANGE_UID,CHANGE_DATE_TIME",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SDE_PESC_IMPORT",
    "PKColumns": "DISTRICT,PROCESS_ID",
    "TableColumns": "DISTRICT,PROCESS_ID,INSTITUTE_ID,STUDENT_ID,ORIGINAL_PESC_XML,INTERMEDIATE_ACADEMIC_CHANGES,INTERMEDIATE_HEALTH_CHANGES,INTERMEDIATE_TEST_CHANGES,IMPORTED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SDE_PESC_TRANSCRIPT",
    "PKColumns": "PROCESS_ID",
    "TableColumns": "PROCESS_ID,USER_ID,FILENAME,COMPLETED,PESC_STATUS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SDE_SECURITY",
    "PKColumns": "DISTRICT,USER_ID,CAMPUSES",
    "TableColumns": "DISTRICT,USER_ID,FIRST_NAME,LAST_NAME,EMAIL,CALL_MODE,CAMPUSES,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SDE_SESSION_TRACKER",
    "PKColumns": "SessionID",
    "TableColumns": "SessionID,UserId,InstitutionID,DistrictID,eSPDBConnect,TaskServer,SchoolYear,SummerSchool,AppHosting,DSN,ApplicationVersion,ApplicationType,DebugMode,SiteCode,BuildingID",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "SDE_TRANSACTION_TIME",
    "PKColumns": "INSTITUTION_ID",
    "TableColumns": "INSTITUTION_ID,LAST_FETCH_TIME_TRANSACTION_LOG,LAST_FETCH_TIME_NOTIFICATION",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "SDE_TRANSCRIPT",
    "PKColumns": "PROCESS_ID",
    "TableColumns": "PROCESS_ID,PARAM_KEY,USER_ID,FILENAME,COMPLETED,STATUS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SDE_TRANSCRIPT_CONFIGURATION",
    "PKColumns": "DISTRICT,BUILDING,PARAM_IDX,APPLICABLE_TO",
    "TableColumns": "DISTRICT,BUILDING,PARAM_IDX,PARAM_NAME,PARAM_VALUE,APPLICABLE_TO,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SEC_GLOBAL_ID",
    "PKColumns": "DISTRICT,LOGIN_ID,LOGIN_TYPE",
    "TableColumns": "DISTRICT,LOGIN_ID,LOGIN_TYPE,CHANGE_DATE_TIME,CHANGE_UID,GLOBAL_ID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SEC_LOOKUP_INFO",
    "PKColumns": "DISTRICT,MENU_ITEM,LOOKUP_ID,SEC_TYPE,PACKAGE,SUBPACKAGE,FEATURE",
    "TableColumns": "DISTRICT,MENU_ITEM,LOOKUP_ID,SEC_TYPE,PACKAGE,SUBPACKAGE,FEATURE,READ_WRITE_REQD,FUNCTIONALITY_DESC,SUBPACKAGE_YEAR_SPEC,RESERVED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SEC_LOOKUP_MENU_ITEMS",
    "PKColumns": "DISTRICT,PARENT_MENU,SEQUENCE",
    "TableColumns": "DISTRICT,PARENT_MENU,SEQUENCE,LOOKUP_ID,SEARCH_TYPE,SORT_TYPE,RESERVED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SEC_LOOKUP_MENU_REL",
    "PKColumns": "DISTRICT,SOURCE_MENU_ITEM,SOURCE_LOOKUP_ID,DEST_MENU_ITEM,DEST_LOOKUP_ID",
    "TableColumns": "DISTRICT,SOURCE_MENU_ITEM,SOURCE_LOOKUP_ID,DEST_MENU_ITEM,DEST_LOOKUP_ID,RESERVED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SEC_LOOKUP_NON_MENU",
    "PKColumns": "DISTRICT,LOOKUP_ID",
    "TableColumns": "DISTRICT,LOOKUP_ID,PAGE_TITLE,PAGE_NAME,SEARCH_TYPE,SORT_TYPE,RESERVED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SEC_USER",
    "PKColumns": "DISTRICT,LOGIN_ID",
    "TableColumns": "DISTRICT,LOGIN_ID,USER_OR_ROLE,LOGIN_NAME,BUILDING,DEPARTMENT,EMAIL,SCHOOL_YEAR,SUMMER_SCHOOL,USE_MENU_CACHE,MAY_IMPERSONATE,HAS_READ_NEWS,INITIALS,LOCAL_LOGIN_ID,TEACHER_ACCOUNT,CHANGE_DATE_TIME,CHANGE_UID,CLASSLINK_ID,USER_UNIQUE_ID,ROW_IDENTITY",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SEC_USER_AD",
    "PKColumns": "DISTRICT,LOGIN_ID",
    "TableColumns": "DISTRICT,LOGIN_ID,USER_OR_ROLE,DEACTIVATE,AD_GROUP,REV_REQ_FOR_ADD,REV_REQ_FOR_DEL,REV_EMAIL_ADDRESS,NOT_REQ_FOR_ADD,NOT_REQ_FOR_DEL,NOT_EMAIL_ADDRESS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SEC_USER_BUILDING",
    "PKColumns": "DISTRICT,LOGIN_ID,BUILDING",
    "TableColumns": "DISTRICT,LOGIN_ID,BUILDING,CHANGE_DATE_TIME,CHANGE_UID,ROW_IDENTITY",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SEC_USER_MENU_CACHE",
    "PKColumns": "DISTRICT,LOGIN_ID",
    "TableColumns": "DISTRICT,LOGIN_ID,MENU,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SEC_USER_RESOURCE",
    "PKColumns": "DISTRICT,LOGIN_ID,ROLE_ID,PACKAGE,SUBPACKAGE,FEATURE,BUILDING",
    "TableColumns": "DISTRICT,LOGIN_ID,ROLE_ID,PACKAGE,SUBPACKAGE,FEATURE,BUILDING,ACCESS_TYPE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SEC_USER_ROLE",
    "PKColumns": "DISTRICT,LOGIN_ID,ROLE_ID",
    "TableColumns": "DISTRICT,LOGIN_ID,ROLE_ID,DEF_BUILDING_OVR,CHANGE_DATE_TIME,CHANGE_UID,ROW_IDENTITY",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SEC_USER_ROLE_BLDG_OVR",
    "PKColumns": "DISTRICT,LOGIN_ID,ROLE_ID,BUILDING",
    "TableColumns": "DISTRICT,LOGIN_ID,ROLE_ID,BUILDING,CHANGE_DATE_TIME,CHANGE_UID,ROW_IDENTITY",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SEC_USER_STAFF",
    "PKColumns": "DISTRICT,LOGIN_ID,STAFF_ID",
    "TableColumns": "DISTRICT,LOGIN_ID,STAFF_ID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SECTB_ACTION_FEATURE",
    "PKColumns": "DISTRICT,AREA,CONTROLLER,ACTION,FEATURE_ID",
    "TableColumns": "DISTRICT,AREA,CONTROLLER,ACTION,FEATURE_ID,PACKAGE,SUBPACKAGE,FEATURE,DESCRIPTION,BUILDING_ACCESS_LEVEL,RESERVED,CHANGE_DATE_TIME,CHANGE_UID,TAC_ACCESS",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SECTB_ACTION_RESOURCE",
    "PKColumns": "DISTRICT,AREA,CONTROLLER,ACTION",
    "TableColumns": "DISTRICT,AREA,CONTROLLER,ACTION,PACKAGE,SUBPACKAGE,FEATURE,ENV_SUBPACKAGE,DESCRIPTION,BUILDING_ACCESS_LEVEL,RESERVED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SECTB_PACKAGE",
    "PKColumns": "DISTRICT,PACKAGE",
    "TableColumns": "DISTRICT,PACKAGE,DESCRIPTION,IS_ADVANCED_FEATURE,RESERVED,LICENSE_KEY,IS_VALID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SECTB_PAGE_RESOURCE",
    "PKColumns": "DISTRICT,MENU_ID,MENU_TYPE",
    "TableColumns": "DISTRICT,MENU_ID,MENU_TYPE,PACKAGE,SUBPACKAGE,FEATURE,ENV_SUBPACKAGE,DESCRIPTION,BUILDING_ACCESS_LEVEL,RESERVED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SECTB_RESOURCE",
    "PKColumns": "DISTRICT,PACKAGE,SUBPACKAGE,FEATURE",
    "TableColumns": "DISTRICT,PACKAGE,SUBPACKAGE,FEATURE,DESCRIPTION,RESERVED,BLDG_LIST_REQUIRED,ADVANCED_FEATURE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SECTB_SUBPACKAGE",
    "PKColumns": "DISTRICT,SUBPACKAGE",
    "TableColumns": "DISTRICT,SUBPACKAGE,DESCRIPTION,RESERVED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SIF_AGENT_CFG",
    "PKColumns": "DISTRICT,AGENT_ID",
    "TableColumns": "DISTRICT,AGENT_ID,AGENT_NAME,SUMMER_SCHOOL,IS_REGISTERED,IS_RUNNING,MAX_BUFFER,SIF_VERSION,SIF_MODE,POLL_INTERVAL,SIF_PROTOCOL,AGENT_URL,ZIS_URL,ZIS_RETRIES,ZIS_ID,AGENT_WAKE_TIME,AGENT_SLEEP_TIME,PROXY_SERVER,MAX_LOG_DAYS,LOG_LEVEL,LAST_LOG_PURGE,CFG_DB_NAME,PUSH_TO_URL,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SIF_EVENT_DET",
    "PKColumns": "TRANSACTION_ID,COLUMN_NAME",
    "TableColumns": "TRANSACTION_ID,COLUMN_NAME,NEW_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SIF_EVENT_HDR",
    "PKColumns": "DISTRICT,TRANSACTION_ID,SIF_EVENT",
    "TableColumns": "DISTRICT,TRANSACTION_ID,SIF_EVENT,ACTION_TYPE,SUMMER_SCHOOL,SIF_MESSAGE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SIF_EXTENDED_MAP",
    "PKColumns": "DISTRICT,AGENT_ID,SIF_EVENT,ELEMENT_NAME",
    "TableColumns": "DISTRICT,AGENT_ID,SIF_EVENT,ELEMENT_NAME,TABLE_NAME,COLUMN_NAME,FORMAT_TYPE,DATA_TYPE,DATA_LENGTH,DEFAULT_VALUE,VALIDATION_LIST,VALIDATION_TABLE,CODE_COLUMN,SIF_CODE_COLUMN,PUBLISH,PROVIDE,SUBSCRIBE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SIF_GUID_ATT_CLASS",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,STUDENT_ID,ATTENDANCE_DATE,ATTENDANCE_PERIOD,SEQUENCE_NUM",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,STUDENT_ID,ATTENDANCE_DATE,ATTENDANCE_PERIOD,SEQUENCE_NUM,SIF_REFID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SIF_GUID_ATT_CODE",
    "PKColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,SUMMER_SCHOOL,ATTENDANCE_CODE",
    "TableColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,SUMMER_SCHOOL,ATTENDANCE_CODE,SIF_REFID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SIF_GUID_ATT_DAILY",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,STUDENT_ID,ATTENDANCE_DATE,ATTENDANCE_PERIOD,SEQUENCE_NUM",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,STUDENT_ID,ATTENDANCE_DATE,ATTENDANCE_PERIOD,SEQUENCE_NUM,SIF_REFID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SIF_GUID_AUTH",
    "PKColumns": "DISTRICT,PERSON_ID,SIF_REFID_TYPE,SYSTEM_TYPE,SYSTEM_VALUE",
    "TableColumns": "DISTRICT,PERSON_ID,SIF_REFID_TYPE,SYSTEM_TYPE,SYSTEM_VALUE,SIF_REFID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SIF_GUID_BUILDING",
    "PKColumns": "DISTRICT,BUILDING",
    "TableColumns": "DISTRICT,BUILDING,SIF_REFID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SIF_GUID_BUS_DETAIL",
    "PKColumns": "SIF_REFID",
    "TableColumns": "DISTRICT,BUSROUTEINFOREFID,BUSSTOPINFOREFID,STOP_TIME,SIF_REFID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SIF_GUID_BUS_INFO",
    "PKColumns": "SIF_REFID",
    "TableColumns": "DISTRICT,BUS_NUMBER,SIF_REFID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SIF_GUID_BUS_ROUTE",
    "PKColumns": "SIF_REFID",
    "TableColumns": "DISTRICT,BUSINFOREFID,BUS_ROUTE,TRAVEL_DIRECTION,SIF_REFID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SIF_GUID_BUS_STOP",
    "PKColumns": "SIF_REFID",
    "TableColumns": "DISTRICT,STOP_DESCRIPTION,SIF_REFID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SIF_GUID_BUS_STU",
    "PKColumns": "DISTRICT,STUDENT_ID,TRAVEL_DIRECTION,TRAVEL_TRIP,TRAVEL_SEGMENT",
    "TableColumns": "DISTRICT,STUDENT_ID,TRAVEL_DIRECTION,TRAVEL_TRIP,TRAVEL_SEGMENT,SIF_REFID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SIF_GUID_CALENDAR_SUMMARY",
    "PKColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,SUMMER_SCHOOL,TRACK,CALENDAR",
    "TableColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,SUMMER_SCHOOL,TRACK,CALENDAR,SIF_REFID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SIF_GUID_CONTACT",
    "PKColumns": "DISTRICT,CONTACT_ID,STUDENT_ID,CONTACT_TYPE",
    "TableColumns": "DISTRICT,CONTACT_ID,STUDENT_ID,CONTACT_TYPE,SIF_REFID,SIF_CONTACT_ID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SIF_GUID_COURSE",
    "PKColumns": "DISTRICT,BUILDING,COURSE",
    "TableColumns": "DISTRICT,BUILDING,COURSE,SIF_REFID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SIF_GUID_CRS_SESS",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,SIF_REFID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SIF_GUID_DISTRICT",
    "PKColumns": "DISTRICT",
    "TableColumns": "DISTRICT,SIF_REFID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SIF_GUID_GB_ASMT",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,ASMT_NUMBER",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,ASMT_NUMBER,SIF_REFID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SIF_GUID_HOSPITAL",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,SIF_REFID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SIF_GUID_IEP",
    "PKColumns": "DISTRICT,STUDENT_ID",
    "TableColumns": "DISTRICT,STUDENT_ID,SIF_REFID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SIF_GUID_MED_ALERT",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,SIF_REFID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SIF_GUID_PROGRAM",
    "PKColumns": "DISTRICT,STUDENT_ID,PROGRAM_ID,FIELD_NUMBER,START_DATE",
    "TableColumns": "DISTRICT,STUDENT_ID,PROGRAM_ID,FIELD_NUMBER,START_DATE,SIF_REFID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SIF_GUID_REG_EW",
    "PKColumns": "DISTRICT,STUDENT_ID,ENTRY_WD_TYPE,SCHOOL_YEAR,ENTRY_DATE",
    "TableColumns": "DISTRICT,STUDENT_ID,ENTRY_WD_TYPE,SCHOOL_YEAR,ENTRY_DATE,SIF_REFID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SIF_GUID_ROOM",
    "PKColumns": "DISTRICT,BUILDING,ROOM_ID",
    "TableColumns": "DISTRICT,BUILDING,ROOM_ID,SIF_REFID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SIF_GUID_STAFF",
    "PKColumns": "DISTRICT,STAFF_ID",
    "TableColumns": "DISTRICT,STAFF_ID,SIF_REFID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SIF_GUID_STAFF_BLD",
    "PKColumns": "DISTRICT,BUILDING,STAFF_ID",
    "TableColumns": "DISTRICT,BUILDING,STAFF_ID,SIF_REFID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SIF_GUID_STU_SESS",
    "PKColumns": "DISTRICT,STUDENT_ID,SECTION_KEY,COURSE_SESSION,DATE_RANGE_KEY",
    "TableColumns": "DISTRICT,STUDENT_ID,SECTION_KEY,COURSE_SESSION,DATE_RANGE_KEY,SIF_REFID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SIF_GUID_STUDENT",
    "PKColumns": "DISTRICT,STUDENT_ID",
    "TableColumns": "DISTRICT,STUDENT_ID,SIF_REFID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SIF_GUID_TERM",
    "PKColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,TRACK,MARKING_PERIOD",
    "TableColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,TRACK,MARKING_PERIOD,SIF_REFID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SIF_LOGFILE",
    "PKColumns": "LOG_ID",
    "TableColumns": "LOG_ID,DISTRICT,AGENT_ID,MESSAGE_REFID,SOURCE_ID,OBJECT_NAME,MESSAGE_TYPE,MESSAGE_XML,WEBSERVICE_XML,ERROR_MESSAGE,LOG_DATETIME",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "SIF_PROGRAM_COLUMN",
    "PKColumns": "DISTRICT,AGENT_ID,PROGRAM_ID,FIELD_NUMBER",
    "TableColumns": "DISTRICT,AGENT_ID,PROGRAM_ID,FIELD_NUMBER,PROVIDE,PUBLISH,SUBSCRIBE,SERVICE_CODE_TYPE,ELEMENT_NAME,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SIF_PROVIDE",
    "PKColumns": "DISTRICT,AGENT_ID,SIF_EVENT",
    "TableColumns": "DISTRICT,AGENT_ID,SIF_EVENT,MESSAGE_ID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SIF_PUBLISH",
    "PKColumns": "DISTRICT,AGENT_ID,SIF_EVENT",
    "TableColumns": "DISTRICT,AGENT_ID,SIF_EVENT,MESSAGE_ID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SIF_REQUEST_QUEUE",
    "PKColumns": "MESSAGE_ID",
    "TableColumns": "MESSAGE_ID,DISTRICT,AGENT_ID,SIF_EVENT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SIF_RESPOND",
    "PKColumns": "DISTRICT,AGENT_ID,SIF_EVENT",
    "TableColumns": "DISTRICT,AGENT_ID,SIF_EVENT,MESSAGE_ID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SIF_SUBSCRIBE",
    "PKColumns": "DISTRICT,AGENT_ID,SIF_EVENT",
    "TableColumns": "DISTRICT,AGENT_ID,SIF_EVENT,MESSAGE_ID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SIF_USER_FIELD",
    "PKColumns": "DISTRICT,AGENT_ID,SIF_EVENT,ELEMENT_NAME",
    "TableColumns": "DISTRICT,AGENT_ID,SIF_EVENT,ELEMENT_NAME,SCREEN_TYPE,SCREEN_NUMBER,FIELD_NUMBER,FORMAT_TYPE,VALIDATION_TABLE,CODE_COLUMN,SIF_CODE_COLUMN,YES_VALUES_LIST,PUBLISH,PROVIDE,SUBSCRIBE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SMS_CFG",
    "PKColumns": "REPORT_CLEANUP",
    "TableColumns": "REPORT_CLEANUP,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SMS_PROGRAM_RULES",
    "PKColumns": "DISTRICT,PROGRAM_ID,FIELD_NUMBER,GROUP_NUMBER,RULE_NUMBER",
    "TableColumns": "DISTRICT,PROGRAM_ID,FIELD_NUMBER,FIELD_ATTRIBUTE,GROUP_NUMBER,RULE_NUMBER,RULE_OPERATOR,RULE_VALUE,RULE_TABLE,RULE_COLUMN,RULE_IDENTIFIER,RULE_FIELD_NUMBER,RULE_FIELD_ATTRIBUTE,WHERE_TABLE,WHERE_COLUMN,WHERE_IDENTIFIER,WHERE_FIELD_NUMBER,WHERE_FIELD_ATTRIBUTE,WHERE_OPERATOR,WHERE_VALUE,AND_OR_FLAG,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SMS_PROGRAM_RULES_MESSAGES",
    "PKColumns": "DISTRICT,PROGRAM_ID,FIELD_NUMBER,GROUP_NUMBER",
    "TableColumns": "DISTRICT,PROGRAM_ID,FIELD_NUMBER,GROUP_NUMBER,ERROR_MESSAGE,SHOW_CUSTOM_MESSAGE,SHOW_BOTH,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SMS_USER_FIELDS",
    "PKColumns": "DISTRICT,SCREEN_TYPE,SCREEN_NUMBER,FIELD_NUMBER",
    "TableColumns": "DISTRICT,SCREEN_TYPE,SCREEN_NUMBER,FIELD_NUMBER,FIELD_LABEL,STATE_CODE_EQUIV,FIELD_ORDER,REQUIRED_FIELD,FIELD_TYPE,DATA_TYPE,NUMBER_TYPE,DATA_LENGTH,FIELD_SCALE,FIELD_PRECISION,DEFAULT_VALUE,DEFAULT_TABLE,DEFAULT_COLUMN,VALIDATION_LIST,VALIDATION_TABLE,CODE_COLUMN,DESCRIPTION_COLUMN,SPI_TABLE,SPI_COLUMN,SPI_SCREEN_NUMBER,SPI_FIELD_NUMBER,SPI_FIELD_TYPE,INCLUDE_PERFPLUS,SEC_PACKAGE,SEC_SUBPACKAGE,SEC_FEATURE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SMS_USER_RULES",
    "PKColumns": "DISTRICT,SCREEN_TYPE,SCREEN_NUMBER,FIELD_NUMBER,GROUP_NUMBER,RULE_NUMBER",
    "TableColumns": "DISTRICT,SCREEN_TYPE,SCREEN_NUMBER,FIELD_NUMBER,GROUP_NUMBER,RULE_NUMBER,RULE_OPERATOR,RULE_VALUE,RULE_TABLE,RULE_COLUMN,RULE_SCREEN_NUMBER,RULE_FIELD_NUMBER,WHERE_TABLE,WHERE_COLUMN,WHERE_SCREEN_NUM,WHERE_FIELD_NUMBER,WHERE_OPERATOR,WHERE_VALUE,AND_OR_FLAG,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SMS_USER_RULES_MESSAGES",
    "PKColumns": "DISTRICT,SCREEN_TYPE,SCREEN_NUMBER,FIELD_NUMBER,GROUP_NUMBER",
    "TableColumns": "DISTRICT,SCREEN_TYPE,SCREEN_NUMBER,FIELD_NUMBER,GROUP_NUMBER,ERROR_MESSAGE,SHOW_CUSTOM_MESSAGE,SHOW_BOTH,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SMS_USER_SCREEN",
    "PKColumns": "DISTRICT,SCREEN_TYPE,SCREEN_NUMBER",
    "TableColumns": "DISTRICT,SCREEN_TYPE,SCREEN_NUMBER,LIST_TYPE,COLUMNS,DESCRIPTION,REQUIRED_SCREEN,SEC_PACKAGE,SEC_SUBPACKAGE,SEC_FEATURE,RESERVED,STATE_FLAG,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SMS_USER_SCREEN_COMB_DET",
    "PKColumns": "DISTRICT,COMBINED_SCREEN_TYPE,COMBINED_SCREEN_NUMBER,SCREEN_TYPE,SCREEN_NUMBER",
    "TableColumns": "DISTRICT,COMBINED_SCREEN_TYPE,COMBINED_SCREEN_NUMBER,SCREEN_TYPE,SCREEN_NUMBER,SCREEN_ORDER,HIDE_ON_MENU,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SMS_USER_SCREEN_COMB_HDR",
    "PKColumns": "DISTRICT,COMBINED_SCREEN_TYPE,COMBINED_SCREEN_NUMBER",
    "TableColumns": "DISTRICT,COMBINED_SCREEN_TYPE,COMBINED_SCREEN_NUMBER,DESCRIPTION,SEC_PACKAGE,SEC_SUBPACKAGE,SEC_FEATURE,RESERVED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SMS_USER_TABLE",
    "PKColumns": "DISTRICT,TABLE_NAME,PACKAGE",
    "TableColumns": "DISTRICT,TABLE_NAME,PACKAGE,TABLE_DESCR,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_API_VAL_COLUMN",
    "PKColumns": "DISTRICT,TABLE_NAME,COLUMN_NAME",
    "TableColumns": "DISTRICT,TABLE_NAME,COLUMN_NAME,COLUMN_ORDER,JSON_PROPERTY_NAME,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_API_VAL_SCOPE",
    "PKColumns": "DISTRICT,TABLE_NAME,SCOPE",
    "TableColumns": "DISTRICT,TABLE_NAME,SCOPE,SQL_WHERE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_API_VAL_TABLE",
    "PKColumns": "DISTRICT,TABLE_NAME",
    "TableColumns": "DISTRICT,TABLE_NAME,JSON_PROPERTY_NAME,SQL_WHERE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_APPUSERDEF",
    "PKColumns": "",
    "TableColumns": "PARENT_MENU,PAGE,SCREEN_TYPE",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "SPI_AUDIT_DET1",
    "PKColumns": "KEY_GUID,REC_INDEX",
    "TableColumns": "KEY_GUID,REC_INDEX,DISTRICT,TABLE_NAME,USER_ID,TWS_USER_ID,MOD_DATE,UPDATE_MODE,DATA_FIELD_01,DATA_VALUE_01,DATA_FIELD_02,DATA_VALUE_02,DATA_FIELD_03,DATA_VALUE_03,DATA_FIELD_04,DATA_VALUE_04,DATA_FIELD_05,DATA_VALUE_05,DATA_FIELD_06,DATA_VALUE_06,DATA_FIELD_07,DATA_VALUE_07,DATA_FIELD_08,DATA_VALUE_08,DATA_FIELD_09,DATA_VALUE_09,DATA_FIELD_10,DATA_VALUE_10,DATA_FIELD_11,DATA_VALUE_11,DATA_FIELD_12,DATA_VALUE_12,DATA_FIELD_13,DATA_VALUE_13,DATA_FIELD_14,DATA_VALUE_14,DATA_FIELD_15,DATA_VALUE_15,DATA_FIELD_16,DATA_VALUE_16,DATA_FIELD_17,DATA_VALUE_17,DATA_FIELD_18,DATA_VALUE_18,DATA_FIELD_19,DATA_VALUE_19,DATA_FIELD_20,DATA_VALUE_20,DATA_FIELD_21,DATA_VALUE_21,DATA_FIELD_22,DATA_VALUE_22,DATA_FIELD_23,DATA_VALUE_23,DATA_FIELD_24,DATA_VALUE_24,DATA_FIELD_25,DATA_VALUE_25",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "SPI_AUDIT_DET2",
    "PKColumns": "KEY_GUID,REC_INDEX",
    "TableColumns": "KEY_GUID,REC_INDEX,DATA_FIELD_26,DATA_VALUE_26,DATA_FIELD_27,DATA_VALUE_27,DATA_FIELD_28,DATA_VALUE_28,DATA_FIELD_29,DATA_VALUE_29,DATA_FIELD_30,DATA_VALUE_30,DATA_FIELD_31,DATA_VALUE_31,DATA_FIELD_32,DATA_VALUE_32,DATA_FIELD_33,DATA_VALUE_33,DATA_FIELD_34,DATA_VALUE_34,DATA_FIELD_35,DATA_VALUE_35,DATA_FIELD_36,DATA_VALUE_36,DATA_FIELD_37,DATA_VALUE_37,DATA_FIELD_38,DATA_VALUE_38,DATA_FIELD_39,DATA_VALUE_39,DATA_FIELD_40,DATA_VALUE_40,DATA_FIELD_41,DATA_VALUE_41,DATA_FIELD_42,DATA_VALUE_42,DATA_FIELD_43,DATA_VALUE_43,DATA_FIELD_44,DATA_VALUE_44,DATA_FIELD_45,DATA_VALUE_45,DATA_FIELD_46,DATA_VALUE_46,DATA_FIELD_47,DATA_VALUE_47,DATA_FIELD_48,DATA_VALUE_48,DATA_FIELD_49,DATA_VALUE_49,DATA_FIELD_50,DATA_VALUE_50",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "SPI_AUDIT_HISTORY",
    "PKColumns": "CHANGE_ID",
    "TableColumns": "CHANGE_ID,SERVER_NAME,TABLE_NAME,CHANGE_TYPE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_AUDIT_HISTORY_FIELDS",
    "PKColumns": "CHANGE_ID,COLUMN_NAME",
    "TableColumns": "CHANGE_ID,COLUMN_NAME,INITIAL_VALUE,NEW_VALUE",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "SPI_AUDIT_HISTORY_KEYS",
    "PKColumns": "CHANGE_ID,KEY_FIELD",
    "TableColumns": "CHANGE_ID,KEY_FIELD,KEY_VALUE",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "SPI_AUDIT_SESS",
    "PKColumns": "KEY_GUID",
    "TableColumns": "KEY_GUID,LOGON_USER,SERVER_NAME,REMOTE_ADDR,USER_AGENT,PATH_INFO,HTTP_REFERER,QUERY_STRING",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "SPI_AUDIT_TASK",
    "PKColumns": "PARAM_KEY,RUN_TIME",
    "TableColumns": "PARAM_KEY,RUN_TIME,DISTRICT,TASK_OWNER,TASK_DESCRIPTION",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "SPI_AUDIT_TASK_PAR",
    "PKColumns": "PARAM_KEY,PARAM_IDX,RUN_TIME",
    "TableColumns": "PARAM_KEY,PARAM_IDX,RUN_TIME,IS_ENV_PARAM,PARAM_NAME,PARAM_VALUE",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "SPI_BACKUP_TABLES",
    "PKColumns": "PACKAGE,TABLE_NAME",
    "TableColumns": "PACKAGE,TABLE_NAME,RESTORE_ORDER,JOIN_CONDITION",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "SPI_BLDG_PACKAGE",
    "PKColumns": "DISTRICT,BUILDING,PACKAGE",
    "TableColumns": "DISTRICT,BUILDING,PACKAGE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_BUILDING_LIST",
    "PKColumns": "DISTRICT,OPTION_TYPE",
    "TableColumns": "DISTRICT,OPTION_TYPE,LIST_PAGE_TITLE,TABLE_NAME,NAVIGATE_TO,USE_SCHOOL_YEAR,USE_SUMMER_SCHOOL",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "Spi_checklist_menu_items",
    "PKColumns": "",
    "TableColumns": "DISTRICT,PAGE_ID,DESCRIPTION,URL,RESERVED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_CHECKLIST_RESULTS",
    "PKColumns": "DISTRICT,BUILDING,CHECKLIST_CODE,CHECKLIST_RUN_WHEN,RC_RUN,CHECKLIST_ORDER",
    "TableColumns": "DISTRICT,BUILDING,CHECKLIST_CODE,CHECKLIST_RUN_WHEN,RC_RUN,CHECKLIST_ORDER,IS_DONE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_CHECKLIST_SETUP_DET",
    "PKColumns": "DISTRICT,BUILDING,CHECKLIST_CODE,CHECKLIST_RUN_WHEN,RC_RUN,CHECKLIST_ORDER",
    "TableColumns": "DISTRICT,BUILDING,CHECKLIST_CODE,CHECKLIST_RUN_WHEN,RC_RUN,CHECKLIST_ORDER,PAGE_ID,CHECKLIST_ITEM_NOTE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_CHECKLIST_SETUP_HDR",
    "PKColumns": "DISTRICT,BUILDING,CHECKLIST_CODE,CHECKLIST_RUN_WHEN,RC_RUN",
    "TableColumns": "DISTRICT,BUILDING,CHECKLIST_CODE,CHECKLIST_RUN_WHEN,RC_RUN,CHECKLIST_DESCRIPTION,PACKAGE,NOTE_TEXT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_CODE_IN_USE",
    "PKColumns": "DISTRICT,TABLE_NAME,COLUMN_NAME,FOREIGN_KEY_TABLE_NAME,FOREIGN_KEY_COLUMN_NAME",
    "TableColumns": "DISTRICT,TABLE_NAME,COLUMN_NAME,FOREIGN_KEY_TABLE_NAME,FOREIGN_KEY_COLUMN_NAME,USE_ENV_DISTRICT,USE_ENV_SCHOOL_YEAR,USE_ENV_SUMMER_SCHOOL,CRITERIA,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_CODE_IN_USE_FILTER",
    "PKColumns": "DISTRICT,TABLE_NAME,COLUMN_NAME,FOREIGN_KEY_TABLE_NAME,FOREIGN_KEY_COLUMN_NAME,FILTER_COLUMN_NAME",
    "TableColumns": "DISTRICT,TABLE_NAME,COLUMN_NAME,FOREIGN_KEY_TABLE_NAME,FOREIGN_KEY_COLUMN_NAME,FILTER_COLUMN_NAME,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_COLUMN_CONTROL",
    "PKColumns": "COLUMNCONTROLID",
    "TableColumns": "COLUMNCONTROLID,TABLENAME,COLUMNNAME,CONTROLTYPEID,RESERVED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_COLUMN_INFO",
    "PKColumns": "DISTRICT,TABLE_NAME,COLUMN_NAME",
    "TableColumns": "DISTRICT,TABLE_NAME,COLUMN_NAME,UI_CONTROL_TYPE,VAL_LIST,VAL_LIST_DISP,VAL_TBL_NAME,VAL_COL_CODE,VAL_COL_DESC,VAL_SQL_WHERE,VAL_ORDER_BY_CODE,VAL_DISP_FORMAT,SEC_PACKAGE,SEC_SUBPACKAGE,SEC_FEATURE,COLUMN_WIDTH,CHANGE_DATE_TIME,CHANGE_UID,SOUNDS_LIKE",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_COLUMN_NAMES",
    "PKColumns": "DISTRICT,TABLE_NAME,COLUMN_NAME,CULTURE_CODE",
    "TableColumns": "DISTRICT,TABLE_NAME,COLUMN_NAME,CULTURE_CODE,COLUMN_DESCRIPTION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_COLUMN_VALIDATION",
    "PKColumns": "DISTRICT,TABLE_NAME,COLUMN_NAME",
    "TableColumns": "DISTRICT,TABLE_NAME,COLUMN_NAME,VAL_LIST,VAL_LIST_DISP,VAL_TBL_NAME,VAL_COL_CODE,VAL_COL_DESC,VAL_SQL_WHERE,RESERVED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_CONFIG_EXTENSION",
    "PKColumns": "CONFIG_ID",
    "TableColumns": "CONFIG_ID,TABLE_NAME,SCHOOL_YEAR_REQUIRED,SUMMER_SCHOOL_REQUIRED,BUILDING_REQUIRED,CONFIG_TYPE_REQUIRED",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "SPI_CONFIG_EXTENSION_DETAIL",
    "PKColumns": "DETAIL_ID",
    "TableColumns": "DETAIL_ID,ENV_ID,CONFIG_ID,PRODUCT,DATA,DATA_TYPE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_CONFIG_EXTENSION_ENVIRONMENT",
    "PKColumns": "ENV_ID",
    "TableColumns": "ENV_ID,DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,CONFIG_TYPE",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "SPI_CONVERT",
    "PKColumns": "ID_NUM",
    "TableColumns": "DISTRICT,DESCRIPTION,CATEGORY,INDEX1,INDEX2,INDEX3,INDEX4,INDEX5,INDEX6,FIELD_VALUE,LOADED,ID_NUM,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_CONVERT_CONTACT",
    "PKColumns": "DISTRICT,STUDENT_ID,CONTACT_ID",
    "TableColumns": "DISTRICT,STUDENT_ID,CONTACT_ID,FIRST_NAME,MIDDLE_NAME,LAST_NAME,APARTMENT,LOT,STREET,CITY,STATE,ZIPCODE,PHONE",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "SPI_CONVERT_ERROR_LOG",
    "PKColumns": "DISTRICT,RUN_ID,RUN_TIME,RUN_ORDER",
    "TableColumns": "DISTRICT,RUN_ID,RUN_TIME,RUN_ORDER,PACKAGE_ID,PROC_NAME,TABLE_NAME,ERROR_ID,LINE_NUMBER,SQL_STATEMENT,ERROR_DESCRIPTION,SEVERITY,KEY1_COLNAME,KEY1_VALUE,KEY2_COLNAME,KEY2_VALUE,KEY3_COLNAME,KEY3_VALUE,KEY4_COLNAME,KEY4_VALUE,KEY5_COLNAME,KEY5_VALUE,KEY6_COLNAME,KEY6_VALUE,KEY7_COLNAME,KEY7_VALUE,KEY8_COLNAME,KEY8_VALUE,KEY9_COLNAME,KEY9_VALUE",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "SPI_CONVERT_MAP",
    "PKColumns": "DISTRICT,TABLE_NAME,FIELD_NAME",
    "TableColumns": "DISTRICT,TABLE_NAME,FIELD_NAME,INDEX1_DESC,INDEX2_DESC,INDEX3_DESC,INDEX4_DESC,INDEX5_DESC,INDEX6_DESC,VAL_TABLE,VAL_FIELD,CATEGORY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_CONVERT_STAFF",
    "PKColumns": "",
    "TableColumns": "DISTRICT,BUILDING,OS_TEA_NUMBER,STAFF_ID,FIRST_NAME,LAST_NAME,SSN",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "SPI_CONVERT_TYPE",
    "PKColumns": "DISTRICT,CATEGORY",
    "TableColumns": "DISTRICT,CATEGORY,INDEX1_DESC,INDEX2_DESC,INDEX3_DESC,INDEX4_DESC,INDEX5_DESC,INDEX6_DESC,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_COPY_CALC",
    "PKColumns": "DISTRICT,TABLE_NAME,COLUMN_NAME",
    "TableColumns": "DISTRICT,TABLE_NAME,COLUMN_NAME,PROCESS_ACTION,RESERVED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_COPY_DET",
    "PKColumns": "DISTRICT,COPY_ID,TABLE_NAME",
    "TableColumns": "DISTRICT,COPY_ID,TABLE_NAME,ORDER_WITHIN_ID,WHERE_BUILDING,WHERE_SCHOOL_YEAR,WHERE_SUMMER,WHERE_ALL_BUILDINGS,SKIP_IF_YEAR_DIFFERS,RESERVED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "spi_copy_det_731719",
    "PKColumns": "",
    "TableColumns": "DISTRICT,COPY_ID,TABLE_NAME,ORDER_WITHIN_ID,WHERE_BUILDING,WHERE_SCHOOL_YEAR,WHERE_SUMMER,WHERE_ALL_BUILDINGS,SKIP_IF_YEAR_DIFFERS,RESERVED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_COPY_HDR",
    "PKColumns": "DISTRICT,COPY_ID",
    "TableColumns": "DISTRICT,COPY_ID,COPY_ID_ORDER,SEC_PACKAGE,TITLE,PACKAGE_ORDER,ROW_POSITION,COLUMN_POSITION,SCHOOL_YEAR_DIFFER,SUMMER_DIFFER,RESERVED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "spi_copy_hdr_731719",
    "PKColumns": "",
    "TableColumns": "DISTRICT,COPY_ID,COPY_ID_ORDER,SEC_PACKAGE,TITLE,PACKAGE_ORDER,ROW_POSITION,COLUMN_POSITION,SCHOOL_YEAR_DIFFER,SUMMER_DIFFER,RESERVED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_COPY_JOIN",
    "PKColumns": "DISTRICT,TABLE_NAME,COLUMN_NAME,HDR_TABLE_NAME,HDR_COLUMN_NAME",
    "TableColumns": "DISTRICT,TABLE_NAME,COLUMN_NAME,HDR_TABLE_NAME,HDR_COLUMN_NAME,RESERVED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_COPY_LINK",
    "PKColumns": "DISTRICT,COPY_ID,LINK_COPY_ID",
    "TableColumns": "DISTRICT,COPY_ID,LINK_COPY_ID,RESERVED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "spi_copy_link_731719",
    "PKColumns": "",
    "TableColumns": "DISTRICT,COPY_ID,LINK_COPY_ID,RESERVED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_COPY_MS_DET",
    "PKColumns": "DISTRICT,TABLE_NAME",
    "TableColumns": "DISTRICT,TABLE_NAME,RESERVED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_CUST_TEMPLATES",
    "PKColumns": "DISTRICT,CUSTOM_CODE,TEMPLATE_FILE_NAME",
    "TableColumns": "DISTRICT,CUSTOM_CODE,TEMPLATE_FILE_NAME,FRIENDLY_NAME,DEFAULT_TEMPLATE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_CUSTOM_CODE",
    "PKColumns": "DISTRICT,CUSTOM_CODE,PACKAGE",
    "TableColumns": "DISTRICT,CUSTOM_CODE,PACKAGE",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "SPI_CUSTOM_DATA",
    "PKColumns": "DISTRICT,CUSTOM_CODE,DATA_CODE",
    "TableColumns": "DISTRICT,CUSTOM_CODE,DATA_CODE,DATA_VALUE",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "SPI_CUSTOM_LAUNCH",
    "PKColumns": "LAUNCHER_ID",
    "TableColumns": "LAUNCHER_ID,BIN_NAME,LAUNCHER_TYPE",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "SPI_CUSTOM_MODS",
    "PKColumns": "DISTRICT,CUSTOM_CODE,BASE_MODULE",
    "TableColumns": "DISTRICT,CUSTOM_CODE,BASE_MODULE,CUSTOM_MODULE,DESCRIPTION",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "SPI_CUSTOM_SCRIPT",
    "PKColumns": "MODULE_NAME",
    "TableColumns": "MODULE_NAME,PROGRAM",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "SPI_DATA_CACHE",
    "PKColumns": "DISTRICT,CACHE_TYPE,CACHE_KEY,OWNER_ID",
    "TableColumns": "DISTRICT,CACHE_TYPE,CACHE_KEY,OWNER_ID,CACHE_DATA,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_DIST_BUILDING_CHECKLIST",
    "PKColumns": "DISTRICT,SETUP_TYPE,PANEL_HEADING_CODE,MENU_ID,MENU_TYPE,OPTION_ORDER",
    "TableColumns": "DISTRICT,SETUP_TYPE,PANEL_HEADING_CODE,PACKAGE,MENU_ID,MENU_TYPE,MENU_TITLE_OVERRIDE,OPTION_ORDER,VAL_TABLE_NAME,EVALUATE_SCHOOL_YEAR,EVALUATE_SUMMER_SCHOOL,QUERYSTRING,RESERVED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_DIST_PACKAGE",
    "PKColumns": "DISTRICT,CONFIG_DIST,PACKAGE",
    "TableColumns": "DISTRICT,CONFIG_DIST,PACKAGE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_DISTRICT_INIT",
    "PKColumns": "VAL_TAB,APP_CODE",
    "TableColumns": "VAL_TAB,APP_CODE,DELETE_BEFORE_COPY",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "SPI_DYNAMIC_CONTAINERTYPE",
    "PKColumns": "CONTAINERTYPEID",
    "TableColumns": "CONTAINERTYPEID,CONTAINERTYPE,RESERVED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_DYNAMIC_LAYOUT",
    "PKColumns": "LAYOUTID",
    "TableColumns": "LAYOUTID,PAGEID,USERID,PARENTLAYOUTID,CONTAINERTYPEID,ORDERNUMBER,TITLE,WIDTH,WIDGETID,INSTANCEID,RESERVED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_DYNAMIC_PAGE",
    "PKColumns": "PAGEID",
    "TableColumns": "PAGEID,PAGENAME,RESERVED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_DYNAMIC_PAGE_WIDGET",
    "PKColumns": "PAGEWIDGETID",
    "TableColumns": "PAGEWIDGETID,PAGEID,WIDGETID,ISEDITABLE,ISREQUIRED,RESERVED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_DYNAMIC_SETTING",
    "PKColumns": "SETTINGID",
    "TableColumns": "SETTINGID,SETTINGNAME,SETTINGTYPEID,DATATYPEID,RESERVED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_DYNAMIC_WIDGET",
    "PKColumns": "WIDGETID",
    "TableColumns": "WIDGETID,WIDGETTYPEID,TITLE,DESCRIPTION,ISRESIZABLE,AREA,CONTROLLER,ACTION,PARTIALVIEW,COLUMNCONTROLID,PACKAGE,SUBPACKAGE,FEATURE,RESERVED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_DYNAMIC_WIDGET_SETTING",
    "PKColumns": "WIDGETSETTINGID,INSTANCEID",
    "TableColumns": "WIDGETSETTINGID,INSTANCEID,WIDGETID,SETTINGID,PAGEID,USERID,DATAKEY,VALUEINT,VALUEBOOL,VALUESTRING,VALUEDATETIME,RESERVED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_DYNAMIC_WIDGET_TYPE",
    "PKColumns": "WIDGETTYPEID",
    "TableColumns": "WIDGETTYPEID,WIDGETTYPE,RESERVED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_EVENT",
    "PKColumns": "DISTRICT,LOGIN_ID,EVENT_DATE_TIME,EVENT_TYPE",
    "TableColumns": "DISTRICT,LOGIN_ID,EVENT_DATE_TIME,EVENT_TYPE,SECTION_KEY,COURSE_SESSION,ASMT_NUMBER,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_FEATURE_FLAG",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ENABLED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_FEEDBACK_ANS",
    "PKColumns": "DISTRICT,CATEGORY,LINE_NUMBER",
    "TableColumns": "DISTRICT,CATEGORY,LINE_NUMBER,ANSWER,COMMENT",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "SPI_FEEDBACK_Q_HDR",
    "PKColumns": "DISTRICT,CATEGORY,DESCRIPTION",
    "TableColumns": "DISTRICT,CATEGORY,DESCRIPTION",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "SPI_FEEDBACK_QUEST",
    "PKColumns": "DISTRICT,CATEGORY,LINE_NUMBER",
    "TableColumns": "DISTRICT,CATEGORY,LINE_NUMBER,QUESTION,ANSWER_TYPE",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "SPI_FEEDBACK_RECIP",
    "PKColumns": "DISTRICT,RECIPIENT",
    "TableColumns": "DISTRICT,RECIPIENT,RECIPIENT_TYPE",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "SPI_FIELD_HELP",
    "PKColumns": "DISTRICT,AREA,CONTROLLER,ACTION,FIELD,STATE",
    "TableColumns": "DISTRICT,AREA,CONTROLLER,ACTION,FIELD,IS_GRID_HEADER,IS_IN_DIALOG,GRID_ID,DIALOG_ID,DESCRIPTION,DISPLAY_NAME,STATE,RESERVED,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_FIRSTWAVE",
    "PKColumns": "FIRSTWAVE_ID",
    "TableColumns": "FIRSTWAVE_ID,SITE_CODE,DISTRICT_NAME",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "SPI_HAC_NEWS",
    "PKColumns": "DISTRICT,NEWS_ID",
    "TableColumns": "DISTRICT,NEWS_ID,ADMIN_OR_TEACHER,HEADLINE,NEWS_TEXT,EFFECTIVE_DATE,EXPIRATION_DATE,FOR_PARENTS,FOR_STUDENTS,STAFF_ID,SECTION_KEY,PRINT_COURSE_INFO,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_HAC_NEWS_BLDG",
    "PKColumns": "DISTRICT,NEWS_ID,BUILDING",
    "TableColumns": "DISTRICT,NEWS_ID,BUILDING,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_HOME_SECTIONS",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,REQUIRED_SECTION,HAS_SETTINGS,REFRESH_TYPE,CAN_DELETE,DESIRED_COL_WIDTH,XSL_DISPLAY_FILE,XSL_SETTINGS_FILE,SEC_PACKAGE,SEC_SUBPACKAGE,SEC_FEATURE,CAN_ADDNEW,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_HOME_USER_CFG",
    "PKColumns": "DISTRICT,LOGIN_ID,SECTION_CODE,SETTING_CODE",
    "TableColumns": "DISTRICT,LOGIN_ID,SECTION_CODE,SETTING_CODE,SETTING_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_HOME_USER_SEC",
    "PKColumns": "DISTRICT,LOGIN_ID,SECTION_CODE",
    "TableColumns": "DISTRICT,LOGIN_ID,SECTION_CODE,COLUMN_NO,ROW_NO,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_IEPWEBSVC_CFG",
    "PKColumns": "DISTRICT",
    "TableColumns": "DISTRICT,CUSTOMER_CODE,PASSWORD,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_IMM_TSK_RESULT",
    "PKColumns": "DISTRICT,PARAM_KEY",
    "TableColumns": "DISTRICT,PARAM_KEY,RESULT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_INPROG",
    "PKColumns": "PROC_KEY,PARAM_KEY",
    "TableColumns": "PROC_KEY,PARAM_KEY,START_TIME,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_INTEGRATION_DET",
    "PKColumns": "DISTRICT,PRODUCT,OPTION_NAME",
    "TableColumns": "DISTRICT,PRODUCT,OPTION_NAME,OPTION_VALUE",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "SPI_INTEGRATION_HDR",
    "PKColumns": "DISTRICT,PRODUCT",
    "TableColumns": "DISTRICT,PRODUCT,DESCRIPTION,PACKAGE,SUBPACKAGE,FEATURE",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "SPI_INTEGRATION_LOGIN",
    "PKColumns": "DISTRICT,PRODUCT,LOGIN_ID",
    "TableColumns": "DISTRICT,PRODUCT,LOGIN_ID,OTHER_LOGIN_ID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_INTEGRATION_SESSION_DET",
    "PKColumns": "SESSION_GUID,VARIABLE_NAME",
    "TableColumns": "SESSION_GUID,VARIABLE_NAME,VARIABLE_VALUE",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "SPI_INTEGRATION_SESSION_HDR",
    "PKColumns": "SESSION_GUID",
    "TableColumns": "SESSION_GUID,TSTAMP",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "SPI_INTEGRATION_STUDATA_DET",
    "PKColumns": "DISTRICT,GROUP_CODE,STUDENT_ID",
    "TableColumns": "DISTRICT,GROUP_CODE,STUDENT_ID",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "SPI_INTEGRATION_STUDATA_HDR",
    "PKColumns": "DISTRICT,GROUP_CODE",
    "TableColumns": "DISTRICT,GROUP_CODE",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "SPI_JOIN_COND",
    "PKColumns": "REFTABLE,REFCOL,LINKTABLE,SEQUENCE",
    "TableColumns": "REFTABLE,REFCOL,LINKTABLE,SEQUENCE,JOINTABLE,JOINCOLUMN,JOINTYPE,VALUE_TYPE,JOINVALUE,BASETABLE,BASECOLUMN",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "SPI_JOIN_SELECT",
    "PKColumns": "REFTABLE,REFCOL,LINKTABLE",
    "TableColumns": "REFTABLE,REFCOL,LINKTABLE,SELECTCLAUSE,AS_COLUMN",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "SPI_MAP_CFG",
    "PKColumns": "DISTRICT",
    "TableColumns": "DISTRICT,GOOGLE_MAP_KEY,HEAT_MAP_KEY,MAX_ROWS,TASK_USER_ID,TASK_PASSWORD,TASK_DOMAIN,TASK_PROXY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_NEWS",
    "PKColumns": "DISTRICT,NEWS_ID",
    "TableColumns": "DISTRICT,NEWS_ID,NEWS_DATE,NEWS_HEADLINE,NEWS_TEXT,EXPIRATION_DATE,REQUIRED_READING,FOR_OFFICE_EMPLOYEES,FOR_TEACHERS,FOR_PARENTS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_NEWS_BLDG",
    "PKColumns": "DISTRICT,NEWS_ID,BUILDING",
    "TableColumns": "DISTRICT,NEWS_ID,BUILDING,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_OBJECT_PERM",
    "PKColumns": "DISTRICT,PERMISSION,OBJECT,SQL_USER",
    "TableColumns": "DISTRICT,PERMISSION,OBJECT,SQL_USER",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "SPI_OPTION_COLUMN_NULLABLE",
    "PKColumns": "DISTRICT,SEARCH_TYPE,TABLE_NAME",
    "TableColumns": "DISTRICT,SEARCH_TYPE,TABLE_NAME,COLUMN_NAME,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_OPTION_EXCLD",
    "PKColumns": "DISTRICT,SEARCH_TYPE,TABLE_NAME,COLUMN_NAME",
    "TableColumns": "DISTRICT,SEARCH_TYPE,TABLE_NAME,COLUMN_NAME,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_OPTION_LIST_FIELD",
    "PKColumns": "DISTRICT,SEARCH_TYPE,TABLE_NAME,COLUMN_NAME",
    "TableColumns": "DISTRICT,SEARCH_TYPE,TABLE_NAME,COLUMN_NAME,DISPLAY_ORDER,IS_HIDDEN,FORMATTER,NAVIGATION_PARAM,COLUMN_LABEL,IS_SEC_BUILDING_COL,COLUMN_WIDTH,RESERVED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_OPTION_NAME",
    "PKColumns": "DISTRICT,SEARCH_TYPE",
    "TableColumns": "DISTRICT,SEARCH_TYPE,OPTION_NAME,NAVIGATE_TO,BTN_NEW_NAVIGATE,USER_DEF_SCR_TYPE,USE_PROGRAMS,TARGET_TABLE,DELETE_TABLE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_OPTION_SIMPLE_SEARCH",
    "PKColumns": "DISTRICT,SEARCH_TYPE,TABLE_NAME,COLUMN_NAME,ENVIRONMENT",
    "TableColumns": "DISTRICT,SEARCH_TYPE,TABLE_NAME,COLUMN_NAME,ENVIRONMENT,DISPLAY_ORDER,OPERATOR,OVERRIDE_LABEL,RESERVED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_OPTION_TABLE",
    "PKColumns": "DISTRICT,SEARCH_TYPE,TABLE_NAME",
    "TableColumns": "DISTRICT,SEARCH_TYPE,TABLE_NAME,SEQUENCE_NUM,SEC_PACKAGE,SEC_SUBPACKAGE,SEC_FEATURE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_OPTION_UPDATE",
    "PKColumns": "DISTRICT,SEARCH_TYPE,TABLE_NAME,COLUMN_NAME",
    "TableColumns": "DISTRICT,SEARCH_TYPE,TABLE_NAME,COLUMN_NAME,UI_CONTROL_TYPE,IS_REQUIRED,ENTRY_FILTER,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_POWERPACK_CONFIGURATION",
    "PKColumns": "DISTRICT,ROW_NUMBER",
    "TableColumns": "DISTRICT,ROW_NUMBER,CUSTOM_CODE,CUSTOM_NAME,CUSTOM_DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_PRIVATE_FIELD",
    "PKColumns": "DISTRICT,TABLE_NAME,COLUMN_NAME",
    "TableColumns": "DISTRICT,TABLE_NAME,COLUMN_NAME,PACKAGE,SUBPACKAGE,FEATURE",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "SPI_RESOURCE",
    "PKColumns": "DISTRICT,APPLICATION_ID,RESOURCE_ID,CULTURE_CODE,RESOURCE_KEY",
    "TableColumns": "DISTRICT,APPLICATION_ID,RESOURCE_ID,CULTURE_CODE,RESOURCE_KEY,RESOURCE_VALUE,RESERVED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_RESOURCE_OVERRIDE",
    "PKColumns": "DISTRICT,APPLICATION_ID,RESOURCE_ID,CULTURE_CODE,RESOURCE_KEY",
    "TableColumns": "DISTRICT,APPLICATION_ID,RESOURCE_ID,CULTURE_CODE,RESOURCE_KEY,OVERRIDE_VALUE,RESERVED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_SEARCH_FAV",
    "PKColumns": "DISTRICT,LOGIN_ID,SEARCH_TYPE,SEARCH_NUMBER",
    "TableColumns": "DISTRICT,LOGIN_ID,SEARCH_TYPE,SEARCH_NUMBER,SEARCH_NAME,DESCRIPTION,LAST_SEARCH,GROUPING_MASK,CATEGORY,PUBLISH,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_SEARCH_FAV_SUBSCRIBE",
    "PKColumns": "DISTRICT,LOGIN_ID,PUB_LOGIN_ID,PUB_SEARCH_TYPE,PUB_SEARCH_NUMBER",
    "TableColumns": "DISTRICT,LOGIN_ID,PUB_LOGIN_ID,PUB_SEARCH_TYPE,PUB_SEARCH_NUMBER,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_SECONDARY_KEY_USED",
    "PKColumns": "DISTRICT,TABLE_NAME",
    "TableColumns": "DISTRICT,TABLE_NAME,LAST_USED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_SESSION_STATE",
    "PKColumns": "SESSION_ID,NAME",
    "TableColumns": "SESSION_ID,NAME,VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_STATE_REQUIREMENTS",
    "PKColumns": "",
    "TableColumns": "ID,STATE,ASPPAGE,FRIENDLYNAME,SQL,WARNING,WARNINGTYPE,SCREENNAME,SHOWDDFORM,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_TABLE_JOIN",
    "PKColumns": "DISTRICT,SOURCE_TABLE,TARGET_TABLE,SEQUENCE_NUMBER",
    "TableColumns": "DISTRICT,SOURCE_TABLE,TARGET_TABLE,SEQUENCE_NUMBER,JOIN_TABLE_1,JOIN_COLUMN_1,JOIN_TABLE_2,JOIN_COLUMN_2,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_TABLE_NAMES",
    "PKColumns": "DISTRICT,TABLE_NAME",
    "TableColumns": "DISTRICT,TABLE_NAME,TABLE_DESCRIPTION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_TASK",
    "PKColumns": "DISTRICT,PARAM_KEY",
    "TableColumns": "DISTRICT,PARAM_KEY,TASK_KEY,TASK_TYPE,RELATED_PAGE,CLASSNAME,TASK_DESCRIPTION,TASK_FILE,SCHEDULED_TIME,TASK_STATUS,TASK_OWNER,TASK_SERVER,NEXT_RUN_TIME,LAST_RUN_TIME,SCHEDULE_TYPE,SCHD_INTERVAL,SCHD_DOW,QUEUE_POSITION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_TASK_ERR_DESC",
    "PKColumns": "PARAM_KEY,DESCRIPTION_INDEX",
    "TableColumns": "PARAM_KEY,DESCRIPTION_INDEX,ERROR_DESCRIPTION",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "SPI_TASK_ERROR",
    "PKColumns": "PARAM_KEY",
    "TableColumns": "PARAM_KEY,DISTRICT,ERROR_SOURCE,ERROR_NUMBER,ERROR_LINE",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "SPI_TASK_LB_STATS",
    "PKColumns": "DISTRICT,SERVER_NAME",
    "TableColumns": "DISTRICT,SERVER_NAME,TASK_DB_CONNECTION_STRING,DEBUG_TASK_SERVICES,TRACE_LB_SERVICE,INCLUDE_WEB_SERVERS,EXCLUDE_WEB_SERVERS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_TASK_LOG_DET",
    "PKColumns": "DISTRICT,PARAM_KEY,RUN_NUMBER,MESSAGE_INDEX",
    "TableColumns": "DISTRICT,PARAM_KEY,RUN_NUMBER,MESSAGE_INDEX,MESSAGE_NUMBER,KEY_VALUE1,KEY_VALUE2,KEY_VALUE3,KEY_VALUE4,KEY_VALUE5,KEY_VALUE6,KEY_VALUE7,KEY_VALUE8,KEY_VALUE9,KEY_VALUE10,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_TASK_LOG_HDR",
    "PKColumns": "DISTRICT,PARAM_KEY,RUN_NUMBER",
    "TableColumns": "DISTRICT,PARAM_KEY,RUN_NUMBER,TASK_CODE,BASE_TASK_NAME,CUSTOM_TASK_NAME,TASK_OWNER,START_TIME,END_TIME,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_TASK_LOG_MESSAGE",
    "PKColumns": "DISTRICT,PARAM_KEY,RUN_NUMBER,MESSAGE_NUMBER",
    "TableColumns": "DISTRICT,PARAM_KEY,RUN_NUMBER,MESSAGE_NUMBER,MESSAGE_TYPE,MESSAGE,DATAFIELD1,DATAFIELD2,DATAFIELD3,DATAFIELD4,DATAFIELD5,DATAFIELD6,DATAFIELD7,DATAFIELD8,DATAFIELD9,DATAFIELD10,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_TASK_LOG_PARAMS",
    "PKColumns": "PARAM_KEY,RUN_NUMBER,PARAM_INDEX",
    "TableColumns": "PARAM_KEY,RUN_NUMBER,PARAM_INDEX,IS_ENV_PARAM,PARAM_NAME,PARAM_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_TASK_PARAMS",
    "PKColumns": "PARAM_KEY,PARAM_IDX",
    "TableColumns": "PARAM_KEY,PARAM_IDX,IS_ENV_PARAM,PARAM_NAME,PARAM_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_TASK_PROG",
    "PKColumns": "PARAM_KEY",
    "TableColumns": "PARAM_KEY,DISTRICT,LOGIN_ID,PROC_DESC,START_TIME,TOTAL_RECS,RECS_PROCESSED,END_TIME,DESCRIPTION,ERROR_OCCURRED",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "SPI_TIME_OFFSET",
    "PKColumns": "DISTRICT",
    "TableColumns": "DISTRICT,OFFSET,DISTRICT_TIMEZONE",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "SPI_TMP_WATCH_LIST",
    "PKColumns": "DISTRICT,LOGIN_ID,WATCH_NAME,STUDENT_ID",
    "TableColumns": "DISTRICT,LOGIN_ID,WATCH_NAME,STUDENT_ID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_TRIGGER_STATE",
    "PKColumns": "TRIGGER_NAME,TRIGGER_STATE,SPID",
    "TableColumns": "TRIGGER_NAME,TRIGGER_STATE,SPID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_USER_GRID",
    "PKColumns": "DISTRICT,LOGIN_ID,PAGE_CODE,GRID_ID",
    "TableColumns": "DISTRICT,LOGIN_ID,PAGE_CODE,GRID_ID,GRID_COLUMN_NAMES,GRID_COLUMN_MODELS,GRID_STATE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_USER_OPTION",
    "PKColumns": "DISTRICT,LOGIN_ID,PAGE_CODE,OPTION_CODE",
    "TableColumns": "DISTRICT,LOGIN_ID,PAGE_CODE,OPTION_CODE,OPTION_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_USER_OPTION_BLDG",
    "PKColumns": "DISTRICT,LOGIN_ID,BUILDING,PAGE_CODE,OPTION_CODE",
    "TableColumns": "DISTRICT,LOGIN_ID,BUILDING,PAGE_CODE,OPTION_CODE,OPTION_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_USER_PROMPT",
    "PKColumns": "DISTRICT,LOGIN_ID,SEARCH_TYPE,PROMPT_NAME",
    "TableColumns": "DISTRICT,LOGIN_ID,SEARCH_TYPE,PROMPT_NAME,PROMPT_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_USER_SEARCH",
    "PKColumns": "DISTRICT,LOGIN_ID,SEARCH_TYPE,SEARCH_NUMBER,SEQUENCE_NUM",
    "TableColumns": "DISTRICT,LOGIN_ID,SEARCH_TYPE,SEARCH_NUMBER,SEQUENCE_NUM,AND_OR_FLAG,TABLE_NAME,SCREEN_TYPE,SCREEN_NUMBER,PROGRAM_ID,COLUMN_NAME,FIELD_NUMBER,OPERATOR,SEARCH_VALUE1,SEARCH_VALUE2,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_USER_SEARCH_LIST_FIELD",
    "PKColumns": "DISTRICT,LOGIN_ID,SEARCH_TYPE,SEARCH_NUMBER,SEQUENCE_NUM",
    "TableColumns": "DISTRICT,LOGIN_ID,SEARCH_TYPE,SEARCH_NUMBER,SEQUENCE_NUM,TABLE_NAME,SCREEN_TYPE,SCREEN_NUMBER,PROGRAM_ID,COLUMN_NAME,FIELD_NUMBER,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_USER_SORT",
    "PKColumns": "DISTRICT,LOGIN_ID,SORT_TYPE,SORT_NUMBER,SEQUENCE_NUM",
    "TableColumns": "DISTRICT,LOGIN_ID,SORT_TYPE,SORT_NUMBER,SEQUENCE_NUM,TABLE_NAME,SCREEN_TYPE,SCREEN_NUMBER,PROGRAM_ID,COLUMN_NAME,FIELD_NUMBER,SORT_ORDER,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_USER_TOKEN",
    "PKColumns": "DISTRICT,LOGIN_ID,PRODUCT,TOKEN_TYPE",
    "TableColumns": "DISTRICT,LOGIN_ID,PRODUCT,TOKEN_TYPE,TOKEN,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_VAL_TABS",
    "PKColumns": "PACKAGE,REFTAB,REFCOL,SEQUENCE",
    "TableColumns": "PACKAGE,REFTAB,REFCOL,SEQUENCE,VALTAB,VALCOL,VALDESC,PARAM,VALUE",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "SPI_VALIDATION_TABLES",
    "PKColumns": "DISTRICT,PACKAGE,TABLE_NAME,USER_DEFINED,RESERVED",
    "TableColumns": "DISTRICT,PACKAGE,TABLE_NAME,TABLE_DESCR,USER_DEFINED,CUSTOM_CODE,RESERVED,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID,FEATURE_FLAG",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_VERSION",
    "PKColumns": "",
    "TableColumns": "VERSION,DB_VERSION,IS_STUPLUS_CONV,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_WATCH_LIST",
    "PKColumns": "DISTRICT,LOGIN_ID,WATCH_NUMBER",
    "TableColumns": "DISTRICT,LOGIN_ID,WATCH_NUMBER,WATCH_NAME,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_WATCH_LIST_STUDENT",
    "PKColumns": "DISTRICT,LOGIN_ID,WATCH_NUMBER,STUDENT_ID",
    "TableColumns": "DISTRICT,LOGIN_ID,WATCH_NUMBER,STUDENT_ID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_WORKFLOW_MESSAGES",
    "PKColumns": "DISTRICT,USER_ID,MSG_DATE,MSG_SEQUENCE",
    "TableColumns": "DISTRICT,USER_ID,MSG_DATE,MSG_SEQUENCE,BUILDING,MSG_TYPE,MESSAGE_BODY,URL,STUDENT_ID,SECTION_KEY,STAFF_ID,COURSE_SESSION,SCHD_RESOLVED,MESSAGE_DATE1,MESSAGE_DATE2,CHANGE_DATE_TIME,CHANGE_UID,FROM_BUILDING",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SPI_Z_SCALE",
    "PKColumns": "DISTRICT,Z_INDEX,PERCENTILE",
    "TableColumns": "DISTRICT,Z_INDEX,PERCENTILE",
    "TableHasChangeDT": ""
  },
  {
    "db": "eSch",
    "name": "SPITB_SEARCH_FAV_CATEGORY",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,RESERVED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSP_CFG",
    "PKColumns": "DISTRICT,BUILDING",
    "TableColumns": "DISTRICT,BUILDING,TEA_STU_SUMM,SUB_STU_SUMM,TEA_SENS_PLAN,SUB_SENS_PLAN,TEA_SENS_INT,SUB_SENS_INT,TEA_SENS_INT_COMM,SUB_SENS_INT_COMM,TEA_INT_MNT,SUB_INT_MNT,TEA_GOAL_VIEW,SUB_GOAL_VIEW,TEA_GOAL_MNT,SUB_GOAL_MNT,TEA_GOAL_ACCESS,SUB_GOAL_ACCESS,TEA_INT_ACCESS,SUB_INT_ACCESS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSP_CFG_AUX",
    "PKColumns": "DISTRICT,BUILDING",
    "TableColumns": "DISTRICT,BUILDING,TEA_PLAN_ENTRY,SUB_PLAN_ENTRY,TEA_PLAN_UPD,SUB_PLAN_UPD,TEA_PLAN_UPD_UNASGN,SUB_PLAN_UPD_UNASGN,TEA_PLAN_DEL,SUB_PLAN_DEL,TEA_PLAN_DEL_UNASGN,SUB_PLAN_DEL_UNASGN,TEA_PLAN_VIEW_UNASGN,SUB_PLAN_VIEW_UNASGN,TEA_INT_ENTRY,SUB_INT_ENTRY,TEA_INT_UPD,SUB_INT_UPD,TEA_INT_UPD_UNASGN,SUB_INT_UPD_UNASGN,TEA_INT_DEL,SUB_INT_DEL,TEA_INT_DEL_UNASGN,SUB_INT_DEL_UNASGN,TEA_INT_VIEW_UNASGN,SUB_INT_VIEW_UNASGN,TEA_INT_PROG_ENT_UNASGN,SUB_INT_PROG_ENT_UNASGN,TEA_INT_PROG_DEL,SUB_INT_PROG_DEL,TEA_INT_PROG_DEL_UNASGN,SUB_INT_PROG_DEL_UNASGN,TEA_GOAL_ENTRY,SUB_GOAL_ENTRY,TEA_GOAL_UPD,SUB_GOAL_UPD,TEA_GOAL_UPD_UNASGN,SUB_GOAL_UPD_UNASGN,TEA_GOAL_DEL,SUB_GOAL_DEL,TEA_GOAL_DEL_UNASGN,SUB_GOAL_DEL_UNASGN,TEA_GOAL_VIEW_UNASGN,SUB_GOAL_VIEW_UNASGN,TEA_GOAL_OBJ_ENT_UNASGN,SUB_GOAL_OBJ_ENT_UNASGN,TEA_GOAL_OBJ_DEL,SUB_GOAL_OBJ_DEL,TEA_GOAL_OBJ_DEL_UNASGN,SUB_GOAL_OBJ_DEL_UNASGN,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSP_CFG_PLAN_GOALS",
    "PKColumns": "DISTRICT,BUILDING,PLAN_TYPE,GOAL",
    "TableColumns": "DISTRICT,BUILDING,PLAN_TYPE,GOAL,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSP_CFG_PLAN_INTERVENTIONS",
    "PKColumns": "DISTRICT,BUILDING,PLAN_TYPE,INTERVENTION",
    "TableColumns": "DISTRICT,BUILDING,PLAN_TYPE,INTERVENTION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSP_CFG_PLAN_REASONS",
    "PKColumns": "DISTRICT,BUILDING,PLAN_TYPE,REASON_CODE",
    "TableColumns": "DISTRICT,BUILDING,PLAN_TYPE,REASON_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSP_CFG_PLAN_RESTRICTIONS",
    "PKColumns": "DISTRICT,BUILDING,PLAN_TYPE",
    "TableColumns": "DISTRICT,BUILDING,PLAN_TYPE,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSP_COORDINATOR",
    "PKColumns": "DISTRICT,BUILDING,REFER_SEQUENCE",
    "TableColumns": "DISTRICT,BUILDING,REFER_SEQUENCE,SSP_REFER_TAG,REFER_TO,REFER_SEQ_ORDER,LOGIN_ID,USE_FILTER,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSP_COORDINATOR_FILTER",
    "PKColumns": "DISTRICT,BUILDING,REFER_SEQUENCE,SEQUENCE_NUM",
    "TableColumns": "DISTRICT,BUILDING,REFER_SEQUENCE,SEQUENCE_NUM,AND_OR_FLAG,TABLE_NAME,COLUMN_NAME,OPERATOR,SEARCH_VALUE1,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSP_DISTRICT_CFG",
    "PKColumns": "DISTRICT",
    "TableColumns": "DISTRICT,USE_PERF_LEVEL,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSP_GD_SCALE_DET",
    "PKColumns": "DISTRICT,GRADING_SCALE_TYPE,DISPLAY_ORDER",
    "TableColumns": "DISTRICT,GRADING_SCALE_TYPE,DISPLAY_ORDER,MARK,DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSP_GD_SCALE_HDR",
    "PKColumns": "DISTRICT,GRADING_SCALE_TYPE",
    "TableColumns": "DISTRICT,GRADING_SCALE_TYPE,DESCRIPTION,DEFAULT_MARK,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSP_INTER_FREQ_DT",
    "PKColumns": "DISTRICT,INTERVENTION,INTER_DATE",
    "TableColumns": "DISTRICT,INTERVENTION,INTER_DATE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSP_INTER_MARKS",
    "PKColumns": "DISTRICT,INTERVENTION,MARK_TYPE",
    "TableColumns": "DISTRICT,INTERVENTION,MARK_TYPE,GRADE_SCALE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSP_INTERVENTION",
    "PKColumns": "DISTRICT,INTERVENTION",
    "TableColumns": "DISTRICT,INTERVENTION,DESCRIPTION,INTERVEN_TYPE,FREQUENCY,FREQ_WEEKDAY,STATE_COURSE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSP_MARK_TYPES",
    "PKColumns": "DISTRICT,MARK_TYPE",
    "TableColumns": "DISTRICT,MARK_TYPE,MARK_ORDER,DESCRIPTION,ACTIVE,DEFAULT_GRADE_SCALE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSP_PARENT_GOAL",
    "PKColumns": "DISTRICT,STUDENT_ID,PLAN_NUM,GOAL",
    "TableColumns": "DISTRICT,STUDENT_ID,PLAN_NUM,GOAL,COMPLETION_DATE,COMMENT,ENTERED_BY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSP_PARENT_OBJECTIVE",
    "PKColumns": "DISTRICT,STUDENT_ID,PLAN_NUM,GOAL,SEQUENCE_NUM,COMMENT_ORDER",
    "TableColumns": "DISTRICT,STUDENT_ID,PLAN_NUM,GOAL,OBJECTIVE,SEQUENCE_NUM,COMMENT,COMMENT_ORDER,COMPLETION_DATE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSP_PERF_LEVEL_DET",
    "PKColumns": "DISTRICT,PERF_CODE,LEVEL",
    "TableColumns": "DISTRICT,PERF_CODE,LEVEL,SUBLEVEL,GRADE,RANGE_START,RANGE_END,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSP_PERF_LEVEL_HDR",
    "PKColumns": "DISTRICT,PERF_CODE,TEST_CODE,TEST_LEVEL,TEST_FORM,SUBTEST,SCORE_CODE",
    "TableColumns": "DISTRICT,PERF_CODE,TEST_CODE,TEST_LEVEL,TEST_FORM,SUBTEST,SCORE_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSP_QUAL_DET",
    "PKColumns": "DISTRICT,QUALIFICATION,QUAL_REASON,QUAL_TYPE,SEQUENCE_NUM",
    "TableColumns": "DISTRICT,QUALIFICATION,QUAL_REASON,QUAL_TYPE,SEQUENCE_NUM,START_DATE,END_DATE,TEST_CODE,TEST_LEVEL,TEST_FORM,SUBTEST,GRADE,SCORE_CODE,CONDITION,QUAL_VALUE,AIS_QUALIFIER,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSP_QUAL_HDR",
    "PKColumns": "DISTRICT,QUALIFICATION,QUAL_REASON",
    "TableColumns": "DISTRICT,QUALIFICATION,DESCRIPTION,QUAL_REASON,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSP_QUAL_SEARCH",
    "PKColumns": "DISTRICT,QUALIFICATION,QUAL_REASON,SEQUENCE_NUM",
    "TableColumns": "DISTRICT,QUALIFICATION,QUAL_REASON,SEQUENCE_NUM,AND_OR_FLAG,TABLE_NAME,SCREEN_TYPE,SCREEN_NUMBER,PROGRAM_ID,COLUMN_NAME,FIELD_NUMBER,OPERATOR,SEARCH_VALUE1,SEARCH_VALUE2,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSP_RSN_TEMP_GOAL",
    "PKColumns": "DISTRICT,QUAL_REASON,GRADE,GOAL",
    "TableColumns": "DISTRICT,QUAL_REASON,GRADE,GOAL,COMMENT,GOAL_MANAGER,GOAL_LEVEL,GOAL_DETAIL,BASELINE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSP_RSN_TEMP_GOAL_OBJ",
    "PKColumns": "DISTRICT,QUAL_REASON,GRADE,GOAL,SEQUENCE_NUM",
    "TableColumns": "DISTRICT,QUAL_REASON,GRADE,GOAL,OBJECTIVE,SEQUENCE_NUM,COMMENT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSP_RSN_TEMP_HDR",
    "PKColumns": "DISTRICT,QUAL_REASON,GRADE",
    "TableColumns": "DISTRICT,QUAL_REASON,GRADE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSP_RSN_TEMP_INT",
    "PKColumns": "DISTRICT,QUAL_REASON,GRADE,INTERVENTION",
    "TableColumns": "DISTRICT,QUAL_REASON,GRADE,INTERVENTION,SENSITIVE_FLAG,LEVEL,ROLE_EVALUATOR,FREQUENCY,FREQ_WEEKDAY,STAFF_ID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSP_RSN_TEMP_PARENT_GOAL",
    "PKColumns": "DISTRICT,QUAL_REASON,GRADE,GOAL",
    "TableColumns": "DISTRICT,QUAL_REASON,GRADE,GOAL,COMMENT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSP_RSN_TEMP_PARENT_GOAL_OBJ",
    "PKColumns": "DISTRICT,QUAL_REASON,GRADE,GOAL,SEQUENCE_NUM",
    "TableColumns": "DISTRICT,QUAL_REASON,GRADE,GOAL,OBJECTIVE,SEQUENCE_NUM,COMMENT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSP_STU_AT_RISK",
    "PKColumns": "DISTRICT,STUDENT_ID,QUAL_REASON,START_DATE",
    "TableColumns": "DISTRICT,STUDENT_ID,QUAL_REASON,START_DATE,END_DATE,PLAN_NUM,PLAN_DATE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSP_STU_GOAL",
    "PKColumns": "DISTRICT,STUDENT_ID,PLAN_NUM,GOAL",
    "TableColumns": "DISTRICT,STUDENT_ID,PLAN_NUM,GOAL,COMPLETION_DATE,COMMENT,GOAL_LEVEL,GOAL_DETAIL,BASELINE,ENTERED_BY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSP_STU_GOAL_STAFF",
    "PKColumns": "DISTRICT,STUDENT_ID,PLAN_NUM,GOAL,STAFF_ID",
    "TableColumns": "DISTRICT,STUDENT_ID,PLAN_NUM,GOAL,STAFF_ID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSP_STU_GOAL_TEMP",
    "PKColumns": "",
    "TableColumns": "DISTRICT,STUDENT_ID,PLAN_NUM,GOAL,COMPLETION_DATE,COMMENT,GOAL_MANAGER,GOAL_LEVEL,GOAL_DETAIL,BASELINE,ENTERED_BY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSP_STU_GOAL_USER",
    "PKColumns": "DISTRICT,STUDENT_ID,PLAN_NUM,GOAL,FIELD_NUMBER",
    "TableColumns": "DISTRICT,STUDENT_ID,PLAN_NUM,GOAL,FIELD_NUMBER,FIELD_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSP_STU_INT",
    "PKColumns": "DISTRICT,STUDENT_ID,PLAN_NUM,INTERVENTION",
    "TableColumns": "DISTRICT,STUDENT_ID,PLAN_NUM,INTERVENTION,START_DATE,COMPLETION_DATE,SENSITIVE_FLAG,LEVEL,ROLE_EVALUATOR,FREQUENCY,FREQ_WEEKDAY,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSP_STU_INT_COMM",
    "PKColumns": "DISTRICT,STUDENT_ID,PLAN_NUM,INTERVENTION,COMMENT_TYPE,SEQUENCE_NUM,COMMENT_ORDER",
    "TableColumns": "DISTRICT,STUDENT_ID,PLAN_NUM,INTERVENTION,COMMENT_TYPE,SEQUENCE_NUM,COMMENT,COMMENT_ORDER,ENTRY_DATE,SENSITIVE_FLAG,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSP_STU_INT_FREQ_DT",
    "PKColumns": "DISTRICT,STUDENT_ID,PLAN_NUM,INTERVENTION,ENTRY_DATE",
    "TableColumns": "DISTRICT,STUDENT_ID,PLAN_NUM,INTERVENTION,ENTRY_DATE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSP_STU_INT_PROG",
    "PKColumns": "DISTRICT,STUDENT_ID,PLAN_NUM,INTERVENTION,ENTRY_DATE,MARK_TYPE",
    "TableColumns": "DISTRICT,STUDENT_ID,PLAN_NUM,INTERVENTION,ENTRY_DATE,MARK_TYPE,MARK_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSP_STU_INT_STAFF",
    "PKColumns": "DISTRICT,STUDENT_ID,PLAN_NUM,INTERVENTION,STAFF_ID",
    "TableColumns": "DISTRICT,STUDENT_ID,PLAN_NUM,INTERVENTION,STAFF_ID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSP_STU_INT_TEMP",
    "PKColumns": "",
    "TableColumns": "DISTRICT,STUDENT_ID,PLAN_NUM,INTERVENTION,START_DATE,COMPLETION_DATE,SENSITIVE_FLAG,LEVEL,ROLE_EVALUATOR,FREQUENCY,FREQ_WEEKDAY,STAFF_ID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSP_STU_OBJ_USER",
    "PKColumns": "DISTRICT,STUDENT_ID,PLAN_NUM,GOAL,SEQUENCE_NUMBER,FIELD_NUMBER",
    "TableColumns": "DISTRICT,STUDENT_ID,PLAN_NUM,GOAL,SEQUENCE_NUMBER,FIELD_NUMBER,FIELD_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSP_STU_OBJECTIVE",
    "PKColumns": "DISTRICT,STUDENT_ID,PLAN_NUM,GOAL,SEQUENCE_NUM,COMMENT_ORDER",
    "TableColumns": "DISTRICT,STUDENT_ID,PLAN_NUM,GOAL,OBJECTIVE,SEQUENCE_NUM,COMMENT,COMMENT_ORDER,COMPLETION_DATE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSP_STU_PLAN",
    "PKColumns": "DISTRICT,STUDENT_ID,PLAN_NUM",
    "TableColumns": "DISTRICT,STUDENT_ID,PLAN_NUM,PLAN_DATE,PLAN_TITLE,COMPLETION_DATE,STATUS,SENSITIVE_FLAG,PLAN_TYPE,PLAN_MANAGER,QUALIFICATIONS,COMPLETION_NOTES,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSP_STU_PLAN_USER",
    "PKColumns": "DISTRICT,STUDENT_ID,PLAN_NUM,FIELD_NUMBER",
    "TableColumns": "DISTRICT,STUDENT_ID,PLAN_NUM,FIELD_NUMBER,FIELD_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSP_USER_FIELDS",
    "PKColumns": "DISTRICT,PLAN_TYPE,SCREEN_TYPE,FIELD_NUMBER",
    "TableColumns": "DISTRICT,PLAN_TYPE,SCREEN_TYPE,FIELD_NUMBER,FIELD_LABEL,FIELD_ORDER,REQUIRED_FIELD,FIELD_TYPE,DATA_TYPE,NUMBER_TYPE,DATA_LENGTH,FIELD_SCALE,FIELD_PRECISION,DEFAULT_VALUE,DEFAULT_TABLE,DEFAULT_COLUMN,VALIDATION_LIST,VALIDATION_TABLE,CODE_COLUMN,DESCRIPTION_COLUMN,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSP_YEAREND_RUN",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,RUN_KEY",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,RUN_KEY,RUN_DATE,RUN_STATUS,RESTORE_KEY,CLEAN_SSP_DATA,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSPTB_AIS_LEVEL",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSPTB_AIS_TYPE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSPTB_GOAL",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,HAC_STUDENT,HAC_PARENT,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSPTB_GOAL_LEVEL",
    "PKColumns": "DISTRICT,LEVEL_CODE",
    "TableColumns": "DISTRICT,LEVEL_CODE,DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSPTB_OBJECTIVE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSPTB_PLAN_STATUS",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSPTB_PLAN_TYPE",
    "PKColumns": "DISTRICT,PLAN_TYPE",
    "TableColumns": "DISTRICT,PLAN_TYPE,DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "SSPTB_ROLE_EVAL",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "STATE_DISTDEF_SCREENS",
    "PKColumns": "DISTRICT,SCREEN_USED_FOR,SCREEN_TYPE,SCREEN_NUMBER",
    "TableColumns": "DISTRICT,SCREEN_USED_FOR,SCREEN_TYPE,SCREEN_NUMBER,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "STATE_DNLD_SUM_INFO",
    "PKColumns": "DISTRICT,STATE,DOWNLOAD_TYPE,TABLE_NAME",
    "TableColumns": "DISTRICT,STATE,DOWNLOAD_TYPE,TABLE_NAME,MULTI_RECORDS,DISPLAY_ORDER,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "STATE_DNLD_SUM_TABLES",
    "PKColumns": "DISTRICT,STATE,DOWNLOAD_TYPE,TABLE_NAME,SESSION_FIELD",
    "TableColumns": "DISTRICT,STATE,DOWNLOAD_TYPE,TABLE_NAME,SESSION_FIELD,DOWNLOAD_FIELD,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "STATE_DNLD_SUMMARY",
    "PKColumns": "DISTRICT,STATE,DOWNLOAD_TYPE",
    "TableColumns": "DISTRICT,STATE,DOWNLOAD_TYPE,ALLOW_EDITS,SEARCH_TYPE,SEC_SUBPACKAGE,SEC_RESOURCE,SYSTEM_NAME,SEARCH_PAGE,LIST_PAGE,YEAR_COLUMN,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "STATE_DOWNLOAD_AUDIT",
    "PKColumns": "DISTRICT,TABLE_NAME,KEYFIELD01,KEYFIELD02,KEYFIELD03,KEYFIELD04,KEYFIELD05,KEYFIELD06,KEYFIELD07,KEYFIELD08,KEYFIELD09,KEYFIELD10,FIELD_CHANGED,CHANGE_DATE_TIME",
    "TableColumns": "DISTRICT,TABLE_NAME,KEYFIELD01,KEYVALUE01,KEYFIELD02,KEYVALUE02,KEYFIELD03,KEYVALUE03,KEYFIELD04,KEYVALUE04,KEYFIELD05,KEYVALUE05,KEYFIELD06,KEYVALUE06,KEYFIELD07,KEYVALUE07,KEYFIELD08,KEYVALUE08,KEYFIELD09,KEYVALUE09,KEYFIELD10,KEYVALUE10,CHANGE_TYPE,FIELD_CHANGED,OLD_VALUE,NEW_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "STATE_DWNLD_COLUMN_NAME",
    "PKColumns": "DISTRICT,TABLE_NAME,COLUMN_NAME,SUBMISSION_PERIOD,FIRST_SCHOOL_YEAR",
    "TableColumns": "DISTRICT,TABLE_NAME,COLUMN_NAME,SUBMISSION_PERIOD,FIRST_SCHOOL_YEAR,COLUMN_DESCRIPTION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "STATE_OCR_BLDG_CFG",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,FEDERAL_CODE_EQUIV,UNGRADED_DETAIL,DISABILITY_SCHOOL,MAGNET_SCHOOL,MAGNET_ENTIRE_SCHOOL,CHARTER_SCHOOL,ALTERNATIVE_SCHOOL,ALT_ACADEMIC_STUDENTS,ALT_DISCIPLINE_STUDENTS,ALT_OTHER_STUDENTS,ALT_OTHER_COMMENTS,ABILITY_GROUPED_SCHOOL,AP_SELF_SELECT,CLASSROOM_TEACHER_FTE,LICENSED_TEACHER_FTE,FTE_TEACHERS_NOTMEETSTATEREQ,FIRST_YEAR_TEACHER_FTE,SECOND_YEAR_TEACHER_FTE,COUNSELOR_FTE,BUILDING_COMMENTS,DUAL_ENROLL,INTERSCH_ATHLETICS,INTERSCH_SPORTS_MALE,INTERSCH_SPORTS_FEMALE,INTERSCH_TEAMS_MALE,INTERSCH_TEAMS_FEMALE,INTERSCH_PARTIC_MALE,INTERSCH_PARTIC_FEMALE,HS_AGE_IN_UNGRADED,ABSENT_TEN_DAY_FTE,TOTAL_PERS_SALARY,TOTAL_PERS_SALARY_FED_ST_LOC,INSTR_PERS_SALARY,NON_PERS_EXP,NON_PERS_EXP_FED_ST_LOC,TEACH_PERS_SALARY,TEACHER_SALARY_FED_ST_LOC,TEACHER_SALARY_FTE,BUILDING_COMMENTS2,OTHER_BUILDING_LIST,JUSTICE_FACILITY,JUSTFAC_NUM_DAYS,JUSTFAC_HOURS_PERWEEK,JUSTFAC_EDUPROG_LESS15,JUSTFAC_EDUPROG_15TO30,JUSTFAC_EDUPROG_31TO90,JUSTFAC_EDUPROG_91TO180,JUSTFAC_EDUPROG_MORE180,PRES_AGE3,PRES_AGE4,PRES_AGE5,PRES_ONLY_IDEA,CREDIT_RECOV,CREDIT_RECOV_STUDENTS,LAW_ENFORCE_OFF,HOMICIDE_DEATHS,FIREARM_USE,FTE_PSYCHOLOGISTS,FTE_SOCIAL_WORKERS,FTE_NURSES,FTE_SECURITY_GUARDS,FTE_LAW_ENFORCEMENT,FTE_INSTRUCTIONAL_AIDES_ST_LOC,INST_AIDE_PERS_SALARY_ST_LOC,FTE_SUPPORT_STAFF_ST_LOC,SUPP_STAFF_PERS_SALARY_ST_LOC,FTE_SCHOOL_ADMIN_ST_LOC,SCHOOL_ADMIN_PERS_SALARY_ST_LOC,FTE_INSTRUCTIONAL_AIDES_FED_ST_LOC,INST_AIDE_PERS_SALARY_FED_ST_LOC,FTE_SUPPORT_STAFF_FED_ST_LOC,SUPP_STAFF_PERS_SALARY_FED_ST_LOC,FTE_SCHOOL_ADMIN_FED_ST_LOC,SCHOOL_ADMIN_PERS_SALARY_FED_ST_LOC,CUR_YEAR_TEACHERS,PRIOR_YEAR_TEACHERS,RETAINED_USE_FED_OR_LOC_GRADE_CODE,INTERNET_FIBER,INTERNET_WIFI,INTERNET_SCHOOL_ISSUED_DEVICE,INTERNET_STUDENT_OWNED_DEVICE,INTERNET_WIFI_ENABLED_DEVICES,CHANGE_DATE_TIME,CHANGE_UID,DIND_INSTRUCTION_TYPE,DIND_VIRTUAL_TYPE,FULLY_VIRTUAL,REMOTE_INSTRUCTION_AMOUNT,REMOTE_INSTRUCTION_PERCENT,INTERSCH_SPORTS_ALL,INTERSCH_TEAMS_ALL,INTERSCH_PARTIC_NONBINARY,FTE_MATH_TEACHERS,FTE_SCIENCE_TEACHERS,FTE_EL_TEACHERS,FTE_SPECIAL_ED_TEACHERS,TEACHERS_RETAINED,INTERNET_WIFI_ENABLED_DEVICES_NEEDED,INTERNET_WIFI_HOTSPOTS_NEEDED,INTERNET_WIFI_ENABLED_DEVICES_RECEIVED,INTERNET_WIFI_HOTSPOTS_RECEIVED",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "STATE_OCR_BLDG_MARK_TYPE",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,MARK_TYPE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,MARK_TYPE,MARK_ORDER,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "STATE_OCR_BLDG_RET_EXCLUDED_CALENDAR",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,CALENDAR",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,CALENDAR,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "STATE_OCR_DETAIL",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,OCR_PART,STUDENT_ID,RECORD_TYPE,BUILDING",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,OCR_PART,STUDENT_ID,RECORD_TYPE,BUILDING,FED_GRADE,FED_RACE,GENDER,DETAIL_RECORD_COUNT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "STATE_OCR_DIST_ATT",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,ATT_CODE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,ATT_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "STATE_OCR_DIST_CFG",
    "PKColumns": "DISTRICT,SCHOOL_YEAR",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,FEDERAL_CODE_EQUIV,ENROLL_DATE,IDEA_DATE,SEMESTER2_DATE,YEAR_START_DATE,YEAR_END_DATE,RACE_CATEGORY,GED_PREP,TOT_PUB_SCHOOLS,TOT_PUB_MEMBERSHIP,TOT_PUB_SERVED,TOT_PUB_WAITING,DESEGRAGATION_PLAN,KG_FULL,KG_FULL_FREE,KG_FULL_PARTORFULL,KG_PART,KG_PART_FREE,KG_PART_PARTORFULL,KG_NONE,KG_REQ_BY_STATUTE,PREK_FULL,PREK_FULL_FREE,PREK_FULL_PARTORFULL,PREK_PART,PREK_PART_FREE,PREK_PART_PARTORFULL,PREK_NONE,PREK_FOR_ALL,PREK_FOR_IDEA,PREK_FOR_TITLE1,PREK_FOR_LOWINCOME,PREK_FOR_OTHER,PREK_AGE_2,PREK_AGE_3,PREK_AGE_4,PREK_AGE_5,PREK_AGE_NONE,PREK_AGE_2_STU_COUNT,PREK_AGE_3_STU_COUNT,PREK_AGE_4_STU_COUNT,PREK_AGE_5_STU_COUNT,EARLY_CHILD_0_2,EARLY_CHILD_0_2_NON_IDEA,CIV_RIGHTS_COORD_GNDR_ID,CIV_RIGHTS_COORD_GNDR_PHONE,CIV_RIGHTS_COORD_GNDR_EXT,CIV_RIGHTS_COORD_RACE_ID,CIV_RIGHTS_COORD_RACE_PHONE,CIV_RIGHTS_COORD_RACE_EXT,CIV_RIGHTS_COORD_DIS_ID,CIV_RIGHTS_COORD_DIS_PHONE,CIV_RIGHTS_COORD_DIS_EXT,HAR_POL_NONE,HAR_POL_SEX,HAR_POL_DIS,HAR_POL_RACE,HAR_POL_ANY,HAR_POL_WEBLINK,CERTIFIED,CERT_NAME,CERT_TITLE,CERT_PHONE,CERT_DATE,CERT_AUTH,CERT_EMAIL,ATT_VIEW_TYPE,ENROLL_DIST_EDU_CRS,RETENTION_POLICY,NUM_STU_NON_LEA,STU_DISC_TRANSFER,CHANGE_DATE_TIME,CHANGE_UID,REPORT_NONBINARY_COUNTS,DETERMINE_STUDENT_GENDER,EARLY_CHILD,EARLY_CHILD_NON_IDEA,HAR_POL_SEX_WEBLINK,HAR_POL_GENDER,HAR_POL_GENDER_WEBLINK,HAR_POL_RELIGION,HAR_POL_RELIGION_WEBLINK",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "STATE_OCR_DIST_COM",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,COMMENT_TYPE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,COMMENT_TYPE,COMMENT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "STATE_OCR_DIST_DISC",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,DISC_CODE_ID,CODE_OR_SUBCODE,DISC_CODE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,DISC_CODE_ID,CODE_OR_SUBCODE,DISC_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "STATE_OCR_DIST_EXP",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,EXPENDITURE_ID",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,EXPENDITURE_ID,EXPENDITURE_INCL,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "STATE_OCR_DIST_LTDB_TEST",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,TEST_TYPE,AP_SUBJECT_CODE,TEST_CODE,TEST_LEVEL,TEST_FORM,SUBTEST,SCORE_CODE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,TEST_TYPE,AP_SUBJECT_CODE,TEST_CODE,TEST_LEVEL,TEST_FORM,SUBTEST,SCORE_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "STATE_OCR_DIST_STU_DISC_XFER",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,REG_OR_ALT,CODE_VALUE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,REG_OR_ALT,CODE_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "STATE_OCR_NON_STU_DET",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,COUNT_TYPE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,BUILDING,COUNT_TYPE,OCR_PART,COUNT_VALUE,OVERRIDE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "STATE_OCR_QUESTION",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,OCR_PART,FORM_TYPE,QUESTION_ID,RECORD_TYPE",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,OCR_PART,FORM_TYPE,QUESTION_ID,RECORD_TYPE,QUESTION_ORDER,DESCRIPTION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "STATE_OCR_SUMMARY",
    "PKColumns": "DISTRICT,SCHOOL_YEAR,OCR_PART,RECORD_TYPE,BUILDING,FED_RACE,GENDER,QUESTION_ID",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,OCR_PART,RECORD_TYPE,BUILDING,FED_RACE,GENDER,QUESTION_ID,COUNT,OVERRIDE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "STATE_TASK_LOG_CFG",
    "PKColumns": "DISTRICT,TASK_CODE",
    "TableColumns": "DISTRICT,TASK_CODE,TASK_NAME,KEYFIELD01,KEYFIELD02,KEYFIELD03,KEYFIELD04,KEYFIELD05,KEYFIELD06,KEYFIELD07,KEYFIELD08,KEYFIELD09,KEYFIELD10,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "STATE_TASK_LOG_DET",
    "PKColumns": "DISTRICT,PARAM_KEY,RUN_NUMBER,KEY_VALUE01,KEY_VALUE02,KEY_VALUE03,KEY_VALUE04,KEY_VALUE05,KEY_VALUE06,KEY_VALUE07,KEY_VALUE08,KEY_VALUE09,KEY_VALUE10,MESSAGE_INDEX",
    "TableColumns": "DISTRICT,PARAM_KEY,RUN_NUMBER,KEY_VALUE01,KEY_VALUE02,KEY_VALUE03,KEY_VALUE04,KEY_VALUE05,KEY_VALUE06,KEY_VALUE07,KEY_VALUE08,KEY_VALUE09,KEY_VALUE10,MESSAGE_INDEX,MESSAGE_TYPE,MESSAGE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "STATE_TASK_LOG_HDR",
    "PKColumns": "DISTRICT,PARAM_KEY,RUN_NUMBER",
    "TableColumns": "DISTRICT,PARAM_KEY,RUN_NUMBER,TASK_CODE,CUSTOM_TASK_NAME,USER_ID,START_TIME,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "STATE_VLD_GROUP",
    "PKColumns": "DISTRICT,GROUP_ID",
    "TableColumns": "DISTRICT,GROUP_ID,GROUP_DESC,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "STATE_VLD_GRP_MENU",
    "PKColumns": "DISTRICT,GROUP_ID,MENU_ID",
    "TableColumns": "DISTRICT,GROUP_ID,MENU_ID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "STATE_VLD_GRP_RULE",
    "PKColumns": "DISTRICT,GROUP_ID,RULE_ID",
    "TableColumns": "DISTRICT,GROUP_ID,RULE_ID,ERROR_MSG,ERROR_TYPE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "STATE_VLD_GRP_USER",
    "PKColumns": "DISTRICT,GROUP_ID,USER_ID",
    "TableColumns": "DISTRICT,GROUP_ID,USER_ID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "STATE_VLD_RESULTS",
    "PKColumns": "DISTRICT,RULE_ID,STUDENT_ID",
    "TableColumns": "DISTRICT,RULE_ID,STUDENT_ID,EXCLUDE,ERROR_MESSAGE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "STATE_VLD_RULE",
    "PKColumns": "DISTRICT,RULE_ID",
    "TableColumns": "DISTRICT,RULE_ID,RULE_DESCRIPTION,ERROR_MESSAGE,ERROR_TYPE,SQL_SCRIPT,STORED_PROC,RETURNS_STUDENT_ID,SQL_SCRIPT_ACTION,STORED_PROC_ACTION,ACTION_DESCRIPTION,EXPCTD_REC_CNT,NAVIGATE_TO,ERROR_PARAMS,RUN_ORDER,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "STATETB_AP_SUBJECT",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "STATETB_DEF_CLASS",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "STATETB_ENTRY_SOURCE",
    "PKColumns": "DISTRICT,TABLE_NAME,COLUMN_NAME",
    "TableColumns": "DISTRICT,TABLE_NAME,COLUMN_NAME,DESCRIPTION,SOURCE_PAGE,SOURCE_DESCRIPTION,FORMATTER,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "STATETB_OCR_COM_TYPE",
    "PKColumns": "DISTRICT,COMMENT_TYPE",
    "TableColumns": "DISTRICT,COMMENT_TYPE,DESCRIPTION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "STATETB_OCR_COUNT_TYPE",
    "PKColumns": "SECTION,ORDER_NUMBER,SEQUENCE,COUNT_TYPE",
    "TableColumns": "DISTRICT,SECTION,ORDER_NUMBER,SEQUENCE,COUNT_TYPE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "STATETB_OCR_DISC_TYPE",
    "PKColumns": "DISTRICT,DISC_CODE_ID",
    "TableColumns": "DISTRICT,DISC_CODE_ID,DESCRIPTION,INCIDENT_OR_ACTION,DISC_CODE_ORDER,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "STATETB_OCR_EXP_TYPE",
    "PKColumns": "DISTRICT,EXPENDITURE_ID",
    "TableColumns": "DISTRICT,EXPENDITURE_ID,EXPENDITURE_ORDER,DESCRIPTION,EXPENDITURE_TYPE,ED_PREFERRED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "Statetb_Ocr_Record_types",
    "PKColumns": "district,record_type,school_year,ocr_part",
    "TableColumns": "district,record_type,school_year,ocr_part,description,change_date_time,change_uid",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "STATETB_RECORD_FIELDS",
    "PKColumns": "DISTRICT,RECORD_TYPE,FIELD_NAME",
    "TableColumns": "DISTRICT,RECORD_TYPE,FIELD_NAME,FIELD_ORDER,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "STATETB_RECORD_TYPES",
    "PKColumns": "DISTRICT,STATE,RECORD_TYPE,TABLE_NAME",
    "TableColumns": "DISTRICT,STATE,RECORD_TYPE,DESCRIPTION,TABLE_NAME,ACTIVE,STUDENTSEARCH,SORTORDER,SUBMISSIONS,DOWNLOAD_TYPES,DISTRICTSEARCH,COURSESEARCH,STAFFSEARCH,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "STATETB_RELIGION",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,ACTIVE,STATE_CODE_EQUIV,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "STATETB_STAFF_ROLE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "STATETB_SUBMISSION_COL",
    "PKColumns": "DISTRICT,STATE,COLUMN_NAME",
    "TableColumns": "DISTRICT,STATE,COLUMN_NAME,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "STATETB_SUBMISSIONS",
    "PKColumns": "DISTRICT,STATE,CODE",
    "TableColumns": "DISTRICT,STATE,CODE,DESCRIPTION,START_DATE,END_DATE,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "TAC_CFG",
    "PKColumns": "DISTRICT,BUILDING",
    "TableColumns": "DISTRICT,BUILDING,TEA_OVR_GB_AVG,SUB_OVR_GB_AVG,SHOW_ALL_TAB,DEFAULT_TAB_TYPE,DEFAULT_TAB,TEA_ISSUES,SUB_ISSUES,TEA_CONDUCT_REFER,SUB_CONDUCT_REFER,SET_ROLES_ON_REFER,SET_TYPE_ON_REFER,DEFAULT_ISSUE_TYPE,TEA_DISABLE_STD,TEA_DISABLE_RUBRIC,TEA_PUBLIC_RUBRIC,TEA_PERFORMANCEPLUS,SUB_PERFORMANCEPLUS,FREE_TEXT_OPTION,TEA_STU_ACCESS,SUB_STU_ACCESS,TEA_MEDALERTS,SUB_MEDALERTS,DISC_REFER,SSP_REFER,TEA_EFP_BP,SUB_EFP_BP,AUTO_PUBLISH_SCORES,TEACHER_EXTRA_CREDIT_CREATION,POINTS,POINTS_OVERRIDE,WEIGHT,WEIGHT_OVERRIDE,PUBLISH,PUBLISH_OVERRIDE,CHANGE_DATE_TIME,CHANGE_UID,TEA_UPD_PM_ASMT_SCORE",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "TAC_CFG_ABS_SCRN",
    "PKColumns": "DISTRICT,BUILDING",
    "TableColumns": "DISTRICT,BUILDING,TEA_SCREEN_ACCESS,TEA_PREV_MP_ACCESS,SUB_SCREEN_ACCESS,SUB_PREV_MP_ACCESS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "TAC_CFG_ABS_SCRN_CODES",
    "PKColumns": "DISTRICT,BUILDING,SEQUENCE,ABS_CODE",
    "TableColumns": "DISTRICT,BUILDING,SEQUENCE,ABS_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "TAC_CFG_ABS_SCRN_DET",
    "PKColumns": "DISTRICT,BUILDING,SEQUENCE",
    "TableColumns": "DISTRICT,BUILDING,SEQUENCE,UPPER_LABEL,LOWER_LABEL,TOTAL_TYPE,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "TAC_CFG_ATTACH",
    "PKColumns": "DISTRICT,BUILDING",
    "TableColumns": "DISTRICT,BUILDING,TEA_STU_ATTACH,TEA_STU_ATTACH_CAT_ALL,SUB_STU_ATTACH,SUB_STU_ATTACH_CAT_ALL,TEA_OTHER_ATTACH,TEA_OTHER_ATTACH_CAT_ALL,SUB_OTHER_ATTACH,SUB_OTHER_ATTACH_CAT_ALL,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "TAC_CFG_ATTACH_CATEGORIES",
    "PKColumns": "DISTRICT,BUILDING,CATEGORY_TYPE,CATEGORY_CODE",
    "TableColumns": "DISTRICT,BUILDING,CATEGORY_TYPE,CATEGORY_CODE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "TAC_CFG_HAC",
    "PKColumns": "DISTRICT,BUILDING",
    "TableColumns": "DISTRICT,BUILDING,USE_TEA_NEWS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "TAC_DISTRICT_CFG",
    "PKColumns": "DISTRICT",
    "TableColumns": "DISTRICT,ALLOW_EMAIL_ATTACH,MAX_ATTACH_SIZE,ATT_FILE_TYPES,FROM_ADDR_TYPE,FROM_ADDRESS,FROM_NAME,ALLOW_REPLY,USE_DEFAULT_MSG,DO_NOT_REPLY_MSG,CRN_FROM_TAC,PRIVACY_STATEMENT,SHOW_USERVOICE,ALLOW_TEACHER_STUDENT_ACCESS,ALLOW_SUBSTITUTE_STUDENT_ACCESS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "TAC_ISSUE",
    "PKColumns": "DISTRICT,ISSUE_ID",
    "TableColumns": "DISTRICT,SCHOOL_YEAR,SUMMER_SCHOOL,BUILDING,STAFF_ID,ISSUE_ID,ISSUE_CODE,ISSUE_DATE,ISSUE_TIME,LOCATION,ISSUE_STATUS,ISSUE_SOURCE,ISSUE_SOURCE_DETAIL,COURSE_SESSION,ISSUE_RESOLVED,COMMENTS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "TAC_ISSUE_ACTION",
    "PKColumns": "DISTRICT,ISSUE_ID,ENTERED_DATE,ENTERED_SEQUENCE",
    "TableColumns": "DISTRICT,ISSUE_ID,ENTERED_DATE,ENTERED_SEQUENCE,ACTION_CODE,START_DATE,END_DATE,START_TIME,END_TIME,ACTION_COMPLETED,PARENTS_CONTACTED,COMMENTS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "TAC_ISSUE_REFER",
    "PKColumns": "DISTRICT,ISSUE_ID,REFER_DATE,REFER_SEQUENCE",
    "TableColumns": "DISTRICT,ISSUE_ID,REFER_DATE,REFER_SEQUENCE,REFER_STATUS,REFER_STAFF_ID,DISC_INCIDENT_ID,COMMENTS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "TAC_ISSUE_REFER_SSP",
    "PKColumns": "DISTRICT,ISSUE_ID,REFER_DATE,REFER_SEQUENCE",
    "TableColumns": "DISTRICT,ISSUE_ID,REFER_DATE,REFER_SEQUENCE,REFER_STATUS,REFER_TO,REFER_COORDINATOR,SSP_PLAN_NUM,SSP_QUAL_REASON,SSP_QUAL_REASON_START,COMMENTS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "TAC_ISSUE_RELATED",
    "PKColumns": "DISTRICT,ISSUE_ID,RELATED_ISSUE_ID",
    "TableColumns": "DISTRICT,ISSUE_ID,RELATED_ISSUE_ID,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "TAC_ISSUE_STUDENT",
    "PKColumns": "DISTRICT,ISSUE_ID,STUDENT_ID",
    "TableColumns": "DISTRICT,ISSUE_ID,STUDENT_ID,STUDENT_ROLE,ADMIN_ROLE,COMMENTS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "TAC_LINK",
    "PKColumns": "DISTRICT,BUILDING,TAC_PAGE,SORT_ORDER",
    "TableColumns": "DISTRICT,BUILDING,TAC_PAGE,SORT_ORDER,LINK_URL,LINK_DESCRIPTION,LINK_COLOR,NEW_UNTIL,POP_UP,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "TAC_LINK_MACRO",
    "PKColumns": "DISTRICT,BUILDING,MACRO_NAME",
    "TableColumns": "DISTRICT,BUILDING,MACRO_NAME,MACRO_VALUE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "TAC_LUNCH_COUNTS",
    "PKColumns": "DISTRICT,BUILDING,LUNCH_TYPE,STAFF_ID,LUNCH_DATE",
    "TableColumns": "DISTRICT,BUILDING,LUNCH_TYPE,STAFF_ID,TEACHER,LUNCH_DATE,LUNCH_COUNT,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "TAC_LUNCH_TYPES",
    "PKColumns": "DISTRICT,BUILDING,LUNCH_TYPE",
    "TableColumns": "DISTRICT,BUILDING,LUNCH_TYPE,DESCRIPTION,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "TAC_MENU_ITEMS",
    "PKColumns": "DISTRICT,PARENT_MENU_ID,SEQUENCE",
    "TableColumns": "DISTRICT,PARENT_MENU_ID,SEQUENCE,MENU_ID,TITLE,CONTROLLER,ACTION,AREA,RESERVED,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "TAC_MESSAGES",
    "PKColumns": "DISTRICT,STAFF_ID,MSG_DATE,MSG_SEQUENCE",
    "TableColumns": "DISTRICT,STAFF_ID,MSG_DATE,MSG_SEQUENCE,BUILDING,MSG_TYPE,MESSAGE_BODY,STUDENT_ID,SECTION_KEY,COURSE_SESSION,SCHD_RESOLVED,MESSAGE_DATE1,MESSAGE_DATE2,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "TAC_MS_SCHD",
    "PKColumns": "DISTRICT,BUILDING,PARAM_KEY,MS_TYPE",
    "TableColumns": "DISTRICT,BUILDING,PARAM_KEY,MS_TYPE,START_TIME,SUNDAY,MONDAY,TUESDAY,WEDNESDAY,THURSDAY,FRIDAY,SATURDAY,MS_PARAMETERS,EMAIL_TEACHERS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "TAC_MSG_CRS_DATES",
    "PKColumns": "DISTRICT,STUDENT_ID,SECTION_KEY,MODELED,DATE_RANGE_KEY",
    "TableColumns": "DISTRICT,STUDENT_ID,SECTION_KEY,MODELED,DATE_RANGE_KEY,DATE_ADDED,DATE_DROPPED,RESOLVED_CONFLICT,CHANGE_DATE_TIME",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "TAC_PRINT_RC",
    "PKColumns": "DISTRICT,LAUNCHER_ID,TAC_NAME",
    "TableColumns": "DISTRICT,LAUNCHER_ID,TAC_NAME,APP_TITLE,PROJECT_NUM,RC_NAME,REPORT_PATH,LOG_PATH,PRINTOFFICECOPY,SCSPI_ALTLANG,GENERAL_A,GENERAL_B,GENERAL_C,GENERAL_D,GENERAL_E,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "TAC_SEAT_CRS_DET",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,STUDENT_ID",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,STUDENT_ID,HORIZONTAL_POS,VERTICAL_POS,GRID_ROW_LOCATION,GRID_COL_LOCATION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "TAC_SEAT_CRS_HDR",
    "PKColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION",
    "TableColumns": "DISTRICT,SECTION_KEY,COURSE_SESSION,LAYOUT_TYPE,NUM_GRID_COLS,NUM_GRID_ROWS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "TAC_SEAT_HRM_DET",
    "PKColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,SUMMER_SCHOOL,HOMEROOM_TYPE,HOMEROOM,STUDENT_ID",
    "TableColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,SUMMER_SCHOOL,HOMEROOM_TYPE,HOMEROOM,STUDENT_ID,HORIZONTAL_POS,VERTICAL_POS,GRID_ROW_LOCATION,GRID_COL_LOCATION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "TAC_SEAT_HRM_HDR",
    "PKColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,SUMMER_SCHOOL,HOMEROOM_TYPE,HOMEROOM",
    "TableColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,SUMMER_SCHOOL,HOMEROOM_TYPE,HOMEROOM,LAYOUT_TYPE,NUM_GRID_COLS,NUM_GRID_ROWS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "TAC_SEAT_PER_DET",
    "PKColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,SUMMER_SCHOOL,PERIOD_LIST,STUDENT_ID",
    "TableColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,SUMMER_SCHOOL,PERIOD_LIST,STUDENT_ID,HORIZONTAL_POS,VERTICAL_POS,GRID_ROW_LOCATION,GRID_COL_LOCATION,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "TAC_SEAT_PER_HDR",
    "PKColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,SUMMER_SCHOOL,PERIOD_LIST",
    "TableColumns": "DISTRICT,BUILDING,SCHOOL_YEAR,SUMMER_SCHOOL,PERIOD_LIST,LAYOUT_TYPE,NUM_GRID_COLS,NUM_GRID_ROWS,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "TACTB_ISSUE",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,USE_IN_CLASS,USE_IN_REFER,DISC_REFER,SSP_REFER,SSP_REFER_TAG,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "TACTB_ISSUE_ACTION",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "TACTB_ISSUE_LOCATION",
    "PKColumns": "DISTRICT,CODE",
    "TableColumns": "DISTRICT,CODE,DESCRIPTION,DISC_CODE,STATE_CODE_EQUIV,ACTIVE,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "tmp_medtb_vis_exam_ark",
    "PKColumns": "",
    "TableColumns": "DISTRICT,FOLLOWUP_CODE,CONFIRMED_NORMAL,CHANGE_DATE_TIME,CHANGE_UID",
    "TableHasChangeDT": "y"
  },
  {
    "db": "eSch",
    "name": "WSSecAuthenticationLogTbl",
    "PKColumns": "WSSecAuthenticationLogID",
    "TableColumns": "WSSecAuthenticationLogID,WSSecApplicationID,WSSecCustomerID,NOnce,CreatedDate,ExpiresDate,AuthenticInd,FailedDesc",
    "TableHasChangeDT": ""
  }
]
'@

    if ($All) {
        return $dbDefinitions
    } elseif ($eFinance) {
        $database = $dbDefinitions | ConvertFrom-Json | Where-Object -Property db -EQ 'eFin'
    } else {
        $database = $dbDefinitions | ConvertFrom-Json | Where-Object -Property db -EQ 'eSch'
    }

    if ($Table) {
        $tblDefinition = $database | Where-Object -Property name -EQ "$Table"
        
        if ($PKColumns) {
            if ($AsString) {
                return $tblDefinition.PKColumns
            } else {
                # return an array of primary key columns. This could potentially be null.
                return ($tblDefinition.PKColumns).Split(',')
            }
        } elseif ($TableColumns) {
            if ($AsString) {
                return $tblDefinition.TableColumns
            } else {
                # return an array of columns.
                return ($tblDefinition.TableColumns).Split(',')
            }
        } else {
            # return the table definition.
            return $tblDefinition
        }
    } else {
        #return entire database for eFinance or eSchool.
        return $database
    }

}