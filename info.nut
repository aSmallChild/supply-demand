class SupplyDemandInfo extends GSInfo {
	function GetAuthor()		{ return "SimeonW"; }
	function GetName()			{ return "Supply & Demand (DEV)"; }
	function GetDescription() 	{ return "Industries scale to meed the demand of towns. Towns grow when supplied."; }
	function GetVersion()		{ return 1; }
	function GetDate()			{ return "2025-07-13"; }
	function CreateInstance()	{ return "SupplyDemand"; }
	function GetShortName()		{ return "SDSD"; }
	function GetAPIVersion()	{ return "1.3"; }
	function GetURL()			{ return "https://github.com/aSmallChild/supply-demand"; }

	function GetSettings()
	{

	}
}

RegisterGS(SupplyDemandInfo());
