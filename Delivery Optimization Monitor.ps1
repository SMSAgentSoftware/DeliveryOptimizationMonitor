##########################################################################
##                                                                      ##
##                 DELIVERY OPTIMIZATION MONITOR TOOL                   ##
##                                                                      ##
## Description: View Delivery Optimization statistics from the local or ##
##              remote computer                                         ##
## Author:      Trevor Jones                                            ##
## Blog:        smsagent.blog                                           ##
##                                                                      ##
##########################################################################


# Set the location we are running from
$Source = $PSScriptRoot

# Load the function library
. "$Source\bin\FunctionLibrary.ps1"

# Do PS version check
If ($PSVersionTable.PSVersion.Major -lt 5)
{
  $Content = "Delivery Optimization Monitor cannot start because it requires minimum PowerShell 5."
  New-WPFMessageBox -Content $Content -Title "Oops!" -TitleBackground Orange -TitleTextForeground Yellow -TitleFontSize 20 -TitleFontWeight Bold -BorderThickness 1 -BorderBrush Orange -Sound 'Windows Exclamation'
  Break
}

# Do .Net Version Check
$Release = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" -Name Release).Release
If ($Release -lt 394802)
{
  $Content = "Delivery Optimization Monitor cannot start because it requires minimum .Net Framework 4.6.2."
  New-WPFMessageBox -Content $Content -Title "Oops!" -TitleBackground Orange -TitleTextForeground Yellow -TitleFontSize 20 -TitleFontWeight Bold -BorderThickness 1 -BorderBrush Orange -Sound 'Windows Exclamation'
  Break
}

# Load the required assemblies
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Drawing
Add-Type -Path "$Source\bin\System.Windows.Interactivity.dll"
Add-Type -Path "$Source\bin\ControlzEx.dll"
Add-Type -Path "$Source\bin\MahApps.Metro.dll"
Add-Type -Path "$Source\bin\LiveCharts.dll"
Add-Type -Path "$Source\bin\LiveCharts.Wpf.dll"

# Define the XAML code
[XML]$Xaml = [System.IO.File]::ReadAllLines("$Source\Xaml\App.xaml") 

# Create a synchronized hash table and add the WPF window and its named elements to it
$UI = [System.Collections.Hashtable]::Synchronized(@{})
$UI.Window = [Windows.Markup.XamlReader]::Load((New-Object -TypeName System.Xml.XmlNodeReader -ArgumentList $xaml))
$xaml.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") | ForEach-Object -Process {
    $UI.$($_.Name) = $UI.Window.FindName($_.Name)
    }

# Set the icon
$UI.Window.Icon = "$Source\bin\peer.ico"

# Set the local computer initially
$UI.ComputerName.Text = $env:COMPUTERNAME

# Hold the background jobs here. Useful for querying the streams for any errors.
$UI.Jobs = @()

# Load in the other code libraries
. "$Source\bin\ClassLibrary.ps1"
. "$Source\bin\EventLibrary.ps1"

# OC for data binding source
$UI.DataSource = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
$UI.DataSource.Add("False") # ProgressBar Indeterminate
$UI.DataSource.Add("Ready") # Status
$UI.DataSource.Add("Black") # Status foreground colour
$UI.DataSource.Add($null)   # This Month Datagrid itemssource
$UI.DataSource.Add($null)   # PerfSnap Datagrid itemssource
$UI.DataSource.Add($null)   # Current Jobs datagrid itemssource
$UI.DataSource.Add($null)   # Download Chart series collection
$UI.DataSource.Add($null)   # Upload Chart series collection
$UI.DataSource.Add("Hidden")# Chart visibility

$UI.Window.DataContext = $UI.DataSource

