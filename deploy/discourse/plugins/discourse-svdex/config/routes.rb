# frozen_string_literal: true
DiscourseSvdex::Engine.routes.draw do
  get "/discoveries/:username" => "discoveries#index", defaults: { format: :json }
  get "/discovery-credit/:user_id" => "discoveries#show", defaults: { format: :json }
  put "/discovery-credit/:user_id" => "discoveries#update", defaults: { format: :json }
  get "/my-interest" => "my_interest#index", defaults: { format: :json }
  delete "/my-interest/:kind/:id" => "my_interest#destroy", defaults: { format: :json }
  get "/offering-bids/:topic_id" => "offering_bids#index", defaults: { format: :json }
  put "/offering-bids/:topic_id" => "offering_bids#update", defaults: { format: :json }
  delete "/offering-bids/:topic_id" => "offering_bids#destroy", defaults: { format: :json }
  get "/interests/:organization_id" => "interests#index", defaults: { format: :json }
  put "/interests/:organization_id/:side" => "interests#update", defaults: { format: :json }
  delete "/interests/:organization_id/:side" => "interests#destroy", defaults: { format: :json }
  get "/company-directory" => "company_directory#index", defaults: { format: :json }
  get "/company-profile/:username" => "company_directory#profile", defaults: { format: :json }
  get "/company-details/:user_id" => "company_details#show", defaults: { format: :json }
  put "/company-details/:user_id" => "company_details#update", defaults: { format: :json }
  get "/" => "listings#index"
  get ".json" => "listings#index"
  get "/companies" => "listings#companies", defaults: { format: :json }
  get "/watchlist" => "listings#saved"
  get "/:id" => "listings#show"
end
