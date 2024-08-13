# 指定要扫描的目录
$sourceFolder = "D:\待剪辑的生活"
# 指定用于存放重复文件的目标目录
$destinationFolder = "D:\待剪辑的生活\Duplicate"
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
