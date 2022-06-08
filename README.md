# CognosModule
These scripts come without warranty of any kind. Use them at your own risk. I assume no liability for the accuracy, correctness, completeness, or usefulness of any information provided by this site nor for any sort of damages using these scripts may cause.

The Cognos Powershell Module requires PowerShell 7

## Installation Process
Open PowerShell Window as Administrator
````
mkdir "C:\Program Files\PowerShell\Modules\CognosModule"
Invoke-WebRequest -Uri https://github.com/carbm1/CognosModule/master/CognosModule.psd1 -OutFile "C:\Program Files\PowerShell\Modules\CognosModule/CognosModule.psd1"
Invoke-WebRequest -Uri https://github.com/carbm1/CognosModule/master/CognosModule.psm1 -OutFile "C:\Program Files\PowerShell\Modules\CognosModule/CognosModule.psm1"
````

## Intial Configuration
````
PS C:\Scripts> Set-CognosConfig -username 0403cmillsap -dsnname gentrysms -eFinanceUsername cmillsap
Please provide your Cognos Password: ********************
````
Provide a name for a specific configuration. Example: If you have multiple users with different privileges.
````
PS C:\Scripts> Set-CognosConfig -ConfigName "Judy" -username 0403judy -dsnname gentryfms -eFinanceUsername judy
Please provide your Cognos Password: ********************
````

## Cmdlets
- Set-CognosConfig
    > Configure the username, dsn, and password for the connection.
- Show-CognosConfig
    > Show available configurations.
- Remove-CognosConfig
    > Remove a configuration.
- Update-CognosPassword
    > Change the password in a saved configuration.
- Start-CognosBrowser
    > Super Awesome command line based Cognos Browser.
- Get-CognosReport
    > Return a Cognos Report as a data object.
- Save-CognosReport
    > Download a Cognos Report and save as CSV,XLSX, or PDF.
- Get-CogSchool
    > School Building Information
- Get-CogStudent
    > Student Demographic Information
- Get-CogStudentSchedule
    > Student Schedule Information
- Get-CogStuAttendance
    > Student Attendance Information

## Example
````
Connect-ToCognos

