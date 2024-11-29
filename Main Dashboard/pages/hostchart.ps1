Add-PodeWebPage -Name "Compliance Chart" -Icon "chart-pie" -ArgumentList $VC_LATEST_VER, $VC_SUPPORTED_VER -ScriptBlock {
     
    Try{
    New-PodeWebContainer -Id 'chart_container_main' -Content @(

    New-PodeWebContainer -Id 'chart_container' -Content @(
        New-PodeWebChart -Name 'Example Chart' -Message '<center><H4>vCenter Compliance</H4></center>' -Type doughnut -Colours '#40de6a', '#bf3d2c' -NoRefresh -CssClass "chart_class" -ArgumentList $VC_LATEST_VER, $VC_SUPPORTED_VER -ScriptBlock {
            Try{
            $path = Join-Path (Get-PodeServerPath) "report"
            
            
            $data = @(Import-Csv -Path "$path\vCenter-Patch-Level_Check.csv")
            
            $non_comp = (@($data | ? { [double]$($_.'Vcenter_Version(Current)').Substring(0, 3) -lt $env:VC_SUPPORTED_VER})).count
            $comp = (@($data | ? { [double]$($_.'Vcenter_Version(Current)').Substring(0, 3) -ge $env:VC_SUPPORTED_VER })).count
            
            $total = $data.Length

            $comp_percent = [Math]::Round(($comp/$total)*100, 2)
            $non_comp_percent = [Math]::Round(($non_comp/$total)*100, 2)

            #Write-PodeHost "Params $non_comp, $comp, $total, $comp_percent, $non_comp_percent"

            $obj = @([hashtable]@{
                    Name  = "Compliance %" 
                    Value = $comp_percent
                }, [hashtable]@{
                    Name  = "Non Compliance %" 
                    Value = $non_comp_percent
                })

            return ($obj | ForEach-Object {
                    @{
                        Key    = $_.Name # x-axis value
                        Values = @(
                            @{
                                Key   = 'Compliance %'
                                Value = $_.Value # y-axis value
                            }
                        )
                    }
            })
            }catch{
                Write-PodeHost "THis error -> $($_)"
            }
        } 

    ) -CssStyle @{ width = "400px"; height = "480px"; } -NoBackground #'margin-top' = "-30px"; 'margin-left' = "20px"; }

    New-PodeWebContainer -Id 'chart_container2' -Content @(
        New-PodeWebChart -Name 'Example Chart 2' -Message '<center><H4>ESXi Host Compliance</H4></center>'  -Type doughnut -Colours '#40de6a', '#bf3d2c' -NoRefresh -CssClass "chart_class2" -ScriptBlock {
        
            $path = Join-Path (Get-PodeServerPath) "report"
            $data = @()
            $data = Import-Csv -Path "$path\VMHost_Patch_Level_Check.csv"
            $non_comp = (@($data | ? { [double]$($_.'ESXi Version').Substring(0, 3) -lt $env:ESXI_HOST_SUPPORTED_VER })).count
            $comp = (@($data | ? { [double]$($_.'ESXi Version').Substring(0, 3) -ge $env:ESXI_HOST_SUPPORTED_VER })).count
            
            $total = $data.Count
            $comp_percent = [Math]::Round(($comp/$total)*100, 2)
            $non_comp_percent = [Math]::Round(($non_comp/$total)*100, 2)

            $obj = @([hashtable]@{
                    Name  = "Compliance %" 
                    Value = "$comp_percent"
                }, [hashtable]@{
                    Name  = "Non Compliance %" 
                    Value = "$non_comp_percent"
                })

            return ($obj | ForEach-Object {
                    @{
                        Key    = $_.Name # x-axis value
                        Values = @(
                            @{
                                Key   = 'Compliance'
                                Value = $_.Value # y-axis value
                            }
                        )
                    }
                })
        }

    ) -CssStyle @{ width = "400px"; height = "480px"; } -NoBackground
    
    ) -CssStyle @{ display = "flex"; border = "none"; 'margin-top' = "-30px"; }
    

    New-PodeWebContainer -Id 'chart_container_main' -Content @(
        New-PodeWebTable -Name "Counts" -Compact -ScriptBlock{
            #vcenter data

            $path = Join-Path (Get-PodeServerPath) "report"
            $vc = @(Import-Csv -Path "$path\vCenter-Patch-Level_Check.csv")
            $vc_non_comp = (@($vc | ? { [double]$($_.'Vcenter_Version(Current)').Substring(0, 3) -lt $env:VC_SUPPORTED_VER })).count
            $vc_comp = (@($vc | ? { [double]$($_.'Vcenter_Version(Current)').Substring(0, 3) -ge $env:VC_SUPPORTED_VER })).count
            
            #esxihost data
            $esxi = Import-Csv -Path "$path\VMHost_Patch_Level_Check.csv"
            $host_non_comp = (@($esxi | ? { [double]$($_.'ESXi Version').Substring(0, 3) -lt $env:ESXI_HOST_SUPPORTED_VER })).count
            $host_comp = (@($esxi | ? { [double]$($_.'ESXi Version').Substring(0, 3) -ge $env:ESXI_HOST_SUPPORTED_VER })).count
                       
            [ordered]@{
                   'Status' = "<b>Compliant</b>"
                   'Number of vCenters ' = "$vc_comp"
                   'Number of ESXi hosts ' = "$host_comp"
            }
            [ordered]@{
                   'Status' = "<b>Non Compliant</b>"
                   'Number of vCenters ' = "$vc_non_comp"
                   'Number of ESXi hosts ' = "$host_non_comp"
            }
            [ordered]@{
                   'Status' = "<b>Total</b>"
                   'Number of vCenters ' = "$($vc.Count)"
                   'Number of ESXi hosts ' = "$($esxi.Count)"
            } 

        } -NoExport -NoRefresh -Columns @(
            Initialize-PodeWebTableColumn -Key '   ' -Alignment Left
            Initialize-PodeWebTableColumn -Key 'Number of vCenters ' -Alignment Right
            Initialize-PodeWebTableColumn -Key 'Number of ESXi hosts ' -Alignment Right 
        ) -CssStyle @{border = "2px solid black"; } 
            
    ) -CssStyle @{ display = "flex"; border = "none"}; 
    }Catch{
        Write-PodeHost "Some error occured: $_" -ForegroundColor Red
    }
            
}