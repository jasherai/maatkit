Name:           mysqltoolkit
Version:        @DISTRIB@
Release:        1%{?dist}
Summary:        MySQL Toolkit

Group:          Applications/Databases
License:        GPL
URL:            http://sourceforge.net/projects/mysqltoolkit/
Source0:        http://prdownloads.sourceforge.net/mysqltoolkit/%{name}-%{version}.tar.gz
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)

BuildArch:      noarch
BuildRequires:  perl-ExtUtils-MakeMaker
Requires:       perl-DBI >= 1.13, perl-DBD-MySQL >= 1.0, perl-TermReadKey >= 2.10
# perl-DBI is required by perl-DBD-MySQL anyway

%description
This toolkit contains essential command-line utilities for MySQL, such as a 
table checksum tool and query profiler. It provides missing features such as 
checking slaves for data consistency, with emphasis on quality and 
scriptability.


%prep
%setup -q


%build
%{__perl} Makefile.PL INSTALLDIRS=vendor < /dev/null
make %{?_smp_mflags}


%install
rm -rf $RPM_BUILD_ROOT
make pure_install PERL_INSTALL_ROOT=$RPM_BUILD_ROOT
find $RPM_BUILD_ROOT -type f -name .packlist -exec rm -f {} ';'
find $RPM_BUILD_ROOT -type d -depth -exec rmdir {} 2>/dev/null ';'
chmod -R u+w $RPM_BUILD_ROOT/*


%clean
rm -rf $RPM_BUILD_ROOT


%files
%defattr(-,root,root,-)
%doc COPYING INSTALL Changelog*
%{_bindir}/*
%{_mandir}/man1/*.1*
%{_mandir}/man3/*.3*
%{perl_vendorlib}/mysqltoolkit.pm


%changelog
* Tue Jun 12 2007 Sven Edge <sven@curverider.co.uk> - 547-1
- initial packaging attempt
