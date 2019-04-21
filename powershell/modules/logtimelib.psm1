




function Stop-WebServer {
    param(
        [psobject]$WebServer,
        [string]$url = "http://localhost:8580/"
    )
    
    $Job = Start-Job -ScriptBlock {
        param($url)
        Start-Sleep -Seconds 1
        #The job will not exit until the httplistener listen() method is closed by calling the URL
        Invoke-RestMethod $url
    } -ArgumentList $url
    
    $WebServer | Stop-Job
        
    $Job | Remove-Job -Force
}
   





$Global:WebServerScriptBlock = {

    # PS Webserver
    
    param(
        [string] $url = 'http://localhost:8580/',
        [string] $folder
    )
    
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add($url)
    $listener.Start()
    
    while ($listener.IsListening) {
    
        $context = $listener.GetContext()
        $Request = $context.Request
        $requestUrl = $context.Request.Url
        $httpMethod = $context.Request.HttpMethod
        $response = $context.Response
    
        $localPath = $requestUrl.LocalPath
    
        if ($httpMethod -ne "POST" -Or $localPath -ne "/addurl") {
            $response.StatusCode = 404
            #$Content = "<h1>404 - Page not found</h1>"
        }
        else {
            try {
                    
                $StreamReader = [System.IO.StreamReader]::new($Request.InputStream)
                $BodyContents = $StreamReader.ReadToEnd()
                $Body = $BodyContents | ConvertFrom-Json
                $Body.url | Out-File "$folder\logurl.txt" -Append 
                    
                $Result = [PSCustomObject]@{ 
                    success = $true 
                } | ConvertTo-Json
    
                $Content = [string]$Result
            }
            catch {
    
                $err = "$($_.InvocationInfo.MyCommand.Name) : $($_.Exception.Message)"
                $err += "$($_.InvocationInfo.PositionMessage)"
                $err += "$($_.CategoryInfo.GetMessage())"
                $err += "$($_.FullyQualifiedErrorId)"
                    
                $Result = [PSCustomObject]@{ 
                    error = $err
                } | ConvertTo-Json
    
                $Content = [string]$Result
                $response.StatusCode = 500
            }
                
        }
    
        $response.ContentType = "application/json"
            
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($content)
        $response.ContentLength64 = $buffer.Length
        $response.OutputStream.Write($buffer, 0, $buffer.Length)
        $response.Close()
    
    }
    


}


