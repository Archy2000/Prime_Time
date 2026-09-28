# ROLLA 参考滤镜

实现：`shaders/retro.gdshader`、`scripts/retro_filter.gd`；城市主场景默认启用。

- 以 720p 下 2 像素为默认，相当于 640×360 的采样网格；窗口变化时保持相近的虚拟分辨率。
- 对比度、曝光、饱和度、冷青暗部与暖白高光；保留红橙色主体。
- 标准 4×4 Bayer 抖色、32 阶颜色、静态颗粒、逐行扫描线。
- 轻微横向 RGB 色差、四采样亮部扩散、暗角。
- F3 打开 12 项实时调节；恢复参考预设按钮；参数保存于 user://retro_filter.cfg。
- Tab 通过隐藏整层实现完整关闭；HUD 与调节面板在后处理之后绘制。

证据：读取本机 ROLLA Demo 的 Assembly-CSharp.dll，ScanlineEffect 的反编译结果保存在 research/rolla_controls/ScanlineEffect.decompiled.cs。该类有 scanlineIntensity=0.5 和 scanlineDensity=800 默认值；这些是类默认值，不代表运行中场景值。已有资源清单还包含 UI_CRT_MAT，但 UI 材质参数不直接等同于整个游戏画面的后处理配置。

本次按用户截图观感重建 Godot 后处理，未声称逐像素恢复原游戏 Shader。扫描线强度采用更轻的 0.12；没有从静态截图推断闪烁、画面撕裂或屏幕弯曲。

验证：运行 tools/verify_retro.gd，在同一冻结场景输出 v6_filter_off.png、v6_filter_on.png 和 v6_filter_panel.png；检查画面发生变化、面板滑块更新 Shader。v6_filter_validation.json 记录结果。v6_smoke.log 记录玩法回归通过。Godot 的系统证书读取告警与渲染无关，实际 OpenGL Shader 编译及截图成功。

当前洪水场景的材质、光照与参考图干燥街区不同，滤镜不会消除这些场景差异。亮部扩散为轻量屏幕采样，并非 HDR 多级 Bloom。
