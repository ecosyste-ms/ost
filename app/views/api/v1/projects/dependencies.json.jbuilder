json.array! @dependencies do |dependency|
  json.ecosystem dependency[:ecosystem]
  json.package_name dependency[:package_name]
  json.count dependency[:count]
  json.in_ost dependency[:in_ost]
end
