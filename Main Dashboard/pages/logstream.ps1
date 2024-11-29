Add-PodeWebPage -Name "Logstream" -Title "Logstream" -Icon "post-outline" -ScriptBlock {
   
    $path = Join-Path (Get-PodeServerPath) "logs"
    $files = (Get-ChildItem -Path $path).Name

    New-PodeWebForm -Name "Select File" -Content @(
        New-PodeWebSelect -Name select -Options $files
    ) -ScriptBlock {
        Move-PodeWebPage -Name "logstream" -DataValue $WebEvent.Data['select']
        $WebEvent.Data['select'] | Out-Default
    }

    if ($WebEvent.Query['Value'])
    {
        New-PodeWebFileStream -Name "stream" -Url "/logstream/$($WebEvent.Query.Value)"
    }

} -Hide

