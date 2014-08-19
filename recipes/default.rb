#
# Cookbook Name:: bind
# Recipe:: default
#
# Copyright 2014, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

package "bind"

zones = []
acls = {}
views = {}

anyView = {
	"match_clients" => [ "any" ],
	"zones" => {},
	"options" => {}
}

bagname = node["bind"]["zones_bag"]
db = data_bag(bagname)

# collect the various configuration items
if db != nil then
	zones_conf = {}
	db.each do |name|
		item = data_bag_item(bagname,name)
		if item.has_key?("zone") then
			zones << item
		end
		if item.has_key?("acls") then
			item["acls"].each do |acl,match|
				acls[acl] = match
			end
		end
		if item.has_key?("views") then
			item["views"].each do |view,match|
				match["zones"] = {}
				if not match.has_key?("options") then
					match["options"] = {}
				end
				views[view] = match
			end
		end
	end
end

views["any"] = anyView

zones.each do |zone|
	name = zone["zone"]
	if zone.has_key?("conf") then
		if zone.has_key?("view") then
			fileName = "#{zone["zone"]}-#{zone["view"]}"
			zone["conf"]["file_name"] = fileName
			views[zone["view"]]["zones"][name] = zone["conf"]
		else
			zone["conf"]["file_name"] = name
			views["any"]["zones"][name] = zone["conf"]
		end
	end
	if zone.has_key?("data") then
		zone_data = zone["data"]
		view = zone["view"]
		if view != nil then
			fileName = zone["zone"] + "-" + view
		else
			fileName = zone["zone"]
		end
		zone_data["origin"] = zone["zone"]
		template "/var/named/#{fileName}" do
			source "zone.erb"
			owner "named"
			mode "0400"
			variables ({
				:zone => zone_data
			})
			notifies :reload, "service[named]", :delayed
		end
	end
end

template "/etc/named.conf" do
	source "named.conf.erb"
	owner "root"
	mode "0644"
	variables ({
		:views => views,
		:acls => acls
	})
	notifies :restart, "service[named]", :delayed
end

file "/etc/named.conf.local" do
	owner "root"
	mode "0644"
end

service "iptables" do
	action [:stop, :disable]
end

service "named" do
	action [:start, :enable]
	supports :restart => true, :reload => true
end
