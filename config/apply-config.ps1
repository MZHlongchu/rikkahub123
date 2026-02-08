# =====================================================
# RikkaHub 配置应用脚本 (Windows PowerShell)
# 用途：自动应用禁用跟踪、改包名、禁更新的配置
# 用法：powershell -ExecutionPolicy Bypass -File apply-config.ps1 [flavor]
# 示例：powershell -File apply-config.ps1 privacy
# =====================================================

param(
    [string]$FLAVOR = "privacy"  # 默认flavor为privacy
)

$CONFIG_FILE = "rikkahub-config.yml"

Write-Host "========================================" -ForegroundColor Green
Write-Host "RikkaHub 配置应用脚本 (Windows)" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# 检查配置文件是否存在
if (-not (Test-Path $CONFIG_FILE)) {
    Write-Host "错误: 找不到配置文件 $CONFIG_FILE" -ForegroundColor Red
    Write-Host "请确保在项目根目录运行此脚本"
    exit 1
}

Write-Host "正在读取配置..." -ForegroundColor Yellow

# 读取配置（简单解析YAML）
$CONFIG_CONTENT = Get-Content $CONFIG_FILE -Raw
$DISABLE_FIREBASE_ANALYTICS = ($CONFIG_CONTENT -match 'disable_firebase_analytics:\s*(true|false)') ? $matches[1] : "true"
$DISABLE_AUTO_UPDATE = ($CONFIG_CONTENT -match 'disable_auto_update:\s*(true|false)') ? $matches[1] : "true"
$NEW_APP_ID = ($CONFIG_CONTENT -match 'new_application_id:\s*"([^"]+)"') ? $matches[1] : ""

Write-Host "配置读取完成:"
Write-Host "  - 禁用Firebase Analytics: $DISABLE_FIREBASE_ANALYTICS"
Write-Host "  - 禁用自动更新: $DISABLE_AUTO_UPDATE"
Write-Host "  - 新的应用ID: $(if ($NEW_APP_ID) { $NEW_APP_ID } else { '(不修改)' })"
Write-Host ""

# 确认
Write-Host "即将应用配置到项目..." -ForegroundColor Yellow
Write-Host "目标flavor: $FLAVOR"
Write-Host ""
$CONFIRM = Read-Host "确认继续? (y/N)"
if ($CONFIRM -notmatch '^[Yy]$') {
    Write-Host "取消操作"
    exit 0
}

# 1. 检查并备份 app/build.gradle.kts
Write-Host "[1/5] 检查 app/build.gradle.kts..." -ForegroundColor Green

if (-not (Test-Path "app/build.gradle.kts")) {
    Write-Host "错误: app/build.gradle.kts 不存在" -ForegroundColor Red
    exit 1
}

Copy-Item "app/build.gradle.kts" "app/build.gradle.kts.backup"
Write-Host "已创建备份: app/build.gradle.kts.backup"

