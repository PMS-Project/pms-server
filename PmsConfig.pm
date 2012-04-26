#!/usr/bin/perl -w

package PmsConfig;

use strict;
use utf8;
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
    name     => "Pms::Modules::Stats",
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
    config   => "----- Welcome to the P.M.S Testserver -----\n"
               ."           Please Respect our Rules\n"
  },
  {
    name     => "Pms::Modules::Security::Module",
    requires => undef,
    config   => \%baseDBHash
  }
);

our %Server = (
    connectionProviders => \@connectionProviders,
    modules             => \@modules
);  

return 1;
