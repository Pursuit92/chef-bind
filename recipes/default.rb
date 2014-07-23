#
# Cookbook Name:: bind
# Recipe:: default
#
# Copyright 2014, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

package "bind"

bagname = node["bind"]["zones_bag"]
db = data_bag(bagname)
zones_conf = Hash.new
db.each do |name|
	zone = data_bag_item(bagname,name)
	if zone.has_key?("zone")
		zoneName = zone["zone"]
		zones_conf[zoneName] = Hash.new
		if zone.has_key?("conf") then
			zone["conf"].each do |item, val|
				zones_conf[zoneName][item] = val
			end
		end
		if zone.has_key?("data") then
			zone_data = Hash.new
			zone["data"].each do |item,val|
				zone_data[item] = val
			end
			zone_data["origin"] = zone["zone"]
			template "/var/named/#{zone["zone"]}" do
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
end

template "/etc/named.conf" do
	source "named.conf.erb"
	owner "root"
	mode "0644"
	variables ({
		:zones => zones_conf
	})
	notifies :restart, "service[named]", :delayed
end

file "/etc/named.conf.local" do
	owner "root"
	mode "0644"
end

service "named" do
	action [:start, :enable]
	supports :restart => true, :reload => true
end
