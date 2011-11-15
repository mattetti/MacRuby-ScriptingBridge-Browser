#
#  AppDelegate.rb
#  MacRubyScriptingBridgeBrowser
#
#  Created by Matt Aimonetti on 11/14/11.
#  Copyright 2011 __MyCompanyName__. All rights reserved.
#

class AppDelegate
  attr_accessor :window, :outline, :documentation, :doc_view
  
  def applicationDidFinishLaunching(a_notification)
    @documentation = parse_objc_header
    @outline.dataSource = self
  end

  def outlineView(view, numberOfChildrenOfItem: item)
    obj = klass_for_item(item) || documentation
    if obj && item
      nbr_of_item_children(obj)
    elsif obj
      obj.size
    else
      0
    end
  end

  def outlineView(view, child: idx, ofItem: item)
    if item.nil?
      name = documentation[idx][0]
    elsif
      name = name_for_method_or_prop(item, idx)
    end
    name
  end

  def outlineView(view, isItemExpandable: item)
    obj = object_for_item(item, false)
    obj && obj.size > 0
  end
  
  def outlineView(view, objectValueForTableColumn: column, byItem: item)
    item.description
  end

  # Parse the provided header file and return an object representing the parsed data.
  # TODO: expose constants, capitalize class names and make the header selection dynamic
  def parse_objc_header
    file = File.join(NSBundle.mainBundle.resourcePath.fileSystemRepresentation, 'omni.h')
    puts file
    header = File.open(file)
    doc = {}
    
    File.foreach(header) do |line|
      if line =~ /^@interface /
        @current_class = line[/^@interface\s(.*)\s:/, 1]
        next if @current_class.nil?
        @current_class = @current_class.capitalize
        elsif line =~ /^- /
        doc[@current_class] ||= {}
        doc[@current_class][:methods] ||= []
        returned_class  = line[/^- \((.*?)\)/, 1].gsub(' *', '')
        selector          = line[/^- \(.*?\)(.*);/, 1].strip
        selector =~ /(.*?):/
        method_name = $1 || selector
        types = selector.scan(/\((.*?)\)/).flatten
        selector_args = [method_name] + selector.scan(/\s(\w.*?):/).flatten
        ruby_method_with_types = Hash[selector_args.zip(types)]
        sa2 = selector_args.dup
        method_signature = sa2.shift
        if types.empty?
          method_signature << "("
        else
          method_signature << "(param_1"
          sa2.each_with_index do |karg, idx|
            method_signature << ", "
            method_signature << "#{karg}: param_#{idx+2}"
          end 
        end
        method_signature << ")"
        comment         = line[/\/\/(.*)/, 1]
        comment         = comment.strip unless comment.nil?
        doc[@current_class][:methods] << { 
          :returned => returned_class, 
          :selector => selector, 
          :method_signature => selector_args, 
          :method_argument_types => types, 
          :method => method_signature, 
          :comment => comment}
        elsif line =~ /^@property/
          doc[@current_class] ||= {}
          doc[@current_class][:properties] ||= []
          property        = line[/\s([a-z|\*|[0-9]]*?);/i, 1].gsub('*', '')
          comment         = line[/\/\/(.*)/, 1]
          comment         = comment.strip unless comment.nil?
          doc[@current_class][:properties] << {:name => property, :comment => comment}
      end
    end
    doc.delete_if{|node| node.nil?}.sort{|a,b| item_sort_value(a) <=> item_sort_value(b)}.to_a
  end
  
  def outlineViewSelectionDidChange(sender)
    puts "selection changed"
    item = outline.itemAtRow(outline.selectedRow)
    parent = outline.parentForItem(item)
    if parent
      display_method_or_property(item, parent, outline.selectedRow)
    else
      display_class(item)
    end
  end
  
  def windowWillClose(sender); exit(1); end
  
  private
  
  def display_method_or_property(item, parent, idx)
    klass = klass_for_item(parent)
    if klass
      # meth = name_for_method_or_prop(item, idx)
      puts item.description
      display_doc(klass[0] + "\n" + item.description)
    end
  end
  
  def display_class(item)
    klass = klass_for_item(item)
    display_doc(klass.inspect)
  end
  
  def display_doc(text)
    ts = doc_view.textStorage
    range = NSMakeRange(0, ts.length) # To append: NSMakeRange(ts.length, 0)
    ts.replaceCharactersInRange(range, withString:text)
    doc_view.scrollRangeToVisible(range, 0)
  end
  
  def name_for_method_or_prop(item, idx)
    doc = klass_for_item(item)
    return nil unless doc
    @sorted_list ||= {}
    @sorted_list[doc[0]] ||= ((doc[1][:properties] || []) + (doc[1][:methods] || [])).compact.sort{|a,b| (a[:method] || a[:name]) <=> (b[:method] || b[:name])}
    item_doc = @sorted_list[doc[0]][idx]
    name = item_doc[:method] || item_doc[:name] if item_doc
    name
  end
  
  def nbr_of_item_children(obj)
    list = obj[1]
    total = 0
    return total unless list
    meths = list[:methods]
    props = list[:properties]
    total += meths.size if meths
    total += props.size if props
    total
  end
  
  def item_sort_value(item)
    item && item[0] ? item[0] : ""
  end
  
  def object_for_item(item, fallback=true)
    obj = klass_for_item(item)
    obj ||= documentation if fallback
    obj
  end
  
  def klass_for_item(item)
    documentation.find{|klass| klass != nil && klass[0] == item.description}
  end
end

