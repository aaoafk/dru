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
        _SCHEMA_BLOCK_: ["enum", "nativeEnum", "array", "tuple", "object"],
        _COERCE_: ["coerce"],
        _PARSE_: ["parse"],
        _LITERAL_: ["literal"],
        _OPTIONAL_: ["optional"],
        _OBJECT_: ["object"],
        _NULLABLE_: ["nullable"],
        _COLON_: [":"]
      }

      # HACK: Investigate cyclical objects?
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
          elsif ZOD_SYNTAX[:_SCHEMA_BLOCK_].any? { |el| tok.match?(/"#{el}/i) }
            [tok.to_s => squash_stack(stack)]
          else # Attribute
            # HACK: `merge` or `merge!` ?
            { tok.to_s => "val" }.merge(squash_stack(stack))
          end
        end
      end

      # HACK: Getting different results with the tokenizing?
      def parse_str str
        conversion_stack = ZodTokenStack.new
        data = ZodTokenizer.tokenize_str(str: str)
        result = {}
        data.tokens.each_with_index do |token, idx|
          peek_previous_token_idx = (idx - 1 unless idx - 1 < 0) || 0
          peek_next_token_idx = (idx + 1 unless idx + 1 > data.tokens.size) || 0
          if token.match?(/schema/i) && data.tokens[peek_previous_token_idx].match?(/const/i) && conversion_stack.size == 0 # Parent Schema
            conversion_stack.push(token)
            next
          end

          if token.match?(/extend/i)
            new_schema_id = data.tokens[idx-4]
            conversion_stack.push new_schema_id
            reference_schema_id = data.tokens[idx-2]
            if squashed_schemas[reference_schema_id]
              squashed_schemas[reference_schema_id].each do |k,v|
                conversion_stack.push k.to_s
              end
            end
          end

          # zod `merge` is equivalent to `A.extend(B.shape)`
          if token.match?(/merge/i)
            new_schema_id = data.tokens[idx-4]
            conversion_stack.push new_schema_id
            # Push the attributes of the previously defined schema onto the stack by accessing squashed_schemas
            extend_schema = data.tokens[idx+2]
            if squashed_schemas[extend_schema]
              squashed_schemas[extend_schema].each do |k,v|
                conversion_stack.push k.to_s
              end
            end

            # Avoid duplicate processing by blanking out the `extend_schema` just in case
            data.tokens[idx+2] = ""
            next
          end

          if(ZOD_SYNTAX[:_SCHEMA_BLOCK_].any? { |el| el == token.match?(/"#{el}/i)}) # Child Schema
            conversion_stack.push (token)
            next
          end

          if data.tokens == ":" # Attributes can refer to schemas that were previously defined
            attr_value_idx = peek_next_token_idx
            attr_value = data.tokens[attr_value_idx]
            if attr_value.match?(/schema/i) && squashed_schemas[attr_value]
              # Push attribute name
              conversion_stack.push attr_value
              squashed_schemas[attr_value].each do |k,v|
                conversion_stack.push k.to_s
              end
            end

            conversion_stack.push(data.tokens[peek_previous_token_idx])
            data.tokens[attr_value_idx] = ""
            next
          end

          if token.match?(/schema/i) && data.tokens[peek_previous_token_idx].match?(/const/i) && conversion_stack.size > 0 # Next Parent Schema so squash

            new_schema_id = conversion_stack.peek_first
            result = squash_stack conversion_stack
            # The first element of a conversion stack should always be the name of a schema
            if !squashed_schemas.key?(new_schema_id)
              squashed_schemas[new_schema_id] = result[new_schema_id]
            end

            # After we squash the stack we lose the current parent unless we push it for processing now...
            conversion_stack.push(token) 
          end
        end

        # If at this point another parent schema was never discovered so check if the conversion stack needs to be processed
        if conversion_stack.size > 0
          new_schema_id = conversion_stack.peek_first
          result = squash_stack conversion_stack
          # The first element of a conversion stack should always be the name of a schema
          if !squashed_schemas.key?(new_schema_id)
            squashed_schemas[new_schema_id] = result[new_schema_id]
          end
        end

        result.merge squashed_schemas
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
          result.merge squashed_schemas
          # HACK: Write the results of the file to a JSON hash
          break
        end
      end

      def validate_hash_structure hash
        # HACK: Validate the hash structure
      end
    end
  end
end
