
## 🧭 产品定位简述

### 🎯 **目标**

构建一个“**图片上传 → 自动裁剪 → 多设备 Widget 自动展示**”的 iOS 18的应用，帮助用户在无需反复操作的前提下，把喜爱的图片以高质量、稳定一致的方式展示在设备桌面上。

---

## 📱 使用场景与用户价值

| 角色         | 需求                       | 本产品如何满足                  |
| ---------- | ------------------------ | ------------------------ |
| 用户（iPhone） | 想把喜爱的插画/照片设置在 Widget 上展示 | App 提供上传界面，一次上传后自动生效     |
| 用户（Mac）    | 希望在 Mac 上也看到同样图片         | 未来可通过 CloudKit 自动同步      |
| 用户（非技术）    | 不懂剪裁比例，不希望图片被裁掉或拉伸       | App 自动裁剪为 Widget 比例，避免失真 |
| 追求仪式感用户    | 喜欢定期更换桌面照片形成“生活感”        | 可管理最多 30 张图片，自动轮播，无需手动切换 |

---

## 🧩 功能结构总览

### App 主体功能：

| 功能            | 描述                                                   |
| --------------- | ------------------------------------------------------ |
| ✅ 添加图片      | 选择自定义图片，自动裁剪为 Widget 比例                 |
| ✅ 裁剪逻辑      | 固定中尺寸 Widget 比例                                 |
| ✅ 文件存储      | 裁剪图保存至 App Group，命名为 UUID.jpg                |
| ✅ metadata 管理 | 使用 JSON 记录添加时间、顺序等                         |
| ✅ 删除单张图片  | 长按图片卡片删除，并更新 metadata 与缓存               |
| ✅ 清空全部图片  | 一键清空所有图片，立即刷新 Widget                      |
| ✅ 数量限制      | 限制最多添加 30 张图片，超限后按钮置灰，显示 “30 / 30” |
| ✅ 权限处理      | 友好提示照片访问权限引导到系统设置                     |

---

### Widget 功能：

| 模块       | 说明                                     |
| -------- | -------------------------------------- |
| 📦 本地读取  | Widget 使用 App Group 中的裁剪图片与 metadata   |
| 🎞️ 显示方式 | 支持顺序播放（默认按添加顺序），未来可扩展随机播放              |
| 🔄 数据刷新  | App 每次图片变动后立即调用 `reloadAllTimelines()` |
| 📱 展示平台  | 支持 iPhone 主屏、macOS 桌面中号 Widget（未来）     |

---

## 🛠️ 技术实现核心原则

| 关键点          | 说明                                                    |
| ------------ | ----------------------------------------------------- |
| 本地裁剪         | 图片由 App 主动处理裁剪，避免 Widget 自动缩放的失控问题                    |
| metadata 独立  | 图片列表通过 `metadata.json` 管理，避免文件系统不一致问题                 |
| App Group 共享 | 图片与 metadata 存于 App Group，确保 App 与 Widget 通信          |
| 可扩展性         | 未来可迁移至 CloudKit：metadata → `CKRecord`，裁剪图 → `CKAsset` |
| 强用户感知更新      | 每次图片变动都强制刷新 Widget，几秒内完成反馈                            |

---

## 🧠 总结一句话：

> 这是一款强调“**视觉控制、自动同步、轻量体验**”的桌面图像展示工具，用户上传即展示，裁剪可控，效果统一，为日常生活添加审美感与陪伴感。

---




------

# 📱 应用页面设计文档

## 页面一：**首页（ContentView）**

### UI 元素（实际实现）

| 元素                  | 类型         | 操作     | 实现函数                          |
| --------------------- | ------------ | -------- | ------------------------------------- |
| 「Choose Photos」按钮 | PhotosPicker | 点击     | `PhotosPicker(selection:)` → 直接选择图片 |
| 底部 Logo / 装饰      | Image        | 静态展示 | 无功能，仅装饰用途                    |

### 🧩 功能作用

- 引导用户进入「添加图片 → 浏览」流程；
- 直接集成了图片选择、裁剪和保存逻辑；
- 选择图片后自动裁剪并跳转进入 **浏览页（GalleryView）**。

------

## 页面二：**浏览页（已添加图片卡片展示）**

