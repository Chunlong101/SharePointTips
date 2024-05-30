var client = new RestClient("https://login.microsoftonline.com/xxx/oauth2/v2.0/token");
client.Timeout = -1;
var request = new RestRequest(Method.POST);
request.AddHeader("Content-Type", "application/x-www-form-urlencoded");
request.AddParameter("grant_type", "client_credentials");
request.AddParameter("client_id", "xxx");
request.AddParameter("client_secret", "xxx");
request.AddParameter("scope", "https://graph.microsoft.com/.default");
IRestResponse response = client.Execute(request);
Console.WriteLine(response.Content);