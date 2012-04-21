#!/usr/bin/perl -w

package PmsConfig;

use strict;
use Data::Dumper;

my @connectionProviders = (
  {
    name   => "Pms::Net::WebSocket::ConnectionProvider",
    config => {
      port => 8888
    }
  }
);

my %baseDBHash = (
  db_host     => "localhost",
  db_database => "pms",
  db_user     => "pms",
  db_pass     => "secret"  
);

my @modules = (
  {
    name     => "Pms::Modules::Database",
    requires => undef,
    config   => \%baseDBHash
  },
  {
    name     => "Pms::Modules::Backlog",
    requires => undef,
    config   => \%baseDBHash
  },
  {
    name     => "Pms::Modules::Motd",
    requires => undef,
    config   => \%baseDBHash
  },
  {
    name     => "Pms::Modules::Security",
    requires => undef,
    config   => \%baseDBHash
  }
);

our %Server = (
    connectionProviders => \@connectionProviders,
    modules             => \@modules
);  

return 1;
