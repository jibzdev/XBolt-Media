class Admin::WorkCardsController < ApplicationController
  layout "adminpanel"
  before_action :require_full_admin
  before_action :set_work_card, only: [:edit, :update, :destroy]

  def index
    @general_setting = GeneralSetting.first_or_initialize
    @work_cards = WorkCard.ordered
  end

  def new
    @general_setting = GeneralSetting.first_or_initialize
    @work_card = WorkCard.new(active: true)
  end

  def create
    @general_setting = GeneralSetting.first_or_initialize
    @work_card = WorkCard.new(work_card_params)

    if @work_card.save
      redirect_to admin_work_cards_path, notice: "Work card created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @general_setting = GeneralSetting.first_or_initialize
  end

  def update
    if @work_card.update(work_card_params)
      redirect_to admin_work_cards_path, notice: "Work card updated."
    else
      @general_setting = GeneralSetting.first_or_initialize
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @work_card.destroy!
    redirect_to admin_work_cards_path, notice: "Work card deleted."
  end

  private

  def set_work_card
    @work_card = WorkCard.find(params[:id])
  end

  def work_card_params
    params.require(:work_card).permit(:name, :domain_url, :image_url, :description, :active, :position)
      .tap do |attrs|
        if params[:work_card].is_a?(ActionController::Parameters) && params[:work_card].key?(:active)
          attrs[:active] = ActiveModel::Type::Boolean.new.cast(params[:work_card][:active])
        end
      end
  end
end
