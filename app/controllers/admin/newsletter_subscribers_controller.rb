class Admin::NewsletterSubscribersController < Admin::BaseController
  before_action :set_newsletter_subscriber, only: [:edit, :update, :destroy]

  def index
    @newsletter_subscribers = NewsletterSubscriber.recent.page(params[:page]).per(20)
  end

  def new
    @newsletter_subscriber = NewsletterSubscriber.new
  end

  def create
    @newsletter_subscriber = NewsletterSubscriber.new(newsletter_subscriber_params)

    if @newsletter_subscriber.save
      redirect_to admin_newsletter_subscribers_path, notice: "Subscriber added successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @newsletter_subscriber.update(newsletter_subscriber_params)
      redirect_to admin_newsletter_subscribers_path, notice: "Subscriber updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @newsletter_subscriber.destroy
    redirect_to admin_newsletter_subscribers_path, notice: "Subscriber deleted successfully."
  end

  private

  def set_newsletter_subscriber
    @newsletter_subscriber = NewsletterSubscriber.find(params[:id])
  end

  def newsletter_subscriber_params
    params.require(:newsletter_subscriber).permit(:email, :active)
  end
end
