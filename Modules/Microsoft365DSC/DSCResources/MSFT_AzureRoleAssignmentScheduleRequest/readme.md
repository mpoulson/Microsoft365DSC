
# AzureRoleAssignmentScheduleRequest

## Description

Represents a request for an active role assignment for a principal through Azure Privileged Identity Management (PIM) for Azure resources. The role assignment can be permanently active without an expiry date or temporarily active with an expiry date.

**Please note:** The difference between start and end times of assignments must be at least 5 minutes. Lower assignment times will result in an error.
Also, if you attempt to remove or update an assignment less than 5 minutes after the last modification, it will fail as well.
