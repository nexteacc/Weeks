# 实现任务列表

## 任务概述

基于现有代码，简化多尺寸智能裁剪系统为专注于大尺寸Widget的视觉重心裁剪系统。

## 实现任务

- [ ] 1. 简化SmartImageCropper为视觉重心裁剪
  - 修改现有的SmartImageCropper.swift，移除复杂的五种策略
  - 实现统一的视觉重心检测流程（人脸→对象→注意力→几何中心）
  - 添加主体内容保留算法，防止局部放大效果
  - 确保只输出1:1正方形裁剪结果
  - _需求: 2.1, 2.2, 4.1, 4.2_

- [ ] 2. 重构ImageManager移除Medium尺寸支持
  - 修改ImageMetadata.swift中的ImageManager类
  - 移除所有Medium Widget (2.13:1) 相关的存储和处理逻辑
  - 简化saveImages方法，只生成Large Widget版本
  - 更新getAllImages方法，只返回大尺寸图片
  - 清理现有用户数据中的Medium尺寸文件
  - _需求: 1.1, 1.4_

- [ ] 3. 更新Widget和UI只支持大尺寸
  - 修改WeeksWidget.swift，移除Medium Widget支持，只保留systemLarge
  - 更新GalleryView.swift，调整预览为正方形显示
  - 修改ContentView.swift，移除Medium相关的UI逻辑
  - 更新ImageCropper.swift，移除mediumAspectRatio相关代码
  - _需求: 1.2, 1.3_

- [ ] 4. 测试和优化裁剪效果
  - 使用多种类型图片测试新的裁剪算法
  - 验证视觉重心检测在不同场景下的效果
  - 确保主体内容保留，避免局部放大
  - 优化性能和错误处理
  - _需求: 3.2, 3.4, 4.4_