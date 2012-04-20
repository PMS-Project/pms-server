#!/usr/bin/perl -w

package Pms::Modules::Security;

use strict;
use Pms::Event::Connect;
use Pms::Core::Connection;
use Pms::Prot::Messages;
use AnyEvent;
use AnyEvent::DBI;
use Data::Dumper;

#the default global rules for a user
our %defaultRuleset = (
  role_create_channel => 1
);

#the default channel rights for the channel creator
our %defaultChannelCreatorRuleset = (
  role_channelAdmin => 1
);

#the default channel rules for a normal user
our %defaultChannelRuleset = (
  is_default_ruleset => 1,
  role_join_channel => 1,
  role_can_speak    => 1
);

#our %users = (
#  ident => {
#    globalRoles => {
#      #roles
#    },
#    channelRoles => {
#      channel => {
#        #roles
#      }
#    }
#  } 
#);

sub new{
  my $class = shift;
  my $self  = {};
  bless ($self, $class);
  
  $self->{m_parent} = shift;
  $self->{m_config} = shift;
  $self->{m_eventGuard} = undef;
  $self->{m_users} = {};
  $self->{m_persistentChannels} = {};
  
  my $host = $self->{m_config}->{db_host}     || "localhost";
  my $db   = $self->{m_config}->{db_database} || "pms";
  my $user = $self->{m_config}->{db_user}     || "pms";
  my $pass = $self->{m_config}->{db_pass}     || "secret";
  
  $self->{m_dbh} = new AnyEvent::DBI("DBI:mysql:$db:$host", $user, $pass,
                                   on_connect  => $self->_onDbConnectCallback(),
                                   on_error    => $self->_dbErrorCallback(),
                                   exec_server => 1
  );
  
  warn "Security Module created";
  return $self;
}

sub DESTROY{
  my $self = shift;
  $self->shutdown();
}

sub initialize{
  my $self = shift;
  $self->{m_eventGuard} = $self->{m_parent}->connect( 
    change_nick_request => $self->_basicNickChangeCallback() ,#we need to catch all basic nick changes
    client_connect_success => $self->_clientConnectedCallback(),
    client_disconnect_success => $self->_disconnectCallback(),
    message_send_request  => $self->_messageSendRequestCallback(),
    join_channel_request  => $self->_joinChannelRequestCallback(),
    leave_channel_success => $self->_leaveChannelSuccessCallback(),
    create_channel_request=> $self->_createChannelRequestCallback(),
    create_channel_success=> $self->_createChannelSuccessCallback(),
    change_topic_request  => $self->_changeTopicRequestCallback()
  );
  $self->{m_parent}->registerCommand("identify",$self->_identifyCallback());
  
  #load the settings from the database right after we entered the eventloop
  $self->{m_timer} = AnyEvent->timer (after => 0.1, cb => $self->_loadSettingsFromDbCallback());
  
}

sub _loadSettingsFromDbCallback(){
  my $self = shift or die "Need Ref";
  return sub{
    delete $self->{m_timer};
    $self->{m_dbh}->exec ("SELECT id,name,topic from mod_security_channels;", (), sub{
      my $dbh = shift;
      my $rows = shift;
      my $rv = shift;
      
      if(@{$rows} > 0){
        foreach my $curr (@{$rows}){
            warn "Creating Persistent Channel: ".$curr->[1];
            
            if($self->{m_parent}->createChannel(undef,$curr->[1],1)){
              $self->{m_persistentChannels}->{$curr->[1]} = {
                id => $curr->[0]
              };
            }
        }
      }
    });
  }
}

sub shutdown{
  my $self = shift;
  warn "Shutting Down";
  $self->{m_parent}->disconnect($self->{m_eventGuard});
}

sub setUserRuleset (){
  my $self    = shift or die "Need Ref";
  my $ident   = shift or die "Need Ident";
  my $set     = shift or die "Need Ruleset";
  
  $self->{m_users}->{$ident} = $set;
  warn "After User Set ".Dumper($self->{m_users}->{$ident});
}

