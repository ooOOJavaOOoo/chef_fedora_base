#
# Cookbook:: chef_fedora_base
# Recipe:: default
#
# Copyright:: 2017, Christopher Maher, MIT

# Development tools
%w(sudo powertop gnupg util-linux-user git make automake gcc gcc-c++ kernel-devel dkms).each do |temppackage|
  package temppackage
end

# OpenSSH Server and Service
package 'openssh-server'

service 'sshd' do
  action [:enable, :start]
end

# Install Vagrant and VirtualBox for local cookbook development
remote_file 'vagrant_file' do
  path "#{Chef::Config['file_cache_path']}/vagrant_#{node['chef_fedora_base']['vagrant_version']}_x86_64.rpm"
  source node['chef_fedora_base']['vagrant_url']
  action :create_if_missing
end

package 'vagrant' do
  package_name "vagrant-#{node['chef_fedora_base']['vagrant-version']}-1.x86_64"
  source "#{Chef::Config['file_cache_path']}/vagrant_#{node['chef_fedora_base']['vagrant_version']}_x86_64.rpm"
end

template '/etc/yum.repos.d/virtualbox.repo' do
  source 'virtualbox.repo.erb'
end

package 'VirtualBox-5.2'

# Install ChefDK via chef-ingredient cookbook
chef_ingredient 'chefdk'

# User Specific Tweaks (NVIM, dotfiles, etc)
%w(zsh zsh-syntax-highlighting neovim tmux gnome-tweak-tool).each do |temppackage|
  package temppackage
end

# Install Docker
remote_file 'docker-ce' do
  path "#{Chef::Config['file_cache_path']}/docker.rpm"
  source node['chef_fedora_base']['docker_url']
  action :create
end

package 'docker-ce' do
  source "#{Chef::Config['file_cache_path']}/docker.rpm"
end

git "#{Chef::Config['file_cache_path']}/.oh-my-zsh" do
  repository 'https://github.com/robbyrussell/oh-my-zsh.git'
  action :sync
end

directory "#{Chef::Config['file_cache_path']}/.oh-my-zsh" do
  mode '0755'
end

hab_install 'install habitat'

node['etc']['passwd'].each do |user, data|
  next unless data['gid'].to_i >= 1000

  user 'user modify' do
    shell '/bin/zsh'
    username user
    action :modify
  end

  group 'docker' do
    action :modify
    members user
    append true
  end

  execute "#{user} install-oh-my-zsh" do
    command "bash #{Chef::Config['file_cache_path']}/.oh-my-zsh/tools/install.sh"
    action :run
    user user
    group data['gid']
    live_stream true
    not_if { ::File.exist?("#{data['dir']}/.oh-my-zsh") }
  end

  template "#{data['dir']}/.zshrc" do
    action :create_if_missing
    source 'zshrc.erb'
    user user
    group data['gid']
    variables(
      user: user
    )
  end

  git "#{data['dir']}/.dotfiles" do
    repository 'https://github.com/defilan/dotfiles'
    action :sync
    user user
    group data['gid']
  end

  directory "#{data['dir']}/.tmux/plugins" do
    recursive true
    user user
    group data['gid']
  end

  git "#{data['dir']}/.tmux/plugins/tpm" do
    repository 'https://github.com/tmux-plugins/tpm'
    action :sync
    user user
    group data['gid']
  end
end

# Making sure docker is enabled and running
service 'docker' do
  action [:enable, :start]
end

# Configure GNOME to use x11 instead of wayland (for zoom.us)
template '/etc/gdm/custom.conf' do
  source 'custom.conf.erb'
  only_if { ::File.exist?('/etc/gdm/custom.conf') }
end
