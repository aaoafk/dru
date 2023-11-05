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

      def ignore_token?(token)
        # Check each thing above
        $logger.info token
        if (ZOD_SYNTAX[:_SCHEMA_BLOCK_].any? { |el| el == token }) || (ZOD_SYNTAX[:_COLON_].any? { |el| el == token})
          return false
        end
        return true
      end

      def squash_stack(stack)
        if stack.size == 0
          return {}
        else
          tok = stack.shift
          if tok.match?(/schema/i) || tok.match?(/object/i)
            {tok.to_s => squash_stack(stack)}
          elsif ZOD_SYNTAX[:_SCHEMA_BLOCK_].any? { |el| tok.match?(/"#{el}/i) }
            [tok.to_s => squash_stack(stack)]
          else # Attribute
            { tok.to_s => "val" }.merge(squash_stack(stack))
          end
        end
      end

      def call
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
              # TODO: Extra bookkeeping here to store the result of a squash. Then we can look up later if it's referenced in later expression
              squashed_schemas << squash_stack(conversion_stack)
              $logger.warn "Conversion Stack size: #{conversion_stack.size}"
              conversion_stack.push(token) # After we squash we lose the current parent unless we push it now
            end
          end
          break
        end
      end
    end
  end
end
