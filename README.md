# vSphere Patch Compliance Tool

## Overview 

The vSphere Patch Compliance Tool is a locally hosted solution designed to connect to multiple vCenters and gather vSphere data. It provides a web-based graphical interface to analyze and display patch compliance status for vCenters, ESXi Hosts, and Hardware.

## Key Features:

Interactive GUI for visualizing compliance data.

Generates colorful HTML reports with graphical and tabular analysis.

Supports exporting compliance reports for offline review.

## Technology Stack

The tool is developed in PowerShell and leverages the following modules (with some customizations):

```
Pode

Pode.Web

ImportExcel

ReportHTML
```

## Usage

Running the Tool

Ensure PowerShell is installed on your system.

Navigate to the root directory of the tool.

Execute the main script:

```
.\Report Consolidation.ps1
```

Access the GUI via the URL displayed in the console after starting the script.

## Directory Structure

```
./config/Input/ - Input .xlsx files from vSphere Patching KB Article.
./config/       - Input data collected from vCenters and ESXi Hosts.
./lib/          - Library and module files.
./log/          - Error log files.
./page/         - Web pages (e.g., home, compliance views).
./public/       - Styles and bootstrap files.
./report/       - Generated HTML reports.
./static/       - Logo and static files.
```
## Requirements

PowerShell 5.1 or later.

Network access to all vCenters and ESXi Hosts.

## Dependencies:

Pode and Pode.Web modules.

ImportExcel module for Excel processing.

ReportHTML module for generating HTML reports.

## Reports and Analytics

Web Interface: Displays compliance status for vCenters, ESXi Hosts, and Hardware.

HTML Report: Downloadable colorful report with graphical and tabular analysis.

## Contributions

Contributions are welcome! Feel free to submit a pull request or raise issues for bugs and feature requests.

## License

This project is licensed under the MIT License. See the LICENSE file for details.

## Contact

For any queries or support, please reach out via GitHub Issues.

