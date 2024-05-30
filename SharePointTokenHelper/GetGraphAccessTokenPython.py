import requests
url = "https://login.microsoftonline.com/xxx/oauth2/v2.0/token"
payload = 'grant_type=client_credentials&client_id=xxx&client_secret=xxx&scope=https%3A//graph.microsoft.com/.default'
headers = {
  'Content-Type': 'application/x-www-form-urlencoded',
}
response = requests.request("POST", url, headers=headers, data = payload)
print(response.text.encode('utf8'))
