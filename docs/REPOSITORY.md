# Skyfire 1943 仓库与开发环境

本文说明源码、设计文档、工具和本地成果的存放方式，以及此次迁移的保留范围。更新日期：2026-10-02。游戏行为仍以 v0.9 为基线，迁移不实现新的玩法。

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
    gameplay/                飞行 射击 接敌 敌种
    rendering/               飞机 场景 云层绘制
  tests/                     GDScript 回归检查
  scripts/                   准备 测试 构建 文档检查
  assets/                    未来原创资源
  docs/                      设计 关卡 进度 历史记录
  licenses/                  Godot 许可说明
  work/                      本地引擎与诊断文件 忽略
  outputs/                   本地应用 压缩包 截图 忽略
```

资源引用使用 `res://src/`、`res://tests/` 和 `res://scenes/`。移动脚本保留对应 `.gd.uid`，不把引擎缓存作为源码提交。

## 本地成果与忽略边界

旧版与 v0.9 试玩应用、压缩包、截图和说明保存在 `outputs/`，可用于对照；它们不会进入普通 Git 提交。本次重构验证可重新生成 v0.9，原位置仍有原包。

已下载的 Godot 和 Mac 导出模板保存在 `work/tools/`，无需重新下载。新克隆机器运行准备脚本可重新取得工具。`work/` 和 `outputs/` 内的 `.gdignore` 防止编辑器扫描本地大目录。

忽略规则覆盖引擎缓存、导出结果、本地工具、日志、环境密钥、签名材料、ROM 和编辑器元数据。不全局忽略图片、音频或 UID，否则未来原创资源也会遗漏。源代码开源许可尚未选择，仓库维持私有；随 Godot 分发的许可单独保留。

## 开发与验证命令

```sh
bash scripts/bootstrap-macos.sh
bash scripts/test.sh
ruby scripts/check-docs.rb
bash scripts/build-macos.sh
```

测试脚本检查 Godot 日志并运行文档校验。构建先测试，再导出应用、附带许可、ad-hoc 签名与压缩。`SKYFIRE_GODOT` 可以指定可执行文件，默认是仓库内的 `work/tools/Godot.app/Contents/MacOS/Godot`。

Mac 应用是本机测试包，未做 Apple 公证。源码迁移不等于跨平台验证，后续平台需分别构建与试玩。导出包保留运行 smoke 所需的测试资源，不因 tests 目录名称就错误排除其 preload 依赖。

## Codex 项目与对话

目标是让 Codex 本地项目以本仓库为主目录，并从 `docs/README.md` 和 `AGENTS.md` 获取持续上下文。项目创建结果应以应用项目列表为准，不能仅因目录存在就称为已注册。

现有长对话仍有自己的历史和工作目录。添加项目不自动等于旧对话已经迁入；没有得到明确迁移结果前保留原对话。只能通过支持的接口添加或调整项目，不编辑 Codex 内部数据库或全局状态来绕过限制。

[返回开发文档目录](README.md)
