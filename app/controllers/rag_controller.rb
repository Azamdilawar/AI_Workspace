class RagController < ApplicationController
  def show
    @question = params[:question]
    @result = nil

    if @question.present?
      service = Rag::RagService.new
      @result = service.search(@question)
    end
  end
end
