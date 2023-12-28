namespace :embedding do
  task cluster: :environment do
    successful = 0
    failed = 0

    failed_categories = {}

    limit = 50

    Project.reviewed.with_embedding.each do |p|
      closest = p.nearest_neighbors(:embedding, distance: "cosine").reviewed.first(limit)
      majority_category = closest.map(&:category).group_by { |n| n }.values.max_by(&:size).first
      if majority_category == p.category
        puts "#{p.name} is in the correct cluster"
        successful += 1
      else
        puts "#{p.name} is in the wrong cluster (#{p.category} instead of #{majority_category})"
        failed += 1
        failed_categories[p.category] ||= 0
        failed_categories[p.category] += 1
      end
    end

    puts "Successful: #{successful}"
    puts "Failed: #{failed}"

    pp failed_categories.sort_by { |k, v| v }.reverse.to_h
  end

  task distance: :environment do
    categories = {}

    Project.reviewed.with_embedding.each do |p|
      distance = p.nearest_neighbors(:embedding, distance: "cosine").reviewed.first.neighbor_distance
      if categories[p.category]
        categories[p.category] = (categories[p.category] + distance) / 2
      else
        categories[p.category] = distance
      end
    end

    pp categories.sort_by { |k, v| v }.reverse.to_h
  end

  task suggest: :environment do
    close = []

    Project.unreviewed.matching_criteria.with_embedding.find_each do |p|

      puts p.url
      puts p.repository_description
      puts p.keywords.join(", ") if p.keywords.any?

      n = p.nearest_neighbors(:embedding, distance: "cosine").reviewed.first(3)
      
      puts "nearest_neighbors:"
      n.each do |n|
        puts "  - #{n.url} - #{n.category} - #{n.description} (#{n.neighbor_distance})"
      end

      if n.all? { |n| n.neighbor_distance < 0.13 }

        puts "all neighbors are close enough"

        # most common category
        category = n.map(&:category).group_by(&:itself).values.max_by(&:size).try(:first)

        close << [p, category] if category
      end

      puts " "
      puts "------------------"
      puts " "
    end

    groups = close.group_by{|k,v| v};nil

    groups.each{|k,v| puts "# #{k}"; v.each{|p| puts "  - #{p[0].url} - #{p[0].description}"}; puts };nil
  end

  task suggest_from_all_reviewed: :environment do
    text = ''

    Project.best_candidates(100).sort_by(&:score).reverse.select{|p| p.neighbor_distance < 0.220 }.first(50).each do |p|
      text += "**#{p.url} (score: #{p.score.round(2)} - similarity: #{p.neighbor_distance.round(4)})**\n<br/>"
      text += "#{p.description}<br/>\n"
      text += "*Topics: #{p.keywords.join(', ')}*\n" if p.keywords.any?
      text += "\n"
    end

    puts text
  end

  task suggest_category: :environment do
    categories = Project.reviewed.pluck(:category).uniq

    text = ''

    categories.each do |category|
      text += "# #{category}\n"

      Project.best_category_candidates(category).each do |p|
        text += "**#{p.url} (#{p.neighbor_distance})**\n<br/>"
        text += "#{p.description}<br/>\n"
        text += "*Topics: #{p.keywords.join(', ')}*\n" if p.keywords.any?
        text += "\n"
      end

      text += "\n"
    end

    puts text
  end

  task suggest_sub_category: :environment do
    categories = Project.reviewed.pluck(:category).uniq

    text = ''

    categories.each do |category|
      sub_categories = Project.reviewed.where(category: category).pluck(:sub_category).uniq

      text += "# #{category}\n"

      sub_categories.each do |sub_category|
        text += "## #{sub_category}\n"

        Project.best_sub_category_candidates(sub_categories).each do |p|
          text += "  - #{p.url} - #{p.description} (#{p.neighbor_distance})\n"
        end

        text += "\n"
      end

      text += "\n"
    end

    puts text
  end
end