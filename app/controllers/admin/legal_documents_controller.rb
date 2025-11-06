class Admin::LegalDocumentsController < Admin::BaseController
  before_action :set_legal_document, only: [ :edit, :update, :destroy ]

  def index
    @legal_documents = LegalDocument.ordered.page(params[:page]).per(20)
  end

  def new
    @legal_document = LegalDocument.new
  end

  def create
    @legal_document = LegalDocument.new(legal_document_params)

    if @legal_document.save
      redirect_to admin_legal_documents_path, notice: "Legal document created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @legal_document.update(legal_document_params)
      redirect_to admin_legal_documents_path, notice: "Legal document updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @legal_document.destroy
    redirect_to admin_legal_documents_path, notice: "Legal document deleted successfully."
  end

  private

  def set_legal_document
    @legal_document = LegalDocument.find(params[:id])
  end

  def legal_document_params
    params.require(:legal_document).permit(
      :title, :slug, :content, :document_type, :active, :version, :effective_date, :product_id
    )
  end
end
