class Message < ApplicationRecord
  belongs_to :conversation, touch: true, inverse_of: :messages

  validates :role, presence: true, inclusion: { in: %w[user assistant system] }
  validates :content, presence: true
end
