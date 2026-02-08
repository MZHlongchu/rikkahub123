# =====================================================
# ProGuard 规则：禁用跟踪库和自动更新
# 用途：通过代码混淆和优化移除相关功能
# 注意：这可能会影响某些功能，请谨慎使用
# =====================================================

# 1. Firebase相关 - 如果完全移除Firebase依赖，以下规则不需要
# 但如果有其他模块依赖Firebase，需要添加- dontwarn

# 2. 禁用自动更新 - 移除UpdateChecker相关代码
# 注意：这会导致UpdateCard无法工作，但不会影响其他功能

# 移除UpdateChecker类（如果确定不需要）
#-keep class me.rerere.rikkahub.utils.UpdateChecker { *; }
#-dontwarn me.rerere.rikkahub.utils.UpdateChecker

# 更激进的：完全移除UpdateChecker及其依赖
#-keep class me.rerere.rikkahub.utils.** { *; }
#-keep class me.rerere.rikkahub.ui.components.ui.UpdateCard { *; }

# 3. 基于BuildConfig字段的条件编译（需要修改源码配合）
# 在代码中使用BuildConfig.DISABLE_AUTO_UPDATE进行条件判断
# 然后通过以下规则优化掉未使用的代码：
#-assumenosideeffects class me.rerere.rikkahub.utils.UpdateChecker {
#    void checkUpdate(...);
#}

# 4. 移除Firebase Analytics事件日志
#-assumenosideeffects class com.google.firebase.analytics.FirebaseAnalytics {
#    void logEvent(...);
#}

# 5. 保留必要的序列化类（不修改现有规则）
-keep @kotlinx.serialization.Serializable class * {*;}

# 6. 现有项目的混淆规则（保持不变）
-keepattributes SourceFile,LineNumberTable
-keep class org.scilab.forge.jlatexmath.** {*;}
-dontwarn com.google.re2j.**
-dontobfuscate

