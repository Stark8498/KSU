module KSU
  module Addon
    @items = {}
    def self.register(key, topts = {})
      k = key.to_s.to_sym
      @items[k] = {
        label: topts[:label].to_s,
        tip: topts[:tip].to_s,
        icon: topts[:icon].to_s,
        launch: topts[:launch],
        visible: topts[:visible],
        dispatch: topts[:dispatch] || {}
      }
      k
    end
    def self.items
      @items
    end
    def self.keys
      @items.keys
    end
    def self.known?(key)
      @items.key?(key.to_s.to_sym)
    end
    def self.labels
      @items.each_with_object({}) { |(k, v), arr52| arr52[k] = [v[:label], v[:tip]] }
    end
    def self.icon_of(key)
      fld = @items[key.to_s.to_sym]
      fld && fld[:icon]
    end
    def self.launch(key)
      fld = @items[key.to_s.to_sym]
      fld[:launch].call if fld && fld[:launch]
    end
    def self.visible?(key)
      fld = @items[key.to_s.to_sym]
      return false unless fld && fld[:visible]
      fld[:visible].call ? true : false
    rescue StandardError
      false
    end
    def self.dispatch_keys
      @items.values.flat_map { |v| v[:dispatch].keys.map(&:to_s) }
    end
    def self.dispatch(dlg2, str, action, id)
      name = str.to_s
      @items.each_value do |v|
        handler = v[:dispatch][name] || v[:dispatch][name.to_sym]
        next unless handler
        handler.call(dlg2, action, id)
        return true
      end
      false
    end
    def self.import
      nesting = File.dirname(File.dirname(__dir__))
      Dir[File.join(nesting, "*_kx", "main.rb")].sort.each do |file|
        begin
          load file
        rescue ScriptError, StandardError => ent
          puts "[KSU] #{File.basename(File.dirname(file))}: #{ent.message}"
        end
      end
    end
  end
end
