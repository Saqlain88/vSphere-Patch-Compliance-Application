$ErrorActionPreference="Stop"

Try{
    #START

    $path = Join-Path (Get-PodeServerPath) "static"
    $lib_path = Join-Path (Get-PodeServerPath) "lib"
    $log_path = Join-Path (Get-PodeServerPath) "report"

    $scriptPath = "$lib_path\ReportHTML"
    $LeftLogo_Path = "$path\small_logo_report.png"  
    $leftlogo = "data:image/png;base64, " + [convert]::ToBase64String((get-content $LeftLogo_Path -AsByteStream)) # replace < -AsByteStream> with < -Encoding byte >, incase of parameter not found error

    $export_path = Join-Path (Get-PodeServerPath) "report"
       

    #Import-Module "$scriptPath" -Verbose
    $GroupTypetable3 = New-Object 'System.Collections.Generic.List[System.Object]'
    $GroupTypetable2 = New-Object 'System.Collections.Generic.List[System.Object]'
    $GroupTypetable1 = New-Object 'System.Collections.Generic.List[System.Object]'
    $GroupTypetable_host1 = New-Object 'System.Collections.Generic.List[System.Object]'
    $GroupTypetable_host2 = New-Object 'System.Collections.Generic.List[System.Object]'
    $GroupTypetable_host3 = New-Object 'System.Collections.Generic.List[System.Object]'
    $Compliance_table_vcenter = New-Object 'System.Collections.Generic.List[System.Object]'
    $Compliance_table_host = New-Object 'System.Collections.Generic.List[System.Object]'

    $vCenter_data = Import-CSV -Path "$log_path\vCenter-Patch-Level_Check.csv"
    $VMHardware_data = Import-CSV -Path "$log_path\VMHardware_Patch_Level_Check.csv"
    $VMHost_data = Import-CSV -Path "$log_path\VMHost_Patch_Level_Check.csv"

    $vcenter_count = $(@($vCenter_data).Count)
    $vmhost_count = $VMHost_data.Count

    #Get Counts for Graph

    $vc_non_comp = (@($vCenter_data | ? { [double]$($_.'Vcenter_Version(Current)').Substring(0, 3) -lt $env:VC_SUPPORTED_VER })).count
    $vc_comp = (@($vCenter_data | ? { [double]$($_.'Vcenter_Version(Current)').Substring(0, 3) -ge $env:VC_SUPPORTED_VER })).count
            
    $host_non_comp = (@($VMHost_data | ? { [double]$($_.'ESXi Version').Substring(0, 3) -lt $env:ESXI_HOST_SUPPORTED_VER })).count
    $host_comp = (@($VMHost_data | ? { [double]$($_.'ESXi Version').Substring(0, 3) -ge $env:ESXI_HOST_SUPPORTED_VER })).count
            
    $tabarray = @('Dashboard', 'vCenter', 'ESXi Host', 'Host Hardware Compatibility')
    
    #Charts configuration
    #comliance chart - vCenter
    $Compliance_chart_vcenter = Get-HTMLPieChartObject
    $Compliance_chart_vcenter.Title = "vCenter Compliance"
    $Compliance_chart_vcenter.Size.Height = 300
    $Compliance_chart_vcenter.Size.width = 300
    $Compliance_chart_vcenter.ChartStyle.ChartType = 'doughnut'
    $Compliance_chart_vcenter.DataDefinition.DataNameColumnName = 'Name'
    $Compliance_chart_vcenter.DataDefinition.DataValueColumnName = 'Count'


    $obj1 = [PSCustomObject]@{
        'Name'  = 'Compliant'
        'Count' = $([Math]::Round($(($vc_comp/$vcenter_count)*100),2))
    }
    $Compliance_table_vcenter.add($obj1)

    $obj1 = [PSCustomObject]@{
        'Name'  = 'Non Compliant'
        'Count' = $([Math]::Round($(($vc_non_comp/$vcenter_count)*100),2))
    }

    $Compliance_table_vcenter.add($obj1)


    #comliance chart - ESXi Host
    $Compliance_chart_host = Get-HTMLPieChartObject
    $Compliance_chart_host.Title = "ESXi Host Compliance"
    $Compliance_chart_host.Size.Height = 300
    $Compliance_chart_host.Size.width = 300
    $Compliance_chart_host.ChartStyle.ChartType = 'doughnut'
    $Compliance_chart_host.DataDefinition.DataNameColumnName = 'Name'
    $Compliance_chart_host.DataDefinition.DataValueColumnName = 'Count'

    $obj1 = [PSCustomObject]@{
        'Name'  = 'Compliant'
        'Count' = [Math]::Round($(($host_comp/$vmhost_count)*100), 2)
    }
    $Compliance_table_host.add($obj1)

    $obj1 = [PSCustomObject]@{
        'Name'  = 'Non Compliant'
        'Count' = [Math]::Round($(($host_non_comp/$vmhost_count)*100), 2)
    }
    $Compliance_table_host.add($obj1)

    ### Get Count of Legacy and Latest - vCenters ###
    $Legacy_vCenter = (@($vCenter_data | ? { [double]$($_.'Vcenter_Version(Current)').Substring(0, 3) -le $env:VC_LEGACY })).count
    $Supported_vCenter = (@($vCenter_data | ? { [double]$($_.'Vcenter_Version(Current)').Substring(0, 3) -ge $env:VC_SUPPORTED_VER })).count

    ### Get Count of Legacy and Latest - Hosts ###
    $Legacy_esx_hosts = (@($VMHost_data | ? { [double]$($_.'ESXi Version').Substring(0, 3) -le $env:ESXI_HOST_LEGACY })).count
    $Supported_esx_hosts = (@($VMHost_data | ? { [double]$($_.'ESXi Version').Substring(0, 3) -ge $env:ESXI_HOST_SUPPORTED_VER })).count

    #Below 6.5 and 6.7 - Red - vCenter - Legacy
    $PieObjectGroupType2 = Get-HTMLPieChartObject
    $PieObjectGroupType2.Title = "Legacy vCenter"
    $PieObjectGroupType2.Size.Height = 250
    $PieObjectGroupType2.Size.width = 250
    $PieObjectGroupType2.ChartStyle.ChartType = 'doughnut'
    $PieObjectGroupType2.DataDefinition.DataNameColumnName = 'Name'
    $PieObjectGroupType2.DataDefinition.DataValueColumnName = 'Count'

    $Legacy_vCenter

    $obj1 = [PSCustomObject]@{
        'Name'  = "vCenter $($env:VC_LEGACY) and below"
        'Count' = $([Math]::Round($(($Legacy_vCenter/$vcenter_count)*100),2))
    }

    $GroupTypetable2.add($obj1)

    $obj1 = [PSCustomObject]@{
        'Name'  = 'Other'
        'Count' = $([Math]::Round($(($Supported_vCenter/$vcenter_count)*100),2))
    }

    $GroupTypetable2.add($obj1)


    #v7.0 and 8.0 - Orange - vCenter - Supported & Latest
    $PieObjectGroupType1 = Get-HTMLPieChartObject
    $PieObjectGroupType1.Title = "Latest & Supported vCenter"
    $PieObjectGroupType1.Size.Height = 250
    $PieObjectGroupType1.Size.width = 250
    $PieObjectGroupType1.ChartStyle.ChartType = 'doughnut'
    $PieObjectGroupType1.DataDefinition.DataNameColumnName = 'Name'
    $PieObjectGroupType1.DataDefinition.DataValueColumnName = 'Count'

    $obj1 = [PSCustomObject]@{
        'Name'  = "vCenter $($env:VC_SUPPORTED_VER) and $($env:VC_LATEST_VER)"
        'Count' = $([Math]::Round($(($Supported_vCenter/$vcenter_count)*100),2))
    }

    $GroupTypetable1.add($obj1)

    $obj1 = [PSCustomObject]@{
        'Name'  = 'Other'
        'Count' = $([Math]::Round($(($Legacy_vCenter/$vcenter_count)*100),2))
    }

    $GroupTypetable1.add($obj1)

    
    #ESXi Host Charts
    #ESXi host Properties 

    #Below 6.5 and 6.7 - Red - vCenter - Legacy
    $PieObjectGroupType_host1 = Get-HTMLPieChartObject
    $PieObjectGroupType_host1.Title = "Legacy Host"
    $PieObjectGroupType_host1.Size.Height = 250
    $PieObjectGroupType_host1.Size.width = 250
    $PieObjectGroupType_host1.ChartStyle.ChartType = 'doughnut'
    $PieObjectGroupType_host1.DataDefinition.DataNameColumnName = 'Name'
    $PieObjectGroupType_host1.DataDefinition.DataValueColumnName = 'Count'

    $obj1 = [PSCustomObject]@{
        'Name'  = "ESXi Host $($env:ESXI_HOST_LEGACY)"
        'Count' = $([Math]::Round($(($Legacy_esx_hosts/$vmhost_count)*100),2))
    }
    $GroupTypetable_host1.add($obj1)

    $obj1 = [PSCustomObject]@{
        'Name'  = 'Other'
        'Count' = $([Math]::Round($(($Supported_esx_hosts/$vmhost_count)*100),2))
    }
    $GroupTypetable_host1.add($obj1)


    #7.0 and 8.0 - Orange - ESXi Host - Latest & Supported
    $PieObjectGroupType_host2 = Get-HTMLPieChartObject
    $PieObjectGroupType_host2.Title = "Latest & Supported Host"
    $PieObjectGroupType_host2.Size.Height = 250
    $PieObjectGroupType_host2.Size.width = 250
    $PieObjectGroupType_host2.ChartStyle.ChartType = 'doughnut'
    $PieObjectGroupType_host2.DataDefinition.DataNameColumnName = 'Name'
    $PieObjectGroupType_host2.DataDefinition.DataValueColumnName = 'Count'


    $Count = 6
    $obj1 = [PSCustomObject]@{
        'Name'  = "ESXi Host $($Env:ESXI_HOST_SUPPORTED_VER) and $($env:ESXI_HOST_LATEST_VER)"
        'Count' = $([Math]::Round($(($Supported_esx_hosts/$vmhost_count)*100),2))
    }
    $GroupTypetable_host2.add($obj1)

    $Count = 4
    $obj1 = [PSCustomObject]@{
        'Name'  = 'Other'
        'Count' = $([Math]::Round($(($Legacy_esx_hosts/$vmhost_count)*100),2))
    }
    $GroupTypetable_host2.add($obj1)
    
    $compliance_table = @()

    $vc_non_comp = (@($vCenter_data | ? { [double]$($_.'Vcenter_Version(Current)').Substring(0, 3) -lt $env:VC_SUPPORTED_VER })).count
    $vc_comp = (@($vCenter_data | ? { [double]$($_.'Vcenter_Version(Current)').Substring(0, 3) -ge $env:VC_SUPPORTED_VER })).count    
       
    $host_non_comp = (@($VMHost_data | ? { [double]$($_.'ESXi Version').Substring(0, 3) -lt $env:ESXI_HOST_SUPPORTED_VER })).count
    $host_comp = (@($VMHost_data | ? { [double]$($_.'ESXi Version').Substring(0, 3) -ge $env:ESXI_HOST_SUPPORTED_VER })).count
      
    ################### Compliance Table ######################

    $Compliance_table_html = "<table style='margin-top:50%; border: 1px solid;'>
    <tr><th style='background: #337e94;color: white; border: 1px solid'></th><th style='background: #337e94;color: white;'>Number of vCenter</th><th style='background: #337e94;color: white;'>Number of ESXi Host</th></tr>
    <tr><th style='background: #337e94;color: white; border: 1px solid'>Compliant</th><td style='border: 1px solid;'>$vc_comp</td><td style='border: 1px solid;'>$host_comp</td></tr>
    <tr><th style='background: #337e94;color: white; border: 1px solid'>Non Compliant</th><td style='border: 1px solid;'>$vc_non_comp</td><td style='border: 1px solid;'>$host_non_comp</td></tr>
    <tr><th style='background: #337e94;color: white; border: 1px solid'>Total</th><td style='border: 1px solid;'>$($vc_comp+$vc_non_comp)</td><td style='border: 1px solid;'>$($vmhost_count)</td></tr>
    </table>"

    ################### vCenter Table ######################

    $vcenter_table_html = "<table style='margin-top:50%; border: 1px solid;'>
    <tr><th style='background: #337e94;color: white; border: 1px solid'>Number of Legacy vCenter</th><td style='border: 1px solid;'>$($Legacy_vCenter)</td></tr>
    <tr><th style='background: #337e94;color: white;border: 1px solid'>Number of Latest and Supported vCenter</th><td style='border: 1px solid;'>$($Supported_vCenter)</td></tr>
    <tr><th style='background: #337e94;color: white; border: 1px solid'>Total Number of vCenters</th><td style='border: 1px solid;'>$($Legacy_vCenter+$Supported_vCenter)</td></tr>
    </table>"

    ################### ESXi Hosts Table ######################

    $host_table_html = "<table style='margin-top:50%; border: 1px solid;'>
    <tr><th style='background: #337e94;color: white; border: 1px solid'>Number of Legacy ESXi Hosts</th><td style='border: 1px solid;'>$($Legacy_esx_hosts)</td></tr>
    <tr><th style='background: #337e94;color: white; border: 1px solid'>Number of Latest and Supported ESXi Hosts</th><td style='border: 1px solid;'>$($Supported_esx_hosts)</td></tr>
    <tr><th style='background: #337e94;color: white; border: 1px solid'>Total Number of ESXi Hosts</th><td style='border: 1px solid;'>$($Legacy_esx_hosts+$Supported_esx_hosts)</td></tr>
    </table>"

    $vCenter_data = $vCenter_data | Select @{Name = "vCenter Name"; Expression = { $_.Vcenter_Name } }, @{Name = "Current Version"; Expression = { $_.'Vcenter_Version(Current)' } }, @{Name = "Current Build"; Expression = { $_.'Build' } }, @{Name = "Release Name"; Expression = { $_.'Release name' } }, 'Release Date', 'Current Patch Level', @{Name = "Compliance Status"; Expression = { $_.'Compliance_status' } }, @{n = 'Target Patch Level'; e = { $(($_.Target).replace('<br>', ', ')) } }
    $VMHost_data = $VMHost_data | Select @{Name = "Host Name"; Expression = { $_.Host } }, 'ESXi Version', 'ESXi Build', 'Release Name', 'Release Date', 'Current Patch Level', @{Name = "Compliance Status"; Expression = { $_.'Compliance_status' } }, @{n = 'Target Patch Level'; e = { $(($_.Target).replace('<br>', ', ')) } }, @{n = 'Target Available as'; e = { $(($_.'Target Available').replace('<br>', ', ')) } }
    $VMHardware_data = $VMHardware_data | Select @{n = 'Host Name'; e = { $_.'Name' } }, @{n = 'Host Model'; e = { $_.'Host_Model' } }, 'Partner Name', ProcessorType, 'CPU Series', 'Target Patch Level', @{Name = "Compliance Status"; Expression = { $_.'Compliance_status' } }

    #Main function
    $rpt = New-Object 'System.Collections.Generic.List[System.Object]'
    $rpt += get-htmlopenpage -TitleText "<div class='Account' style='font-size:25px; text-decoration: underline;'>$AccountName<br></div>Wipro Patch Compliance Report" -RightLogoString $LeftLogo
    $rpt += "<style>div.pageTitle {padding-bottom: 10px}</style>"
    $rpt += "<script src='https://cdn.jsdelivr.net/npm/chartjs-plugin-datalabels@2.0.0/dist/chartjs-plugin-datalabels.min.js'></script>"
    $rpt += Get-HTMLTabHeader -TabNames $tabarray
    $rpt += get-htmltabcontentopen -TabName $tabarray[0] -TabHeading "`n"
    #version charts
    $rpt += Get-HtmlContentOpen -HeaderText "Charts"
    $rpt += get-htmltabcontentclose -
                
    $rpt += Get-HTMLContentOpen -HeaderText "vSphere Compliance Summary"
    $rpt += Get-HTMLColumnOpen -ColumnNumber 1 -ColumnCount 3
    $rpt += '<script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/2.7.2/Chart.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.3.1/jquery.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/chartjs-plugin-datalabels@0.7.0"></script>'
    $rpt += Get-HTMLPieChart -ChartObject $Compliance_chart_vcenter -DataSet $Compliance_table_vcenter -Background @("rgb(34, 139, 34)", "rgb(199, 0, 57)")
    $rpt += Get-HTMLColumnClose
    $rpt += Get-HTMLColumnOpen -ColumnNumber 2 -ColumnCount 3
    $rpt += '<script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/2.7.2/Chart.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.3.1/jquery.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/chartjs-plugin-datalabels@0.7.0"></script>'
    $rpt += Get-HTMLPieChart -ChartObject $Compliance_chart_host -DataSet $Compliance_table_host -Background @("rgb(34, 139, 34)", "rgb(199, 0, 57)")
    $rpt += Get-HTMLColumnClose
    $rpt += Get-HTMLColumnOpen -ColumnNumber 3 -ColumnCount 3
    $rpt += $Compliance_table_html
    #$rpt += Get-HTMLPieChart -ChartObject $Compliance_chart_host -DataSet $Compliance_table_host -Background @("rgb(34, 139, 34)", "rgb(199, 0, 57)")
    $rpt += Get-HTMLColumnClose
    $rpt += Get-HTMLContentClose


    $rpt += Get-HTMLContentOpen -HeaderText "vCenter Overview"
    $rpt += Get-HTMLColumnOpen -ColumnNumber 1 -ColumnCount 3
    $rpt += '<script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/2.7.2/Chart.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.3.1/jquery.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/chartjs-plugin-datalabels@0.7.0"></script>'
    $rpt += Get-HTMLPieChart -ChartObject $PieObjectGroupType2 -DataSet $GroupTypetable2 -Background "rgb(199, 0, 57)"
    $rpt += Get-HTMLColumnClose
    $rpt += Get-HTMLColumnOpen -ColumnNumber 2 -ColumnCount 3
    $rpt += '<script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/2.7.2/Chart.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.3.1/jquery.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/chartjs-plugin-datalabels@0.7.0"></script>'
    $rpt += Get-HTMLPieChart -ChartObject $PieObjectGroupType1 -DataSet $GroupTypetable1 -Background "rgb(34, 139, 34)"
    $rpt += Get-HTMLColumnClose
    $rpt += Get-HTMLColumnOpen -ColumnNumber 3 -ColumnCount 3
    $rpt += $vcenter_table_html
    $rpt += Get-HTMLColumnClose
    
    $rpt += Get-HTMLContentClose

    $rpt += Get-HTMLContentOpen -HeaderText "ESXi Host Overview"
    $rpt += Get-HTMLColumnOpen -ColumnNumber 1 -ColumnCount 3
    $rpt += '<script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/2.7.2/Chart.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.3.1/jquery.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/chartjs-plugin-datalabels@0.7.0"></script>'
    $rpt += Get-HTMLPieChart -ChartObject $PieObjectGroupType_host1 -DataSet $GroupTypetable_host1 -Background "rgb(199, 0, 57)"
    $rpt += Get-HTMLColumnClose
    $rpt += Get-HTMLColumnOpen -ColumnNumber 2 -ColumnCount 3
    $rpt += '<script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/2.7.2/Chart.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.3.1/jquery.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/chartjs-plugin-datalabels@0.7.0"></script>'
    $rpt += Get-HTMLPieChart -ChartObject $PieObjectGroupType_host2 -DataSet $GroupTypetable_host2 -Background "rgb(34, 139, 34)"
    $rpt += Get-HTMLColumnClose
    $rpt += Get-HTMLColumnOpen -ColumnNumber 3 -ColumnCount 3
    $rpt += $host_table_html
    $rpt += Get-HTMLColumnClose
   
    $rpt += Get-HTMLContentClose
    $rpt += Get-HTMLContentClose
    $rpt += get-htmltabcontentclose

    $rpt += get-htmltabcontentopen -TabName $tabarray[1] -TabHeading "`n"
    $rpt += Get-HtmlContentOpen -HeaderText "vCenter Patch Summary"
    $rpt += Get-HtmlContentTable $vCenter_data 
    $rpt += Get-HTMLContentClose
    $rpt += get-htmltabcontentclose

    $rpt += get-htmltabcontentopen -TabName $tabarray[2] -TabHeading "`n"
    $rpt += Get-HtmlContentOpen -HeaderText "ESXi Host Patch Summary"
    $rpt += Get-HtmlContentTable $VMHost_data 
    $rpt += Get-HTMLContentClose
    $rpt += get-htmltabcontentclose

    $rpt += get-htmltabcontentopen -TabName $tabarray[3] -TabHeading "`n"
    $rpt += Get-HtmlContentOpen -HeaderText "Hardware Compliance Summary"
    $rpt += Get-HtmlContentTable $VMHardware_data 
    $rpt += Get-HTMLContentClose
    $rpt += get-htmltabcontentclose
    $rpt += Get-HTMLClosePage    


    $Day = (Get-Date).Day
    $Month = (Get-Date).Month
    $Year = (Get-Date).Year
    $time = (Get-Date -Format "hhmmss")
    $VC_REPORT_NAME = ($vCenter_data.'vCenter Name' | Select -First 1)
    $ReportName = ("Wipro Patch Compliance Report" + "_$Day" + "-" + "$Month" + "-" + "$Year" + "-" + $time+"-"+$VC_REPORT_NAME)
    $ReportSavePath = "$export_path"
    $out = $(Save-HTMLReport -ReportContent $rpt -ShowReport -ReportName $ReportName -ReportPath $ReportSavePath) | Out-Null
    #Write-PodeHost "Success", $out
}catch{
    Write-PodeHost "Failure", $_
}