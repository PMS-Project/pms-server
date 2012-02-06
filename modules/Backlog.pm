#!/usr/bin/perl -w

package Backlog;

use strict;

sub new (){
  my $class = shift;
  my $self  = {};

  $self->{m_parent} = shift;

  bless ($self, $class);
}

sub intialize (){
  
}

sub shutdown (){
  
}

1;