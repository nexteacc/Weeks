# Widget 图片裁剪简化设计文档

## 概述

基于需求分析，设计一个简化的图片裁剪系统，专注于大尺寸 Widget (1:1 正方形) 的图片展示。核心目标是识别图片的视觉重心，以此为基础进行裁剪，确保保留主体内容的完整性，避免局部放大效果。

## 架构设计

### 整体架构

```
用户上传图片 → 视觉重心检测 → 裁剪区域计算 → 图片裁剪 → Widget 展示
```

### 核心组件

| 组件 | 职责 | 输入 | 输出 |
|------|------|------|------|
| **VisualCenterDetector** | 检测图片视觉重心 | UIImage | CGPoint (重心坐标) |
| **CropRegionCalculator** | 计算裁剪区域 | 重心坐标 + 图片尺寸 | CGRect (裁剪区域) |
| **SimpleCropper** | 执行图片裁剪 | UIImage + 裁剪区域 | UIImage (裁剪结果) |
| **ImageManager** | 图片管理和存储 | 原图 | 处理后的图片 |

## 技术方案

### 1. 视觉重心检测策略

#### 检测方法
使用 Apple Vision 框架的统一检测流程：

```swift
// 伪代码示例
func detectVisualCenter(image: UIImage) -> CGPoint {
    // 1. 尝试人脸检测
    if let faceCenter = detectFaces(image) {
        return faceCenter
    }
    
    // 2. 尝试对象显著性检测
    if let objectCenter = detectSalientObjects(image) {
        return objectCenter
    }
    
    // 3. 尝试注意力显著性检测
    if let attentionCenter = detectAttentionSaliency(image) {
        return attentionCenter
    }
    
    // 4. 回退到几何中心
    return geometricCenter(image)
}
```

#### 检测优先级
1. **人脸检测** - 最高优先级，适用于人像照片
2. **对象显著性** - 识别前景物体（动物、物品等）
3. **注意力显著性** - 识别视觉焦点（风景、艺术作品）
4. **几何中心** - 兜底方案

### 2. 裁剪区域计算

#### 基本原则
- 以视觉重心为中心
- 创建最大可能的正方形区域
- 确保不超出图片边界
- 优先保留主体完整性

#### 计算逻辑
```swift
func calculateCropRegion(center: CGPoint, imageSize: CGSize) -> CGRect {
    // 1. 计算以重心为中心的最大正方形
    let maxSquareSize = min(imageSize.width, imageSize.height)
    
    // 2. 调整位置确保不超出边界
    let adjustedCenter = adjustCenterForBounds(center, imageSize, maxSquareSize)
    
    // 3. 创建最终裁剪区域
    return CGRect(
        x: adjustedCenter.x - maxSquareSize/2,
        y: adjustedCenter.y - maxSquareSize/2,
        width: maxSquareSize,
        height: maxSquareSize
    )
}
```

### 3. 主体内容保留策略

#### 避免局部放大的方法
1. **扩展检测区域**：如果检测到的重要区域太小，适当扩展裁剪范围
2. **边界智能调整**：当重心靠近边缘时，调整裁剪区域以包含更多内容
3. **最小裁剪原则**：优先选择包含更多原图内容的裁剪方案

#### 扩展算法
```swift
func expandCropRegion(detectedRegion: CGRect, imageSize: CGSize) -> CGRect {
    let regionArea = detectedRegion.width * detectedRegion.height
    let imageArea = imageSize.width * imageSize.height
    let areaRatio = regionArea / imageArea
    
    // 如果检测区域太小，扩展裁剪范围
    if areaRatio < 0.3 {
        let expansionFactor: CGFloat = 1.5
        return expandRect(detectedRegion, factor: expansionFactor, bounds: imageSize)
    }
    
    return detectedRegion
}
```

## 数据模型

### 简化的图片元数据
```swift
struct ImageMetadata: Codable {
    let id: String              // UUID
    let addedDate: Date         // 添加时间
    let order: Int              // 显示顺序
    let visualCenter: CGPoint   // 检测到的视觉重心
    let cropRegion: CGRect      // 使用的裁剪区域
}
```

### 裁剪结果
```swift
struct CropResult {
    let croppedImage: UIImage   // 裁剪后的图片
    let visualCenter: CGPoint   // 检测到的视觉重心
    let cropRegion: CGRect      // 实际使用的裁剪区域
    let method: DetectionMethod // 使用的检测方法
}

enum DetectionMethod {
    case face, object, attention, geometric
}
```

## 组件接口设计

### VisualCenterDetector
```swift
protocol VisualCenterDetector {
    func detectCenter(in image: UIImage, completion: @escaping (CGPoint, DetectionMethod) -> Void)
}
```

### SimpleCropper
```swift
protocol SimpleCropper {
    func crop(image: UIImage, to region: CGRect) -> UIImage?
    func cropToSquare(image: UIImage, center: CGPoint) -> CropResult?
}
```

### 简化的 ImageManager
```swift
class ImageManager {
    // 只保留大尺寸版本的方法
    func saveImageForLargeWidget(_ image: UIImage, completion: @escaping (String?) -> Void)
    func getAllLargeWidgetImages() -> [(metadata: ImageMetadata, image: UIImage)]
    func clearAllImages() -> Bool
}
```

## 性能考虑

### 优化策略
1. **异步处理**：所有检测和裁剪操作在后台线程执行
2. **超时机制**：每个检测步骤设置合理超时，确保响应速度
3. **缓存机制**：缓存检测结果，避免重复计算
4. **内存管理**：及时释放大图片的内存占用

### 超时设置
- 人脸检测：2秒
- 对象检测：2秒  
- 注意力检测：2秒
- 总体超时：8秒

## 错误处理

### 异常情况处理
1. **检测失败**：回退到几何中心裁剪
2. **图片损坏**：返回错误，不进行处理
3. **内存不足**：降低图片分辨率后重试
4. **超时**：使用已有的最佳结果或几何中心

### 日志记录
记录关键信息用于调试：
- 使用的检测方法
- 检测耗时
- 最终裁剪区域
- 是否发生回退

## 与现有系统的集成

### 需要修改的组件
1. **ImageManager**：移除 Medium Widget 相关代码
2. **SmartImageCropper**：替换为新的 SimpleCropper
3. **WeeksWidget**：只支持 systemLarge 类型
4. **UI界面**：更新为只显示大尺寸 Widget 预览

### 迁移策略
1. 保留现有数据结构的兼容性
2. 逐步替换裁剪算法
3. 提供数据迁移工具清理旧的 Medium 尺寸图片

## 测试策略

### 测试用例
1. **人像照片**：验证人脸检测和居中效果
2. **动物照片**：验证对象检测（如你提到的猫咪图片）
3. **风景照片**：验证注意力检测
4. **抽象图片**：验证几何中心回退
5. **边缘案例**：极小图片、极大图片、异常比例图片

### 成功标准
- 重要内容保留率 > 90%
- 处理速度 < 3秒/张
- 内存使用稳定
- 无崩溃和异常