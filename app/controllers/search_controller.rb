class SearchController < ApplicationController
  def show
    @query = params[:query]
    @results = []

    if @query.present?
      service = KnowledgeBase::SemanticSearchService.new
      @results = service.search(@query)
    end
  end
end
