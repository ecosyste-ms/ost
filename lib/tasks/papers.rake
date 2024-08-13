namespace :papers do
  desc "export papers to markdown"
  task :export => :environment do
    markdown_string = ""

    categories = {}

    Project.reviewed.with_works.group_by(&:category).each do |category, cat_projects|
      categories[category] = []
      markdown_string << "## #{category}\n\n"
      
      cat_projects.group_by(&:sub_category).each do |sub_category, projects|
        markdown_string << "### #{sub_category}\n\n"

        categories[category] << sub_category

        projects.each do |project|

          project.works.each do |doi, work|
            next if work.nil?
            
            markdown_string << "- [#{work['title']}](https://doi.org/#{doi})\n"
            
          end
        end
      end
    end

    # table of contents
    toc = "## Contents\n\n"
    categories.each do |category, sub_categories|
      toc << "- [#{category}](##{category.downcase.gsub(' ', '-')})\n"
      sub_categories.each do |sub_category|
        toc << "  - [#{sub_category}](##{sub_category.downcase.gsub(' ', '-')})\n"
      end
    end
    toc << "\n\n"

    markdown_string = "# Open Sustainable Papers\n\n" + toc + markdown_string
    
  end
end