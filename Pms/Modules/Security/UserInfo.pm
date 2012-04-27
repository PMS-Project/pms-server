#!/usr/bin/perl -w

=begin nd

  Package: Pms::Modules::Security::UserInfo
  
  Description:
    This class represents the userinformation in the security modul.
    This includes the user database id and the rolesets the user posseses.
  
=cut

package Pms::Modules::Security::UserInfo;

=begin nd
  Constructor: new
    Initializes the Object
=cut
sub new{
  my $class = shift;
  my $self  = {};
  bless ($self, $class);
  
  $self->{m_globalRoles}  = {};
  $self->{m_channelRoles} = {};
  $self->{m_id}           = -1;
  
  return $self;
}

=begin nd
  Function: id
    Reads the userid
  
  Access:
    Public
    
  Returns:
    int - the user id from the database
=cut
sub id{
  return $_[0]->{m_id};
}

=begin nd
  Function: setId
    Sets the userid
  
  Access:
    Public
    
  Parameters:
    $id - the new userid
=cut
sub setId{
  $_[0]->{m_id} = $_[1];
}

=begin nd
  Function: setChannelRoleset
    overwrites the roleset for a channel with 
    the new one
  
  Access:
    Public
    
  Parameters:
    $channel - the name of the channel
    $roleset - the new roleset hash
=cut
sub setChannelRoleset {
  my $self = shift or die "Need Ref";;
  my $channel = shift or die "Need Channel";
  my $roleset = shift or die "Need Roleset";
  
  $self->{m_channelRoles}->{$channel} = $roleset;  
}

=begin nd
  Function: channelRoleset
    Reads the channels roleset hash
  
  Access:
    Public
    
  Parameters:
    $channel - the channel name
    
  Returns:
    hashref - the hash containing the roles
=cut
sub channelRoleset{
  my $self = shift or die "Need Ref";
  my $channel = shift or die "Need Channel";
  
  if(!defined $self->{m_channelRoles}->{$channel}){
    return {};
  }
  
  return $self->{m_channelRoles}->{$channel};
}

=begin nd
  Function: setGlobalRoleset
    overwrites the global roleset with the new
    hash
  
  Access:
    Public
    
  Parameters:
    $roleset - the new roleset
=cut
sub setGlobalRoleset {
  my $self = shift or die "Need Ref";;
  my $roleset = shift or die "Need Roleset";
  
  $self->{m_globalRoles} = $roleset;  
}

=begin nd
  Function: globalRoleset
    Reads the users global roleset
  
  Access:
    Public
    
  Returns:
    hashref - the hash containing the roleset
=cut
sub globalRoleset{
  my $self = shift or die "Need Ref";
  
  return $self->{m_globalRoles};
}

=begin nd
  Function: hasChannelRole
    Checks if the user has a specific role
  
  Access:
    Public
    
  Parameters:
    $channel - the channel name
    $role    - the name of the role we are looking for
    
  Returns:
    1 - for true
    0 - for false
=cut
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

=begin nd
  Function: addChannelRole
    adds a role to a channel roleset
  
  Access:
    Public
    
  Parameters:
    $channel - the channel we want to add the role to
    $role    - the name of the role we want to add
=cut
sub addChannelRole {
  my $self = shift or die "Need Ref";;
  my $channel = shift or die "Need Channel";
  my $role = shift or die "Need Role";
  
  if(!defined $self->{m_channelRoles}->{$channel}){
    $self->{m_channelRoles}->{$channel} = {};
  }
  $self->{m_channelRoles}->{$channel}->{$role} = 1;
}

=begin nd
  Function: removeChannelRole
    Removes a role from a channel roleset
  
  Access:
    Public
    
  Parameters:
    $channel - the channel we want to remove the role from 
    $role    - the role we want to remove
=cut
sub removeChannelRole {
  my $self = shift or die "Need Ref";;
  my $channel = shift or die "Need Channel";
  my $role = shift or die "Need Role";
  
  if(!defined $self->{m_channelRoles}->{$channel}){
    return;
  }
  delete $self->{m_channelRoles}->{$channel}->{$role};
}

=begin nd
  Function: removeChannelRoleset
    removes a complete channel roleset from the internal
    hash. The user has no more rights in the channel after
    this operation
  
  Access:
    Public
    
  Parameters:
    $channel - the channel name
=cut
sub removeChannelRoleset {
  my $self = shift or die "Need Ref";;
  my $channel = shift or die "Need Channel";
  
  if(!defined $self->{m_channelRoles}->{$channel}){
    return;
  }
  delete $self->{m_channelRoles}->{$channel};
}

=begin nd
  Function: hasGlobalRole
    checks if the user has a global role
    
  Access:
    Public
    
  Parameters:
    $role - the role we want to check
    
  Returns:
    0 - for false
    1 - for true
=cut
sub hasGlobalRole {
  my $self = shift or die "Need Ref";
  my $role = shift or die "Need Role";
  
  if(defined $self->{m_globalRoles}->{role_admin} ||
     defined $self->{m_globalRoles}->{$role} ){
      return 1;
  }
  
  return 0;
}

=begin nd
  Function: addGlobalRole
    Adds a role to the global roleset of the user
  
  Access:
    Public
    
  Parameters:
    $role - the role we want to add
=cut
sub addGlobalRole {
  my $self = shift;
  my $role = shift or die "Need Role";
  
  $self->{m_globalRoles}->{$role} = 1;
}

=begin nd
  Function: removeGlobalRole
    removes a role from the users global roleset
  
  Access:
    Public
    
  Parameters:
    $role - the role we want to remove
=cut
sub removeGlobalRole {
  my $self = shift;
  my $role = shift or die "Need Role";
  
  if(defined $self->{m_globalRoles}->{$role}){
    delete $self->{m_globalRoles}->{$role};
  }
}


1;