# ROLLA 完整资源库

来源：`D:\SteamLibrary\steamapps\common\ROLLA Demo\Rolla Demo_Data`。原安装未被修改。

- `models/`：建筑、人物、NPC、车辆、植物、道具等独立 glTF，可拖入 Godot 场景。
- `rolla_catalogue.gltf`：全部网格与材质变体的总览。
- `rolla_level2.gltf`：完整原始城市层级，保留实例位置；未沿用旧脚本的范围裁切。
- `rolla_level0.gltf`、`rolla_level1.gltf`：其他原始关卡层级。
- `rolla_resources_assets.gltf`、`rolla_sharedassets0_assets.gltf`、`rolla_sharedassets2_assets.gltf`：资源文件中的对象层级。
- `audio/`：全部 43 个 AudioClip 的解码音频。
- PNG：456 张可解码贴图；独立模型共享上一级的贴图和 `rolla_all.bin`，移动时请一起保留。

源文件共有 235 个网格，其中 233 个包含几何数据，2 个为空占位。233 个有效网格导出为 278 个材质变体。9 张动态字体纹理没有可读取的持久像素数据；对应原始字体资源完整保留。

完整原始数据、动画/材质/脚本元数据位于 `research/rolla_source/`，使用 `.gdignore` 避免 Godot 错误导入 Unity 数据。162 个源文件均进行了 SHA-256 复制校验。清单与转换错误记录在 `research/rolla_complete_report.json`。

人物当前导出为绑定姿态网格。原骨骼、蒙皮权重、36 个动画片段、控制器均保存在原始数据中，尚未转换为 Godot 骨骼动画。Unity 着色器、粒子、碰撞、AI 和脚本需要后续适配。原始 inactive/renderer enabled 状态以 glTF extras 保留，Godot 展示时需要按用途筛选。完整城市导入用于资源编辑，并未替换现有游戏地图或生成逻辑。

重新提取：用包含 NumPy 的 Python 执行 `tools/extract_rolla_all.py`；UnityPy 使用项目已有的 `tools/python_libs`。

## 贴图修复

补齐金属度/粗糙度、法线和发光贴图，包括水晶着色器的 `_Normal`、`_MetallicSmoothness`、`_Emission` 别名。保留 Unity 贴图缩放/偏移并转换为 `KHR_texture_transform`。Unity 金属贴图 R/平滑度 A 转换为 glTF 金属 B/粗糙度 G；法线按源打包格式转换。

`man_hazard` 和 `woman_scientist` 原来绑定无贴图的 `MatteBlack`，现按相同的色板 UV 布局接回已有的 `LOW-POLY-COLORS` 色板。两个 `None__palette_astalo_png` 材质按原名称补回已有色板。这四项为有依据的推断修复，记录在模型 material extras 与 `research/rolla_complete_report.json`，没有新增虚构贴图。其他原始纯色/黑色模板保留原材质。

原着色器的色阶、溶解、透光等自定义逻辑没有完整转换为 glTF；原始纹理与槽位信息保留在存档和 material extras 中。验证结果见 `research/rolla_texture_validation.json`。更新后的图册位于 `research/rolla_previews/index.html`，每个模型提供两个相反角度。
