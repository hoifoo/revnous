json.data @products do |product|
  json.partial! "api/v1/products/product", product: product
end

json.meta do
  json.total_count @products.size
end
