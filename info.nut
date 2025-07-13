class SupplyDemandInfo extends GSInfo {
	function GetAuthor()		{ return "SimeonW"; }
	function GetName()			{ return "Supply & Demand"; }
	function GetDescription() 	{ return "Industries scale to meed the demand of cities. Cities grow when supplied."; }
	function GetVersion()		{ return 1; }
	function GetDate()			{ return "2025-07-13"; }
	function CreateInstance()	{ return "SupplyDemand"; }
	function GetShortName()		{ return "SDSD"; }
	function GetAPIVersion()	{ return "1.3"; }
	function GetURL()			{ return ""; }

	function GetSettings()
	{

	}
}

RegisterGS(SupplyDemandInfo());
