<#

    MS project LogTime

#> 



# Add config
Import-Module -Name $PSScriptRoot\config\logtimeconfig.psm1

# Add lib
Import-Module -Name $PSScriptRoot\modules\logtimelib.psm1

# Add assemblies
Add-Type -AssemblyName PresentationFramework, System.Drawing, System.Windows.Forms


#$WatchJob = Start-Job -ScriptBlock $WatchScriptBlock -ArgumentList $Drive , $FolderPath , $LogFolder
#$WatchJob = Start-Job -InitializationScript $WatchScriptInitBlock -ScriptBlock $WatchScriptBlock -ArgumentList $Drive , $FolderPath , $LogFolder, $LibFolder

#$WebServerJob = Start-Job -ScriptBlock $WebServerScriptBlock -ArgumentList $url , $LogFolder


# Extract icon from PowerShell to use as the NotifyIcon
#$icon = [System.Drawing.Icon]::ExtractAssociatedIcon("$pshome\powershell.exe")

$image = [System.Drawing.Image]::FromFile("$PSScriptRoot\icon.png")
$bitmap = [System.Drawing.Bitmap]$image
$icon = [System.Drawing.Icon]::FromHandle($bitmap.GetHicon());

# Create XAML form in Visual Studio, ensuring the ListView looks chromeless
[xml]$xaml = '<Window
xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
Name="window" WindowStyle="None" Height="200" Width="400"
ResizeMode="NoResize" ShowInTaskbar="False">
</Window>'

# Turn XAML into PowerShell objects
$window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
$xaml.SelectNodes("//*[@Name]") | ForEach-Object { Set-Variable -Name ($_.Name) -Value $window.FindName($_.Name) -Scope Script }



# Create notifyicon, and right-click -> Exit menu
$notifyicon = New-Object System.Windows.Forms.NotifyIcon
$notifyicon.Text = "Disk Usage"
$notifyicon.Icon = $icon
$notifyicon.Visible = $true

#$notifyicon.showballoontip(10, 'Hello Miki', 'Ceci est une notification de Ms Miko', [system.windows.forms.tooltipicon]::None)

$menuitem = New-Object System.Windows.Forms.MenuItem
$menuitem.Text = "Exit"

$contextmenu = New-Object System.Windows.Forms.ContextMenu
$notifyicon.ContextMenu = $contextmenu
$notifyicon.contextMenu.MenuItems.AddRange($menuitem)


function Show-JobProgress {
    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Job[]]
        $Job
        ,
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.Windows.Forms.NotifyIcon]
        $Notify
    )

    Process {
        $Job.ChildJobs | ForEach-Object {
            if (-not $_.Progress) {
                return
            }

            $LastProgress = $_.Progress
           

            $LastProgress | Group-Object -Property Activity,StatusDescription | ForEach-Object {
                $_.Group | Select-Object -Last 1

            } | ForEach-Object {
                $ProgressParams = @{}
                if ($_.Activity          -and $_.Activity          -ne $null) { $ProgressParams.Add('Activity',         $_.Activity) }
                if ($_.StatusDescription -and $_.StatusDescription -ne $null) { $ProgressParams.Add('Status',           $_.StatusDescription) }
                if ($_.CurrentOperation  -and $_.CurrentOperation  -ne $null) { $ProgressParams.Add('CurrentOperation', $_.CurrentOperation) }
                if ($_.ActivityId        -and $_.ActivityId        -gt -1)    { $ProgressParams.Add('Id',               $_.ActivityId) }
                if ($_.ParentActivityId  -and $_.ParentActivityId  -gt -1)    { $ProgressParams.Add('ParentId',         $_.ParentActivityId) }
                if ($_.PercentComplete   -and $_.PercentComplete   -gt -1)    { $ProgressParams.Add('PercentComplete',  $_.PercentComplete) }
                if ($_.SecondsRemaining  -and $_.SecondsRemaining  -gt -1)    { $ProgressParams.Add('SecondsRemaining', $_.SecondsRemaining) }

                $Notify.showballoontip(10, 'Hello Miki', $_.StatusDescription, [system.windows.forms.tooltipicon]::None)

                #Write-Progress @ProgressParams
            }
        }
    }
}

#$notify = {
#    $notifyicon.showballoontip(10, 'Hello Miki', 'Ceci est une notification de Ms Miko', [system.windows.forms.tooltipicon]::None)
#}

#[Action]$action = {
#   Out-File -FilePath "$LogFolder\app.log" -Append -InputObject "entree1"
   #$notifyicon.showballoontip(10, 'Hello Miki', 'Ceci est une notification de Ms Miko', [system.windows.forms.tooltipicon]::None)
#}

$WatchJob = Start-Job -InitializationScript $WatchScriptInitBlock -ScriptBlock $WatchScriptBlock -ArgumentList $Drive , $FolderPath , $LogFolder, $LibFolder

#Get-Job $WatchJob | Receive-Job
<#
#Timer Event
$timer = New-Object timers.timer
# 1 second interval
$timer.Interval = 1000
#Create the event subscription
Register-ObjectEvent -InputObject $timer -EventName Elapsed -SourceIdentifier Timer.Output -Action {
    Write-Host "1 second has passed"
}
$timer.Enabled = $True
#>

#$WatchJob.ChildJobs[0].Progress

# Add a left click that makes the Window appear in the lower right
# part of the screen, above the notify icon.
$notifyicon.add_Click( {

        if ($_.Button -eq [Windows.Forms.MouseButtons]::Left) {
            # reposition each time, in case the resolution or monitor changes
            $window.Left = $([System.Windows.SystemParameters]::WorkArea.Width - $window.Width)
            $window.Top = $([System.Windows.SystemParameters]::WorkArea.Height - $window.Height)
            $window.Show()
            $window.Activate()
        }
    })

# Close the window if it's double clicked
$window.Add_MouseDoubleClick( {
        $window.Hide()
    })

# Close the window if it loses focus
$window.Add_Deactivated( {
        $window.Hide()
    })

# When Exit is clicked, close everything and kill the PowerShell process
$menuitem.add_Click( {
        $notifyicon.Visible = $false
        $window.Close()

        #Stop-WebServer $WebServerJob

        Stop-Job $WatchJob
        Remove-Job $WatchJob -Force
    
        Stop-Process $pid
    })

<#
while (@('Completed', 'Failed') -notcontains $WatchJob.State) {
    Show-JobProgress -Job $WatchJob -Notify $notifyicon
}
#>

# Make PowerShell Disappear
$windowcode = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
$asyncwindow = Add-Type -MemberDefinition $windowcode -name Win32ShowWindowAsync -namespace Win32Functions -PassThru
$null = $asyncwindow::ShowWindowAsync((Get-Process -PID $pid).MainWindowHandle, 0)

# Force garbage collection just to start slightly lower RAM usage.
[System.GC]::Collect()

# Create an application context for it to all run within.
# This helps with responsiveness, especially when clicking Exit.
$appContext = New-Object System.Windows.Forms.ApplicationContext
[void][System.Windows.Forms.Application]::Run($appContext)





