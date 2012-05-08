#!/usr/bin/perl -w

=begin nd

  Package: Pms::Modules::Security::Module
  
  Description:
    This plugin implements a security model for the pms server.
    It introduces a role concept. Every user has his set of roles which 
    describe what he can do and what he can't do.
    
    The roles are splitted in global and channel roles, a user has his
    own set of roles for every channel he joined into. 
    
  Available global roles:
    - role_admin: A user has all rights - *everywhere*
    - role_create_channel: A user can create channels
  
  Available channel roles:
    - role_channelAdmin: A user has all rights in the channel
    - role_join_channel: A user can enter the channel
    - role_can_speak: A user can speak in the channel
    - role_change_topic: A user can change the topic of a channel
=cut

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

=begin nd
  Constructor: new
    Initializes the Object
    
  Parameters:
    parent - The <Pms::Application> object
    config - The module config hash
=cut
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
  
  warn "PMS-Core> ". "Security Module created";
  return $self;
}

=begin nd
  Destructor: DESTROY
    Destroys the Object and cleans up the modules ressources
    
  Parameters:
=cut
sub DESTROY{
  my $self = shift;
  $self->shutdown();
}

=begin nd
  Function: initialize
    Called by the constructor, initializes the module
    and connects to all the required signals and events
  
  Access:
    Public
=cut
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

=begin nd
  Function: _loadSettingsFromDbCallback
    This function is called on module initialization and is loading 
    persistent channels from the database
  
  Access:
    Private