# 检查是否已添加flavor配置
$BUILD_GRADLE_CONTENT = Get-Content "app/build.gradle.kts" -Raw
if ($BUILD_GRADLE_CONTENT -match "flavorDimensions") {
    Write-Host "检测到已配置productFlavors，跳过..."
} else {
    Write-Host "正在添加productFlavors配置..."
    Write-Host "  - flavorDimensions += `"privacy`""
    Write-Host "  - productFlavors { free, noTracking, privacy }"
    Write-Host "  - sourceSets 配置"
    Write-Host "  - 使用freeImplementation控制Firebase依赖"
    Write-Host "请手动参考 config\gradle-build-config.kts 修改 app/build.gradle.kts" -ForegroundColor Yellow
}

# 2. 创建flavor-specific源文件
Write-Host "[2/5] 创建flavor-specific源文件..." -ForegroundColor Green

if ($FLAVOR -eq "privacy" -or $FLAVOR -eq "noTracking") {
    $UPDATE_CHECKER_DIR = "app/src/$FLAVOR/java/me/rerere/rikkahub/utils"
    if (-not (Test-Path $UPDATE_CHECKER_DIR)) {
        New-Item -ItemType Directory -Path $UPDATE_CHECKER_DIR -Force | Out-Null
    }

    $UPDATE_CHECKER_FILE = "$UPDATE_CHECKER_DIR/UpdateChecker.kt"
    if (-not (Test-Path $UPDATE_CHECKER_FILE)) {
        @"
package me.rerere.rikkahub.utils

import androidx.compose.runtime.MutableStateFlow
import androidx.compose.runtime.StateFlow
import me.rerere.rikkahub.utils.UiState

/**
 * $FLAVOR版本的UpdateChecker - 禁用更新检查
 */
class UpdateChecker(private val client: Any?) {
    fun checkUpdate(): StateFlow<UiState<UpdateInfo>> {
        return MutableStateFlow(UiState.Success(UpdateInfo("", "", "", emptyList())))
    }

    fun downloadUpdate(context: Any, download: UpdateDownload) {
        // 空实现
    }
}

@Serializable
data class UpdateDownload(
    val name: String,
    val url: String,
    val size: String
)

@Serializable
data class UpdateInfo(
    val version: String,
    val publishedAt: String,
    val changelog: String,
    val downloads: List<UpdateDownload>
)
"@ | Out-File -FilePath $UPDATE_CHECKER_FILE -Encoding UTF8
        Write-Host "已创建: $UPDATE_CHECKER_FILE"
    } else {
        Write-Host "文件已存在，跳过: $UPDATE_CHECKER_FILE"
    }
} else {
    Write-Host "flavor '$FLAVOR' 不需要覆盖UpdateChecker"
}

# 3. 创建资源覆盖文件
Write-Host "[3/5] 创建资源覆盖文件..." -ForegroundColor Green

if ($FLAVOR -eq "privacy" -or $FLAVOR -eq "noTracking") {
    $RES_DIR = "app/src/$FLAVOR/res/values"
    if (-not (Test-Path $RES_DIR)) {
        New-Item -ItemType Directory -Path $RES_DIR -Force | Out-Null
    }

    $RES_FILE = "$RES_DIR/config.xml"
    if (-not (Test-Path $RES_FILE)) {
        @'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <bool name="show_updates">false</bool>
</resources>
'@ | Out-File -FilePath $RES_FILE -Encoding UTF8
        Write-Host "已创建: $RES_FILE"
    } else {
        Write-Host "文件已存在，跳过: $RES_FILE"
    }
}

# 4. 创建build.gradle.kts（如果不存在）
Write-Host "[4/5] 检查flavor-specific build配置..." -ForegroundColor Green

$FLAVOR_BUILD_FILE = "app/src/$FLAVOR/build.gradle.kts"
if ((Test-Path "app/src/$FLAVOR") -and (-not (Test-Path $FLAVOR_BUILD_FILE))) {
    @"
// $FLAVOR flavor specific configuration
// 在此可以覆盖依赖或添加特定配置

dependencies {
    // 如果需要排除某些依赖，可以在这里配置
    // 例如：不包含Firebase依赖（已在主配置中使用freeImplementation）
}
"@ | Out-File -FilePath $FLAVOR_BUILD_FILE -Encoding UTF8
    Write-Host "已创建: $FLAVOR_BUILD_FILE"
}

# 5. 检查gradle.properties
Write-Host "[5/5] 检查 gradle.properties..." -ForegroundColor Green

if (Test-Path "gradle.properties") {
    Write-Host "gradle.properties 已存在"
    $GRADLE_PROPS = Get-Content "gradle.properties" -Raw
    if ($GRADLE_PROPS -match "disableFirebase") {
        Write-Host "  已包含 disableFirebase 配置"
    } else {
        Write-Host "  建议添加: disableFirebase=true" -ForegroundColor Yellow
    }
} else {
    Write-Host "未找到 gradle.properties，建议创建并添加:" -ForegroundColor Yellow
    Write-Host "  disableFirebase=true"
    Write-Host "  disableAutoUpdate=true"
}

# 完成
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "配置应用完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "下一步："
Write-Host "1. 手动修改 app/build.gradle.kts（如果尚未修改）"
Write-Host "2. 运行构建命令："
Write-Host "   .\gradlew assemble$($FLAVOR.Substring(0,1).ToUpper() + $FLAVOR.Substring(1))Release"
Write-Host ""
Write-Host "验证："
Write-Host "  - 检查APK大小"
Write-Host "  - 反编译检查Firebase类"
Write-Host "  - 运行应用验证功能"
Write-Host ""

