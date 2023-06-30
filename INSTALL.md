## Install

Note : in the following example,  fgtconfig is installed  on a unbuntu 23.04 

- Download code using git
 use **'release'** branch from github  
 The 'master' branch is mainly used for development and may not be always working.  
 `git clone -b release git://github.com/cgustave/fgtconfig.git`

~~~
root@ubuntu:/home/ubuntu# git clone -b release https://github.com/cgustave/fgtconfig.git 
Cloning into 'fgtconfig'...
remote: Enumerating objects: 116, done.
remote: Counting objects: 100% (116/116), done.
remote: Compressing objects: 100% (79/79), done.
remote: Total 116 (delta 63), reused 88 (delta 35), pack-reused 0
Receiving objects: 100% (116/116), 184.40 KiB | 899.00 KiB/s, done.
Resolving deltas: 100% (63/63), done.
root@ubuntu:/home/ubuntu# 
~~~

- Install perl 
  If not already installed from the distribution, install the perl package (apt install perl).

- Install required perl module
  Use perl CPAN install (perl -MCPAN -e shell) or more simpler, install using apt
  required modules : 
  - libmoose-perl
  - libnet-netmask-perl

example with apt
~~~
root@ubuntu:/home/ubuntu# apt install libmoose-perl libnet-netmask-perl libxml-libxml-perl
Press Y or Enter to install packages and dependancies.
~~~

- make sure PERL5LIB environment variable has fgtconfig path in the list so all cfg_*.pm can be loaded from perl.  

~~~
root@ubuntu:/home/ubuntu# cd fgtconfig/
root@ubuntu:/home/ubuntu/fgtconfig# pwd
/home/ubuntu/fgtconfig
root@ubuntu:/home/ubuntu/fgtconfig# export PERL5LIB=$PERL5LIB:/home/ubuntu/fgtconfig
~~~


- Try ./fgtconfig.pl --help

You should see the help file displayed

~~~
root@ubuntu:/home/ubuntu/fgtconfig# ./fgtconfig.pl --help

usage: fgtconfig.pl -config <filename> [ Operation selection options ]

Description: FortiGate configuration file summary, analysis, statistics and vdom-splitting tool

Input: FortiGate configuration file

Selection options:

[ Operation selection ]

   -fullstats                                                   : create report for each vdom objects for build comparison

   -splitconfig                                                 : split config in multiple vdom config archive with summary file
   -nouuid                                                      : split config option to remove all uuid keys (suggest. no)


Display options:
    -routing                                                    : display routing information section if relevant (suggest. yes)
    -ipsec                                                      : display ipsec information sections if relevant (suggest. yes)
    -stat                                                       : display some statistics (suggest. yes)
    -color                                                      : ascii colors
    -html                                                       : HTML output

    -debug                                                      : debug mode
    -ruledebug                                                  : rule parsing debug
~~~


- Test with a config file

Here, providing config /home/ubuntu/myconfig.conf
~~~
./fgtconfig.pl -config /home/ubuntu/myconfig.conf -routing -ipsec -stats

root@ubuntu:/home/ubuntu/fgtconfig# ./fgtconfig.pl -config /home/ubuntu/myconfig.conf -routing -ipsec -stats

|=============================================================================================================================================================================|
| Model  | Firmware version, build, tag  |     HA     |       Hostname       |  Fortimanager   |  Fortianalyzer  |  Fortianalyzer2 |  Fortianalyzer3 |          Nb VDOMs      |
| FGVMK6 | 7.2.4  B1396(FW )             | standalone |       spin-sl3-kvm03 |                 |                 |                 |                 |                      1 |
|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|                              Fortiguard                                    |                 |     Syslog      |     Syslog2     |     Syslog3     |       Admin users      |
| mod_hostname=no   mgmt=no   webfilter=no   antispam=no   avquery=no        |                 |                 |                 |                 | no_pwd=no  trusted=no  |
|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| warn:                                                                                                                                                                       |
|=============================================================================================================================================================================|

|====================================================================================================|
|                             Aggregate, Redundant and Switch interfaces                             |
|----------------------------------------------------------------------------------------------------|
| Interface                 |    type     | Members                                                  |
|---------------------------|-------------|----------------------------------------------------------|
| fortilink                 | aggregate   |                                                          |
|=================================+==================================================================|

