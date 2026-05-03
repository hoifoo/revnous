# frozen_string_literal: true

require_relative "../../lib/zepto_mail_delivery_method"

ActionMailer::Base.add_delivery_method :zepto_mail, ZeptoMailDeliveryMethod
