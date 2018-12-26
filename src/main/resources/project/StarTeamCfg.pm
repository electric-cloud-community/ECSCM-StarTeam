####################################################################
#
# ECSCM::StarTeam::Cfg: Object definition of CC  configuration.
#
####################################################################
package ECSCM::StarTeam::Cfg;
@ISA = (ECSCM::Base::Cfg);
if (!defined ECSCM::Base::Cfg) {
    require ECSCM::Base::Cfg;
}


####################################################################
# Object constructor for ECSCM::StarTeam::Cfg
#
# Inputs
#   cmdr  = a previously initialized ElectricCommander handle
#   name  = a name for this configuration
####################################################################
sub new {
    my $class = shift;

    my $cmdr = shift;
    my $name = shift;

    my($self) = ECSCM::Base::Cfg->new($cmdr,"$name");
    bless ($self, $class);
    return $self;
}

####################################################################
# StarTeamHostName
####################################################################
sub getStarTeamHostName {
    my ($self) = @_;
    return $self->getServer();
}
sub setStarTeamHostName {
    my ($self, $name) = @_;
    print "Setting StarTeamHostName to $name\n";
    return $self->setServer("$name");
}

####################################################################
# StarTeamPassword
####################################################################
sub getStarTeamPassword {
    my ($self) = @_;
    return $self->getPassword();
}
sub setStarTeamPassword {
    my ($self, $name) = @_;
    print 'Setting StarTeamPassword to ***\n';
    return $self->setPassword("$name");
}

####################################################################
# StarTeamUserName
####################################################################
sub getStarTeamUserName {
    my ($self) = @_;
    return $self->getUser();
}
sub setStarTeamUserName {
    my ($self, $name) = @_;
    print "Setting StarTeamUserName to $name\n";
    return $self->setUser("$name");
}

####################################################################
# StarTeamPasswordFile
####################################################################
sub getStarTeamPasswordFile {
    my ($self) = @_;
    return $self->get('StarTeamPasswordFile');
}
sub setStarTeamPasswordFile {
    my ($self, $name) = @_;
    print "Setting StarTeamPasswordFile to $name\n";
    return $self->set('StarTeamPasswordFile', "$name");
}
####################################################################
# StarTeamPasswordFileIsEncrypted
####################################################################
sub getStarTeamPasswordFileIsEncrypted {
    my ($self) = @_;
    return $self->get('StarTeamPasswordFileIsEncrypted');
}
sub setStarTeamPasswordFileIsEncrypted {
    my ($self, $name) = @_;
    print "Setting StarTeamPasswordFileIsEncrypted to $name\n";
    return $self->set('StarTeamPasswordFileIsEncrypted', "$name");
}
####################################################################
# StarTeamEndpoint
####################################################################
sub getStarTeamEndpoint {
    my ($self) = @_;
    return $self->get('StarTeamEndpoint');
}
sub setStarTeamEndpoint {
    my ($self, $name) = @_;
    print "Setting StarTeamEndpoint to $name\n";
    return $self->set('StarTeamEndpoint', "$name");
}

1;
