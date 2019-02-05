#######################################################################
##                                                                   ##
## Defines event handlers used by Delivery Optimization Monitor Tool ##
##                                                                   ##
#######################################################################

# Bring the window to the fore
$UI.Window.Add_Loaded({
    $This.Activate()
})

$UI.GO.Add_Click({

    # Reset values
    $UI.DataSource[0] = $true
    $UI.DataSource[1] = "Running..."
    $UI.DataSource[2] = "Black"
    $UI.DataSource[3] = $null
    $UI.DataSource[4] = $null
    $UI.DataSource[5] = $null
    $UI.DataSource[6][0].Values[0].Value = 0
    $UI.DataSource[6][1].Values[0].Value = 0
    $UI.DataSource[6][2].Values[0].Value = 0
    $UI.DataSource[7][0].Values[0].Value = 0
    $UI.DataSource[7][1].Values[0].Value = 0
    $UI.DataSource[8] = "Visible"
    
    # Main code to run in background job
    $Code = {
        Param($UI,$ComputerName)

        # If local machine
        If ($ComputerName -eq $env:COMPUTERNAME)
        {
            # Test for elevation
            If (([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
            {
            }
            Else
            {
                $SoundFile = "$env:SystemDrive\Windows\Media\notify.wav"
                $SoundPlayer = New-Object System.Media.SoundPlayer -ArgumentList $SoundFile
                $SoundPlayer.Add_LoadCompleted({
                    $This.Play()
                    $This.Dispose()
                })
                $SoundPlayer.LoadAsync()
                $UI.DataSource[1] = "ERROR: Please run as administrator when connecting to the local machine!"
                $UI.DataSource[2] = "Red"
                $UI.DataSource[0] = $false
                Return
            }
        }
        Else
        {
            $UI.DataSource[1] = "Testing connectivity to $ComputerName"
            $TC = Test-Connection -ComputerName $ComputerName -Count 2 -Quiet
            If ($TC -eq $false)
            {
                $SoundFile = "$env:SystemDrive\Windows\Media\notify.wav"
                $SoundPlayer = New-Object System.Media.SoundPlayer -ArgumentList $SoundFile
                $SoundPlayer.Add_LoadCompleted({
                    $This.Play()
                    $This.Dispose()
                })
                $SoundPlayer.LoadAsync()
                $UI.DataSource[1] = "ERROR: Could not contact $ComputerName on the network!"
                $UI.DataSource[2] = "Red"
                $UI.DataSource[0] = $false
                Return
            }

            Try
            {
                $PSSession = New-PSSession -ComputerName $ComputerName -ErrorAction Stop
            }
            Catch
            {
                $SoundFile = "$env:SystemDrive\Windows\Media\notify.wav"
                $SoundPlayer = New-Object System.Media.SoundPlayer -ArgumentList $SoundFile
                $SoundPlayer.Add_LoadCompleted({
                    $This.Play()
                    $This.Dispose()
                })
                $SoundPlayer.LoadAsync()
                $UI.DataSource[1] = "ERROR: Could not create a PS Session to $ComputerName! $_"
                $UI.DataSource[2] = "Red"
                $UI.DataSource[0] = $false
                Return
            }
        }

        # Get Delivery Optimization Snapshot This month
        $UI.DataSource[1] = "Retrieving PerfSnap for this month"
        If ($ComputerName -eq $env:COMPUTERNAME)
        {
            $DOPerfSnapTM = Try{Get-DeliveryOptimizationPerfSnapThisMonth -Verbose -ErrorAction Stop}Catch{}
        }
        Else
        {
            $DOPerfSnapTM = Invoke-Command -Session $PSSession -ScriptBlock { Try{Get-DeliveryOptimizationPerfSnapThisMonth -Verbose -ErrorAction Stop}Catch{} }
        }
        $DOPerfSnapTMTable = New-Object System.Data.DataTable

        If ($DOPerfSnapTM.Count -ge 1 -and $DOPerfSnapTM.GetType().Name -ne "String")
        {
            
            [void]$DOPerfSnapTMTable.Columns.Add("Statistic")
            [void]$DOPerfSnapTMTable.Columns.Add("Value")

            # Convert to a useable object
            [pscustomobject]$Obj = @{}
            Foreach ($Item in $DOPerfSnapTM)
            {
                $Obj.Add($Item.Split()[0], $Item.Split()[-1])
            }


            # Percentages
            $DownloadTotal = ([int]$Obj.MonthlyDownloadHttpBytes + [int]$Obj.MonthlyDownloadLanBytes + [int]$Obj.MonthlyDownloadInternetBytes)
            $Percent_DownloadHttpBytes = [Math]::Round((100 * ([int]$Obj.MonthlyDownloadHttpBytes / $DownloadTotal)),2)
            $Percent_MonthlyDownloadLanBytes = [Math]::Round((100 * ([int]$Obj.MonthlyDownloadLanBytes / $DownloadTotal)),2)
            $Percent_MonthlyDownloadInternetBytes = [Math]::Round((100 * ([int]$Obj.MonthlyDownloadInternetBytes / $DownloadTotal)),2)

            # Populate table
            [void]$DOPerfSnapTMTable.Rows.Add("Start Date", $Obj.MonthStartDate)
            [void]$DOPerfSnapTMTable.Rows.Add("Uploaded to PCs on the local network", "$([math]::Round(($Obj.MonthlyUploadLanBytes / 1MB),2)) MB")
            [void]$DOPerfSnapTMTable.Rows.Add("Uploaded to PCs on the internet", "$([math]::Round(($Obj.MonthlyUploadInternetBytes / 1MB),2)) MB")
            [void]$DOPerfSnapTMTable.Rows.Add("Downloaded from Microsoft", "$([math]::Round(($Obj.MonthlyDownloadHttpBytes/ 1MB),2)) MB ($Percent_DownloadHttpBytes %)")
            [void]$DOPerfSnapTMTable.Rows.Add("Downloaded from PCs on your local network", "$([math]::Round(($Obj.MonthlyDownloadLanBytes / 1MB),2)) MB ($Percent_MonthlyDownloadLanBytes %)")
            [void]$DOPerfSnapTMTable.Rows.Add("Downloaded from PCs on the internet", "$([math]::Round(($Obj.MonthlyDownloadInternetBytes / 1MB),2)) MB ($Percent_MonthlyDownloadInternetBytes %)")
            [void]$DOPerfSnapTMTable.Rows.Add("Average download speed (user initiated)", "$([math]::Round(($Obj.MonthlyDownloadFgRateKbps / 1024),2)) Mbps")
            [void]$DOPerfSnapTMTable.Rows.Add("Average download speed (background)", "$([math]::Round(($Obj.MonthlyDownloadBgRateKbps / 1024),2)) Mbps")
            [void]$DOPerfSnapTMTable.Rows.Add("Monthly Upload Limit Reached", $Obj.MonthlyUploadLimitReached)

            # Populate Charts
            $UI.DataSource[6][0].Values[0].Value = $([math]::Round(($Obj.MonthlyDownloadHttpBytes/ 1MB),2))
            $UI.DataSource[6][1].Values[0].Value = $([math]::Round(($Obj.MonthlyDownloadLanBytes / 1MB),2))
            $UI.DataSource[6][2].Values[0].Value = $([math]::Round(($Obj.MonthlyDownloadInternetBytes / 1MB),2))
            $UI.DataSource[7][0].Values[0].Value = $([math]::Round(($Obj.MonthlyUploadInternetBytes/ 1MB),2))
            $UI.DataSource[7][1].Values[0].Value = $([math]::Round(($Obj.MonthlyUploadLanBytes / 1MB),2))

        }
        ElseIf ($DOPerfSnapTM.GetType().Name -eq "String")
        {
            [void]$DOPerfSnapTMTable.Columns.Add("Info")
            [void]$DOPerfSnapTMTable.Rows.Add("$DOPerfSnapTM")
        }
        $UI.DataSource[3] = $DOPerfSnapTMTable




        # Get Get Delivery Optimization Snapshot 
        $UI.DataSource[1] = "Retrieving PerfSnap long term data"
        If ($ComputerName -eq $env:COMPUTERNAME)
        {
            $DOPerfSnap = Try{Get-DeliveryOptimizationPerfSnap -Verbose -ErrorAction Stop}Catch{}
        }
        Else
        {
            $DOPerfSnap = Invoke-Command -Session $PSSession -ScriptBlock { Try{Get-DeliveryOptimizationPerfSnap -Verbose -ErrorAction Stop}Catch{} }
        }       
        $DOPerfSnapTable = New-Object System.Data.Datatable
        
        If ($DOPerfSnap.Count -ge 1 -and $DOPerfSnap.GetType().Name -ne "String")
        {            
            [pscustomobject]$Obj = @{}
            Foreach ($Item in $DOPerfSnap)
            {
                $Obj.Add($Item.Split()[0], $Item.Split()[-1])
            }

            [void]$DOPerfSnapTable.Columns.Add("Statistic")
            [void]$DOPerfSnapTable.Columns.Add("Value")

            Foreach ($Item in $Obj.Keys)
            {
                [void]$DOPerfSnapTable.Rows.Add($Item, $obj["$item"])
            }
        }
        ElseIf ($DOPerfSnap.GetType().Name -eq "String")
        {
            [void]$DOPerfSnapTable.Columns.Add("Info")
            [void]$DOPerfSnapTable.Rows.Add("$DOPerfSnap")
        }
        $UI.DataSource[4] = $DOPerfSnapTable



        # Get the DO status
        $UI.DataSource[1] = "Retrieving Current DO Status"
        If ($ComputerName -eq $env:COMPUTERNAME)
        {
            $DOStatus = Try{Get-DeliveryOptimizationStatus -Verbose -ErrorAction Stop}Catch{}
        }
        Else
        {
            $DOStatus = Invoke-Command -Session $PSSession -ScriptBlock { Try{Get-DeliveryOptimizationStatus -Verbose -ErrorAction Stop}Catch{} }
        }  
        $DOStatusTable = New-Object System.Data.Datatable
        
        If ($DOStatus.Count -ge 1 -and $DOStatus.GetType().Name -ne "String")
        {            
            $Properties = $DOStatus[0] | Get-Member -MemberType Property | Select -ExpandProperty Name
            Foreach ($Property in $Properties)
            {
                [void]$DOStatusTable.Columns.Add("$Property")
            }
            Foreach ($Item in $DOStatus)
            {
                $Row = $DOStatusTable.NewRow()
                Foreach ($Property in $Properties)
                {
                    $Row.$Property = $Item.$Property
                }
                [void]$DOStatusTable.Rows.Add($Row)
            }
        }
        ElseIf ($DOStatus.GetType().Name -eq "String")
        {
            [void]$DOStatusTable.Columns.Add("Info")
            [void]$DOStatusTable.Rows.Add("$DOStatus")
        }
        $UI.DataSource[5] = $DOStatusTable

        # Finish up
        $UI.DataSource[0] = $False
        $UI.DataSource[1] = "Completed"
        $UI.DataSource[2] = "Black"
        If ($PSSession)
        {
            Remove-PSSession $PSSession
        }
    }

    $ComputerName = $UI.ComputerName.Text

    # Start a background job
    $Job = [BackgroundJob]::New($Code,@($UI,$ComputerName))
    $UI.Jobs += $Job
    $Job.Start()

})