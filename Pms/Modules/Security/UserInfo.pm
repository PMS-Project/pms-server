#!/usr/bin/perl -w

package Pms::Modules::Security::UserInfo;

sub new{
  my $class = shift;
  my $self  = {};
  bless ($self, $class);
  
  $self->{m_globalRoles}  = {};
  $self->{m_channelRoles} = {};
  $self->{m_id}           = -1;
  
  return $self;
}

sub id{
  return $_[0]->{m_id};
}

sub setId{
  $_[0]->{m_id} = $_[1];
}


sub setChannelRoleset {
  my $self = shift or die "Need Ref";;
  my $channel = shift or die "Need Channel";
  my $roleset = shift or die "Need Roleset";
  
  $self->{m_channelRoles}->{$channel} = $roleset;  
}

sub channelRoleset{
  my $self = shift or die "Need Ref";
  my $channel = shift or die "Need Channel";
  
  if(!defined $self->{m_channelRoles}->{$channel}){
    return {};
  }
  
  return $self->{m_channelRoles}->{$channel};
}

sub setGlobalRoleset {
  my $self = shift or die "Need Ref";;
  my $roleset = shift or die "Need Roleset";
  
  $self->{m_globalRoles} = $roleset;  
}

sub globalRoleset{
  my $self = shift or die "Need Ref";
  
  return $self->{m_globalRoles};
}

sub hasChannelRole {
  my $self = shift or die "Need Ref";
  my $channel = shift or die "Need Channel";
  my $role = shift or die "Need Role";
  
  if(!defined $self->{m_channelRoles}->{$channel}){
    return 0;
  }
  
  if(defined $self->{m_channelRoles}->{$channel}->{role_admin}        ||
     defined $self->{m_channelRoles}->{$channel}->{role_channelAdmin} ||
     defined $self->{m_channelRoles}->{$channel}->{$role} ){
      return 1;
  }
  
  return 0;
}

sub addChannelRole {
  my $self = shift or die "Need Ref";;
  my $channel = shift or die "Need Channel";
  my $role = shift or die "Need Role";
  
  if(!defined $self->{m_channelRoles}->{$channel}){
    $self->{m_channelRoles}->{$channel} = {};
  }
  $self->{m_channelRoles}->{$channel}->{$role} = 1;
}

sub removeChannelRole {
  my $self = shift or die "Need Ref";;
  my $channel = shift or die "Need Channel";
  my $role = shift or die "Need Role";
  
  if(!defined $self->{m_channelRoles}->{$channel}){
    return;
  }
  delete $self->{m_channelRoles}->{$channel}->{$role};
}

sub removeChannelRoleset {
  my $self = shift or die "Need Ref";;
  my $channel = shift or die "Need Channel";
  
  if(!defined $self->{m_channelRoles}->{$channel}){
    return;
  }
  delete $self->{m_channelRoles}->{$channel};
}

sub hasGlobalRole {
  my $self = shift or die "Need Ref";
  my $role = shift or die "Need Role";
  
  if(defined $self->{m_globalRoles}->{role_admin} ||
     defined $self->{m_globalRoles}->{$role} ){
      return 1;
  }
  
  return 0;
}

sub addGlobalRole {
  my $self = shift;
  my $role = shift or die "Need Role";
  
  $self->{m_globalRoles}->{$role} = 1;
}

sub removeGlobalRole {
  my $self = shift;
  my $role = shift or die "Need Role";
  
  if(defined $self->{m_globalRoles}->{$role}){
    delete $self->{m_globalRoles}->{$role};
  }
}


1;