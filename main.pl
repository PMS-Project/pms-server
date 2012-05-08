#!/usr/bin/perl -w
=begin nd
  Script: main.pl
  
  Description:
    This is the entry script for out application.
    The Script just creates the <Pms::Application> object
    and executes the mainloop.
=cut

use strict;
use utf8;
use Pms::Application;
use PmsConfig;

=begin nd
  Function: main
  
  Description:
    Initializes and starts the server application
=cut
sub main{
  my $app = Pms::Application->new(\%PmsConfig::Server);    
  $app->execute();
}
main();