$Global:WatchScriptInitBlock = {

    function GetWordDocContent {

        param(
            [string]$path,
            [string]$tmppath
        )

        $MSWord = New-Object -ComObject word.application
        $MSWord.Visible = $False
        $MSWord.Documents.Open($path, $false, $true)
         
        $filename = Split-Path $path -leaf
        $pathtxt = "$tmppath\$filename.txt"
        $MSWord.ActiveDocument.SaveAs($pathtxt, 2)

        $MSWord.ActiveDocument.Close($false)
        $MSWord.Quit()

        $file = Get-Content $pathtxt -Raw
        Remove-Item $pathtxt

        return $file
    }

    function GetDiffs {
        
        param(
            [string]$Before,
            [string]$After
        )
        
        $n = 0
        $espace = $false
        $message = 
        @"
<div style='font-size: 13px;font-family: "Courier New","Segoe UI"'>
"@
    
        $Differ = New-Object DiffPlex.Differ
        $diffBuilder = [DiffPlex.DiffBuilder.InlineDiffBuilder]::new($Differ)
        $diff = $diffBuilder.BuildDiffModel($Before, $After)
        
        foreach ($line in $diff.Lines) {
    
            if ($line.Type -eq [DiffPlex.DiffBuilder.Model.ChangeType]::Inserted -or `
                    $line.Type -eq [DiffPlex.DiffBuilder.Model.ChangeType]::Deleted -or `
                    $line.Type -eq [DiffPlex.DiffBuilder.Model.ChangeType]::Modified) {
    
                if ($espace -eq $false) {
                    if ($n -ge 1 -and $diff.Lines.Count -ge ($n - 1) -and ($diff.Lines[$n - 1].Type -ne [DiffPlex.DiffBuilder.Model.ChangeType]::Inserted `
                                -and ($diff.Lines[$n - 1].Type -ne [DiffPlex.DiffBuilder.Model.ChangeType]::Deleted))) {
                        $message += "...<br />"
                        $message += [string]$diff.Lines[$n - 1].Position + " " + [string]$diff.Lines[$n - 1].Text.Replace(" ", "&nbsp;") + "<br />"
                    }
                }
    
                $espace = $true
    
                if ($line.Type -eq [DiffPlex.DiffBuilder.Model.ChangeType]::Inserted) {
                    $message += "<span style='display:inline-block;background-color:#c0f0c0'>" + [string]$line.Position + " "
                }
                elseif ($line.Type -eq [DiffPlex.DiffBuilder.Model.ChangeType]::Deleted) {
                    $message += "<span style='display:inline-block;background-color:#fec0c0'>" + [string]$line.Position + " "
                }          
                elseif ($line.Type -eq [DiffPlex.DiffBuilder.Model.ChangeType]::Modified) {
                    $message += "<span style='display:inline-block;color:#1b92dc'>" + [string]$line.Position + " "
                }
    
                $message += $line.Text.Replace(" ", "&nbsp;") + "</span>" + "<br />"
            }
            else {
                if ($espace -eq $true) {
                    $message += [string]$line.Position + " " + $line.Text.Replace(" ", "&nbsp;") + "<br />"
                    $message += "...<br />"
                    $message += "<br />"
                    $espace = $false
                }
            }
    
            $n++
            
        }
        $message += "</div>"
    
        return $message
        
    }

}

<#
$Global:WatchScriptBlock = {

    
    param(
        [string] $Drive,
        [string] $FolderPath,
        [string] $LogFolder,
        [string] $LibFolder
    )
     
    Add-Type -Path "$LibFolder\DiffPlex.dll"
    
    $query = @"
Select * from __InstanceOperationEvent within 1
where targetInstance isa 'CIM_DataFile'
AND targetInstance.Drive = `"$Drive`" 
AND targetInstance.Path = `"$FolderPath`"
"@ 
    
    $Identifier = "LTFileMonitor" 

    $files = @{}
      
    $ActionBlock = {            
        $name = $event.SourceEventArgs.NewEvent.TargetInstance.Name
        $timeStamp = $event.TimeGenerated 
    
        $data = @{
            Date = $timeStamp
            Nom  = $name
        }


        try {
        
            if ($event.SourceEventArgs.NewEvent.__CLASS -eq "__InstanceCreationEvent") {
                $data["Operation"] = "Creation"
                #LogFile -data [PSCustomObject]$data
                #Out-File -FilePath "S:\Perso\LogTime\powershell\logfile.txt" -Append -InputObject "The file '$name' was created at $timeStamp"
                [PSCustomObject]$data | Export-Csv -Path "$LogFolder\logfile.csv" -Delimiter ";" -Append -NoTypeInformation
            } 
            elseif ($event.SourceEventArgs.NewEvent.__CLASS -eq "__InstanceModificationEvent") {
                #Out-File -FilePath "S:\Perso\LogTime\powershell\logfile.txt" -Append -InputObject "The file '$name' was modified at $timeStamp"
                $data["Operation"] = "Modification"

                if ($files.ContainsKey($name)) {
                    $oldfile = $files[$name]
                    $newfile = Get-Content $name -Raw 

                    GetDiffs -Before $oldfile -After $newfile | Out-File -FilePath "$LogFolder\diffs.html" -Append

                    $files.Remove($name)
                }
                
                $files[$name] = Get-Content $name -Raw 
                
            
                #LogFile -data [PSCustomObject]$data
                [PSCustomObject]$data | Export-Csv -Path "$LogFolder\logfile.csv" -Delimiter ";" -Append -NoTypeInformation
            }
            elseif ($event.SourceEventArgs.NewEvent.__CLASS -eq "__InstanceDeletionEvent") {
                #Out-File -FilePath "S:\Perso\LogTime\powershell\logfile.txt" -Append -InputObject "The file '$name' was deleted at $timeStamp"
                $data["Operation"] = "Suppression"
                #LogFile -data [PSCustomObject]$data
                [PSCustomObject]$data | Export-Csv -Path "$LogFolder\logfile.csv" -Delimiter ";" -Append -NoTypeInformation
            }

        }
        catch {
            $_ | Out-File -FilePath "$LogFolder\app.log" -Append
        }

        
    } 
      
    Register-WMIEvent -Query $Query -SourceIdentifier $Identifier -Action $ActionBlock  
    
    Wait-Event -SourceIdentifier $Identifier
    
    Unregister-Event -SourceIdentifier "LTFileMonitor"

}
#>

$Global:WatchScriptBlock = {
    
        
    param(
        [string] $Drive,
        [string] $FolderPath,
        [string] $LogFolder,
        [string] $LibFolder
    )
         
    Add-Type -Path "$LibFolder\DiffPlex.dll"

    Out-File -FilePath "$LogFolder\app.log" -Append -InputObject "entree1"
    
    for ($i=0;$i -lt 10;$i++) {
        $VerbosePreference = 'continue'
        Write-Progress -Activity "Progress" -Status ("Iteration: {0}" -f $i) -PercentComplete ($i)
        Start-Sleep -Seconds 5
    }
    #Add-Type -AssemblyName PresentationFramework, System.Windows.Forms

    #$notify.Invoke()
    #$notifyicon.showballoontip(10, 'Hello Miki', 'Ceci est une notification de Ms Miko', [system.windows.forms.tooltipicon]::None)
    
    
    Out-File -FilePath "$LogFolder\app.log" -Append -InputObject "entree2"

    $files = @{}
    $lastRead = [DateTime]::MinValue

    #$folder = 'E:\wamp2\www\advizeapi3' # Enter the root path you want to monitor. 
    $filter = '*.*'  # You can enter a wildcard filter here. 
    #$logfile = "S:\Perso\LogTime\powershell\logfile.txt"  # You can enter a wildcard filter here. 
         
    # In the following line, you can change 'IncludeSubdirectories to $true if required.                           
    $fsw = New-Object IO.FileSystemWatcher $FolderPath, $filter -Property @{EnableRaisingEvents = $true; IncludeSubdirectories = $true; NotifyFilter = [IO.NotifyFilters]'FileName, Size'} 
         
    # Here, all three events are registerd.  You need only subscribe to events that you need: 

    Register-ObjectEvent $fsw Created -SourceIdentifier FileCreated -Action { 
        $name = $Event.SourceEventArgs.Name 

        $filename = Split-Path "$FolderPath\$name" -leaf
        if (-not ($filename.StartsWith(".") -or $filename.StartsWith("~"))) {
            $changeType = $Event.SourceEventArgs.ChangeType 
            $timeStamp = $Event.TimeGenerated 
            $data = @{
                Date      = $timeStamp
                Nom       = "$FolderPath\$name"
                Operation = "Creation"
            }
            [PSCustomObject]$data | Export-Csv -Path "$LogFolder\logfile.csv" -Delimiter ";" -Append -NoTypeInformation
        }
    } 
 
    Register-ObjectEvent $fsw Deleted -SourceIdentifier FileDeleted -Action { 
        $name = $Event.SourceEventArgs.Name 

        $filename = Split-Path "$FolderPath\$name" -leaf
        if (-not ($filename.StartsWith(".") -or $filename.StartsWith("~"))) {
            $changeType = $Event.SourceEventArgs.ChangeType 
            $timeStamp = $Event.TimeGenerated 
            $data = @{
                Date      = $timeStamp
                Nom       = "$FolderPath\$name"
                Operation = "Suppression"
            }
            [PSCustomObject]$data | Export-Csv -Path "$LogFolder\logfile.csv" -Delimiter ";" -Append -NoTypeInformation
        }
    } 
         
    Register-ObjectEvent $fsw Renamed -SourceIdentifier FileRenamed -Action { 
        $name = $Event.SourceEventArgs.Name 
        $timeStamp = $Event.TimeGenerated 

        $filename = Split-Path "$FolderPath\$name" -leaf

        Out-File -FilePath "$LogFolder\app.log" -Append -InputObject "entree rename $filename"
        
        if ($filename.EndsWith(".docx")) {

            $lastWriteTime = $timeStamp
            if ($lastWriteTime -ne $lastRead) {

                Out-File -FilePath "$LogFolder\app.log"  -Append  -InputObject "entree5"

                if ($files.ContainsKey("$FolderPath\$name")) {
                    $oldfile = $files["$FolderPath\$name"]
                    $newfile = GetWordDocContent -path "$FolderPath\$name" -tmppath  "$LogFolder\tmp"
                    $files["$FolderPath\$name"] = $newfile

                    GetDiffs -Before $oldfile -After $newfile | Out-File -FilePath "$LogFolder\diffs.html" -Append

                    #$files.Remove("$FolderPath\$name")
                } else {
            
                    $files["$FolderPath\$name"] = GetWordDocContent -path "$FolderPath\$name" -tmppath  "$LogFolder\tmp"
                }
            } 

            $lastRead = $timeStamp
        }
    } 

    Register-ObjectEvent $fsw Changed -SourceIdentifier FileChanged -Action { 

        try {
            
            #Out-File -FilePath "$LogFolder\app.log" -Append -InputObject "entree1"

            $name = $Event.SourceEventArgs.Name 

            Out-File -FilePath "$LogFolder\app.log" -Append -InputObject "entree modif $name"
        
            $filename = Split-Path "$FolderPath\$name" -leaf

            if (-not ($filename.StartsWith(".") -or $filename.StartsWith("~"))) {

                $changeType = $Event.SourceEventArgs.ChangeType 
                $timeStamp = $Event.TimeGenerated 
                $data = @{
                    Date      = $timeStamp
                    Nom       = "$FolderPath\$name"
                    Operation = "Modification"
                }
            
                $lastWriteTime = $timeStamp
                if ($lastWriteTime -ne $lastRead) {

                    Out-File -FilePath "$LogFolder\app.log" -Append -InputObject "entree3"
                
                    if (-not $filename.EndsWith(".docx")) {

                        if ($files.ContainsKey("$FolderPath\$name")) {
                            $oldfile = $files["$FolderPath\$name"]
                            $newfile = Get-Content "$FolderPath\$name" -Raw 
                            $files["$FolderPath\$name"] = $newfile
        
                            GetDiffs -Before $oldfile -After $newfile | Out-File -FilePath "$LogFolder\diffs.html" -Append
        
                            $files.Remove("$FolderPath\$name")
                        } else {
                    
                            $files["$FolderPath\$name"] = Get-Content "$FolderPath\$name" -Raw 
                        }
                    }



                    $lastRead = $timeStamp
                }

                [PSCustomObject]$data | Export-Csv -Path "$LogFolder\logfile.csv" -Delimiter ";" -Append -NoTypeInformation
            }

        }
        catch {
            Out-File -FilePath "$LogFolder\app.log" -Append -InputObject [PSCustomObject]@ {date=(Get-Date).ToString("yyyy-MM-dd-HH.mm.ss"); Error=$_}
        }
    }
        
    Wait-Event -SourceIdentifier FileCreated
    Wait-Event -SourceIdentifier FileDeleted
    Wait-Event -SourceIdentifier FileChanged
    Wait-Event -SourceIdentifier FileRenamed
        
    Unregister-Event -SourceIdentifier FileCreated
    Unregister-Event -SourceIdentifier FileDeleted
    Unregister-Event -SourceIdentifier FileChanged
    Unregister-Event -SourceIdentifier FileRenamed
    
}
    