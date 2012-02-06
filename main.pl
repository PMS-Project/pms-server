#!/usr/bin/perl -w

use strict;
use PmsApplication;

sub main (){
    my $app = PmsApplication->new();
    $app->execute();
}

main();