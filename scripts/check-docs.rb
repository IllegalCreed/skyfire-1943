#!/usr/bin/env ruby
# Read-only checks; compatible with the Ruby bundled on macOS.
Dir.chdir(File.expand_path('..', __dir__))

files = ['README.md', 'AGENTS.md'] + Dir.glob('{docs,assets}/**/*.md')
errors = []
link_count = 0

files.each do |file|
  content = File.read(file, encoding: 'UTF-8')
  lines = content.lines.map(&:chomp)
  unless lines.count { |line| line.start_with?('# ') } == 1
    errors << "#{file}: expected one document title"
  end
  in_fence = false
  lines.each_with_index do |line, index|
    if line.match?(/^`{3}/)
      in_fence = !in_fence
      next
    end
    next if in_fence
    if line.match?(/^[#]{1,6} /) && index + 1 < lines.length && !lines[index + 1].empty?
      errors << "#{file}:#{index + 1}: heading needs a blank line"
    end
    if line.match?(/^[#]{2,6} /)
      next_content = lines[(index + 1)..-1].find { |following| !following.empty? }
      if next_content.nil? || next_content.match?(/^[#]{1,6} /)
        errors << "#{file}:#{index + 1}: empty section"
      end
    end
    if line.start_with?('|') && index > 0 && !lines[index - 1].start_with?('|') && !lines[index - 1].empty?
      errors << "#{file}:#{index + 1}: table needs a blank line"
    end
  end
  errors << "#{file}: unclosed code fence" if in_fence
  content.scan(/\[[^\]]+\]\(([^)]+)\)/).flatten.each do |target|
    next if target.match?(/\A(?:https?:|mailto:|#)/)
    path = target.split('#', 2).first
    path = path[1...-1] if path.start_with?('<') && path.end_with?('>')
    link_count += 1
    unless File.exist?(File.expand_path(path, File.dirname(file)))
      errors << "#{file}: broken link #{target}"
    end
  end
end

def seconds(value)
  case value
  when /\A(\d+)分(\d+)秒\z/ then Regexp.last_match(1).to_i * 60 + Regexp.last_match(2).to_i
  when /\A(\d+)分钟\z/ then Regexp.last_match(1).to_i * 60
  when /\A(\d+)秒\z/ then Regexp.last_match(1).to_i
  else raise "Unknown duration: #{value}"
  end
end

campaign = File.read('docs/CAMPAIGN.md', encoding: 'UTF-8')
summaries = campaign.lines.select { |line| line.match?(/^\| 第[一二三四五六]关 /) }.map do |line|
  cells = line.split('|').map(&:strip).reject(&:empty?)
  road, boss, total = cells[2..4].map { |value| seconds(value) }
  errors << "#{cells[0]}: total differs from road plus Boss" unless road + boss == total
  [cells[0], road, total, cells[5].to_i]
end
sections = campaign.split(/^## 第[一二三四五六]关 /).drop(1)
abort 'Campaign must contain six stages and six summaries' unless summaries.size == 6 && sections.size == 6

sections.each_with_index do |section, index|
  ending = 0
  waves = 0
  section.scan(/^\| (\d+):(\d+)至(\d+):(\d+) \| [^|]+ \| (\d+) \|/).each do |values|
    a, b, c, d, count = values.map(&:to_i)
    starts = a * 60 + b
    finishes = c * 60 + d
    errors << "#{summaries[index][0]}: timeline gap or overlap" unless starts == ending && finishes > starts
    ending = finishes
    waves += count
  end
  errors << "#{summaries[index][0]}: road duration mismatch" unless ending == summaries[index][1]
  errors << "#{summaries[index][0]}: wave total mismatch" unless waves == summaries[index][3]
end

total = summaries.sum { |stage| stage[2] }
errors << 'Campaign total differs from stated 26m40s' unless total == 1600
errors << 'Carrier phases differ from Boss duration' unless 40 + 45 + 35 == summaries.last[2] - summaries.last[1]
abort errors.join("\n") unless errors.empty?

puts "DOCS PASS: #{files.size} Markdown files, #{link_count} local links, structure checks"
puts "CAMPAIGN PASS: six contiguous timelines, matching wave totals, #{total / 60}m#{total % 60}s"
