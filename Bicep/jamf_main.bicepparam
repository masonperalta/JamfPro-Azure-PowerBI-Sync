using ‘jamf_main.bicep' //keep this the same name as your .bicep file name

param functionAppName = 'YourJamfSyncFunctionName'
param resourceLocation = 'East US’ // or preferred location
param jss = 'https://yourInstance.jamfcloud.com'
param jssPass = 'jamfApiPassword'
param jssUser = 'jamfApiUsername'
