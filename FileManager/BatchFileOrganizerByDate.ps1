# 我有一个文件夹里面有很多的文件，这些文件的名字里面都带有时间（时间的格式可能不一样）比如：
# DJI_20240810213802_0011_D.MP4
# VirtuaNES - 热血物语 2024-08-08 21-57-28.mp4
# 2024_08_01_22_57_IMG_8693.PNG
# 2024_06_16_12_50_IMG_8117.MOV
# 2024_02_26_18_41_IMG_7375.MP4
# 2023_11_23_15_12_IMG_4980.JPG
# 现在请你帮忙写一个powershell脚本将所有文件按日期分类并移动到相应的文件夹当中。

# 定义要处理的文件夹路径
$sourceFolder = "C:\xxx"

# 切换到源文件夹
Set-Location -Path $sourceFolder

# 获取所有文件
$files = Get-ChildItem -File

# 正则表达式用于匹配不同的日期格式
$datePatterns = @(
    '\d{4}_\d{2}_\d{2}_\d{2}_\d{2}',      # YYYY_MM_DD_HH_MM
    '\d{4}-\d{2}-\d{2} \d{2}-\d{2}-\d{2}', # YYYY-MM-DD HH-MM-SS
    '\d{14}'                             # YYYYMMDDHHMMSS
)

foreach ($file in $files) {
    $fileName = $file.Name
    $dateMatch = $null

    # 尝试匹配文件名中的日期
    foreach ($pattern in $datePatterns) {
        if ($fileName -match $pattern) {
            $dateMatch = $Matches[0]
            break
        }
    }

    if ($dateMatch) {
        # 根据匹配的日期构建目标文件夹路径
        if ($dateMatch.Length -eq 14) {
            # 日期格式为 YYYYMMDDHHMMSS
            $dateFolder = [datetime]::ParseExact($dateMatch, 'yyyyMMddHHmmss', $null).ToString('yyyy-MM-dd')
        } elseif ($dateMatch.Length -eq 10 -and $dateMatch.Contains('-')) {
            # 日期格式为 YYYY-MM-DD
            $dateFolder = $dateMatch.Substring(0, 10)
        } elseif ($dateMatch.Length -eq 16 -and $dateMatch.Contains('_')) {
            # 日期格式为 YYYY_MM_DD_HH_MM
            $dateFolder = $dateMatch.Substring(0, 10).Replace('_', '-')
        } else {
            # 默认格式为 YYYY-MM-DD
            $dateFolder = $dateMatch.Substring(0, 10)
        }

        # 创建目标文件夹路径
        $targetFolder = Join-Path -Path $sourceFolder -ChildPath $dateFolder

        # 如果目标文件夹不存在，则创建它
        if (-not (Test-Path -Path $targetFolder)) {
            New-Item -Path $targetFolder -ItemType Directory
        }

        # 移动文件到目标文件夹
        $destination = Join-Path -Path $targetFolder -ChildPath $file.Name
        Move-Item -Path $file.FullName -Destination $destination
    }
}
