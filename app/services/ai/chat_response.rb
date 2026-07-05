module AI
  class ChatResponse
    attr_reader :content, :model, :usage

    def initialize(content:, model:, usage: {})
      @content = content
      @model = model
      @usage = usage
    end

    def success?
      true
    end
  end
end
