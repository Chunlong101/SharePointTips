#
# C:\xxx，这个路径下面有2000多个文件，请你帮忙写个powershell脚本，将这些文件分为若干个部分，每个部分有500个文件。
#

$sourceDir = "C:\xxx"
$destinationDir = "C:\xxx"
$batchSize = 500
$fileIndex = 0
$folderIndex = 1

# 获取源目录下的所有文件
$files = Get-ChildItem -Path $sourceDir -File

foreach ($file in $files) {
    # 计算当前文件应放入的子文件夹
    $targetFolder = "$destinationDir\Part$folderIndex"
    
    # 如果子文件夹不存在则创建
    if (-not (Test-Path $targetFolder)) {
        New-Item -ItemType Directory -Path $targetFolder
    }
    
    # 将文件移动到目标子文件夹
    Move-Item -Path $file.FullName -Destination $targetFolder
    
    # 更新文件计数器
    $fileIndex++
    
    # 如果文件计数器达到了批次大小，重置计数器并增加文件夹索引
    if ($fileIndex -ge $batchSize) {
        $fileIndex = 0
        $folderIndex++
    }
}

Write-Host "文件已成功分批并移动到各子文件夹。"
