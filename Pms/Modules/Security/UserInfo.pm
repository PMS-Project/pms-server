#!/usr/bin/perl -w

=begin nd

  Package: Pms::Modules::Security::UserInfo
  
  Description:
  
=cut

package Pms::Modules::Security::UserInfo;

=begin nd
  Constructor: new
    Initializes the Object
    
  Parameters:
    xxxx - description
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
    <function_description>
  
  Access:
    Public
    
  Parameters:
    
  Returns:
    xxxx
=cut
sub id{
  return $_[0]->{m_id};
}

=begin nd
  Function: setId
    <function_description>
  
  Access:
    Public
    
  Parameters:
    
  Returns:
    xxxx
=cut
sub setId{
  $_[0]->{m_id} = $_[1];
}

=begin nd
  Function: setChannelRoleset
    <function_description>
  
  Access:
    Public
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
=cut
sub setChannelRoleset {
  my $self = shift or die "Need Ref";;
  my $channel = shift or die "Need Channel";
  my $roleset = shift or die "Need Roleset";
  
  $self->{m_channelRoles}->{$channel} = $roleset;  
}

=begin nd
  Function: channelRoleset
    <function_description>
  
  Access:
    Public
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
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
    <function_description>
  
  Access:
    Public
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
=cut
sub setGlobalRoleset {
  my $self = shift or die "Need Ref";;
  my $roleset = shift or die "Need Roleset";
  
  $self->{m_globalRoles} = $roleset;  
}

=begin nd
  Function: globalRoleset
    <function_description>
  
  Access:
    Public
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
=cut
sub globalRoleset{
  my $self = shift or die "Need Ref";
  
  return $self->{m_globalRoles};
}

=begin nd
  Function: hasChannelRole
    <function_description>
  
  Access:
    Public
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
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
    <function_description>
  
  Access:
    Public
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
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
    <function_description>
  
  Access:
    Public
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
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
    <function_description>
  
  Access:
    Public
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
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
    <function_description>
  
  Access:
    Public
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
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
    <function_description>
  
  Access:
    Public
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
=cut
sub addGlobalRole {
  my $self = shift;
  my $role = shift or die "Need Role";
  
  $self->{m_globalRoles}->{$role} = 1;
}

=begin nd
  Function: removeGlobalRole
    <function_description>
  
  Access:
    Public
    
  Parameters:
    xxxx - description
    
  Returns:
    xxxx
=cut
sub removeGlobalRole {
  my $self = shift;
  my $role = shift or die "Need Role";
  
  if(defined $self->{m_globalRoles}->{$role}){
    delete $self->{m_globalRoles}->{$role};
  }
}


1;