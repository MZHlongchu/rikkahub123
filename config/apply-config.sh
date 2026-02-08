#!/bin/bash

# =====================================================
# RikkaHub 配置应用脚本
# 用途：自动应用禁用跟踪、改包名、禁更新的配置
# 用法：bash apply-config.sh [flavor]
# 示例：bash apply-config.sh privacy
# =====================================================

set -e  # 遇到错误退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 配置参数
FLAVOR="${1:-privacy}"  # 默认flavor为privacy
CONFIG_FILE="rikkahub-config.yml"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}RikkaHub 配置应用脚本${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# 检查配置文件是否存在
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}错误: 找不到配置文件 $CONFIG_FILE${NC}"
    echo "请确保在项目根目录运行此脚本"
    exit 1
fi

# 读取配置（使用yq或手动解析）
echo -e "${YELLOW}正在读取配置...${NC}"

# 简单解析YAML（如果没有yq）
if command -v yq &> /dev/null; then
    DISABLE_FIREBASE_ANALYTICS=$(yq e '.disable_firebase_analytics' $CONFIG_FILE)
    DISABLE_AUTO_UPDATE=$(yq e '.disable_auto_update' $CONFIG_FILE)
    NEW_APP_ID=$(yq e '.new_application_id' $CONFIG_FILE)
else
    # 简单grep解析（仅适用于本配置格式）
    DISABLE_FIREBASE_ANALYTICS=$(grep -E '^disable_firebase_analytics:' $CONFIG_FILE | awk '{print $2}')
    DISABLE_AUTO_UPDATE=$(grep -E '^disable_auto_update:' $CONFIG_FILE | awk '{print $2}')
    NEW_APP_ID=$(grep -E '^new_application_id:' $CONFIG_FILE | awk '{print $2}')
fi

echo "配置读取完成:"
echo "  - 禁用Firebase Analytics: $DISABLE_FIREBASE_ANALYTICS"
echo "  - 禁用自动更新: $DISABLE_AUTO_UPDATE"
echo "  - 新的应用ID: ${NEW_APP_ID:-(不修改)}"
echo ""

# 确认
echo -e "${YELLOW}即将应用配置到项目...${NC}"
echo "目标flavor: $FLAVOR"
echo ""
read -p "确认继续? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "取消操作"
    exit 0
fi

# 1. 检查并修改 app/build.gradle.kts
echo -e "${GREEN}[1/5] 检查 app/build.gradle.kts...${NC}"

if [ ! -f "app/build.gradle.kts" ]; then
    echo -e "${RED}错误: app/build.gradle.kts 不存在${NC}"
    exit 1
fi

# 备份原文件
cp app/build.gradle.kts app/build.gradle.kts.backup
echo "已创建备份: app/build.gradle.kts.backup"

# 检查是否已添加flavor配置
if grep -q "flavorDimensions" app/build.gradle.kts; then
    echo "检测到已配置productFlavors，跳过..."
else
    echo "正在添加productFlavors配置..."
    # 这里可以自动插入配置，但风险较高，建议手动修改
    echo -e "${YELLOW}请手动参考 config/gradle-build-config.kts 修改 app/build.gradle.kts${NC}"
    echo "需要添加:"
    echo "  - flavorDimensions += \"privacy\""
    echo "  - productFlavors { free, noTracking, privacy }"
    echo "  - sourceSets 配置"
    echo "  - 使用freeImplementation控制Firebase依赖"
fi

# 2. 创建flavor-specific源文件
echo -e "${GREEN}[2/5] 创建flavor-specific源文件...${NC}"

if [ "$FLAVOR" = "privacy" ] || [ "$FLAVOR" = "noTracking" ]; then
    # 创建UpdateChecker覆盖
    UPDATE_CHECKER_DIR="app/src/$FLAVOR/java/me/rerere/rikkahub/utils"
    mkdir -p "$UPDATE_CHECKER_DIR"

    UPDATE_CHECKER_FILE="$UPDATE_CHECKER_DIR/UpdateChecker.kt"
    if [ ! -f "$UPDATE_CHECKER_FILE" ]; then
        cat > "$UPDATE_CHECKER_FILE" << 'EOF'
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
EOF
        echo "已创建: $UPDATE_CHECKER_FILE"
    else
        echo "文件已存在，跳过: $UPDATE_CHECKER_FILE"
    fi
else
    echo "flavor '$FLAVOR' 不需要覆盖UpdateChecker"
fi

# 3. 创建资源覆盖文件
echo -e "${GREEN}[3/5] 创建资源覆盖文件...${NC}"

if [ "$FLAVOR" = "privacy" ] || [ "$FLAVOR" = "noTracking" ]; then
    RES_DIR="app/src/$FLAVOR/res/values"
    mkdir -p "$RES_DIR"

    RES_FILE="$RES_DIR/config.xml"
    if [ ! -f "$RES_FILE" ]; then
        cat > "$RES_FILE" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <bool name="show_updates">false</bool>
</resources>
EOF
        echo "已创建: $RES_FILE"
    else
        echo "文件已存在，跳过: $RES_FILE"
    fi
fi

# 4. 创建build.gradle.kts（如果不存在）
echo -e "${GREEN}[4/5] 检查flavor-specific build配置...${NC}"

FLAVOR_BUILD_FILE="app/src/$FLAVOR/build.gradle.kts"
if [ -d "app/src/$FLAVOR" ] && [ ! -f "$FLAVOR_BUILD_FILE" ]; then
    cat > "$FLAVOR_BUILD_FILE" << EOF
// $FLAVOR flavor specific configuration
// 在此可以覆盖依赖或添加特定配置

dependencies {
    // 如果需要排除某些依赖，可以在这里配置
    // 例如：不包含Firebase依赖（已在主配置中使用freeImplementation）
}
EOF
    echo "已创建: $FLAVOR_BUILD_FILE"
fi

# 5. 检查gradle.properties
echo -e "${GREEN}[5/5] 检查 gradle.properties...${NC}"

if [ -f "gradle.properties" ]; then
    echo "gradle.properties 已存在"
    if grep -q "disableFirebase" gradle.properties; then
        echo "  已包含 disableFirebase 配置"
    else
        echo -e "  ${YELLOW}建议添加: disableFirebase=true${NC}"
    fi
else
    echo -e "${YELLOW}未找到 gradle.properties，建议创建并添加:${NC}"
    echo "  disableFirebase=true"
    echo "  disableAutoUpdate=true"
fi

# 完成
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}配置应用完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "下一步："
echo "1. 手动修改 app/build.gradle.kts（如果尚未修改）"
echo "2. 运行构建命令："
echo "   ./gradlew assemble${FLAVOR^}Release"
echo ""
echo "验证："
echo "  - 检查APK大小"
echo "  - 反编译检查Firebase类"
echo "  - 运行应用验证功能"
echo ""

