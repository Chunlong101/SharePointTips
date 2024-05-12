# Web Intermittent Issue Detector

The Web Intermittent Issue Detector is a tool designed to detect intermittent issues, aiming to assist users in automatically discovering and debugging those problems that occur infrequently and are difficult to reproduce. In many cases, users may encounter intermittent web issues that occur only once a day or even every few days. Typically, users have no means to actively identify and reproduce such issues, and developers find themselves equally powerless, as they can only react to problems occasionally bothering users, feeling frustrated and helpless. With this tool, users and developers no longer need to rely on luck to manually detect these issues; the entire process of discovery and debugging can be automated.

![alt text](image.png)

## Usage

1. Download and install the tool: [IntermittentIssueDetector.zip](https://github.com/Chunlong101/SharePointTips/blob/master/IntermittentIssueDetector/IntermittentIssueDetector/IntermittentIssueDetector.zip).
![alt text](image-1.png)
2. Open the tool and configure parameters, including the page URL and refresh frequency. For example, in the image above, we set the tool to refresh the page "https://5xxsz0.sharepoint.com/sites/test" every 60 seconds. If the page content contains the phrase "Learn more about your Communication site" the tool will log a successful page load; otherwise, it will log a failed page load.
3. Combining the use of Fiddler can enhance issue analysis: [Web Connection with Fiddler](https://learn.microsoft.com/en-us/power-query/web-connection-fiddler), how to set a filter in Fiddler: [YouTube Tutorial](https://www.youtube.com/watch?v=DtTBLa0SeM8).

----- 
----- 
----- 

# Web间歇性问题检测器

Web间歇性问题检测器是一个用于检测间歇性问题的工具，旨在帮助用户自动发现和调试那些发生概率很低、难以重现的问题。在许多情况下，用户可能会遇到间歇性的网页问题，这些问题可能一天甚至几天才会发生一次，通常用户没有方法来主动地挖掘和重现这类问题，开发者在面对同样的境遇时也很被动，只能任由问题时不时地打扰用户，束手无策，令人不胜其烦。有了这个工具之后，用户和开发者不再需要手动地凭运气去检测这些问题，整个问题的发现和调试流程都可以被自动化。

![alt text](image.png)

## 使用方法

1. 下载并安装工具: https://github.com/Chunlong101/SharePointTips/blob/master/IntermittentIssueDetector/IntermittentIssueDetector/IntermittentIssueDetector.zip。
![alt text](image-1.png)
2. 打开工具并配置参数，包括页面URL、刷新频率等。例如，在上图中，我们设置了每隔60秒刷新一次页面“https://5xxsz0.sharepoint.com/sites/test”，如果刷出来的页面的内容中出现了“Learn more about your Communication site”的字样，那么工具将会记录一条成功加载页面的日志；反之，将记录一条加载页面失败的日志。
3. 结合Fiddler的使用可以更好地分析问题：https://learn.microsoft.com/en-us/power-query/web-connection-fiddler，how to set filter in fiddler: https://www.youtube.com/watch?v=DtTBLa0SeM8