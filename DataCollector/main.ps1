Try {
    Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser -Confirm:$false -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Out-Null
}
catch {
}
 
$EXEName = "vSphere_Data_Assembler"
if ($MyInvocation.MyCommand.Path) {
    $WorkingPath = Split-Path -Parent $MyInvocation.MyCommand.Path
}
else {
    $Process = $WorkingPath = $null; $ToFind = $True
    1..10 | ForEach-Object {
        Write-Host "Please wait! Gathering the executable location."
        Write-Host "." 
        Start-Sleep-Sleep 1
        Clear-Host
        Write-Host "Please wait! Gathering the executable location." 
        Write-Host ".."
        Start-Sleep 1
        Clear-Host 
        Write-Host "Please wait! Gathering the executable location."
        Write-Host "..."
        Start-Sleep-Sleep 1
        Clear-Host
        if ($ToFind) {
            $EXENameUpper = $EXEName.ToUpper()
            $Process = Get-Process | Where-Object { $_.Name.ToUpper() -match $EXENameUpper }
            if (($Process -eq $null) -or ($Process.Path -eq $null)) {
                Start-Sleep 1
            }
            else {
                $WorkingPath = Split-Path -Parent $Process.Path
                $ToFind = $False
            }
        }
    }
}

$LibrariesPath = "$WorkingPath\lib"
$exportPath = "$WorkingPath\exports"
$logPath = "$WorkingPath\logs"

$podepath_reportconsolidation = "$(Split-Path -Path $WorkingPath)\Analyzing and Report Generation\config\Report Consolidation"
$podepath_config = "$(Split-Path -Path $WorkingPath)\Analyzing and Report Generation\config\"
if ($(test-path $podepath_reportconsolidation) -eq $true) {
    Remove-Item -Path "$podepath_config\all_vcenters.csv" -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Item -Path "$podepath_config\all_hardwares.csv" -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Item -Path "$podepath_config\all_hosts.csv" -Confirm:$false -ErrorAction SilentlyContinue
    
    $oldfiles = $podepath_reportconsolidation
}
else {
    $oldfiles = "$WorkingPath\old"
}


#---- Libraries ----#
$CLIModulePath = "$LibrariesPath\VMware.PowerCLI"

