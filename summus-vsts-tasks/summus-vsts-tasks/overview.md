## Azure-Arm-Tasks ##

Varous small tasks to automate and create the build and deployment pipleline for ARM based resources

### Quick steps to get started ###

![](/static/images/Screen1.png)

Install the extension from the Visual Sudio Marketplace and use different tasks as per your need. These tasks require to log on to Azure ARM subscription using the SPN (Service Principle Name) account. You would need to 
ensure that follwoing variables are available in your build/release definition and available in the scope of the task.

1.	AzureSPNAppID (application's object id you get from the Azure Active Directory)
2.	AzureSPNToken (Access Key of the application)
3.	AzureSubscriptionId (Subscription id)
4.	AzureTenantId  (Your Azure Tenant id)



### Features 
#### New Resource Group
A custom VSTS task which checks whether a resource group for given name exists and create one if it does not exists.

#### New Storage account
Chekcs for the existance of the storage account for the given name and creates if it does not exists. This tasks assumes you provide corect name for the storage account within the limit. 

#### Azure Automation account
Chekcs for the existance of the automation account for the given name and creates if it does not exists. This tasks assumes you provide corect unique name for the automation account as per the azure specification. 

#### Azure Import AA Resources
Download the DSC modules from the powershell gallery and upload to the azure automation account

#### Azure Import DSC Configuration
Upload the DSC configuration and DSC configuration data to azure automation account, initiate the compilation of the DSC configuration and wait until it finishes.

#### Azure Get AA Reg Info
Gets the registration information of the azure automation account such as URL and the key and populates the VSTS variables (registrationUrl and registrationKey). These variables could be used by ARM temlates to register the new nodes


### Known issue(s)
- No tests exists, hoping to add pester tests soon

### Learn More
A blog post is under progress to help how to use and extend

### Minimum supported environments ###
- Visual Studio Team Services
- Azure powershell cmdlets should be installed on the agents

### Contribution ###
Feel free to fork and modify and raise a pull request for any fixes, addition of features etc. 

### Feedback ###
- Add a review below.
- Send us an [email](ssingh@summus-technology.co.uk, sujit.singh@gmail.com).