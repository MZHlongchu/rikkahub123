# GitHub Actions 自动化构建指南

本指南说明如何使用提供的GitHub Actions工作流自动化构建RikkaHub的多个flavor。

---

## 📋 工作流文件

```
.github/workflows/
├── build-flavors.yml      # 主要构建工作流（多flavor）
├── daily-build.yml        # 每日构建和验证
└── (existing) release.yml # 原有release工作流（可选保留）
```

---

## 🚀 快速设置

### 1. 配置Secrets

参考 `.github/SECRETS_EXAMPLE.md`，在GitHub仓库Settings中添加以下secrets：

- `KEY_BASE64` - Base64编码的keystore
- `SIGNING_CONFIG` - 签名配置
- `GOOGLE_SERVICES_JSON` - Firebase配置（仅free flavor需要）

### 2. 确保Flavor配置正确

检查 `app/build.gradle.kts` 已配置productFlavors：

```kotlin
flavorDimensions += "privacy"

productFlavors {
    create("free") { ... }
    create("noTracking") { ... }
    create("privacy") { ... }
}
```

### 3. 测试工作流

手动触发一次工作流：
1. 进入 **Actions** 标签
2. 选择 **Build All Flavors**
3. 点击 **Run workflow**
4. 选择 flavor: `all`
5. 不勾选 release（先测试）
6. 点击 **Run workflow**

---

## 🔨 构建工作流说明

### build-flavors.yml

**触发条件**：
- 推送版本标签（如 `v1.0.0`）
- 手动触发（workflow_dispatch）

**功能**：
- 并行构建三个flavor：free, noTracking, privacy
- 自动重命名APK文件，包含flavor和版本信息
- 上传构建产物为artifact
- 自动创建GitHub Release（仅free flavor，且仅在推送标签时）

**输出文件命名**：
```
rikkahub-{flavor}-{version}.apk
示例：rikkahub-privacy-1.9.0-beta.1.apk
```

**构建命令**：
```bash
./gradlew :app:assemble{Flavor}Release
# 例如：./gradlew :app:assemblePrivacyRelease
```

### daily-build.yml

**触发条件**：
- 每天凌晨2点（UTC）
- 手动触发

**功能**：
- 验证构建配置
- 构建所有flavor的debug版本（无需签名）
- 运行代码检查（ktlint, detekt）
- 运行单元测试
- 可选构建AAB包

---

## 📦 构建产物

### APK文件位置
```
app/build/outputs/apk/
├── freeRelease/
│   └── rikkahub-free-{version}.apk
├── noTrackingRelease/
│   └── rikkahub-noTracking-{version}.apk
└── privacyRelease/
    └── rikkahub-privacy-{version}.apk
```

### AAB文件位置（如需要）
```
app/build/outputs/bundle/
├── freeRelease/
│   └── app-free-release.aab
├── noTrackingRelease/
│   └── app-noTracking-release.aab
└── privacyRelease/
    └── app-privacy-release.aab
```

---

## 🔖 版本管理

### 自动版本检测

工作流会自动从以下位置获取版本：

1. **Git标签**（优先级最高）：
   - 推送 `v1.0.0` 标签时，版本为 `1.0.0`
   - 适用于正式发布

2. **build.gradle.kts**：
   - 读取 `versionName` 值
   - 适用于手动触发或日常构建

### 版本标签建议

```bash
# 正式版
git tag v1.0.0
git push origin v1.0.0

# 测试版
git tag v1.0.0-beta.1
git push origin v1.0.0-beta.1

# 发布候选版
git tag v1.0.0-rc.1
git push origin v1.0.0-rc.1
```

推送标签后，工作流会自动：
- 构建free flavor的release APK和AAB
- 创建GitHub Release（带release notes）
- 上传所有构建产物

---

## 🎯 手动触发构建

### 构建单个Flavor

1. 进入 **Actions** → **Build All Flavors**
2. 点击 **Run workflow**
3. 填写参数：
   - **flavor**: 选择 `free`、`noTracking`、`privacy` 或 `all`
   - **release**: 选择 `true` 发布到GitHub Releases，`false` 仅保存artifact
4. 点击 **Run workflow**

### 构建Debug版本

使用 **Daily Build & Verify** 工作流：
1. 进入 **Actions** → **Daily Build & Verify**
2. 点击 **Run workflow**
3. 这将构建所有flavor的debug版本并运行检查

---

## 📊 Artifact管理

### 下载构建产物

1. 进入工作流运行记录
2. 点击 **Artifacts** 部分
3. 下载所需的APK或AAB文件

