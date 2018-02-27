include_recipe 'nginx'

# generate ssl certs for https
directory '/etc/nginx/ssl' do
    owner 'root'
    group 'root'
    mode '0755'
    action :create
end

openssl_x509 '/etc/nginx/ssl/mycert.pem' do
    common_name 'www.acme.com'
    org 'Acme Inc'
    org_unit 'Lab'
    country 'US'
end

# download inspec page
remote_file "#{Chef::Config[:file_cache_path]}/gh-pages.tar.gz" do
  source 'https://github.com/chef/inspec/archive/gh-pages.tar.gz'
  mode '0755'
  action :create
end

install_path = "/usr/share/nginx/inspec/"

bash 'extract inspec web page' do
  cwd Chef::Config[:file_cache_path]
  code <<-EOF
    tar -xvf gh-pages.tar.gz
    mv inspec-gh-pages #{install_path}
  EOF
  user "root"
  not_if { ::File.exists?(install_path) }
end

# ensure directory permission
directory install_path do
    owner node['nginx']['user'] 
    group node['nginx']['group']
    mode '0755'
end

nginx_site "inspec" do
    template "inspec.conf.erb"
    action :enable
end