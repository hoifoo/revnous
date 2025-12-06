Rails.application.routes.draw do
  devise_for :users, skip: [ :registrations ]
  # Admin routes
  namespace :admin do
    root "dashboard#index"
    resources :case_studies, except: [ :show ]
    resources :blogs, except: [ :show ]
    resources :notices, except: [ :show ]
    resources :products, except: [ :show ]
    resources :pricing_plans, except: [ :show ]
    resources :trusted_brands, except: [ :show ]
    resources :special_offers, except: [ :show ]
    resources :partners, except: [ :show ]
    resources :newsletter_subscribers, except: [ :show ]
    resources :legal_documents, except: [ :show ]
    resources :beta_users, only: [ :index, :destroy ]
  end

  # Public routes
  get "services", to: "services#index"
  resources :products, only: [ :index, :show ]
  resources :case_studies, only: [ :index, :show ]
  resources :blogs, only: [ :index, :show ], path: "blog"
  get "contact-us", to: "contacts#index", as: :contact_us
  post "contact", to: "contacts#create"
  post "newsletter", to: "newsletters#create", as: :newsletter_subscription
  get "altcha/challenge", to: "altcha_challenges#create", as: :altcha_challenge

  # Beta user routes
  get "beta-signup", to: "beta_users#index", as: :beta_signup
  post "beta-signup", to: "beta_users#create"

  # Global legal documents
  get "privacy-policy", to: "legal_documents#privacy_policy", as: :privacy_policy
  get "terms-of-service", to: "legal_documents#terms_of_service", as: :terms_of_service

  # Product-scoped routes
  scope "/products/:product_slug" do
    get "pricing", to: "pricing#product_pricing", as: :product_pricing
    get "privacy-policy", to: "legal_documents#product_privacy_policy", as: :product_privacy_policy
    get "terms-of-service", to: "legal_documents#product_terms_of_service", as: :product_terms_of_service
    get "beta-signup", to: "beta_users#index", as: :product_beta_signup
  end

  # Sitemap
  get "sitemap.xml", to: "sitemap#index", defaults: { format: :xml }

  # Solutions Engine (Polymorphic Landing Pages)
  get "/solutions/:slug", to: "solutions#show", as: :solution

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "home#index"
end
