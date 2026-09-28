# V14 深度颜色修正

V13 的红绿蓝吸收系数分别为 0.85 / 0.40 / 0.18，随厚度增加会选择性留下蓝色；同时散射颜色又向偏蓝 deep_color 混合，两项共同造成高水位过蓝。

现在采用共享透射率 exp(-thickness * clarity * 0.5)，以互补权重混合水底颜色和固定色相的水体散射色 shallow_color * 0.72。深度改变水底可见度，取消额外向深蓝色混合。视角反射、法线、泡沫保持不变。这是项目风格适配，并非光谱吸收的完整物理模型。

tools/verify_water_depth_color.gd 在固定相机下分别渲染 0.5、1.15、3、5 米水位，各水位 before / after 共用同一场景状态。before 为 v14_before 中保存的 V13 shader，after 为修正版本。真实 OpenGL 渲染完成，日志 research/v14_depth_color.log 无 shader 错误；已查看高水位前后和低水位结果。未重跑未修改的泡沫物理测试。
