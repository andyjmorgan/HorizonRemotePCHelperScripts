function Get-HVUserOrSummaryView{
    param(
    $userid,
    $ExtensionData
    )
    $query_service_helper = New-Object VMware.Hv.QueryServiceService
    $userQuery = New-Object VMware.Hv.QueryDefinition
    $userQuery.queryEntityType = 'ADUserOrGroupSummaryView'


    $userQueryFilter = New-Object VMware.Hv.QueryFilterEquals
    $userQueryFilter.MemberName = 'base.loginName'
    $userQueryFilter.Value = $userid


    $groupQueryFilter = New-Object VMware.Hv.QueryFilterEquals
    $groupQueryFilter.MemberName = 'base.group'
    $groupQueryFilter.Value = $false

    $groupQueryFilterAnd = New-Object VMware.Hv.QueryFilterAnd
    $groupQueryFilterAnd.filters += $userQueryFilter
    $groupQueryFilterAnd.filters += $groupQueryFilter

    $userQuery.Filter = $groupQueryFilterAnd

    $query_service_helper.QueryService_Query($ExtensionData, $userQuery).results[0]
   
}
function Get-ComputerDetails{

 param(
        [string]$machineName,
        $credentials
    )
    Invoke-Command -ComputerName $machineName -Credential $credentials -ScriptBlock{
        $operatingsystem = (gwmi win32_operatingsystem).caption
                $edition = Get-ItemPropertyValue -Path "hklm:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name CompositionEditionID
                $release = Get-ItemPropertyValue -Path "hklm:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name releaseid
    
    
    $returnObject = New-Object -TypeName psobject -Property @{    
                    OperatingSystem = $operatingsystem
                    edition = $edition
                    release = $release
                }
    $returnObject
    }
}
function Get-HVRegisteredMachine{
    param(
        $machineName,
        $extensionData
    )
        $query_service_helper = New-Object VMware.Hv.QueryServiceService
        $Machinequery = New-Object VMware.Hv.QueryDefinition
        $Machinequery.queryEntityType = 'RegisteredPhysicalMachineInfo'
        $MachineQueryFilter = New-Object VMware.Hv.QueryFilterStartsWith
        $MachineQueryFilter.MemberName = 'machineBase.name'
        $MachineQueryFilter.Value = "$($machineName)."
        $Machinequery.Filter = $MachineQueryFilter
        $query_service_helper.QueryService_Query($ExtensionData, $Machinequery).Results[0]
}
function Get-HVDesktopSummaryView{
    param(
        $desktopname,
        $extensiondata
    )
    $query_service_helper = New-Object VMware.Hv.QueryServiceService

    $desktopQuery = new-object VMware.Hv.QueryDefinition
    $desktopQuery.QueryEntityType = 'DesktopSummaryView'

    $desktopQueryFilter = New-Object VMware.Hv.QueryFilterEquals
    $desktopQueryFilter.MemberName = 'desktopSummaryData.name'
    $desktopQueryFilter.Value = $desktopName

    $desktopQuery.Filter = $desktopQueryFilter


    [VMware.Hv.DesktopSummaryView]($query_service_helper.QueryService_Query($extensiondata, $desktopQuery)).results[0]
}
function Get-HVMachineByPool{
    param($desktopid,
    $machineName,
    $extensionData
    )

    $query_service_helper = New-Object VMware.Hv.QueryServiceService

    $newdesktopQuery = new-object VMware.Hv.QueryDefinition
    $newdesktopQuery.QueryEntityType = 'MachineNamesView'
    $newdesktopQueryFilterAnd = New-Object VMware.Hv.QueryFilterAnd
    
    $newdesktopQueryFilter = New-Object VMware.Hv.QueryFilterEquals
    $newdesktopQueryFilter.MemberName = 'base.desktop'
    $newdesktopQueryFilter.Value = $desktopid

    $MachineQueryFilter = New-Object VMware.Hv.QueryFilterStartsWith
    $MachineQueryFilter.MemberName = 'base.name'
    $MachineQueryFilter.Value = "$($machineName)."

    $newdesktopQueryFilterAnd.Filters += $newdesktopQueryFilter
    $newdesktopQueryFilterAnd.Filters += $MachineQueryFilter

    $newdesktopQuery.Filter = $newdesktopQueryFilterAnd
    $query_service_helper.QueryService_Query($ExtensionData, $newdesktopQuery).results[0]
}
function Add-HVUserToManualMachine{
    param(
    $userid,
    $machineid,
    $hvServer
    )

    $mapEntry = New-Object VMware.Hv.MapEntry
    $mapEntry.Key = "base.user"
    $mapEntry.Value = $userid
    $hvserver.ExtensionData.Machine.Machine_Update($machineid, $mapEntry)

}
function Get-ComputerPrimaryUser{
    param(
        [string]$machineName,
        $credentials
    )
    Invoke-Command -ComputerName $machineName -Credential $credentials -ScriptBlock{
    $logs = get-eventlog system -source Microsoft-Windows-Winlogon -InstanceId 7001
    $users =@()
    $logs | % {
        try{
            $users += (new-object System.Security.Principal.SecurityIdentifier $_.replacementstrings[1]).Translate([System.Security.Principal.NTAccount])
        }
        catch{
            write-warning "Could not translate a sid"
        }
    } 
    $primaryUser = ($users | Group-Object | sort count -Descending)[0].Name

    $returnObject = New-Object psobject -Property @{
        primaryuser = $primaryUser
    }
    $returnObject
    }
}
function Set-ComputerPowerPolicy{
    param(
        [string]$machineName,
        $credentials
    )
    Invoke-Command -ComputerName $machineName -Credential $credentials -ScriptBlock{
    $oldValue = gwmi -namespace root\cimv2\power -Class Win32_PowerPlan | ?{$_.isactive} | select elementName
    Start-Process -filepath "powercfg.exe" -argumentlist "/setactive e9a42b02-d5df-448d-aa00-03f14749eb61" -Wait
    $newValue = gwmi -namespace root\cimv2\power -Class Win32_PowerPlan | ?{$_.isactive} | select elementName 
    $returnObject = New-Object psobject -Property @{
        OldPlan = $oldValue.elementName
        NewPlan = $newValue.elementName
    }
    $returnObject
    }
}
function copy-HorizonAgentFile{
[CmdletBinding(SupportsShouldProcess=$true)]
Param(
    [string]$filepath,
    [string]$machineName
)
    
    if(test-path $filepath){
        Write-Verbose "Found source file"
        $file = Get-Item $filepath
        $fileName = $file.Name
        Write-Verbose "Testing connection"
        if(Test-Connection $machineName -Count 1){
            Write-Verbose "Connection Found"
            $adminShare ="\\$($machineName)\admin$" 
            $tempPath = "$($adminShare)\temp"
            Write-Verbose "Testing Admin share: $tempPath"
            if(test-path $adminShare){
                Write-Verbose "Admin Share Accessible"
                $tempFilePath = "$($tempPath)\$($filename)"
                Write-Verbose "Copying $filepath to $tempfilePath"
                copy-item $filepath -Destination $tempFilePath -Force
                Write-Verbose "Copy complete"
                if(test-path $tempFilePath){
                    Write-Verbose "Destination file created successfully"
                    $true
                }
                else{
                    write-warning "failed to copy the file to the destination"
                }
            }
            else{
            
                Write-Warning "Failed to open the remote machines admin$ share"
                $false
            }

        }
        else{
            Write-Warning "Failed to communicate with the remote machine"
            $false
        }
    }
    else{
        Write-Warning "Failed to find source file $filepath"
        $false
    }
}
function install-HorizonAgent{
    [CmdletBinding(SupportsShouldProcess=$true)]   
    param(
        [string]$machineName,
        [string]$filepath,
        $credentials,
        [string]$ConnectionServerName,
        [string]$ConnectionServerUserName,
        [string]$ConnectionServerPassword
    )

    $returnObject = New-Object psobject
    $file = Get-Item $filepath
    $fileName = $file.Name
    Write-Verbose "Attempting to install $filePath on $machineName"
    try{
            $arguments = $filename, $ConnectionServerName, $ConnectionServerUserName, $ConnectionServerPassword
            $returnObject = Invoke-Command -ComputerName $machineName -Credential $credentials -ArgumentList $arguments -ScriptBlock{
                param(
                    [string]$fileName, 
                    [string]$ConnectionServerName,
                    [string]$ConnectionServerUserName,
                    [string]$ConnectionServerPassword
                )
                $VDMRegPath = "hklm:\SOFTWARE\VMware, Inc.\VMware VDM"
                $returnObject = New-Object -TypeName psobject -Property @{    
                    PrimaryUser = 'unknown'
                    InstallResult = $false
                    ReturnCode = -1
                    VersionInstalled = "unknown"
                    FailureReason = ""
                    OperatingSystem = "unknown"
                    edition = "unknown"
                    release = "unknown"
                }

                $returnObject.operatingsystem = (gwmi win32_operatingsystem).caption
                $returnObject.edition = Get-ItemPropertyValue -Path "hklm:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name CompositionEditionID
                $returnObject.release = Get-ItemPropertyValue -Path "hklm:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name releaseid
                $tempFilePath = [System.Environment]::GetEnvironmentVariable('TEMP','Machine')
                if(test-path $tempFilePath){
                    $agentPath = "$($tempFilePath)\$($fileName)"
                    Write-Verbose "Attempting to find agent installer in $agentPath"
                    if(test-path $agentPath){
                        Write-Verbose "Agent found, starting installer"
                        
                        $process = (Start-Process -FilePath $agentPath -ArgumentList "/s /v""/qn VDM_VC_MANAGED_AGENT=0 VDM_SERVER_NAME=$($connectionServerName) VDM_SERVER_USERNAME=$($connectionServerUserName) VDM_SERVER_PASSWORD=$($connectionServerPassword) REBOOT=Reallysuppress"""  -Wait -PassThru)
                        $returnobject.returncode = $process.ExitCode
                        
                        Write-Verbose "Process exit code = $($process.exitcode)"
                        if(Test-Path $VDMRegPath){
                            $productVersion = Get-ItemPropertyValue -Path $VDMRegPath -Name "ProductVersion";
                            write-verbose "Installation Detected version: ($productVersion)"
                            $returnobject.VersionInstalled = $productVersion

                            #set power configuration to ultimate performance (windows 10)
                            Start-Process -filepath "powercfg.exe" -argumentlist "/setactive e9a42b02-d5df-448d-aa00-03f14749eb61" -Wait


                            # Get all users who have logged into this machine, select the most frequent logged in user
                            $logs = get-eventlog system -source Microsoft-Windows-Winlogon -InstanceId 7001
                            $users =@()
                            $logs | % {
                                try{
                                    $users += (new-object System.Security.Principal.SecurityIdentifier $_.replacementstrings[1]).Translate([System.Security.Principal.NTAccount])
                                }
                                catch{
                                    write-warning "Could not translate a sid"
                                }
                            } 
                            $primaryUser = ($users | Group-Object | sort count -Descending)[0].Name
                            $returnObject.PrimaryUser = $primaryUser
                            $returnObject.InstallResult = $true
                        }
                        else{
                            Write-warning "Agent VDM registry key missing, assumed installer failed"
                            $returnobject.failurereason = "Agent VDM registry key missing, assumed installer failed"
                            $returnObject.InstallResult = $false
                        }
                    }
                    else{
                        Write-Warning "Failed to find the agent in the temp directory on remote machine"
                        $returnobject.failurereason = "Failed to find the agent in the temp directory on remote machine"
                        $returnObject.InstallResult = $false 
                    }
                }
                else{
                    Write-Warning "Failed to find the temp directory on remote machine"
                    $returnobject.failurereason = "Failed to find the temp directory on remote machine"
                    $returnObject.InstallResult = $false
                }
                $returnObject
        }
        
        $returnObject
    }
    catch{
        Write-Warning "Failed to remote to the machine."
        $returnObject = New-Object -TypeName psobject -Property @{    
                    failurereason = "Failed to remote to the machine."
                    PrimaryUser = 'unknown'
                    InstallResult = $false
                    ReturnCode = -1
                    VersionInstalled = "unknown"
                    OperatingSystem = "unknown"
                    edition = "unknown"
                    release = "unknown"
        }
        $returnObject
    }
}

