module Dru
  module ZodTokenizer
    class << self
      def tokenizer
        @tokenizer ||= Tokenizers::Tokenizer.from_file(File.join(File.expand_path(__dir__), "tokenizer-zod.json"))
      end

      def tokenize_str(str:)
        raise DruError if str.nil? && str.empty?
        tokenizer.encode str
      end
    end
  end
end