|=============================================================================================================================================================================|
| vdom: [ root ]                                           opmode: nat                                                                                                        |
|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| warn: WIFI_COUNTRY_US                                                                                                                                                       |
|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|                   features: gre=no          pptp=no        l2tp=no        ssl=YES       dnstrans=no   wccp=no       icap=no                                                 |
|                   features: vip=no          vip_lb=no      vip_slb=no     centnat=no                                                                                        |
|                   features: snat=no         ipsec=no       webproxy=no    wanopt=no     gtp=no        ssync=no      client_rep=no     dev_ident=no                          |
|                   features: localinpol=no   anypol=no      mcastpol=no    geoaddr=no    fqdnaddr=YES  logdisc=YES                                                           |
|                       auth: local=no        fsso=no        ldap=no        radius=no     tacacs=no     token=no                                                              |
|                 0 policies: applist=no      ipssensor=no   av=no          webfilter=no  dnsfilter= no voip=no                                                               |
|                           : shaping=no      logtraffic=no  webcache=no    learning=no                                                                                       |
|       0 interface_policies: applist=no      ipssensor=no   DoS=no         av=no         webfilter=no  dlp=no                                                                |
|             0 DoS_policies: DoS=no                                                                                                                                          |
|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|        firewall ipv4 :   policy=0       addr=14        addrgrp=2       serv_cust=87      schedule=3       ip_pools=0       vip=0       vip_grp=0                            |
|        firewall ipv6 :   policy6=0      addr6=3        addrgrp6=0                                                                                                           |
|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| interface (alias)         | zone          | physical / flags      |  mode  | vlan |     ip address     |     network     |    broadcast    |state |PS|MO|   admin access    |
|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| fortilink                 |               | [A]                   | static |      |      10.255.1.1/24 |      10.255.1.0 |    10.255.1.255 | up   |  |  | p fabric          |
| port1                     |               |                       | static |      |       10.10.7.3/20 |       10.10.0.0 |    10.10.15.255 | up   |  |  | p hs sh hp t      |
| port2                     |               |                       | static |      |       10.5.23.3/20 |       10.5.16.0 |     10.5.31.255 | up   |  |  | p hs sh hp t      |
| port3                     |               |                       | static |      |                    |                 |                 | up   |  |  |                   |
| port4                     |               |                       | static |      |                    |                 |                 | up   |  |  |                   |
| port5                     |               |                       | static |      |                    |                 |                 | up   |  |  |                   |
| port6                     |               |                       | static |      |                    |                 |                 | up   |  |  |                   |
| port7                     |               |                       | static |      |                    |                 |                 | up   |  |  |                   |
| port8                     |               |                       | static |      |                    |                 |                 | up   |  |  |                   |
| port9                     |               |                       | static |      |                    |                 |                 | up   |  |  |                   |
| port10                    |               |                       | static |      |                    |                 |                 | up   |  |  |                   |
| naf.root                  |               | [T]                   | static |      |                    |                 |                 | up   |  |  |                   |
| l2t.root                  |               | [T]                   | static |      |                    |                 |                 | up   |  |  |                   |
| ssl.root (SSL VPN interfac|               | [T]                   | static |      |                    |                 |                 | up   |  |  |                   |
|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|  id  | subnets            | device        | gateway               |  dist  | prio | weig |    id_route=no    p_route=no    rip=no    ospf=no    isis=no    bgp=no    pim=no |
|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|    1 |          0.0.0.0/0 |         port2 |           10.5.31.254 |     10 |      |      |                                                                                  |
|=============================================================================================================================================================================|
~~~






## Q/A ?

- I have warnings like:

~~~
root@ubuntu:/home/ubuntu/fgtconfig# ./fgtconfig.pl
perl: warning: Setting locale failed.
perl: warning: Please check that your locale settings:
        LANGUAGE = "",
        LC_ALL = (unset),
        LC_ADDRESS = "fr_FR.UTF-8",
        LC_NAME = "fr_FR.UTF-8",
        LC_MONETARY = "fr_FR.UTF-8",
        LC_PAPER = "fr_FR.UTF-8",
        LC_IDENTIFICATION = "fr_FR.UTF-8",
        LC_TELEPHONE = "fr_FR.UTF-8",
        LC_MEASUREMENT = "fr_FR.UTF-8",
        LC_TIME = "fr_FR.UTF-8",
        LC_NUMERIC = "fr_FR.UTF-8",
        LANG = "en_US.UTF-8"
    are supported and installed on your system.
~~~

You may want to set LC_ALL variable like:

~~~
root@ubuntu:/home/ubuntu/fgtconfig# export LC_ALL=en_US.UTF-8
~~~






## Integration as vim plugin

This is optional. For vim users, lauching vim command :Fgtconfig while editing a configuration file, would display the config summary.  

- edit ~/,vimrc and define a command `:Fgtconfig` calling the script: 
~~~
:function! Func_fgtconfig()
:       let mycmd = "w! /tmp/fgtconfig.txt"
:       execute mycmd
:       ! (clear && cd ~/github/perl/fgtconfig && ./fgtconfig.pl -config /tmp/fgtconfig.txt -routing -ipsec -stat -color)
:endfunction
:command -nargs=0 Fgtconfig call Func_fgtconfig()
~~~

