# Create custom php.ini for apache
template "/etc/php5/apache2/php.ini" do
  source "php.ini.erb"
  owner "root"
  group "root"
  mode "0644"
end

# Setup a virtual host for apache
hostname = node['webapp']['hostname']
app_path = node['webapp']['path']

web_app hostname do
  cookbook 'apache2'
  server_name hostname
  server_aliases ["www.#{ hostname }"]
  docroot "#{ app_path }/web"
  allow_override 'All'
end

mysql_connection_info = {:host => "localhost", :username => 'root', :password => node['mysql']['server_root_password']}

# Create db
mysql_database 'symfony' do
  connection mysql_connection_info
  action :create
end

# Create db user
mysql_database_user 'symfony' do
  connection mysql_connection_info
  password 'symfony'
  action :create
end

# Grant db user access to db
mysql_database_user 'symfony' do
  connection mysql_connection_info
  database_name 'symfony'
  action :grant
end

# Install some php modules and other deps with apt
packages = %w(php5-sqlite php5-mysql php5-intl php5-xdebug php-apc git-flow autojump)

packages.each do |p|
  package p do
    action :install
  end 
end

# Intall some other packages with gem
gems = %w(sass compass zen-grids)

gems.each do |g|
  gem_package g do
    gem_binary '/usr/bin/gem'
    action :install
  end
end

# Upgrade PEAR and install PHPUnit
execute "upgrade Console_Getopt" do
  command "sudo pear upgrade --force Console_Getopt"
  action :run
  not_if "which phpunit"
end

execute "upgrade PEAR" do
  command "sudo pear upgrade --force pear"
  action :run
  not_if "which phpunit"
end

execute "config pear auto_discover" do
  command "pear config-set auto_discover 1"
  action :run
  not_if "which phpunit"
end

execute "install phpunit" do
  command "pear install pear.phpunit.de/PHPUnit"
  action :run
  not_if "which phpunit"
end

#Run composer install
composer_project app_path do
  action [:install]
end

# Dump assets for production
symfony2_console "dump assets for env prod" do
  action :cmd
  command "assetic:dump --env prod"
  path app_path
end