# Create the chart series
# Download chart
$DownloadSeriesCollection = [LiveCharts.SeriesCollection]::new()
$DownloadSeries = [LiveCharts.Wpf.PieSeries]::new()
$DownloadSeries.Title = "From Microsoft"
$DownloadSeriesValue = [LiveCharts.ChartValues[LiveCharts.Defaults.ObservableValue]]::new()
$DownloadSeriesValue.Add([LiveCharts.Defaults.ObservableValue]::new(0))
$DownloadSeries.Values = $DownloadSeriesValue
$DownloadSeries.DataLabels = $true
$DownloadSeriesCollection.Add($DownloadSeries)

$DownloadSeries = [LiveCharts.Wpf.PieSeries]::new()
$DownloadSeries.Title = "From Microsoft cache server"
$DownloadSeriesValue = [LiveCharts.ChartValues[LiveCharts.Defaults.ObservableValue]]::new()
$DownloadSeriesValue.Add([LiveCharts.Defaults.ObservableValue]::new(0))
$DownloadSeries.Values = $DownloadSeriesValue
$DownloadSeries.DataLabels = $true
$DownloadSeriesCollection.Add($DownloadSeries)

$DownloadSeries = [LiveCharts.Wpf.PieSeries]::new()
$DownloadSeries.Title = "From PCs on your local network"
$DownloadSeriesValue = [LiveCharts.ChartValues[LiveCharts.Defaults.ObservableValue]]::new()
$DownloadSeriesValue.Add([LiveCharts.Defaults.ObservableValue]::new(0))
$DownloadSeries.Values = $DownloadSeriesValue
$DownloadSeries.DataLabels = $true
$DownloadSeriesCollection.Add($DownloadSeries)

$DownloadSeries = [LiveCharts.Wpf.PieSeries]::new()
$DownloadSeries.Title = "From PCs on the Internet"
$DownloadSeriesValue = [LiveCharts.ChartValues[LiveCharts.Defaults.ObservableValue]]::new()
$DownloadSeriesValue.Add([LiveCharts.Defaults.ObservableValue]::new(0))
$DownloadSeries.Values = $DownloadSeriesValue
$DownloadSeries.DataLabels = $true
$DownloadSeriesCollection.Add($DownloadSeries)

$UI.DataSource[6] = $DownloadSeriesCollection

# Upload chart
$UploadSeriesCollection = [LiveCharts.SeriesCollection]::new()
$UploadSeries = [LiveCharts.Wpf.PieSeries]::new()
$UploadSeries.Title = "Uploaded to PCs on the internet"
$UploadSeriesValue = [LiveCharts.ChartValues[LiveCharts.Defaults.ObservableValue]]::new()
$UploadSeriesValue.Add([LiveCharts.Defaults.ObservableValue]::new(0))
$UploadSeries.Values = $UploadSeriesValue
$UploadSeries.DataLabels = $true
$UploadSeriesCollection.Add($UploadSeries)

$UploadSeries = [LiveCharts.Wpf.PieSeries]::new()
$UploadSeries.Title = "Uploaded to PCs on the local network"
$UploadSeriesValue = [LiveCharts.ChartValues[LiveCharts.Defaults.ObservableValue]]::new()
$UploadSeriesValue.Add([LiveCharts.Defaults.ObservableValue]::new(0))
$UploadSeries.Values = $UploadSeriesValue
$UploadSeries.DataLabels = $true
$UploadSeriesCollection.Add($UploadSeries)

$UI.DataSource[7] = $UploadSeriesCollection

# Region to display the UI
#region DisplayUI

# If code is running in ISE, use ShowDialog()...
if ($psISE)
{
    $null = $UI.window.Dispatcher.InvokeAsync{$UI.window.ShowDialog()}.Wait()
}
# ...otherwise run as an application
Else
{
    # Make PowerShell Disappear
    $windowcode = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
    $asyncwindow = Add-Type -MemberDefinition $windowcode -Name Win32ShowWindowAsync -Namespace Win32Functions -PassThru
    $null = $asyncwindow::ShowWindowAsync((Get-Process -PID $pid).MainWindowHandle, 0)
 
    $app = New-Object -TypeName Windows.Application
    $app.Properties
    $app.Run($UI.Window)
}

#endregion