module Scimitar

  # An ActiveRecord-centric subclass of Scimitar::ResourcesController. See that
  # class's documentation first, as it describes things that your subclass must
  # do which apply equally to subclasses of this ActiveRecord-focused code.
  #
  # In addition to requirements mentioned above, your subclass MUST override
  # protected method #storage_scope, returning an ActiveRecord::Relation which
  # is used as a starting scope for any 'index' (list) views. This gives you an
  # opportunity to apply things like is-active filters, apply soft deletion
  # scopes, apply security scopes and so-on. For example:
  #
  #     protected
  #       def storage_scope
  #         self.storage_class().where(is_deleted: false)
  #       end
  #
  class ActiveRecordBackedResourcesController < ResourcesController

    rescue_from 'ActiveRecord::RecordNotFound', with: :handle_resource_not_found # See Scimitar::ApplicationController

    before_action :obtain_id_column_name_from_attribute_map

    # GET (list)
    #
    def index
      query = if params[:filter].blank?
        self.storage_scope()
      else
        attribute_map = storage_class().new.scim_queryable_attributes()
        parser        = ::Scimitar::Lists::QueryParser.new(attribute_map)

        parser.parse(params[:filter])
        parser.to_activerecord_query(self.storage_scope())
      end

      pagination_info = scim_pagination_info(query.count())

      # SCIM 2.0 RFC 7644: When count=0, return metadata only (no Resources).
      # This avoids an unnecessary database query for record data.
      page_of_results = if pagination_info.limit == 0
        []
      else
        query
          .order(@id_column => :asc)
          .offset(pagination_info.offset)
          .limit(pagination_info.limit)
          .to_a()
      end

      super(pagination_info, page_of_results) do | record |
        record_to_scim(record)
      end
    end

    # GET/id (show)
    #
    def show
      super do |record_id|
        record = self.find_record(record_id)
        record_to_scim(record)
      end
    end

    # POST (create)
    #
    # Calls #save! on the new record if no block is given, else invokes the
    # block, passing it the new ActiveRecord model instance to be saved. It
    # is up to the block to make any further changes and persist the record.
    #
    # Blocks are invoked from within a wrapping database transaction.
    # ActiveRecord::RecordInvalid exceptions are handled for you, rendering
    # an appropriate SCIM error.
    #
    def create(&block)
      super do |scim_resource|
        self.storage_class().transaction do
          record = self.storage_class().new
          record.from_scim!(scim_hash: scim_resource.as_json())
          self.save!(record, &block)
          record_to_scim(record)
        end
      end
    end

    # PUT (replace)
    #
    # Calls #save! on the updated record if no block is given, else invokes the
    # block, passing the updated record which the block must persist, with the
    # same rules as for #create.
    #
    def replace(&block)
      super do |record_id, scim_resource|
        self.storage_class().transaction do
          record = self.find_record(record_id)
          record.from_scim!(scim_hash: scim_resource.as_json())
          self.save!(record, &block)
          record_to_scim(record)
        end
      end
    end

    # PATCH (update)
    #
    # Calls #save! on the updated record if no block is given, else invokes the
    # block, passing the updated record which the block must persist, with the
    # same rules as for #create.
    #
    def update(&block)
      super do |record_id, patch_hash|
        self.storage_class().transaction do
          record = self.find_record(record_id)
          record.from_scim_patch!(patch_hash: patch_hash)
          self.save!(record, &block)
          record_to_scim(record)
        end
      end
    end

    # DELETE (remove)
    #
    # Deletion methods can vary quite a lot with ActiveRecord objects. If you
    # just let this superclass handle things, it'll call:
    #
    #   https://api.rubyonrails.org/classes/ActiveRecord/Persistence.html#method-i-destroy-21
    #
    # ...i.e. the standard delete-record-with-callbacks method. If you pass
    # a block, then this block is invoked and passed the ActiveRecord model
    # instance to be destroyed. You can then do things like soft-deletions,
    # updating an "active" flag, perform audit-related operations and so-on.
    #
    def destroy(&block)
      super do |record_id|
        record = self.find_record(record_id)

        if block_given?
          yield(record)
        else
          record.destroy!
        end
      end
    end

    # =========================================================================
    # PROTECTED INSTANCE METHODS
    # =========================================================================
    #
    protected

      # Return an ActiveRecord::Relation used as the starting scope for #index
      # lists and any 'find by ID' operation.
      #
      def storage_scope
        raise NotImplementedError
      end

      # Return an Array of exceptions that #save! can rescue and handle with a
      # SCIM error automatically.
      #
      def scimitar_rescuable_exceptions
        [
          ActiveRecord::RecordInvalid,
          ActiveRecord::RecordNotSaved,
          ActiveRecord::RecordNotUnique,
        ]
      end

      # Find a record by ID. Subclasses can override this if they need special
      # lookup behaviour.
      #
      # +record_id+:: Record ID (SCIM schema 'id' value - "our" ID).
      #
      def find_record(record_id)
        self.storage_scope().find_by!(@id_column => record_id)
      end

      # DRY up controller actions - pass a record; returns the SCIM
      # representation, with a "show" location specified via #url_for.
      #
      def record_to_scim(record)
        record.to_scim(
          location: url_for(action: :show, id: record.send(@id_column)),
          include_attributes: params.fetch(:attributes, "").split(",")
        )
      end

      # Save a record, dealing with validation exceptions by raising SCIM
      # errors.
      #
      # +record+:: ActiveRecord subclass to save.
      #
      # If you just let this superclass handle things, it'll call the standard
      # +#save!+ method on the record. If you pass a block, then this block is
      # invoked and passed the ActiveRecord model instance to be saved. You can
      # then do things like calling a different method, using a service object
      # of some kind, perform audit-related operations and so-on.
      #
      # The return value is not used internally, making life easier for
      # overriding subclasses to "do the right thing" / avoid mistakes (instead
      # of e.g. requiring that a to-SCIM representation of 'record' is returned
      # and relying upon this to generate correct response payloads - an early
      # version of the gem did this and it caused a confusing subclass bug).
      #
      def save!(record, &block)
        if block_given?
          yield(record)
        else
          record.save!
        end
      rescue *self.scimitar_rescuable_exceptions() => exception
        handle_on_save_exception(record, exception)
      end

      # Deal with exceptions related to errors upon saving, by responding with
      # an appropriate SCIM error. This is most effective if the record has
      # validation errors defined, but falls back to the provided exception's
      # message otherwise.
      #
      # +record+::    The record that provoked the exception. Mandatory.
      # +exception+:: The exception that was raised. If omitted, a default of
      #               'Unknown', in English with no I18n, is used.
      #
      def handle_on_save_exception(record, exception = RuntimeError.new('Unknown'))
        details = if record.errors.present?
          record.errors.full_messages.join('; ')
        else
          exception.message
        end

        # https://tools.ietf.org/html/rfc7644#page-12
        #
        #   If the service provider determines that the creation of the requested
        #   resource conflicts with existing resources (e.g., a "User" resource
        #   with a duplicate "userName"), the service provider MUST return HTTP
        #   status code 409 (Conflict) with a "scimType" error code of
        #   "uniqueness"
        #
        if exception.is_a?(ActiveRecord::RecordNotUnique) || record.errors.any? { | e | e.type == :taken }
          raise Scimitar::ErrorResponse.new(
            status:   409,
            scimType: 'uniqueness',
            detail:   "Operation failed due to a uniqueness constraint: #{details}"
          )
        else
          raise Scimitar::ResourceInvalidError.new(details)
        end
      end

      # Called via +before_action+ - stores in @id_column the name of whatever
      # model column is used to store the record ID, via
      # Scimitar::Resources::Mixin::scim_attributes_map.
      #
      # Default is <tt>:id</tt>.
      #
      def obtain_id_column_name_from_attribute_map
        attrs      = storage_class().scim_attributes_map() || {}
        @id_column = attrs[:id] || :id
      end

  end
end
