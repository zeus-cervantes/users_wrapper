#
# Cookbook Name:: myusers
# Recipe:: default
#
# Copyright (C) 2015 YOUR_NAME
#
# All rights reserved - Do Not Redistribute
#
#

include_recipe 'users'

#Getting data bag names
users_common_databag_name='users_common'
users_env_databag_name="users_#{node.chef_environment}"
users_env_results_databag_name="users_#{node.chef_environment}_processed"

#Getting user list per data bag
users = data_bag(users_common_databag_name)
users_env = data_bag(users_env_databag_name)
users_env_results = data_bag(users_env_results_databag_name)

users_processed=[]
users.each do |user|
  user_data = Chef::DataBagItem.load(users_common_databag_name, user)
  user_data_env = users_env.include?(user) ?  Chef::DataBagItem.load(users_env_databag_name, user) : { 'shell' => '', 'home' => '', 'id' => '', 'groups' => '', 'ssh_keys' => [] } 

  #Joining all groups/ssh_keys and eliminating duplicates
  new_groups = Array(user_data['groups']).concat(Array(user_data_env['groups'])).sort.uniq 
  new_ssh_keys = Array(user_data['ssh_keys']).concat(Array(user_data_env['ssh_keys'])).sort.uniq
  
  users_processed<< { 'name' => user, 'shell' => user_data['shell'], 'home' => user_data['home'], 'id' => user_data['id'], 'groups' => new_groups, 'ssh_keys' => new_ssh_keys }
  
end

#Looking for environment users only and adding them to user_processed array
users_env.each do |user|
   found=false
   users_processed.each{ |userp| found=true if userp['name'] == user }

   if !found 
      user_data_env = Chef::DataBagItem.load(users_env_databag_name, user)
      user_data_env['groups'] = Array(user_data_env['groups']).sort.uniq
      user_data_env['ssh_keys'] = Array(user_data_env['ssh_keys']).sort.uniq
   
      users_processed<<{ 'name' => user }.merge(user_data_env) 
   end
end


# Checking if new user data is the same as in the data bags
users_processed.each do |user|

  update_user_data = false
 
  if users_env_results.include?(user['name']) 
     cur_user_data = Chef::DataBagItem.load(users_env_results_databag_name, user['name'])
     cur_user_data['groups'] = Array(cur_user_data['groups']).sort.uniq
     cur_user_data['ssh_keys'] = Array(cur_user_data['ssh_keys']).sort.uniq

     cur_user_data.each { |key, value | update_user_data = true if user[key]!=value }
     
  else
     update_user_data = true
  end

  if update_user_data 
    Chef::DataBagItem.destroy(users_env_results_databag_name, user['name']) if users_env_results.include?(user['name']) 
    new_user={}
    user.each{ |key, value| new_user=new_user.merge({key => value}) if key!='name' }
    new_user_databag_item = Chef::DataBagItem.from_hash(new_user)
    new_user_databag_item.save
  end
  
end


users_manage "sysadmin" do
  data_bag "users_#{node.chef_environment}_processed"
  group_id 2300
  action [ :remove, :create ]
end
