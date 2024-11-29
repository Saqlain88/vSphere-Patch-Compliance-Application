#$ScriptPath = $MyInvocation.MyCommand.Path
#$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

$EXEName = "vSphere_Patch_Compliance_Tool"
if ($MyInvocation.MyCommand.Path) {
    $ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
}
else {
    $Process = $ScriptPath = $null; $ToFind = $True
    1..20 | ForEach-Object {
        if ($ToFind) {
            $EXENameUpper = $EXEName.ToUpper()
            $Process = Get-Process | Where-Object { $_.Name.ToUpper() -match $EXENameUpper }
            if (($Process -eq $null) -or ($Process.Path -eq $null)) {
                Start-Sleep 1
            }
            else {
                $ScriptPath = Split-Path -Parent $Process.Path
                $ToFind = $False
            }
        }
    }
}

Get-ChildItem -Path $ScriptPath -Recurse | Unblock-File

Write-Host "Please wait! required modules are being imported." -ForegroundColor Green -BackgroundColor Black

Import-Module "$ScriptPath\lib\Pode" -ErrorAction Stop
Import-Module "$ScriptPath\lib\Pode.Web" -ErrorAction Stop
Import-Module "$ScriptPath\lib\ImportExcel" -ErrorAction Stop
Import-Module "$scriptPath\lib\ReportHTML" -ErrorAction Stop

<# 
    ..........
    ... Configuring paths
    ..........
#>
$ConfigPath = "$ScriptPath\config"
$LogPath = "$ScriptPath\logs"
$OldReportPath = "$ConfigPath\Old Report"

<# 
    ..........
    ... Clearing old logs
    ..........
#>
Get-ChildItem $LogPath -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.CreationTime -lt (Get-Date).AddDays(-15) } | Remove-Item -Force -Confirm:$false -ErrorAction SilentlyContinue

<# 
    ..........
    ... Gather vcenter, host, and hardware
    ..........
#>

#Read all files from config
$all = Get-ChildItem -Path "$ConfigPath\Report Consolidation" -ErrorAction Stop
$hostfiles = $all | Where-Object { $_.Name -match "all_hosts" }
$hardwarefiles = $all | Where-Object { $_.Name -match "all_hardwares" }
$vcenterfiles = $all | Where-Object { $_.Name -match "all_vcenters" }
$all_host = @()
$all_hardware = @()
$all_vcenter = @()

foreach ($ht in $hostfiles) {
    $all_host += Import-CSv -Path "$ConfigPath\Report Consolidation\$($ht.Name)" -ErrorAction Stop
}

foreach ($hw in $hardwarefiles) {
    $all_hardware += Import-CSv -Path "$ConfigPath\Report Consolidation\$($hw.Name)" -ErrorAction Stop
}

foreach ($vc in $vcenterfiles) {
    $all_vcenter += Import-CSv -Path "$ConfigPath\Report Consolidation\$($vc.Name)" -ErrorAction Stop
}

#Append in main file
$all_host | Sort-Object Host -Unique | Export-Csv -Path "$ConfigPath\all_hosts.csv" -Append -NoTypeInformation -ErrorAction Stop
$all_hardware | Sort-Object Name -Unique | Export-Csv -Path "$ConfigPath\all_hardwares.csv" -Append -NoTypeInformation -ErrorAction Stop
$all_vcenter | Sort-Object Name -Unique  | Export-Csv -Path "$ConfigPath\all_vcenters.csv" -Append -NoTypeInformation -ErrorAction Stop

$all | Move-Item -Destination $OldReportPath -Force -ErrorAction Stop

<# 
    ..........
    ... Declaring global/env vars
    ..........
#>
Foreach ($i in $(Get-Content "$ConfigPath\main.conf")) {
    Set-Variable -Name $($i.split("=")[0]) -Value $i.split("=", 2)[1]
}