### Artifact保留策略

- **Release构建**：永久保留（GitHub Releases）
- **Debug构建**：保留7天（daily-build.yml配置）
- **AAB构建**：保留30天

---

## 🐛 故障排除

### 问题：签名失败

**症状**：`Signing config not found` 或 `Keystore was tampered with`

**解决**：
1. 检查 `KEY_BASE64` 是否正确base64编码
2. 验证 `SIGNING_CONFIG` 中的密码和alias
3. 确保keystore文件未损坏：`keytool -list -v -keystore app/app.jks`

### 问题：找不到Flavor任务

**症状**：`Task 'assemblePrivacyRelease' not found`

**解决**：
1. 确认 `app/build.gradle.kts` 已配置productFlavors
2. 检查flavor名称拼写（大小写敏感）
3. 运行 `./gradlew tasks --all` 查看可用任务

### 问题：Google Services配置错误

**症状**：`The plugin com.google.gms.google-services is not found`

**解决**：
1. 仅free flavor需要 `google-services.json`
2. 确保文件格式正确（JSON）
3. 检查 `app/build.gradle.kts` 中apply plugin配置

### 问题：工作流卡住或超时

**症状**：构建时间过长或失败

**解决**：
1. 启用Gradle缓存（已配置）
2. 考虑使用更大的runner（`runs-on: ubuntu-latest` → `ubuntu-24.04-arm` 或自托管runner）
3. 检查网络连接（依赖下载）

---

## 🔧 自定义配置

### 修改保留期限

编辑 `.github/workflows/*.yml` 中的 `retention-days`：

```yaml
- uses: actions/upload-artifact@v4
  with:
    retention-days: 30  # 修改此值
```

### 添加更多Flavor

1. 在 `app/build.gradle.kts` 添加新的flavor
2. 在 `build-flavors.yml` 的matrix中添加：
   ```yaml
   strategy:
     matrix:
       flavor: [free, noTracking, privacy, yourNewFlavor]
   ```
3. 更新构建和上传步骤

### 启用代码覆盖率

在 `daily-build.yml` 的test job中添加：

```yaml
- name: Generate coverage report
  run: |
    ./gradlew jacocoTestReport

- name: Upload coverage to Codecov
  uses: codecov/codecov-action@v4
  with:
    file: app/build/reports/jacoco/jacocoTestReport/jacocoTestReport.xml
```

---

## 📈 最佳实践

1. **标签命名规范**：
   - 使用语义化版本：`vMAJOR.MINOR.PATCH`
   - 预发布版本：`v1.0.0-beta.1`、`v1.0.0-rc.1`

2. **Secret管理**：
   - 定期轮换keystore密码
   - 使用不同的Firebase项目用于不同flavor（可选）
   - 考虑使用环境保护规则

3. **测试策略**：
   - 日常构建debug版本进行测试
   - Release构建前运行完整测试套件
   - 使用不同的测试flavor

4. **Release说明**：
   - 使用 `CHANGELOG.md` 自动生成release notes
   - 在 `build-flavors.yml` 中设置 `generate_release_notes: true`

---

## 🔄 与本地构建同步

确保本地环境与CI环境一致：

1. **Java版本**：CI使用JDK 17，本地也应使用相同版本
2. **Gradle版本**：使用wrapper（`./gradlew`）
3. **Flavor配置**：本地测试所有flavor：
   ```bash
   ./gradlew assemblePrivacyRelease
   ./gradlew assembleNoTrackingRelease
   ./gradlew assembleFreeRelease
   ```

---

## 📝 注意事项

1. **签名密钥安全**：
   - 不要将keystore文件提交到仓库
   - 定期备份keystore
   - 使用强密码

2. **Firebase配置**：
   - `google-services.json` 仅用于free flavor
   - noTracking和privacy flavor不需要Firebase

3. **版本一致性**：
   - 确保 `build.gradle.kts` 中的版本与git tag一致
   - 发布前更新版本号

4. **Artifact大小**：
   - 监控artifact大小，避免超过GitHub限制（2GB per file）
   - 使用 `.gitattributes` 压缩大型文件

---

## 🎉 开始使用

1. 配置Secrets（参考 `.github/SECRETS_EXAMPLE.md`）
2. 手动测试构建一个flavor
3. 验证APK功能正常
4. 创建版本标签触发自动发布
5. 享受自动化构建的便利！

---

**相关文档**：
- `config/IMPLEMENTATION_GUIDE.md` - Flavor配置详情
- `config/README.md` - 配置包说明
- `.github/workflows/build-flavors.yml` - 工作流源码

