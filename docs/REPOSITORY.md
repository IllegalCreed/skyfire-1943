# Skyfire 1943 仓库与开发环境

本文说明源码、设计文档、工具和本地成果的存放方式，以及迁移的保留范围。更新日期：2026-10-15。当前 v0.16 增加我方姿态像素图集，保留 v0.15 单人样段、设置、输入与原敌种；基础飞行与命中以 v0.9 为基线。

## 主目录与远端

本机主仓库为 `/Users/zhangxu/illegal/skyfire-1943`，由现有私有仓库 [IllegalCreed 的 skyfire-1943](https://github.com/IllegalCreed/skyfire-1943) 克隆。这个目录自身就是 Git 和 Godot 项目根，不再额外嵌套一层仓库。

原目录 `/Users/zhangxu/Documents/Codex/2026-09-11/wo-you` 保留为迁移备份，不删除、不重置，也不作为后续同步目标。未提交代码、UID、文档、试玩包和截图已复制到新目录。原作研究与 ROM 保留在原位置的忽略目录，没有随源码迁移或上传。

## 目录结构

```text
skyfire-1943/
  AGENTS.md                  开发约定与文档维护规则
  README.md                  试玩和开发入口
  project.godot              Godot 项目配置
  export_presets.cfg         Mac 导出配置
  scenes/                    入口与场景
  src/
    main.gd                  主流程
    gameplay/                飞行 射击 接敌 敌种 关卡导演 Boss
    input/                   单人键盘 手柄 输入路由
    rendering/               飞机 舰船 Boss 场景 云层绘制
    ui/                      菜单 设置 关卡 HUD 胜败结算
  tests/                     GDScript 回归检查
  scripts/                   准备 测试 构建 文档检查
  assets/                    原创资源；我方姿态像素图集
  docs/                      设计 关卡 进度 历史记录
  licenses/                  Godot 许可说明
  work/                      本地引擎与诊断文件 忽略
  outputs/                   本地应用 压缩包 截图 忽略
```

资源引用使用 `res://src/`、`res://tests/` 和 `res://scenes/`。移动脚本保留对应 `.gd.uid`，不把引擎缓存作为源码提交。

文档入口为 [docs/README.md](README.md)；阶段顺序、依赖与范围集中在 [ROADMAP.md](ROADMAP.md)，实现和验证记录在 [DEVELOPMENT.md](DEVELOPMENT.md)，具体玩法保留在各专题。新增的 [SCORING.md](SCORING.md)集中记录计分与排行榜设计，不包含实际成绩或账号数据。路线图是仓库内的本地文档，不另建云端项目或任务系统。

## 本地成果与忽略边界

旧版与 v0.16 两版应用、压缩包、截图、视频、图鉴和说明保存在 `outputs/`，不进入普通 Git 提交。v0.9 至 v0.15 成果保留，当前构建不覆盖旧版应用。

单位图鉴模板与生成工具在 `scripts/`，游戏造型与运行数据在 `src/`。`bash scripts/build-unit-handbook.sh` 绘制二十张单位图、导出参数并生成 `outputs/skyfire-unit-handbook.html`。HTML 内嵌图片与数据、文件名固定，可单独复制，不发布网站或联网服务。修改代码后需重生成，Mac 构建会同步生成。

独立美术设计稿来自可选的 `outputs/unit-designs/catalog.json`，与运行时图分开；`poses-v3/` 保留十一种姿态的模型图与大尺寸像素预览，建模 / 姿态 / 桨盘特效源脚本在 `work/blender/`，仍被忽略。v0.16 用同一模型另烘焙实际尺寸的连续帧，三张运行时图集放在 `assets/aircraft/player/`，不依赖这些本地研究文件即可构建游戏。烘焙 / 打包工具在 `scripts/`，输入依赖见[资源说明](../assets/README.md)。图鉴模板支持 `#design=条目ID`，设计动画仍内嵌，缺失帧会报错，不依赖外部服务。

已下载的 Godot 和 Mac 导出模板保存在 `work/tools/`，无需重新下载。新克隆机器运行准备脚本可重新取得工具。`work/` 和 `outputs/` 内的 `.gdignore` 防止编辑器扫描本地大目录。

忽略规则覆盖引擎缓存、导出结果、本地工具、日志、环境密钥、签名材料、ROM 和编辑器元数据。不全局忽略图片、音频或 UID，否则未来原创资源也会遗漏。源代码开源许可尚未选择，仓库维持私有；随 Godot 分发的许可单独保留。

## 开发与验证命令

```sh
bash scripts/bootstrap-macos.sh
bash scripts/test.sh
ruby scripts/check-docs.rb
bash scripts/build-macos.sh
```

测试脚本检查 Godot 日志并运行文档校验。构建先测试，再分别导出玩家版与开发版应用，附带许可、ad-hoc 签名、独立应用 smoke 与原生菜单输入检查，再压缩并验证 ZIP。两版当前都是带断言的本机调试导出；开发入口由显式 `developer` 特征区分，不用 debug 特征判断。构建日志必须没有运行错误并包含最终 PASS。`SKYFIRE_GODOT` 可以指定可执行文件，默认是仓库内的 `work/tools/Godot.app/Contents/MacOS/Godot`。

Mac 应用是本机测试包，未做 Apple 公证。源码迁移不等于跨平台验证，后续平台需分别构建与试玩。导出包保留运行 smoke 所需的测试资源，不因 tests 目录名称就错误排除其 preload 依赖。

## Codex 项目与对话

2026-10-02 迁移初期完成后台登记时，桌面侧栏仍未显示项目。随后用户亲自在桌面创建 `skyfire-1943`，应用项目列表已核对项目路径为本仓库，桌面接入现已完成。项目从 `docs/README.md` 和 `AGENTS.md` 获取持续上下文。

用户授权在本项目创建接续对话，以成果摘要和仓库文档继续开发。原长对话《设计三视角弹幕射击游戏》完整保留；新对话不等于完整旧消息搬迁。期间没有修改 Codex 内部数据库或全局状态，旧备份目录仍保留。

[返回开发文档目录](README.md)
