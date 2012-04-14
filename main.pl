#!/usr/bin/perl -w

use strict;
use Pms::Application;
use PmsConfig;

sub main (){
  my $app = Pms::Application->new(\%PmsConfig::Server);    
  $app->execute();
}

main();