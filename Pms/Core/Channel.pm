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

sub _connectionForIdent(){
  my $self = shift or die "Need Ref";
  my $key  = shift or die "Need Key";
  
  return $self->{m_connections}->{$key}->{"object"};
}

sub sendMessage(){
  my $self = shift or die "Need Ref";
  my $who  = shift or die "Need a username";
  my $when = shift or die "Need a when";
  my $message = shift or die "Need Message";
  
  
  my $keys = keys %{ $self->{m_connections} };
  
  foreach my $k (keys %{$self->{m_connections}}){
    if(defined($self->{m_connections}->{$k})){
       $self->_connectionForIdent($k)->postMessage("/message \"".$self->{m_name}."\" \"".$who."\" ".$when." \"".$message."\"");
    }
  } 
}

sub sendChannelMessage(){
  my $self = shift or die "Need Ref";  
  my $message = shift or die "Need Message";
  
  my $keys = keys %{ $self->{m_connections} };
  
  foreach my $k (keys %{$self->{m_connections}}){
    if(defined($self->{m_connections}->{$k})){
       $self->_connectionForIdent($k)->postMessage("/serverMessage \"".$self->{m_name}."\" \"".$message."\"");
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
  
  my $stuff= { "eventguard" => $connection->connect("disconnect" => $self->_disconnectCallback(),"change_username" => $self->_changeUsernameCallback()),
               "object"     => $connection
  };
  
  
  $self->{m_connections}->{$connection->identifier()} = $stuff;
  $connection->postMessage("/openwindow \"".$self->{m_name}."\"");
}

sub _disconnectCallback(){
  my $self = shift;
  return sub{
    my $connection = shift;
    $self->removeConnection($connection);
  }
}

sub _changeUsernameCallback(){
  my $self = shift;
  return sub{
    my $connection = shift;
    my $oldname = shift;
    my $newname = shift;
    
    $self->sendChannelMessage("User ".$oldname." is now named ".$newname);
  }
}

sub removeConnection() {
  my $self = shift;
  my $connection = shift;
  
  my $ident = $connection->identifier();
  
  #we are not in the channel
  if(!defined $self->{m_connections}->{$ident}){
    return;
  }
  
  $connection->disconnect($self->{m_connections}->{$ident}->{"eventguard"});
  
  delete $self->{m_connections}->{$connection->identifier()};
  
  #TODO check if connection is still open 
  $connection->postMessage("/closewindow \"".$self->{m_name}."\"");
  
  $self->sendChannelMessage("Client ".$connection->username()." disconnected");
}
1;