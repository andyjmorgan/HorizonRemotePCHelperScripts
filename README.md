# Horizon Remote PC Helper Scripts
 
 The following repo is a library of scripts to help push, report and identify remote machines with the aim to add the machines to a Horizon Manual pool for remote access.
 
 This script has been primarily written for Windows 10 endpoint targets and requires Powershell Remoting (invoke-command) in order to perform the queries.
 
 This script can do all or some of the required tasks, depending on what you need.

# Deploying the agent to remote machines:

This script will do the following:

1: Copy the agent file you specify to the admin$ share on the remote machine.

2: Install the Agent using powershell remoting in manual machine mode.

3: Set the power policy to maximum performance

4: Determine the primary user of the machine, as the user whom has logged in most frequently.

5: Determine the operating system, version and edition.

6: return all of these details (along with the exit code & version of the installed agent).

# Settings your variables:
 
the following variables are required in order to use the script for deployment, the names are self explanatory and please change them before attempting to use the tool:


```powershell
$filePath = "C:\Users\andy\source\repos\horizonpush\VMware-Horizon-Agent-x86_64-7.11.0-15238678.exe"
$PowerShellRemotingCreds = get-credential -UserName "lab\administrator" -Message "Enter psremoting credentials"
$ConnectionServerName="connectionserver.lab.local"
$ConnectionServerUserName="domain\username"
$ConnectionServerPassword="password"
```

# Running the script:

The following lines of the script will push the agent and perform the install, passing the results back into an object you can enumerate later. The $computers array, can be retrieved from any source you like, such as an AD query, this array will be used to deploy the agent to the listed machines:
```PowerShell
$computers=@("m10d1","m10d2")

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
```

# Viewing the results:

Upon completion, you can review the $results object, it will appear similar to below:
```PowerShell
InstallResult    : True
release          : 1903
FailureReason    :
OperatingSystem  : Microsoft Windows 10 Enterprise
ReturnCode       : 3010
edition          : Enterprise
VersionInstalled : 7.11.0
PrimaryUser      : M10D1\Administrator
PSComputerName   : m10d1
```

In the above example, the deployment was successful, the primary user is m10d1\Administrator and the machine requires a restart (3010 exit code).

From here, you could export the results to a CSV file named machines.csv, to be used in Chris Halsteads utility as follows:

$results | ? {$_.installresult} | select pscomputername, primaryuser | export-csv -NoTypeInformation machines.csv

# Just getting the primary user:

If you simply want to get the primary user, using the $computers array above, you can use the following snippet in the script:

```powershell
$remoteUsersResults=@()
foreach($computer in $computers){
    $remoteUser = Get-ComputerPrimaryUser -machineName $computer -credentials $PowerShellRemotingCreds
    $remoteUsersResults += $remoteUser
}
```

this returns: 

```powershell
primaryuser         PSComputerName RunspaceId
-----------         -------------- ----------
M10D1\Administrator m10d1          ce72d988-cf08-4fcf-b294-3c3e43ca3ad6
```


# Just setting the power policy: (windows 10 only)

If you simply want to set the power policy, using the $computers array above, you can use the following snippet in the script:

```powershell
$powerplanResults =@()
foreach($computer in $computers){
    $powerplan = Set-ComputerPowerPolicy -machineName $computer -credentials $PowerShellRemotingCreds
    $powerplanResults += $powerplan
}
```

this returns:

```powershell
OldPlan        : Ultimate Performance
NewPlan        : Ultimate Performance
PSComputerName : m10d1
RunspaceId     : ca19cfb5-a1b3-4df9-989b-b98fa6d4711d
```

# Just Getting the remote machines operating system details:

If you simply want to get the operating system details, using the $computers array above, you can use the following snippet in the script:

```powershell
$osResults =@()
foreach($computer in $computers){
    $detail = Get-ComputerDetails -machineName $computer -credentials $PowerShellRemotingCreds
    $osResults += $detail
}
```

This Returns:

```powershell
edition         : Enterprise
release         : 1903
OperatingSystem : Microsoft Windows 10 Enterprise
PSComputerName  : m10d1
RunspaceId      : 2e924fe8-a7b6-4547-ba66-19cbb09619c7
```
