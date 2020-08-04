# websiteinspector
Bashtool to monitor any website for HTTP-CODE, TLS-TTL and the HTTP response time. You will get an mail notification for each alarm.

This tool has been programmed to monitor all of your desired websites.

### Requirements:

- A working mailserver
- Tool mailx to send mails

### Information:

- The websiteinspector call a website and expect the 200 HTTP-CODE. Each redirect will be followed until the HTTP-CODE 200 is reached.

- If websiteinspector not found an HTTP-CODE 200, this is treated as an error.

- If the TLS-TTL (SSL certificate expire date) is lower then 14 days and higher then 7 days this will be handled as **warning**.

- If the TLS-TTL (SSL certificate expire date) is lower then 7 days this will be handled as **alarm**.

