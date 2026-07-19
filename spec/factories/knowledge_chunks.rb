FactoryBot.define do
  factory :knowledge_chunk do
    knowledge { nil }
    content { "MyText" }
    position { 1 }
    metadata { "" }
  end
end