#### Set your variables here!

$filePath = "C:\Users\andy\source\repos\horizonpush\VMware-Horizon-Agent-x86_64-7.11.0-15238678.exe"

$PowerShellRemotingCreds = get-credential -UserName "lab\administrator" -Message "Enter psremoting credentials"

$ConnectionServerName="connectionserver.lab.local"
$ConnectionServerUserName="domain\username"
$ConnectionServerPassword="password"

#$TargetDesktopPool = "manualdesktop"


$computers=@("m10d1","m10d2")


#### This will copy and deploy the horizon agent out to machines
$results =@()
foreach($computer in $computers){
    
    $copyResult = copy-HorizonAgentFile -filepath $filePath -machineName $computer -Verbose
    if($copyResult){
        $results += install-HorizonAgent -filepath $filePath -machineName $computer -credentials $PowerShellRemotingCreds -ConnectionServerName $ConnectionServerName -ConnectionServerUserName $ConnectionServerUserName -ConnectionServerPassword $ConnectionServerPassword -Verbose
    }
    else{
        Write-Warning "failed to copy file to $computer"
    }
}



##### If you just want to get the primary user of a machine, use this:
$remoteUsersResults=@()
foreach($computer in $computers){
    $remoteUser = Get-ComputerPrimaryUser -machineName $computer -credentials $PowerShellRemotingCreds
    $remoteUsersResults += $remoteUser
}

