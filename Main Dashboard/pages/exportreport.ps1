Add-PodeWebPage -Name "Export" -Title "Export Report" -Icon "download-box" -ScriptBlock {
    
     New-PodeWebForm -Name "Report Form" -ScriptBlock {
        
        New-PodeSemaphore -Name "GlobalSema" -Scope Global -Count 2
        
        Use-PodeSemaphore -Name "GlobalSema" -ScriptBlock {

            Set-Variable -Name 'AccountName' -Value $WebEvent.Data["Account Name"] -Scope Global 
            $path = Join-Path (Get-PodeServerPath) "generate_report.ps1"
            $path | Out-PodeHost
            $output, $message = ."$path"
        }
        
        Remove-PodeSemaphore -Name "GlobalSema"
        Move-PodeWebPage "export"
        
    } -Content @(
        New-PodeWebTextbox -Name "Account Name" -Type Text
    )
            
} -Hide
