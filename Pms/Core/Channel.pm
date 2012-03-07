#!/usr/bin/perl -w 

package Pms::Core::Channel;

sub new (){
  my $class = shift;
  my $self  = {};
  bless($self,$class);
  
  $self->{m_parent} = shift or die "Channel needs a Parent";
  $self->{m_name}   = shift or die "Channel needs a Name";
  $self->{m_connections} = (); #all connections that joined the channel
  $self->{m_persistent}  = 0; #will the channel stay open after the last user has disconnected?
  
  return $self;
}

sub addConnection (){
  my $self = shift;
  my $connection = shift;
  
  $self->{m_connections}{$connection} = $connection;
}

sub removeConnection() {
  my $self = shift;
  my $connection = shift;
  
  delete $self->{m_connections}{$connection};
  
}


1;