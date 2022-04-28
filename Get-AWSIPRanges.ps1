Function Get-AWSIPRanges {

    New-Variable -Force -Name:'IPAddresses' -Value:(New-Object -TypeName:'System.Collections.ArrayList')
    @('WebRequest', 'IPRangesJson') | ForEach-Object {
        New-Variable -Force -Name:$_ -Value:$Null
    }

    Set-Variable -Name:'WebRequest' -Value:(
        Invoke-WebRequest -Uri:'https://ip-ranges.amazonaws.com/ip-ranges.json' -ErrorAction:'Stop'
    )

    If ([Int]$WebRequest.StatusCode -eq 200) {
        If (-NOT ([String]::IsNullOrEmpty($WebRequest.Content))) {
            Write-Debug -Message:'WebRequest has content.'

            Try {
                $IPRangesJson = $WebRequest.Content |ConvertFrom-Json
            } catch {
                Throw $_
            }

            ForEach ($Prefix in $IPRangesJson.prefixes) {
                $_IPAddress = [PSCustomObject]@{
                    IPVer = $Null
                    IPAddress = $Null
                    Region = $Prefix.region
                    Service = $Prefix.service
                    NetworkBorderGroup = $Prefix.network_border_group
                    Type = 'Commercial'
                }

                Write-Debug -Message:'Determining IP Address family.'
                If ($prefix.PSOBject.Properties.name.Contains('ip_prefix')) {
                    $_IPAddress.IPAddress = $Prefix.ip_prefix
                    $_IPAddress.IPVer = 'IPv4'
                } ElseIf ($prefix.PSOBject.Properties.name.Contains('ipv6_prefix')) {
                    $_IPAddress.IPAddress = $Prefix.ipv6_prefix
                    $_IPAddress.IPVer = 'IPv6'
                } Else {
                    Write-Warning -Message:'Unable to determine IP version information.'
                    Continue
                }
                Write-Debug -Message:"IP Address family: $($_IPAddress.IPVer); IPAddress: $($_IPAddress.IPAddress)"

                Write-Debug -Message:'Determine if Commercial or Government Services.'
                If (($Prefix.region -like '*-gov-*') -or ($prefix.NetworkBorderGroup -like '*-gov-*')) {
                    $_IPAddress.Type = 'Government'
                }

                #Add IPAddress to IPAddresses
                $Null = $IPAddresses.Add($_IPAddress)

                Clear-Variable -Name:'_IPAddress'
            }
        } Else {
            Write-Error -Message:'WebRequest has no output.'
            Throw
        }
    } Else {
        Write-Error -Message:"Invoke Web request failed with error code '$([Int]$WebRequest.StatusCode)'."
        Exit
    }

    Return $IPAddresses
}

Get-AWSIPRanges | Where-Object -FilterScript: {
    ($_.Type -eq 'Government') -AND ($_.IPVer -eq 'IPv4')
} |Format-Table -AutoSize
