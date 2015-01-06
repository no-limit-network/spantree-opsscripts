require 'spec_helper'

describe 'opsscripts', :type => :class do

  shared_examples_for 'a linux os' do
    context 'with default paramameters' do
      let(:params) {{ }}
      it { should compile.with_all_deps }
      it { should contain_class('opsscripts::params') }
      it { should contain_file('/usr/local/bin/backup-mongo.sh') }
      it { should contain_file('/usr/local/bin/restore-mongo.sh') }
    end
    context 'with paramameters path = "/opt/bin"' do
      let(:params) {{ :path => '/opt/bin' }}
      it { should compile.with_all_deps }
      it { should contain_class('opsscripts::params') }
      it { should contain_file('/opt/bin/backup-mongo.sh') }
      it { should contain_file('/opt/bin/restore-mongo.sh') }
    end
  end

  context 'supported operating systems' do
    ['Linux'].each do |kernel|
      describe "opsscripts class without any parameters on #{kernel}" do
        let(:facts) {{ :kernel => kernel, }}
        it_behaves_like 'a linux os' do
        end
      end
    end
  end
  context 'unsupported operating systems' do
    let(:facts) {{ :osfamily => 'xxx' }}
    it 'should fail if operating system family not supported' do
      expect { should compile }.to raise_error(/not supported/)
    end
  end
end
