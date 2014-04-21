# -*- coding: utf-8 -*-
# Copyright 2014 TIS Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# using address block. requiring cidr format
address_block '10.0.0.0/24'
# subnet address block should be narrower than the above
subnet_address_block '10.0.0.0/24'

# setting provisioning target os type
# target_os_type 'centos'
target_os_type 'ubuntu' # setting invalid target os type

# Machine create timeout
machine.create_timeout 30

# log settings
log_dir 'log'
log_file 'conductor.log'
log_level :error

# deltacloud settings
deltacloud_host '127.0.0.1'
deltacloud_port 9292
