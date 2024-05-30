var settings = {
    "url": "https://login.microsoftonline.com/xxx/oauth2/v2.0/token",
    "method": "POST",
    "timeout": 0,
    "headers": {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    "data": {
      "grant_type": "client_credentials",
      "client_id": "xxx",
      "client_secret": "xxx",
      "scope": "https://graph.microsoft.com/.default"
    }
  };
  
  $.ajax(settings).done(function (response) {
    console.log(response);
  });