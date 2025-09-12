class MockGroupBatch < MockGroup
  def self.scim_attributes_map
    {
      id:          :id,
      externalId:  :scim_uid,
      displayName: :display_name,
      members:     [
        {
          list:  :scim_users_and_groups,
          using: { value: :id },
          # Minimal mock: assume user-only entries (type omitted => User)
          find_all_with: -> (entries) do
            ids = entries.map { |e| e['value'] }
            MockUser.where(primary_key: ids).to_a
          end
        }
      ]
    }
  end
end
