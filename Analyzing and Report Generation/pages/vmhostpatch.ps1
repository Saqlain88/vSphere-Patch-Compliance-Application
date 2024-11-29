Add-PodeWebPage -Name "Host Compliance" -Icon "information" -ScriptBlock {
Try{
        New-PodeWebTable -Name 'Host Compliance' -ScriptBlock {
               

            $config_path = Join-Path (Get-PodeServerPath) "config"
            $log_path = Join-Path (Get-PodeServerPath) "report"

            $ConfigPath = "$config_path\Input\ESXi Host-Patch-Level.xlsx"
            $ExportPath = "$log_path\VMHost_Patch_Level_Check.csv"

            $ComplianceStatus = @()
            $ComplianceStatus = Import-CSv "$ExportPath" -ErrorAction Stop
            
            foreach ($svc in $($ComplianceStatus)) {
                [ordered]@{
                    'Host Name'                   = $($svc.Host)
                    'ESXi Version'         = $($svc.'ESXi Version')
                    'ESXi Build'           = $($svc.'ESXi Build')
                    'Version Name'         = $($svc.Version)
                    'Release Name'         = ([string]$svc.'Release Date').split(" ")[0]
                    'Current Patch Level'  = $svc.'Current Patch Level'
                    'Compliance Status'    = $svc.'Compliance_status'
                    'Target Patch Level'   = $svc.Target
                    "Available as"         = $svc.'Target Available'
                }
            }
        } -CssStyle @{border = "2px solid black"; } 
}catch{
   Write-PodeHost "Some error occured :`n$_" -ForegroundColor Red
    
}
}