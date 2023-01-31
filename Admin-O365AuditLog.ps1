#Requires -Modules ExchangeOnlineManagement 

# Ensure its enabled: https://learn.microsoft.com/en-us/microsoft-365/compliance/audit-log-enable-disable?view=o365-worldwide

# The following command loads the Exchange Online management module.
Import-Module ExchangeOnlineManagement

# Next, you connect using your user principal name. A dialog will prompt you for your 
# password and any multi-factor authentication requirements.
Connect-ExchangeOnline -UserPrincipalName rromano@rrmsft.onmicrosoft.com

# Now you can query for Power BI activity. In this example, the results are limited to 
# 1,000, shown as a table, and the "more" command causes output to display one screen at a time. 
$results = Search-UnifiedAuditLog -StartDate '2023-01-31' -EndDate '2023-02-01' -RecordType PowerBIAudit -ResultSize 1000