#!/usr/bin/perl -w

package Pms::Modules::Security::Module;

use strict;
use utf8;
use Pms::Event::Connect;
use Pms::Core::Connection;
use Pms::Prot::Messages;
use AnyEvent;
use AnyEvent::DBI;
use Data::Dumper;
use Pms::Modules::Security::UserInfo;

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
                                   exec_server => 1,
                                   mysql_auto_reconnect => 1,
                                   mysql_enable_utf8 => 1
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
  $self->{m_parent}->registerCommand("showRights",$self->_showRightsCallback());
  $self->{m_parent}->registerCommand("giveOp",$self->_giveChannelOpCallback());
  $self->{m_parent}->registerCommand("takeOp",$self->_takeChannelOpCallback());
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

sub userInfo(){
  my $self    = shift or die "Need Ref";
  my $ident   = shift or die "Need Ident";
  
  if (!defined $self->{m_users}->{$ident}){
      #if the user is not known in the structure we have to create the 
      #default ruleset
      $self->{m_users}->{$ident} = Pms::Modules::Security::UserInfo->new();
      my %roles = %defaultRuleset;
      $self->{m_users}->{$ident}->setGlobalRoleset(\%roles);
  }
  
  return $self->{m_users}->{$ident};
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

sub _clientConnectedCallback{
  my $self = shift;
  return sub{
    my $eventChain = shift;
    my $eventType  = shift;
    
    my $connection = $eventType->connection();
    warn "Applying default Ruleset";
    $self->userInfo($connection->identifier());
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
      my %rules = %defaultChannelRuleset;
      my $userinfo = $self->userInfo($connIdent);
      $userinfo->setChannelRoleset($channel->channelName(),\%rules);
      
      return;
    }
    
    if($self->{m_users}->{$connIdent}->id() < 0){
      $eventType->reject("You do not have the right to join this channel. Identify yourself before");
      $eventChain->stop_event;
      return;
    }
    
    
    #we now stop the event and issue joinChannel() later if the user can join this channel
    #this also makes it impossible for every other module to handle this event if they are not registered BEFORE this module
    $eventType->reject("Please Wait checking your rights.");
    $eventChain->stop_event;
    
    my @args;
    push(@args,$self->{m_users}->{$connIdent}->id());
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
      
      my %roles = ();
      foreach my $curr (@{$rows}) {
        $roles{$curr->[0]} = 1;
      }
      
      my $userinfo = $self->userInfo($conn->identifier());
      my $channelName = $channel->channelName();
      $userinfo->setChannelRoleset($channelName,\%roles);
      if(!$userinfo->hasChannelRole($channelName,"role_join_channel")){
        $userinfo->removeChannelRoleset($channelName);
        $conn->postMessage(Pms::Prot::Messages::serverMessage("default","You do not have the right to join this channel. Identify yourself before"));
      }else{
        #join the channel and force it
        if(!$self->{m_parent}->joinChannel($conn,$channelName,1)){
          $userinfo->removeChannelRoleset($channelName);
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
    
    my $userinfo = $self->userInfo($connIdent);
    $userinfo->removeChannelRoleset($channel->channelName());
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
        my $userinfo = $self->userInfo($connection->identifier());
        my %globaleRoles = ();
        warn Dumper($rows);
        foreach my $curr ( @{$rows} ){          
          warn "Found Role: ".$curr->[1];
          $globaleRoles{$curr->[1]} = 1;
          $userId = $curr->[0];
        }
        $userinfo->setId($userId);
        $userinfo->setGlobalRoleset(\%globaleRoles);
        
        warn Dumper($self->{m_users}->{$connection->identifier()});
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

sub _messageSendRequestCallback{
  my $self = shift;
  return sub{
    my $eventChain = shift;
    my $eventType  = shift;    
    
    my $connIdent = $eventType->connection()->identifier();
    my $channel   = $eventType->channel();
    my $info      = $self->userInfo($connIdent);
    
    if(!$info->hasChannelRole($channel,"role_can_speak")){
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
    my $info      = $self->userInfo($connIdent);
    if(!$info->hasGlobalRole("role_create_channel")){
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
    my $userInfo  = $self->userInfo($connIdent);
    my %ruleset   = (role_channelAdmin => 1);
    $userInfo->setChannelRoleset($eventType->channelName(),\%ruleset);
  };
}

sub _changeTopicRequestCallback{
  my $self = shift;
  return sub{
    my $eventChain = shift;
    my $eventType  = shift;    
    
    my $connIdent = $eventType->connection()->identifier();
    my $userInfo  = $self->userInfo($connIdent);
    if(!$userInfo->hasChannelRole($eventType->channelName(),"role_change_topic")){
      $eventType->reject("You don't have the rights to change the Topic");
      $eventChain->stop_event;
    }
  };
}

sub _showRightsCallback{
  my $self = shift;
  return sub{
    my $connection = shift;
    my $userInfo   = $self->userInfo($connection->identifier());
    if(defined $userInfo){
      $connection->postMessage(Pms::Prot::Messages::serverMessage("default",Dumper($userInfo)));
    }
  }
}

sub _giveChannelOpCallback{
  my $self = shift;
  return sub{
    my $connection = shift;
    my $channel = shift;
    my $nickname = shift;
    
    my $connIdent = $connection->identifier();
    my $userInfo  = $self->userInfo($connIdent);
    
    if(!$userInfo->hasChannelRole($channel,"role_channelAdmin")){
      $connection->postMessage(Pms::Prot::Messages::serverMessage("default","You don't have the rights to do that"));
      return;
    }
    
    my $otherConnection = $self->{m_parent}->nicknameToConnection($nickname);
    
    if(!defined $otherConnection){
      $connection->postMessage(Pms::Prot::Messages::serverMessage("default","$nickname is not known"));
      return;
    }
    
    my $channelObj = $self->{m_parent}->channel($channel);
    if(!defined $channelObj){
      $connection->postMessage(Pms::Prot::Messages::serverMessage("default",$self->{m_parent}->{m_lastError}));
      return;
    }
    
    if(!$channelObj->hasConnection($otherConnection->identifier())){
      $connection->postMessage(Pms::Prot::Messages::serverMessage("default","You can only give rights to a user IN the channel"));
      return;
    }
    
    warn "About to Set Roles";
    my $otherUserInfo   = $self->userInfo($otherConnection->identifier());
    warn Dumper($otherUserInfo);
    
    my %ruleset = %{$otherUserInfo->channelRoleset($channel)};
    $ruleset{role_channelAdmin} = 1;
    warn Dumper(%ruleset);
    $otherUserInfo->setChannelRoleset($channel,\%ruleset);
  }
}

sub _takeChannelOpCallback{
  my $self = shift;
  return sub{
    my $connection = shift;
    my $channel = shift;
    my $nickname = shift;
    
    my $connIdent = $connection->identifier();
    my $userInfo  = $self->userInfo($connIdent);
    
    if(!$userInfo->hasChannelRole($channel,"role_channelAdmin")){
      $connection->postMessage(Pms::Prot::Messages::serverMessage("default","You don't have the rights to do that"));
      return;
    }
    
    my $otherConnection = $self->{m_parent}->nicknameToConnection($nickname);
    if(!defined $otherConnection){
      $connection->postMessage(Pms::Prot::Messages::serverMessage("default","$nickname is not known"));
      return;
    }
    
    my $channelObj = $self->{m_parent}->channel($channel);
    if(!defined $channelObj){
      $connection->postMessage(Pms::Prot::Messages::serverMessage("default",$self->{m_parent}->{m_lastError}));
      return;
    }
    
    if(!$channelObj->hasConnection($otherConnection->identifier())){
      $connection->postMessage(Pms::Prot::Messages::serverMessage("default","You can only take rights from a user IN the channel"));
      return;
    }
    
    warn "About to Revok Admin Roler";
    my $otherUserInfo   = $self->userInfo($otherConnection->identifier());
    
    my %ruleset = %{$otherUserInfo->channelRoleset($channel)};
    delete $ruleset{role_channelAdmin};
    if(!keys(%ruleset)){
      warn "Filling Empty Ruleset";
      %ruleset = %defaultChannelRuleset;
    }
    warn Dumper(%ruleset);
    $otherUserInfo->setChannelRoleset($channel,\%ruleset);
  }
}
1;
