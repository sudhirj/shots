Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  #
  #
  get '/:pincode', to: 'dashboard#show', as: :pincode
  post '/jump', to: 'dashboard#jump', as: :jump
  root to: 'dashboard#index'

end
