#!/usr/bin/perl -w 

package Pms::Core::Connection;

sub new (){
  my $class = shift;
  my $self  = {};
  bless($self,$class);
  
  $self->{m_handle} = shift or die "Connection needs a Handle Value";
  $self->{m_host}   = shift or die "Connection needs a Host Value";
  $self->{m_port}   = shift or die "Connection needs a Port Value";
  $self->{m_user}   = undef;
  
  return $self;
}
