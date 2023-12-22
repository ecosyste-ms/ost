namespace :embedding do
  task cluster: :environment do
    successful = 0
    failed = 0

    failed_categories = {}

    limit = 50

    Project.with_embedding.each do |p|
      closest = p.nearest_neighbors(:embedding, distance: "cosine").first(limit)
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

    Project.with_embedding.each do |p|
      distance = p.nearest_neighbors(:embedding, distance: "cosine").first.neighbor_distance
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
      n = p.nearest_neighbors(:embedding, distance: "cosine").reviewed.first(3)
      
      if n.all? { |n| n.neighbor_distance < 0.13 }
        puts p.url

        # most common category
        category = n.map(&:category).group_by(&:itself).values.max_by(&:size).first

        close << [p, category]
      end
    end

    groups = close.group_by{|k,v| v};nil

    groups.each{|k,v| puts "# #{k}"; v.each{|p| puts "  - #{p[0].url} - #{p[0].description}"}; puts };nil
  end
end