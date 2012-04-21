#!/usr/bin/perl -w

package Pms::Core::ConnectionProvider;

use strict;
use utf8;
use Pms::Core::Object;

our @ISA = qw(Pms::Core::Object);
our %PmsEvents = ('connectionAvailable' => 1);

sub new {
  my $class = shift;
  my $self = $class->SUPER::new( );
  
  bless($self,$class);
  
  $self->{m_parent} = shift or die "needs a reference to parent";
  $self->{m_connectionQueue} = [];
  
  return $self;
  
}

sub nextConnection{
  my $self = shift or die "No Ref";
  
  my $connection = shift(@{ $self->{m_connectionQueue} });
  return $connection;
}

sub connectionsAvailable{
  my $self = shift or die "No Ref";
  my $count = @{ $self->{m_connectionQueue} };
  return $count;
}

1;