sub userRuleset (){
  my $self    = shift or die "Need Ref";
  my $ident   = shift or die "Need Ident";
  
  if (!defined $self->{m_users}->{$ident}){
      #if the user is not known in the structure we have to create the 
      #default ruleset
      $self->{m_users}->{$ident} = $self->_createDefaultRuleset();
  }
  
  return $self->{m_users}->{$ident}->{globalRoles};
}

sub setChannelRuleset(){
  my $self    = shift or die "Need Ref";
  my $ident   = shift or die "Need Ident";
  my $channel = shift or die "Need Channel";
  my $set     = shift or die "Need Ruleset";
  
  if (!defined $self->{m_users}->{$ident}){
      #if the user is not known in the structure we have to create the 
      #default ruleset
      $self->{m_users}->{$ident} = $self->_createDefaultRuleset();
  }
  $self->{m_users}->{$ident}->{channelRoles}->{$channel} = $set;
  
  warn "After Channel Set ".Dumper($self->{m_users}->{$ident});
}

sub channelRuleset (){
  my $self    = shift or die "Need Ref";
  my $ident   = shift or die "Need Ident";
  my $channel = shift or die "Need Channel";

  warn "All User Rights:";
  warn Dumper($self->{m_users});
  
  if (!defined $self->{m_users}->{$ident}){
      #if the user is not known in the structure we have to create the 
      #default ruleset
      warn "Applying complete Default Ruleset";
      $self->{m_users}->{$ident} = $self->_createDefaultRuleset();
  }
  
  if (!defined $self->{m_users}->{$ident}->{channelRoles}->{$channel}){
      #if the channel is not known in the structure
      #we return a empty ruleset
	warn "Returning empty Ruleset: $ident $channel";
      return {};
  }
  
  return $self->{m_users}->{$ident}->{channelRoles}->{$channel};
}

sub _onDbConnectCallback{
  my $self = shift;
  return sub{
    my $dbh = shift;
    my $success = shift;
    
    if(!$success){
      warn "Could not connect to database, no Security functions will be registered";
      return;
    }
    
    warn "Database connection success, creating Security Hooks";
    $self->initialize();
  };
}

sub _dbErrorCallback{
  my $self = shift;
  return sub{
    warn "DBI Error: $@ at $_[1]:$_[2]";
  };
}

sub _createDefaultRuleset{
  my %hash = %defaultRuleset;
  return {
    userId       => -1, #a regular user, did not use /identify yet
    globalRoles  => \%hash,
    channelRoles => {} #empty ruleset 
  };
}

sub _clientConnectedCallback{
  my $self = shift;
  return sub{
    my $eventChain = shift;
    my $eventType  = shift;
    
    my $connection = $eventType->connection();
    warn "Applying default Ruleset";
    $self->{m_users}->{$connection->identifier()} = $self->_createDefaultRuleset();
    warn Dumper($self->{m_users}->{$connection->identifier()});
  };
}

