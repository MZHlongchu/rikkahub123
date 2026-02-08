// =====================================================
// RikkaHub Gradle 构建配置修改示例
// 文件：app/build.gradle.kts
// 用途：禁用跟踪库、修改包名、禁用自动更新
// =====================================================

// 在文件顶部的plugins块之后添加：
android {
    // ... 现有配置 ...

    // 1. 添加产品风味（Product Flavors）支持
    flavorDimensions += "privacy"

    productFlavors {
        // 默认版本（包含所有功能）
        create("free") {
            dimension = "privacy"
            // 使用默认包名
            applicationIdSuffix = ""
        }

        // 无跟踪版本（禁用Firebase跟踪，保留更新）
        create("noTracking") {
            dimension = "privacy"
            applicationIdSuffix = ".notracking"
            // 添加BuildConfig字段控制功能
            buildConfigField("boolean", "DISABLE_FIREBASE_ANALYTICS", "true")
            buildConfigField("boolean", "DISABLE_FIREBASE_CRASHLYTICS", "true")
            buildConfigField("boolean", "DISABLE_FIREBASE_REMOTE_CONFIG", "true")
            buildConfigField("boolean", "DISABLE_AUTO_UPDATE", "false") // 保留更新检查
        }

        // 隐私版本（禁用跟踪和更新）
        create("privacy") {
            dimension = "privacy"
            applicationIdSuffix = ".privacy"
            buildConfigField("boolean", "DISABLE_FIREBASE_ANALYTICS", "true")
            buildConfigField("boolean", "DISABLE_FIREBASE_CRASHLYTICS", "true")
            buildConfigField("boolean", "DISABLE_FIREBASE_REMOTE_CONFIG", "true")
            buildConfigField("boolean", "DISABLE_AUTO_UPDATE", "true")
        }
    }

    // 2. 如果要修改包名（不通过flavor），直接修改：
    // namespace = "com.yourcompany.rikkahub"
    // defaultConfig {
    //     applicationId = "com.yourcompany.rikkahub"
    // }

    // 3. 为不同构建类型配置资源覆盖
    sourceSets {
        // 为privacy flavor创建资源覆盖
        getByName("privacy") {
            res.srcDirs("src/privacy/res")
        }
        getByName("noTracking") {
            res.srcDirs("src/noTracking/res")
        }
    }

    // ... 其余现有配置 ...
}

// 4. 修改dependencies块以条件性添加Firebase依赖
dependencies {
    // 基础依赖（保持不变）
    implementation(libs.androidx.core.ktx)
    // ... 其他依赖 ...

    // Firebase依赖 - 根据flavor条件添加
    // 方法1：使用flavor-specific source sets（推荐）
    // 在 app/src/noTracking/build.gradle.kts 和 app/src/privacy/build.gradle.kts 中移除Firebase依赖

    // 方法2：使用Gradle的配置条件（如果不想创建单独的build.gradle.kts）
    // 在根build.gradle.kts中添加：
    afterEvaluate {
        dependencies {
            if (!project.hasProperty("disableFirebase")) {
                implementation(platform(libs.firebase.bom))
                implementation(libs.firebase.analytics)
                implementation(libs.firebase.crashlytics)
                implementation(libs.firebase.config)
            }
        }
    }
}

// 5. 可选：通过gradle.properties控制
// 在 gradle.properties 中添加：
// disableFirebase=true
// disableAutoUpdate=true