=cut
sub _loadSettingsFromDbCallback(){
  my $self = shift or die "Need Ref";
  return sub{
    delete $self->{m_timer};
    $self->{m_dbh}->exec ("CALL mod_security_getChannels();", (), sub{
      my $dbh = shift;
      my $rows = shift;
      my $rv = shift;
      
      if(@{$rows} > 0){
        foreach my $curr (@{$rows}){
            warn "PMS-Core> ". "Creating Persistent Channel: ".$curr->[1];
            
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

=begin nd
  Function: shutdown
    Cleans up the modules resources.
    Is automatically called by the destructor
  
  Access:
    Public
=cut
sub shutdown{
  my $self = shift;
  warn "PMS-Core> ". "Shutting Down";
  $self->{m_parent}->disconnect($self->{m_eventGuard});
}

=begin nd
  Function: userInfo
    Tries to find the user information for a connection identifier.
    
    If it can not find one, it defines a default information set
  
  Access:
    Public
    
  Parameters:
    $ident - The connection identifier
    
  Returns:
    ref - <Pms::Modules::Security::UserInfo> object
=cut
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

=begin nd
  Function: _onDbConnectCallback
    Returns a function that is called when the
    connection to the database is finished
  
  Access:
    Private
    
  Returns:
    sub - a callback function
=cut
sub _onDbConnectCallback{
  my $self = shift;
  return sub{
    my $dbh = shift;
    my $success = shift;
    
    if(!$success){
      warn "PMS-Core> ". "Could not connect to database, no Security functions will be registered";
      return;
    }
    
    warn "PMS-Core> ". "Database connection success, creating Security Hooks";
    $self->initialize();
  };
}

=begin nd
  Function: _dbErrorCallback
    Returns a function that is called when there
    was a error in communication with the database
  
  Access:
    Private
    
  Returns:
    sub - a callback function
=cut
sub _dbErrorCallback{
  my $self = shift;
  return sub{
    warn "PMS-Core> ". "DBI Error: $@ at $_[1]:$_[2]";
  };
}

=begin nd
  Function: _clientConnectedCallback
    Creates the callback that is used to 
    handle <Pms::Event::Connect> events.
  
  Access:
    Private
    
  Returns:
    sub - a callback function
=cut
sub _clientConnectedCallback{
  my $self = shift;
  return sub{
    my $eventChain = shift;
    my $eventType  = shift;
    
    my $connection = $eventType->connection();
    warn "PMS-Core> ". "Applying default Ruleset";
    $self->userInfo($connection->identifier());
    warn "PMS-Core> ". Dumper($self->{m_users}->{$connection->identifier()});
  };
}

=begin nd
  Function: _joinChannelRequestCallback
    Creates the callback that is used to 
    handle <Pms::Event::Join> events.
  
  Access:
    Private
    
  Returns:
    sub - a callback function
=cut
sub _joinChannelRequestCallback{
  my $self = shift;
  return sub{
    my $eventChain = shift;
    my $eventType  = shift;  
    
    my $channel     = $eventType->channel();
    my $conn        = $eventType->connection();
    my $connIdent   = $conn->identifier();
    my $channelInfo = $self->{m_persistentChannels}->{$eventType->channel()->channelName()};
    
    warn "PMS-Core> ". "Join Channel Request";
    
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

    $self->{m_dbh}->exec ("CALL mod_security_getChannelRoles(?,?);"
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

=begin nd
  Function: _leaveChannelSuccessCallback
    Creates the callback that is used to 
    handle <Pms::Event::Leave> events.
  
  Access:
    Private
    
  Returns:
    sub - a callback function
=cut
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

=begin nd
  Function: _basicNickChangeCallback
    Creates the callback that is used to 
    handle <Pms::Event::NickChange> events.
  
  Access:
    Private
    
  Returns:
    sub - a callback function
=cut
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

=begin nd
  Function: _identifyCallback
    Creates a callback function that is used to handle the
    identify command registered from the security module.
  
  Access:
    Private
    
  Returns:
    sub - the identify callback
=cut
sub _identifyCallback{
  my $self = shift;
  return sub{
    my $connection = shift;
    my $nickname = shift;
    my $password = shift;
    
    my @args;
    push(@args,$nickname);
    push(@args,$password);
    
    #load the user from the database if username and nicknames are matching
    my $select = "CALL mod_security_getUserWithRoles(?,?)";

    $self->{m_dbh}->exec ($select, @args, sub{
      my $dbh = shift;
      my $rows = shift;
      my $rv = shift;
      
      if(@{$rows} > 0){
        
        my $userId  = -1;
        my $userinfo = $self->userInfo($connection->identifier());
        my %globaleRoles = ();
        warn "PMS-Core> ". Dumper($rows);
        foreach my $curr ( @{$rows} ){          
          warn "PMS-Core> ". "Found Role: ".$curr->[1];
          $globaleRoles{$curr->[1]} = 1;
          $userId = $curr->[0];
        }
        $userinfo->setId($userId);
        $userinfo->setGlobalRoleset(\%globaleRoles);
        
        warn "PMS-Core> ". Dumper($self->{m_users}->{$connection->identifier()});
        $self->{m_parent}->changeNick($connection, $nickname,1); #change nick and force the change
      }else{
        $connection->postMessage(Pms::Prot::Messages::serverMessage("default","Wrong Username or Password, please try again."));
      } 
    });
  }
}

=begin nd
  Function: _disconnectCallback
    Creates the callback that is used to 
    handle <Pms::Event::Disconnect> events.
  
  Access:
    Private
    
  Returns:
    sub - a callback function
=cut
sub _disconnectCallback{
  my $self = shift;
  return sub{
    my $eventChain = shift;
    my $eventType  = shift;    
    
    my $conn = $eventType->connection();
    
    if(defined $self->{m_users}->{$conn->identifier()}){
      warn "PMS-Core> ". "User disconnected, removing rights";
      delete $self->{m_users}->{$conn->identifier()};
    }
  };
}

=begin nd
  Function: _messageSendRequestCallback
    Creates the callback that is used to 
    handle <Pms::Event::Message> events.
  
  Access:
    Private
    
  Returns:
    sub - a callback function
=cut
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

=begin nd
  Function: _createChannelRequestCallback
    Creates the callback that is used to 
    handle <Pms::Event::Channel> events.
  
  Access:
    Private
    
  Returns:
    sub - a callback function
=cut
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

=begin nd
  Function: _createChannelSuccessCallback
    Creates the callback that is used to 
    handle <Pms::Event::Channel> events.
    
  Note:
    This handles the special case when the Server
    tells us that the create was successfull.
  
  Access:
    Private
    
  Returns:
    sub - a callback function
=cut
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

=begin nd
  Function: _changeTopicRequestCallback
    Creates the callback that is used to 
    handle <Pms::Event::Topic> events.
  
  Access:
    Private
    
  Returns:
    sub - a callback function
=cut
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

=begin nd
  Function: _showRightsCallback
    Creates a callback function that is used to handle the
    showRights command registered from the security module.
  
  Access:
    Private
    
  Returns:
    sub - the showRights callback
=cut
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

=begin nd
  Function: _giveChannelOpCallback
    Creates a callback function that is used to handle the
    giveChannelOp command registered from the security module.
  
  Access:
    Private
    
  Returns:
    sub - the giveChannelOp callback
=cut
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
    
    warn "PMS-Core> ". "About to Set Roles";
    my $otherUserInfo   = $self->userInfo($otherConnection->identifier());
    warn "PMS-Core> ". Dumper($otherUserInfo);
    
    my %ruleset = %{$otherUserInfo->channelRoleset($channel)};
    $ruleset{role_channelAdmin} = 1;
    warn "PMS-Core> ". Dumper(%ruleset);
    $otherUserInfo->setChannelRoleset($channel,\%ruleset);
  }
}

=begin nd
  Function: _takeChannelOpCallback
    Creates a callback function that is used to handle the
    takeChannelOp command registered from the security module.
  
  Access:
    Private
    
  Returns:
    sub - the takeChannelOp callback
=cut
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
    
    warn "PMS-Core> ". "About to Revoke Admin Role";
    my $otherUserInfo   = $self->userInfo($otherConnection->identifier());
    
    my %ruleset = %{$otherUserInfo->channelRoleset($channel)};
    delete $ruleset{role_channelAdmin};
    if(!keys(%ruleset)){
      warn "PMS-Core> ". "Filling Empty Ruleset";
      %ruleset = %defaultChannelRuleset;
    }
    warn "PMS-Core> ". Dumper(%ruleset);
    $otherUserInfo->setChannelRoleset($channel,\%ruleset);
  }
}
1;
