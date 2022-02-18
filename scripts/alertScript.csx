#r "Newtonsoft.Json"
#r "System.Net.Http"

using System.Net;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Primitives;
using Newtonsoft.Json;
using System.Text;
 
 
private static HttpClient HttpClient = new HttpClient();
 
public static async Task<IActionResult> Run(HttpRequest req, ILogger log)
{
    string requestBody = await new StreamReader(req.Body).ReadToEndAsync();
    dynamic data = JsonConvert.DeserializeObject(requestBody);

    string link = data?.data?.context?.portalLink;
    string resourceName = data?.data?.context?.resourceName;
    string metricName = data?.data?.context?.condition?.allOf?[0].metricName;
    string threshold = data?.data?.context?.condition?.allOf?[0].metricValue;

    string jsonText = $"{{\"text\": \"*❗ALERT❗*\n*FROM*: {resourceName}:\n`{metricName}` is over {threshold}!!!\n<{link}|*Check it out*>\"}}";
    string sendToUrl = Environment.GetEnvironmentVariable("SLACK_URL");

    HttpRequestMessage slackMessage = new HttpRequestMessage(HttpMethod.Post, sendToUrl);
    slackMessage.Content = new StringContent(jsonText, Encoding.UTF8, "application/json");
 
    await HttpClient.SendAsync(slackMessage);
 
    return new OkObjectResult("OK");
}
