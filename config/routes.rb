Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  #
  #
  get '/:pincode', to: 'dashboard#show'
  root to: 'dashboard#index'

end
