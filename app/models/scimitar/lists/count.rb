module Scimitar
  module Lists
    class Count
      include ActiveModel::Model

      attr_accessor :limit, :start_index, :total
      attr_reader   :offset

      def initialize(*args)
        @limit       = 100
        @start_index = 1

        super(*args)
      end

      # Set a limit (page size) value.
      #
      # +value+:: Integer value held in a String. Must be >= 0.
      #
      # Per SCIM 2.0 RFC 7644 Section 3.4.2.4: "A value of '0' indicates that
      # no resource results are to be returned except for 'totalResults'."
      #
      # Raises exceptions if given non-numeric or negative input.
      #
      def limit=(value)
        value = value&.to_s
        return if value.blank? # NOTE EARLY EXIT

        validate_numericality(value)
        input = value.to_i
        raise if input < 0
        @limit = input
      end

      # Set a start index (offset) value. Values start at 1. See also #offset.
      #
      # +value+:: Integer value held in a String. Must be >= 1.
      #
      # Raises exceptions if given non-numeric or negative input. Corrects an
      # input value of zero to 1.
      #
      def start_index=(value)
        value = value&.to_s
        return if value.blank? # NOTE EARLY EXIT

        validate_numericality(value)
        input = value.to_i
        input = 1 if input < 1
        @start_index = input
      end

      # Read-only accessor that represents #start_index as a zero-based offset,
      # rather than 1-based. This is useful for most storage engines.
      #
      def offset
        start_index - 1
      end

    private

      def validate_numericality(input)
        raise unless input.match?(/\A\d+\z/)
      end

    end
  end
end
