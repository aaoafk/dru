module Dru
  module Parser
    class << self
      ZOD_SYNTAX = {
        _PRIMITIVES_: ["string", "number", "bigint", "boolean", "date", "symbol", "undefined", "null", "void", "any", "unknown", "never"],
        _STRING_VALIDATIONS_: ["max", "min", "length", "email", "url", "emoji", "uuid", "cuid", "cuid2", "ulid", "regex", "includes", "startsWith", "endsWith", "datetime", "ip"],
        _STRING_TRANSFORMATIONS_: ["trim", "toLowerCase", "toUpperCase"],
        _NUMBER_VALIDATIONS: ["gt", "gte", "lt", "lte", "int", "positive", "nonnegative", "negative", "nonpositive", "multipleOf", "finite", "safe"],
        _VALUE_STATE_: ["required"],
        _SEPERATORS_: ["(", "{", "}", ")", ".", ";"],
        _OPERATORS_: ["parse", "coerce", "shape"],
        _SCHEMA_BLOCK_: ["enum", "nativeEnum", "object", "array", "tuple"],
        _COERCE_: ["coerce"],
        _PARSE_: ["parse"],
        _LITERAL_: ["literal"],
        _OPTIONAL_: ["optional"],
        _OBJECT_: ["object"],
        _NULLABLE_: ["nullable"],
        _COLON_: [":"]
      }

      class ZodTokenStack
        include Dru::Stackable
      end

      def squashed_schemas
        @squashed_schemas ||= Hash.new
      end

      def squash_stack(stack)
        if stack.size == 0
          return Hash.new
        else
          tok = stack.shift
          if tok.match?(/schema/i) || tok.match?(/object/i)
            {tok.to_s => squash_stack(stack)}
          elsif tok.match?(/merge/i)
            # HACK: `merge` requires a lookup for previous defined schemas
          elsif ZOD_SYNTAX[:_SCHEMA_BLOCK_].any? { |el| tok.match?(/"#{el}/i) }
            [tok.to_s => squash_stack(stack)]
          else # Attribute
            { tok.to_s => "val" }.merge(squash_stack(stack))
          end
        end
      end

      # HACK: Run another time for extend?
      def parse_string str
        conversion_stack = ZodTokenStack.new
        data = ZodTokenizer.tokenize_str(str: str)
        result = {}
        data.tokens.each_with_index do |token, idx|
          peek_previous_token = (idx - 1 unless idx - 1 < 0) || 0
          peek_next_token = (idx + 1 unless idx + 1 > data.tokens.size) || 0
          if token.match?(/schema/i) && data.tokens[peek_previous_token].match?(/const/i) && conversion_stack.size == 0 # Parent Schema
            conversion_stack.push(token)
            next
          end

          if(ZOD_SYNTAX[:_SCHEMA_BLOCK_].any? { |el| el == token.match?(/"#{el}/i)}) # Child Schema
            conversion_stack.push (token)
            next
          end

          if data.tokens[peek_next_token] == ":" # Attribute
            conversion_stack.push(token)
            next
          end

          if token.match?(/schema/i) && data.tokens[peek_previous_token].match?(/const/i) && conversion_stack.size > 0 # Next Parent Schema so squash
            result = squash_stack conversion_stack

            # The first element of a conversion stack should always be the name of a schema
            squashed_schemas.fetch(conversion_stack.peek_first) { |new_schema| squashed_schemas[new_schema] = result }
            $logger.warn "Conversion Stack size: #{conversion_stack.size}"

            # After we squash the stack we lose the current parent unless we push it for processing now...
            conversion_stack.push(token) 
          end
        end
      end

      def parse_files
        squashed_schemas = {}
        conversion_stack = ZodTokenStack.new
        schema_files = Dru.config.zod_schema_directories
        schema_files.each do |file|
          $logger.info "Current file: #{file}"
          data = ZodTokenizer.tokenize_str(str: File.read(file))
          result = {}
          data.tokens.each_with_index do |token, idx|
            # next if ignore_token?(token)
            peek_previous_token = idx - 1 unless idx - 1 < 0
            peek_next_token = idx + 1 unless idx + 1 > data.tokens.size
            if token.match?(/schema/i) && data.tokens[peek_previous_token].match?(/const/i) && conversion_stack.size == 0 # Parent Schema
              conversion_stack.push(token)
              next
            end

            if(ZOD_SYNTAX[:_SCHEMA_BLOCK_].any? { |el| el == token.match?(/"#{el}/i)}) # Child Schema
              conversion_stack.push (token)
              next
            end

            if data.tokens[peek_next_token] == ":" # Attribute
              conversion_stack.push(token)
              next
            end

            if token.match?(/schema/i) && data.tokens[peek_previous_token].match?(/const/i) && conversion_stack.size > 0 # Next Parent Schema so squash
              squashed_schema = squash_stack(conversion_stack)
              squashed_schemas[squashed_schema.first.at(0)] = squashed_schema.first.at(1)
              $logger.warn "Conversion Stack size: #{conversion_stack.size}"
              conversion_stack.push(token) # After we squash we lose the current parent unless we push it now
            end
          end
          # HACK: Write the results of the file to a JSON hash
          break
        end
      end
    end
  end
end
