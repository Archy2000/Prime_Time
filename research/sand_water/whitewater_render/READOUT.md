# Sandcastle Lit/Whitewater：本轮新增的绘制证据

`tools/disassemble_whitewater_render.py` 解压原先从本机 Sandcastle Demo 提取的 `626_Lit_Whitewater.json` 内的 LZ4 compressedBlob，并用系统 D3DDisassemble 解析 16 个 DXBC 程序。源文件没有有效 HLSL，以下是编译指令读出，不是恢复的原始源码。

## 直接可见的指令

`program_00.asm.txt`（Forward VS）：

- 输入 `SV_InstanceID`，先通过 stride=4 的 drawList 读取索引，再读取 stride=16 的 whitewater 状态。
- 状态 x 乘以 10 并 saturate，再乘 0.4，作为传给 PS 的透明度系数。
- 状态 x 乘 -5.770780，再执行以 2 为底的 exp；之后计算 `(1-result)*0.1` 缩放基础网格。数学等价于约 `0.1*(1-exp(-4*s))`。
- 基础顶点采用 xzy 分量排列，叠加状态中的位置，竖直偏移 +0.02。

`program_04.asm.txt`（Forward PS）：

- UV 减 0.5，计算二维距离；距离大于 0.5 丢弃。
- Alpha 为 `max(0.5-length(UV-0.5),0)*传入系数`。因此这是柔边圆片，而非描边环或一张滚动泡沫网格。
- 白色受环境、太阳/月亮和阴影项影响；基础系数 0.95。

原解析渲染状态：Transparent+4、ZWrite Off，源 Alpha / OneMinusSrcAlpha 混合。计算更新内核 `647_Whitewater_Update.asm.txt` 的末段可见：由水场插值的水平分量按 deltaTime*0.5 更新位置，状态按 deltaTime*0.2 衰减，并有生成项。

## Godot 重建与尚未恢复的部分

`whitewater_particles.gd` / `whitewater_particles.gdshader` 使用独立 MultiMesh 水面片，复用上述圆片、尺寸和透明度曲线、半速平流与状态衰减。小人两侧生成少量重叠圆片，物体边缘通过粗水网格候选和实际碰撞射线确定生成位置。无连续接触描边。

**发射密度、成簇数量、世界尺度适配和碰撞定位是本项目重建参数**，不能称为原作完整生成公式。原作生成项来源、完整状态压缩格式、基础网格尺寸、完整调度和灯光管线仍未全部恢复。项目采用固定偏白颜色，而非逐行移植原光照。这些区别会影响最终观感。
