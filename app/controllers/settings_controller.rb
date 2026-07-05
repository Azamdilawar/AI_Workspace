class SettingsController < ApplicationController
  def show
    @config = AI.config
  end
end
