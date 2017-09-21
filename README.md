# AzureArmVSTSTasks

AzureARMVSTSTAsks contains some custom VSTS tasks for the deployment of ARM template based resources to Azure. It usages a powershell script to log on to azure account using the SPN credentials.

Make sure you have created an application in Azure Active directory and it has sufficient permission to work on the subscription you are going to use for the deployment.

# Building

You need to download tfx-cli to build and create the vsix extension if you want. VSIX extension can be published to the visual studio market place using your publisher account.

Alternatively if you want to use these tasks or similar tasks for inhouse deployments you can upload one or all the tasks individually by using the tfx-cli as

tfx build tasks upload --task-path LOCATION_TO_TASK_FOLDER



Feel free to fork, change and use. 