$env:VC_LATEST_VER = "$VC_LATEST_VER"
$env:VC_SUPPORTED_VER = $VC_SUPPORTED_VER
$env:ESXI_HOST_LATEST_VER = $ESXI_HOST_LATEST_VER
$env:ESXI_HOST_SUPPORTED_VER = $ESXI_HOST_SUPPORTED_VER
$env:VC_LEGACY = $VC_LEGACY
$env:ESXI_HOST_LEGACY = $ESXI_HOST_LEGACY

<# 
    ..........
    ... Declaring mandatory functions 
    ..........
#>

$config_path = Join-Path "$ScriptPath" "config"
$log_path = Join-Path "$ScriptPath" "report"

Function Check-VMHardwarePatchLevel {
    param(
        [Parameter(Mandatory = $true)]$ConfigPath,
        [Parameter(Mandatory = $true)]$ExportPath
    )
    $Error.Clear();
    $ErrorMessage = "";


    Try {
    
        $vc = @()

        $vc = Import-Csv -Path "$config_path\all_hardwares.csv" -ErrorAction Stop

        $LatestRelease = Import-Excel $ConfigPath -ErrorAction Stop
        $compliantLimit = @()

        foreach ($oneh in $vc) {
            
            $res = ""
                    
            $tmp_res = $LatestRelease | Where-Object { ($_.Model -eq ($oneh.'Model')) <#-and ($_.'CPU Series' -eq $oneh.'ProcessorType')#> } | Select-Object @{n = "Partner Name"; e = { $_.'Partner Name' } }, @{n = "Model"; e = { $_.'Model' } }, @{n = "CPU Series"; e = { $_.'CPU Series' } }, @{n = "Patch Level"; e = { @($_.'Patch Level 1', $_.'Patch Level 2', $_.'Patch Level 3', $_.'Patch Level 4') } } | Sort-Object -Property 'CPU Series'
           
            # capture 4 digit of the input
            # split the digits into 2 digits
            # now search in temporary result ($temp_res) for the first two digit from prev. step to find the target processor type family
            # additionally, there is a version check as well.
            # for example, v2, v3, v4 will be detected and searched with the same
            
            Try {
                $tokenize = ($oneh.ProcessorType).Replace("-", " ").Split(" ")
                $4_dgts = $tokenize | Where-Object { $_ -match "\d{4}" }
            }
            Catch {
                $4_dgts = $null
            }

            if ($null -ne $4_dgts) {
                $2_dgts = ($4_dgts[0] + $4_dgts[1] + "00")
                $processor_type_ver = $tokenize | Where-Object { $_ -match "v\d" }
                $res = $tmp_res | Where-Object { $_.'CPU Series' -match $2_dgts -and $_.'CPU Series' -match $processor_type_ver } | Select-Object -First 1
            }
            else {
                $res = $null
            }


            $pl = [string]($res."Patch Level")
            $pl = $pl.Replace("U1", " ")
            $pl = $pl.Replace("U2", " ")
            $pl = $pl.Replace("U3", " ")
            $pls = $pl.Split(", ")

            $current_version = ($oneh.'ESXi Version').split(".")[0]
            $search_ver_query = [double]($current_version[0] + "." + $current_version[1])

            if ($null -ne $res) {
                $med = [PSCustomObject]@{
                    Name                 = $oneh.Name
                    'Manufacturer'       = $oneh.'Manufacturer'
                    'Host_Model'         = $oneh.'Model'
                    'ProcessorType'      = $oneh.'ProcessorType'
                    'Partner Name'       = [string]$res.'Partner Name'
                    'Model'              = [string]$res.'Model'
                    'CPU Series'         = [string]$res.'CPU Series'
                    'Target Patch Level' = [string](($res."Patch Level") -join ", ")
                    'Compliance_status'  = if ([double]$env:ESXI_HOST_LATEST_VER -in $pls) {
                        foreach ($ver_in_list in $pls) {
                            if ([double]$ver_in_list -ge $search_ver_query) {
                                "Compliant"
                                Break
                            }
                        }
                    }
                    else {
                        "Non-Compliant"
                    }
                }
            }
            else {
                $med = [PSCustomObject]@{
                    Name                 = $oneh.Name
                    'Manufacturer'       = $oneh.'Manufacturer'
                    'Host_Model'         = $oneh.'Model'
                    'ProcessorType'      = $oneh.'ProcessorType'
                    'Partner Name'       = [string]$res.'Partner Name'
                    'Model'              = [string]$res.'Model'
                    'CPU Series'         = [string]$res.'CPU Series'
                    'Target Patch Level' = [string](($res."Patch Level") -join ", ")
                    'Compliance_status'  = "The device model is not available in hardware compatibility list."
                }
            }

            $compliantLimit += $med;
        
        }

        $compliantLimit | Export-Csv -Path $ExportPath -NoTypeInformation -ErrorAction Stop;

    }
    Catch {
        $ErrorMessage = $Error[0].Exception.Message;
        Write-PodeHost $ErrorMessage
    }
    if ($ErrorMessage -ne '') {
        return $ErrorMessage;
    }
    else {
        return $compliantLimit; 
    }
}

$ConfigPath = "$config_path\Input\VMWare_Hardware_compatibility.xlsx"
$ExportPath = "$log_path\VMHardware_Patch_Level_Check.csv"
Check-VMHardwarePatchLevel -ConfigPath "$ConfigPath" -ExportPath "$ExportPath" -ErrorAction Stop | Out-NUll

Function Check-HostVersion{
    param(
        [Parameter(Mandatory = $true)]$ConfigPath,
        [Parameter(Mandatory = $true)]$ExportPath
    )
    $Error.Clear();
    $ErrorMessage = "";

    Try {
        $hosts = Import-Csv -Path "$config_path\all_hosts.csv" -ErrorAction Stop #Get-VMHost -ErrorAction SilentlyContinue | Select @{Label = "Host"; Expression = {$_.Name}} , @{Label = "ESX Version"; Expression = {$_.version}}, @{Label = "ESX Build" ; Expression = {$_.build}}

        $LatestRelease = Import-Excel "$ConfigPath" -ErrorAction Stop
                    
        $compliantLimit = @()

        foreach ($oneh in $hosts) {
        
            $res = ""
            $current_version = ($oneh.'ESX Version').split(".")
            $search_ver_query = $current_version[0] + "." + $current_version[1]
            
            $extra_target = @()
            $supported_target = $null
            $latest_target = $null

            if ([double]$search_ver_query -lt [double]$env:ESXI_HOST_SUPPORTED_VER) {
                # get supported
                $supported_target = $LatestRelease |`
                    Where-Object { ($_.Version -like "*$env:ESXI_HOST_SUPPORTED_VER*") -and ($_.'Patch Level' -eq 'N') } |`
                Select-Object @{n = "Target Release Name"; e = { $_.'Release Name' } }, @{n = "Target Build"; e = { $_.'Build Number' } }, @{n = "Target Verion"; e = { $_.'Version' } } , @{n = "Target Patch Level"; e = { $_.'Patch Level' } }, 'Available as'

                $extra_target += $supported_target
            }
            
            if ([double]$search_ver_query -ne [double]$env:ESXI_HOST_LATEST_VER) {
                # get latest 
                $latest_target = $LatestRelease |`
                    Where-Object { ($_.Version -like "*$env:ESXI_HOST_LATEST_VER*") -and ($_.'Patch Level' -eq 'N') } |`
                Select-Object @{n = "Target Release Name"; e = { $_.'Release Name' } }, @{n = "Target Build"; e = { $_.'Build Number' } }, @{n = "Target Verion"; e = { $_.'Version' } } , @{n = "Target Patch Level"; e = { $_.'Patch Level' } }, 'Available as'

                $extra_target += $latest_target
            }

            #$res = $LatestRelease | ? { ($_.Version -match ($oneh.'ESX Version').Replace(".0", "")) -and ($_.'Build Number' -eq $oneh.'ESX Build') } 
            $res = $LatestRelease | Where-Object { ($_.Version -match $search_ver_query) -and ($_.'Build Number' -eq $oneh.'ESX Build') } 

            $TargetLevels = @($extra_target)
            #Write-PodeHost $(($LatestRelease | ? { ([System.Version]([regex]::Match($_.Version, '\d+(\.\d+)?').Value) -eq [System.Version]($search_ver_query+"0")) -and ($_.'Patch Level' -eq 'N')}).Version)
            $TargetLevels += $LatestRelease | `
             Where-Object { (($_.Version -match $search_ver_query) -and ($_.'Patch Level' -eq 'N')) } | `
             Select-Object @{n = "Target Release Name"; e = { $_.'Release Name' } }, @{n = "Target Build"; e = { $_.'Build Number' } }, @{n = "Target Verion"; e = { $_.'Version' } } , @{n = "Target Patch Level"; e = { $_.'Patch Level' } }, 'Available as'


            $med = [PSCustomObject]@{
                Host                     = $oneh.Host
                'ESXi Version'           = $oneh.'ESX Version'
                'ESXi Build'             = $oneh.'ESX Build'
                'Version'                = $res.'Version'
                'Release Name'           = $res.'Release Name'
                'Release Date'           = $res.'Release Date'
                'Build Number'           = $res.'Build Number'
                'Available as'           = $res.'Available as'
                'Installer Build Number' = $res.'Installer Build Number'
                'Current Patch Level'    = $res.'Patch Level'
                'Compliance_status'      = if ($(($res."Patch Level" -eq 'N') -or ($res."Patch Level" -eq 'N-1'))) { "Compliant" }else { "Non-Compliant" }
                'Target Available'       = if ($(($res."Patch Level" -ne 'N') -or ($res."Patch Level" -ne 'N-1'))) { 
                    if ($null -ne $supported_target -and $null -ne $latest_target) {
                        "1. $($TargetLevels[2].'Available as'); 2. $($TargetLevels[1].'Available as'); 3. $($TargetLevels[0].'Available as')" 
                    }
                    elseif ($null -ne $extra_target) {
                        "1. $($TargetLevels[1].'Available as'); 2. $($TargetLevels[0].'Available as')"
                    }
                    else {
                        "1. $($TargetLevels[0].'Available as')"
                    }
                }
                else { 
                    $null 
                }
                'Target'                 = if ($(($res."Patch Level" -ne 'N') -or ($res."Patch Level" -ne 'N-1'))) { 
                    if ($null -ne $supported_target -and $null -ne $latest_target) {
                        "1. $($TargetLevels[2].'Target Release Name'); 2. $($TargetLevels[1].'Target Release Name'); 3. $($TargetLevels[0].'Target Release Name')" 
                    }
                    elseif ($null -ne $extra_target) {
                        "1. $($TargetLevels[1].'Target Release Name'); 2. $($TargetLevels[0].'Target Release Name')"
                    }
                    else {
                        "1. $($TargetLevels[0].'Target Release Name')"
                    }
                }
                else {
                    $null
                }
                            
            }
            $compliantLimit += $med;
        }

        $compliantLimit | Export-Csv -Path "$ExportPath" -NoTypeInformation -ErrorAction Stop;
                    
    }
    Catch {
        $ErrorMessage = $Error[0].Exception.Message;
        Write-PodeHost $_
    }
    if ($ErrorMessage -ne '') {
        return $ErrorMessage;
    }
    else {
        return $compliantLimit;
    }
}

$ConfigPath = "$config_path\Input\ESXi Host-Patch-Level.xlsx"
$ExportPath = "$log_path\VMHost_Patch_Level_Check.csv"
Check-HostVersion -ConfigPath "$ConfigPath" -ExportPath "$ExportPath" -ErrorAction Stop | Out-NUll

Function Check-VcenterPatchLevel {
    param(
        [Parameter(Mandatory = $true)]$ConfigPath,
        [Parameter(Mandatory = $true)]$ExportPath
    )
    $Error.Clear();
    $ErrorMessage = "";


    Try {
    
        $vc = @()

        $vc = Import-Csv -Path "$config_path\all_vcenters.csv" -ErrorAction Stop 
        
        $LatestRelease = Import-Excel $ConfigPath -ErrorAction Stop
                
        #Top 2 versions Latest, Supported
        #$extra_target = $LatestRelease | ? { $_.'Targets' -in ('Latest', 'Supported') } | select @{n = "Target Release Name"; e = { $_.'Release name' } }, @{n = "Target Build"; e = { $_.'Client/MOB/vpxd.log' } }, @{n = "Target Patch Level"; e = { $_.'Patch Level' } }

        $compliantLimit = @()

        foreach ($oneh in $vc) {
            
            $res = ""
            $current_version = $oneh.'Version'.split(".")
            $search_ver_query = $current_version[0] + "." + $current_version[1]
            
            $extra_target = @()
            $supported_target = $null
            $latest_target = $null

            if ([double]$search_ver_query -lt [double]$env:VC_SUPPORTED_VER) {
                # get supported
                $supported_target = $LatestRelease |`
                    Where-Object { $_.'Release name' -match $env:VC_SUPPORTED_VER -and ($_.'Patch Level' -eq 'N') } |`
                    Select-Object @{n = "Target Release Name"; e = { $_.'Release name' } }, @{n = "Target Build"; e = { $_.'Client/MOB/vpxd.log' } }, @{n = "Target Patch Level"; e = { $_.'Patch Level' } }
                $extra_target += $supported_target 
            }
            
            if ([double]$search_ver_query -ne [double]$env:VC_LATEST_VER) {
                # get latest 
                $latest_target = $LatestRelease |`
                    Where-Object { $_.'Release name' -match $env:VC_LATEST_VER -and ($_.'Patch Level' -eq 'N') } |`
                    Select-Object @{n = "Target Release Name"; e = { $_.'Release name' } }, @{n = "Target Build"; e = { $_.'Client/MOB/vpxd.log' } }, @{n = "Target Patch Level"; e = { $_.'Patch Level' } }
                $extra_target += $latest_target
            }

            #$LatestRelease | ? { $_.'Targets' -in ('Latest', 'Supported') } | select @{n = "Target Release Name"; e = { $_.'Release name' } }, @{n = "Target Build"; e = { $_.'Client/MOB/vpxd.log' } }, @{n = "Target Patch Level"; e = { $_.'Patch Level' } }

            if ([double]($search_ver_query) -lt 6.7) {
                $res = $LatestRelease | Where-Object { ($_.'Release name' -match $search_ver_query) -and ($_.'VAMI/Release Notes' -eq $oneh.'Build') } 
            }
            else {
                $res = $LatestRelease | Where-Object { ($_.'Release name' -match $search_ver_query) -and ($_.'Client/MOB/vpxd.log' -eq $oneh.'Build') } 
            }

            $OsType = $oneh.OsType

            if ($OsType.startsWith("Win")) {
                $resType = "Windows"
            }
            else {
                $resType = "Appliance"
            }

            #$resType = if($res){ if (($res.'Release name').IndexOf("Appliance") -ne -1) { "Appliance" }else { "Windows" } } else{ $null }
                   
            $TargetLevels = @($extra_target)
                      
            if ($resType -eq "Appliance") {

                #$TargetLevels += $LatestRelease | ? { ($_.'Release name' -match $search_ver_query) -and ($_.'Release name' -match $resType) -and ($_.'Patch Level' -eq 'N' ) } | select @{n = "Target Release Name"; e = { $_.'Release name' } }, @{n = "Target Build"; e = { if($_.'Client/MOB/vpxd.log' -eq $null){$_.'VAMI/Release Notes'}else{$_.'Client/MOB/vpxd.log'} } }, @{n = "Target Patch Level"; e = { $_.'Patch Level' } }
                $TargetLevels += $LatestRelease | `
                    Where-Object { ($_.'Release name' -match $search_ver_query) -and ($_.'Patch Level' -eq 'N' ) } | `
                    Select-Object @{n = "Target Release Name"; e = { $_.'Release name' } }, @{n = "Target Build"; e = { if ($null -eq $_.'Client/MOB/vpxd.log') { $_.'VAMI/Release Notes' }else { $_.'Client/MOB/vpxd.log' } } }, @{n = "Target Patch Level"; e = { $_.'Patch Level' } }
            }
            else {
                $TargetLevels += $LatestRelease | `
                    Where-Object { ($_.'Release name' -match $search_ver_query) -and ($_.'Release name' -notmatch "Appliance") -and ($_.'Patch Level' -eq 'N' ) } | `
                    Select-Object @{n = "Target Release Name"; e = { $_.'Release name' } }, @{n = "Target Build"; e = { if ($null -eq $_.'Client/MOB/vpxd.log') { $_.'VAMI/Release Notes' }else { $_.'Client/MOB/vpxd.log' } } }, @{n = "Target Patch Level"; e = { $_.'Patch Level' } }
            }

            if ($null -ne $res) {
                $med = [PSCustomObject]@{
                    Vcenter_Name               = $oneh.Name
                    'Vcenter_Version(Current)' = $oneh.'Version'
                    'Build'                    = $oneh.'Build'
                    'Version'                  = if ($res.'Version' -eq "" -or $null -eq $res.'Version') { " " }else { $res.'Version' }
                    'Release name'             = if ($res.'Release name' -eq "" -or $null -eq $res.'Release name') { " " }else { $res.'Release name' }
                    'Release Date'             = if ($res.'Release Date' -eq "" -or $null -eq $res.'Release Date') { " " }else { $res.'Release Date' }
                    'VAMI/Release Notes'       = if ($res.'VAMI/Release Notes' -eq "" -or $null -eq $res.'VAMI/Release Notes') { " " }else { $res.'VAMI/Release Notes' }
                    'Client/MOB/vpxd.log'      = if ($null -eq $res.'Client/MOB/vpxd.log') { " " }else { $res.'Client/MOB/vpxd.log' }
                    'Current Patch Level'      = if ($null -eq $res.'Patch Level') { " " }else { $res.'Patch Level' }
                    'Compliance_status'        = if ($(($res."Patch Level" -eq 'N') -or ($res."Patch Level" -eq 'N-1'))) { "Compliant" }else { "Non-Compliant" }
                    'Target'                   = if ($($res."Patch Level" -ne 'N') -and $($res)) {
                        if (($null -ne $latest_target) -and ($null -ne $supported_target)) { 
                            "1.$($TargetLevels[2].'Target Release Name')<br>2. $($TargetLevels[1].'Target Release Name')<br>3. $($TargetLevels[0].'Target Release Name')" 
                        }
                        elseif ($null -ne $extra_target) {
                            "1.$($TargetLevels[1].'Target Release Name')<br>2. $($TargetLevels[0].'Target Release Name')"
                        }
                        else {
                            "1.$($TargetLevels[0].'Target Release Name')"
                        }
                    }
                    elseif ($($res.'Version' -lt $env:VC_LATEST_VER)) {
                        "1.$($TargetLevels[1].'Target Release Name')<br>2. $($TargetLevels[0].'Target Release Name')"
                    }
                }

            }
            else {
                $med = [PSCustomObject]@{
                    Vcenter_Name               = $oneh.Name
                    'Vcenter_Version(Current)' = $oneh.'Version'
                    'Build'                    = $oneh.'Build'
                    'Version'                  = " "
                    'Release name'             = " "
                    'Release Date'             = " "
                    'VAMI/Release Notes'       = " "
                    'Client/MOB/vpxd.log'      = " "
                    'Current Patch Level'      = " "
                    'Compliance_status'        = "The patch version is not available in OEM Patch List"
                    'Target'                   = " "
                }
            }

            $compliantLimit += $med;
        
        }

        $compliantLimit | Export-Csv -Path $ExportPath -NoTypeInformation -ErrorAction Stop;
        #Write-PodeHost "The export path - $compliantLimit -"

    }
    Catch {
        $ErrorMessage = $Error[0].Exception.Message;
        Write-PodeHost "Error-$_"
    }
    if ($ErrorMessage -ne '') {
        return $ErrorMessage;
    }
    else {
        return $compliantLimit;
    }
}

$ConfigPath = "$config_path\Input\vCenter-Patch-Level.xlsx"
$ExportPath = "$log_path\vCenter-Patch-Level_Check.csv"
Check-VcenterPatchLevel -ConfigPath "$ConfigPath" -ExportPath "$ExportPath" -ErrorAction Stop | Out-NUll

<#
    ..........
    ... To load Web Pages Faster
    ..........
#>

@{
    Server = @{
        Request    = @{
            Timeout = 60
        }
        AutoImport = @{
            Modules = @{
                Enable     = $true
                ExportOnly = $true
            }
        }
    }
    Web    = @{
        Static = @{
            Cache = @{
                Enable = $true
            }
        }
    }
} | Out-Null

<#
    ..........
    ... To Start The Browser With Chrome\EDGE\FireFox\Opera
    ..........
#>

function Start-Browser {
    param(
        $Port
    )

    $browsers_installed = Get-ItemProperty 'HKLM:Software\Microsoft\Windows\CurrentVersion\App Paths\*.exe' |
    Where-Object { $_.PSChildName -match "chrome|firefox|edge|opera|iexplore" } |
    Select-Object -ExpandProperty PSChildName


    if ($null -ne $browsers_installed) {
        $edge = $browsers_installed | Where-Object { $_ -eq 'msedge.exe' }
        $chrome = $browsers_installed | Where-Object { $_ -eq 'chrome.exe' }
        if ($null -ne $edge) {
            Start-Process $edge -ArgumentList "`"http://localhost:${Port}`""
        }
        elseif ($null -ne $chrome) {
            Start-Process $chrome -ArgumentList "`"http://localhost:${Port}`""
        }
        else {
            Start-Process $browsers_installed[0] -ArgumentList "`"http://localhost:${Port}`"" -ErrorAction SilentlyContinue
        }
    }
}

$ApplicationName = "vSphere Patch Compliance Tool"

<#
 *   ..........
  *  ... Server SetUp
 *   ..........
#>
Write-Host "Starting pode server.." -ForegroundColor Green -BackgroundColor Black

Start-PodeServer -RootPath $ScriptPath -Threads 2 {
    
    $endpoint = "localhost"
    $port = 3600

    Add-PodeEndpoint -Address "$endpoint" -Port $port -Protocol Http 

    New-PodeLoggingMethod -file -Name "errors" |  Enable-PodeErrorLogging
    New-PodeLoggingMethod -File -Name "requests" | Enable-PodeRequestLogging

    Add-PodeStaticRoute -Path '/static' -Source './static'
    Add-PodeStaticRoute -Path '/logstream' -Source './logs'
         
    Use-PodeWebTemplates -Title "$ApplicationName" -Theme Light -NoPageFilter
    
    $link1 = New-PodeWebNavLink -name 'Logstream' -Url "http://$endpoint`:$port/pages/Logstream" -Icon 'post-outline'
    $link2 = New-PodeWebNavLink -name 'Export Report' -Url "http://$endpoint`:$port/pages/export" -Icon 'download-box'

    Set-PodeWebNavDefault -Items $link1, $link2

    Use-PodeWebPages 
    
    $PID | Out-Default
    
    ${function:Start-Browser}
    Start-Browser -Port $port

} -Verbose -ErrorAction Stop

#Generate exe from here
#ps2exe "E:\vSphere Patching Compliance Tool\vSPCTEXE\Analyzing and Report Generation\Report Consolidation.ps1" "E:\vSphere Patching Compliance Tool\vSPCTEXE\Analyzing and Report Generation\vSphere_Patch_Compliance_Tool.exe"