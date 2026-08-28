package AutoclaveSterilizationSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	package Definitions {
		attribute def TemperatureValue :> Real;
		attribute def PressureValue :> Real;
		attribute def DurationValue :> Real;

		attribute def 'Start Cycle Command';
		attribute def 'Cycle Complete Signal';
		attribute def 'Exposure Complete Signal';
		attribute def 'Start Steam Signal';
		attribute def 'Cooling Complete Signal';

		item def Water;
		item def SaturatedSteam {
			attribute temp : TemperatureValue = 394.15 [K];
			attribute pressure : PressureValue = 205000 [Pa];
		}

		part def AdhesiveBacking {
			attribute maxWithstandTemp : TemperatureValue = 423.15 [K];
			attribute bondStrength : PressureValue = 500000 [Pa];
			attribute 'bond maintained' : Boolean = true;
		}

		state def 'Indicator States';
		state def 'Generator States';
		state def 'Control States';

		action def 'Generate Steam' {
			in item water : Water;
			out item steam : SaturatedSteam;
		}

		action def 'Monitor Exposure' {
			out time : DurationValue;
		}

		part def ChemicalIndicator {
			attribute color : String = "beige";
			exhibit state 'indicator states' : 'Indicator States';
		}

		part def AutoclaveTape {
			part backing : AdhesiveBacking;
			part indicator : ChemicalIndicator;
		}

		part def SterilizationItem;
		part def SterilizationPackage {
			part 'sealed item' : SterilizationItem;
			part tape : AutoclaveTape;
		}

		part def SteamGenerator {
			flow water : Water;
			flow steam : SaturatedSteam;
			perform action 'generate steam' : 'Generate Steam';
			exhibit state 'generator states' : 'Generator States';
		}

		part def SealedChamber {
			flow steam : SaturatedSteam;
			part packages[*] : SterilizationPackage;
			attribute internalTemp : TemperatureValue;
			attribute internalPressure : PressureValue;
		}

		part def ControlSystem {
			ref 'steam generator' : SteamGenerator;
			ref 'sealed chamber' : SealedChamber;
			attribute 'cycle time' : DurationValue = 900 [s];
			attribute 'elapsed time' : DurationValue = 0 [s];
			perform action 'monitor exposure' : 'Monitor Exposure';
			exhibit state 'control states' : 'Control States';
		}

		part def AutoclaveMachine {
			part 'steam generator' : SteamGenerator;
			part 'sealed chamber' : SealedChamber;
			part 'control system' : ControlSystem;
			flow 'steam generator'.steam to 'sealed chamber'.steam;
		}

		part def Operator;

		action def 'Perform Sterilization' {
			in packages : SterilizationPackage;
		}
	}

	package Usages {
		private import Definitions::*;

		action 'generate steam' : 'Generate Steam';
		action 'monitor exposure' : 'Monitor Exposure';

		part autoclave : AutoclaveMachine {
			part 'steam generator' : SteamGenerator;
			part 'sealed chamber' : SealedChamber {
				part packages[*] : SterilizationPackage {
					part tape : AutoclaveTape;
				}
			}
			part 'control system' : ControlSystem {
				ref 'steam generator' = autoclave.'steam generator';
				ref 'sealed chamber' = autoclave.'sealed chamber';
			}
		}

		part operator : Operator;

		state 'indicator states' : 'Indicator States' {
			entry; then beige;
			state beige;
			transition 'beige-to-green'
				first beige
				accept 'Exposure Complete Signal'
				then green;
			state green;
		}

		state 'generator states' : 'Generator States' {
			entry; then idle;
			state idle;
			transition 'idle-to-generating'
				first idle
				accept 'Start Steam Signal'
				then 'generating';
			state 'generating' {
				do 'generate steam';
			}
		}

		state 'control states' : 'Control States' {
			entry; then idle;
			state idle;
			transition 'idle-to-sterilizing'
				first idle
				accept 'Start Cycle Command'
				do send new 'Start Steam Signal'() to autoclave.'steam generator'
				then 'sterilizing';
			state 'sterilizing' {
				entry;
				do 'monitor exposure';
			}
			transition 'sterilizing-to-cooling'
				first 'sterilizing'
				accept when 'monitor exposure'.time >= autoclave.'control system'.'cycle time'
				do send new 'Exposure Complete Signal'() to autoclave.'sealed chamber'
				then 'cooling down';
			state 'cooling down';
			transition 'cooling-to-idle'
				first 'cooling down'
				accept 'Cooling Complete Signal'
				do send new 'Cycle Complete Signal'() to operator
				then idle;
		}

		action 'perform sterilization' : 'Perform Sterilization' {
			action 'generate steam usage' : 'Generate Steam' {
				in water : Water;
				out steam : SaturatedSteam;
			}
			flow 'generate steam usage'.steam to autoclave.'sealed chamber'.steam;
			action 'expose to steam' {
				in steam : SaturatedSteam;
				in packages : SterilizationPackage;
				out 'exposed packages' : SterilizationPackage;
			}
		}
	}

	package Requirements {
		private import Definitions::*;
		private import Usages::*;

		requirement def 'Sterilization Requirement' {
			doc /* The system must sterilize equipment using saturated steam at 121 C (394.15 K) and 205 kPa for at least 15 minutes. */
			subject autoclave : AutoclaveMachine;
			objective {
				assume autoclave.'steam generator'.steam.temp == 394.15 [K];
				assume autoclave.'steam generator'.steam.pressure == 205000 [Pa];
				assume autoclave.'control system'.'cycle time' >= 900 [s];
			}
		}

		requirement def 'Tape Visual Confirmation Requirement' {
			doc /* The tape must provide visual confirmation of successful sterilization by changing from beige to green. */
			subject tape : AutoclaveTape;
			objective {
				assume tape.indicator.color == "green";
			}
		}

		requirement def 'Adhesive Robustness Requirement' {
			doc /* The adhesive backing must maintain its bond at temperatures up to 150 C (423.15 K). */
			subject backing : AdhesiveBacking;
			objective {
				assume backing.'bond maintained' == true;
			}
		}

		requirement 'sterilization req' : 'Sterilization Requirement';

		requirement 'tape confirmation req' : 'Tape Visual Confirmation Requirement';

		requirement 'adhesive robustness req' : 'Adhesive Robustness Requirement';
	}
}
