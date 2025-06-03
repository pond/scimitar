module Scimitar
  module Lists

    # Simple SCIM filter support.
    #
    # This is currently an extremely limited query parser supporting only a
    # single "name-operator-value" query, no boolean operations or precedence
    # operators and it assumes "(I)LIKE" and "%" as wildcards in SQL for any
    # operators which require partial match (contains / "co", starts with /
    # "sw", ends with / "ew"). Generic operations don't support "pr" either
    # ('presence').
    #
    # Create an instance, then construct a query appropriate for your storage
    # back-end using #attribute to get the attribute name (in terms of "your
    # data", via your Scimitar::Resources::Mixin-including class implementation
    # of ::scim_queryable_attributes), #operator to get a generic SQL operator
    # such as "=" or "!=" and #parameter to get the value to be found (which
    # you MUST take care to process so as to avoid an SQL injection or similar
    # issues - use escaping suitable for your storage system's query language).
    #
    # * If you don't want to support (I)LIKE just check for it in #parameter's
    #   return value; it'll be upper case.
    #
    # Given the likelihood of using ActiveRecord via Rails, there's a higher
    # level and easier method - just create the instance, then call
    # QueryParser#to_activerecord_query to get a given base scope narrowed down
    # to match the filter parameters.
    #
    class QueryParser

      attr_reader :attribute_map, :rpn

      # Combined operator precedence.
      #
      OPERATORS = {
        'pr' => 4,

        'eq' => 3,
        'ne' => 3,
        'gt' => 3,
        'ge' => 3,
        'lt' => 3,
        'le' => 3,
        'co' => 3,
        'sw' => 3,
        'ew' => 3,

        'and' => 2,
        'or'  => 1
      }.freeze

      # Unary operators.
      #
      UNARY_OPERATORS = Set.new([
        'pr'
      ]).freeze

      # Binary operators.
      #
      BINARY_OPERATORS = Set.new(OPERATORS.keys.reject { |op| UNARY_OPERATORS.include?(op) }).freeze

      # Precompiled expression that matches a valid attribute name according to
      # https://tools.ietf.org/html/rfc7643#section-2.1.
      #
      ATTRNAME = /[[:alpha:]][[:alnum:]$-_]*/

      # =======================================================================
      # Tokenizing expressions
      # =======================================================================

      PAREN       = /[\(\)]/.freeze
      STR         = /"(?:\\"|[^"])*"/.freeze
      OP          = /(?:#{OPERATORS.keys.join('|')})\b/i.freeze
      WORD        = /[\w\.]+/.freeze
      SEP         = /\s?/.freeze
      NEXT_TOKEN  = /\A(#{PAREN}|#{STR}|#{OP}|#{WORD})#{SEP}/.freeze
      IS_OPERATOR = /\A(?:#{OP})\Z/.freeze

      MONGO_SIMPLE_COMPARISON_OPERATORS = {
        "eq" => "$eq", # equal
        "ne" => "$ne", # not equal
        "lt" => "$lt", # less than
        "le" => "$lte", # less than or equal
        "gt" => "$gt", # greater than
        "ge" => "$gte" # greater than or equal
      }.freeze

      # Present, starts with, ends with, contains
      MONGO_COMPLEX_COMPARISON_OPERATORS = %w[pr sw ew co].freeze
      MONGO_COMBINATION_OPERATORS = {
        "and" => "$and",
        "or" => "$or"
      }.freeze

      # Initialise an object.
      #
      # +attribute_map+:: See Scimitar::Resources::Mixin and documentation on
      #                   implementing ::scim_queryable_attributes; pass that
      #                   method's return value here.
      #
      def initialize(attribute_map)
        @attribute_map = attribute_map.with_indifferent_case_insensitive_access()
      end

      # Parse SCIM filter query into RPN stack
      #
      # +input+:: Input filter string, e.g. 'givenName eq "Briony"'.
      #
      # Returns a "self" for convenience. Call #rpn thereafter to retrieve the
      # parsed RPN stack. For example, given this input:
      #
      #     userType eq "Employee" and (emails co "example.com" or emails co "example.org")
      #
      # ...returns a parser object wherein #rpn will yield:
      #
      #     [
      #       'userType',
      #       '"Employee"',
      #       'eq',
      #       'emails',
      #       '"example.com"',
      #       'co',
      #       'emails',
      #       '"example.org"',
      #       'co',
      #       'or',
      #       'and'
      #     ]
      #
      # Alternatively, call #tree to get an expression tree:
      #
      #     [
      #       'and',
      #       [
      #         'eq',
      #         'userType',
      #         '"Employee"'
      #       ],
      #       [
      #         'or',
      #         [
      #           'co',
      #           'emails',
      #           '"example.com"'
      #         ],
      #         [
      #           'co',
      #           'emails',
      #           '"example.org"'
      #         ]
      #       ]
      #     ]
      #
      def parse(input)
        preprocessed_input = flatten_filter(input) rescue input

        @input  = input.clone() # Saved just for error msgs
        @tokens = self.lex(preprocessed_input)
        @rpn    = self.parse_expr()

        self.assert_eos()
        self
      end

      # Transform the RPN stack into a tree, returning the result. A new tree
      # is created each time, so you can mutate the result if need be.
      #
      # See #parse for more information.
      #
      def tree
        @stack = @rpn.clone()
        self.get_tree()
      end

      # Having called #parse, call here to generate an ActiveRecord query based
      # on a given starting scope. The scope is used for all 'and' queries and
      # as a basis for any nested 'or' scopes. For example, given this input:
      #
      #     userType eq "Employee" and (emails eq "a@b.com" or emails eq "a@b.org")
      #
      # ...and if you passed 'User.active' as a scope, there would be something
      # along these lines sent to ActiveRecord:
      #
      #     User.active.where(user_type: 'Employee').and(User.active.where(work_email: 'a@b.com').or(User.active.where(work_email: 'a@b.org')))
      #
      # See query_parser_spec.rb to get an idea for expected SQL based on various
      # kinds of input, especially section "context 'with complex cases' do".
      #
      # +base_scope+:: The starting scope, e.g. User.active.
      #
      # Returns an ActiveRecord::Relation giving an SQL query that is the gem's
      # best attempt at interpreting the SCIM filter string.
      #
      def to_activerecord_query(base_scope)
        return self.to_activerecord_query_backend(
          base_scope:      base_scope,
          expression_tree: self.tree()
        )
      end

      # Having called #parse, call here to generate a Mongoid query
      # For example, given this input:
      #
      #     userType eq "Employee" and (emails eq "a@b.com" or emails eq "a@b.org")
      #
      # this method will return a Mongoid query that looks like this:
      #
      #   {
      #     "$and" => [
      #       { :user_type => { "$eq" => 'Employee' } },
      #       { "$or" => [
      #         { :emails => { "$eq" => "a@b.com" } },
      #         { :emails => { "$eq" => "a@b.org" } }
      #       ]
      #     ]
      #  }
      #
      #  Use it with the Mongoid::Criteria#where method to filter results, e.g.:
      #
      #     User.where(parser.to_mongoid_query)
      #
      # Returns a Mongoid query that is the gem's
      # best attempt at interpreting the SCIM filter string.
      def to_mongoid_query
        tree_node_to_mongoid_query(tree)
      end

      # =======================================================================
      # PRIVATE INSTANCE METHODS
      # =======================================================================
      #
      private

        def parse_expr
          ast       = []
          expect_op = false

          while !self.eos? && self.peek() != ')'
            expect_op && self.assert_op() || self.assert_not_op()

            ast.push(self.start_group? ? self.parse_group() : self.pop())

            if ast.last.is_a?(String) && !UNARY_OPERATORS.include?(ast.last.downcase) || ast.last.is_a?(Array)
              expect_op ^= true
            end
          end

          self.to_rpn(ast)
        end

        def parse_group
          # pop '(' token
          self.pop()

          ast = self.parse_expr()

          # pop ')' token
          self.assert_close() && self.pop()

          ast
        end

        # Split input into tokens. Returns an array of strings.
        #
        # +input+:: String to parse.
        #
        def lex(input)
          input = input.clone
          tokens = []

          until input.empty? do
            input.sub!(NEXT_TOKEN, '') || fail(Scimitar::FilterError, "Can't lex input here '#{input}'")

            tokens.push($1)
          end
          tokens
        end

        # Turn parsed tokens into an RPN stack
        #
        # See also http://en.wikipedia.org/wiki/Shunting_yard_algorithm
        #
        # +ast+:: Array of parsed tokens (see e.g. #parse_expr).
        #
        def to_rpn(ast)
          out = []
          ops = []

          out.push(ast.shift) unless ast.empty?

          until ast.empty? do
            op = ast.shift
            precedence = OPERATORS[op&.downcase] || fail(Scimitar::FilterError, "Unknown operator '#{op}'")

            until ops.empty? do
              break if precedence > OPERATORS[ops.first&.downcase]
              out.push(ops.shift)
            end

            ops.unshift(op)
            out.push(ast.shift) unless UNARY_OPERATORS.include?(op&.downcase)
          end
          (out.concat(ops)).flatten
        end

        # Transform RPN stack into a tree structure. A new copy of the tree is
        # returned each time, so you can mutate the result if need be.
        #
        def get_tree
          tree = []
          unless @stack.empty?
            op = tree[0] = @stack.pop()
            tree[1] = OPERATORS[@stack.last&.downcase] ? self.get_tree() : @stack.pop()

            unless UNARY_OPERATORS.include?(op&.downcase)
              tree.insert(1, (OPERATORS[@stack.last&.downcase] ? self.get_tree() : @stack.pop()))
            end
          end
          tree
        end

        # =====================================================================
        # Flattening
        # =====================================================================

        # A depressingly heavyweight method that attempts to partly rationalise
        # some of the simpler cases of filters-in-filters by realising that the
        # expression can be done in two ways.
        #
        # https://tools.ietf.org/html/rfc7644#page-23 includes these examples:
        #
        #     filter=userType eq "Employee" and (emails.type eq "work")
        #     filter=userType eq "Employee" and emails[type eq "work" and value co "@example.com"]
        #
        # Ignoring the extra 'and', we can see that using either a nested
        # filter-like path *or* the dotted notation are equivalent here. So, if
        # we were to step along the string looking for an unescaped "[" at the
        # start of an inner filter, we could extract attributes therein and use
        # the part before the "[" as a prefix - "emails[type" to "emails.type",
        # with similar substitutions therein.
        #
        # Further, via https://github.com/pond/scimitar/issues/115 we see
        # a requirement to support a broken form emitted by Microsoft; that is
        # supported herein.
        #
        # This method tries to flatten things thus. It throws exceptions if any
        # problems arise at all. Some limitations:
        #
        # * Inner filters with further complex filters inside will not work.
        # * Spaces immediately after an opening "[" will break the flattener.
        # * 'not' can only be used in the context of 'and not' / 'or not'; it
        #   isn't supported stand-alone at the start of expressions (e.g.
        #   'not userType eq "Employee')
        #
        # Examples:
        #
        #     <- userType eq "Employee" and emails[type eq "work" and value co "@example.com"]
        #     => userType eq "Employee" and emails.type eq "work" and emails.value co "@example.com"
        #
        #     <- emails[type eq "work" and value co "@example.com"] or ims[type eq "xmpp" and value co "@foo.com"]
        #     => emails.type eq "work" and emails.value co "@example.com" or ims.type eq "xmpp" and ims.value co "@foo.com"
        #
        #     <- userType eq "Employee" or userName pr and emails[type eq "with spaces" and value co "@example.com"]
        #     => userType eq "Employee" or userName pr and emails.type eq "with spaces" and emails.value co "@example.com"
        #
        #     <- userType ne "Employee" and not (emails[value co "example.com" or (value co "example.org")]) and userName="foo"
        #     => userType ne "Employee" and not (emails.value co "example.com" or (emails.value co "example.org")) and userName="foo"
        #
        #     <- emails[type eq "work"].value eq "foo@bar.com"   (Microsoft workaround)
        #     => emails.type eq "work" and emails.value eq "foo@bar.com"
        #
        # +filter+:: Input filter string. Returns a possibly modified String,
        #            with the hopefully equivalent but flattened filter inside.
        #
        def flatten_filter(filter)
          rewritten                 = []
          components                = filter.gsub(/\s+\]/, ']').split(' ')
          expecting_attribute       = true
          expecting_closing_bracket = false
          attribute_prefix          = nil
          expecting_operator        = false
          expecting_value           = false
          expecting_closing_quote   = false
          expecting_logic_word      = false
          skip_next_component       = false

          components.each.with_index do | component, index |
            if skip_next_component
              skip_next_component = false
              next
            end

            downcased = component.downcase.strip

            if expecting_attribute
              if downcased.match?(/[^\\]\[/) # Not backslash then literal '['
                attribute_prefix       = component.match(/(.*?[^\\])\[/   )[1] # Everything before no-backslash-then-literal (unescaped) '['
                first_attribute_inside = component.match(    /[^\\]\[(.*)/)[1] # Everything  after no-backslash-then-literal (unescaped) '['
                opening_paren          = '(' if attribute_prefix.start_with?('(')
                rewritten << "#{opening_paren}#{apply_attribute_prefix(attribute_prefix, first_attribute_inside)}"
                expecting_closing_bracket = true
              else # No inner filter component being started, but might be inside one with a prefix set
                rewritten << apply_attribute_prefix(attribute_prefix, component)
              end
              expecting_attribute = false
              expecting_operator  = true

            elsif expecting_operator
              rewritten << component
              if BINARY_OPERATORS.include?(downcased)
                expecting_operator = false
                expecting_value    = true
              elsif UNARY_OPERATORS.include?(downcased)
                expecting_operator   = false
                expecting_logic_word = true
              else
                raise 'Expected operator'
              end

            elsif expecting_value
              matches = downcased.match(/([^\\])\](.*)/) # Contains no-backslash-then-literal (unescaped) ']'; also capture anything after
              unless matches.nil? # Contains no-backslash-then-literal (unescaped) ']'
                character_before_closing_bracket = matches[1]
                characters_after_closing_bracket = matches[2]

                # https://github.com/pond/scimitar/issues/115 - detect
                # bad Microsoft filters. After the closing bracket, we expect a
                # dot then valid attribute characters and at least one white
                # space character and filter operator, but we split on spaces,
                # so the next item in the components array must be a recognised
                # operator for the special case code to kick in.
                #
                # If this all works out, we transform this section of the
                # filter string into a local dotted form, reconstruct the
                # overall filter with this substitution, and call back to this
                # method with that modified filter, returning the result.
                #
                # So - NOTE RECURSION AND EARLY EXIT POSSIBILITY HEREIN.
                #
                if (
                  !attribute_prefix.nil? &&
                  OPERATORS.key?(components[index + 1]&.downcase) &&
                  characters_after_closing_bracket.match?(/^\.#{ATTRNAME}$/)
                )
                  # E.g. '"work"' and '.value' from input '"work"].value'
                  #
                  component_matches           = component.match(/^(.*?[^\\])\](.*)/)
                  part_before_closing_bracket = component_matches[1]
                  part_after_closing_bracket  = component_matches[2]

                  # Produces e.g. '"work"] and emails.value'
                  #
                  dotted_version = "#{part_before_closing_bracket}] and #{attribute_prefix}#{part_after_closing_bracket}"

                  # Overwrite the components array entry with this new version.
                  #
                  components[index] = dotted_version

                  # Join it back again as a reconstructed valid filter string.
                  #
                  hopefully_valid_filter = components.join(' ')

                  # NOTE EARLY EXIT
                  #
                  return flatten_filter(hopefully_valid_filter)
                end

                component.gsub!(/[^\\]\]/, character_before_closing_bracket)

                if expecting_closing_bracket
                  attribute_prefix          = nil
                  expecting_closing_bracket = false
                else
                  raise 'Unexpected closing "]"'
                end
              end

              rewritten << component

              if downcased.start_with?('"')
                expecting_closing_quote = true
                downcased = downcased[1..-1] # Strip off opening '"' to avoid false-positive on 'contains closing quote' check below
              elsif !expecting_closing_quote # If not expecting a closing quote, then the component must be the entire no-spaces value
                expecting_value      = false
                expecting_logic_word = true
              end

              if expecting_closing_quote
                if downcased.match?(/[^\\]\"/) # Contains no-backslash-then-literal (unescaped) '"'
                  expecting_closing_quote = false
                  expecting_value         = false
                  expecting_logic_word    = true
                end
              end

            elsif expecting_logic_word
              if downcased == 'and' || downcased == 'or'
                rewritten << component
                next_downcased_component = components[index + 1].downcase.strip
                if next_downcased_component == 'not' # Special case "and not" / "or not"
                  skip_next_component = true
                  rewritten << 'not'
                end
                expecting_logic_word = false
                expecting_attribute  = true
              else
                raise 'Expected "and" or "or"'
              end
            end
          end

          # Handle schema IDs.
          #
          # Scimitar currently has a limitation where it strips schema IDs in
          # things like PATCH operation path traversal; see
          # https://github.com/pond/scimitar/issues/130. At least that
          # makes things easy here; use the same approach and strip them out!
          #
          # We don't know which resource is being queried at this layer of the
          # software. If Scimitar were to bump major version, then an extension
          # to QueryParser#parse to include this information would be wise. In
          # the mean time, all we can do is enumerate all extension schema
          # subclasses with IDs and remove those IDs if present in the filter.
          #
          # Inbound unrecognised schema IDs will be left behind. If the client
          # Scimitar application hasn't defined requested schemas, it would
          # very likely never have been able to handle the filter either way.
          #
          rewritten_joined = rewritten.join(' ')
          if rewritten_joined.include?(':')

            # README.md notes that extensions *must* be a subclass of
            # Scimitar::Schema::Base and must define IDs.
            #
            known_schema_ids = Scimitar::Schema::Base.subclasses.map { |s| s.new.id }.compact
            known_schema_ids.each do | schema_id |
              rewritten_joined.gsub!(/#{schema_id}[\:\.]/, '')
            end
          end

          return rewritten_joined
        end

        # Service method to DRY up #flatten_filter a little. Applies a prefix
        # to a component, but is careful with opening parentheses.
        #
        # +attribute_prefix+:: Prefix from before a "[", which may include an
        #                      opening "(" itself.
        #
        # +component+::        Component attribute to receive the prefix, which
        #                      may also include an opening "(" itself.
        #
        # The result will be "prefix.component", with a "(" at the start if
        # the *component* had an opening paren. If the prefix includes one, the
        # caller must deal with it as only the caller knows if this application
        # of prefix is being done for the first attribute within an inner
        # filter (in which case a wrapping opening paren should be included) or
        # subsequent attributes inside that filter (in which case the original
        # wrapping opening paren should not be repeated).
        #
        def apply_attribute_prefix(attribute_prefix, component)
          if attribute_prefix.nil?
            component
          else
            attribute_prefix = attribute_prefix[1..-1] if attribute_prefix.start_with?('(')
            if component.start_with?('(')
              "(#{attribute_prefix}.#{component[1..-1]}"
            else
              "#{attribute_prefix}.#{component}"
            end
          end
        end

        # =====================================================================
        # Token sugar methods
        # =====================================================================

        def peek
          @tokens.first()
        end

        def pop
          @tokens.shift()
        end

        def eos?
          @tokens.empty?
        end

        def start_group?
          self.peek() == '('
        end

        def peek_operator
          !self.eos? && self.peek().match(IS_OPERATOR)
        end

        # =====================================================================
        # Error handling
        # =====================================================================

        def parse_error(msg)
          raise Scimitar::FilterError.new("#{sprintf(msg, *@tokens, 'EOS')}.\nInput: '#{@input}'\n")
        end

        def assert_op
          return true if self.peek_operator()
          self.parse_error("Unexpected token '%s'. Expected operator")
        end

        def assert_not_op
          return true unless self.peek_operator()
          self.parse_error("Unexpected operator '%s'")
        end

        def assert_close
          return true if self.peek() == ')'
          self.parse_error("Unexpected token '%s'. Expected ')'")
        end

        def assert_eos
          return true if self.eos?
          self.parse_error("Unexpected token '%s'. Expected EOS")
        end

        # =====================================================================
        # ActiveRecord query support
        # =====================================================================

        # Recursively process an expression tree. Calls itself with nested tree
        # fragments. Each inner expression fragment calculates on the given
        # base scope, with aggregation at each level into a wider query using
        # AND or OR depending on the expression tree contents.
        #
        # +base_scope+::      Base scope (ActiveRecord::Relation, e.g. User.all
        #                     - never changes during recursion).
        #
        # +expression_tree+:: Top-level expression tree or fragments inside if
        #                     self-calling recursively.
        #
        def to_activerecord_query_backend(base_scope:, expression_tree:)
          combining_method = :and
          combining_yet    = false
          query            = base_scope

          first_item = expression_tree.first
          first_item = first_item.downcase if first_item.is_a?(String)

          if first_item == 'or'
            combining_method = :or
            expression_tree.shift()
          elsif first_item == 'and'
            expression_tree.shift()
          elsif ! first_item.is_a?(Array) # Simple query; entire tree is just presence tuple or expression triple
            raise Scimitar::FilterError unless expression_tree.size == 2 || expression_tree.size == 3
            return apply_scim_filter( # NOTE EARLY EXIT
              base_scope:     query,
              scim_attribute: expression_tree[1],
              scim_operator:  expression_tree[0]&.downcase,
              scim_parameter: expression_tree[2],
              case_sensitive: false
            )
          end

          expression_tree.each do | entry |
            raise Scimitar::FilterError unless entry.is_a?(Array)

            first_sub_item = entry.first
            first_sub_item = first_sub_item.downcase if first_sub_item.is_a?(String)
            nested         = first_sub_item.is_a?(Array) || first_sub_item == 'and' || first_sub_item == 'or'

            if nested
              query_component = to_activerecord_query_backend(
                base_scope:      base_scope,
                expression_tree: entry
              )
            else
              raise Scimitar::FilterError unless entry.size == 2 || entry.size == 3
              query_component = apply_scim_filter(
                base_scope:     base_scope,
                scim_attribute: entry[1],
                scim_operator:  entry[0]&.downcase,
                scim_parameter: entry[2],
                case_sensitive: false
              )
            end

            # ActiveRecord quirk: User.and(User.where...) produces useful SQL
            # but User.or(User.where...) just ignores everything inside 'or';
            # so, make sure we only use a combination method once actually
            # combining things - not for the very first query component.
            #
            if combining_yet
              query = query.send(combining_method, query_component)
            else
              query = query.and(query_component)
              combining_yet = true
            end
          end

          return query
        end

        # =====================================================================
        # Mongoid query support
        # =====================================================================

        # Recursively processes an expression tree. Calls itself with nested tree
        # fragments. Handles three cases:
        # 1. Combination operators (and/or) - converted to { "operator" => [condition1, condition2]}
        # 2. Simple comparison operators (eq, ne, lt, le, gt, ge) - converted to { column => { operator => value } }
        # 3. Complex comparison operators (pr, sw, ew, co) - converted to { column => regex }
        # or { column => { "$exists" => true, "$ne" => nil } }
        def tree_node_to_mongoid_query(node)
          op = node[0]

          if MONGO_COMBINATION_OPERATORS.key?(op)
            components = node.drop(1)
            # Parser works in a way that max number of arguments is 2 here
            # In case the request is A && B && C, it will be parsed as A && (B && C)
            raise "Combination operators expect two arguments: #{node}" unless components.size == 2

            {
              MONGO_COMBINATION_OPERATORS[op] => [
                tree_node_to_mongoid_query(components[0]),
                tree_node_to_mongoid_query(components[1])
              ]
            }
          elsif MONGO_SIMPLE_COMPARISON_OPERATORS.key?(op) || MONGO_COMPLEX_COMPARISON_OPERATORS.include?(op)
            mongoid_comparison_operation(node)
          else
            raise "Unsupported operator: #{op}"
          end
        end

        def mongoid_comparison_operation(node)
          raise "No arrays allowed in comparison subnodes: #{node}" if node.any? { |subnode| subnode.is_a?(Array) }

          column = attribute_map.dig(node[1], :column)
          raise "Unsupported field: #{node[1]}" unless column

          value = node[2]&.delete("\"")

          if MONGO_SIMPLE_COMPARISON_OPERATORS.key?(node[0])
            mongoid_simple_comparison_operation(MONGO_SIMPLE_COMPARISON_OPERATORS[node[0]], column, value)
          elsif MONGO_COMPLEX_COMPARISON_OPERATORS.include?(node[0])
            mongoid_complex_comparison_operation(node[0], column, value)
          end
        end

        def mongoid_simple_comparison_operation(op, column, value)
          { column => { op => value } }
        end

        def mongoid_complex_comparison_operation(op, column, value)
          case op
          when "pr"
            { column => { "$exists" => true, "$ne" => nil } }
          when "sw"
            { column => /^#{Regexp.escape(value)}/ }
          when "ew"
            { column => /#{Regexp.escape(value)}$/ }
          when "co"
            { column => /#{Regexp.escape(value)}/ }
          end
        end

        # Apply a filter to a given base scope. Mandatory named parameters:
        #
        # +base_scope+::     Base scope (ActiveRecord::Relation, e.g. User.all)
        # +scim_attribute+:: SCIM domain attribute, e.g. 'familyName'
        # +scim_operator+::  SCIM operator, e.g. 'eq', 'co', 'pr'
        # +scim_parameter+:: Parameter to match, or +nil+ for operator 'pr'
        # +case_sensitive+:: Boolean; see notes below on case sensitivity.
        #
        # Case sensitivity in databases is tricky. If you wanted case sensitive
        # behaviour then it might need configuration in your engine. Internally
        # Scimitar uses AREL operations to try and get appropriate behaviour so
        # if your database adapter is doing the right thing there should be the
        # right outcome - even so, check your database adapter documentation to
        # be sure.
        #
        def apply_scim_filter(
          base_scope:,
          scim_attribute:,
          scim_operator:,
          scim_parameter:,
          case_sensitive:
        )
          scim_operator  = scim_operator.downcase
          query          = base_scope
          arel_table     = base_scope.model.arel_table
          column_names   = self.activerecord_columns(scim_attribute)
          value          = self.activerecord_parameter(scim_parameter)
          value_for_like = self.sql_modified_value(scim_operator, value)
          arel_columns   = column_names.map do |column|
            if base_scope.model.column_names.include?(column.to_s)
              arel_table[column]
            elsif column.is_a?(Arel::Attribute)
              column
            end
          end

          raise Scimitar::FilterError unless arel_columns.all?

          unless case_sensitive
            lc_scim_attribute = scim_attribute.downcase()

            case_sensitive = (
              lc_scim_attribute == 'id' ||
              lc_scim_attribute == 'externalid' ||
              lc_scim_attribute.start_with?('meta.')
            )
          end

          arel_columns.each.with_index do | arel_column, index |
            arel_operation = case scim_operator
              when 'eq'
                if case_sensitive
                  arel_column.eq(value)
                else
                  arel_column.matches(value_for_like, nil, false) # false -> case insensitive
                end
              when 'ne'
                if case_sensitive
                  arel_column.not_eq(value)
                else
                  arel_column.does_not_match(value_for_like, nil, false) # false -> case insensitive
                end
              when 'gt'
                arel_column.gt(value)
              when 'ge'
                arel_column.gteq(value)
              when 'lt'
                arel_column.lt(value)
              when 'le'
                arel_column.lteq(value)
              when 'co', 'sw', 'ew'
                arel_column.matches(value_for_like, nil, case_sensitive)
              when 'pr'
                arel_column.relation.grouping(arel_column.not_eq_all(['', nil]))
              else
                raise Scimitar::FilterError.new("Unsupported operator: '#{scim_operator}'")
            end

            if index == 0
              query = base_scope.where(arel_operation)
            else
              query = query.or(base_scope.where(arel_operation))
            end
          end

          return query
        end

        # Returns the mapped-to-your-domain column name(s) that a filter string
        # is operating upon, in an Array. If empty, the attribute is to be
        # ignored. Raises an exception if entirely unmapped (thus unsupported).
        #
        # Note plural - the return value is always an array any of which should
        # be used (implicit 'OR').
        #
        # +scim_attribute+:: SCIM attribute from a filter string.
        #
        def activerecord_columns(scim_attribute)
          raise Scimitar::FilterError.new("No scim_attribute provided") if scim_attribute.blank?

          mapped_attribute = self.attribute_map()[scim_attribute]
          raise Scimitar::FilterError.new("Unable to find domain attribute from SCIM attribute: '#{scim_attribute}'") if mapped_attribute.blank?

          if mapped_attribute[:ignore]
            return []
          elsif mapped_attribute[:column]
            return [mapped_attribute[:column]]
          elsif mapped_attribute[:columns]
            return mapped_attribute[:columns]
          else
            raise "Malformed scim_queryable_attributes entry for #{scim_attribute.inspect}"
          end
        end

        # Return the parameter that you're looking for, from a filter string.
        # This might be blank, e.g. for "pr" (presence), but is never +nil+. Use
        # this to construct your storage-system-specific search string but be
        # sure to escape it, where necessary, for any special characters (e.g.
        # to prevent SQL injection attacks or accidentally-wildcarded searches).
        #
        # +scim_operator+:: SCIM parameter from a filter string. Even if given
        #                   +nil+ here, would always return an empty string;
        #                   all blank inputs yield this.
        #
        def activerecord_parameter(scim_parameter)
          if scim_parameter.blank?
            return ''
          elsif scim_parameter.start_with?('"') && scim_parameter.end_with?('"')
            return scim_parameter[1..-2]
          else
            return scim_parameter
          end
        end

        # Pass a SCIM operation and a value from e.g. #activerecord_parameter.
        # Returns a safe-for-"LIKE" string with potential internal wildcards
        # escaped, along with actual wildcards added for "co" (contains), "sw"
        # (starts with) or "ew" (ends with) operators.
        #
        # Escapes values for "eq" and "ne" operations on assumption of a LIKE
        # style query by the caller - the caller should use the modified value
        # only if that is indeed their intended use case. If just using e.g.
        # SQL "=" or "!=", use the #activerecord_parameter (or other original
        # 'raw' value) instead.
        #
        # For other operators, just returns the given value directly.
        #
        # +scim_operator+:: The SCIM operator, lower case.
        # +value+::         Parameter (value) to potentially escape or modify.
        #
        def sql_modified_value(scim_operator, value)
          safe_for_LIKE_value  = ActiveRecord::Base.sanitize_sql_like(value) if value.present?

          case scim_operator
            when 'eq', 'ne'
              safe_for_LIKE_value
            when 'co'
              "%#{safe_for_LIKE_value}%"
            when 'sw'
              "#{safe_for_LIKE_value}%"
            when 'ew'
              "%#{safe_for_LIKE_value}"
            else
              value
          end
        end

    end
  end
end
