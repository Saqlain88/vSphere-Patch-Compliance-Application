Add-PodeWebPage -Name "vCenter Compliance" -Icon "information" -ScriptBlock {
Try{
        New-PodeWebTable -Name 'vCenter' -ScriptBlock {
               
            $config_path = Join-Path (Get-PodeServerPath) "config"
            $log_path = Join-Path (Get-PodeServerPath) "report"

            $ConfigPath = "$config_path\Input\vCenter-Patch-Level.xlsx"
            $ExportPath = "$log_path\vCenter-Patch-Level_Check.csv"
        
            $ComplianceStatus = @()
            $ComplianceStatus = Import-CSv "$ExportPath" -ErrorAction Stop
                            
            foreach ($svc in $($ComplianceStatus)) {
                [ordered]@{
                    'vCenter Name'        = $svc.Vcenter_Name
                    'Current Version'     = $svc.'Vcenter_Version(Current)'
                    'Current Build'       = $svc.'Build'
                    #'Version'                  = $svc.'Version'
                    'Release Name'        = $svc.'Release name'
                    'Release Date'        = ([string]$svc.'Release Date').split(" ")[0]
                    #'VAMI/Release Notes'       = $svc.'VAMI/Release Notes'
                    #'vSphere Client Version'      = $svc.'Client/MOB/vpxd.log'
                    'Current Patch Level' = $svc.'Current Patch Level'
                    'Compliance Status'   = $svc.'Compliance_status'
                    'Target Patch Level'  = $svc.'Target'
                }
            }

        } -Compact -CssStyle @{border = "2px solid black"; }
    }Catch{
       Write-PodeHost "Some error occured :`n$_" -ForegroundColor Red
    
    }       
}