sub _joinChannelRequestCallback{
  my $self = shift;
  return sub{
    my $eventChain = shift;
    my $eventType  = shift;  
    
    my $channel     = $eventType->channel();
    my $conn        = $eventType->connection();
    my $connIdent   = $conn->identifier();
    my $channelInfo = $self->{m_persistentChannels}->{$eventType->channel()->channelName()};
    
    warn "Join Channel Request";
    
    if(!defined $channelInfo){
      #this is a non persistent channel everyone can join it
      my %ruleset = %defaultChannelRuleset;
      $self->setChannelRuleset($conn->identifier(),$channel->channelName(),\%ruleset);
      return;
    }
    
    if($self->{m_users}->{$connIdent}->{userId} < 0){
      $eventType->reject("You do not have the right to join this channel. Identify yourself before");
      $eventChain->stop_event;
      return;
    }
    
    
    #we now stop the event and issue joinChannel() later if the user can join this channel
    #this also makes it impossible for every other module to handle this event if they are not registered BEFORE this module
    $eventType->reject("Please Wait checking your rights.");
    $eventChain->stop_event;
    
    my @args;
    push(@args,$self->{m_users}->{$connIdent}->{userId});
    push(@args,$channelInfo->{id});

    $self->{m_dbh}->exec ("Select roles.name from ".
                          "mod_security_user_to_channelRole as usrToRoles, ".
                          "mod_security_channelRoles as roles ".
                          "where usrToRoles.userRef = ? and usrToRoles.channelRef = ? and usrToRoles.roleRef = roles.id;"
    , @args
    , sub{
      my $dbh = shift;
      my $rows = shift;
      my $rv = shift;
      
      my %ruleset = ();
      foreach my $curr (@{$rows}) {
        $ruleset{$curr->[0]} = 1;
      }
      
      $self->setChannelRuleset($conn->identifier(),$channel->channelName(),\%ruleset);
      if(!$self->_hasChannelRole($connIdent,$channel->channelName(),"role_join_channel")){
        $conn->postMessage(Pms::Prot::Messages::serverMessage("default","You do not have the right to join this channel. Identify yourself before"));
      }else{
        #join the channel and force it
        if(!$self->{m_parent}->joinChannel($conn,$channel->channelName(),1)){
          $conn->postMessage(Pms::Prot::Messages::serverMessage("default",$self->{m_parent}->{m_lastError}));
        }
      }
    });
  };
}

sub _leaveChannelSuccessCallback{
  my $self = shift;
  return sub{
    my $eventChain = shift;
    my $eventType  = shift;   
    
    my $channel     = $eventType->channel();
    my $conn        = $eventType->connection();
    my $connIdent   = $conn->identifier();
    
    if(!defined $self->{m_users}->{$connIdent}){
      return;
    }
    
    if(!defined $self->{m_users}->{$connIdent}->{channelRoles}->{$channel->channelName()}){
      return;
    }
    delete $self->{m_users}->{$connIdent}->{channelRoles}->{$channel->channelName()};
  };
}

sub _basicNickChangeCallback{
  my $self = shift;
  return sub{
    my $eventChain = shift;
    my $eventType  = shift;
    
    #we now stop the event and issue changeNick() later if the user can change to this nick
    #this also makes it impossible for every other module to check nicknames if they are not registered BEFORE this module
    $eventType->reject("Please Wait checking if user exists.");
    $eventChain->stop_event;
    
    my @args;
    push(@args,$eventType->newName());

    $self->{m_dbh}->exec ("SELECT * from mod_security_users where username = ?", @args, sub{
      my $dbh = shift;
      my $rows = shift;
      my $rv = shift;
      
      if(@{$rows} > 0){
        $eventType->connection()->postMessage(Pms::Prot::Messages::serverMessage("default","Registered Nickname, use the identify command to identify yourself."));
      }else{
       if($self->{m_parent}->changeNick($eventType->connection(), $eventType->newName()) == 0){
          #a error happened
          $eventType->connection()->postMessage(Pms::Prot::Messages::serverMessage("default",$self->{m_parent}->{m_lastError}));
        }    
      } 
    });
  }
}

sub _identifyCallback{
  my $self = shift;
  return sub{
    my $connection = shift;
    my $nickname = shift;
    my $password = shift;
    
    my @args;
    push(@args,$nickname);
    push(@args,$password);
    
    my $select = "Select users.id as userId,roles.name as roleName from mod_security_users as users , ".
                 "mod_security_user_to_roles as usrToRoles, ".
                 "mod_security_roles as roles ".
                 "where users.id = usrToRoles.userRef and usrToRoles.roleRef = roles.id ".
                 "and users.username = ? and users.password = ?";

    $self->{m_dbh}->exec ($select, @args, sub{
      my $dbh = shift;
      my $rows = shift;
      my $rv = shift;
      
      if(@{$rows} > 0){
        
        my $userId  = -1;
        my $ruleset = $self->{m_users}->{$connection->identifier()};
        my %globaleRoles = ();
        warn Dumper($rows);
        foreach my $curr ( @{$rows} ){          
          warn "Found Role: ".$curr->[1];
          $globaleRoles{$curr->[1]} = 1;
          $userId = $curr->[0];
        }
        $ruleset->{userId}      = $userId;
        $ruleset->{globalRoles} = \%globaleRoles;
        
        #save the ruleset in our array
        $self->{m_users}->{$connection->identifier()} = $ruleset;
        warn "Rules after Identify: ";
        warn Dumper($ruleset);
        $self->{m_parent}->changeNick($connection, $nickname,1); #change nick and force the change
      }else{
        $connection->postMessage(Pms::Prot::Messages::serverMessage("default","Wrong Username or Password, please try again."));
      } 
    });
  }
}

