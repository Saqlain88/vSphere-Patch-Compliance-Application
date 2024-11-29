Add-PodeWebPage -Name "Hardware Compliance" -Icon "information" -ScriptBlock {
Try{
        New-PodeWebTable -Name 'Hardware' -ScriptBlock {
              
            $config_path = Join-Path (Get-PodeServerPath) "config"
            $log_path = Join-Path (Get-PodeServerPath) "report"
            $ConfigPath = "$config_path\Input\VMWare_Hardware_compatibility.xlsx"
            $ExportPath = "$log_path\VMHardware_Patch_Level_Check.csv"

            $ComplianceStatus = @()
            $ComplianceStatus = Import-Csv "$ExportPath" -ErrorAction Stop
                            
            foreach ($svc in $($ComplianceStatus)) {
                [ordered]@{
                     'Host Name'                       = $svc.Name
                     'Manufacturer'             = $svc.'Partner Name'
                     'Model'               = $svc.'Host_Model'
                     'ProcessorType'            = $svc.'ProcessorType'
                     #'Manufacturer'             = $svc.'Manufacturer'
                     #'Model'                    = $svc.'Model'
                     #'CPU Series'               = $svc.'CPU Series'
                     'Supported Patch Level'    = $svc.'Target Patch Level'
                     'Compliance Status'        = $svc.'Compliance_status'
                }
          }

          } 
   }Catch{
    Write-PodeHost "Some error occured :`n$_" -ForegroundColor Red
   } 
}