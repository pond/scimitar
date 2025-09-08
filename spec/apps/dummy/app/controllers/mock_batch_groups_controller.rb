class MockBatchGroupsController < Scimitar::ActiveRecordBackedResourcesController

  protected

    def storage_class
      MockGroupBatch
    end

    def storage_scope
      MockGroupBatch.all
    end

end
