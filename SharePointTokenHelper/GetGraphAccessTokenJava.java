OkHttpClient client = new OkHttpClient().newBuilder()
  .build();
MediaType mediaType = MediaType.parse("application/x-www-form-urlencoded");
RequestBody body = RequestBody.create(mediaType, "grant_type=client_credentials&client_id=xxx&client_secret=xxx&scope=https://graph.microsoft.com/.default");
Request request = new Request.Builder()
  .url("https://login.microsoftonline.com/xxx/oauth2/v2.0/token")
  .method("POST", body)
  .addHeader("Content-Type", "application/x-www-form-urlencoded")
  .build();
Response response = client.newCall(request).execute();