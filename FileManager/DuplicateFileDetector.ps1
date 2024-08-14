# 在我磁盘上有大量的重复的文件，请你帮忙写一个powershell脚本，要求：
# 1. 将这些重复的文件找出来。如果大小相同，名字一样，就说明是重复的文件。
# 2. 将重复的文件移动到一个新的文件夹。
# 3. 请添加一个参数，当其为true的时候才执行文件移动，当其为false的时候只打印重复文件信息。

# 指定要扫描的目录
$sourceFolder = "C:\xxx"
# 指定用于存放重复文件的目标目录
$destinationFolder = "C:\xxx\Duplicate"
# 设置是否移动重复文件
$moveFiles = $false  # 设置为 $false 只打印重复文件信息

# 创建目标文件夹（如果不存在的话）
if ($moveFiles -and -not (Test-Path $destinationFolder)) {
    New-Item -Path $destinationFolder -ItemType Directory
}

# 获取所有文件
$fileList = Get-ChildItem -Path $sourceFolder -Recurse -File

# 使用哈希表来跟踪文件大小和名称
$fileHashTable = @{}

foreach ($file in $fileList) {
    $key = "$($file.Length)_$($file.Name)"
    
    if ($fileHashTable.ContainsKey($key)) {
        # 如果哈希表中已经存在相同的键
        $existingFile = $fileHashTable[$key]
        
        if ($moveFiles) {
            # 如果 $moveFiles 为 true，移动重复文件
            $destinationPath = Join-Path -Path $destinationFolder -ChildPath $file.Name

            # 确保目标文件夹中没有相同名称的文件
            if (Test-Path $destinationPath) {
                $i = 1
                while (Test-Path "$destinationFolder\$($file.BaseName)_$i$($file.Extension)") {
                    $i++
                }
                $destinationPath = "$destinationFolder\$($file.BaseName)_$i$($file.Extension)"
            }

            Move-Item -Path $file.FullName -Destination $destinationPath -Force
            Write-Output "Moved duplicate file: $($file.FullName) to $destinationPath"
        } else {
            # 如果 $moveFiles 为 false，只打印重复文件信息
            Write-Output "Duplicate file found: $($file.FullName) (Original: $existingFile)"
        }
    } else {
        # 将文件信息添加到哈希表中
        $fileHashTable[$key] = $file.FullName
    }
}
