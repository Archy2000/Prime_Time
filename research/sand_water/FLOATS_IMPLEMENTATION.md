# 高楼、全场景物件破坏与漂流物（2026-09-29）

## 参考来源与还原边界

只读分析 `D:\SteamLibrary\steamapps\common\Sandcastle Demo\Sandcastle_Data`，提取原始网格到本项目 `assets/sand_floats/`。源安装目录未修改。

| 资源 | sharedassets0.assets 的 Mesh path ID | 用途 |
| --- | --- | --- |
| Rock_01 | 470 | 建筑坍塌后的小石块 |
| Buoy_01 | 399 | 红色航道信标 |
| Boat_01 | 502 | 小帆船 |
| WoodenBoat_01 | 535 | 木船 |

清单、材质编号和包围盒见 `float_sources.json`，可复现脚本为 `tools/inspect_sand_floats.py`、`tools/extract_sand_floats.py`。参考视频为 `research/reference_video/expansion_reference.mp4`，关键帧为 `expansion_sheet.jpg`。

原项目是 IL2CPP；已识别 Buoy / Buoyancy 类型，但没有恢复其方法源码。本次运动是根据视频重建：采样当前水面高度与水平流速，船体通过前后左右高度差俯仰、侧倾；信标使用回锚力并闪灯。不能将这些参数称作原作精确物理算法。石块漂浮是按参考表现实现的游戏效果。

## 游戏行为

- 新增四栋约 11–12 米高楼，每栋四名持枪士兵；小鲨鱼真实弹道高度不足，不会被辅助跳跃直接拉上楼。成长增加跳跃高度，水位同步上涨；高楼破坏门槛 2.30×，普通建筑仍为 1.65×。
- 落在屋顶时沿建筑边界寻找无碰撞的落水位置，自动滑离；入水前检查垂直路径和目标体积。复杂屋檐卡住超过六秒才启用安全水面恢复。跃起期间模型跟随实际高度。
- 城市所有独立模型物件接入破坏，包括树、灌木、杆塔、电线、围栏、路边物件、汽车，以及新增船和信标。连续地面、道路、水面和阴影贴片属于关卡基础，不作为可破坏物件。
- 原墙片碎裂短暂保留 0.75 秒，随后留下约 0.22–0.48 米的原作石块网格。碎石落到水面后随水流漂移、起伏，碰到墙停止水平穿越；50–70 秒寿命，最后五秒缩小，最多 650 颗。
- 四艘船、四个信标使用相同水面场，可碰撞、可冲刺破坏。

## 验证

`scripts/test_world_expansion.gd` 验证：全物件注册、屋顶落下后在六秒兜底前回水、小体型不能上高楼/破坏高楼、守卫开火、大体型锁定和吞噬、真实冲刺查询触发高楼完整坍塌、五类道具和船破坏、碎石数量上限、漂浮及受控水流位移。

另运行原有低楼吞噬、十二组建筑形状/水位碰撞、血迹消散和基础游玩烟测。结果在 `research/world_expansion_tests.json`、`research/v5_gameplay_tests.json`、`research/v7_collision_diffusion_tests.json`（以测试脚本实际输出名为准）、`research/smoke_test.json`。截图为 `research/expansion_tower_hunt.png`、`expansion_rubble.png`、`expansion_boats.png`。

## 版本 16 修订（覆盖上述版本 15 的统一石块方案）

用户要求保留每栋建筑自身的废墟，因此停止使用 Rock_01。impact_fx 的墙片刚体在 0.75 秒后把自己的 MeshInstance3D 转交 floating_world：几何、UV、材质及世界姿态保持连续，再根据同一水面场漂流。模型内的墙面、窗户、屋顶因此各不相同。上述 0.22–0.48 米统一石块尺寸不再适用，碎块保持切割后的原尺寸。Sandcastle 船和信标资源仍保留。
