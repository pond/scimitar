module Scimitar
  module Resources

    # The mixin included by any class in your application which is to be mapped
    # to and exposed via a SCIM interface. Any one such class must have one
    # corresponding ResourcesController subclass declaring its association to
    # that model.
    #
    # Your class becomes responsible for implementing various *class methods*
    # as described below. YOU MUST DECLARE THESE **BEFORE** YOU INCLUDE THE
    # MIXIN MODULE because Ruby parses classes top-down and the mixin checks to
    # make sure that required methods exist, so these must be defined *first*.
    #
    #
    #
    # == scim_resource_type
    #
    # Define this method to return the Scimitar resource class that corresponds
    # to the mixing-in class.
    #
    # For example, if you have an ActiveRecord "User" class that maps to a SCIM
    # "User" resource type:
    #
    #     def self.scim_resource_type
    #       return Scimitar::Resources::User
    #     end
    #
    # This is used to render SCIM JSON data via #to_scim.
    #
    #
    #
    # == scim_attributes_map
    #
    # Define this method to return a Hash that maps SCIM attributes to
    # corresponding supported accessor methods in the mixing-in class.
    #
    # Define read-only, write-only or read-write attributes here. Scimitar will
    # check for an appropriate accessor depending on whether SCIM operations
    # are read or write and acts accordingly. At each level of the Ruby Hash,
    # the keys are case-sensitive attributes from the SCIM schema and values
    # are either Symbols, giving a corresponding read/write accessor name in
    # the mixing-in class, Hashes for nested SCIM schema data as shown below or
    # for Array entries, special structures described later.
    #
    # For example, for a User model <-> SCIM user:
    #
    #     def self.scim_attributes_map
    #       return {
    #         id:         :id,
    #         externalId: :scim_external_id,
    #         userName:   :username,
    #         name:       {
    #           givenName:  :given_name,
    #           familyName: :last_name
    #         },
    #         active: :is_active?
    #       }
    #     end
    #
    # Note that providing storage and filter (search) support for externalId is
    # VERY STRONGLY recommended (bordering on mandatory) for your service to
    # provide adequate support for typical clients to function smoothly. See
    # "scim_queryable_attributes" below for filtering.
    #
    # This omits things like "email" because in SCIM those are specified in an
    # Array, where each entry has a "type" field - e.g. "home", "work". Within
    # SCIM this is common but there are also just free lists of data, such as
    # the list of Members in a Group. This makes the mapping description more
    # complex. You can provide two kinds of mapping data:
    #
    # * One where a specific SCIM attribute is present in each array entry and
    #   can contain only a set of specific, discrete values; your mapping
    #   defines entries for each value of interest. E-mail is an example here,
    #   where "type" is the SCIM attribute and you might map "work" and "home".
    #
    # For discrete matches, you declare the Array containing Hashes with key
    # "match", where the value gives the name of the SCIM attribute to read or
    # write for each array entry; "with", where the value gives the thing to
    # match at this attribute; then "using", where the value is a Hash giving
    # a mapping schema just as described herein (schema can nest as deeply as
    # you like).
    #
    # Given that e-mails in SCIM look something like this:
    #
    #     "emails": [
    #       {
    #         "value": "bjensen@example.com",
    #         "type": "work",
    #         "primary": true
    #       },
    #       {
    #         "value": "babs@jensen.org",
    #         "type": "home"
    #       }
    #     ]
    #
    # ...then we could extend the above attributes map example thus:
    #
    #     def self.scim_attributes_map
    #       # ...
    #       emails: [
    #         {
    #           match: 'type',
    #           with:  'work',
    #           using: {
    #             value:   :work_email_address,
    #             primary: true
    #           }
    #         },
    #         {
    #           match: 'type',
    #           with:  'home',
    #           using: { value: :home_email_address }
    #         }
    #       ],
    #       # ...
    #     end
    #
    # ...where the including class would have a #work_email_address accessor
    # and we're hard-coding this as the primary (preferred) address (but could
    # just as well map this to another accessor, e.g. :work_email_is_primary?).
    #
    # * One where a SCIM array contains just a list of arbitrary entries, each
    #   with a known schema, and these map attribute-by-attribute to same-index
    #   items in a corresponding array in the mixing-in model. Group members
    #   are the example use case here.
    #
    # For things like a group's list of members, again include an array in the
    # attribute map as above but this time have a key "list" with a value that
    # is the attribute accessor in your mixing in model that returns an
    # Enumerable of values to map, then as above, "using" which provides the
    # nested schema saying how each of those objects should be mapped.
    #
    # Suppose you were mixing this module into a Team class and there was an
    # association Team#users that provided an Enumerable of team member User
    # objects:
    #
    #     def self.scim_attributes_map
    #       # ...
    #       groups: [
    #         {
    #           list:  :users,         # <-- i.e. Team.users,
    #           using: {
    #             value:   :id,        # <-- i.e. Team.users[n].id
    #             display: :full_name  # <-- i.e. Team.users[n].full_name
    #           },
    #           class: Team, # Optional; see below
    #           find_with: -> (scim_list_entry) {...} # See below
    #         }
    #       ],
    #       #...
    #     end
    #
    # The mixing-in class _must_ implement the read accessor identified by the
    # value of the "list" key, returning any indexed, Enumerable collection
    # (e.g. an Array or ActiveRecord::Relation instance). The optional key
    # ":find_with" is defined with a Proc that is passed the SCIM entry at each
    # list position. It must use this to look up the equivalent entry for
    # association via the write accessor described by the ":list" key. In the
    # example above, "find_with"'s Proc might look at a SCIM entry value which
    # is expected to be a user ID and find that User. The mapped set of User
    # data thus found would be written back with "#users=", due to the ":list"
    # key declaring the method name ":users". The optional "class" key is
    # recommended but not really *needed* unless the configuration option
    # Scimitar::EngineConfiguration::schema_list_from_attribute_mappings is
    # defined; see documentation of that option for more information.
    #
    # Note that you can only use either:
    #
    # * One or more static maps where each matches some other piece of source
    #   SCIM data field value, so that specific SCIM array entries are matched
    #
    # * A single dynamic list entry which maps app SCIM array entries.
    #
    # A mixture of static and dynamic data, or multiple dynamic entries in a
    # single mapping array value will produce undefined behaviour.
    #
    #
    #
    # == scim_mutable_attributes
    #
    # Define this method to return a Set (preferred) or Array of names of
    # attributes which may be written in the mixing-in class. The names MUST be
    # expressed as Symbols, *not* Strings.
    #
    # If you return +nil+, it is assumed that +any+ attribute mapped by
    # ::scim_attributes_map which has a write accessor will be eligible for
    # assignment during SCIM creation or update operations.
    #
    # For example, if everything in ::scim_attributes_map with a write accessor
    # is to be mutable over SCIM:
    #
    #     def self.scim_mutable_attributes
    #       return nil
    #     end
    #
    # Note that as a common special case, any mapped attribute of the Symbol
    # value ":id" will be removed from the list, as it is assumed to be e.g. a
    # primary key or similar. So, even though it'll have a write accessor, it
    # is not something that should be mutable over SCIM - it's taken to be your
    # internal record ID. If you do want :id included as mutable or if you have
    # a different primary key attribute name, you'll just need to return the
    # mutable attribute list directly in your ::scim_mutable_attributes method
    # rather than relying on the list extracted from ::scim_attributes_map.
    #
    #
    # == scim_queryable_attributes
    #
    # Define this method to return a Hash that maps field names you wish to
    # support in SCIM filter queries to corresponding attributes in the in the
    # mixing-in class. If +nil+ then filtering is not supported in the
    # ResourceController subclass which declares that it maps to the mixing-in
    # class. If not +nil+ but a SCIM filter enquiry is made for an unmapped
    # attribute, an 'invalid filter' exception is raised.
    #
    # If using ActiveRecord support in Scimitar::Lists::QueryParser, the mapped
    # entities are columns and that's expressed in the names of keys described
    # below; if you have other approaches to searching, these might be virtual
    # attributes or other such constructs rather than columns. That would be up
    # to your non-ActiveRecord's implementation to decide.
    #
    # Each STRING field name(s) represents a *flat* attribute path that might
    # be encountered in a filter - e.g. "name.familyName", "emails.value" (and
    # often it makes sense to define "emails" and "emails.value" identically to
    # allow for different client searching "styles", given ambiguities in RFC
    # 7644 filter examples).
    #
    # Each value is a hash of queryable SCIM attribute options, described
    # below - for example:
    #
    #     def self.scim_queryable_attributes
    #       return {
    #         'name.givenName'  => { column: :first_name },
    #         'name.familyName' => { column: :last_name  },
    #         'emails'          => { columns: [ :work_email_address, :home_email_address ] },
    #         'emails.value'    => { columns: [ :work_email_address, :home_email_address ] },
    #         'emails.type'     => { ignore: true },
    #         'groups.value'    => { column: Group.arel_table[:id] }
    #       }
    #     end
    #
    # Column references can be either a Symbol representing a column within
    # the resource model table, or an <tt>Arel::Attribute</tt> instance via
    # e.g. <tt>MyModel.arel_table[:my_column]</tt>.
    #
    # === Queryable SCIM attribute options
    #
    # +:column+::  Just one simple column for a mapping.
    #
    # +:columns+:: An Array of columns that you want to map using 'OR' for a
    #              single search of the corresponding entity.
    #
    # +:ignore+::  When set to +true+, the matching attribute is ignored rather
    #              than resulting in an "invalid filter" exception. Beware
    #              possibilities for surprised clients getting a broader result
    #              set than expected, since a constraint may have been ignored.
    #
    # Filtering is currently limited and searching within e.g. arrays of data
    # is not supported; only simple top-level keys can be mapped.
    #
    #
    # == Optional methods
    #
    # === scim_timestamps_map
    #
    # If you implement this class method, it should return a Hash with one or
    # both of the keys 'created' and 'lastModified', as Symbols. The values
    # should be methods that the including method supports which return a
    # creation or most-recently-updated time, respectively. The returned object
    # must support #iso8601 to convert to a String representation. Example for
    # a typical ActiveRecord object with standard timestamps:
    #
    #     def self.scim_timestamps_map
    #       {
    #         created:      :created_at,
    #         lastModified: :updated_at
    #       }
    #     end
    #
    module Mixin
      extend ActiveSupport::Concern

      included do
        %w{
          scim_resource_type
          scim_attributes_map
          scim_mutable_attributes
          scim_queryable_attributes
        }.each do | required_class_method_name |
          raise "You must define ::#{required_class_method_name} in #{self}" unless self.respond_to?(required_class_method_name)
        end

        # An instance-level method which calls ::scim_mutable_attributes and
        # either uses its returned array of mutable attribute names or reads
        # ::scim_attributes_map and determines the list from that. Caches
        # the result in an instance variable.
        #
        def scim_mutable_attributes
          @scim_mutable_attributes ||= self.class.scim_mutable_attributes()&.map(&:to_sym)

          if @scim_mutable_attributes.nil?
            @scim_mutable_attributes = Set.new

            # Variant of https://stackoverflow.com/a/49315255
            #
            extractor = ->(outer_enum) do
              outer_enum.each do |key, value|
                enum = [key, value].detect(&Enumerable.method(:===))
                if enum.nil?
                  @scim_mutable_attributes << value if value.is_a?(Symbol) && self.respond_to?("#{value}=")
                else
                  if enum.is_a?(Hash)
                    extractor.call(enum)
                  elsif enum.is_a?(Array)
                    enum.each do | static_or_dynamic_mapping |
                      if static_or_dynamic_mapping.key?(:match) # Static
                        extractor.call(static_or_dynamic_mapping[:using])
                      elsif static_or_dynamic_mapping.key?(:find_with) # Dynamic
                        @scim_mutable_attributes << static_or_dynamic_mapping[:list]
                      end
                    end
                  end
                end
              end
            end

            extractor.call(self.class.scim_attributes_map())
            @scim_mutable_attributes.delete(:id)
          end

          @scim_mutable_attributes
        end

        # An instance level method which calls ::scim_queryable_attributes and
        # caches the result in an instance variable, for symmetry with
        # #scim_mutable_attributes and to permit potential future enhancements
        # for how the return value of ::scim_queryable_attributes is handled.
        #
        def scim_queryable_attributes
          @scim_queryable_attributes ||= self.class.scim_queryable_attributes()
        end

        # Render self as a SCIM object using ::scim_attributes_map. Fields that
        # are marked as <tt>returned: 'never'</tt> are excluded.
        #
        # +location+::           The location (HTTP(S) full URI) of this
        #                        resource in the domain of the object including
        #                        this mixin - "your" IDs, not the remote SCIM
        #                        client's external IDs. #url_for is a good way
        #                        to generate this.
        #
        # +include_attributes+:: The attributes that should be included in the
        #                        response, in the form of a list of full
        #                        attribute paths. Schema IDs are not supported.
        #                        See RFC 7644 section 3.9 and section 3.10 for
        #                        more. When a collection is given, +nil+ value
        #                        items are also excluded from the response. If
        #                        omitted or given an empty collection, all
        #                        attributes are included.
        #
        def to_scim(location:, include_attributes: [])
          map             = self.class.scim_attributes_map()
          resource_type   = self.class.scim_resource_type()
          timestamps_map  = self.class.scim_timestamps_map() if self.class.respond_to?(:scim_timestamps_map)
          attrs_hash      = self.to_scim_backend(
            data_source:             self,
            resource_type:           resource_type,
            attrs_map_or_leaf_value: map,
            include_attributes:      include_attributes
          )

          resource        = resource_type.new(attrs_hash)
          meta_attrs_hash = { location: location }

          meta_attrs_hash[:created     ] = self.send(timestamps_map[:created     ])&.iso8601(0) if timestamps_map&.key?(:created)
          meta_attrs_hash[:lastModified] = self.send(timestamps_map[:lastModified])&.iso8601(0) if timestamps_map&.key?(:lastModified)

          resource.meta = Meta.new(meta_attrs_hash)
          return resource
        end

        # Update self from a SCIM object using ::scim_attributes_map. This does
        # NOT PERSIST ("save") 'this' instance - it just sets attribute values
        # within it.
        #
        # If you are mixing into an ActiveRecord subclass then depending on how
        # your ::scim_attributes_map updates associated objects (if any), Rails
        # might make database writes to update those associations immediately.
        # Given this, it is highly recommended that you wrap calls to this
        # method and your subsequent save of 'self' inside a transaction.
        #
        #     ActiveRecord::Base.transaction do
        #       record.from_scim!(scim_hash: some_payload)
        #       record.save!
        #     end
        #
        # Call ONLY for POST or PUT. For PATCH, see #from_scim_patch!.
        #
        # Mandatory named parameters:
        #
        # +scim_hash+::     A Hash that's the result of parsing a JSON payload
        #                   from an inbound POST or PUT request.
        #
        # Optional named parameters:
        #
        # +with_clearing+:: According to RFC 7644 section 3.5.1, PUT operations
        #                   MAY default or clear any attribute missing from
        #                   +scim_hash+ as this is deemed "not asserted by the
        #                   client" (see
        #                   https://tools.ietf.org/html/rfc7644#section-3.5.1).
        #                   This parameter controls such behaviour. It defaults
        #                   to +true+, so clearing is applied - single value
        #                   attributes are set to +nil+ and arrays are emptied.
        #                   If +false+, an unusual <b>preservation</b> mode is
        #                   applied and anything absent from +scim_hash+ will
        #                   have no impact on the target object (any mapped
        #                   attributes in the local data model with existing
        #                   non-nil values will retain those values).
        #
        # Returns 'self', for convenience of e.g. chaining other methods.
        #
        def from_scim!(scim_hash:, with_clearing: true)
          scim_hash.freeze()
          map = self.class.scim_attributes_map().freeze()

          self.from_scim_backend!(
            attrs_map_or_leaf_value: map,
            scim_hash_or_leaf_value: scim_hash,
            with_clearing:           with_clearing
          )

          return self
        end

        # Update self from a SCIM object representing a PATCH operation. This
        # does NOT PERSIST ("save") 'this' instance - it just sets attribute
        # values within it.
        #
        # SCIM patch operations are complex. A series of operations is given,
        # each asking to add, remove or replace specific attributes or, via
        # filters, potentially multiple attributes if the filter matches many.
        #
        # Pass the PATCH payload. Then:
        #
        # * This instance (self) is converted to a SCIM representation via
        #   calling #to_scim.
        #
        # * The inbound operations are applied. A Scimitar::ErrorResponse may
        #   be thrown if the patch data looks bad - if you are calling from a
        #   Scimitar::ActiveRecordBackedResourcesController subclass, this will
        #   be handled for you and returned as an appropriate HTTP response.
        #   Otherwise, you'll need to rescue it yourself and e.g. make use of
        #   Scimitar::ApplicationController#handle_scim_error, passing the
        #   exception object to it, if you are a subclass of that base class.
        #
        # * The (possibly) updated SCIM representation of 'self' is pushed
        #   back into 'this' instance via #from_scim!.
        #
        # IMPORTANT: Please see #from_scim! for notes about associations and
        # use of transactions with ActiveRecord.
        #
        # Call ONLY for PATCH. For POST and PUT, see #from_scim!.
        #
        def from_scim_patch!(patch_hash:)
          frozen_ci_patch_hash = patch_hash.with_indifferent_case_insensitive_access().freeze()
          ci_scim_hash         = self.to_scim(location: '(unused)').as_json().with_indifferent_case_insensitive_access()
          operations           = frozen_ci_patch_hash['operations']

          raise Scimitar::InvalidSyntaxError.new("Missing PATCH \"operations\"") unless operations

          operations.each do |operation|
            nature   = operation['op'   ]&.downcase
            path_str = operation['path' ]
            value    = operation['value']

            unless %w[add remove replace].include?(nature)
              raise Scimitar::InvalidSyntaxError.new("Unrecognised PATCH \"op\" value of \"#{nature}\"")
            end

            # https://tools.ietf.org/html/rfc7644#section-3.5.2.2
            #
            # o  If "path" is unspecified, the operation fails with HTTP status
            #    code 400 and a "scimType" error code of "noTarget".
            #
            # (...for "add" or "replace", no path means "whole object").
            #
            if nature == 'remove' && path_str.blank?
              raise Scimitar::ErrorResponse.new(
                status:    400,
                scimType: 'noTarget',
                detail:   'No "path" target given for "replace" operation'
              )
            end

            # Deal with the exception case of no path, where the entire object
            # is addressed. It's easier internally to treat a path as a set of
            # steps towards a final Hash key (attribute) with an associated
            # value to change (and filters may apply if the value is an Array).
            #
            extract_root = false
            if path_str.blank?
              extract_root = true
              path_str     = 'root'
              ci_scim_hash = { 'root' => ci_scim_hash }.with_indifferent_case_insensitive_access()
            end

            # Split the path into an array of path components, in a way
            # which is aware of extension schemas. See documentation of
            # Scimitar::Support::Utilities.path_str_to_array for details.
            #
            paths = ::Scimitar::Support::Utilities.path_str_to_array(
              self.class.scim_resource_type.extended_schemas,
              path_str
            )

            self.from_patch_backend!(
              nature:        nature,
              path:          paths,
              value:         value,
              altering_hash: ci_scim_hash,
              with_attr_map: self.class.scim_attributes_map()
            )

            if extract_root
              ci_scim_hash = ci_scim_hash['root']
            end
          end

          self.from_scim!(scim_hash: ci_scim_hash, with_clearing: false)
          return self
        end

        private # (...but note that we're inside "included do" within a mixin)

          # A recursive method that takes a Hash mapping SCIM attributes to the
          # mixing in class's attributes and via ::scim_attributes_map replaces
          # symbols in the schema with the corresponding value from the user.
          #
          # Given a schema with symbols, this method will search through the
          # object for the symbols, send those symbols to the model and replace
          # the symbol with the return value.
          #
          # +data_source+::             The source of data. At the top level,
          #                             this is "self" (an instance of the
          #                             class mixing in this module).
          #
          # +resource_type+::           The resource type carrying the schemas
          #                             describing the SCIM object. If at the
          #                             top level when +data_source+ is +self+,
          #                             this would be sent as
          #                             <tt>self.class.scim_resource_type()</tt>.
          #
          # +attrs_map_or_leaf_value+:: The attribute map. At the top level,
          #                             this is from ::scim_attributes_map.
          #
          # +include_attributes+::      The attributes that should be included
          #                             in the response, in the form of a list
          #                             of full attribute paths. Schema IDs are
          #                             not supported. See RFC 7644 section
          #                             3.9 and section 3.10 for more. When a
          #                             collection is given, +nil+ value items
          #                             are also excluded from the response. If
          #                             omitted or given an empty collection,
          #                             all attributes are included.
          #
          # Internal recursive calls also send:
          #
          # +attribute_path+::          Array of path components to the
          #                             attribute, which can be found through
          #                             +resource_type+ so that things like the
          #                             "+returned+" state can be checked.
          #
          def to_scim_backend(
            data_source:,
            resource_type:,
            attrs_map_or_leaf_value:,
            include_attributes:,
            attribute_path: []
          )
            # NOTE EARLY EXIT
            #
            return unless scim_attribute_included?(
              include_attributes: include_attributes,
              attribute_path:     attribute_path
            )

            # On assumption of a top-level attributes list, the 'return never'
            # state is only checked on the recursive call from a Hash type. The
            # other handled types are assumed to only happen when called
            # recursively, so no need to check as no such call is made for a
            # 'return never' attribute.
            #
            case attrs_map_or_leaf_value
              when Hash # Expected at top-level of any map, or nested within
                result = attrs_map_or_leaf_value.each.with_object({}) do |(key, value), hash|
                  nested_attribute_path = attribute_path + [key]

                  if resource_type.find_attribute(*nested_attribute_path)&.returned != "never"
                    hash[key] = to_scim_backend(
                      data_source:             data_source,
                      resource_type:           resource_type,
                      attribute_path:          nested_attribute_path,
                      attrs_map_or_leaf_value: value,
                      include_attributes:      include_attributes
                    )
                  end
                end

                result.compact! if include_attributes.any?
                result

              when Array # Static or dynamic mapping against lists in data source
                built_dynamic_list = false
                mapped_array = attrs_map_or_leaf_value.map do |value|
                  if ! value.is_a?(Hash)
                    raise 'Bad attribute map: Array contains something other than mapping Hash(es)'

                  elsif value.key?(:match) # Static map
                    static_hash = { value[:match] => value[:with] }
                    static_hash.merge!(
                      to_scim_backend(
                        data_source:             data_source,
                        resource_type:           resource_type,
                        attribute_path:          attribute_path,
                        attrs_map_or_leaf_value: value[:using],
                        include_attributes:      include_attributes
                      )
                    )
                    static_hash

                  elsif value.key?(:list) # Dynamic mapping of each complex list item
                    built_dynamic_list = true
                    list = data_source.public_send(value[:list])
                    list.map do |list_entry|
                      to_scim_backend(
                        data_source:             list_entry,
                        resource_type:           resource_type,
                        attribute_path:          attribute_path,
                        attrs_map_or_leaf_value: value[:using],
                        include_attributes:      include_attributes
                      )
                    end

                  else # Unknown type, just treat as flat values
                    raise 'Bad attribute map: Mapping Hash inside Array does not contain supported data'

                  end
                end

                # If a dynamic list was generated, it's sitting as a nested
                # Array in the first index of the mapped result; pull it out.
                #
                mapped_array = mapped_array.first if built_dynamic_list
                mapped_array

              when Symbol # Leaf node, Symbol -> reader method to call on data source
                if data_source.respond_to?(attrs_map_or_leaf_value) # A read-accessor exists?
                  value = data_source.public_send(attrs_map_or_leaf_value)
                  value = value.to_s if value.is_a?(Numeric)
                  value
                else
                  nil
                end

              else # Leaf node, other type -> literal static value to use
                attrs_map_or_leaf_value
            end
          end

          # Given a SCIM resource representation (left) and an attribute map to
          # an instance of the mixin-including class / 'self' (right), walk the
          # attribute map, looking up equivalent values in the SCIM resource.
          # Mutable attributes will be set from the SCIM data, or cleared if
          # the SCIM data has nothing set ("PUT" semantics; splat resource data
          # in full, writing all mapped attributes).
          #
          # * Literal map values like 'true' are for read-time uses; ignored.
          # * Symbol map values are treated as read accessor method names and a
          #   write accessor checked for by adding "=". If this method exists,
          #   a value write is attempted using the SCIM resource data.
          # * Static and dynamic array mappings perform as documented for
          #   ::scim_attributes_map.
          #
          #     {                                                     | {
          #       "userName": "foo",                                  |   'id': :id,
          #       "name": {                                           |   'externalId': :scim_uid,
          #         "givenName": "Foo",                               |   'userName': :username,
          #         "familyName": "Bar"                               |   'name': {
          #       },                                                  |     'givenName': :first_name,
          #       "active": true,                                     |     'familyName': :last_name
          #       "emails": [                                         |   },
          #         {                                                 |   'emails': [
          #           "type": "work",                  <------\       |     {
          #           "primary": true,                         \------+---    'match': 'type',
          #           "value": "foo.bar@test.com"                     |       'with': 'work',
          #         }                                                 |       'using': {
          #       ],                                                  |         'value': :work_email_address,
          #       "phoneNumbers": [                                   |         'primary': true
          #         {                                                 |       }
          #           "type": "work",                                 |     }
          #           "primary": false,                               |   ],
          #           "value": "+642201234567"                        |   groups: [
          #         }                                                 |     {
          #       ],                                                  |       list:  :groups,
          #       "id": "42",                                         |       using: {
          #       "externalId": "AA02984",                            |         value:   :id,
          #       "meta": {                                           |         display: :full_name
          #         "location": "https://test.com/mock_users/42",     |       }
          #         "resourceType": "User"                            |     }
          #       },                                                  |   ],
          #       "schemas": [                                        |   'active': :is_active
          #         "urn:ietf:params:scim:schemas:core:2.0:User"      | }
          #       ]                                                   |
          #     }                                                     |
          #
          # Named parameters:
          #
          # +attrs_map_or_leaf_value+:: Attribute map; recursive calls just
          #                             pass in the fragment for recursion, so
          #                             at the deepest level, this ends up
          #                             being a leaf node which may have a
          #                             Symbol method name, used to look for a
          #                             write accessor; or a read-only literal,
          #                             which is ignored (right hand side of
          #                             the ASCII art diagram).
          #
          # +scim_hash_or_leaf_value+:: Similar to +attrs_map_or_leaf_value+
          #                             but tracks the SCIM schema data being
          #                             read as input source material (left
          #                             hand side of the ASCII art diagram).
          #
          # +with_clearing+::           If +true+, attributes absent in
          #                             +scim_hash_or_leaf_value+ but present
          #                             in +attrs_map_or_leaf_value+ will be
          #                             cleared (+nil+ or empty array), for PUT
          #                             ("replace") semantics. If +false+, such
          #                             missing attribute values are left
          #                             untouched - whatever mapped value is in
          #                             +self+ is preserved.
          #
          # +path+::                    Array of SCIM attribute names giving a
          #                             path into the SCIM schema where
          #                             iteration has reached. Used to find the
          #                             schema attribute definition and check
          #                             mutability before writing.
          #
          def from_scim_backend!(
            attrs_map_or_leaf_value:,
            scim_hash_or_leaf_value:,
            with_clearing:,
            path: []
          )
            scim_hash_or_leaf_value = scim_hash_or_leaf_value.with_indifferent_case_insensitive_access() if scim_hash_or_leaf_value.is_a?(Hash)

            # We get the schema via this instance's class's resource type, even
            # if we end up in collections of other types - because it's *this*
            # schema at the top level that defines the attributes of interest
            # within any collections, not SCIM schema - if any - for the items
            # within the collection (a User's "groups" per-array-entry schema
            # is quite different from the Group schema).
            #
            resource_class = self.class.scim_resource_type()

            case attrs_map_or_leaf_value
              when Hash # Nested attribute-value pairs
                attrs_map_or_leaf_value.each do | scim_attribute, sub_attrs_map_or_leaf_value |
                  next if scim_attribute&.to_s&.downcase == 'id' && path.empty?

                  # Handle extension schema. Contributed by @bettysteger and
                  # @MorrisFreeman via:
                  #
                  #   https://github.com/pond/scimitar/issues/48
                  #   https://github.com/pond/scimitar/pull/49
                  #
                  # Note the shortcoming that attribute names within extensions
                  # must be unique, as this mechanism basically just pulls out
                  # extension attributes to the top level, losing what amounts
                  # to the namespace that the extension schema ID provides.
                  #
                  attribute_tree = []
                  resource_class.extended_schemas.each do |schema|
                    if schema.scim_attributes.any? { |attribute| attribute.name == scim_attribute.to_s }
                      attribute_tree << schema.id
                      break # NOTE EARLY LOOP EXIT
                    end
                  end
                  attribute_tree << scim_attribute.to_s

                  continue_processing = if with_clearing
                    true
                  else
                    most_of_attribute_tree = attribute_tree[...-1]
                    last_attribute_in_tree = attribute_tree.last

                    if most_of_attribute_tree.empty?
                      scim_hash_or_leaf_value&.key?(last_attribute_in_tree)
                    else
                      scim_hash_or_leaf_value&.dig(*most_of_attribute_tree)&.key?(last_attribute_in_tree)
                    end
                  end

                  if continue_processing
                    sub_scim_hash_or_leaf_value = scim_hash_or_leaf_value&.dig(*attribute_tree)

                    self.from_scim_backend!(
                      attrs_map_or_leaf_value: sub_attrs_map_or_leaf_value,
                      scim_hash_or_leaf_value: sub_scim_hash_or_leaf_value, # May be 'nil'
                      with_clearing:           with_clearing,
                      path:                    path + [scim_attribute]
                    )
                  end
                end

              when Array # Static or dynamic maps
                attrs_map_or_leaf_value.each_with_index do | mapped_array_entry |
                  next unless mapped_array_entry.is_a?(Hash)

                  if mapped_array_entry.key?(:match) # Static map
                    attr_to_match  = mapped_array_entry[:match].to_s
                    value_to_match = mapped_array_entry[:with]
                    sub_attrs_map  = mapped_array_entry[:using]

                    # Search for the array entry in the SCIM object that
                    # matches the thing we're looking for via :match & :with.
                    #
                    found_source_list_entry = scim_hash_or_leaf_value&.find do | scim_array_entry |
                      scim_array_entry[attr_to_match] == value_to_match
                    end

                    self.from_scim_backend!(
                      attrs_map_or_leaf_value: sub_attrs_map,
                      scim_hash_or_leaf_value: found_source_list_entry, # May be 'nil'
                      with_clearing:           with_clearing,
                      path:                    path
                    )

                  elsif mapped_array_entry.key?(:list) # Dynamic mapping of each complex list item
                    attribute = resource_class.find_attribute(*path)
                    method    = "#{mapped_array_entry[:list]}="

                    if (attribute&.mutability == 'readWrite' || attribute&.mutability == 'writeOnly') && self.respond_to?(method)
                      find_with_proc = mapped_array_entry[:find_with]

                      unless find_with_proc.nil?
                        mapped_list = (scim_hash_or_leaf_value || []).map do | source_list_entry |
                          find_with_proc.call(source_list_entry)
                        end

                        mapped_list.compact!

                        self.public_send(method, mapped_list)
                      end
                    end
                  end # "elsif mapped_array_entry.key?(:list)"
                end # "map_entry&.each do | mapped_array_entry |"

              when Symbol # Setter/getter method at leaf position in attribute map
                if path.length == 1 && path.first&.to_s&.downcase == 'externalid' # Special case held only in schema base class
                  mutable = true
                else
                  attribute = resource_class.find_attribute(*path)
                  mutable   = attribute&.mutability == 'readWrite' || attribute&.mutability == 'writeOnly'
                end

                if mutable
                  method = "#{attrs_map_or_leaf_value}="
                  self.public_send(method, scim_hash_or_leaf_value) if self.respond_to?(method)
                end

              # else - fixed value of interest in #to_scim only.

            end # "case scim_hash_or_leaf_value"
          end # "def from_scim_backend!..."

          # Recursive back-end for #from_scim_patch! which traverses paths down
          # into one or - if multiple-match filters are encountered - multiple
          # attributes and performs updates on a SCIM Hash representation of
          # 'self'. Throws Scimitar::ErrorResponse (or a subclass thereof) upon
          # encountering any errors.
          #
          # Named parameters:
          #
          # +nature+::        The PATCH operation nature - MUST be a lower case
          #                   String of 'add', 'remove' or 'replace' ONLY.
          #
          # +path+::          Operation path, as a series of array entries (so
          #                   an inbound dot-separated path string would first
          #                   be split into an array by the caller). For
          #                   internal recursive calls, this will be a subset
          #                   of array entries from an index somewhere into the
          #                   top-level array, through to its end.
          #
          # +value+::         The value to apply at the attribute(s) identified
          #                   by +path+. Ignored for 'remove' operations.
          #
          # +altering_hash+:: The Hash to operate on at the current +path+. For
          #                   recursive calls, this will be some way down into
          #                   the SCIM representation of 'self'. MUST be a
          #                   HashWithIndifferentCaseInsensitiveAccess.
          #
          # Note that SCIM PATCH operations permit *no* path for 'replace' and
          # 'add' operations, meaning "apply to whole object". To avoid special
          # case code in the back-end, callers should in such cases add their
          # own wrapping Hash with a single key addressing the SCIM object of
          # interest and supply this key as the sole array entry in +path+.
          #
          def from_patch_backend!(nature:, path:, value:, altering_hash:, with_attr_map:)
            raise 'Case sensitivity violation' unless altering_hash.is_a?(Scimitar::Support::HashWithIndifferentCaseInsensitiveAccess)

            # These all throw exceptions if data is not as expected / required,
            # any of which are rescued below.
            #
            if path.count == 1
              from_patch_backend_apply!(
                nature:        nature,
                path:          path,
                value:         value,
                altering_hash: altering_hash,
                with_attr_map: with_attr_map
              )
            else
              from_patch_backend_traverse!(
                nature:        nature,
                path:          path,
                value:         value,
                altering_hash: altering_hash,
                with_attr_map: with_attr_map
              )
            end

            # Treat all exceptions as a malformed or unsupported PATCH.
            #
            rescue => _exception # You can use _exception if debugging
              raise Scimitar::InvalidSyntaxError.new('PATCH describes unrecognised attributes and/or unsupported filters')
          end

          # Called by #from_patch_backend! when dealing with path elements that
          # is not yet the final (leaf) entry. Deals with filters etc. and
          # traverses down one path level, making one or more recursive calls
          # back up into #from_patch_backend!
          #
          # Parameters are as for #from_patch_backend!, where +path+ is assumed
          # to have at least two entries.
          #
          # Happily throws exceptions if data is not as expected / required.
          #
          def from_patch_backend_traverse!(nature:, path:, value:, altering_hash:, with_attr_map:)
            raise 'Case sensitivity violation' unless altering_hash.is_a?(Scimitar::Support::HashWithIndifferentCaseInsensitiveAccess)

            path_component, filter = extract_filter_from(path_component: path.first)

            # https://tools.ietf.org/html/rfc7644#section-3.5.2.1
            #
            # o  If the target location specifies an attribute that does not exist
            #    (has no value), the attribute is added with the new value.
            #
            # https://tools.ietf.org/html/rfc7644#section-3.5.2.3
            #
            # o  If the target location path specifies an attribute that does not
            #    exist, the service provider SHALL treat the operation as an "add".
            #
            # Harmless in this context for 'remove'.
            #
            altering_hash[path_component] ||= Scimitar::Support::HashWithIndifferentCaseInsensitiveAccess.new

            # Unless the PATCH is bad, inner data is an Array or Hash always as
            # by definition this method is only called at path positions above
            # the leaf (target attribute-to-modify) node.
            #
            inner_data = altering_hash[path_component]

            found_data_for_recursion = if filter
              matched_hashes = []

              all_matching_filter(filter: filter, within_array: inner_data) do | matched_hash, _matched_index |
                matched_hashes << matched_hash
              end

              # Same reason as section 3.5.2.1 / 3.5.2.3 RFC quotes above.
              #
              if nature != 'remove' && matched_hashes.empty?
                new_hash = Scimitar::Support::HashWithIndifferentCaseInsensitiveAccess.new
                altering_hash[path_component] = [new_hash]
                matched_hashes                = [new_hash]
              end

              matched_hashes
            else
              [ inner_data ]
            end

            found_data_for_recursion.each do | found_data |
              extension_schema = self.class.scim_resource_type&.schemas&.detect { |schema| schema.id == path_component }

              attr_map = if path_component.to_sym == :root
                with_attr_map
              elsif extension_schema
                with_attr_map.slice(*extension_schema.scim_attributes.map { |attr| attr.name.to_sym })
              else
                with_attr_map[path_component.to_sym]
              end

              # Static array mappings need us to find the right map entry that
              # corresponds to the SCIM data at hand and recurse back into the
              # patch engine with the ":using" attribute map data.
              #
              if attr_map.is_a?(Array)
                array_attr_map = find_matching_static_attr_map(data: found_data, with_attr_map: attr_map)
                attr_map       = array_attr_map unless array_attr_map.nil?
              end

              self.from_patch_backend!(
                nature:        nature,
                path:          path[1..],
                value:         value,
                altering_hash: found_data,
                with_attr_map: attr_map
              )
            end
          end

          # Called by #from_patch_backend! when dealing with path the last path
          # element; applies the operation nature and value. Deals with filters
          # etc. in this final path position (filters only being relevant for
          # 'remove' or 'replace' operations).
          #
          # Parameters are as for #from_patch_backend!, where +path+ is assumed
          # to have exactly one entry only.
          #
          # Happily throws exceptions if data is not as expected / required.
          #
          def from_patch_backend_apply!(nature:, path:, value:, altering_hash:, with_attr_map:)
            raise 'Case sensitivity violation' unless altering_hash.is_a?(Scimitar::Support::HashWithIndifferentCaseInsensitiveAccess)

            path_component, filter = extract_filter_from(path_component: path.first)
            current_data_at_path   = altering_hash[path_component]

            if current_data_at_path.nil?
              case nature
                when 'add', 'replace'
                  if filter.present? # Implies we expected to replace/add to an item matched inside an array
                    altering_hash[path_component] = [value]
                  else
                    altering_hash[path_component] = value
                  end
                when 'remove'
                  # Nothing to do - no data here anyway
              end

            # Path filters are not described for 'add' and assumed to have no
            # meaning - https://tools.ietf.org/html/rfc7644#section-3.5.2.1
            #
            elsif filter.present? && nature != 'add'
              compact_after = false
              found_matches = false

              all_matching_filter(filter: filter, within_array: current_data_at_path) do | matched_hash, matched_index |
                found_matches = true

                case nature
                  when 'remove'
                    handled        = false
                    attr_map_path  = path[..-2] + [path_component]
                    attr_map_entry = with_attr_map.dig(*attr_map_path.map(&:to_sym))

                    # Deal with arrays specially; static maps require specific
                    # treatment, but dynamic or actual array values do not.
                    #
                    if attr_map_entry.is_a?(Array)
                      array_attr_map = find_matching_static_attr_map(
                        data:          matched_hash,
                        with_attr_map: attr_map_entry
                      )

                      # Found? Run through the mapped attributes. Anything that
                      # has an associated model attribute (i.e. some property
                      # that must be to be written into local data in response
                      # to the SCIM attribute being changed) is 'removed' by
                      # setting the corresponding value in "altering_hash" (of
                      # which "matched_hash" referenced fragment) to "nil".
                      #
                      handled = clear_data_for_removal!(
                        altering_hash: matched_hash,
                        with_attr_map: array_attr_map
                      )
                    end

                    # For dynamic arrays or other value types, we assume that
                    # just clearing the item from the array or setting its SCIM
                    # attribute to "nil" will result in an appropriate update
                    # to the local data model (e.g. by a change in an Rails
                    # associated collection or clearing a local model attribute
                    # directly to "nil").
                    #
                    unless handled
                      current_data_at_path[matched_index] = nil
                      compact_after = true
                    end

                  when 'replace'
                    matched_hash.reject! { true }
                    matched_hash.merge!(value)

                end
              end

              current_data_at_path.compact! if compact_after

              # https://tools.ietf.org/html/rfc7644#section-3.5.2.1
              #
              # o  If the target location specifies an attribute that does not exist
              #    (has no value), the attribute is added with the new value.
              #
              # https://tools.ietf.org/html/rfc7644#section-3.5.2.3
              #
              # o  If the target location path specifies an attribute that does not
              #    exist, the service provider SHALL treat the operation as an "add".
              #
              current_data_at_path << value unless found_matches || nature == 'remove'

            else
              case nature
                when 'add'
                  if current_data_at_path.is_a?(Array)
                    altering_hash[path_component] += value
                  elsif current_data_at_path.is_a?(Hash)

                    # Need to dive down inside a Hash value for additions; a
                    # deep merge isn't enough. Take this Group example where
                    # nature is "add" and value is:
                    #
                    #     "members":[
                    #       {
                    #         "value":"<user-id>"
                    #       }
                    #     ]
                    #
                    # ...in that case, a deep merge would *replace* the array
                    # at key 'members' with the above, rather than adding.
                    #
                    value.keys.each do | key |

                      # Handle the Azure (Entra) case where keys might use
                      # dotted paths - see:
                      #
                      #   https://github.com/pond/scimitar/issues/123
                      #
                      # ...along with keys containing schema IDs - see:
                      #
                      #   https://is.docs.wso2.com/en/next/apis/scim2-patch-operations/#add-user-attributes
                      #
                      # ...and scroll down to example 3 of "Complex singular
                      # attributes".
                      #
                      subpaths = ::Scimitar::Support::Utilities.path_str_to_array(
                        self.class.scim_resource_type.extended_schemas,
                        key
                      )

                      from_patch_backend!(
                        nature:        nature,
                        path:          path + subpaths,
                        value:         value[key],
                        altering_hash: altering_hash,
                        with_attr_map: with_attr_map
                      )
                    end
                  else
                    altering_hash[path_component] = value
                  end

                when 'replace'
                  if path_component == 'root'
                    dot_pathed_value = value.inject({}) do |hash, (k, v)|
                      subpaths = ::Scimitar::Support::Utilities.path_str_to_array(
                        self.class.scim_resource_type.extended_schemas,
                        k
                      )

                      hash.deep_merge!(::Scimitar::Support::Utilities.dot_path(subpaths, v))
                    end

                    altering_hash[path_component].deep_merge!(dot_pathed_value)
                  else
                    altering_hash[path_component] = value
                  end

                # The array check handles payloads seen from e.g. Microsoft for
                # remove-user-from-group, where contrary to examples in the RFC
                # which would imply "payload removes all users", there is the
                # clear intent to remove just one.
                #
                # https://tools.ietf.org/html/rfc7644#section-3.5.2.2
                # https://learn.microsoft.com/en-us/azure/active-directory/app-provisioning/use-scim-to-provision-users-and-groups#update-group-remove-members
                #
                # Since remove-all in the face of remove-one is destructive, we
                # do a special check here to see if there's an array value for
                # the array path that the payload yielded. If so, we can match
                # each value against array items and remove just those items.
                #
                # There is an additional special case to handle a bad example
                # from Salesforce:
                #
                #   https://help.salesforce.com/s/articleView?id=sf.identity_scim_manage_groups.htm&type=5
                #
                when 'remove'
                  if altering_hash[path_component].is_a?(Array) && value.present?

                    # Handle bad Salesforce example. That might be simply a
                    # documentation error, but just in case...
                    #
                    value = value.values.first if (
                      path_component&.downcase == 'members' &&
                      value.is_a?(Hash)                     &&
                      value.keys.size == 1                  &&
                      value.keys.first&.downcase == 'members'
                    )

                    # The Microsoft example provides an array of values, but we
                    # may as well cope with a value specified 'flat'. Promote
                    # such a thing to an Array to simplify the following code.
                    #
                    value = [value] unless value.is_a?(Array)

                    # For each value item, delete matching array entries. The
                    # concept of "matching" is:
                    #
                    # * For simple non-Hash values (if possible) just delete on
                    #   an exact match
                    #
                    # * For Hash-based values, only delete if all 'patch' keys
                    #   are present in the resource and all values thus match.
                    #
                    # Special case to ignore '$ref' from the Microsoft payload.
                    #
                    # Note coercion to strings to account for SCIM vs the usual
                    # tricky case of underlying implementations with (say)
                    # integer primary keys, which all end up as strings anyway.
                    #
                    value.each do | value_item |
                      altering_hash[path_component].map! do | item |
                        item_is_matched = if item.is_a?(Hash) && value_item.is_a?(Hash)
                          matched_all = true
                          value_item.each do | value_key, value_value |
                            next if value_key == '$ref'
                            if ! item.key?(value_key) || item[value_key]&.to_s != value_value&.to_s
                              matched_all = false
                            end
                          end
                          matched_all
                        else
                          item&.to_s == value_item&.to_s
                        end

                        if item_is_matched
                          handled        = false
                          attr_map_path  = path[..-2] + [path_component]
                          attr_map_entry = with_attr_map.dig(*attr_map_path.map(&:to_sym))
                          array_attr_map = find_matching_static_attr_map(
                            data:          item,
                            with_attr_map: attr_map_entry
                          )

                          handled = clear_data_for_removal!(
                            altering_hash: item,
                            with_attr_map: array_attr_map
                          )

                          handled ? item : nil
                        else
                          item
                        end
                      end

                      altering_hash[path_component].compact!
                    end

                  elsif altering_hash[path_component].is_a?(Array)
                    handled        = false
                    attr_map_path  = path[..-2] + [path_component]
                    attr_map_entry = with_attr_map.dig(*attr_map_path.map(&:to_sym))

                    if attr_map_entry.is_a?(Array) # Array mapping
                      altering_hash[path_component].each do | data_to_check |
                        array_attr_map = find_matching_static_attr_map(
                          data:          data_to_check,
                          with_attr_map: attr_map_entry
                        )

                        handled = clear_data_for_removal!(
                          altering_hash: data_to_check,
                          with_attr_map: array_attr_map
                        )
                      end
                    end

                    unless handled
                      altering_hash[path_component] = []
                    end

                  else
                    altering_hash[path_component] = nil
                  end

              end
            end
          end

          # Given a path element from SCIM, splits this into the attribute and
          # filter parts. Returns a tuple of [attribute, filter] where +filter+
          # will be +nil+ if no filter string was given.
          #
          # Named parameters:
          #
          # +path_component+:: Path component to examine (a String), e.g.
          #                    'userName' or 'emails[type eq "work"]'.
          #
          # Happily throws exceptions if data is not as expected / required.
          #
          def extract_filter_from(path_component:)
            filter = nil

            if path_component.include?('[')
              composition    = path_component.split(/[\[\]]/) # "attribute_name[filter_string]" -> ["attribute_name", "filter_string"]
              path_component = composition.first
              filter         = composition.last
            end

            [path_component, filter]
          end

          # Given a SCIM filter string and array of Hashes from a SCIM object,
          # search for matches within the array and invoke a given block for
          # each.
          #
          # Obtain filter strings by calling #extract_filter_from.
          #
          # TODO: Support more complex matchers than 'attr eq "value"'.
          #
          # Named parameters:
          #
          # +filter+::       Filter string, e.g. 'type eq "work"'.
          # +within_array+:: Array to search.
          #
          # You must pass a block. It is invoked with each matching array entry
          # (a Hash) and the index into +within_array+ at which this was found.
          #
          # Happily throws exceptions if data is not as expected / required.
          #
          def all_matching_filter(filter:, within_array:, &block)
            filter_components = filter.split(' ', 3)

            attribute = filter_components[0]
            operator  = filter_components[1]
            value     = filter_components[2]

            # Quoted value includes closing quote but has data afterwards?
            # Bad; implies extra conditions, e.g. '...eq "one two" and..." or
            # just junk data.
            #
            # Value is *not* quoted but contains a space? Means there must be
            # again either extra conditions or trailing junk data.
            #
            raise "Unsupported matcher #{filter.inspect}" if (
              filter_components.size != 3         ||
              operator.downcase != 'eq'           ||
              value.strip.match?(/\".+[^\\]\".+/) || # Literal '"', any data, no-backslash-then-literal (unescaped) '"', more data
              (!value.start_with?('"') && value.strip.include?(' '))
            )

            value = value[1..-2] if value.start_with?('"') && value.end_with?('"')

            within_array.each.with_index do | hash, index |
              ci_hash = hash.with_indifferent_case_insensitive_access()
              matched = ci_hash.key?(attribute) && ci_hash[attribute]&.to_s == value&.to_s

              yield(hash, index) if matched
            end
          end

          # Static attribute maps are used where SCIM attributes include some
          # kind of array, but it's not an arbitrary collection (dynamic maps
          # handle those). Instead, specific matched values inside the SCIM
          # data are mapped to specific attributes in the local data model.
          #
          # A typical example is for e-mails, where the SCIM "type" field in an
          # array of e-mail addresses might get mapped to detect specific types
          # of address such as "work" and "home", which happen to be stored
          # locally in dedicated attributes (e.g. "work_email_address").
          #
          # During certain processing operations we end up with a set of data
          # sent in from some SCIM operation and need to make modifications
          # (e.g. for a PATCH) that require the attribute map corresponding to
          # each part of the inbound SCIM data to be known. That's where this
          # method comes in. Usually, it's not hard to traverse a path of SCIM
          # data and dig a corresponding path through the attribute map Hash,
          # except for static arrays. There, we need to know which of the
          # static map entries matches a piece of SCIM data *from entries* in
          # the array of SCIM data corresponding to the static map.
          #
          # Call here with a piece of SCIM data from an array, along with an
          # attribute map fragment that must be the Array containing mappings.
          # Static mapping entries from this are compared with the data and if
          # a match is found, the sub-attribute map from the static entry's
          # <tt>:using</tt> key is returned; else +nil+.
          #
          # Named parameters are:
          #
          # +data+::          A SCIM data entry from a SCIM data array which is
          #                   mapped via the data given in the +with_attr_map+
          #                   parameter.
          #
          # +with_attr_map+:: The attributes map fragment which must be an
          #                   Array of mappings for the corresponding array
          #                   in the SCIM data from which +data+ was drawn.
          #
          # For example, if SCIM data consisted of:
          #
          #     {
          #       'emails' => [
          #         {
          #           'type' => 'work',
          #           'value' => 'work_1@test.com'
          #         },
          #         {
          #           'type' => 'work',
          #           'value' => 'work_2@test.com'
          #         }
          #       ]
          #     }
          #
          # ...which was mapped to the local data model using the following
          # attribute map:
          #
          #     {
          #       emails: [
          #         { match: 'type', with: 'home', using: { value: :home_email } },
          #         { match: 'type', with: 'work', using: { value: :work_email } },
          #       ]
          #     }
          #
          # ...then when it came to processing the SCIM 'emails' entry, one of
          # the array _entries_ therein would be passed in +data+, while the
          # attribute map's <tt>:emails</tt> key's value (the _array_ of map
          # data) would be given in <tt>:with_attr_map</tt>. The first SCIM
          # array entry matches +work+ so the <tt>:using</tt> part of the map
          # for that match would be returned:
          #
          #     { value: :work_email }
          #
          # If there was a SCIM entry with a type of something unrecognised,
          # such as 'holiday', then +nil+ would be returned since there is no
          # matching attribute map entry.
          #
          # Note that the <tt>:with_attr_map</tt> array can contain dynamic
          # mappings or even be just a simple fixed array - only things that
          # "look like" static mapping entries are processed (i.e. Hashes with
          # a Symbol key of <tt>:match</tt> present), with the rest ignored.
          #
          def find_matching_static_attr_map(data:, with_attr_map:)
            matched_map = with_attr_map.find do | static_or_dynamic_mapping |

              # Only interested in Static Array mappings.
              #
              if static_or_dynamic_mapping.is_a?(Hash) && static_or_dynamic_mapping.key?(:match)

                attr_to_match  = static_or_dynamic_mapping[:match].to_s
                value_to_match = static_or_dynamic_mapping[:with]
                sub_attrs_map  = static_or_dynamic_mapping[:using]

                # If this mapping refers to the matched data at hand,
                # then we can process it further (see later below.
                #
                found = data[attr_to_match] == value_to_match

                # Not found? No static map match perhaps; this could be
                # because a filter worked on a value which is fixed in
                # the static map. For example, a filter might check for
                # emails with "primary true", and the emergence of the
                # value for "primary" might not be in the data model -
                # it could be a constant declared in the 'using' part
                # of a static map. Ugh! Check for that.
                #
                unless found
                  sub_attrs_map.each do | scim_attr, model_attr_or_constant |

                    # Only want constants such as 'true' or 'false'.
                    #
                    next if model_attr_or_constant.is_a?(Symbol)

                    # Does the static value match in the source data?
                    # E.g. a SCIM attribute :primary with value 'true'.
                    #
                    if data[scim_attr] == model_attr_or_constant
                      found = true
                      break
                    end
                  end
                end

                found
              else
                false
              end
            end

            return matched_map&.dig(:using)
          end

          # Related to #find_matching_static_attr_map - often, the reason to
          # find a static array entry related to some inbound SCIM data is for
          # a removal operation, where the way to "remove" the data in the
          # local data model is to set an attribute to "nil". This means you
          # need to know if there is an attribute writer related to the SCIM
          # data being removed - and #find_matching_static_attr_map helps.
          #
          # With that done, you can call here with the hash data to be changed
          # and fragment of attribute map that #find_matching_static_attr_map
          # (or something like it) found.
          #
          # +altering_hash+:: The fragment of SCIM data that might be updated
          #                   with +nil+ to ultimately lead to an atttribute
          #                   writer identified through +with_attr_map+ being
          #                   called with that value. This is often the same
          #                   that was passed in the +data+ attribute in a
          #                   prior #find_matching_static_attr_map call.
          #
          # +with_attr_map::  The map fragment that corresponds exactly to the
          #                   +altering_hash+ data - e.g. the return value of a
          #                   prior #find_matching_static_attr_map call.
          #
          # Update +altering_hash+ in place if the map finds a relevant local
          # data model attribute and returns +true+. If no changes are made,
          # returns +false+.
          #
          def clear_data_for_removal!(altering_hash:, with_attr_map:)
            handled = false

            with_attr_map&.each do | scim_attr, model_attr_or_constant |

              # Only process attribute names, not constants.
              #
              next unless model_attr_or_constant.is_a?(Symbol)

              altering_hash[scim_attr] = nil
              handled                  = true
            end

            return handled
          end

          # Related to to_scim_backend, this methods tells whether +attribute_path+
          # should be included in the current +include_attributes+. This method
          # implements the attributes request from RFC 7644, section 3.9 and 3.10.
          #
          # +include_attributes+::      The attributes that should be included
          #                             in the response, in the form of a list of
          #                             full attribute paths. See RFC 7644 section
          #                             3.9 and section 3.10. An empty collection
          #                             will include all attributes.
          #
          # +attribute_path+::          Array of path components to the attribute,
          #                             e.g. <tt>["name", "givenName"]</tt>.
          #
          def scim_attribute_included?(include_attributes:, attribute_path:)
            return true unless attribute_path.any? && include_attributes.any?

            full_path = attribute_path.join(".")
            attribute_included = full_path.start_with?(*include_attributes)
            will_include_nested = include_attributes.any? { |att| att.start_with?(full_path) }

            attribute_included || will_include_nested
          end

      end # "included do"
    end # "module Mixin"
  end # "module Resources"
end # "module Scimitar"
