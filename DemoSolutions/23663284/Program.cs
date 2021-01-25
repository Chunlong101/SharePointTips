using RestSharp;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace _23663284
{
    class Program
    {
        static void Main(string[] args)
        {
            // RestSharp with graph api to download a file from sharepoint online, download the file from response body 
            var client = new RestClient("https://graph.microsoft.com/v1.0/sites/siteid/drives/driveid/items/itemid/content");
            client.Timeout = -1;
            var request = new RestRequest(Method.GET);
            request.AddHeader("Authorization", "Bearer YourAccessToken");
            var response = client.DownloadData(request);

            BinaryWriter bw = new BinaryWriter(new FileStream("mydata.docx", FileMode.Create));
            bw.Write(response);
        }
    }
}
