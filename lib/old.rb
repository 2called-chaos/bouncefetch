#!/usr/bin/env ruby
# encoding: UTF-8

class App < CLib::CLI::App
  def log_unhandled_mail mail
    # unless @params[:dryrun]
      FileUtils.mkdir_p("#{@approot}/unhandled")

      message = "".tap do |s|
        s << mail.reasons.join("\n")
        s << "\n\n"
        s << mail.headers.map{|h, v| "#{h} => #{v}" }.join("\n")
        s << "\n\n"
        s << mail.body
      end

      hashed = Digest::SHA1.hexdigest(message)
      file = "#{@approot}/unhandled/#{hashed}.txt"
      File.open(file, "w") {|f| f.write(message) } unless File.exists?(file)
    # end
  end
end
