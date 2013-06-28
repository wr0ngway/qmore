require 'qmore'

module Qmore
  module Server

    Attr = Qmore::Attributes

    def self.registered(app)

      app.helpers do
        
        def qmore_view(filename, options = {}, locals = {})
          options = {:layout => true, :locals => { :title => filename.to_s.capitalize }}.merge(options)
          dir = File.expand_path("../server/views/", __FILE__)
          erb(File.read(File.join(dir, "#{filename}.erb")), options, locals)
        end

        alias :original_tabs :tabs
        def tabs
          qmore_tabs = [
              {:name => 'DynamicQueues', :path => '/dynamicqueues'},
              {:name => 'QueuePriority', :path => '/queuepriority'}
          ]
          queue_tab_index = original_tabs.index {|t| t[:name] == 'Queues' }
          original_tabs.insert(queue_tab_index + 1, *qmore_tabs)
        end
        
      end

      #
      # Dynamic queues
      #

      app.get "/dynamicqueues" do
        @queues = []
        real_queues = Qmore.client.queues.counts.collect {|q| q['name'] }
        dqueues = Attr.get_dynamic_queues
        dqueues.each do |k, v|
          expanded = Attr.expand_queues(["@#{k}"], real_queues)
          expanded = expanded.collect { |q| q.split(":").last }
          view_data = {
              'name' => k,
              'value' => Array(v).join(", "),
              'expanded' => expanded.join(", ")
          }
          @queues << view_data
        end

        @queues.sort! do |a, b|
          an = a['name']
          bn = b['name']
          if an == 'default'
            1
          elsif bn == 'default'
            -1
          else
            an <=> bn
          end
        end

        qmore_view :dynamicqueues
      end

      app.post "/dynamicqueues" do
        dynamic_queues = Array(params['queues'])
        queues = {}
        dynamic_queues.each do |queue|
          key = queue['name']
          values = queue['value'].to_s.split(',').collect { |q| q.gsub(/\s/, '') }
          queues[key] = values
        end
        Attr.set_dynamic_queues(queues)
        redirect to("/dynamicqueues")
      end

      #
      # Queue priorities
      #

      app.get "/queuepriority" do
        @priorities = Attr.get_priority_buckets
        qmore_view :priorities
      end

      app.post "/queuepriority" do
        priorities = params['priorities']
        Attr.set_priority_buckets priorities
        redirect to("/queuepriority")
      end

    end
  end
end
