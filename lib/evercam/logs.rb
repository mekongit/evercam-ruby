# Copyright © 2014, Evercam.

module Evercam
   module Logs
      # This method fetches activity log details for a specified camera from
      # the system.
      #
      # ==== Parameters
      # camera_id::  The unique identifier of the camera to fetch the logs for.
      # options::    A Hash of additional parameters for the request. Currently
      #              recognised keys for this request are :from, :to, :limit,
      #              :page, :types and :objects.
      def get_logs(camera_id, options={})
         parameters = {}
         parameters[:from] = options[:from] if options.include?(:from)
         parameters[:to] = options[:to] if options.include?(:to)
         parameters[:limit] = options[:limit] if options.include?(:limit)
         parameters[:page] = options[:page] if options.include?(:page)
         if options.include?(:types)
            values = options[:types]
            if values.kind_of?(Array)
               parameters[:types] = options[:types].join(",")
            else
               parameters[:types] = options[:types]
            end
         end
         parameters[:objects] = (options[:objects] == true) if options.include?(:objects)
         data = handle_response(call("/cameras/#{camera_id}/logs", :get, parameters))
         if !data.include?("logs") || !data.include?("pages")
            message = "Invalid response received from server."
            @logger.error message
            raise EvercamError.new(message)
         end
         {logs: data["logs"], pages: data["pages"]}
      end

      # This method add activity in the system.
      #
      # ==== Parameters
      # camera_id::  The unique camera identifier.
      # action::     Type of log: login, logout etc
      # is_public::  A boolean to indicate whether the new camera is public.
      # values::     A Hash of additional params. Like: country, browser etc
      def create_log(action, values={} , camera_id=nil)
        parameters = {action: action}.merge(values)
        parameters[:camera_id] = camera_id if !camera_id.nil?
        handle_response(call("/logs", :post, parameters))
        self
      end
   end
end