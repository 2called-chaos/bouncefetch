module Bouncefetch
  class Application
    class Registry
      attr_reader :file, :opts, :storage

      def initialize file, opts = {}
        @file = file
        @opts = { lifetime: 14, soft_limit: 10, hard_limit: 1 }.merge(opts)
        load!
      end

      def load!
        if File.exist?(@file)
          @storage = Marshal.load(File.read(@file))
        else
          @storage = {}
        end
      end

      def save
        File.open("#{@file}.tmp", "w") {|f| f.write(Marshal.dump(@storage)) }
        FileUtils.mv("#{@file}.tmp", @file)
      end

      def cleanup!
        @storage.each do |candidate, data|
          @storage.delete(candidate) if (data[:updated_at] + @lifetime) < Date.today
        end
      end

      def reached_limit
        sl = @opts[:soft_limit]
        hl = @opts[:hard_limit]
        if sl.is_a?(Hash)
          slimit = sl.keys.first
          sscale = sl.values.first
        else
          slimit = sl
          sscale = :any
        end
        if hl.is_a?(Hash)
          hlimit = hl.keys.first
          hscale = hl.values.first
        else
          hlimit = hl
          hscale = :any
        end
        @storage.select do |candidate, data|
          if sscale == :day
            sel = data[:hits][:soft].uniq.count >= slimit
          else
            sel = data[:hits][:soft].count >= slimit
          end
          if !sel && hscale == :day
            sel = data[:hits][:hard].uniq.count >= hlimit
          else
            sel = data[:hits][:hard].count >= hlimit
          end
          sel
        end
      end

      def handle candidate, mode, date, rule = nil
        if @storage[candidate]
          @storage[candidate] = nil if (@storage[candidate][:updated_at] + @opts[:lifetime]) < Date.today
        end
        @storage[candidate] ||= { reasons: { soft: [], hard: [] }, hits: { soft: [], hard: [] }, updated_at: Date.today }
        @storage[candidate][:hits][mode.to_sym] << date.to_date.to_s
        @storage[candidate][:reasons][mode.to_sym] << rule.try(:cond).to_s if rule.try(:cond).to_s.present?
      end

      def stats
        {}.tap do |r|
          r_tot = @storage.length
          r_rea = reached_limit.length
          r_inv = @storage.map{|c, d| d[:reasons][:soft] + d[:reasons][:hard] }.flatten.uniq.count
          r_hbs = @storage.map{|c, d| d[:hits][:soft].count }.inject(&:+)
          r_hbh = @storage.map{|c, d| d[:hits][:hard].count }.inject(&:+)
          r_hbb = r_hbs + r_hbh

          r["Candidates (total)"] = r_tot
          r["Candidates (unreachable)"] = "#{r_rea}\t(#{(r_rea / r_tot.to_f * 100).round(2)}%)"
          r["Involved rules"] = r_inv
          r["Handled bounces"] = r_hbb
          r["Handled bounces (soft)"] = "#{r_hbs}\t(#{(r_hbs / r_hbb.to_f * 100).round(2)}%)"
          r["Handled bounces (hard)"] = "#{r_hbh}\t(#{(r_hbh / r_hbb.to_f * 100).round(2)}%)"

          r["  "]  = ""
          r[""]  = "=== TOP REASONS ==="
          r[" "] = ""
          top_reasons = {}.tap do |tr|
            @storage.map{|c, d| d[:reasons][:soft] + d[:reasons][:hard] }.flatten.each do |reason|
              tr[reason] ||= 0
              tr[reason] += 1
            end
          end.sort_by {|reason, count| count }.reverse[0..14].each_with_index do |(reason, count), index|
            r["#{index + 1}. #{count.to_s.rjust(6)} occurrences"] = reason
          end
        end
      end
    end
  end
end
