[![License](http://img.shields.io/:license-apache-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0.html) [![Build Status](https://travis-ci.org/simp/pupmod-simp-svckill.svg)](https://travis-ci.org/simp/pupmod-simp-svckill) [![SIMP compatibility](https://img.shields.io/badge/SIMP%20compatibility-4.2.*%2F5.1.*-orange.svg)](https://img.shields.io/badge/SIMP%20compatibility-4.2.*%2F5.1.*-orange.svg)

#### Table of Contents

1. [Overview](#this-is-a-simp-module)
2. [Module Description - A Puppet module for managing svckill](#module-description)
3. [Setup - The basics of getting started with pupmod-simp-svckill](#setup)
    * [What pupmod-simp-svckill affects](#what-simp-svckill-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with svckill](#beginning-with-svckill)
4. [Usage - Configuration options and additional functionality](#usage)
5. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
5. [Limitations - OS compatibility, etc.](#limitations)
6. [Development - Guide for contributing to the module](#development)

## This is a SIMP module
This module is a component of the
[System Integrity Management Platform](https://github.com/NationalSecurityAgency/SIMP),
a compliance-management framework built on Puppet.

If you find any issues, they can be submitted to our
[JIRA](https://simp-project.atlassian.net/).

Please read our [Contribution Guide](https://simp-project.atlassian.net/wiki/display/SD/Contributing+to+SIMP)
and visit our [developer wiki](https://simp-project.atlassian.net/wiki/display/SD/SIMP+Development+Home).

This module is optimally designed for use within a larger SIMP ecosystem, but it
can be used independently:
* When included within the SIMP ecosystem, security compliance settings will be
managed from the Puppet server.
* In the future, all SIMP-managed security subsystems will be disabled by
default and must be explicitly opted into by administrators.  Please review
*simp/simp_options* for details.

## Module Description

Svckill is a system that attempts to run with the security best practice that
"No unnecessary services should be running on the system."

The way svckill works is to fetch all services on the running system and then
shutdown and disable any that are not declared in a Puppet manifest (or ignore
list/file) somewhere.

## Setup

### What simp svckill affects

*simp/svckill* effects ALL services on a given node. If this class is included
on a node, all services not declared in a puppet service resource or a svckill
ignore list will be disabled and turned off on a system. The following are
exceptions:

```
    The following services are hard coded to never be killed by svckill:
      * amtu
      * blk-availability
      * crond
      * ebtables
      * gpm
      * haldaemon
      * ip6tables
      * iptables
      * irqbalance
      * killall
      * libvirt-guests
      * lvm2-monitor
      * mcstrans
      * mdmonitor
      * messagebus
      * netcf-transaction
      * netfs
      * netlabel
      * network
      * ntpdate
      * portreserve
      * puppet
      * restorecond
      * sandbox
      * sshd
      * sysstat
      * udev-post
      * getty*
      * dbus*

   These are here because their status function is broken
      * krb524
      * mdmpd
      * readahead_later
      * rawdevices
      * lm_sensors
      * kudzu
```

### Setup Requirements

### Beginning with svckill

You can set up svckill on a node by:

```puppet
include 'svckill'
```

## Usage

### I have a service I don't want puppet to kill on a single node

There are two ways to solve this problem:

Declare the service in puppet:

```puppet
service { 'myservice':
  ensure => running,
}
```

or Declare the service in an ignore list in svckill:

```puppet
svckill { 'myservice':
  ignore => ['myservice'],
}
```

### I want to ignore a list of services I deploy in a file

```puppet
svckill { 'ourservices':
  ignorefiles => '/opt/services',
}
```

### I want to set a list of services allowed in my entire infrascture

```puppet
site.pp

class { 'svckill':
  ignore => ['A',
             'B',
             'C'
            ],
}
```

### I don't want to kill a service, but I'd like to be alerted when it is running

```puppet
class { 'svckill':
  ignore => 'A',
  mode   => 'warning',
}
```

## Reference

### Types
* ['svckill'](#svckill-type): Type used to declare services to ignore.

### Public Classes
* ['svckill'](#svckill-class): Main class used to set up a set of default
services to ignore in an infrastructure.
* ['svckill::ignore'](#svckillignore): Ensure a service will not be killed by
svckill
* ['svckill::ignore::collector'](#svckillignorecollector): Build default ignore
file for svckill

### `svckill` Type

#### Parameters

##### ignore
  An array of services to never kill. Can also accept a regex.
  * Valid Options: Array of Strings.

##### ignorefiles
  An array of files containing a list of services to ignore, one
per line. Can also accept regexes in the file.
  * Valid Options: Array of Strings.
  * Default: `/usr/local/etc/svckill.ignore`

##### verbose
  If set, output all services that were affected by svckill.
  * Valid Options: true or false.
  * Default: `true`

##### mode
  If set to 'enforcing', will actually shut down and disable all
services not listed in your manifests or the exclusion file. If set to
'warning', will only report on what would happen without actually making the
changes to the system.
  * Valid Options: enforcing and warning.
  * Default: `enforcing`.

### `svckill` Class

#### Parameters

##### ignore
  An array of services to never kill. Can also accept a regex.
  * Valid Options: Array of Strings.
  * Default: `[]`.

##### ignore_defaults
  An internal list of embedded services to never kill.
  * Valid Options: Array of Strings.
  * Default: `[]`.

##### ignore_files
  An array of files containing a list of services to ignore, one
per line. Can also accept regexes in the file.
  * Valid Options: Array of Strings.
  * Default: `[]`.

##### verbose
  If set, output all services that were affected by svckill.
  * Valid Options: true or false.
  * Default: `true`

##### mode
  If set to 'enforcing', will actually shut down and disable all
services not listed in your manifests or the exclusion file. If set to
'warning', will only report on what would happen without actually making the
changes to the system.
  * Valid Options: enforcing and warning.
  * Default:`enforcing`.

### `svckill::ignore`

#### Parameters

##### name
  Name of service to ignore with svckill.
  * Valid Options: String.

### `svckill::ignore::collector`

#### Parameters

##### default_ignore_file
  Path to ignore file.
  * Valid Options: Absolute Path.
  * Default: `/usr/local/etc/svckill.ignore`.

## Limitations

This module is only designed to work in RHEL or CentOS 6 and 7. Any other
operating systems have not been tested and results cannot be guaranteed.

# Development

Please see the
[SIMP Contribution Guidelines](https://simp-project.atlassian.net/wiki/display/SD/Contributing+to+SIMP).

General developer documentation can be found on
[Confluence](https://simp-project.atlassian.net/wiki/display/SD/SIMP+Development+Home).
Visit the project homepage on [GitHub](https://simp-project.com),
chat with us on our [HipChat](https://simp-project.hipchat.com/),
and look at our issues on  [JIRA](https://simp-project.atlassian.net/).
