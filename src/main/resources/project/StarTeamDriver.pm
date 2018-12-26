####################################################################
#
# ECSCM::StarTeam::Driver  Object to represent interactions with 
#        StarTeam.
####################################################################
package ECSCM::StarTeam::Driver;
@ISA = (ECSCM::Base::Driver);
use ElectricCommander;
use Time::Local;
use File::Basename;
use Getopt::Long;
use HTTP::Date(qw {str2time time2str time2iso time2isoz});
use strict;

$|=1;
####################################################################
# Object constructor for ECSCM::StarTeam::Driver
#
# Inputs
#    cmdr          previously initialized ElectricCommander handle
#    name          name of this configuration
#                 
####################################################################
sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $cmdr = shift;
    my $name = shift;
    my $cfg = new ECSCM::StarTeam::Cfg($cmdr, "$name");
    
    if ("$name" ne ''){
        my $sys = $cfg->getSCMPluginName();
        if ("$sys" ne 'ECSCM-StarTeam') { die "SCM config $name is not type ECSCM-StarTeam"; }
    }

    my ($self) = new ECSCM::Base::Driver($cmdr,$cfg);

    bless ($self, $class);
    return $self;
}

####################################################################
# isImplemented
####################################################################
sub isImplemented {
    my ($self, $method) = @_;
    
    if ($method eq 'getSCMTag'  ||
        $method eq 'apf_driver' || 	
        $method eq 'cpf_driver' ||
        $method eq 'checkoutCode') {
        return 1;
    } else {
        return 0;
    }
}

####################################################################
# get scm tag for sentry (continous integration)
####################################################################

