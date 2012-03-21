#!/usr/bin/perl -w 

package Pms::Core::Channel;
use strict;

sub new (){
  my $class = shift;
  my $self  = {};
  bless($self,$class);
  
  $self->{m_parent} = shift or die "Channel needs a Parent";
  $self->{m_name}   = shift or die "Channel needs a Name";
  $self->{m_connections} = {}; #all connections that joined the channel
  $self->{m_persistent}  = 0; #will the channel stay open after the last user has disconnected?
  
  return $self;
}

sub handleReceivedMessage(){
  my $self = shift or die "Need Ref";
  my $message = shift or die "Need Message";
  
  my $keys = keys %{ $self->{m_connections} };
  
  foreach my $k (keys %{$self->{m_connections}}){
    if(defined($self->{m_connections}{$k})){
      $self->{m_connections}{$k}->postMessage("/message \"".$self->{m_name}."\" \"".$message."\"");
    }
  } 
}

sub addConnection (){
  my $self = shift;
  my $connection = shift;
  
  #we are already in the channel
  if(defined $self->{m_connections}->{$connection->identifier()}){
    return;
  }
  
  $self->{m_connections}->{$connection->identifier()} = $connection;
  $connection->postMessage("/openwindow \"".$self->{m_name}."\"");
}

sub removeConnection() {
  my $self = shift;
  my $connection = shift;
  
  #we are not in the channel
  if(!defined $self->{m_connections}->{$connection->identifier()}){
    return;
  }
  
  delete $self->{m_connections}->{$connection->identifier()};
  $connection->postMessage("/closewindow \"".$self->{m_name}."\"");
  
}
1;