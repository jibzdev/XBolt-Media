class Admin::ReviewsController < ApplicationController
  layout 'adminpanel'
  before_action :require_login
  before_action -> { require_admin_area(:reviews) }
  before_action :set_review, only: [:edit, :update, :destroy]

  def index
    @general_setting = GeneralSetting.first_or_initialize
    @reviews = Review.includes(:business).order(position: :asc, created_at: :desc)
  end

  def new
    @general_setting = GeneralSetting.first_or_initialize
    @review = Review.new(rating: 5, active: true)
    @businesses = Business.order(:name)
  end

  def create
    @general_setting = GeneralSetting.first_or_initialize
    @review = Review.new(review_params)

    if @review.save
      flash[:notice] = 'Review created.'
      redirect_to admin_reviews_path
    else
      @businesses = Business.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @general_setting = GeneralSetting.first_or_initialize
    @businesses = Business.order(:name)
  end

  def update
    if @review.update(review_params)
      flash[:notice] = 'Review updated.'
      redirect_to admin_reviews_path
    else
      @general_setting = GeneralSetting.first_or_initialize
      @businesses = Business.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @review.destroy
    flash[:notice] = 'Review deleted.'
    redirect_to admin_reviews_path
  end

  private

  def set_review
    @review = Review.find(params[:id])
  end

  def review_params
    params.require(:review).permit(
      :reviewer_name, :company_name, :review_text,
      :rating, :source, :avatar_url, :business_id, :active, :position
    )
  end
end