####################################################################
# getSCMTag
# 
# Get the latest changelist on this branch/client
#
# Args:
# Return: a string representing the latest changes
#         
####################################################################
sub getSCMTag {
    my ($self, $opts) = @_;

    # add configuration that is stored for this config
    my $name = $self->getCfg()->getName();
    my %row = $self->getCfg()->getRow($name);
    foreach my $k (keys %row) {
            $opts->{$k}=$row{$k};
    }

    # Load userName and password from the credential
    ($opts->{StarTeamUserName}, $opts->{StarTeamPassword}) = 
        $self->retrieveUserCredential($opts->{credential},
        $opts->{StarTeamUserName}, $opts->{StarTeamPassword});
        
        
        
    if (length ($opts->{StarTeamHostName}) == 0) {        
        issueWarningMsg ('*** No StarTeam host was specified');
        return (undef,undef);
    }

    # set the StarTeam command
    #   stcmd hist -is -x -p "user1:abcdef@192.168.6.83:49201/Sentry Test/Sentry View/files"
    #           Optional :  -pwdfile "buildpw.txt"
    #   
    # It would be nice to have a more efficient query for StarTeam.  As it is.
    # this query gets EVERY revision of EVERY file and looks for the 
    # most recent date

    # Set the base query command
    my $command = 'stcmd hist -is -x';

    # Set the user name and password in the project specifier
    my $passwordStart = 0;
    my $passwordLength = 0;
    my $projectSpecifier = '';
    if ($opts->{StarTeamUserName} ne '') {
        $projectSpecifier .= "$opts->{StarTeamUserName}";
        if ($opts->{StarTeamPassword} ne '') {
            $projectSpecifier .= ':';
            $passwordStart = length $projectSpecifier;
            $projectSpecifier .= $opts->{StarTeamPassword};
            $passwordLength = (length $projectSpecifier) - $passwordStart;
        }
    }
    
    # Set the host name and "endpoint" (port) in the project specifier
    if ($opts->{StarTeamHostName} ne '') {
        $projectSpecifier .= '@' . $opts->{StarTeamHostName};
        if ($opts->{StarTeamEndPoint} ne '') {
            $projectSpecifier .= ":$opts->{StarTeamEndPoint}";
        }
    }

    # Set the project, view, and folder in the project specifier
    $projectSpecifier .= "/$opts->{StarTeamProjectName}";
    if ($opts->{StarTeamViewName} ne '') {
        $projectSpecifier .= "/$opts->{StarTeamViewName}";
    }
    if ($opts->{StarTeamFolderPath} ne '') {
        $projectSpecifier .= "/$opts->{StarTeamFolderPath}";
    }

    # Add the password file if specified
    if ($opts->{StarTeamPasswordFile} ne '') {
        my $pwdFileOption = ($opts->{StarTeamPasswordFileIsEncrypted}) ?
                            '-epwdfile' : '-pwdfile';

        $command .= qq| $pwdFileOption "$opts->{StarTeamPasswordFile}"|;
    }
    
    #Add the label
    if ($opts->{StarTeamLabel} ne '') {   
        $command .= qq( -vl $opts->{StarTeamLabel} );        
    }

    # run StarTeam
    $command .= qq{ -p "};
    $passwordStart += length ($command) if $passwordLength;
    $command .= qq{$projectSpecifier"};
    
    my $cmndReturn = $self->RunCommand("$command", 
            {LogCommand => 1, LogResult => 1, HidePassword => 1,
            passwordStart => $passwordStart, 
            passwordLength => $passwordLength});

    # parse the result looking for the most recent date
    #   ----------------------------
    #   Revision: 2 View: Sentry Test Branch Revision: 1.1
    #   Author: build Date: 5/29/08 5:55:03 PM PDT
    #   Adding an error line
    #   
    #   ----------------------------
    #   Revision: 1 View: Sentry Test Branch Revision: 1.0
    #   Author: build Date: 5/29/08 5:21:14 PM PDT
    #   Files for Sample App
    #   
    #   =============================================================================
    my $newestTime = 0;
    my $newestTimeString =  '';
    foreach my $line (split (/\n/, $cmndReturn)) {
        if  ( $line =~ /^Author.*Date: (.*)/ )
        {
            # save the newest time
            my $timeStamp = $self->sentryTimeConvert($1);
            if ($timeStamp > $newestTime) {

                $newestTime = $timeStamp;
                # Store the newest time in ISO Format
                $newestTimeString =  time2str($timeStamp);
            }
        }
    }

    return ($newestTimeString, $newestTime);
}


####################################################################
# checkoutCode
#
# Results:
#   Uses the "stcmd co" command to checkout code to the workspace.
#   Collects data to call functions to set up the scm change log.
#
# Arguments:
#   self -              the object reference
#   opts -              A reference to the hash with values
#
# Returns
#   Output of the the "stcmd co" command.
#
####################################################################
sub checkoutCode {
    my ($self, $opts) = @_;     
    my $name = $self->getCfg()->getName();
    my %row = $self->getCfg()->getRow($name);
    
    foreach my $k (keys %row) {
        $opts->{$k}=$row{$k};
    }
       
    # Load userName and password from the credential
    ($opts->{StarTeamUserName}, $opts->{StarTeamPassword}) = 
        $self->retrieveUserCredential($opts->{credential},
        $opts->{StarTeamUserName}, $opts->{StarTeamPassword});
            
    if (length ($opts->{StarTeamHostName}) == 0) {
        $self->issueWarningMsg ('*** No StarTeam host was specified');
        return (undef,undef);
    }

    # set the StarTeam command
    #   stcmd co -is -x -nologo -x -is -rp destFolder -p "user1:abcdef@192.168.6.83:49201/Sentry Test/Sentry View/files"
    #           Optional :  -pwdfile "buildpw.txt"
    #   
  
    # Set the base query command
    my $command = 'stcmd co';

    # Set the user name and password in the project specifier
    my $passwordStart = 0;
    my $passwordLength = 0;
    my $projectSpecifier = '';
    if ($opts->{StarTeamUserName} ne '') {    
        $projectSpecifier .= "$opts->{StarTeamUserName}";
        if ($opts->{StarTeamPassword} ne '') {        
            $projectSpecifier .= ':';
            $passwordStart = length $projectSpecifier;
            $projectSpecifier .= $opts->{StarTeamPassword};
            $passwordLength = (length $projectSpecifier) - $passwordStart;
        }
    }
    
    # Set the host name and "endpoint" (port) in the project specifier
    if ($opts->{StarTeamHostName} ne '') {    
        $projectSpecifier .= '@' . $opts->{StarTeamHostName};
        if ($opts->{StarTeamEndPoint} ne '') {        
            $projectSpecifier .= ":$opts->{StarTeamEndPoint}";
        }
    }

    # Set the project, view, and folder in the project specifier
    $projectSpecifier .= "/$opts->{StarTeamProjectName}";
    if ($opts->{StarTeamViewName} ne '') {    
        $projectSpecifier .= "/$opts->{StarTeamViewName}";
    }
    if ($opts->{StarTeamFolderPath} ne '') {    
        $projectSpecifier .= "/$opts->{StarTeamFolderPath}";
    }
   
    # Add the password file if specified
    if ($opts->{StarTeamPasswordFile} ne '') {    
        my $pwdFileOption = ($opts->{StarTeamPasswordFileIsEncrypted}) ?
                            '-epwdfile' : '-pwdfile';

        $command .= qq| $pwdFileOption "$opts->{StarTeamPasswordFile}"|;
    }
    # run StarTeam
    $command .= qq{ -p "};
    $passwordStart += length ($command) if $passwordLength;
    $command .= qq{$projectSpecifier"};
    if ($opts->{dest} eq "") {  #if no dest folder supplied we use the current folder
        $command .= qq( -rp .);  
    } else {
        $command .= qq( -rp "$opts->{dest}");
    }
    #Add the label
    if ($opts->{StarTeamLabel} ne '') {   
        $command .= qq( -vl $opts->{StarTeamLabel} );        
    }
	#Additional options
	if ($opts->{AdditionalOptions} ne '') {
	    $command .= qq( $opts->{AdditionalOptions} );
	}	
    $command .= qq( -nologo -x -is);
    
    my $cmndReturn = $self->RunCommand("$command", 
            {LogCommand => 1, LogResult => 1, HidePassword => 1,
            passwordStart => $passwordStart, 
            passwordLength => $passwordLength});
            
   
    if (!defined $cmndReturn) { 
        return 0;
    }

    return 1;
}

###############################################################################
# agentPreflight routines  (apf_xxxx)
###############################################################################

###############################################################################
# apf_getScmInfo
#
#       If the client script passed some SCM-specific information, then it is
#       collected here.
###############################################################################

sub apf_getScmInfo {
    my ($self,$opts) = @_;
    my $scmInfo = $self->pf_readFile('ecpreflight_data/scmInfo');
    
    $scmInfo =~ m/(.*)\n(.*)\n(.*)\n(.*)\n(.*)\n(.*)\n(.*)\n(.*)\n/;
    $opts->{StarTeamEndPoint}       = $1;
    $opts->{StarTeamPassword}       = $2;
    $opts->{StarTeamUserName}       = $3;
    $opts->{StarTeamProjectName}    = $4;
	$opts->{StarTeamHostName}       = $5;
    $opts->{StarTeamViewName}       = $6;
    $opts->{StarTeamFolderPath}     = $7;
    $opts->{AdditionalOptions}      = $8;  
  
    print join("\n",
        "StarTeam information received from client:",
        "StarTeamUser: $opts->{StarTeamUserName}",
        "StarTeamProjectName: $opts->{StarTeamProjectName}",
		"StarTeamHostName: $opts->{StarTeamHostName}",			
        "StarTeamViewName(optional): $opts->{StarTeamViewName}",  
        "StarTeamFolderPath(optional): $opts->{StarTeamFolderPath}",                
        "StarTeamEndPoint: $opts->{StarTeamEndPoint}",
        "Additional options: $opts->{AdditionalOptions}",
        "",
        "StarTeam information from server:",
        "EndPoint: $opts->{StarTeamEndPoint}",
        "User: $opts->{StarTeamUserName}")."\n";
}

###############################################################################
# apf_createSnapshot
#
#       Create the basic source snapshot before overlaying the deltas passed
#       from the client.
###############################################################################
sub apf_createSnapshot {   
    my ($self,$opts) = @_;
    my $jobId = $::ENV{COMMANDER_JOBID};            
    my $result = $self->checkoutCode($opts);
    
    if (defined $result) {
        print "checked out $result\n";
    }
}

################################################################################
# apf_driver
#
# agent preflight driver for StarTeam
################################################################################
sub apf_driver() {
    my $self = shift;
    my $opts = shift;
    
    if ($opts->{test}) { $self->setTestMode(1); }
    
    $opts->{delta} = 'ecpreflight_files';    
    $self->apf_downloadFiles($opts);
    $self->apf_transmitTargetInfo($opts);
    $self->apf_getScmInfo($opts);
    $self->apf_createSnapshot($opts);
    $self->apf_deleteFiles($opts);
    $self->apf_overlayDeltas($opts);
}

###############################################################################
# clientPreflight routines  (cpf_xxxx)
###############################################################################

###############################################################################
# cpf_st
#
#       Runs a StarTeam command.  For testing, the requests and responses will be
#       pre-arranged.
# Arguments:
#  -opts array
# Returns:
#  -command output
#
################################################################################
sub cpf_st {   
    my ($self,$opts, $command, $options) = @_;
    
    $self->cpf_debug("Running StarTeam command \"$command\"");
    if ($opts->{opt_Testing}) {
        my $request = uc("stcmd_$command"); #stcmd is the starteam command line
        $request =~ s/[^\w]//g;
        if (defined($ENV{$request})) {
            return $ENV{$request};
        } else {
            $self->cpf_error('Pre-arranged command output not found in ENV');
        }
    } else {
        return $self->RunCommand("stcmd $command", $options);
    }
}

##################################################################################
# cpf_genProjectSpec
#
# generates the project specifier string using the data from the user
# 
#  Arguments: 
#   -opts array :username, password, host, port, projectname, viewname, folderpath
#  Returns:
#   -projectspecifier
# 
#
##################################################################################
sub cpf_genProjectSpec {
    my($self, $opts) = @_;
    my $projectSpecifier = '';
  
    $self->cpf_debug('Generating the project specifier');  
  
    if ($opts->{scm_username} ne ''){
        $projectSpecifier .= "$opts->{scm_username}";
        if ($opts->{scm_password} ne ''){
            $projectSpecifier .= ':';
            #$passwordStart = length $projectSpecifier;
            $projectSpecifier .= $opts->{scm_password};
            #$passwordLength = (length $projectSpecifier) - $passwordStart;
        }
    }
    
    # Set the host name and "endpoint" (port) in the project specifier
    if ($opts->{scm_hostname} ne '') {    
        $projectSpecifier .= '@' . $opts->{scm_hostname};
        if ($opts->{scm_endpoint} ne '') {       
            $projectSpecifier .= ":$opts->{scm_endpoint}";
        }
    }

    # Set the project, view, and folder in the project specifier
    $projectSpecifier .= "/$opts->{scm_projectname}";
    if ($opts->{scm_viewname} ne '') {
        $projectSpecifier .= "/$opts->{scm_viewname}";
    }
    if ($opts->{scm_folderpath} ne '') {
        $projectSpecifier .= "/$opts->{scm_folderpath}";
    }
        
    my $tmpPS = '';
    # Add the password file if specified
    if ($opts->{scm_passwordfile} ne '') {
        my $pwdFileOption = ($opts->{scm_encryptedpasswordfile}) ?
            '-epwdfile' : '-pwdfile';
       $tmpPS .= qq| $pwdFileOption "$opts->{scm_passwordfile}"|;
    }  

    $tmpPS .= qq{ -p "};
    $tmpPS .= qq{$projectSpecifier"};

    return $tmpPS;
}

################################################################################
# copyDeltas
#
#       Finds all new and modified files and either copies them directly to
#       the job's workspace or transfers them via the server using putFiles.
#       The job is kicked off once the sources are ready to upload.
# 
#   Arguments: 
#    -opts array
#   Returns:
#    - void 
#   
#################################################################################
sub cpf_copyDeltas {
    my ($self, $opts) = @_;
    $self->cpf_display('Collecting delta information');

    $self->cpf_saveScmInfo($opts,$opts->{scm_endpoint} . "\n"
        . $opts->{scm_password} . "\n"
        . $opts->{scm_username} . "\n"
        . $opts->{scm_projectname} . "\n"
        . $opts->{scm_hostname} . "\n"
        . $opts->{scm_viewname} . "\n"
        . $opts->{scm_folderpath} . "\n"
        . $opts->{scm_addopts} . "\n");

    $self->cpf_findTargetDirectory($opts);
    $self->cpf_createManifestFiles($opts);

    # Collect a list of opened files.
    my $projectSpecifier = $self->cpf_genProjectSpec($opts);
    my $output = $self->cpf_st($opts,"list $projectSpecifier -short  -is -nologo -x",{LogCommand => 1, LogResult => 1});        
   
    $self->cpf_debug("output from opened=[$output]");
    chomp $output;
    if ($output eq '' || $output =~ /not opened on this client/ ) {
        $self->cpf_error('No file changes found.');
    }
    
    $opts->{rt_openedFiles} = $output;

    foreach(split(/\n/, $output)) {
        # Parse the output from StarTeam opened and figure out the file name and what
        # type of change is being made.
        # C = current, M = modified, G = merge, O = Out of date, I = missing, U = Unknown

        $_ =~ m/(C|M|G|O|I|U) (.*)/;
        my $type = $1;
        my $file = $2;
        my $source;
        my $dest;           	
        
        if ($file ne ''){
          $dest = $file;
          $dest =~ s/([A-Za-z0-9_-]*)[\\|\/]//;
        }
        
        $source = $file;

        $self->cpf_debug("source: $source dest: $dest file: $file type: $type \n");	

        # Add all files that are not missing to the putFiles operation.
        if ($source ne '' && $dest ne '') {           
            if ($type ne 'I' && $type ne 'C') {
                $self->cpf_addDelta($opts,$source, $dest);
            } else {
              if ($type eq 'I'){
                $self->cpf_addDelete($dest);
                }
            }
        }
    }

    $self->cpf_closeManifestFiles($opts);
    $self->cpf_uploadFiles($opts);
}

###########################################################################
# cpf-lastUpdate
#
#  Arguments:
#  -Opts array
#
#  Returns:
#  -lastUpdate date 
#
#############################################################################
sub cpf_lastUpdate(){
    my($self, $opts) = @_; 
    my $output = '';
    my $projectSpecifier = $self->cpf_genProjectSpec($opts);
    
    $output .= $self->cpf_st($opts,"hist -is -x $projectSpecifier", {DieOnError => 0});

    my $newestTime = 0;
    my $newestTimeString =  '';
    foreach my $line (split (/\n/, $output)) {
        if  ( $line =~ /^Author.*Date: (.*)/ ){
            # save the newest time
            my $timeStamp = $self->sentryTimeConvert($1);
            if ($timeStamp > $newestTime) {
                $newestTime = $timeStamp;
                # Store the newest time in ISO Format
                $newestTimeString =  time2str($timeStamp);
            }
        }
    }
    return $newestTimeString; 
}


#############################################################################
# autoCommit
#
#       Automatically commit changes in the user's client.  Error out if:
#       - A check-in has occurred since the preflight was started, and the
#         policy is set to die on any check-in.
#       - A check-in has occurred and opened files are out of sync with the
#         head of the branch.
#       - A check-in has occurred and non-opened files are out of sync with
#         the head of the branch, and the policy is set to die on any changes
#         within the client workspace.
##############################################################################
sub cpf_autoCommit(){
    my ($self, $opts) = @_;
    # Make sure none of the files have been touched since the build started.

    $self->cpf_checkTimestamps($opts);

    # Check the last update.  If there have been any changes,
    # error out.    
    
    my $timeString = $self->cpf_lastUpdate($opts);   
    
    # If the changelists are different, then check the policies.  If it is
    # set to always die on new check-ins, then error out.

    if ($timeString ne $opts->{scm_lastchange} && $opts->{opt_DieOnNewCheckins}) {
        $self->cpf_error('A check-in has been made since ecpreflight was started. '
            . 'Sync and resolve conflicts, then retry the preflight '
            . 'build');                
    }  
        
    #change to the folder in wich changes were made
    chdir($opts->{scm_workingdir});
    
    #commit the changes
    $self->cpf_display('Committing changes');
    
    my $projectSpecifier = $self->cpf_genProjectSpec($opts);
    my $cmdOut = $self->cpf_st($opts,"ci $projectSpecifier -nologo -x "); 
    
    $self->cpf_debug("command output: $cmdOut");
    $self->cpf_display('Changes have been successfully submitted');         
}

#------------------------------------------------------------------------------
# driver
#
#       Main program for the application.
#------------------------------------------------------------------------------
sub cpf_driver {
    my ($self, $opts) = @_;
    
    $::gHelpMessage .= "StarTeam Options:
    --projectname <project>    The StarTeam project name.
    --workingdir  <path>       Working dir of the updated files.
    --viewname    <view>       The of the view to use.
    --entrypoint  <number>     Entry point number.
    --hostname    <host>       Name/ip of the StarTeam server.
    --username    <user>       A valid user name to connect to StartTeam.
    --password    <pwd>        User's password.
    --addopts     <options>    Provide additional options to Starteam";

    $self->cpf_display('Executing StarTeam actions for ecpreflight');

    ## override config file with command line options 
    my %ScmOptions = (    
        "projectname=s"     => \$opts->{scm_projectname},      
        "workingdir=s"      => \$opts->{scm_workingdir},
        "view=s"            => \$opts->{scm_viewname},
        "entrypoint=n"      => \$opts->{scm_endpoint},
        "hostname=s"        => \$opts->{scm_hostname},
        "username=s"        => \$opts->{scm_username},
        "password=s"        => \$opts->{scm_password},
        "addopts=s"         => \$opts->{scm_addopts},
    );

    Getopt::Long::Configure('default');
    if (!GetOptions(%ScmOptions)) {
        error($::gHelpMessage);
    }

    if ($::gHelp eq '1') {
        $self->cpf_display($::gHelpMessage);
        return;
    }

    # Collect SCM-specific information from the configuration     
    # this block may be unnecessary now
      
    $self->extractOption($opts,'scm_projectname', { required => 1, cltOption => 'projectname' });
    $self->extractOption($opts,'scm_workingdir', { required => 1, cltOption => 'workingdir' });
    $self->extractOption($opts,'scm_viewname', { required => 0, cltOption => 'view' });
    $self->extractOption($opts,'scm_endpoint', { required => 0, cltOption => 'entrypoint' });
    $self->extractOption($opts,'scm_hostname', { required => 1, cltOption => 'hostname' });
    $self->extractOption($opts,'scm_username', { required => 1, cltOption => 'username' });
    $self->extractOption($opts,'scm_password', { required => 1, cltOption => 'password' });
    $self->extractOption($opts,'scm_addopts', { required => 0, cltOption => 'addopts' });
    
    $opts->{scm_lastchange} = $self->cpf_lastUpdate($opts);              
    
    # Copy the deltas to a specific location.
    $self->cpf_copyDeltas($opts);
    
    # Auto commit if the user has chosen to do so.

    if ($opts->{scm_autoCommit}) {
        if (!$opts->{opt_Testing}) {
            $self->cpf_waitForJob($opts);
        }
        $self->cpf_autoCommit($opts);
    }    
}

1;