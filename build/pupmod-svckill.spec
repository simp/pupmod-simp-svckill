Summary: Svckill Puppet Module
Name: pupmod-svckill
Version: 1.0.0
Release: 5
License: Apache License, Version 2.0
Group: Applications/System
Source: %{name}-%{version}-%{release}.tar.gz
Buildroot: %{_tmppath}/%{name}-%{version}-%{release}-buildroot
Requires: puppet >= 3.3.0
Buildarch: noarch
Requires: simp-bootstrap >= 4.2.0
Obsoletes: pupmod-timezone
Obsoletes: pupmod-svckill-test

Prefix: /etc/puppet/environments/simp/modules

%description
This Puppet module provides the capability to disable all services on
a system that are not controlled by Puppet.

Several methods for excluding services from the kill list are
provided.

%prep
%setup -q

%build

%install
[ "%{buildroot}" != "/" ] && rm -rf %{buildroot}

mkdir -p %{buildroot}/%{prefix}/svckill

dirs='files lib manifests templates'
for dir in $dirs; do
  test -d $dir && cp -r $dir %{buildroot}/%{prefix}/svckill
done

%clean
[ "%{buildroot}" != "/" ] && rm -rf %{buildroot}

mkdir -p %{buildroot}/%{prefix}/svckill

%files
%defattr(0640,root,puppet,0750)
%{prefix}/svckill

%post
#!/bin/sh

if [ -d /etc/puppet/environments/simp/modules/svckill/plugins ]; then
  /bin/mv /etc/puppet/environments/simp/modules/svckill/plugins /etc/puppet/environments/simp/modules/common/plugins.bak
fi

%postun
# Post uninstall stuff

%changelog
* Tue Nov 10 2015 Chris Tessmer <chris.tessmer@onypoint.com> - 1.0.0-5
- migration to simplib and simpcat (lib/ only)

* Fri Jan 16 2015 Trevor Vaughan <tvaughan@onyxpoint.com> - 1.0.0-4
- Changed puppet-server requirement to puppet

* Thu Aug 28 2014 Trevor Vaughan <tvaughan@onyxpoint.com> - 1.0.0-3
- Fixed a long-standing bug where failing to stop a service would
  prevent svckill from disabling it.
- Added prefdm to the list of services to never kill.
- Updated to not kill services that have definitions in puppet that
  are aliased in systemd.

* Thu Jun 19 2014 Trevor Vaughan <tvaughan@onyxpoint.com> - 1.0.0-2
- Added support for systemd
- Added support for regex ignore statements
- Had to force the service provider to 'redhat' if it fell back to
  'init' otherwise the startup scripts wouldn't be called

* Fri May 09 2014 Trevor Vaughan <tvaughan@onyxpoint.com> - 1.0.0-1
- Add 'rc' to the svckill list so that weird race conditions don't
  render an Upstart-based system unbootable.

* Wed Apr 16 2014 Trevor Vaughan <tvaughan@onyxpoint.com> - 1.0.0-0
- First release of svckill as its own module.
