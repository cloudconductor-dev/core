# using address block. requiring cidr format
address_block '10.0.0.0/16'
# subnet address block should be narrower than the above
subnet_address_block '10.0.0.0/24'

# setting provisioning target os type
target_os_type  'centos'

# Machine create timeout
machine.create_timeout  30

# MachineFilterRule create retry and timeout
machine_filter_rule.create_timeout 10
machine_filter_rule.create_retry 30

# Deploy Application name(using JNDI resource name)
application_name 'cloudconductor'

# log settings
log_dir 'log'
log_file 'conductor.log'
log_level :debug

# deltacloud settings
deltacloud_host '127.0.0.1'
deltacloud_port 9292
