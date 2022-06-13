# CognosModule
These scripts come without warranty of any kind. Use them at your own risk. I assume no liability for the accuracy, correctness, completeness, or usefulness of any information provided by this site nor for any sort of damages using these scripts may cause.

The Cognos Powershell Module requires PowerShell 7

## Tutorial
[![tutorial](/images/youtube_thumbnail.jpg)](https://youtu.be/rdVpaGocKTI)

## Installation Process
Open PowerShell Window as Administrator
````
mkdir "C:\Program Files\PowerShell\Modules\CognosModule"
Invoke-WebRequest -Uri https://raw.githubusercontent.com/carbm1/CognosModule/master/CognosModule.psd1 -OutFile "C:\Program Files\PowerShell\Modules\CognosModule\CognosModule.psd1"
Invoke-WebRequest -Uri https://raw.githubusercontent.com/carbm1/CognosModule/master/CognosModule.psm1 -OutFile "C:\Program Files\PowerShell\Modules\CognosModule\CognosModule.psm1"
````

## Initial Configuration
````
PS C:\Scripts> Set-CognosConfig -username 0403cmillsap -dsnname gentrysms -eFinanceUsername cmillsap
Please provide your Cognos Password: ********************
````
Provide a name for a specific configuration. Example: If you have multiple users with different privileges.
````
PS C:\Scripts> Set-CognosConfig -ConfigName "Judy" -username 0403judy -dsnname gentryfms -eFinanceUsername judy
Please provide your Cognos Password: ********************
````

# Cmdlets

### Configure a profile for the username, dsn, and password for the connection.
````
Set-CognosConfig [[-ConfigName] <String>] [-username] <String> [[-eFinanceUsername] <String>] [-dsnname] <String>
````

### Show available configurations.
```
Show-CognosConfig
````

### Remove a configuration.
````
Remove-CognosConfig [-ConfigName] <String>
````

### Change the password in a saved configuration.
````
Update-CognosPassword [[-ConfigName] <String>]
````

### Super Awesome command line based Cognos Browser.
````
Start-CognosBrowser
````
    
### Return a Cognos Report as a data object.
````
Get-CognosReport [-report] <String> [[-cognosfolder] <String>] [[-reportparams] <String>] [[-XMLParameters] <String>] [-SavePrompts] [[-Timeout] <Int32>] [-Raw] [-TeamContent]
````

### Download a Cognos Report and save as CSV,XLSX, or PDF.
````
Save-CognosReport -report <String> [[-extension] <String>] [-filename <String>] [-savepath <String>] [-cognosfolder <String>] [-reportparams <String>] [-XMLParameters <String>] [-SavePrompts] [-Timeout <Int32>] [-TeamContent] [-TrimCSVWhiteSpace] [-CSVUseQuotes] [-RandomTempFile]
````

### School Building Information
````
Get-CogSchool [[-Building] <Object>]
````

### Student Demographic Information
````
Get-CogStudent [-id <Object>] [-Building <Object>] [-Grade <Object>] [-FirstName <Object>] [-LastName <Object>] [-EntryAfter <DateTime>]
Get-CogStudent [-All]
````

### Student Schedule Information
````
Get-CogStuSchedule [[-id] <Object>] [[-Grade] <Object>] [[-Building] <Object>]
````

### Student Attendance Information
````
Get-CogStuAttendance [[-id] <Object>] [[-Building] <Object>] [[-AttendanceCode] <Object>] [[-ExcludePeriodsByName] <Object>] [[-date] <DateTime>] [[-dateafter] <String>] [-All]
````

# Examples
````
PS C:\Users\craig> Connect-ToCognos
Authenticating and switching to gentrysms... Success.
PS C:\Users\craig> $advisors = Get-CognosReport -report "advisors"
PS C:\Users\craig> $advisors | Select-Object -First 5 | Format-Table

Current Building Student Id Advisor
---------------- ---------- -------
17               403004590  1063
17               403004604  2225
17               403004635  2356
17               403004638  2311
17               403004650  2309

PS C:\Users\craig> Save-CognosReport -report "advisors"
Info: Saving to C:\Users\craig\advisors.csv

PS C:\Users\craig> Save-CognosReport -report "advisors" -savepath c:\scripts
Info: Saving to c:\scripts\advisors.csv

PS C:\Users\craig> Import-Csv C:\Scripts\advisors.csv | Select-Object -First 5 | Format-Table

Current Building Student Id Advisor
---------------- ---------- -------
17               403004590  1063
17               403004604  2225
17               403004635  2356
17               403004638  2311
17               403004650  2309

PS C:\Users\craig> Get-CognosReport -report schools -cognosfolder "_Shared Data File Reports\Clever Files" -TeamContent | Measure-Object

Count             : 4
Average           :
Sum               :
Maximum           :
Minimum           :
StandardDeviation :
Property          :

PS C:\Users\craig> Save-CognosReport -report schools -cognosfolder "_Shared Data File Reports\Clever Files" -TeamContent -savepath "c:\scripts"
````

## eFinance Context
````
PS C:\Users\craig> Connect-ToCognos -eFinance -ConfigName "GentryeFinance"
Authenticating and switching to gentryfms... Success.

PS C:\Users\craig> Get-CognosReport -report "Open PO List" -cognosfolder "District Shared\Gentry" -TeamContent | Where-Object { $PSItem.VENDOR -LIKE "2414*" } | Select-Object -Property 'VENDOR','NAME','PAYMENTS' -First 5 | Format-Table

VENDOR NAME                                PAYMENTS
------ ----                                --------
2414   CDW GOVERNMENT INC                  1218.54
2414   CDW GOVERNMENT INC                  1061.05
2414   CDW GOVERNMENT INC                  1061.06
2414   CDW GOVERNMENT INC                  1061.06
2414   CDW GOVERNMENT INC                  0

PS C:\Users\craig> Save-CognosReport -report "Open PO List" -cognosfolder "District Shared\Gentry" -TeamContent
Info: Saving to C:\Users\craig\Open PO List.csv
````