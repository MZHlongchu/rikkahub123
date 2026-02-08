# RikkaHub 配置实施指南

## 概述

本指南详细说明如何通过Gradle构建配置实现以下目标，**无需修改源码**：

1. ✅ 禁用跟踪库（Firebase Analytics, Crashlytics, Remote Config）
2. ✅ 修改应用包名
3. ✅ 禁用APK自动更新检查

---

## 项目结构分析

### 检测到的跟踪库

| 库名 | 依赖标识 | 用途 | 位置 |
|------|---------|------|------|
| Firebase Analytics | `com.google.firebase:firebase-analytics` | 用户行为分析 | `app/build.gradle.kts` |
| Firebase Crashlytics | `com.google.firebase:firebase-crashlytics` | 崩溃报告 | `app/build.gradle.kts` |
| Firebase Remote Config | `com.google.firebase:firebase-config` | 远程配置 | `app/build.gradle.kts` |

初始化位置：`app/src/main/java/me/rerere/rikkahub/RikkaHubApp.kt` 和 `app/src/main/java/me/rerere/rikkahub/di/AppModule.kt`

### APK自动更新机制

```
UpdateChecker.kt (检查更新)
    ↓
ChatVM.kt (初始化时自动触发)
    ↓
UpdateCard.kt (显示更新UI)
    ↓
用户点击下载 → DownloadManager
```

更新检查API：`https://updates.rikka-ai.com/`

控制开关：
- `Settings.displaySetting.showUpdates` (默认为 `true`)
- 位置：`app/src/main/java/me/rerere/rikkahub/data/datastore/PreferencesStore.kt`

### 当前包名

```
namespace: me.rerere.rikkahub
applicationId: me.rerere.rikkahub
```

---

## 实施方案

### 方案一：产品风味（Product Flavors）【推荐】

此方案创建多个构建变体，每个变体有不同的功能组合。

#### 步骤1：修改 `app/build.gradle.kts`

在 `android {}` 块中添加：

```kotlin
android {
    // ... 现有配置 ...

    // 添加风味维度
    flavorDimensions += "privacy"

    productFlavors {
        // 1. 完整版（默认，包含所有功能）
        create("free") {
            dimension = "privacy"
            applicationIdSuffix = ""
            // 不设置BuildConfig字段，使用默认行为
        }

        // 2. 无跟踪版（禁用Firebase，保留更新）
        create("noTracking") {
            dimension = "privacy"
            applicationIdSuffix = ".notracking"
            buildConfigField("boolean", "DISABLE_FIREBASE_ANALYTICS", "true")
            buildConfigField("boolean", "DISABLE_FIREBASE_CRASHLYTICS", "true")
            buildConfigField("boolean", "DISABLE_FIREBASE_REMOTE_CONFIG", "true")
            buildConfigField("boolean", "DISABLE_AUTO_UPDATE", "false")
        }

        // 3. 隐私版（禁用跟踪和更新）
        create("privacy") {
            dimension = "privacy"
            applicationIdSuffix = ".privacy"
            buildConfigField("boolean", "DISABLE_FIREBASE_ANALYTICS", "true")
            buildConfigField("boolean", "DISABLE_FIREBASE_CRASHLYTICS", "true")
            buildConfigField("boolean", "DISABLE_FIREBASE_REMOTE_CONFIG", "true")
            buildConfigField("boolean", "DISABLE_AUTO_UPDATE", "true")
        }
    }

    // 为不同flavor配置资源目录
    sourceSets {
        getByName("privacy") {
            res.srcDirs("src/privacy/res")
        }
        getByName("noTracking") {
            res.srcDirs("src/noTracking/res")
        }
    }
}
```

#### 步骤2：为每个flavor创建独立的依赖配置

创建文件 `app/src/noTracking/build.gradle.kts`：

```kotlin
dependencies {
    // 继承主配置，但移除Firebase依赖
}
```

创建文件 `app/src/privacy/build.gradle.kts`：

```kotlin
dependencies {
    // 同样移除Firebase依赖
}
```

或者使用flavor-specific依赖（推荐）：

在主 `app/build.gradle.kts` 的 `dependencies` 块中：

```kotlin
dependencies {
    // 基础依赖（所有flavor）
    implementation(libs.androidx.core.ktx)
    // ... 其他通用依赖 ...

    // Firebase仅在free flavor中启用
    freeImplementation(platform(libs.firebase.bom))
    freeImplementation(libs.firebase.analytics)
    freeImplementation(libs.firebase.crashlytics)
    freeImplementation(libs.firebase.config)
}
```

#### 步骤3：创建资源覆盖文件

为 `privacy` 和 `noTracking` flavor创建资源目录：

```
app/src/privacy/res/values/config.xml
app/src/noTracking/res/values/config.xml
```

内容（禁用更新提示）：

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <bool name="show_updates">false</bool>
</resources>
```

#### 步骤4：覆盖UpdateChecker类（无需修改主源码）

创建flavor-specific的源文件覆盖：

```
app/src/privacy/java/me/rerere/rikkahub/utils/UpdateChecker.kt
app/src/noTracking/java/me/rerere/rikkahub/utils/UpdateChecker.kt
```

示例 `app/src/privacy/java/me/rerere/rikkahub/utils/UpdateChecker.kt`：

```kotlin
package me.rerere.rikkahub.utils

import androidx.compose.runtime.MutableStateFlow
import androidx.compose.runtime.StateFlow
import me.rerere.rikkahub.utils.UiState

