module Spree
  class ChimpyMailer < BaseMailer
    def subscribe_email(success_count, fail_count, exist_count, fail_list)
      @success_count = success_count
      @fail_count = fail_count
      @exist_count = exist_count
      @fail_list = fail_list
      subject = "#{Spree::Store.current.name} #{Spree.t('chimpy_mailer.subscribe_email.subject')} ##{Time.now.strftime('%Y/%m/%d')}"
      mail(to: Spree::Chimpy::Config[:report_email], from: from_address, subject: subject) if Spree::Chimpy::Config[:report_email]
    end
  end
end