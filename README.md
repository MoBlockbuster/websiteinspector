# websiteinspector
Bashtool to monitor any websites for HTTP-CODE, TLS-TTL and the HTTP response time. You will get a mail notification for each alarm.

This tool was programmed to monitor all of your websites. The websiteinspector detects automatically if a website uses HTTPS (443) and also checks the expire of the TLS certificate. If the website uses only HTTP (80) the webinspector checks the site without the TLS-TTL.

### Requirements:
- SSH access
- Bash as a shell
- A working mailserver
- Tools: mailx to send mails, curl, host and openssl
- Create a cronjob
- Define the variable **MAILFROM** and **MAILTO** in websiteinspector
- Enter the URL in the variable **WEBSITES**. 
  - Example for the variable WEBSITES: **WEBSITES="https://github.com http://www.postfix.org"**

### Information:
- You can change in the config\_websiteinspector.cnf the values for TLS-WARN, TLS-CRIT and HTTP-RESPONSE-TIME
- The websiteinspector calls a website and expects the 200 HTTP-CODE. Each redirection will be followed until the HTTP-CODE 200 is reached
- If websiteinspector doesn't find a HTTP-CODE 200, this is treated as an error
- If the TLS-TTL (SSL certificate expire date) is lower then 14 days and higher then 7 days this will be handled as **warning**
- If the TLS-TTL (SSL certificate expire date) is lower then 7 days this will be handled as **alarm**
- If the website takes longer then 3 seconds to load this will be handled as **alarm**

### Usage:
- Save the websiteinspector.sh on the server which is used to monitor other websites
- Make the websiteinspector.sh executable
- **Start the webinspector for the first time, to create his missing configfile**
- Modify the configfile config\_websiteinspector.cnf for your case. The most important variable that you should adjust is **>> WEBSITE <<**
- Create a cronjob, that runs every 3 minutes (change this value for your case) and add at the end of the line **> /dev/null 2>&1**
- Use parameter **-s** to show only the monitored websites
- Use parameter **-v** to check the current version
- Use parameter **-f** to show the current content of alarmlog websiteinspector.log
- Use parameter **-r** to clear the websiteinspector.log and forget all alarm and warnings
- Use parameter **-h** to show the usage of websiteinspector.log
- Use parameter **-u** to update me
- Use parameter **-x** to show my current settings

### Support and contact:
If you use this tool, I would be happy to receive your feedback and your experience with websiteinspector.

To contact me: mmarzouki@protonmail.com

**Cheers**

