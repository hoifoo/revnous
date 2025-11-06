require 'rails_helper'

RSpec.describe 'Admin Resource Deletion', type: :request do
  let(:admin_user) { create(:user, :admin) }
  let(:regular_user) { create(:user) }

  describe 'Notice deletion' do
    let!(:notice) { create(:notice) }

    context 'when user is an admin' do
      before { sign_in admin_user }

      it 'deletes the notice' do
        expect {
          delete admin_notice_path(notice)
        }.to change(Notice, :count).by(-1)
      end

      it 'redirects to notices index' do
        delete admin_notice_path(notice)
        expect(response).to redirect_to(admin_notices_path)
      end

      it 'shows success message' do
        delete admin_notice_path(notice)
        follow_redirect!
        expect(response.body).to include('Notice deleted successfully')
      end
    end

    context 'when user is not an admin' do
      before { sign_in regular_user }

      it 'does not delete the notice' do
        expect {
          delete admin_notice_path(notice)
        }.not_to change(Notice, :count)
      end

      it 'redirects to root path' do
        delete admin_notice_path(notice)
        expect(response).to redirect_to(root_path)
      end

      it 'shows access denied message' do
        delete admin_notice_path(notice)
        follow_redirect!
        expect(response.body).to include('Access denied')
      end
    end

    context 'when user is not authenticated' do
      it 'does not delete the notice' do
        expect {
          delete admin_notice_path(notice)
        }.not_to change(Notice, :count)
      end

      it 'redirects to sign in page' do
        delete admin_notice_path(notice)
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'Blog deletion' do
    let!(:blog) { create(:blog) }

    context 'when user is an admin' do
      before { sign_in admin_user }

      it 'deletes the blog post' do
        expect {
          delete admin_blog_path(blog)
        }.to change(Blog, :count).by(-1)
      end

      it 'redirects to blogs index' do
        delete admin_blog_path(blog)
        expect(response).to redirect_to(admin_blogs_path)
      end

      it 'shows success message' do
        delete admin_blog_path(blog)
        follow_redirect!
        expect(response.body).to include('Blog post deleted successfully')
      end
    end

    context 'when user is not an admin' do
      before { sign_in regular_user }

      it 'does not delete the blog post' do
        expect {
          delete admin_blog_path(blog)
        }.not_to change(Blog, :count)
      end

      it 'redirects to root path' do
        delete admin_blog_path(blog)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'Case Study deletion' do
    let!(:case_study) { create(:case_study) }

    context 'when user is an admin' do
      before { sign_in admin_user }

      it 'deletes the case study' do
        expect {
          delete admin_case_study_path(case_study)
        }.to change(CaseStudy, :count).by(-1)
      end

      it 'redirects to case studies index' do
        delete admin_case_study_path(case_study)
        expect(response).to redirect_to(admin_case_studies_path)
      end

      it 'shows success message' do
        delete admin_case_study_path(case_study)
        follow_redirect!
        expect(response.body).to include('Case study deleted successfully')
      end
    end

    context 'when user is not an admin' do
      before { sign_in regular_user }

      it 'does not delete the case study' do
        expect {
          delete admin_case_study_path(case_study)
        }.not_to change(CaseStudy, :count)
      end

      it 'redirects to root path' do
        delete admin_case_study_path(case_study)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'Legal Document deletion' do
    let!(:legal_document) { create(:legal_document) }

    context 'when user is an admin' do
      before { sign_in admin_user }

      it 'deletes the legal document' do
        expect {
          delete admin_legal_document_path(legal_document)
        }.to change(LegalDocument, :count).by(-1)
      end

      it 'redirects to legal documents index' do
        delete admin_legal_document_path(legal_document)
        expect(response).to redirect_to(admin_legal_documents_path)
      end

      it 'shows success message' do
        delete admin_legal_document_path(legal_document)
        follow_redirect!
        expect(response.body).to include('Legal document deleted successfully')
      end
    end

    context 'when user is not an admin' do
      before { sign_in regular_user }

      it 'does not delete the legal document' do
        expect {
          delete admin_legal_document_path(legal_document)
        }.not_to change(LegalDocument, :count)
      end

      it 'redirects to root path' do
        delete admin_legal_document_path(legal_document)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'Generic admin resource deletion' do
    before { sign_in admin_user }

    it 'can delete products' do
      product = create(:product, name: 'Test Product')
      expect {
        delete admin_product_path(product)
      }.to change(Product, :count).by(-1)
    end

    it 'can delete pricing plans' do
      product = create(:product, name: 'Test Product for Plan')
      plan = create(:pricing_plan, product: product)
      expect {
        delete admin_pricing_plan_path(plan)
      }.to change(PricingPlan, :count).by(-1)
    end

    it 'can delete partners' do
      partner = create(:partner)
      expect {
        delete admin_partner_path(partner)
      }.to change(Partner, :count).by(-1)
    end

    it 'can delete special offers' do
      special_offer = create(:special_offer)
      expect {
        delete admin_special_offer_path(special_offer)
      }.to change(SpecialOffer, :count).by(-1)
    end

    it 'can delete trusted brands' do
      trusted_brand = create(:trusted_brand)
      expect {
        delete admin_trusted_brand_path(trusted_brand)
      }.to change(TrustedBrand, :count).by(-1)
    end
  end
end
