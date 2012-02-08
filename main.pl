#!/usr/bin/perl -w

use strict;
use Pms::Application;

sub main (){
  my $app = Pms::Application->new();
  $app->execute();
}

main();