module KSU
  def self.select_tool(klass)
    return unless KSU::Drag.licensed? == true
    if klass.is_a?(Class)
      model = Sketchup.active_model
      model.close_active while model.active_path
      model.select_tool(klass.new)
    else
      Sketchup.active_model.select_tool(nil)
    end
  end
  def self.prepare_model
    start(false)
    Sketchup.active_model.set_attribute("_temp_", "_", nil)
    commit
  end
  def self.start(gtr = true)
    Sketchup.active_model.start_operation("KSU", true, false, gtr)
  end
  def self.commit
    Sketchup.active_model.commit_operation
  end
  def self.abort_op
    begin
      Sketchup.active_model.abort_operation
    rescue StandardError
    end
  end
  def self.set_status(text)
    Sketchup.set_status_text(text)
  end
  def self.set_vcb(lbl, value)
    Sketchup.set_status_text(lbl, SB_VCB_LABEL)
    return unless value
    Sketchup.set_status_text(value, SB_VCB_VALUE)
  end
  def self.container?(entity)
    entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
  end
  def self.entities_in(entity)
    if entity.is_a?(Sketchup::Group)
      entity.entities
    elsif entity.is_a?(Sketchup::ComponentInstance)
      entity.definition&.entities
    end
  end
  def self.selection
    Sketchup.active_model.selection.to_a
  end
  def self.select_only(ents)
    _79f8d55d = Sketchup.active_model.selection
    _79f8d55d.clear
    ents = Array(ents)
    return if ents.empty?
    _79f8d55d.add(ents)
  end
  def self.model_dir
    path = Sketchup.active_model.path.to_s
    return nil if path.empty?
    dir = File.dirname(path)
    File.directory?(dir) ? dir : nil
  rescue StandardError
    nil
  end
end
module KSU
  def self.wmi_connect
    WIN32OLE.new("WbemScripting.SWbemLocator").ConnectServer(".", "root\\cimv2")
  end
end
