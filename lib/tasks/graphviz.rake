namespace :graphviz do
  task generate: :environment do
    text = ''

    projects = Set.new

    Project.reviewed.with_embedding.limit(100).each do |p|
      projects << p
      p.nearest_neighbors(:embedding, distance: "cosine").first(5).each do |n|
        projects << n
        text << "\"#{p.name}\" -> \"#{n.name}\"\n"
      end
    end;nil


    categories = Project.reviewed.pluck(:category).uniq

    colors = [
      'salmon2',
      'darkolivegreen2',
      'darkorchid2',
      'darkgoldenrod2',
      'darkslategray2',
      'darkturquoise',
      'darkseagreen2',
      'darkslateblue',
      'darkkhaki',
      'darkorange2',
      'darkorchid2',
      'greenyellow',
      'red2',
    ]
    text2 = ''

    projects.each do |p|
      text2 << "\"#{p.name}\" [color=#{colors[categories.index(p.category)]}]\n"
    end;nil

    total = ''
    total << 'digraph "unix" {
      overlap=scale
      fontname="Helvetica,Arial,sans-serif"
      node [fontname="Helvetica,Arial,sans-serif",color = white,style = filled]
      edge [fontname="Helvetica,Arial,sans-serif"]
      layout=neato'
    total << text2
    total << text
    total << "}"
    File.write('graphviz.dot', total)
  end
end