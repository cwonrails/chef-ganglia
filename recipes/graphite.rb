if node['ganglia']['graphite_host'].nil?
  graphite_host = search(:node, "role:#{node['ganglia']['server_role']} AND chef_environment:#{node.chef_environment}").map { |node| node['ipaddress'] }
else
  graphite_host = node['ganglia']['graphite_host']
end

graphite_host = 'localhost' if graphite_host.empty?

template '/usr/local/sbin/ganglia_graphite.rb' do
  source 'ganglia_graphite.rb.erb'
  mode '744'
  variables graphite_host: graphite_host
end

cron 'ganglia_graphite' do
  command '/usr/local/sbin/ganglia_graphite.rb'
end
