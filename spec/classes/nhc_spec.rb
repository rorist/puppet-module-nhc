require 'spec_helper'

describe 'nhc' do
  on_supported_os({
    :supported_os => [
      {
        "operatingsystem" => "CentOS",
        "operatingsystemrelease" => ["5", "6", "7"],
      }
    ]
  }).each do |os, facts|
    context "on #{os}" do
      let(:facts) { facts }

      it { should create_class('nhc') }
      it { should contain_class('nhc::params') }

      it { should contain_anchor('nhc::start').that_comes_before('Class[nhc::install]') }
      it { should contain_class('nhc::install').that_comes_before('Class[nhc::config]') }
      it { should contain_class('nhc::config').that_comes_before('Anchor[nhc::end]') }
      it { should contain_anchor('nhc::end') }

      context "nhc::install" do
        it do
          should contain_package("lbnl-nhc-1.4.2-1.el#{facts[:operatingsystemmajrelease]}.noarch").only_with({
            :ensure   => 'installed',
            :name     => "lbnl-nhc-1.4.2-1.el#{facts[:operatingsystemmajrelease]}.noarch",
            :source   => "https://github.com/mej/nhc/releases/download/1.4.2/lbnl-nhc-1.4.2-1.el#{facts[:operatingsystemmajrelease]}.noarch.rpm",
            :provider => 'rpm',
          })
        end

        context 'when install_from_repo defined' do
          let(:params) {{ :install_from_repo => 'local' }}
          let(:pre_condition) {
            "yumrepo { 'local':
              descr     => 'local',
              baseurl   => 'file:///dne',
              gpgcheck  => '0',
              enabled   => '1',
            }"
          }

          it do
            should contain_package('lbnl-nhc').only_with({
              :ensure   => "1.4.2-1.el#{facts[:operatingsystemmajrelease]}",
              :name     => 'lbnl-nhc',
              :provider => 'yum',
              :require  => 'Yumrepo[local]'
            })
          end

          context 'when package_ensure => "latest"' do
            let(:params) {{ :install_from_repo => 'local', :package_ensure => "latest" }}
            let(:pre_condition) {
              "yumrepo { 'local':
                descr     => 'local',
                baseurl   => 'file:///dne',
                gpgcheck  => '0',
                enabled   => '1',
              }"
            }

            it { should contain_package('lbnl-nhc').with_ensure('latest') }
          end
        end

        context 'when ensure => "absent"' do
          let(:params) {{ :ensure => "absent" }}
          it { should contain_package("lbnl-nhc-1.4.2-1.el#{facts[:operatingsystemmajrelease]}.noarch").with_ensure('absent') }
        end
      end

      context "nhc::config" do
        it do
          should contain_file('/etc/nhc').with({
            :ensure  => 'directory',
            :path    => '/etc/nhc',
            :owner   => 'root',
            :group   => 'root',
            :mode    => '0700',
          })
        end

        it do
          should contain_file('/etc/nhc/nhc.conf').with({
            :ensure   => 'file',
            :path     => '/etc/nhc/nhc.conf',
            :owner    => 'root',
            :group    => 'root',
            :mode     => '0644',
            :require  => 'File[/etc/nhc]',
          })
        end

        it do
          verify_exact_contents(catalogue, '/etc/nhc/nhc.conf', [])
        end

        it do
          should contain_file('/etc/nhc/scripts').with({
            :ensure   => 'directory',
            :path     => '/etc/nhc/scripts',
            :owner    => 'root',
            :group    => 'root',
            :mode     => '0700',
            :require  => 'File[/etc/nhc]',
          })
        end

        it do
          should contain_file('/etc/sysconfig/nhc').with({
            :ensure   => 'file',
            :path     => '/etc/sysconfig/nhc',
            :owner    => 'root',
            :group    => 'root',
            :mode     => '0644',
          })
        end

        it do
          verify_exact_contents(catalogue, '/etc/sysconfig/nhc', [
            'CONFDIR=/etc/nhc',
            'CONFFILE=/etc/nhc/nhc.conf',
            'DETACHED_MODE=0',
            'DETACHED_MODE_FAIL_NODATA=0',
            'INCDIR=/etc/nhc/scripts',
            'NAME=nhc',
          ])
        end

        it 'should manage logrotate::rule[nhc]' do
          should contain_logrotate__rule('nhc').with({
            :ensure       => 'present',
            :path         => '/var/log/nhc.log',
            :missingok    => 'true',
            :ifempty      => 'false',
            :rotate_every => 'weekly',
          })
        end

        it 'File[/etc/logrotate.d/nhc] should have valid contents' do
          verify_contents(catalogue, '/etc/logrotate.d/nhc', [
            '/var/log/nhc.log {',
            '  missingok',
            '  notifempty',
            '  weekly',
            '}',
          ])
        end

        context 'when detached_mode => true' do
          let(:params) {{ :detached_mode => true }}
          it { verify_contents(catalogue, '/etc/sysconfig/nhc', ['DETACHED_MODE=1']) }
        end

        context 'when detached_mode_fail_nodata => true' do
          let(:params) {{ :detached_mode_fail_nodata => true }}
          it { verify_contents(catalogue, '/etc/sysconfig/nhc', ['DETACHED_MODE_FAIL_NODATA=1']) }
        end

        context 'when config_overrides is defined' do
          let(:params) do
            {
              :config_overrides => {
                'HOSTNAME'  => '$HOSTNAME_S',
              }
            }
          end

          it { verify_contents(catalogue, '/etc/sysconfig/nhc', ['HOSTNAME=$HOSTNAME_S']) }
        end

        context 'when settings is defined' do
          let(:params) do
            {
              :settings => {
                'HOSTNAME'  => '$HOSTNAME_S',
              }
            }
          end

          it { verify_contents(catalogue, '/etc/nhc/nhc.conf', ['* || export HOSTNAME=$HOSTNAME_S']) }
        end

        context 'when checks defined as an Array' do
          let(:params) do
            {
              :checks => [
                'check_fs_mount_rw -f /',
                'check_fs_mount_rw -t tmpfs -f /tmp',
              ]
            }
          end

          it do
            verify_exact_contents(catalogue, '/etc/nhc/nhc.conf', [
              '* || check_fs_mount_rw -f /',
              '* || check_fs_mount_rw -t tmpfs -f /tmp',
            ])
          end
        end

        context 'when checks defined as a Hash' do
          let(:params) do
            {
              :checks => {
                '*' => [
                  'check_fs_mount_rw -f /',
                  'check_fs_mount_rw -t tmpfs -f /tmp',
                ],
                'foo.bar' => [
                  'check_hw_physmem_free 1MB',
                ],
                'foo.baz' => 'check_hw_swap_free 1MB',
              }
            }
          end

          it do
            content = catalogue.resource('file', '/etc/nhc/nhc.conf').send(:parameters)[:content]
            pp content.split(/\n/)
            verify_exact_contents(catalogue, '/etc/nhc/nhc.conf', [
              '* || check_fs_mount_rw -f /',
              '* || check_fs_mount_rw -t tmpfs -f /tmp',
              'foo.bar || check_hw_physmem_free 1MB',
              'foo.baz || check_hw_swap_free 1MB',
            ])
          end
        end

        context 'when ensure => "absent"' do
          let(:params) {{ :ensure => "absent" }}
          it { should contain_file('/etc/nhc').with_ensure('absent') }
          it { should contain_file('/etc/nhc/nhc.conf').with_ensure('absent') }
          it { should contain_file('/etc/nhc').with_ensure('absent') }
          it { should contain_file('/etc/sysconfig/nhc').with_ensure('absent') }
          it { should contain_logrotate__rule('nhc').with_ensure('absent') }
        end
      end

      context 'when ensure => "foo"' do
        let(:params) {{ :ensure => 'foo' }}
        it "should raise an error" do
          expect { should compile }.to raise_error(/Module nhc: ensure parameter must be 'present' or 'absent', foo given./)
        end
      end

      context "with checks => 'foo'" do
        let(:params) {{ :checks => 'foo' }}
        it "should raise an error" do
          expect { should compile }.to raise_error(/Module nhc: checks parameter must be a Hash or an Array./)
        end
      end

      # Test validate_bool parameters
      [
        :detached_mode,
        :detached_mode_fail_nodata,
        :manage_logrotate,
      ].each do |param|
        context "with #{param} => 'foo'" do
          let(:params) {{ param.to_sym => 'foo' }}
          it "should raise an error" do
            expect { should compile }.to raise_error(/is not a boolean/)
          end
        end
      end

      # Test validate_hash parameters
      [
        :settings,
        :config_overrides,
      ].each do |param|
        context "with #{param} => 'foo'" do
          let(:params) {{ param.to_sym => 'foo' }}
          it "should raise an error" do
            expect { should compile }.to raise_error(/is not a Hash/)
          end
        end
      end
    end # end os context
  end # end on_supported_os
end # end describe nhc
