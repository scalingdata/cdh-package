# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

%define lib_llama /usr/lib/llama
%define etc_llama /etc/llama
%define run_llama /var/run/llama
%define log_llama /var/log/llama
%define hadoop_home /usr/lib/hadoop
%define state_llama /var/lib/llama

%if  %{?suse_version:1}0
%define initd_dir %{_sysconfdir}/rc.d
%define alternatives_cmd update-alternatives
%define alternatives_dep update-alternatives
%else
%define initd_dir %{_sysconfdir}/rc.d/init.d
%define alternatives_cmd alternatives
%define alternatives_dep chkconfig 
%endif

# disable repacking jars
%define __os_install_post %{nil}

Name: llama
Version: %{llama_version}
Release: %{llama_release}
Summary: Low Latency Application Master for running Impala on YARN
URL: http://cloudera.com/llama
Group: Development/Libraries
BuildArch: noarch
Buildroot: %(mktemp -ud %{_tmppath}/llama-%{version}-%{release}-XXXXXX)
License: ASL 2.0
Source0: llama-%{llama_patched_version}.tar.gz
Source1: do-component-build 
Source2: install_llama.sh
Source3: llama.default
Source4: llama.svc
Source5: init.d.tmpl
Source6: packaging_functions.sh
Requires: hadoop-yarn
Requires(post): %{alternatives_dep}
Requires(preun): %{alternatives_dep}

%description
 Llama is a low-latency application master for hosting applications like Impala on a YARN cluster.
 This package should be installed on every node in the YARN / Impala cluster.

%prep
%setup -n llama-%{llama_patched_version}

%build
env FULL_VERSION=%{llama_patched_version} bash $RPM_SOURCE_DIR/do-component-build

%install
%__rm -rf $RPM_BUILD_ROOT
bash $RPM_SOURCE_DIR/install_llama.sh \
          --distro-dir=$RPM_SOURCE_DIR \
          --build-dir=./ \
          --prefix=$RPM_BUILD_ROOT \
          --extra-dir=$RPM_SOURCE_DIR
bash $RPM_SOURCE_DIR/init.d.tmpl $RPM_SOURCE_DIR/llama.svc rpm $RPM_BUILD_ROOT/%{initd_dir}/llama

%package master
Summary: Scripts for running the Llama Application Master
Group: System/Daemons
BuildArch: noarch
Requires: llama

%description master
 This package provides an init script and chkconfig configuration for managing the Llama Application Master service

# Documentation
%package doc
Summary: Documentation for Llama
Group: Documentation

%description doc
This package provides documentation for Llama

%pre
getent group llama >/dev/null || groupadd -r llama
getent passwd llama > /dev/null || useradd -c "Llama" -s /bin/bash -g llama -d %{state_llama} llama 2> /dev/null || :

%post
%{alternatives_cmd} --install %{etc_llama}/conf llama-conf %{etc_llama}/conf.dist 30

%preun
if [ "$1" = 0 ]; then
    %{alternatives_cmd} --remove llama-conf %{etc_llama}/conf.dist || :
fi

%post master
chkconfig --add llama

%preun master
if [ $1 = 0 ] ; then
    service llama stop > /dev/null 2>&1
    chkconfig --del llama
fi

%postun master
if [ $1 -ge 1 ]; then
    service llama condrestart >/dev/null 2>&1
fi

#######################
#### FILES SECTION ####
#######################
%files
%defattr(-,root,root,755)
%attr(755, root, root) /usr/bin/*
%config(noreplace) %{etc_llama}/conf.dist
%config(noreplace) /etc/default/llama
%{lib_llama}
%defattr(-,llama,llama,755)
%{log_llama}
%{run_llama}
%{state_llama}

%files master
%attr(755, root, root) %{initd_dir}/llama

%files doc
%attr(0755,root,root) /usr/share/doc/llama

