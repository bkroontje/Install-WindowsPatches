#-------------------------------------------------------------------------
# Author      : bkroontje
# FileName    : Install-WindowsPatches.ps1
# Version     : 1.0
# Revision    :
# Created     : February 1, 2020
# Description : Powershell Script that automates Windows Patching download and installation process:
# Remarks     : Text file with computer names should not contain any "White space", "line feed" or "new line" characters at the end of the file. This creates small bug in PSWindowsUpdate Module and arrayList
#             : 
#             : 
#             :
# Prerequisite: This script depends on a publicaly available module called PSWindowsUpdate. This Module must be downloaded and installed on all machine that will rely on the script.
#             : Each Server has to be configured for remote Unrestricted before script can be run
#             : Each server need to be added to your RSAT server winrm trusted hosts list.
#-------------------------------------------------------------------------

#Asks user to enter in file path of server_list
$server_list = Read-Host "file path of server list"

#Converts textfile of computer names to an array then to an arraylist named $complist
[System.Collections.ArrayList]$complist = @((Get-Content -Path $server_list))


#leave line below for testing purposes
#[System.Collections.ArrayList]$complist = @((Get-Content -Path "<FilePathHere>")) 

#verbose switch
$VerbosePreference = "continue"


function Get-WindowsUpdates 

    <#
        .SYPNOPSIS
            Searches remote server for the number of updates available and returns the total back to main

        .DESCRIPTION
            This function uses the Get-WUList command from PSWindows updates to look for the available updates for the remote server. 
            The number of available udpates are counted and returned back to main of the script

        .PARAMATER $computer
             Holds the name of the current computer being scanned for updates from the server list

        .PARAMATER $update
            An array that contains the list of available updates by the KB number

        .Parameter $update_count
            The count of the total number of updates based on the number of updates stored in the $update array
    #>
{
    
    [CmdletBinding()]
    param 
    (
        [Parameter(Mandatory=$true)]
        [String]$computer
    )

    $updates = Invoke-Command -ComputerName $computer -ScriptBlock {Get-WUList}
    $update_count = ($updates.kb).count
    return $update_count
}


function Install-WindowsUpdates 
    <#
        .SYPNOPIS
            Function exucutes command to start patch install process on remote machine

        .DESCRIPTION
            The function executes the patch installation process on the remote machine using the  PSWindowsUpdate command Get-WUInstall.
            The command tells the machine to accept and install all available WSUS approved updates without initializing reboot sequence. Download 
            times may vary pending on size of update, OS running on server, and download speeds.

        .PARAMATER $computer
            Holds the name of the current computer being scanned for updates from the server list
    #>
{
    param
    (
        [CmdletBinding()]
        [String]$computer
    )

    Invoke-WUInstall -ComputerName $computer -Script {impo PSWindowsUpdate; Get-WUInstall -IgnoreReboot -AcceptAll} -Confirm:$false    
}


# While loop that determines the size of the arrayList and will continue to loop until the arrayList reaches a size of 0
while($complist.length -gt 0) 
{

<#
    For each computer at index $i: 
    check for and count available updates then execute installation process. 
    If 0 updates are available delete computer from $complist at index $i and continue through for loop
#>
    for ($i = 0; $i -lt $complist.count; $i++) 
    {
        $update_count = Get-WindowsUpdates($complist[$i])
        $computer = $complist[$i]
        Write-Verbose "$update_count updates available for $computer"
        if($update_count -ge 1) 
        {
            Install-WindowsUpdates($complist[$i])
        } else 
        {
            $computer = $complist[$i]
            Write-Verbose "$computer is up to date"
            $complist.RemoveAt($i)
            $i--
        }
    }

 <#
    if $complist length is greater than 0 (i.e. still computers in arraylist pause program for 1 hour)
    Pausing program for one hour allows time for all computers in list to finish donwloading availabile patches
    After 1 hour all computers in list will be rebooted. After reboot script will return to the top of while loop
    and repeat process until $complist is empty.
 #>

    if($complist.length -gt 0) 
    {
        Write-Verbose "Starting 1 hour Sleep interval while computers download patches"
        Start-Sleep -Seconds 3600 -verbose
        Restart-Computer $complist -wait -force -verbose
    }
   

    
}

Write-Verbose "Script is finished"