sub _disconnectCallback{
  my $self = shift;
  return sub{
    my $eventChain = shift;
    my $eventType  = shift;    
    
    my $conn = $eventType->connection();
    
    if(defined $self->{m_users}->{$conn->identifier()}){
      warn "User disconnected, removing rights";
      delete $self->{m_users}->{$conn->identifier()};
    }
  };
}

sub _hasRole{
  my $self = shift or die "Need Ref";
  my $ident = shift or die "Need Ident";
  my $role = shift or die "Need Role";
  
  my $ruleset = $self->{m_users}->{$ident};
  warn "Checking for role: ".$role;
  warn Dumper($ruleset);
  if(!defined $ruleset){
    #if(defined $defaultRuleset{$role}){
    return 0;
    #}
  }
  if(defined $ruleset->{globalRoles}->{role_admin} || defined $ruleset->{globalRoles}->{$role}){
    return 1;
  }
  return 0;
}

sub _hasChannelRole{
  my $self = shift or die "Need Ref";
  my $ident = shift or die "Need Ident";
  my $channelName = shift or die "Need ChannelName";
  my $role = shift or die "Need Role";  
  
  my $ruleset = $self->channelRuleset($ident,$channelName); # $self->{m_users}->{$ident};
  
  warn "Checking for ChannelRole: ".$role." for IDENT: $ident";
  warn Dumper($ruleset);
  
  if(!defined $ruleset){
      return 0;
  }
  if(defined $self->userRuleset($ident)->{role_admin} 
    || defined $ruleset->{role_channelAdmin}
    || defined $ruleset->{$role})
  {
    return 1;
  }
  return 0;
}

sub _messageSendRequestCallback{
  my $self = shift;
  return sub{
    my $eventChain = shift;
    my $eventType  = shift;    
    
    my $connIdent = $eventType->connection()->identifier();
    my $channel   = $eventType->channel();
    
    if(!$self->_hasChannelRole($connIdent,$channel,"role_can_speak")){
      $eventType->reject("You don't have the rights to speak in this Channel");
      $eventChain->stop_event;      
    }
  };
}

sub _createChannelRequestCallback{
  my $self = shift;
  return sub{
    my $eventChain = shift;
    my $eventType  = shift;    
    
    #If there is no connection, this was called from the server
    if(!defined $eventType->connection()){
      return;
    }
    
    my $connIdent = $eventType->connection()->identifier();
    if(!$self->_hasRole($connIdent,"role_create_channel")){
      $eventType->reject("You don't have the rights to create Channels");
      $eventChain->stop_event;
    }
    
  };
}

sub _createChannelSuccessCallback{
  my $self = shift;
  return sub{
    my $eventChain = shift;
    my $eventType  = shift;   
    
    #If there is no connection, this was called from the server
    if(!defined $eventType->connection()){
      return;
    }
    
    my $connIdent = $eventType->connection()->identifier();
    $self->setChannelRuleset($connIdent,$eventType->channelName(),{
        role_channelAdmin => 1
    });
  };
}

sub _changeTopicRequestCallback{
  my $self = shift;
  return sub{
    my $eventChain = shift;
    my $eventType  = shift;    
    
    my $connIdent = $eventType->connection()->identifier();
    if(!$self->_hasChannelRole($connIdent,$eventType->channelName(),"role_change_topic")){
      $eventType->reject("You don't have the rights to change the Topic");
      $eventChain->stop_event;
    }
  };
}

1;
