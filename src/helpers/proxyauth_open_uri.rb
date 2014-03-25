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
require 'open-uri'

class ProxyauthOpenUri
  attr_reader :proxy
  attr_reader :options # for debug purpose

  def initialize
    Log.debug(Log.format_method_start(self.class, __method__))
    @proxyenv = {}
    !ENV.nil? && ENV.each do |key, value|
      @proxyenv.store(key.upcase, value) if key.upcase.end_with?('PROXY')
    end
    Log.debug(Log.format_debug_param(proxyenv: @proxyenv))
  end

  def read_url(url)
    Log.debug(Log.format_method_start(self.class, __method__))
    Log.debug(Log.format_debug_param(url: url))
    @options = nil
    use_proxy = true
    xml_uri = URI.parse(url)
    Log.debug(Log.format_debug_param(xml_uri: xml_uri))
    unless @proxyenv['NO_PROXY'].nil?
      no_proxies = @proxyenv['NO_PROXY'].upcase.split(',')
      no_proxies.each do |x|
        x = x.strip!
      end
      use_proxy = no_proxies.include?(xml_uri.host.upcase) ? false : true
      use_proxy = false if no_proxies.include?('*') # same as curl
    end

    Log.debug(Log.format_debug_param(use_proxy: use_proxy))

    if use_proxy
      if xml_uri.scheme == 'http' && !@proxyenv['HTTP_PROXY'].nil?
        proxy_uri = URI.parse(@proxyenv['HTTP_PROXY'])
      elsif xml_uri.scheme == 'https' && !@proxyenv['HTTPS_PROXY'].nil?
        proxy_uri = URI.parse(@proxyenv['HTTPS_PROXY'])
      end

      unless proxy_uri.nil?
        proxy = sprintf('%s://%s:%d/', proxy_uri.scheme, proxy_uri.host, proxy_uri.port)
        if !proxy_uri.userinfo.nil?
          (username, password) = proxy_uri.userinfo.split(':')
          @options = { proxy_http_basic_authentication: [proxy, username, password] }
        else
          @options = { proxy: proxy }
        end
      end
    end
    Log.debug(Log.format_debug_param(options: @options))
    @options ? open(url, @options).read : open(url).read
  rescue
    Log.error(Log.format_error_params(
      self.class,
      __method__,
      url: url,
      options: @options,
      proxyenv: @proxyenv
    ))
    raise
  end
end