#### If you just want to set the power plan, use this:
$powerplanResults =@()
foreach($computer in $computers){
    $powerplan = Set-ComputerPowerPolicy -machineName $computer -credentials $PowerShellRemotingCreds
    $powerplanResults += $powerplan
}

#### If you just want to get the remote operating system details, use this:
$osResults =@()
foreach($computer in $computers){
    $detail = Get-ComputerDetails -machineName $computer -credentials $PowerShellRemotingCreds
    $osResults += $detail
}

##### export results to csv for Chris Halsteads's tool:
$results | ? {$_.installresult} | select pscomputername, primaryuser | export-csv -NoTypeInformation machines.csv



#### Add results to horizon via powershell (requires PowerCLI)
# $hvserver = Connect-HVServer $ConnectionServerName -Credential $PowerShellRemotingCreds
# $TargetDesktop = Get-HVDesktopSummaryView -desktopname $TargetDesktopPool -extensiondata $hvserver.ExtensionData

# foreach($result in $results){
#    if($result.InstallResult){
#         if($result.PrimaryUser -ne $null){
#             $user = $result.PrimaryUser
#             $machineName = $result.PSComputerName
#             $userName = $result.PrimaryUser.Split("\")[1]
#             if($userName.Length -gt 0){
#                 $userToAdd = Get-HVUserOrSummaryView -userid $userName -ExtensionData $hvserver.ExtensionData
#                 if($userToAdd -ne $null){
#                     $machineToAdd  = Get-HVRegisteredMachine -machineName $machineName -extensionData $hvserver.ExtensionData
#                     if($machineToAdd -ne $null){
#                         $hvserver.ExtensionData.Desktop.Desktop_AddMachinesToManualDesktop($targetdesktop.Id,$machineToAdd.Id)
#                         #this can fail if you request it immediately
#                         start-sleep 5
#                         $newMachinePostAdd = Get-HVMachineByPool -desktopid $TargetDesktop.Id -machineName $machineName -extensionData $hvserver.ExtensionData
#                         if($newMachinePostAdd -ne $null){
#                             Add-HVUserToManualMachine -userid $userToAdd.Id -machineid $newMachinePostAdd.Id -hvServer $hvserver
#                             $entitlement = New-Object VMware.Hv.UserEntitlementBase
#                             $entitlement.Resource = $TargetDesktop.Id
#                             $entitlement.UserOrGroup = $userToAdd.Id
#                             $hvserver.ExtensionData.UserEntitlement.UserEntitlement_CreateUserEntitlements($entitlement)    
#                         }
#                         else{
#                             Write-Warning "Could not add find the new machine ($($result.PSComputerName)) after adding it to the pool"
#                         }                       
#                     }
#                     else{
#                         Write-Warning "Could not add Machine $($result.PSComputerName) as the machine could not be found in horizon"
#                     }
#                 }
#                 else{
#                     Write-Warning "Could not add machine: $($result.PSComputerName) as the primary user could not be found in horizon"
#                 }
#             }
#             else{
#                 Write-Warning "Could not add machine: $($result.PSComputerName) as the primary user name could not be split"
#             }
#         }
#         else{
#             Write-Warning "Could not add machine: $($result.psComputername) as the primary user was not found"
#         }
#    }
#    else{
#     Write-Warning "Machine install failed"
#    }

# }






