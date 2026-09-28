# Sandcastle 水体调查与 Godot V3

本报告来自本机 Sandcastle Demo 的资源和编译着色器，不是网络推测。未恢复完整 C# 或原始 HLSL；Godot 代码是依据证据重建的近似实现。

## 确认的原作结构

`636_Water.json` 为 Unity ComputeShader。通过系统 D3DDisassemble 反汇编其中的 DXBC，生成相邻的 `*.asm.txt`。原始内核名称保留了：

- Initialization、UpdateFloor、BlurFloor：水网格初始化、地形更新与平滑。
- HeightIntegration、VelocityIntegration：独立的水高和速度积分。
- Advection：平流步骤。
- UpdateAmount：读取 obstaclesMap 和 airCells，同时包含 waveAmplitude、customWave、level 参数。
- UpdateTangent：为水面更新切线。
- SubtractFloor、CopyGroundHeight、Paint：地形和交互编辑相关操作。

`636_Water_constants.json` 保留了 waterResolution、waterCellSize、deltaTime、gravityForce、maxVelocity、damping、kappa、advectionFactor 等参数名及常量缓冲偏移。HeightIntegration 指令读取四邻域并计算由速度决定的水量变化；VelocityIntegration 读取相邻水单元并含边缘衰减。结合这些证据，可判断为高度场水流模拟；具体数值格式、全部方程和更新顺序仍未完整恢复。

`647_Whitewater.json` 为独立白沫计算着色器，包含 Initialization、Update、Culling；Update 读取 waterCells。白沫并非仅水面上的循环贴图。白沫的完整生成阈值和所有粒子行为尚未还原。

`587_Lit_Water.shader.txt` 只能恢复渲染状态、属性和通道信息，导出器未给出有效原始 HLSL。`water_source.json` 的法线、折射和颜色参数是实际提取值，但不能脱离原渲染流程直接当作 Godot 对应参数。

IL2CPP metadata 为版本 39；本次未解析其新版字符串布局或恢复 C# 方法体。没有把原始字节中的偶然字符串当作代码证据。

## Godot 重建

`scripts/water_hydro.gd`：160×160 网格，交错网格水平速度、重力驱动、守恒面通量更新水高、局部水深、固体边界和边缘吸收。白沫使用双线性半拉格朗日平流与衰减，根据坡度/撞击生成。海浪从边界施加；内部传播通过求解器完成，不再独立滚动一条正弦白线。

`scripts/water_async.gd`：工作线程计算，主线程仅提交扰动和上传已完成的快照。固定时间步目标 30Hz；机器过慢时限制积压，因此不是无限追赶的离线精确时间积分。

`shaders/water_v3.gdshader`：同一水高场控制网格起伏、法线与浪峰；流场影响细节，白沫来自持久场。保留原作法线贴图，焦散为重建纹理。不是原作 Shader 的逐行移植。

角色游动注入船首正压、尾部负压及两侧方向性流动；角色/人物读取局部水高。瓦砾读取局部水面以触发溅水、阻力及部分浮力，密集碎块仍会下沉。试验场木块随水高与流速漂移，反馈小扰动；它们使用简化运动学浮力而非全体积刚体流固耦合。

## 观察与验证

双击 `Water Lab.cmd`，或城市中 F2。WASD 游动、空格冲刺、Q 产生额外波列、R 重置、F2 返回城市。

试验场包含倾斜沙床、圆形岩石截面、横墙、可推动木块。城市中的建筑使用保守 AABB 障碍近似，细小物体会受网格分辨率限制；目前不是逐三角形水体碰撞。没有泥沙侵蚀、翻卷浪或完整三维流体。

`scripts/test_water.gd` 检查静水稳定、白沫平移、无墙传播与完整墙体阻断；结果见 `research/v3_solver_tests.json`。`research/smoke_test.json` 为城市交互回归，`v3_water_validation.json` 为试验场运行数据。视频记录原始 Godot 渲染，没有后期补水花。
