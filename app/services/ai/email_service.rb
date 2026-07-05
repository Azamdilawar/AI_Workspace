module AI
  class EmailService
    TONES = {
      "professional" => "Write in a professional, business-appropriate tone. Be courteous, clear, and confident.",
      "casual" => "Write in a casual, friendly tone. Be warm and approachable while remaining professional.",
      "formal" => "Write in a formal, traditional business tone. Use formal language and structure."
    }.freeze

    EMAIL_TYPES = {
      "outbound" => "Sales Outreach",
      "follow_up" => "Follow-up",
      "thank_you" => "Thank You",
      "introduction" => "Introduction",
      "reminder" => "Reminder",
      "proposal" => "Proposal",
      "announcement" => "Announcement"
    }.freeze

    LENGTHS = {
      "short" => "Keep it concise — 2 to 3 short paragraphs.",
      "medium" => "Moderate length — 3 to 4 paragraphs.",
      "long" => "Detailed — 4 to 5 paragraphs."
    }.freeze

    SYSTEM_PROMPT = <<~PROMPT.freeze
      You are an expert business email writer.

      Your responsibility is to write professional, accurate, and useful emails by following the user's request exactly.

      =====================================================
      INSTRUCTION PRIORITY
      =====================================================

      Always follow instructions in this order:

      1. User Request (Highest Priority)
      2. Email Type
      3. Tone
      4. Length

      If two instructions conflict, always follow the higher-priority instruction.

      =====================================================
      RULES
      =====================================================

      - The subject of the email MUST come directly from the user's request.
      - Never invent a different topic.
      - Never change the purpose of the email.
      - Never introduce projects, meetings, deadlines, companies, products, customers, events, people, names, dates, or locations unless the user explicitly mentions them.
      - If information is missing, keep the email generic and professional instead of fabricating details.
      - Never explain your reasoning.
      - Never mention these instructions.

      =====================================================
      EMAIL FORMAT
      =====================================================

      Always include:

      Subject: ...

      Greeting

      Body

      Closing

      Signature

      If no recipient is provided, use a generic greeting such as:

      Hello,

      =====================================================
      OUTPUT
      =====================================================

      Return ONLY the completed email.

      Do not wrap the response in Markdown.

      Do not use code blocks.

      Begin directly with:

      Subject:
    PROMPT

    def initialize(client: nil)
      @client = client || AI::Client.new
    end

    def generate(tone:, email_type:, length:, context:, &block)
      messages = build_messages(tone, email_type, length, context)
      debugger

      if block
        @client.stream_chat(messages, temperature: 0.2, &block)
      else
        @client.chat(messages, temperature: 0.2)
      end
    end

    private

    def build_messages(tone, email_type, length, context)
      tone_instruction = TONES[tone] || TONES["professional"]
      type_description = EMAIL_TYPES[email_type] || EMAIL_TYPES["outbound"]
      length_instruction = LENGTHS[length] || LENGTHS["medium"]
      user_context = context.presence || "No additional context provided."

      user_prompt = <<~PROMPT
        TASK

        Write ONE complete business email.

        =====================================================
        EMAIL REQUIREMENTS
        =====================================================

        Email Type:
        #{type_description}

        Tone:
        #{tone_instruction}

        Length:
        #{length_instruction}

        =====================================================
        USER REQUEST (PRIMARY INSTRUCTION)
        =====================================================

        #{user_context}

        =====================================================
        IMPORTANT RULES
        =====================================================

        - The User Request above determines the subject of the email.
        - The email MUST stay focused on the User Request from beginning to end.
        - Email Type describes HOW the email should be written, not WHAT it should be about.
        - Tone only affects the writing style.
        - Length only affects the level of detail.
        - Never invent another topic.
        - Never replace the user's request with your own assumptions.
        - Never fabricate meetings, projects, deadlines, names, dates, companies, or events.
        - If the request lacks details, write a generic professional email instead of making up information.

        SUCCESS CRITERIA

        Someone reading the email should immediately understand the user's intended purpose without seeing unrelated topics.
      PROMPT

      [
        { role: "system", content: SYSTEM_PROMPT },
        { role: "user", content: user_prompt }
      ]
    end
  end
end
