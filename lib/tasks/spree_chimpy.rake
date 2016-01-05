namespace :spree_chimpy do
  namespace :merge_vars do
    desc 'sync merge vars with mail chimp'
    task :sync do
      Spree::Chimpy.sync_merge_vars
    end
  end

  namespace :orders do
    desc 'sync all orders with mail chimp'
    task sync: :environment do
      scope = Spree::Order.complete

      puts "Exporting #{scope.count} orders"

      scope.find_in_batches do |batch|
        print '.'
        batch.each do |order|
          begin
            order.notify_mail_chimp
          rescue => exception
            if defined?(::Delayed::Job)
              raise exception
            else
              puts exception
            end
          end
        end
      end

      puts nil, 'done'
    end
  end

  namespace :users do
    desc 'segment all subscribed users'
    task segment: :environment do
      if Spree::Chimpy.segment_exists?
        emails = Spree.user_class.where(subscribed: true).pluck(:email)
        puts "Segmenting all subscribed users"
        response = Spree::Chimpy.list.segment(emails)
        response["errors"].try :each do |error|
          puts "Error #{error["code"]} with email: #{error["email"]} \n msg: #{error["msg"]}"
        end
        puts "segmented #{response["success"] || 0} out of #{emails.size}"
        puts "done"
      end
    end
  end

  desc 'sync all users with mailchimp'
  task sync: :environment do
    emails = Spree.user_class.pluck(:email)
    puts "Syncing all users"
    emails.each do |email|
      response = Spree::Chimpy.list.info(email)
      print '.'

      response["errors"].try :each do |error|
        puts "Error #{error['error']["code"]} with email: #{error['email']["email"]} \n
              msg: #{error["error"]}"
      end

      case response[:status]
        when "subscribed"
          Spree.user_class.where(email: email).update_all(subscribed: true)
        when "unsubscribed"
          Spree.user_class.where(email: email).update_all(subscribed: false)
      end
    end
  end

  desc 'sync users that have order in our shop with mailchimp'
  task sync_to: :environment do
    emails = Spree::Order.pluck(:email).uniq
    puts "sync users that have order in our shop with mailchimp"
    emails.each do |email|
      Spree::Chimpy.list.subscribe(email)
    end
  end

  desc 'subscribe all users with mailchimp'
  task subscribe: :environment do
    emails = Spree.user_class.pluck(:email)
    puts "subscribe all users"
    success_count = 0
    fail_count = 0
    exist_count = 0
    fail_list = []
    emails.each do |email|
      begin
        info = Spree::Chimpy.list.info(email)
        if info.blank?
          response = Spree::Chimpy.list.subscribe(email)
          puts "add #{email}"
          success_count = success_count + 1
        else
          puts "exist #{email}"
          exist_count = exist_count + 1
        end
      rescue Exception => e1
        puts "fail #{email} 1 times"
        puts("error=#{e1.inspect}")
        begin
          info = Spree::Chimpy.list.info(email)
          if info.blank?
            response = Spree::Chimpy.list.subscribe(email)
            puts "add #{email}"
            success_count = success_count + 1
          else
            puts "exist #{email}"
            exist_count = exist_count + 1
          end
        rescue Exception => e2
          puts "fail #{email} 2 times"
          puts("error=#{e2.inspect}")
          begin
            info = Spree::Chimpy.list.info(email)
            if info.blank?
              response = Spree::Chimpy.list.subscribe(email)
              puts "add #{email}"
              success_count = success_count + 1
            else
              puts "exist #{email}"
              exist_count = exist_count + 1
            end
          rescue Exception => e3
            puts "fail #{email} 3 times"
            puts("error=#{e3.inspect}")
            fail_list.push(email)
            fail_count = fail_count + 1
          end
        end
      end
    end

    Spree::ChimpyMailer.subscribe_email(success_count, fail_count, exist_count, fail_list).deliver_later
  end
end
