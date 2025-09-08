# This test app mounts everything at the root level, but you'd usually be doing
# more in your Rails app than just SCIM! Wrapping with 'namespace :foo do' is
# strongly recommended to avoid routing namespace collisions. See README.md for
# an example.
#
Rails.application.routes.draw do
  mount Scimitar::Engine, at: '/'

  get    'Users',      to: 'mock_users#index'
  get    'Users/:id',  to: 'mock_users#show'
  post   'Users',      to: 'mock_users#create'
  put    'Users/:id',  to: 'mock_users#replace'
  patch  'Users/:id',  to: 'mock_users#update'
  delete 'Users/:id',  to: 'mock_users#destroy'

  get    'Groups',     to: 'mock_groups#index'
  get    'Groups/:id', to: 'mock_groups#show'
  patch  'Groups/:id', to: 'mock_groups#update'

  # Batch lookup variant for testing find_all_with
  get    'BatchGroups',     to: 'mock_batch_groups#index'
  get    'BatchGroups/:id', to: 'mock_batch_groups#show'
  patch  'BatchGroups/:id', to: 'mock_batch_groups#update'

  # For testing blocks passed to ActiveRecordBackedResourcesController#create,
  # #update, #replace and #destroy.
  #
  post   'CustomCreateUsers',      to: 'custom_create_mock_users#create'
  patch  'CustomUpdateUsers/:id',  to: 'custom_update_mock_users#update'
  put    'CustomReplaceUsers/:id', to: 'custom_replace_mock_users#replace'
  delete 'CustomDestroyUsers/:id', to: 'custom_destroy_mock_users#destroy'

  # Needed because the auto-render of most of the above includes a 'url_for'
  # call for a 'show' action, so we must include routes (implemented in the
  # base class) for the "show" endpoint.
  #
  get  'CustomCreateUsers/:id',  to: 'custom_create_mock_users#show'
  get  'CustomUpdateUsers/:id',  to: 'custom_update_mock_users#show'
  get  'CustomReplaceUsers/:id', to: 'custom_replace_mock_users#show'

  # For testing blocks passed to ActiveRecordBackedResourcesController#save!
  #
  post 'CustomSaveUsers',     to: 'custom_save_mock_users#create'
  get  'CustomSaveUsers/:id', to: 'custom_save_mock_users#show'

  # For testing environment inside Scimitar::ApplicationController subclasses.
  #
  get  'CustomRequestVerifiers', to: 'custom_request_verifiers#index'
  post 'CustomRequestVerifiers', to: 'custom_request_verifiers#create'
end
