#!/usr/bin/perl -w
=begin nd

  Package: PmsConfig
  
  Description:
  This is the configuration file of the pms-server.
  It is written and perl and is directly interpreted by the
  application.
    
  Here its possible to configure the ConnectionProviders and 
  the Modules
=cut
package PmsConfig;

use strict;
use utf8;
use Data::Dumper;

=begin nd
  var: @connectionProviders
  
  Description:
  Contains all ConnectionProviders that are loaded at startup time.
  
=cut
my @connectionProviders = (
  {
    name   => "Pms::Net::WebSocket::ConnectionProvider", #the name of the plugin
    config => {                                          #the specific config hash
      port => 8888
    }
  }
);

=begin nd
  var: %baseDBHash
  
  Description:
    The basic database hash for all modules
=cut
my %baseDBHash = (
  db_host     => "localhost",
  db_database => "pms",
  db_user     => "pms",
  db_pass     => "secret"  
);

=begin nd
  var: @modules
  
  Description:
    Contains all modules that are loaded at startup time.
=cut
my @modules = (
  {
    name     => "Pms::Modules::Backlog", #The name of the plugin
    requires => undef,                   #which other modules are required
    config   => \%baseDBHash             #the specific module config hash
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

=begin nd
  var: %Server
  This is the main config Hash, its directly passed to the server.
  It requires two elements:
  
  connectionProviders:
    This is the element that contains a array of all connectionProviders
    
    the Server should load at startup.
    
  modules:
    This element contains all modules that are loaded at startup.
    
    Every Module can depend on other modules and has its own config hash.
=cut
our %Server = (
    connectionProviders => \@connectionProviders,
    modules             => \@modules
);  

return 1;
