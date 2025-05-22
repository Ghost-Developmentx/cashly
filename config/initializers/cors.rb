Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "http://localhost:4000", "http://127.0.0.1:4000", "http://192.168.2.16:4000"

    resource "*",
      headers: :any,
      expose: [ "Authorization" ],
      methods: [ :get, :post, :patch, :put, :delete, :options, :head ]
  end
end
