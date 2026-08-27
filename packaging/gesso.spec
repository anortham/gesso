Name: gesso
Version: 0.1.0
Release: 1%{?dist}
Summary: Fedora KDE add-on for theming, defaults, and coding agents
License: MIT
URL: https://github.com/anortham/gesso
Source0: %{url}/archive/v%{version}/%{name}-%{version}.tar.gz

BuildRequires: cmake
BuildRequires: extra-cmake-modules
BuildRequires: gcc-c++
BuildRequires: kf6-kirigami-devel
BuildRequires: qt6-qtbase-devel
BuildRequires: qt6-qtdeclarative-devel
BuildRequires: qt6-qtquickcontrols2-devel

Requires: bash
Requires: python3
Recommends: plasma-workspace

%description
Gesso is a Fedora KDE add-on. It ships one palette, install-then-set-default
commands, and a coding-agent picker. It is not a distro.

%package plasma
Summary: Kirigami Setup app for Gesso
Requires: gesso
Requires: kf6-kirigami
Requires: qt6-qtdeclarative
Recommends: gesso-agents

%description plasma
Kirigami Gesso Setup. Install this package for the desktop entry and GUI.
It requires the gesso CLI.

%package agents
Summary: Coding-agent extras for Gesso
Requires: gesso
Requires: mise

%description agents
Metapackage that pulls mise for Gesso coding agents. Agent commands stay
in the main gesso package.

%prep
%autosetup -n %{name}-%{version}

%build
pushd setup
%cmake
%cmake_build
popd

%install
pushd setup
%cmake_install
popd

install -d -m 0755 %{buildroot}%{_bindir}
install -p -m 0755 bin/gesso %{buildroot}%{_bindir}/gesso
install -p -m 0755 bin/gesso-* %{buildroot}%{_bindir}/

install -d -m 0755 %{buildroot}%{_datadir}/gesso
cp -a themes default data %{buildroot}%{_datadir}/gesso/

install -d -m 0755 %{buildroot}%{_datadir}/applications
install -p -m 0644 setup/org.gesso.setup.desktop %{buildroot}%{_datadir}/applications/org.gesso.setup.desktop

%files
%license LICENSE
%doc README.md
%{_bindir}/gesso
%{_bindir}/gesso-*
%{_datadir}/gesso

%files plasma
%{_libexecdir}/gesso/gesso-setup
%{_datadir}/applications/org.gesso.setup.desktop

%files agents
%license LICENSE

%changelog
* Thu Aug 27 2026 Alan Northam <anortham@gmail.com> - 0.1.0-1
- Initial package
