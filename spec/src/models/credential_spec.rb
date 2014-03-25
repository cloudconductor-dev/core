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
require 'uri'

describe Credential do
  before(:all) do
    @cloud = FactoryGirl.create(:aws)
    key = URI.encode_www_form_component(@cloud.key)
    secret = URI.encode_www_form_component(@cloud.secret)
    @deltacloud_url = "http://#{key}:#{secret}@#{ConductorConfig.deltacloud_host}:#{ConductorConfig.deltacloud_port}/api"
    @params = FactoryGirl.attributes_for(:aws_key).merge(cloud_entry_point: @cloud)
  end

  after(:all) do
    Credential.delete_all(@params)
  end

  let(:credential) do
    FactoryGirl.create(:aws_key)
  end

  describe 'on self.create' do
    context 'When success to create credential on cloud' do
      before do
        post_response = <<-'EOS'
        {
        "key": {
          "credential_type": "key",
          "fingerprint": "ee:c2:17:c8:c5:e7:78:b8:51:b3:f1:e4:0e:72:d3:3e",
          "href": "http://127.0.0.1:9292/api/keys/test-api",
          "id": "test-api",
          "password": null,
          "pem_rsa_key": "-----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAKCAQEA4s3hBrgrH/NkZDKtJzA0kfq96vKfBoU38HTey/rpXEB8BJgz\nt3VPb3Xq9eUIDoQgt5Gh2c4dhDoAU0aGOoMoRL33sbax0rYCFcuqc2bZ4kht1Iw5\nziC9MNpbdwcLWvg2xVt39JcZY3Szeerk8TxeT8Wh0v+hn7+7EkGYo5y79MgGe1dI\n7EF6f6PM3X1ecW+ylgKos4UvW2HisfPgEZHG2o0xT5uY8ZxVIs5ZRf9gWCXG5cOS\n0+yr7BT116LmkJG3bZj7eQ4OMrkzrRTyOcg0AHf7ts7FaDmthAJRqOdWrqG86k+A\nL7wMJVzq7tLWadByYcBWNFdqacEKOGSl8i7GCQIBIwKCAQEAyOI8VmibOY5u3Gdm\nKgYf7wKoNn8fIwhHfTRQTkSizg06pPvWCOQ/CvNptTiSG3xXfgSlS+Jx6iS+daTd\nScSgAl8dNwDmpK/V9gwpQaQ9U2S5DLa22yRPzC8dz9MKDr6W6VED2KMWfKkxQBkx\nLW/7wv+As5H1jX3u1afQVmZAE1BphIHGONcQ1CGVBUTJxy+gW0GNZrhD46u7xn0D\nt8jYau+Z5UIhA7x00X1A5tWdsYPjS5ejT9uvyaRVCPzYUXmXU1UmBUNrrYOAtncE\nxpdI2cWt7XW0XL41UxH9R5bxx9n7OTFHFpNl0w9TahL+uF/pg+2VZQ5Xc6hqPAsi\nj/672wKBgQDycEDZECDK5BeHSnajUc2oZPNDDCkZL+tkDTf17O0wk3GImBjN2byS\ngGix1SG4aP84LopvEDNQhTkmFW9yZbhS4VkDuacr8i8bGyfesHQyBc46HAISZ3l/\nBrfewhKXgwS8pZHeCBywo7phJDBCKauTC+Es0/mBLW4Lkwy9PZHvbQKBgQDvfb25\nWeOMF2ZbQsFTLjq4PaRapv+ofP7stB5AyMHTe8sTvO3PG+n0a43qjUdQu2Aaeqa1\ns+JbIBoEZXkUlQ4MRvBZNVSR+IIDHsGKA/OGcCVolvU58uEsFz5ldPjG92TUHPFa\nJuhsrB2fOhmFLeoiAvw2YeJdNZ0bWUtWVBojjQKBgHXBfpVQ+fwlpQcyy+jtOAFV\nmroqelyw4AwGa6NV0krLRcYAu5cvPlXJV2xRlAkdDj/cF1qENi5smBnP5ayXzo6n\n+AkfqPgWi+iYKU7n/expOEgcO4VIM7K6HstIUixVlJYkiK2sKzE5lQqcjHfoWqaC\nHOnjTU1fNXNWDYB8/b1vAoGBALjAFgQDg6aVtVxYEXquolOdREXuirUtOa9JHqcB\nRRDb1yx7zWVBa1YnFbTwpLqfLOE6C5N8I6Vh6C9G9wE/yQIoGH9VBrm/tMCUEaT7\nu9y86ah0dAghw6Wrh+fd5Hw7MIZfeFt9GbLrLMtKE6/hl1wQ7nMYT4m7pRUY/5pe\nIsr3AoGBAMHRNEchanmaVUzieAiGSGQ98/NuGLLlalgcwDxrhS+J63EoY06e0rWy\nFCG0IlGp/Xq3Oh7CrxdZlUxLFRFvM3f+isF3o4cWx8+itnp6MhEt/ltDsrEcQNC4\nd5WMDQ2wwBy1Py7IU68MqyGDPt/6ahTfHgomsOHLIOc+F9v/g5Yb\n-----END RSA PRIVATE KEY-----\n",
           "state": "AVAILABLE",
           "username": null
          }
        }
        EOS
        WebMock.stub_request(:post, "#{@deltacloud_url}\/keys")
          .to_return(status: 201, body: post_response)
      end
      it 'should store parameters and return Credential object' do
        credential = Credential.create(@params)
        expect(Credential.find_by(id: credential.id)).to be
        expect(credential).to be_an_instance_of(Credential)
        expect(credential.private_key).to be_an_instance_of(String)
      end
    end

    context 'When error occurred' do
      before do
        post_response = '{"code":500,"message":"The server returned status 409","error":"Deltacloud::Exceptions::BackendError"}'
        WebMock.stub_request(:post, "#{@deltacloud_url}\/keys")
          .to_return(status: 500, body: post_response)
      end
      it 'should fail to create credential and raise exception' do
        expect do
          Credential.create(@params)
        end.to raise_error
      end
    end

    context 'When Deltacloud server returns 500 Internal Server Error' do
      before do
        WebMock.stub_request(:post, "#{@deltacloud_url}\/keys")
          .to_return(status: 500)
      end
      it 'should fail to create credential' do
        expect do
          Credential.create(@params)
        end.to raise_error
      end
    end
  end

  describe 'on #destroy' do
    context 'When DeltaCloud server returns 204 No Content' do
      before do
        WebMock.stub_request(:delete, "#{@deltacloud_url}\/keys\/#{credential.name}").to_return(status: 204)
      end
      it 'should delete record' do
        id = credential.id
        credential.destroy
        expect(Credential.find_by(id: id)).to be_nil
      end
    end

    context 'When error occurred' do
      before do
        WebMock.stub_request(:delete, "#{@deltacloud_url}\/keys\/invalid_name").to_return(status: 500)
      end
      it 'should fail to destroy credential and raise exception' do
        expect do
          credential.destroy
        end.to raise_error
      end
    end
  end
end
