# JamfPro-Azure-Sync-for-PowerBI
Jamf Pro / Power BI data sync project


## Purpose and Function
Microsoft Power BI is a powerful business intelligence tool available to Microsoft Azure customers that can allow Jamf Pro administrators to unlock additional understanding of their environment through the visualization of their Jamf inventory data.  This project creates a workflow with two primary functions:
1. Syncing Jamf Pro data to Azure Cosmos DB / Power BI dataset
2. Displaying this data through a Jamf-provided Power BI dashboard

The data syncing techniques utilized in these workflow are designed to work for large or small organizations.  Additionally, this method is designed to make use of an all-Azure architecture, meaning that no additional servers or databases must be maintained in order to provide data syncing to Power BI.  Instead, Azure services are created and configured once, then run automatically.
This document will walk through the installation and configuration of all elements required to achieve a Jamf Pro-to-Power BI integration using an Azure Bicep template. When complete, you a pre-configured Power BI dashboard will automatically sync and display your Jamf Pro inventory.

![alt text](https://masonperalta.com/s/Power-BI-Dashboard-t6xp.png "Jamf Pro Power BI Dashboard Image")

## Jamf Pro Data Sync with Azure
Data from Jamf Pro is synced to a Microsoft Azure Cosmos DB resource, where it is used as a real-time Power BI dataset. The use of Azure Cosmos DB provides real-time datasets, while also greatly simplifying management of the data sync by removing elements necessary for other Power BI data sync workflows; these include On-Premise Data Gateways, which must be installed on a separate server to periodically update Power BI datasets.

### Full Sync Method
This workflow is designed to perform a full sync of a Jamf Pro instance at a scheduled timed interval.  The script will run to collect all Jamf Pro inventory data during the sync.  As a result, the larger the Jamf Pro deployment, the longer the syncs will take to complete.

This script is designed to run within an Azure Function app and within the 10 minute maximum runtime of the Function.  It is designed to run every 10 minutes and, if the script does not finish within the 10 minute runtime limit (due to large device count), picks up where it left off on the previous Function run.

However, after the first sync, further syncs will be much faster as only devices that have checked in since the last successful sync will be updated.

### Historical Data Collection
This workflow collects and summarizes various data points daily for historical tracking of Jamf Pro data.  For example, models, OS versions, group memberships and applications across computers and mobile devices are collected for historical viewing in Power BI.

## Requirements

### Jamf Pro Data Sync (Timed Sync or Webhook method)
* Jamf Pro instance
* Microsoft Azure Function Apps (1x)
* Microsoft Azure Cosmos DB (1x)
* Microsoft Azure Key Vault (1x, optional)

### Jamf Pro Power BI Dashboard
Once the Jamf Pro data is synced to Azure, the provided Power BI App automatically displays the information in preconfigured dashboards.
The following service is required for this step:
* Microsoft Power BI (Power BI Pro Subscription)

## Getting Started
To get started, go to **Instructions.md** to download the complete documentation.










