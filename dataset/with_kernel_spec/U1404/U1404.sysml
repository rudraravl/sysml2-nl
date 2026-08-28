package ElectromagneticRelay {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::*;

	package Definitions {
		attribute def ControlVoltage :> ElectricPotentialValue;
		attribute def LoadCurrent :> ElectricCurrentValue;
		attribute def ContactPower :> PowerValue;
		attribute def SwitchingTime :> DurationValue;
		attribute def SpringForce :> ForceValue;

		port def ControlPort {
			attribute voltage : ControlVoltage;
		}

		port def LoadPort {
			attribute current : LoadCurrent;
		}

		part def ElectromagneticCoil {
			port controlInput : ControlPort;
			attribute resistance : ResistanceValue;
			attribute inductance : InductanceValue;
		}

		part def Armature {
			attribute mass : MassValue;
			attribute position : String;
		}

		part def ReturnSpring {
			attribute springConstant : Real;
			attribute restForce : SpringForce;
		}

		part def ContactSet {
			port loadPort1 : LoadPort;
			port loadPort2 : LoadPort;
			attribute maxPower : ContactPower;
			attribute material : String = "Silver Alloy";
			attribute normallyOpenClosed : Boolean = false;
			attribute normallyClosedClosed : Boolean = true;
		}

		action def EnergizeCoil;
		action def MoveArmature;
		action def SwitchContacts;
		action def DeenergizeCoil;
		action def ReturnArmature;

		state def RelayStates;

		part def Relay {
			port control : ControlPort;
			port load : LoadPort;

			attribute activationVoltage : ControlVoltage;
			attribute switchingTime : SwitchingTime;
			attribute maxContactPower : ContactPower;

			part coil : ElectromagneticCoil;
			part armature : Armature;
			part spring : ReturnSpring;
			part contacts : ContactSet;

			connect control to coil.controlInput;
			connect contacts.loadPort1 to load;

			exhibit state relayStates : RelayStates;
		}

		requirement def IsolationRequirement {
			subject relay : Relay;
			doc /* The control circuit and load circuit must be electrically isolated. */
		}

		requirement def SwitchingRequirement {
			subject relay : Relay;
			attribute requiredActivationVoltage : ControlVoltage;
			doc /* The relay must switch states when control voltage exceeds the activation voltage. */
		}

		requirement def PerformanceRequirement {
			subject relay : Relay;
			attribute maxSwitchingTime : SwitchingTime;
			attribute requiredMaxContactPower : ContactPower;
			doc /* The relay must switch within the specified time and handle the maximum contact power. */
		}
	}

	import Definitions::*;

	package Usages {
		private import Definitions::*;

		action 'energize coil' : EnergizeCoil;
		action 'move armature' : MoveArmature;
		action 'switch contacts' : SwitchContacts;
		action 'deenergize coil' : DeenergizeCoil;
		action 'return armature' : ReturnArmature;

		part relay : Relay {
			attribute activationVoltage = 5 [V];
			attribute switchingTime = 10 [ms];
			attribute maxContactPower = 100 [W];

			part coil : ElectromagneticCoil {
				attribute resistance = 100 [Ohm];
			}
			part armature : Armature {
				attribute mass = 0.05 [kg];
				attribute position = "open";
			}
			part spring : ReturnSpring {
				attribute springConstant = 10.0;
				attribute restForce = 2 [N];
			}
			part contacts : ContactSet {
				attribute maxPower = 100 [W];
			}

			state relayStates : RelayStates {
				entry; then de_energized;

				state de_energized;
				accept when relay.control.voltage > relay.activationVoltage
					do 'energize coil'
					then energizing;

				state energizing {
					entry 'move armature';
					do 'switch contacts';
				}
				accept after relay.switchingTime
					then energized;

				state energized;
				accept when relay.control.voltage < relay.activationVoltage
					do 'deenergize coil'
					then releasing;

				state releasing {
					entry 'return armature';
				}
				accept after relay.switchingTime
					then de_energized;
			}
		}

		requirement isolation : IsolationRequirement;
		requirement switching : SwitchingRequirement {
			attribute requiredActivationVoltage = 5 [V];
		}
		requirement performance : PerformanceRequirement {
			attribute maxSwitchingTime = 10 [ms];
			attribute requiredMaxContactPower = 100 [W];
		}
	}
}
