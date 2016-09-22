if node['ganglia']['from_source']
  include_recipe 'ganglia::source'
else
  package 'gmetad'
end

directory '/var/lib/ganglia/rrds' do
  owner node['ganglia']['user']
  recursive true
end
if node['ganglia']['enable_two_gmetads']
  directory node['ganglia']['two_gmetads']['empty_rrd_rootdir'] do
    owner node['ganglia']['user']
    recursive true
  end
end

# if we should use rrdcached, set it up here.
if node['ganglia']['enable_rrdcached'] == true
  package 'rrdcached' do
    action :install
  end
  include_recipe 'runit'
  runit_service 'rrdcached' do
    template_name 'rrdcached'
    options(user: node['ganglia']['rrdcached']['user'],
            main_socket: node['ganglia']['rrdcached']['main_socket'],
            limited_socket: node['ganglia']['rrdcached']['limited_socket'],
            ganglia_rrds: node['ganglia']['rrdcached']['ganglia_rrds'],
            timeout: node['ganglia']['rrdcached']['timeout'],
            delay: node['ganglia']['rrdcached']['delay'])
  end
  # install socat to make it easy to talk to rrdcached for diagnostics.
  package 'socat' do
    action :install
  end
end

case node['ganglia']['unicast']
when true
  gmond_collectors = search(:node, "role:#{node['ganglia']['server_role']} AND chef_environment:#{node.chef_environment}").map { |node| node['ipaddress'] }
  gmond_collectors = ['127.0.0.1'] if gmond_collectors.empty?
  template '/etc/ganglia/gmetad.conf' do
    source 'gmetad.conf.erb'
    variables(clusters: node['ganglia']['clusterport'].to_hash,
              hosts: gmond_collectors,
              xml_port: node['ganglia']['gmetad']['xml_port'],
              interactive_port: node['ganglia']['gmetad']['interactive_port'],
              rrd_rootdir: node['ganglia']['rrd_rootdir'],
              write_rrds: 'on',
              grid_name: node['ganglia']['grid_name'])
    notifies :restart, 'service[gmetad]'
  end
  if node['ganglia']['enable_two_gmetads']
    template '/etc/ganglia/gmetad-norrds.conf' do
      source 'gmetad.conf.erb'
      variables(clusters: node['ganglia']['clusterport'].to_hash,
                hosts: gmond_collectors,
                xml_port: node['ganglia']['two_gmetads']['xml_port'],
                interactive_port: node['ganglia']['two_gmetads']['interactive_port'],
                rrd_rootdir: node['ganglia']['two_gmetads']['empty_rrd_rootdir'],
                write_rrds: 'off',
                grid_name: node['ganglia']['grid_name'])
      notifies :restart, 'service[gmetad-norrds]'
    end
  end
  include_recipe 'ganglia::iptables' if node['recipes'].include? 'iptables'
when false
  ips = search(:node, '*:*').map { |node| node['ipaddress'] }
  template '/etc/ganglia/gmetad.conf' do
    source 'gmetad.conf.erb'
    variables(clusters: node['ganglia']['clusterport'].to_hash,
              hosts: ips,
              grid_name: node['ganglia']['grid_name'])
    notifies :restart, 'service[gmetad]'
  end
end

# drop in our own gmetad init script to enable rrdcached if appropriate
template '/etc/init.d/gmetad' do
  source 'gmetad-startscript.erb'
  mode '0755'
  variables(gmetad_name: 'gmetad')
  notifies :restart, 'service[gmetad]'
end
service 'gmetad' do
  supports restart: true
  action [:enable, :start]
end

if node['ganglia']['enable_two_gmetads']
  template '/etc/init.d/gmetad-norrds' do
    source 'gmetad-startscript.erb'
    mode '0755'
    variables(gmetad_name: 'gmetad-norrds')
    notifies :restart, 'service[gmetad-norrds]'
  end
  service 'gmetad-norrds' do
    supports restart: true
    action [:enable, :start]
  end
end
