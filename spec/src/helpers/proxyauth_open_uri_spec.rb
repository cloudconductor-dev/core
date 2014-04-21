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
describe ProxyauthOpenUri do
  before(:all) do
    @proxy_user = 'username'
    @proxy_password = 'password'
    @http_proxy_option = { proxy_http_basic_authentication:
      ['http://proxy:8080/', @proxy_user, @proxy_password]
    }
    @https_proxy_option = { proxy_http_basic_authentication:
      ['https://proxy:8080/', @proxy_user, @proxy_password]
    }
  end

  before(:each) do
    # clear proxy related environments every time
    ENV && ENV.each do |key, value|
      ENV[key] = nil if key.upcase.end_with?('PROXY')
    end
  end

  describe 'proxy environment test' do
    context 'when no_proxy environment is not set' do
      it 'option is nil when direct connection' do
        mock = double('mock')
        allow(mock).to receive(:read)
        openuri = ProxyauthOpenUri.new
        allow(openuri).to receive(:open).and_return(mock)

        openuri.read_url('http://example.com/')
        expect(openuri.options).to eq(nil)
        openuri.read_url('https://example.com/')
        expect(openuri.options).to eq(nil)
      end

      it 'http proxy option is set when http_proxy envronment is set' do
        ENV['http_proxy'] = sprintf('http://%s:%s@proxy:8080/', @proxy_user, @proxy_password)
        mock = double('mock')
        allow(mock).to receive(:read)
        openuri = ProxyauthOpenUri.new
        allow(openuri).to receive(:open).and_return(mock)

        openuri.read_url('http://example.com/')
        expect(openuri.options).to eq(@http_proxy_option)
        # https should be direct connection
        openuri.read_url('https://example.com/')
        expect(openuri.options).to eq(nil)
      end

      it 'https proxy option is set when https_proxy envronment is set' do
        ENV['https_proxy'] = sprintf('https://%s:%s@proxy:8080/', @proxy_user, @proxy_password)
        mock = double('mock')
        allow(mock).to receive(:read)
        openuri = ProxyauthOpenUri.new
        allow(openuri).to receive(:open).and_return(mock)

        openuri.read_url('https://example.com/')
        expect(openuri.options).to eq(@https_proxy_option)
        # http should be direct connection
        openuri.read_url('http://example.com/')
        expect(openuri.options).to eq(nil)
      end
    end

    context 'when no_proxy environment is set' do
      it 'http proxy option is not set when http_proxy envronment is set' do
        ENV['http_proxy'] = sprintf('http://%s:%s@proxy:8080/', @proxy_user, @proxy_password)
        ENV['no_proxy'] = 'example.com,example.net,example.org'
        mock = double('mock')
        allow(mock).to receive(:read)
        openuri = ProxyauthOpenUri.new
        allow(openuri).to receive(:open).and_return(mock)

        openuri.read_url('http://example.com/')
        expect(openuri.options).to eq(nil)
      end

      it 'https proxy option is not set when https_proxy envronment is set' do
        ENV['https_proxy'] = "https://#{@proxy_user}:#{@proxy_password}#{@proxy}:8080"
        ENV['no_proxy'] = 'example.com,example.net,example.org'
        mock = double('mock')
        allow(mock).to receive(:read)
        openuri = ProxyauthOpenUri.new
        allow(openuri).to receive(:open).and_return(mock)

        openuri.read_url('https://example.net/')
        expect(openuri.options).to eq(nil)
      end
    end
    context 'when exception occurred' do
      it 'should be raise error' do
        allow(URI).to receive(:parse).and_raise
        openuri = ProxyauthOpenUri.new
        expect { openuri.read_url('http://example.com/') }.to raise_error
      end
    end
  end
end
