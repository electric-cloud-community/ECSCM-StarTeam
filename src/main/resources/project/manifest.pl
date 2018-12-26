@files = (
    ['//property[propertyName="ECSCM::StarTeam::Cfg"]/value', 'StarTeamCfg.pm'],
    ['//property[propertyName="ECSCM::StarTeam::Driver"]/value', 'StarTeamDriver.pm'],
    ['//property[propertyName="sentry"]/value', 'starTeamSentryForm.xml'],
    ['//property[propertyName="checkout"]/value', 'starTeamCheckoutForm.xml'],
    ['//property[propertyName="createConfig"]/value', 'starTeamCreateConfigForm.xml'],
    ['//property[propertyName="trigger"]/value', 'starTeamTriggerForm.xml'],
	['//property[propertyName="editConfig"]/value', 'starTeamEditConfigForm.xml'],
	['//property[propertyName="preflight"]/value', 'starTeamPreflightForm.xml'],
    ['//property[propertyName="ec_setup"]/value', 'ec_setup.pl'],    
	['//procedure[procedureName="CheckoutCode"]/propertySheet/property[propertyName="ec_parameterForm"]/value', 'starTeamCheckoutForm.xml'],
	['//procedure[procedureName="Preflight"]/propertySheet/property[propertyName="ec_parameterForm"]/value', 'starTeamPreflightForm.xml'],
);
