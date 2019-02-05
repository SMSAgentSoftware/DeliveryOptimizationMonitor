![](https://raw.githubusercontent.com/SMSAgentSoftware/DeliveryOptimizationMonitor/master/bin/Peer.ico)
# Delivery Optimization Monitor
A tool for viewing Delivery Optmization data on the local or remote computer

![Delivery Optimization Monitor](https://github.com/SMSAgentSoftware/DeliveryOptimizationMonitor/raw/master/Assets/DO%20Monitor.PNG)

The tool uses the Delivery Optimization cmdlets built in to Windows 10 to retrieve and display DO data, including stats and charts for the current month, performance snapshot data and data on any current DO jobs.

## Requirements
* A supported version of Windows 10 (1703 onward) 
* PowerShell 5 minimum 
* .Net Framework 4.6.2 minimum 
* PS Remoting enabled to view data from remote computers. 

This WPF tool is coded in Xaml and PowerShell and uses the MahApps.Metro and LiveCharts open source libraries.

## Download
A ZIP file can be downloaded from the [TechNet Gallery](https://gallery.technet.microsoft.com/Delivery-Optimization-3eff74ac)

## Use
To use the tool, extract the ZIP file, right-click the Delivery Optimization Monitor.ps1 and run with PowerShell.
To run against the local machine, you must run the tool elevated. To do so, create a shortcut to the ps1 file. Edit the properties of the shortcut and change the target to read:
> PowerShell.exe -ExecutionPolicy Bypass -File "`<pathtoPS1file`>"

Right-click the shortcut and run as administrator, or edit the shortcut properties (under Advanced) to run as administrator.
For completeness, you can also change the icon of the shortcut to the icon file included in the bin directory.
