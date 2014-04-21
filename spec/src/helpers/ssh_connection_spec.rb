describe SSHConnection do
  let(:params) do
    params = {
      entry_point: 'http://openstack-host:5000/v2.0/',
      host: '10.0.1.1',
      user: 'root',
      key: 'ssh_key',
      pass: nil,
      ssh_proxy: '10.0.0.1',
      c_name: 'OpenStack'
    }
  end

  describe 'initialize' do
    context 'when ssh_proxy and http_proxy are set' do
      before do
        key_file = Tempfile.open('ssh_key')
        Tempfile.stub(:open).and_return(key_file)
        @http_proxy = '127.0.0.1:8080'
        SSHConnection.any_instance.stub(:find_http_proxy).and_return(@http_proxy)
        @ssh_command = "ssh -o 'ProxyCommand nc -X connect -x #{@http_proxy} #{params[:ssh_proxy]} 22' -o stricthostkeychecking=no -i #{key_file.path} -l #{params[:user]} #{params[:ssh_proxy]} -W %h:%p"
      end
      it 'should connect through multistage proxy' do
        ssh = SSHConnection.new(params)
        expect(ssh.instance_values['opts'][:proxy].command_line_template).to eq(@ssh_command)
      end
    end
    context 'when ssh_proxy is set and http_proxy is not set' do
      before do
        key_file = Tempfile.open('ssh_key')
        Tempfile.stub(:open).and_return(key_file)
        SSHConnection.any_instance.stub(:find_http_proxy).and_return(nil)
        @ssh_command = "ssh #{params[:user]}@#{params[:ssh_proxy]} -o stricthostkeychecking=no -W %h:%p -i #{key_file.path}"
      end
      it 'should connect through ssh_proxy' do
        ssh = SSHConnection.new(params)
        expect(ssh.instance_values['opts'][:proxy].command_line_template).to eq(@ssh_command)
      end
    end
    context 'when ssh_proxy is not set and http_proxy is set' do
      before do
        key_file = Tempfile.open('ssh_key')
        Tempfile.stub(:open).and_return(key_file)
        @http_proxy = '127.0.0.1:8080'
        SSHConnection.any_instance.stub(:find_http_proxy).and_return(@http_proxy)
        @ssh_command = "nc -X connect -x #{@http_proxy} #{params[:host]} 22"
      end
      it 'should connect through http_proxy' do
        params[:ssh_proxy] = nil
        ssh = SSHConnection.new(params)
        expect(ssh.instance_values['opts'][:proxy].command_line_template).to eq(@ssh_command)
      end
    end
    context 'when ssh_proxy and http_proxy are not set ' do
      before do
        key_file = Tempfile.open('ssh_key')
        Tempfile.stub(:open).and_return(key_file)
        SSHConnection.any_instance.stub(:find_http_proxy).and_return(nil)
      end
      it 'should connect without proxy' do
        params[:ssh_proxy] = nil
        ssh = SSHConnection.new(params)
        expect(ssh.instance_values['opts'][:proxy]).to be_nil
      end
    end
  end

  describe 'find_http_proxy' do
    next if ENV.nil?
    before(:all) do
      @https_proxy = ENV['https_proxy']
      @http_proxy = ENV['http_proxy']
      @no_proxy = ENV['no_proxy']
    end
    after(:all) do
      ENV['https_proxy'] = @https_proxy
      ENV['http_proxy'] = @http_proxy
      ENV['no_proxy'] = @no_proxy
    end
    context 'When https_proxy is set' do
      before do
        ENV['https_proxy'] = 'http://https-proxy-host:8080'
        ENV['http_proxy'] = 'http://http-proxy-host:8080'
        ENV['no_proxy'] = nil
      end
      it 'should return https_proxy host and port' do
        ssh = SSHConnection.new(params)
        expect(ssh.find_http_proxy(params[:entry_point], params[:c_name])).to eq('https-proxy-host:8080')
      end
    end
    context 'When https_proxy is not set but http_proxy is set' do
      before do
        ENV['https_proxy'] = nil
        ENV['http_proxy'] = 'http://http-proxy-host:8080'
        ENV['no_proxy'] = nil
      end
      it 'should return http_proxy host and port' do
        ssh = SSHConnection.new(params)
        expect(ssh.find_http_proxy(params[:entry_point], params[:c_name])).to eq('http-proxy-host:8080')
      end
    end
    context 'When cloud_entory_point is set no_proxy' do
      before do
        ENV['https_proxy'] = nil
        ENV['http_proxy'] = 'http://http-proxy-host:8080'
        ENV['no_proxy'] = URI.parse(params[:entry_point]).host
      end
      it 'should not return proxy info' do
        ssh = SSHConnection.new(params)
        expect(ssh.find_http_proxy(params[:entry_point], params[:c_name])).to be_nil
      end
    end
    context 'When https_proxy and http_proxy are not set' do
      before do
        ENV['https_proxy'] = nil
        ENV['http_proxy'] = nil
        ENV['no_proxy'] = nil
      end
      it 'should not return proxy info' do
        ssh = SSHConnection.new(params)
        expect(ssh.find_http_proxy(params[:entry_point], params[:c_name])).to be_nil
      end
    end
  end
end
