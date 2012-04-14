#!/usr/bin/perl -w

package Pms::Modules::Security;

use strict;
use Pms::Event::Connect;
use Pms::Core::Connection;
use Pms::Prot::Messages;
use AnyEvent::DBI;

sub new{
  my $class = shift;
  my $self  = {};
  bless ($self, $class);
  
  $self->{m_parent} = shift;
  $self->{m_eventGuard} = undef;
  
  $self->{m_dbh} = new AnyEvent::DBI('DBI:mysql:pms', 'pms', 'secret',
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
    change_nick_request => $self->_basicNickChangeCallback() #we need to catch all basic nick changes
  );
  $self->{m_parent}->registerCommand("identify",$self->_identifyCallback());
}

sub shutdown{
  my $self = shift;
  warn "Shutting Down";
  $self->{m_parent}->disconnect($self->{m_eventGuard});
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
        $self->{m_parent}->changeNick($eventType->connection(), $eventType->newName(),1);  
      } 
    });
  }
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

sub _identifyCallback{
  my $self = shift;
  return sub{
    my $connection = shift;
    my $nickname = shift;
    my $password = shift;
    
    my @args;
    push(@args,$nickname);
    push(@args,$password);

    $self->{m_dbh}->exec ("SELECT * from mod_security_users where username = ? and password = ?", @args, sub{
      my $dbh = shift;
      my $rows = shift;
      my $rv = shift;
      
      if(@{$rows} > 0){
        $self->{m_parent}->changeNick($connection, $nickname,1); #change nick and force the change
      }else{
        $connection->postMessage(Pms::Prot::Messages::serverMessage("default","Wrong Username or Password, please try again."));
      } 
    });
  }
}

1;