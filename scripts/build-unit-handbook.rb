#!/usr/bin/env ruby
# Generate a portable single-file guide from Godot's exact portraits and roster dump.
require 'json'
require 'base64'

root = File.expand_path('..', __dir__)
art = File.join(root, 'outputs', 'unit-art-v0.16')
catalog = JSON.parse(File.read(File.join(art, 'units.json'), encoding: 'UTF-8'))
catalog.fetch('units').each do |unit|
  unit['images'] = unit.fetch('views').each_with_object({}) do |view, images|
    path = File.join(art, "#{unit.fetch('id')}-#{view}.png")
    raise "Missing engine portrait: #{path}" unless File.exist?(path)
    images[view.to_s] = 'data:image/png;base64,' + Base64.strict_encode64(File.binread(path))
  end
end

# Optional, offline-only art review gallery. These are deliberately separate
# from runtime unit portraits: missing local design files do not block the
# playable roster from being documented.
designs = []
design_catalog_path = File.join(root, 'outputs', 'unit-designs', 'catalog.json')
design_gallery_title = '美术设计稿（尚未生成）'
design_gallery_notice = '独立设计稿不会自动替换当前游戏绘制。'
if File.exist?(design_catalog_path)
  design_catalog = JSON.parse(File.read(design_catalog_path, encoding: 'UTF-8'))
  design_gallery_title = design_catalog.fetch('title', '我方战机姿态设计稿')
  design_gallery_notice = design_catalog.fetch('notice', design_gallery_notice)
  design_catalog.fetch('assets', []).each do |asset|
    relative_path = asset.fetch('image')
    image_path = File.join(root, 'outputs', 'unit-designs', relative_path)
    unless File.exist?(image_path)
      warn "HANDBOOK NOTE: skipped missing design image #{image_path}"
      next
    end
    design_fields = asset
    if relative_path.start_with?('blender/')
      design_fields = {'medium' => '3D结构参考', 'status' => '待审核'}.merge(asset)
    end
    frames = asset.fetch('frames', []).map do |frame|
      frame_path = File.join(root, 'outputs', 'unit-designs', frame)
      raise "Missing animation frame: #{frame_path}" unless File.exist?(frame_path)
      'data:image/png;base64,' + Base64.strict_encode64(File.binread(frame_path))
    end
    designs << design_fields.merge('image' => 'data:image/png;base64,' + Base64.strict_encode64(File.binread(image_path)), 'frames' => frames)
  end
end

# These are explicitly unimplemented campaign designs, never numerical game configs.
plans = [
  ['shore', '岸防静态炮台', '静态防御草案', '俯视岸防和横版断崖中的固定炮位。当前岸上建筑只是背景。', '候选为直射、斜射或延迟齐射；射速、预警与耐久待验证。', '尚未确定独立奖励。', '依赖关卡波次编排、地面目标判定与攻击预警'],
  ['boss-seagull', '重型鱼雷攻击机「海鸥」', '完整部件 Boss 草案', '宽翼双发动机与后部炮位；一次接近后保持距离，发动机拟分别可破坏。简化验证版另有实际条目。', '疏双弹，持续摆动，一侧损伤后冒烟，中央机身进入最后阶段。', '正式关末奖励待定，验证版另行记录。', '正式目标战斗 50 秒和部件耐久仍待验证，不反复离场重生'],
  ['boss-cape', '岸防雷达炮台「岬角」', '第二关 Boss 草案', '海岸雷达与多炮位组合，作为固定地面大型目标。', '候选分组炮位攻击与雷达阶段；具体火力待验证。', '关末奖励尚未确定。', '目标战斗 60 秒，攻击布局待定'],
  ['boss-falcon', '灰隼编队', '第三关 Boss 草案', '精锐敌机编队；由多机协同压力构成，而非单一巨大飞机。', '候选编队接近、掩护与脱离；每轮弹量和耐久待验证。', '关末奖励尚未确定。', '目标战斗 70 秒，保留追尾空中上限'],
  ['boss-night', '护航驱逐舰「夜潮」', '第四关 Boss 草案', '夜海中的多炮位护航舰，灯光和航迹提供位置线索。', '舰炮分组攻击与可读预警；尚未确定火力参数。', '关末奖励尚未确定。', '目标战斗 80 秒，不能依靠黑暗隐藏攻击'],
  ['boss-train', '装甲列车「铁脊」', '第五关 Boss 草案', '前防空车、弹药车、指挥车和后炮车。', '候选斜射炮车；弹药车开放时可攻击，局部爆炸削弱相邻部件。', '关末奖励尚未确定。', '目标战斗 80 秒，需确保主炮可攻击路线'],
  ['boss-carrier', '旗舰航母「黑潮」', '第六关 Boss 草案', '追尾、俯视、低空追尾连续交战，同一航母保留部件损伤。', '候选护航机、四组防空炮、起飞机能和船体弱点；不是已实现火力。', '最终计分和奖励尚未确定。', '目标战斗 120 秒，鱼雷需求和部件耐久待验证']
]
plans.each do |id, name, role, summary, weapons, reward, dependency|
  catalog['units'] << {'id'=>id, 'name'=>name, 'role'=>role, 'summary'=>summary,
    'weapons'=>weapons, 'reward'=>reward, 'category'=>'plan', 'status'=>'讨论草案 · 未实现',
    'traits'=>['背景为 1943 年架空太平洋岛链', dependency], 'views'=>[],
    'stats'=>{'实现状态'=>'未实现', '耐久'=>'待验证', '火力数值'=>'待验证', '原型入口'=>'暂无'}}
end
catalog['designs'] = designs
catalog['design_gallery'] = {
  'title' => design_gallery_title,
  'notice' => design_gallery_notice
}

template = File.read(File.join(__dir__, 'unit-handbook.html'), encoding: 'UTF-8')
raise 'Catalog placeholder missing' unless template.scan('__SKYFIRE_CATALOG__').size == 1
payload = JSON.generate(catalog).gsub('</', '<\/')
html = template.sub('__SKYFIRE_CATALOG__') { payload }
raise 'Unexpected external resource' if html.match?(/(?:src|href)=["']https?:/)
destination = File.join(root, 'outputs', 'skyfire-unit-handbook.html')
File.write(destination, html, encoding: 'UTF-8')
portraits = catalog['units'].sum { |unit| unit.fetch('views').size }
puts "HANDBOOK PASS: #{catalog['units'].size} units, #{portraits} embedded engine portraits, offline single file"
puts "HANDBOOK DESIGNS PASS: #{designs.size} independent images, #{designs.count { |asset| !asset.fetch('frames').empty? }} animation previews"
puts destination
