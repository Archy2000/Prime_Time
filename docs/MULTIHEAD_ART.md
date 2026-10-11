> 当前集成：多头模型已独立于肉鸽流程，主场景直接使用 source_shark_hydra.gd，默认三头、F4 切换；下文肉鸽回归命令为历史记录，当前验证使用 scripts/test_freeplay_multihead.gd。

# 基于当前普通鲨鱼的多头进化

当前实现以 assets/characters/shark/SK_Great_White_Shark.glb 为基础。原始文件没有改动，Git blob hash 为 7bbc8bee1bce7bf9e7dd42cc7aa8542467a0e8ad。

## 当前实现

- 直接复用普通鲨鱼 Head、Jaw、TeethTop 的网格、UV、贴图和骨骼权重。
- 原躯干、尾巴、鱼鳍及骨骼动画保留；不再替换整条鲨鱼。
- 头颈后端保持原位置，前端旋转展开，中间平滑过渡。头颅和嘴部保持原形状。
- 双头替换中央头；三头、五头、九头保留中央头并增加两侧分支。仍沿用原模型的分部网格拓扑，并非重新焊接成单一封闭网格。
- 各头共用原骨骼动画；捕食点跟随各自嘴部，猎物进入对应嘴部。
- 水中浮深恢复普通鲨鱼规则，尸化副系仍可叠加。

实现见 scripts/source_shark_hydra.gd 与 scripts/mutation_visual.gd。

## 验证与预览

scripts/test_source_shark_hydra.gd 检查原资源保留、UV/权重/拓扑、头颅形状、颈根位置、嘴部数量、变异清理和尸化组合，共 30 项通过。scripts/test_roguelite.gd 的 33 项回归检查通过。

```text
tools/godot/Godot.exe --headless --path . --script scripts/test_source_shark_hydra.gd
tools/godot/Godot.exe --headless --path . --script scripts/test_roguelite.gd -- --roguelite-test
tools/godot/Godot.exe --path . --script tools/preview_multihead.gd
```

research/source_shark_comparison.png 为 Godot 同角度真实渲染：左侧普通鲨鱼，右侧三头进化。research/multihead_after_* 展示全部形态；research/multihead_water_2.png 与 multihead_water_4.png 展示实际城镇水中效果。预览脚本设置镜头和进化等级以便检查造型，不代表人工通关录像。

## 历史参考

前一轮参考了 The Asylum 的双头鲨、三头鲨、五头鲨和六头鲨电影宣传造型。当前只借鉴分叉方向，使用游戏已有鲨鱼资源。

上一轮 assets/characters/mutations/hydra_*.glb、shaders/hydra_skin.gdshader 和 tools/build_multihead.py 保留为实验记录，当前游戏不加载它们。research/multihead_geometry_tests.json 是旧隐式曲面模型的检查结果，不是当前原鲨鱼派生网格的证据。
