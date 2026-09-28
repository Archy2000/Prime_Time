# V12 / V13 水面着色对比

before 为本轮修改前保存的 V12 水面着色器，after 为 V13。比较在同一次运行、完全相同模拟快照、相机、时刻和物体位置下替换着色器完成，未用生成图片代替运行截图。

沙岸：top、low、opposite 各有 before / after PNG，工具 `tools/verify_water_optics.gd`。城市：city_before.png / city_after.png，工具 `tools/verify_city_optics.gd`。均使用实际 OpenGL 渲染器，日志无着色器错误，模拟能量有限。已人工查看城市及沙岸俯视、低角度输出。

本轮修改集中于透水颜色、双相法线、视角反射和高光。小人/建筑泡沫沿用 V12；这些静帧用于验证着色差异，不替代游动与泡沫的动态验收。源代码备份位于 ../v13_before/。
