# Skyfire 1943 原创资源

`aircraft/player/` 是 v0.16 我方飞机的原创像素图集，来自用户认可的 v3 原创模型。横版、俯视、追尾各一张 RGBA 图集；不是第三方游戏资源。敌机、场景仍由 `src/rendering/` 绘制，音效由代码合成。

## 运行时布局

每张图集 16 列，格内四周 2 px 透明隔离。横版每格 80×60 px，俯视 64×64 px，追尾 112×84 px；每个姿态连续存放 8 个桨盘相位，每帧 40 ms。横版 / 俯视各 9 个滚转档位；追尾以俯仰为外层、滚转为内层，共 9×9 个姿态。原生帧尺寸包括固定透明余量，不是机翼外接框；不按帧重新居中。

Godot 使用最近邻、不生成 mipmap、无损导入；主机的原生像素按逻辑像素显示，默认 1920×1080 内部画面为 2 倍。僚机和首页按原有比例缩放。`provenance.json` 记录源文件 / 原网格哈希、相机投影检查、姿态角度、桨盘与布局；运行时不读取本机绝对路径。

## 可选再烘焙

游戏测试 / 构建只需要这里的 PNG，不要求安装 Blender。再次修改美术时，需要本地保留的 `outputs/unit-designs/blender/skyfire-airframe-v3.blend` 以及 `work/blender/render_airframe_poses.py`、`propeller_speed_fx.py`。这些研究源文件尚未纳入仓库，不能声称仅克隆仓库即可重建美术源模型。

用 Blender 执行 `scripts/render-player-sprites.py`（可加 `-- --preview` 先看原生尺寸），然后再执行一次并加 `-- --body-only` 输出独立机体覆盖通道，最后用 Godot 的 `--headless --path . --script scripts/pack-player-sprites.gd` 打包。前者保持模型文件 / 原网格不变，仅整机刚体姿态渲染与分阶材质；后者以机体覆盖率 0.4 为像素边界、映射到 36 色机体调色板，并添加原生一像素外轮廓，不缩放图片。白桨盘单独保留透明度，不把整个机体做成半透明模糊边缘。生成中间帧保存在 `work/player-sprite-bake/`。替换 PNG 后运行一次 Godot `--headless --editor --import`，再测试、打包并实际查看。

新增第三方资源时记录来源和许可，不使用原作游戏资源。实际素材可提交；导出包、缓存、ROM 和研究文件不能放进这个目录。
