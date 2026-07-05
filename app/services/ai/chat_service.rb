module AI
  class ChatService
    def initialize(client: nil)
      @client = client || AI::Client.new
    end

    def call(prompt, model: nil, temperature: nil, max_tokens: nil, **options)
      messages = build_messages(prompt)

      @client.chat(
        messages,
        model: model,
        temperature: temperature,
        max_tokens: max_tokens,
        **options
      )
    end

    def chat_with_history(conversation_messages, model: nil, temperature: nil, max_tokens: nil, **options)
      messages = conversation_messages.map { |m| { role: m.role, content: m.content } }

      @client.chat(
        messages,
        model: model,
        temperature: temperature,
        max_tokens: max_tokens,
        **options
      )
    end

    def chat_with_history_streaming(conversation_messages, model: nil, temperature: nil, max_tokens: nil, **options, &block)
      messages = conversation_messages.map { |m| { role: m.role, content: m.content } }

      @client.stream_chat(
        messages,
        model: model,
        temperature: temperature,
        max_tokens: max_tokens,
        **options,
        &block
      )
    end

    private

    def build_messages(prompt)
      [{ role: "user", content: prompt }]
    end
  end
end
