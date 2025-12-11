# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_12_11_144657) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "audit_logs", force: :cascade do |t|
    t.bigint "user_id"
    t.string "action", null: false
    t.string "resource_type"
    t.integer "resource_id"
    t.text "details"
    t.string "ip_address"
    t.text "user_agent"
    t.datetime "performed_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_audit_logs_on_action"
    t.index ["performed_at"], name: "index_audit_logs_on_performed_at"
    t.index ["resource_type", "resource_id"], name: "index_audit_logs_on_resource_type_and_resource_id"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "audits", force: :cascade do |t|
    t.integer "auditable_id"
    t.string "auditable_type"
    t.integer "associated_id"
    t.string "associated_type"
    t.integer "user_id"
    t.string "user_type"
    t.string "username"
    t.string "action"
    t.text "audited_changes"
    t.integer "version", default: 0
    t.string "comment"
    t.string "remote_address"
    t.string "request_uuid"
    t.datetime "created_at"
    t.index ["associated_type", "associated_id"], name: "associated_index"
    t.index ["auditable_type", "auditable_id", "version"], name: "auditable_index"
    t.index ["created_at"], name: "index_audits_on_created_at"
    t.index ["request_uuid"], name: "index_audits_on_request_uuid"
    t.index ["user_id", "user_type"], name: "user_index"
  end

  create_table "beta_users", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.string "company"
    t.string "website"
    t.string "store_link"
    t.integer "product_id", null: false
    t.text "message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_beta_users_on_email"
    t.index ["product_id"], name: "index_beta_users_on_product_id"
  end

  create_table "blogs", force: :cascade do |t|
    t.string "title"
    t.string "author"
    t.datetime "published_at"
    t.string "category"
    t.text "excerpt"
    t.text "content"
    t.string "slug"
    t.boolean "featured"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "featured_on_home", default: false, null: false
    t.string "meta_title"
    t.text "meta_description"
    t.index ["featured_on_home"], name: "index_blogs_on_featured_on_home"
  end

  create_table "blogs_products", id: false, force: :cascade do |t|
    t.bigint "blog_id", null: false
    t.bigint "product_id", null: false
    t.index ["blog_id", "product_id"], name: "index_blogs_products_on_blog_id_and_product_id"
    t.index ["product_id", "blog_id"], name: "index_blogs_products_on_product_id_and_blog_id"
  end

  create_table "case_studies", force: :cascade do |t|
    t.string "name"
    t.string "industry"
    t.string "product_features"
    t.boolean "ad_active"
    t.string "image_url"
    t.text "description"
    t.string "conversion_rate"
    t.string "revenue_increase"
    t.text "challenge"
    t.text "solution"
    t.text "results"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "case_studies_products", id: false, force: :cascade do |t|
    t.bigint "case_study_id", null: false
    t.bigint "product_id", null: false
    t.index ["case_study_id", "product_id"], name: "index_case_studies_products_on_case_study_id_and_product_id"
    t.index ["product_id", "case_study_id"], name: "index_case_studies_products_on_product_id_and_case_study_id"
  end

  create_table "contribution_receipts", force: :cascade do |t|
    t.bigint "donation_id", null: false
    t.bigint "user_id", null: false
    t.string "receipt_number"
    t.date "issued_date"
    t.text "digital_signature"
    t.string "verification_code"
    t.boolean "is_verified"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["donation_id"], name: "index_contribution_receipts_on_donation_id"
    t.index ["user_id"], name: "index_contribution_receipts_on_user_id"
  end

  create_table "donation_reminders", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "reminder_type"
    t.date "sent_date"
    t.decimal "due_amount"
    t.string "status"
    t.date "next_reminder_date"
    t.integer "reminder_count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_donation_reminders_on_user_id"
  end

  create_table "donation_schedules", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.decimal "expected_amount"
    t.string "frequency"
    t.date "start_date"
    t.date "end_date"
    t.boolean "is_active"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_donation_schedules_on_user_id"
  end

  create_table "donations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.decimal "amount"
    t.string "donation_type"
    t.date "donation_date"
    t.string "payment_method"
    t.string "reference_number"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_donations_on_user_id"
  end

  create_table "legal_documents", force: :cascade do |t|
    t.string "title", null: false
    t.string "slug", null: false
    t.text "content"
    t.string "document_type", null: false
    t.boolean "active", default: true, null: false
    t.string "version", default: "1.0"
    t.date "effective_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "product_id"
    t.index ["active"], name: "index_legal_documents_on_active"
    t.index ["document_type"], name: "index_legal_documents_on_document_type"
    t.index ["product_id", "document_type"], name: "index_legal_docs_on_product_and_type"
    t.index ["product_id"], name: "index_legal_documents_on_product_id"
    t.index ["slug"], name: "index_legal_documents_on_slug", unique: true
  end

  create_table "membership_applications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "recruiter_id"
    t.string "status", default: "pending", null: false
    t.datetime "submitted_at"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["recruiter_id"], name: "index_membership_applications_on_recruiter_id"
    t.index ["status"], name: "index_membership_applications_on_status"
    t.index ["submitted_at"], name: "index_membership_applications_on_submitted_at"
    t.index ["user_id"], name: "index_membership_applications_on_user_id"
  end

  create_table "membership_decisions", force: :cascade do |t|
    t.bigint "membership_application_id", null: false
    t.bigint "approver_id", null: false
    t.string "decision", null: false
    t.text "reasoning", null: false
    t.datetime "decided_at"
    t.boolean "can_be_revoked", default: true
    t.datetime "revoked_at"
    t.text "revocation_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approver_id"], name: "index_membership_decisions_on_approver_id"
    t.index ["can_be_revoked"], name: "index_membership_decisions_on_can_be_revoked"
    t.index ["decided_at"], name: "index_membership_decisions_on_decided_at"
    t.index ["decision"], name: "index_membership_decisions_on_decision"
    t.index ["membership_application_id"], name: "index_membership_decisions_on_membership_application_id"
  end

  create_table "membership_verifications", force: :cascade do |t|
    t.bigint "membership_application_id", null: false
    t.bigint "verifier_id", null: false
    t.string "background_check_status", default: "not_started", null: false
    t.text "background_check_notes"
    t.boolean "police_clearance_verified"
    t.text "police_clearance_notes"
    t.boolean "kyc_verified"
    t.text "kyc_notes"
    t.string "overall_recommendation", default: "pending_review", null: false
    t.datetime "verification_completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["background_check_status"], name: "index_membership_verifications_on_background_check_status"
    t.index ["membership_application_id"], name: "index_membership_verifications_on_membership_application_id"
    t.index ["overall_recommendation"], name: "index_membership_verifications_on_overall_recommendation"
    t.index ["verification_completed_at"], name: "index_membership_verifications_on_verification_completed_at"
    t.index ["verifier_id"], name: "index_membership_verifications_on_verifier_id"
  end

  create_table "monthly_donation_uploads", force: :cascade do |t|
    t.bigint "uploaded_by_id", null: false
    t.string "file_name"
    t.integer "total_records"
    t.integer "processed_records"
    t.integer "failed_records"
    t.date "upload_date"
    t.string "status"
    t.text "error_log"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["uploaded_by_id"], name: "index_monthly_donation_uploads_on_uploaded_by_id"
  end

  create_table "newsletter_subscribers", force: :cascade do |t|
    t.string "email", null: false
    t.datetime "subscribed_at"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_newsletter_subscribers_on_active"
    t.index ["email"], name: "index_newsletter_subscribers_on_email", unique: true
  end

  create_table "notices", force: :cascade do |t|
    t.text "message", null: false
    t.string "link_url"
    t.string "link_text", default: "→"
    t.string "background_color", default: "pink-purple"
    t.boolean "active", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_notices_on_active"
  end

  create_table "notification_logs", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "notification_type"
    t.string "recipient"
    t.string "subject"
    t.text "content"
    t.datetime "sent_at"
    t.string "delivery_status"
    t.string "provider"
    t.text "provider_response"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_notification_logs_on_user_id"
  end

  create_table "partners", force: :cascade do |t|
    t.string "name", null: false
    t.string "website_url"
    t.text "description"
    t.boolean "active", default: true, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_partners_on_active"
    t.index ["position"], name: "index_partners_on_position"
  end

  create_table "partners_products", id: false, force: :cascade do |t|
    t.bigint "partner_id", null: false
    t.bigint "product_id", null: false
    t.index ["partner_id", "product_id"], name: "index_partners_products_on_partner_id_and_product_id"
    t.index ["product_id", "partner_id"], name: "index_partners_products_on_product_id_and_partner_id"
  end

  create_table "pricing_plans", force: :cascade do |t|
    t.string "name", null: false
    t.decimal "price", precision: 10, scale: 2
    t.string "billing_period", default: "mo"
    t.text "description"
    t.string "order_limit"
    t.string "cta_text", default: "Try Now for Free"
    t.string "cta_url"
    t.text "trial_text"
    t.boolean "is_popular", default: false, null: false
    t.boolean "shopify_plus_only", default: false, null: false
    t.integer "position", default: 0, null: false
    t.text "features"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "product_id"
    t.index ["position"], name: "index_pricing_plans_on_position"
    t.index ["product_id"], name: "index_pricing_plans_on_product_id"
  end

  create_table "products", force: :cascade do |t|
    t.string "name", null: false
    t.string "product_type"
    t.string "url"
    t.text "short_description"
    t.text "description"
    t.boolean "featured", default: false, null: false
    t.boolean "featured_on_home", default: false, null: false
    t.boolean "active", default: true, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_products_on_active"
    t.index ["featured"], name: "index_products_on_featured"
    t.index ["featured_on_home"], name: "index_products_on_featured_on_home"
    t.index ["position"], name: "index_products_on_position"
  end

  create_table "products_special_offers", id: false, force: :cascade do |t|
    t.bigint "special_offer_id", null: false
    t.bigint "product_id", null: false
    t.index ["product_id", "special_offer_id"], name: "idx_on_product_id_special_offer_id_4278b602be"
    t.index ["special_offer_id", "product_id"], name: "idx_on_special_offer_id_product_id_302ad04826"
  end

  create_table "seo_metadata", force: :cascade do |t|
    t.string "page_identifier"
    t.string "page_title"
    t.text "meta_description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["page_identifier"], name: "index_seo_metadata_on_page_identifier", unique: true
  end

  create_table "special_offers", force: :cascade do |t|
    t.string "title", null: false
    t.string "subtitle"
    t.text "description"
    t.string "terms_text"
    t.string "cta_text", default: "Get the offer"
    t.string "cta_url"
    t.string "logo_text"
    t.boolean "active", default: false, null: false
    t.text "placement_tags"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_special_offers_on_active"
  end

  create_table "system_configurations", force: :cascade do |t|
    t.string "key", null: false
    t.text "value"
    t.text "description"
    t.string "data_type", default: "string"
    t.boolean "is_encrypted", default: false
    t.bigint "updated_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["data_type"], name: "index_system_configurations_on_data_type"
    t.index ["key"], name: "index_system_configurations_on_key", unique: true
    t.index ["updated_by_id"], name: "index_system_configurations_on_updated_by_id"
  end

  create_table "trusted_brands", force: :cascade do |t|
    t.string "name", null: false
    t.string "font_style", default: "bold"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["position"], name: "index_trusted_brands_on_position"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "first_name"
    t.string "last_name"
    t.string "phone"
    t.text "address"
    t.text "roles", default: "[\"member\"]"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "profession"
    t.text "educational_background"
    t.text "interest_in_sdp"
    t.date "date_of_birth"
    t.string "government_id_type"
    t.string "government_id_number"
    t.text "present_address"
    t.text "permanent_address"
    t.boolean "permanent_same_as_present"
    t.boolean "admin", default: false, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "audit_logs", "users"
  add_foreign_key "contribution_receipts", "donations"
  add_foreign_key "contribution_receipts", "users"
  add_foreign_key "donation_reminders", "users"
  add_foreign_key "donation_schedules", "users"
  add_foreign_key "donations", "users"
  add_foreign_key "legal_documents", "products"
  add_foreign_key "membership_applications", "users"
  add_foreign_key "membership_applications", "users", column: "recruiter_id"
  add_foreign_key "membership_decisions", "membership_applications"
  add_foreign_key "membership_decisions", "users", column: "approver_id"
  add_foreign_key "membership_verifications", "membership_applications"
  add_foreign_key "membership_verifications", "users", column: "verifier_id"
  add_foreign_key "monthly_donation_uploads", "users", column: "uploaded_by_id"
  add_foreign_key "notification_logs", "users"
  add_foreign_key "pricing_plans", "products"
  add_foreign_key "system_configurations", "users", column: "updated_by_id"
end