### UI 元素拆解（实际实现）

| 元素                    | 类型                       | 操作         | 实现函数                                     |
| ----------------------- | -------------------------- | ------------ | -------------------------------------------- |
| 图片卡片                | `ScrollView + VStack + ForEach` | 展示每张图片，带3D旋转效果 | `getAllImages()`：从 ImageManager 中加载        |
| 图片卡片（长按）        | `contextMenu`              | 弹出删除菜单 | `deleteImage(withID:)` 并刷新 UI 和 metadata     |
| 图片数量提示（11 / 30） | Text                       | 动态展示     | `uiImages.count / 30`：直接显示当前数量   |
| 「添加图片」按钮        | PhotosPicker              | 打开系统相册 | `PhotosPicker(selection:)` → 裁剪保存并刷新      |
| 「添加图片」按钮置灰    | 条件渲染                   | 达上限隐藏   | `if !ImageManager.shared.isMaxImageCountReached()`              |
| 「清空全部图片」按钮    | Button + UIAlertController | 清空全部图片并确认 | `clearAllImages()`：删除文件 + metadata 清空 |
| 无图片状态时返回首页    | 条件渲染 + onAppear       | 自动跳转     | `if uiImages.isEmpty { dismiss() }`       |
| 左侧年份和周数显示      | VStack                     | 静态展示     | 显示固定的"2025"和"Week 27"文本 |
| 自定义返回按钮          | ToolbarItem + Button      | 返回上一页   | `dismiss()` 关闭当前视图 |

------

## 页面三：**Widget 展示页（中尺寸 Widget 效果）**

> ⚠️ 该页面仅用于 App 内 Mock 效果，实际 Widget 内容由 `TimelineProvider` 提供

### Widget 功能对应

| 功能           | Widget 实现方式                                              |
| -------------- | ------------------------------------------------------------ |
| 自动轮播       | `getTimeline()` 中生成多个 `TimelineEntry`                   |
| 图片展示       | 从 App Group 中读取 `metadata + 文件路径`                    |
| 顺序播放       | 遍历 metadata，按添加顺序排序                                |
| 清空图片后更新 | App 端调用 `WidgetCenter.shared.reloadAllTimelines()` 进行刷新 |

------

## ✅ 页面结构一览

```text
[首页 - ContentView]
 └── PhotosPicker「Choose Photos」
       → 直接选择、裁剪、保存图片并跳转

[浏览页 - GalleryView]
 ├── 图片卡片展示（3D旋转效果）
 │     → getAllImages() 从 ImageManager 中加载
 ├── 图片卡片长按删除（contextMenu）
 │     → deleteImage(withID:) + 刷新UI
 ├── 清空全部图片按钮（带确认对话框）
 │     → clearAllImages() + 刷新UI
 ├── 添加图片按钮（居中显示）
 │     → PhotosPicker + 裁剪 + 保存
 ├── 图片数量提示
 │     → uiImages.count / 30
 ├── 左侧年份和周数显示
 │     → 静态文本"2025"和"Week 27"
 └── 自定义返回按钮
       → 替代系统默认返回按钮

[Widget 展示页]
 └── getTimeline()
       → 从 App Group 读取 metadata + 图像
       → 生成 TimelineEntry
       → 显示年份和周数信息
```

------

最终图片处理流程，举例说明

  完整处理管道:

  原始图片 (3024×4032, 12M像素)
      ↓ PhotosPicker加载
  UIImage创建 (scale=1.0)
      ↓ ImageCropper.cropCenter()
  裁剪比例 (3024×1420, 4.3M像素)
      ↓ resizeForWidget()
  检查限制 (4.3M > 1.9M, 需要缩放)
      ↓ 计算缩放因子
  智能缩放 (factor=0.665)
      ↓ UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0) 
  最终输出 (944×2011, 1.9M像素)
      ↓ 保存到App Groups
  Widget安全显示 ✅

  关键技术参数:

  - Widget安全限制: 1,900,000像素 (iOS限制的90%)
  - 目标宽高比: 2.13:1 (Medium Widget规格)
  - Graphics Scale: 1.0 (强制点像素1:1对应)
  - 质量平衡: 压缩质量0.8 + 智能缩放