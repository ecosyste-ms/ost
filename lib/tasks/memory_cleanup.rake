namespace :memory do
  desc "Clean up memory issues: remove bot contributors, cap array sizes, populate image/zenodo flags"
  task cleanup: :environment do
    puts "=" * 80
    puts "MEMORY CLEANUP TASK"
    puts "=" * 80
    puts "Started at: #{Time.now}"
    puts ""

    # Task 1: Delete bot contributors
    puts "Task 1: Deleting bot contributors..."
    bot_contributors = Contributor.where(
      "email ILIKE '%[bot]%' OR
       email ILIKE '%bot@%' OR
       email ~ '^[0-9]+\\+.*@users\\.noreply\\.github\\.com$' OR
       email IN (?)",
      Contributor::IGNORED_EMAILS
    )

    bot_count = bot_contributors.count
    bot_topic_count = bot_contributors.sum { |c| c.topics.size }
    puts "  Found #{bot_count} bot contributors with #{bot_topic_count} total topics"

    deleted = bot_contributors.delete_all
    puts "  ✓ Deleted #{deleted} bot contributors"
    puts ""

    # Task 2: Cap contributor array sizes for existing records
    puts "Task 2: Capping contributor array sizes..."
    capped_count = 0

    Contributor.where("array_length(topics, 1) > 100 OR
                       array_length(categories, 1) > 20 OR
                       array_length(sub_categories, 1) > 20 OR
                       array_length(reviewed_project_ids, 1) > 200")
               .find_each do |contributor|

      contributor.topics = contributor.topics.uniq.first(100) if contributor.topics.size > 100
      contributor.categories = contributor.categories.uniq.first(20) if contributor.categories.size > 20
      contributor.sub_categories = contributor.sub_categories.uniq.first(20) if contributor.sub_categories.size > 20
      contributor.reviewed_project_ids = contributor.reviewed_project_ids.uniq.first(200) if contributor.reviewed_project_ids.size > 200
      contributor.reviewed_projects_count = contributor.reviewed_project_ids.length

      contributor.save(validate: false)
      capped_count += 1
    end

    puts "  ✓ Capped arrays for #{capped_count} contributors"
    puts ""

    # Task 3: Populate has_images flag
    puts "Task 3: Populating has_images flag..."
    updated = Project.where(has_images: false)
                     .where.not(readme: nil)
                     .where("readme ~ ?", '!\\[.*?\\]\\(')
                     .update_all(has_images: true)
    puts "  ✓ Updated #{updated} projects with has_images = true"
    puts ""

    # Task 4: Populate has_zenodo flag
    puts "Task 4: Populating has_zenodo flag..."
    updated = Project.where(has_zenodo: false)
                     .where.not(readme: nil)
                     .where("readme ILIKE ?", '%zenodo%')
                     .update_all(has_zenodo: true)
    puts "  ✓ Updated #{updated} projects with has_zenodo = true"
    puts ""

    # Task 5: Vacuum database
    puts "Task 5: Vacuuming database tables..."
    puts "  Vacuuming contributors table..."
    ActiveRecord::Base.connection.execute("VACUUM ANALYZE contributors;")
    puts "  ✓ Contributors table vacuumed"

    puts "  Vacuuming projects table..."
    ActiveRecord::Base.connection.execute("VACUUM ANALYZE projects;")
    puts "  ✓ Projects table vacuumed"
    puts ""

    # Summary
    puts "=" * 80
    puts "CLEANUP COMPLETE"
    puts "=" * 80
    puts "Finished at: #{Time.now}"
    puts ""
    puts "Summary:"
    puts "  - Deleted #{deleted} bot contributors"
    puts "  - Capped arrays for #{capped_count} contributors"
    puts "  - Database vacuumed and analyzed"
    puts ""
    puts "Run 'Contributor.count' and check table sizes to verify changes."
    puts "=" * 80
  end

  desc "Show memory statistics before cleanup"
  task stats: :environment do
    puts "=" * 80
    puts "MEMORY STATISTICS"
    puts "=" * 80
    puts ""

    # Contributor stats
    puts "Contributors:"
    puts "  Total: #{Contributor.count}"
    puts "  Bots: #{Contributor.where("email ILIKE '%[bot]%' OR email ILIKE '%bot@%'").count}"
    puts "  With 20+ topics: #{Contributor.where('array_length(topics, 1) > 20').count}"
    puts "  With 50+ topics: #{Contributor.where('array_length(topics, 1) > 50').count}"
    puts "  With 100+ topics: #{Contributor.where('array_length(topics, 1) > 100').count}"
    puts ""

    # Topic stats
    total_topics = ActiveRecord::Base.connection.execute(
      "SELECT SUM(array_length(topics, 1)) as total FROM contributors WHERE topics IS NOT NULL;"
    ).first['total'].to_i

    bot_topics = ActiveRecord::Base.connection.execute(
      "SELECT SUM(array_length(topics, 1)) as total
       FROM contributors
       WHERE (email ILIKE '%[bot]%' OR email ILIKE '%bot@%') AND topics IS NOT NULL;"
    ).first['total'].to_i

    puts "Topics:"
    puts "  Total entries: #{total_topics}"
    puts "  In bot accounts: #{bot_topics} (#{((bot_topics.to_f / total_topics) * 100).round(2)}%)"
    puts "  Memory estimate: #{((total_topics * 15) / 1024.0 / 1024.0).round(2)} MB"
    puts ""

    # Project stats
    puts "Projects:"
    puts "  Total: #{Project.count}"
    puts "  Reviewed: #{Project.reviewed.count}"
    puts "  With readme: #{Project.where.not(readme: nil).count}"
    puts "  has_images=true: #{Project.where(has_images: true).count}"
    puts "  has_zenodo=true: #{Project.where(has_zenodo: true).count}"
    puts "  Need has_images update: #{Project.where(has_images: false).where.not(readme: nil).where("readme ~ ?", '!\\[.*?\\]\\(').count}"
    puts "  Need has_zenodo update: #{Project.where(has_zenodo: false).where.not(readme: nil).where("readme ILIKE ?", '%zenodo%').count}"
    puts ""

    # Table sizes
    result = ActiveRecord::Base.connection.execute("
      SELECT
        tablename,
        pg_size_pretty(pg_total_relation_size('public.'||tablename)) AS size
      FROM pg_tables
      WHERE schemaname = 'public'
        AND tablename IN ('contributors', 'projects')
      ORDER BY pg_total_relation_size('public.'||tablename) DESC;
    ")

    puts "Table sizes:"
    result.each { |row| puts "  #{row['tablename']}: #{row['size']}" }
    puts ""
    puts "=" * 80
  end

  desc "Dry run - show what would be cleaned up without making changes"
  task dry_run: :environment do
    puts "=" * 80
    puts "MEMORY CLEANUP DRY RUN"
    puts "=" * 80
    puts "This shows what WOULD be deleted/updated without making changes"
    puts ""

    # Bot contributors
    bot_contributors = Contributor.where(
      "email ILIKE '%[bot]%' OR
       email ILIKE '%bot@%' OR
       email ~ '^[0-9]+\\+.*@users\\.noreply\\.github\\.com$' OR
       email IN (?)",
      Contributor::IGNORED_EMAILS
    )

    bot_count = bot_contributors.count
    bot_topic_count = bot_contributors.sum { |c| c.topics.size }

    puts "Would delete #{bot_count} bot contributors:"
    puts "  Total topics in bots: #{bot_topic_count}"
    puts "  Memory to free: ~#{((bot_topic_count * 15) / 1024.0 / 1024.0).round(2)} MB"
    puts ""

    puts "  Top 10 bots to be deleted:"
    bot_contributors.order(Arel.sql('array_length(topics, 1) DESC')).limit(10).each do |c|
      puts "    #{c.email}: #{c.topics.size} topics, #{c.reviewed_project_ids.size} projects"
    end
    puts ""

    # Contributors with oversized arrays
    oversized = Contributor.where("array_length(topics, 1) > 100 OR
                                   array_length(categories, 1) > 20 OR
                                   array_length(sub_categories, 1) > 20 OR
                                   array_length(reviewed_project_ids, 1) > 200")

    puts "Would cap arrays for #{oversized.count} contributors:"
    oversized.limit(10).each do |c|
      changes = []
      changes << "topics: #{c.topics.size} -> 100" if c.topics.size > 100
      changes << "categories: #{c.categories.size} -> 20" if c.categories.size > 20
      changes << "sub_categories: #{c.sub_categories.size} -> 20" if c.sub_categories.size > 20
      changes << "project_ids: #{c.reviewed_project_ids.size} -> 200" if c.reviewed_project_ids.size > 200
      puts "    #{c.email}: #{changes.join(', ')}"
    end
    puts ""

    # Projects needing flags
    needs_images = Project.where(has_images: false)
                          .where.not(readme: nil)
                          .where("readme ~ ?", '!\\[.*?\\]\\(')
                          .count

    needs_zenodo = Project.where(has_zenodo: false)
                          .where.not(readme: nil)
                          .where("readme ILIKE ?", '%zenodo%')
                          .count

    puts "Would update project flags:"
    puts "  #{needs_images} projects -> has_images = true"
    puts "  #{needs_zenodo} projects -> has_zenodo = true"
    puts ""

    puts "=" * 80
    puts "Run 'rake memory:cleanup' to perform these changes"
    puts "=" * 80
  end
end
