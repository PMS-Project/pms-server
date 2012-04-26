#!/usr/bin/perl -w

use strict;
use utf8;
use Pms::Application;
use PmsConfig;

=begin nd
  Function: main
    <function_description>
  
  Access:
    Public
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
=cut
sub main (){
  my $app = Pms::Application->new(\%PmsConfig::Server);    
  $app->execute();
}

main();