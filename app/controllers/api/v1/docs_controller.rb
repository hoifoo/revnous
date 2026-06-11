module Api
  module V1
    # Serves the OpenAPI 3.1 description of the public read-only API.
    class DocsController < BaseController
      def openapi
        render json: spec
      end

      private

      def spec
        {
          openapi: "3.1.0",
          info: {
            title: "Revnous Public API",
            version: "1.0.0",
            description: "Read-only access to published Revnous blog posts and active products. No authentication required; only public content is exposed."
          },
          servers: [ { url: "https://www.revnous.com" } ],
          paths: {
            "/api/v1/blogs" => {
              get: {
                summary: "List published blog posts",
                operationId: "listBlogs",
                parameters: [
                  { name: "page", in: "query", required: false, schema: { type: "integer", minimum: 1 } }
                ],
                responses: { "200" => { description: "A paginated list of blog posts" } }
              }
            },
            "/api/v1/blogs/{slug}" => {
              get: {
                summary: "Get a single blog post by slug",
                operationId: "getBlog",
                parameters: [
                  { name: "slug", in: "path", required: true, schema: { type: "string" } }
                ],
                responses: {
                  "200" => { description: "The blog post" },
                  "404" => { description: "Not found" }
                }
              }
            },
            "/api/v1/products" => {
              get: {
                summary: "List active products",
                operationId: "listProducts",
                responses: { "200" => { description: "A list of products" } }
              }
            },
            "/api/v1/products/{id}" => {
              get: {
                summary: "Get a single product by id",
                operationId: "getProduct",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                responses: {
                  "200" => { description: "The product" },
                  "404" => { description: "Not found" }
                }
              }
            }
          }
        }
      end
    end
  end
end
