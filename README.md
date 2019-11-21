Steps to reset the flaky status: 

1. Download the ResetFlakyBits.ps1.
2. open powershell windows and locate the file.
3. Please generate PAT token from AzDO account.
4. Get the build did from the build url - https://dev.azure.com/accountname/projectname/_build/results?buildId=buildid
5. Run the following command with the information.

.\ResetFlakyBits.ps1 -AccountName "<Account-Name>" -TeamProject "<Project-Name>" -AccessToken "<Pat token>" -BuildNumber "<Build-Id>" 

5. Scripts will unmark flaky status and status will start reflecting from next build onwards. 
