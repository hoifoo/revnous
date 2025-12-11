module Admin
  class SeoMetadataController < BaseController
    before_action :set_seo_metadatum, only: %i[edit update destroy]

    def index
      @seo_metadata = SeoMetadatum.all.order(:page_identifier)
    end

    def new
      @seo_metadatum = SeoMetadatum.new
    end

    def create
      @seo_metadatum = SeoMetadatum.new(seo_metadatum_params)

      if @seo_metadatum.save
        redirect_to admin_seo_metadata_path, notice: "SEO Metadata was successfully created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @seo_metadatum.update(seo_metadatum_params)
        redirect_to admin_seo_metadata_path, notice: "SEO Metadata was successfully updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @seo_metadatum.destroy
      redirect_to admin_seo_metadata_path, notice: "SEO Metadata was successfully destroyed."
    end

    private

    def set_seo_metadatum
      @seo_metadatum = SeoMetadatum.find(params[:id])
    end

    def seo_metadatum_params
      params.require(:seo_metadatum).permit(:page_identifier, :page_title, :meta_description)
    end
  end
end
