Set-PodeWebHomePage -Layouts @(
    New-PodeWebHero -Title 'vSphere Patch Compliance Tool' -Message 'We provides insights of vCenter and ESXi host patch levels and hardware challenges prior to a vSphere upgrade.' -Content @(
    )

    New-PodeWebContainer -Content @(
        New-PodeWebImage -Source "/static/logo.png" -Alignment Center
    )

)