#---- Take inputs (vCenter, Account, Credential) ----#
Function Get-VCandCredential {
    param()
    $Error.Clear()
    $Status = $false; $VC = $VCCred = $AccountName = $null
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
 
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "vSphere Data Collector"
    $form.Size = New-Object System.Drawing.Size(500, 300)
    $form.StartPosition = "CenterScreen"
  
    $vCenterFQDNLabel = New-Object System.Windows.Forms.Label
    $vCenterFQDNLabel.Location = New-Object System.Drawing.Point(20, 80)
    $vCenterFQDNLabel.Size = New-Object System.Drawing.Size(150, 40)
    $vCenterFQDNLabel.Font = New-Object System.Drawing.Font($form.Font.Name, 10)
    $vCenterFQDNLabel.Text = "vCenter FQDN:"
    $form.Controls.Add($vCenterFQDNLabel)
 
    $vCenterFQDNTextBox = New-Object System.Windows.Forms.TextBox
    $vCenterFQDNTextBox.Location = New-Object System.Drawing.Point(300, 80)
    $vCenterFQDNTextBox.Font = New-Object System.Drawing.Font($form.Font.Name, 16)
    $vCenterFQDNTextBox.Size = New-Object System.Drawing.Size(150, 20)
    $form.Controls.Add($vCenterFQDNTextBox)
 
    $submitButton = New-Object System.Windows.Forms.Button
    $submitButton.Location = New-Object System.Drawing.Point(125, 150)
    $submitButton.Size = New-Object System.Drawing.Size(100, 40)
    $submitButton.Text = "Submit"
    $submitButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.AcceptButton = $submitButton
    $form.Controls.Add($submitButton)
 
    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(275, 150)
    $cancelButton.Size = New-Object System.Drawing.Size(100, 40)
    $cancelButton.Text = "Cancel"
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.CancelButton = $cancelButton
    $form.Controls.Add($cancelButton)
 
    #$form.Add_Shown({$accountNameTextBox.Select()})
    $result = $form.ShowDialog()
 
    if ($result -eq [System.Windows.Forms.DialogResult]::Cancel) { Break }
 
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        if ($vCenterFQDNTextBox.Text) {
            #Write-Host "Account Name: $($accountNameTextBox.Text)"
            Write-Host "vCenter FQDN: $($vCenterFQDNTextBox.Text)"
            $CredMessage = "Enter the VCenter Credentials for $VC"
            $VC = $vCenterFQDNTextBox.Text
        }
        else {
            Break
            #[System.Windows.Forms.MessageBox]::Show("Please provide input", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    }
    $form.Close()
 
    $cform = New-Object System.Windows.Forms.Form
    $cform.Text = "Enter Credential for vCenter"
    $cform.Size = New-Object System.Drawing.Size(500, 300)
    $cform.StartPosition = "CenterScreen"
 
    $usernameLabel = New-Object System.Windows.Forms.Label
    $usernameLabel.Location = New-Object System.Drawing.Point(20, 20)
    $usernameLabel.Font = New-Object System.Drawing.Font($cform.Font.Name, 10)
    $usernameLabel.Size = New-Object System.Drawing.Size(150, 40)
    $usernameLabel.Text = "Username:"
    $cform.Controls.Add($usernameLabel)
 
    $usernameTextBox = New-Object System.Windows.Forms.TextBox
    $usernameTextBox.Location = New-Object System.Drawing.Point(300, 20)
    $usernameTextBox.Font = New-Object System.Drawing.Font($cform.Font.Name, 16)
    $usernameTextBox.Size = New-Object System.Drawing.Size(150, 20)
    $cform.Controls.Add($usernameTextBox)
 
    $passwordLabel = New-Object System.Windows.Forms.Label
    $passwordLabel.Location = New-Object System.Drawing.Point(20, 80)
    $passwordLabel.Size = New-Object System.Drawing.Size(150, 40)
    $passwordLabel.Font = New-Object System.Drawing.Font($cform.Font.Name, 10)
    $passwordLabel.Text = "Password:"
    $cform.Controls.Add($passwordLabel)
 
    $passwordTextBox = New-Object System.Windows.Forms.MaskedTextBox
    $passwordTextBox.PasswordChar = '*'
    $passwordTextBox.Location = New-Object System.Drawing.Point(300, 80)
    $passwordTextBox.Font = New-Object System.Drawing.Font($cform.Font.Name, 16)
    $passwordTextBox.Size = New-Object System.Drawing.Size(150, 20)
    $cform.Controls.Add($passwordTextBox)
 
    $submitButton = New-Object System.Windows.Forms.Button
    $submitButton.Location = New-Object System.Drawing.Point(125, 150)
    $submitButton.Size = New-Object System.Drawing.Size(100, 40)
    $submitButton.Text = "Submit"
    $submitButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $cform.AcceptButton = $submitButton
    $cform.Controls.Add($submitButton)
 
    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(275, 150)
    $cancelButton.Size = New-Object System.Drawing.Size(100, 40)
    $cancelButton.Text = "Cancel"
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $cform.CancelButton = $cancelButton
    $cform.Controls.Add($cancelButton)
 
    $cform.Add_Shown({ $usernameTextBox.Select() })
    $cform_result = $cform.ShowDialog()
 
    if ($cform_result -eq [System.Windows.Forms.DialogResult]::Cancel) { Break }
 
    if ($cform_result -eq [System.Windows.Forms.DialogResult]::OK) {
        if ($usernameTextBox.Text -and $passwordTextBox.Text) {
            Write-Host "username: $($usernameTextBox.Text)"
            $VCCred = New-Object System.Management.Automation.PSCredential ($usernameTextBox.Text, $(ConvertTo-SecureString -AsPlainText -Force $passwordTextBox.Text))
            #$VC = $passwordTextBox.Text
        }
        else {
            [System.Windows.Forms.MessageBox]::Show("Please provide input", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            $cform.Close()
            Break
            #[System.Windows.Forms.MessageBox]::Show("Please provide input", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    }
    $cform.Close()
 
    #Write-Host $VCCred
 
    #$VCCred = Get-Credential -Message $CredMessage
    if ($VC -and $VCCred) {
        $Status = $true
        $VCDetail = New-Object PSObject -Property @{VC = $VC.Trim(); Credential = $VCCred; AccountName = $AccountName }
    }
    else {
        $Status = $false
        $VCDetail = "`n`r" + (Get-Date -Format "dd-MM-yyyy HH:mm:ss - ") + " Error: Missing VC Details $($_)`n"
    }
    return $Status, $VCDetail
}

#---- Check PowerCLI module ----#
Function Check-ModulePowerCLI {
    param(
        [Parameter(Mandatory = $true)]$CLIModulePath
    )
    $Error.Clear()
    $check_before_import = Get-Module "VMware.*"
    if ($null -eq $check_before_import) {
        $Message = "$(Get-Date -Format "dd-M-yyyy hh:mm:ss - ") - PowerCLI Module Imported.`n"     
        $status = $true
        return $status, $Message
    }
    $NoReturn = Import-Module VMWare.VimAutomation.Sdk, VMWare.VimAutomation.Common, VMWare.Vim, VMWare.VimAutomation.Cis.Core, VMWare.VimAutomation.Core -ErrorAction SilentlyContinue
    $MatchModule = Get-Module "VMware.*"
    if ($null -eq $MatchModule) {
        $Message = "$(Get-Date -Format "dd-M-yyyy hh:mm:ss - ") - Importing module.`n"
        $NoReturn = Import-module "$CLIModulePath\VMWare.VimAutomation.Sdk", "$CLIModulePath\VMWare.VimAutomation.Common", "$CLIModulePath\VMWare.Vim", "$CLIModulePath\VMWare.VimAutomation.Cis.Core", "$CLIModulePath\VMWare.VimAutomation.Core" -Cmdlet Connect-VIServer, Disconnect-VIServer, Get-VMHost -NoClobber -ErrorAction SilentlyContinue
        $MatchModule = Get-Module "VMware.*"
        if ($MatchModule) {
            $Message = "$(Get-Date -Format "dd-M-yyyy hh:mm:ss - ") - PowerCLI Module Imported.`n"
            $status = $true
        }
        else {
            $Message = "$(Get-Date -Format "dd-M-yyyy hh:mm:ss - ") - Failed to imported powercli.`n"       
            $status = $false
        }
    }
    else {
        $Message = "$(Get-Date -Format "dd-M-yyyy hh:mm:ss - ") - PowerCLI Module Imported.`n"        
        $status = $true
    }  

    return $Status, $Message
}

Function ConnectTo-VC {
    param(
        [Parameter(Mandatory = $true)]$server,
        [Parameter(Mandatory = $true)]$credential
    )
    $Error.Clear()
    $Message = ""
    Try {
        
        Connect-VIServer $server -Credential $credential -WarningAction SilentlyContinue -ErrorAction Stop
        $Message += "`n`r" + (Get-Date -Format "dd-MM-yyyy HH:mm:ss - ") + " Connected to vCenter [$server]`n"
        $status = $true

    }
    Catch {
        $Message += "$(Get-Date -Format "dd-MM-yyyy HH:mm:ss - ") Error: Failed to connect to vCenter [$server] - $($_)`n"
        $status = $false
    }
    return $status, $Message 
}

Function Get-VCInfo {
    $Error.Clear()
    $Vcinfo = @()
    $Message = ""
    Try {
        
        #$Vcinfo = Get-View -ViewType VimAbout | Select Name, Version, Build
        $OSType = $Global:DefaultVIServer.ExtensionData.Content.About.OsType
        $Vcinfo = $Global:DefaultVIServer | Select-Object Name, Version, Build, @{n = "OsType"; e = { $OSType } }
        
        $Message += (Get-Date -Format "dd-MM-yyyy HH:mm:ss - ") + " vCenter [$($Vcinfo.Name)] information collected`n"
        $status = $true
    }
    Catch {
        $Message += (Get-Date -Format "dd-MM-yyyy HH:mm:ss - ") + " Error: Failed to fetch vCenter information $($_)`n"
        $status = $false
    }
    return $Vcinfo, $status, $Message 
}

Function Export-File {
    param(
        [Parameter(Mandatory = $true)]$exportPath,
        [Parameter(Mandatory = $true)]$vCenterData
    )
    $Error.Clear()
    $Message = ""
    Try {
        $vCenterData | Export-Csv -Path "$exportPath" -Append -NoClobber -NoTypeInformation -ErrorAction Stop
        $Message += (Get-Date -Format "dd-MM-yyyy HH:mm:ss - ") + "Information exported to $exportPath" + "`n"
        $status = $true
    }
    Catch {
        $Message += (Get-Date -Format "dd-MM-yyyy HH:mm:ss - ") + " Error: Failed to export vCenter [$($vCenterData.Name)] info $($_)`n"
        $status = $false
    }
    return $status, $Message
}

function ShowAbout {

    [void] [System.Windows.MessageBox]::Show( "Data Exported Successfully", "About script", "OK", "Information" )

}

function ShowError {
    param(
        [Parameter(Mandatory = $true)]$Emessage
    )
    [void] [System.Windows.MessageBox]::Show( "$Emessage", "About script", "OK", "Error" )

}

function MoveOlderFile {
    param(
        [Parameter(Mandatory = $true)]$From,
        [Parameter(Mandatory = $true)]$To               
    )
    $Status = ""
    $Message = @()
    Try {
        Get-ChildItem -Path $From -ErrorAction Stop | Foreach-Object { Rename-Item -Path $_.FullName  -NewName $($($_.Name.Replace(".csv", "")) + "_" + $_.CreationTime.ToString("ddMMyyyy_hhmmss") + ".csv") -Confirm:$false -ErrorAction Stop }
        $Message += (Get-Date -Format "dd-MM-yyyy HH:mm:ss - ") + "Renamed files.`n"
        Get-ChildItem -Path $From | Move-Item -Destination $To -Confirm:$false -ErrorAction Stop
        $Message += (Get-Date -Format "dd-MM-yyyy HH:mm:ss - ") + "Moved files to $To.`n"
        $Status = $true
    }
    Catch {
        $Message += (Get-Date -Format "dd-MM-yyyy HH:mm:ss - ") + "Some error occured: $($_)`n"
        $Status = $false
    }
    return $Status, $Message
}

Try {

    $log = ""   
    $log += (Get-Date -Format "dd-MM-yyyy HH:mm:ss - ") + "-------Application Started-------`n"
    Add-Type -AssemblyName PresentationFramework
    try {
        $initialTimeout = (Get-PowerCLIConfiguration -Scope Session).WebOperationTimeoutSeconds
        Set-PowerCLIConfiguration -Scope Session -WebOperationTimeoutSeconds 1 -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
        Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false -Confirm:$false -ErrorAction SilentlyContinue  | Out-Null
    }
    catch {}
    $CLIModulePath = "$LibrariesPath"
    Write-Host "Please wait! required modules are being loaded."
    $IsPowerCLI, $CLIMessage = Check-ModulePowerCLI -CLIModulePath $CLIModulePath
    $log += $CLIMessage

    if ($IsPowerCLI) {
        $log += $Message
    
        While ($true) {
            $IsVCDetails, $VCDetails = Get-VCandCredential
            $serverName = $VCDetails.VC
            #$AccountName = $VCDetails.AccountName
            $Credential = $VCDetails.Credential
    
            $serverStatus, $Message = ConnectTo-VC -server $serverName -credential $Credential 
            $log += $Message
        
            if ($serverStatus) {
            
                $VCInfo, $fetchStatus, $Message = Get-VCInfo
                $log += $Message

                if ($fetchStatus) {

                    $hostDetail = Get-VmHost -State Maintenance, Connected -ErrorAction Stop | Select-Object Name, version, build, Manufacturer, Model, ProcessorType
                    $log += "$(Get-Date -Format 'dd-mm-yyyy hh:mm:ss') - Fetched Hosts Information`n"

                    $discarded_hosts = Get-VmHost -State Disconnected, NotResponding -ErrorAction Stop | Select-Object Name, version, build, Manufacturer, Model, ProcessorType
                    if ($null -ne $discarded_hosts) {
                        $log += "$(Get-Date -Format 'dd-mm-yyyy hh:mm:ss') - Hosts unreachable -> $($discarded_hosts.Name -join ", ")`n"
                        Write-Host "Hosts unreachable : $($discarded_hosts.Name -join ", ")"
                    }

                    $host_data = $hostDetail | Select-Object @{Label = "Host"; Expression = { $_.Name } } , @{Label = "ESX Version"; Expression = { $_.version } }, @{Label = "ESX Build" ; Expression = { $_.build } }
                    $hardware_data = $hostDetail | Select-Object -Property Name, Manufacturer, Model, ProcessorType, @{Label = "ESXi Version"; Expression = { $_.version } }
                    $log += "$(Get-Date -Format 'dd-mm-yyyy hh:mm:ss') - Fetched Hardware Information`n"
                
                    $ExportStatus, $Message = Export-File -exportPath "$exportPath\all_vcenters.csv" -vCenterData $VCInfo
                    $log += $Message

                    $HostExportStatus, $Message = Export-File -exportPath "$exportPath\all_hosts.csv" -vCenterData $host_data
                    $log += $Message

                    $HardwareExportStatus, $Message = Export-File -exportPath "$exportPath\all_hardwares.csv" -vCenterData $hardware_data
                    $log += $Message
            
                    #Close-loadingScreen -loadingWindow $loader
            
                    if ($ExportStatus) {
                        ShowAbout
                        [void][System.Reflection.Assembly]::LoadWithPartialName(‘Microsoft.VisualBasic’) 
                        $Continue = [Microsoft.VisualBasic.Interaction]::MsgBox(“Do you want to add next vCenter?”, ‘YesNo,Information’, “Stop or Continue”) 
                        if ($Continue -eq "No") {
                            Break;
                        }
                        else {
                            Continue;
                        }

                    }
                    else {
                        ShowError -Emessage "Error occured while exporting data. Please check error log."  
                        [void][System.Reflection.Assembly]::LoadWithPartialName(‘Microsoft.VisualBasic’) 
                        $Continue = [Microsoft.VisualBasic.Interaction]::MsgBox(“Do you want to add next vCenter?”, ‘YesNo,Information’, “Stop or Continue”) 
                        if ($Continue -eq "No") {
                            Break;
                        }
                        else {
                            Continue;
                        }
                    }
                }
                else {
                    ShowError -Emessage "Error occured while fetching data from server. Please check error log."            
                    [void][System.Reflection.Assembly]::LoadWithPartialName(‘Microsoft.VisualBasic’) 
                    $Continue = [Microsoft.VisualBasic.Interaction]::MsgBox(“Do you want to add next vCenter?”, ‘YesNo,Information’, “Stop or Continue”) 
                    if ($Continue -eq "No") {
                        Break;
                    }
                    else {
                        Continue;
                    }
                }
            }
            else {
                ShowError -Emessage "Error occured while connecting to server. Please check error log."
                [void][System.Reflection.Assembly]::LoadWithPartialName(‘Microsoft.VisualBasic’) 
                $Continue = [Microsoft.VisualBasic.Interaction]::MsgBox(“Do you want to add next vCenter?”, ‘YesNo,Information’, “Stop or Continue”) 
                if ($Continue -eq "No") {
                    Break;
                }
                else {
                    Continue;
                }
            }
        }
    }
}
Catch {
    Write-Host "Some error occured: $_`n" -ForegroundColor Red -BackgroundColor Black
}
Finally {
    
    if ((Test-Path "$(Split-Path -Path $WorkingPath)\Analyzing and Report Generation\master_script.ps1") -eq $false) {
        Get-ChildItem -Path $exportPath  | Where-Object { $_.CreationTime -lt (Get-Date).AddDays(-30) } | Remove-Item -Force -Confirm:$false -ErrorAction SilentlyContinue
    }
    else {
        $status, $Message = MoveOlderFile -From $exportPath -To $oldfiles
    }
    Get-ChildItem -Path $logPath | Where-Object { $_.CreationTime -lt (Get-Date).AddDays(-15) } | Remove-Item -Force -Confirm:$false -ErrorAction SilentlyContinue
    $log += "$(Get-Date -Format 'dd-mm-yyyy hh:mm:ss') - Removed 15 days older log`n"

    $todays_log = "$logPath\log_$(Get-Date -Format 'ddMMyyyy').log" 
    $log += "$(Get-Date -Format 'dd-mm-yyyy hh:mm:ss') - Exporting log file.`n"

    if (Test-Path $todays_log) {
        $log | Out-File -FilePath $todays_log -Append
    }
    else {
        $log | Out-File -FilePath $todays_log
    }

    try { Set-PowerCLIConfiguration -Scope Session -WebOperationTimeoutSeconds $initialTimeout -Confirm:$false | Out-Null }catch {}

    if (Test-Path "$(Split-Path -Path $WorkingPath)\Analyzing and Report Generation\vSphere_Patch_Compliance_Tool.exe") {
        Invoke-Command -ScriptBlock {
            Start-Process "$(Split-Path -Path $WorkingPath)\Analyzing and Report Generation\vSphere_Patch_Compliance_Tool.exe" -Verb Open 
        }
    }
    elseif (Test-Path "$(Split-Path -Path $WorkingPath)\Analyzing and Report Generation\master_script.ps1") {
        Invoke-Command -ScriptBlock {
            . "$(Split-Path -Path $WorkingPath)\Analyzing and Report Generation\master_script.ps1"
        }
    }
}