/**
 * 隐私版本的UpdateChecker - 禁用更新检查
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
```

**注意**：需要保持与原始类相同的包名和类结构，但实现为空。这会完全替换主源码中的实现。

#### 步骤5：修改包名（可选）

如果需要修改包名，在flavor中设置：

```kotlin
productFlavors {
    create("privacy") {
        dimension = "privacy"
        applicationId = "com.yourcompany.rikkahub.privacy"  // 完全自定义
        // 或使用suffix保持基础包名
        // applicationIdSuffix = ".privacy"
    }
}
```

**注意**：如果修改 `applicationId`，需要确保所有Manifest中的 `provider.authorities` 使用 `${applicationId}.fileprovider` 形式（当前已正确使用）。

#### 步骤6：构建命令

```bash
# 构建隐私版（禁用跟踪和更新）
./gradlew assemblePrivacyRelease

# 构建无跟踪版（禁用跟踪，保留更新）
./gradlew assembleNoTrackingRelease

# 构建完整版（包含所有功能）
./gradlew assembleFreeRelease

# 构建所有版本
./gradlew assembleRelease
```

---

### 方案二：使用Gradle属性控制（简化版）

如果不需要多个flavor，可以通过Gradle属性控制：

#### 步骤1：`gradle.properties`

```properties
# 禁用Firebase
disableFirebase=true

# 禁用自动更新
disableAutoUpdate=true
```

#### 步骤2：`app/build.gradle.kts`

```kotlin
android {
    defaultConfig {
        // 条件性添加BuildConfig字段
        if (project.hasProperty("disableAutoUpdate")) {
            buildConfigField("boolean", "DISABLE_AUTO_UPDATE", "true")
        }
    }
}

dependencies {
    // 条件性添加Firebase依赖
    if (!project.hasProperty("disableFirebase")) {
        implementation(platform(libs.firebase.bom))
        implementation(libs.firebase.analytics)
        implementation(libs.firebase.crashlytics)
        implementation(libs.firebase.config)
    }
}
```

**限制**：需要修改源码以检查 `BuildConfig.DISABLE_AUTO_UPDATE`。

---

## 验证清单

构建后，验证以下内容：

- [ ] **APK大小**：隐私版应比完整版小（缺少Firebase库，约500KB-2MB差异）
- [ ] **无Firebase类**：使用 `apktool` 或 `jadx` 反编译，确认没有 `com/google/firebase/` 包
- [ ] **无更新检查**：隐私版中不应看到更新提示UI
- [ ] **无网络请求**：使用抓包工具，确认没有请求到 `firebase` 或 `updates.rikka-ai.com` 域名
- [ ] **包名正确**：安装后检查包名是否为预期值
- [ ] **功能正常**：核心聊天功能不受影响

---

## 常见问题

### Q1: 移除Firebase后，应用会崩溃吗？

**A**：只要正确移除依赖且不引用Firebase类，就不会崩溃。需要确保：
- 所有Firebase相关的代码都有条件编译或已被覆盖
- `RikkaHubApp.kt` 和 `AppModule.kt` 中的Firebase初始化需要条件化处理

**解决方案**：使用flavor-specific源文件覆盖这些类，或使用 `if (BuildConfig.DISABLE_FIREBASE_XXX)` 包裹。

### Q2: 如何完全移除Firebase初始化代码？

**A**：创建flavor-specific版本：

```
app/src/privacy/java/me/rerere/rikkahub/RikkaHubApp.kt
app/src/privacy/java/me/rerere/rikkahub/di/AppModule.kt
```

在这些文件中，不初始化Firebase。

### Q3: 修改包名后，现有数据会丢失吗？

**A**：`applicationId` 是应用的唯一标识。修改后，系统会视为全新应用，**数据不会迁移**。如果需要保留数据，需要：
1. 使用相同的 `applicationId` 但不同的 `applicationIdSuffix`（仅调试版本）
2. 或编写数据迁移脚本（复杂）

### Q4: 如何同时支持多个版本发布？

**A**：使用不同的 `applicationIdSuffix`：

```kotlin
free { applicationIdSuffix = "" }          // me.rerere.rikkahub
noTracking { applicationIdSuffix = ".nt" } // me.rerere.rikkahub.nt
privacy { applicationIdSuffix = ".p" }     // me.rerere.rikkahub.p
```

这样三个版本可以同时安装在同一设备上。

### Q5: 更新检查完全禁用了吗？

**A**：通过flavor-specific覆盖 `UpdateChecker.kt`，可以确保：
- `UpdateChecker.checkUpdate()` 立即返回空数据
- `UpdateCard` 不会显示更新提示（因为无新版本）
- 不会发起网络请求

但 `UpdateChecker` 类仍存在（空实现）。如需完全移除，需使用ProGuard：

```proguard
-assumenosideeffects class me.rerere.rikkahub.utils.UpdateChecker {
    void checkUpdate(...);
}
```

但这需要代码不直接引用 `UpdateChecker` 的其它方法。

---

## 总结

**推荐方案**：产品风味 + flavor-specific源文件覆盖

优点：
- ✅ 无需修改主源码
- ✅ 支持多版本共存
- ✅ 完全移除跟踪库依赖
- ✅ 完全禁用更新检查
- ✅ 灵活控制包名
- ✅ 易于维护和扩展

缺点：
- ⚠️ 需要创建额外的源文件
- ⚠️ 需要理解Gradle产品风味概念

---

## 联系

如有问题，请参考：
- `config/gradle-build-config.kts` - Gradle配置示例
- `config/res-values-config.xml` - 资源覆盖示例
- `config/proguard-rules-disable-tracking.pro` - ProGuard规则

