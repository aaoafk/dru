# frozen_string_literal: true

require 'minitest'
require 'test_helper'

# Include everything in lib directory
require File.join(File.expand_path("/home/sf/Development/dru/"), "lib", "dru.rb")
Dir.glob(File.join(File.expand_path("/home/sf/Development/dru/"), "lib", "dru", "utils", "*.rb")).each do |file|
  require "#{file}"
end

class Stack
  include Dru::Stackable
end

class StackableTest < Minitest::Test

  def setup
    @stack = Stack.new
  end

  def stack
    @stack
  end

  def test_push
    assert(stack.size == 0)
    stack.push "data"
    assert(stack.size == 1)
  end

  def test_pop_empty
    assert_nil stack.pop
  end

  def test_peek_empty
    assert_nil stack.peek
  end

  def test_peek_with_data
    old_size = stack.size
    stack.push "data"
    element_peeked = stack.peek
    assert_equal old_size + 1, stack.size
    refute_nil element_peeked
  end

  def test_peek_first_without_data
    stack.push 1
    stack.push 2
    assert_equal stack.peek_first, 1
  end

  def test_peek_first_with_data
    assert_nil stack.peek
  end

  def test_clear
    stack.clear
    assert(stack.size == 0)
  end
end

class ParserTest < Minitest::Test

  # def test_parser
  #   Dru.configure do |config|
  #     config.zod_schema_directories = Dir.glob(File.join("/home/sf/Development/nobee-saas/apps/saas/lib/shared/schemas/", "*.ts"))
  #   end
  #   Dru::Parser.parse_files
  # end

  def test_parser_only_parent
    # We need a heredoc for the schema
    schema = <<-ZODSCHEMA
    import { z } from 'zod'

    import { OptionalStringSchema } from './string-schema'

    export const AgentInformationSchema = z.object({
        firstName: OptionalStringSchema,
        lastName: OptionalStringSchema,
        phone: OptionalStringSchema,
        brokerage: OptionalStringSchema,
        email: OptionalStringSchema,
    })
    ZODSCHEMA

    # Implement as a call to the parser
    parse_result = Dru::Parser.parse_str schema

    required_keys = %w(firstName lastName phone brokerage email)
    required_keys.each do |key|
      assert parse_result["AgentInformationSchema"].key?(key), "Key #{key} is missing from the Agent Information Schema"
    end
  end

  def test_parser_many_parents
    schema = <<-ZODSCHEMA
    import { z } from 'zod'

    import { OptionalStringSchema } from './string-schema'

    export const AgentInformationSchema = z.object({
        firstName: OptionalStringSchema,
        lastName: OptionalStringSchema,
        phone: OptionalStringSchema,
        brokerage: OptionalStringSchema,
        email: OptionalStringSchema,
    })

    export type AgentInformation = z.infer<typeof AgentInformationSchema>

    const CosignerInformationSchema = z.object({
        firstName: OptionalStringSchema,
        lastName: OptionalStringSchema,
        phoneNumber: OptionalStringSchema,
        email: OptionalStringSchema,
    })

    const ApplicantInformationSchema = z.object({
        firstName: OptionalStringSchema,
        lastName: OptionalStringSchema,
        phoneNumber: OptionalStringSchema,
        occupation: OptionalStringSchema,
        email: OptionalStringSchema,
        cosigner: z.string().optional(),
    })
    ZODSCHEMA

    # Implement as a call to the parser
    parse_result = Dru::Parser.parse_str schema

    required_keys_agent_information_schema = %w(firstName lastName phone brokerage email)
    required_keys_cosigner_information_schema = %w(firstName lastName phoneNumber email)
    required_keys_agent_information_schema.each do |key|
      assert parse_result["AgentInformationSchema"].key?(key), "Key #{key} is missing from the Agent Information Schema"
    end

    required_keys_cosigner_information_schema.each do |key|
      assert parse_result["CosignerInformationSchema"].key?(key), "Key #{key} is missing from the Cosigner Information Schema"
    end
  end

  def test_parser_parent_and_reference_schema

    schema = <<-ZODSCHEMA
    import { z } from 'zod'

    import { OptionalStringSchema } from './string-schema'

    export const AgentInformationSchema = z.object({
        firstName: OptionalStringSchema,
        lastName: OptionalStringSchema,
        phone: OptionalStringSchema,
        brokerage: OptionalStringSchema,
        email: OptionalStringSchema,
    })

    export type AgentInformation = z.infer<typeof AgentInformationSchema>

    const CosignerInformationSchema = z.object({
        firstName: OptionalStringSchema,
        lastName: OptionalStringSchema,
        phoneNumber: OptionalStringSchema,
        email: OptionalStringSchema,
    })

    const ApplicantInformationSchema = z.object({
        firstName: OptionalStringSchema,
        lastName: OptionalStringSchema,
        phoneNumber: OptionalStringSchema,
        occupation: OptionalStringSchema,
        email: OptionalStringSchema,
        cosigner: CosignerInformationSchema.optional(),
    })
    ZODSCHEMA

    parse_result = Dru::Parser.parse_str schema

    required_keys_agent_information_schema = %w(firstName lastName phone brokerage email)
    required_keys_cosigner_information_schema = %w(firstName lastName phoneNumber email)
    required_keys_application_information_schema = %w(firstName lastName phoneNumber occupation email cosigner)

    required_keys_agent_information_schema.each do |key|
      assert parse_result["AgentInformationSchema"].key?(key), "Key #{key} is missing from the Agent Information Schema"
    end

    required_keys_cosigner_information_schema.each do |key|
      assert parse_result["CosignerInformationSchema"].key?(key), "Key #{key} is missing from the Cosigner Information Schema"
    end

    required_keys_application_information_schema.each do |key|
      assert parse_result["ApplicantInformationSchema"].key?(key), "Key #{key} is missing from the Applicant Information Schema"
    end

    ap "ApplicantInformationSchema: \n"
    ap parse_result["ApplicantInformationSchema"]
    required_keys_cosigner_information_schema.each do |key|
      assert parse_result["ApplicantInformationSchema"]["cosigner"].key?(key), "Key #{key} is missing from the Application Information `cosigner` schema reference"
    end
  end

  def test_parser_parent_and_extend_schema
  end

  def test_parser_parent_and_merge_schema
  end
  # def test_parser_parent_child
  #   schema = <<-ZODSCHEMA
  #   import { z } from 'zod'

  #   import { OptionalStringSchema } from './string-schema'

  #   export const TestSchema = z.object({
  #                                                    attr_1: OptionalStringSchema,
  #                                                    attr_2: OptionalStringSchema,
  #                                                    attr_3: z.object({
  #                                                       child_attr_1: true,
  #                                                   }),
  #                                                  })
  #   ZODSCHEMA

  #   # Implement as a call to the parser
  #   parse_result = Dru::Parser.parse_str schema
  #   puts "\n"
  #   ap "test_parse_parent_child:"
  #   ap parse_result
  #   refute_nil parse_result
  # end

  def test_parser_family; end

end
