my $projPrincipal = "project: $pluginName";
my $ecscmProj = '$[/plugins/ECSCM/project]';

if ($promoteAction eq 'promote') {
    # The plugin is being promoted, register with the base scm plugin
    $batch->setProperty("/plugins/ECSCM/project/scm_types/@PLUGIN_KEY@", 'StarTeam');
	
	 # Give our project principal execute access to the ECSCM project
    my $xpath = $commander->getAclEntry("user", $projPrincipal,
                                        {projectName => $ecscmProj});
    if ($xpath->findvalue('//code') eq 'NoSuchAclEntry') {
        $batch->createAclEntry("user", $projPrincipal,
                               {projectName => $ecscmProj,
                                executePrivilege => "allow"});
}
} elsif ($promoteAction eq 'demote') {
    $batch->deleteProperty("/plugins/ECSCM/project/scm_types/@PLUGIN_KEY@");
	
	    # remove permissions
    my $xpath = $commander->getAclEntry("user", $projPrincipal,
                                        {projectName => $ecscmProj});
    if ($xpath->findvalue('//principalName') eq $projPrincipal) {
        $batch->deleteAclEntry("user", $projPrincipal,
                               {projectName => $ecscmProj});
    }
}

# Unregister current and past entries first.
$batch->deleteProperty("/server/ec_customEditors/pickerStep/ECSCM-StarTeam - Checkout");
$batch->deleteProperty("/server/ec_customEditors/pickerStep/ECSCM-StarTeam - Preflight");
$batch->deleteProperty("/server/ec_customEditors/pickerStep/StarTeam - Checkout");
$batch->deleteProperty("/server/ec_customEditors/pickerStep/StarTeam - Preflight");

# Data that drives the create step picker registration for this plugin.
my %checkoutStep = (
    label       => "StarTeam - Checkout",
    procedure   => "CheckoutCode",
    description => "Checkout code from StarTeam.",
    category    => "Source Code Management"
);
my %Preflight = (
	label 		=> "StarTeam - Preflight",
	procedure 	=> "Preflight",
	description => "Checkout code from StarTeam during Preflight",
	category 	=> "Source Code Management"
);
@::createStepPickerSteps = (\%checkoutStep, \%Preflight);
