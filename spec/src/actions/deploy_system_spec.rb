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
describe Action do
  include Action

  before(:all) do
    @system = FactoryGirl.create(:system)
  end

  after(:all) do
    @system.delete if @system
  end

  describe '#deploy_system' do
    context 'When specified valid parameters' do
      before do
        FactoryGirl.create(:openstack)
        FactoryGirl.create(:centos)
        FactoryGirl.create(:small)
      end
      it 'should deploy system from xml' do
        log_file = '/tmp/cloudconductor-cloudinit.log'
        ssh_mock = double
        allow(SSHConnection).to receive(:new).and_return(ssh_mock)
        allow(ssh_mock).to receive(:exec!).with("[ -e #{log_file} ]; echo -n $?").and_return(0)
        allow(ssh_mock).to receive(:exec!).with("tail #{log_file} | grep -c -e '\\[.*\\] ERROR:'").and_return(0)
        allow(ssh_mock).to receive(:exec!).with("tail #{log_file} | grep -c -e '\\[.*\\] INFO: Success to setup instance'").and_return(1)
        VCR.use_cassette 'actions/deploy_system' do
          result = deploy_system(@system.id)
          expect(result).to be
        end
      end
    end

    context 'When received invalid system id' do
      it 'should raise Runtime Exception' do
        expect { deploy_system(-1) }.to raise_error
      end
    end
  end

  describe '#allocate_network_address' do
    let(:external_net_addrs) do
      ['192.168.166.0/24']
    end
    context 'When default net_addr does not conflicted with external_network_address' do
      before do
        @cloud = FactoryGirl.create(:openstack)
        @network_group = FactoryGirl.create(:network_group)
        @cloud.stub(external_net_addrs: external_net_addrs)
      end
      it 'sheuld be allocated default network address' do
        network_address =  send(:allocate_network_address, @cloud, @network_group)
        default_network_address = send(:default_network_address)
        expect(network_address).to eq(default_network_address)
      end
    end
    context 'When default net_addr conflicts with external_network_address' do
      before do
        @cloud = FactoryGirl.create(:openstack)
        @network_group = FactoryGirl.create(:network_group)
        default_network_address = send(:default_network_address)
        addr_blocks = external_net_addrs << default_network_address
        @cloud.stub(external_net_addrs: addr_blocks)
      end
      let(:alternative_net_addr) do
        '10.0.1.0/24'
      end
      it 'should be allocated alternative network address' do
        network_address =  send(:allocate_network_address, @cloud, @network_group)
        expect(network_address).to eq(alternative_net_addr)
      end
    end
  end
end
