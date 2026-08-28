package TENS_Device {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	package Definitions {
		attribute def ImpedanceValue :> Real;
		attribute def CurrentValue :> Real;
		attribute def VoltageValue :> Real;
		attribute def FrequencyValue :> Real;
		attribute def TimeValue :> Real;
		attribute def ChargeValue :> Real;

		item def PowerOn;
		item def PowerOff;
		item def ModeSelect { attribute mode : String; }
		item def IntensityAdjust { attribute level : Real; }
		item def ElectrodeFault;

		port def UserInputPort {
			in powerOn : PowerOn;
			in powerOff : PowerOff;
			in modeSelect : ModeSelect;
			in intensityAdjust : IntensityAdjust;
		}

		port def PowerPort {
			out voltage : VoltageValue;
		}

		port def PulseCmdPort {
			out frequency : FrequencyValue;
			out pulseWidth : TimeValue;
			out amplitude : VoltageValue;
		}

		port def PulseOutPort {
			out pulse : PulseCmdPort;
		}

		port def ImpedanceInPort {
			in impedance : ImpedanceValue;
		}

		port def SafetyOutPort {
			out fault : ElectrodeFault;
		}

		action def GeneratePulse;
		action def MonitorImpedance { out impedance : ImpedanceValue; }
		action def ShutdownTherapy;

		state def DeviceStates;

		requirement def SafeCurrentLimit {
			doc /* The device shall not deliver electrical current exceeding 50 mA. */
		}

		requirement def ElectrodeContactSafety {
			doc /* Therapy shall automatically shut down if skin impedance exceeds 5000 Ohm. */
		}

		part def MicrocontrollerUnit {
			port userIn : UserInputPort;
			port powerIn : ~PowerPort;
			port pulseCmdOut : PulseCmdPort;
			port safetyIn : ~SafetyOutPort;
			attribute currentMode : String;
			attribute currentIntensity : Real;
		}

		part def UserControlPanel {
			port userOut : ~UserInputPort;
		}

		part def BatteryPack {
			port powerOut : PowerPort;
			attribute capacity : ChargeValue;
		}

		part def PulseGeneratorCircuit {
			port cmdIn : ~PulseCmdPort;
			port powerIn : ~PowerPort;
			port electrodeOut : PulseOutPort;
			perform action generatePulse : GeneratePulse;
		}

		part def ElectrodePad {
			port pulseIn : ~PulseOutPort;
			port impedanceOut : ~ImpedanceInPort;
			attribute skinImpedance : ImpedanceValue;
		}

		part def SafetyMonitoringSystem {
			port senseIn : ImpedanceInPort;
			port safetyOut : SafetyOutPort;
			attribute maxImpedance : ImpedanceValue = 5000;
			attribute maxCurrent : CurrentValue = 50;
			perform action monitorImpedance : MonitorImpedance;
		}

		part def TENSDevice {
			part mcu : MicrocontrollerUnit;
			part panel : UserControlPanel;
			part battery : BatteryPack;
			part pulseGen : PulseGeneratorCircuit;
			part anode : ElectrodePad;
			part cathode : ElectrodePad;
			part safety : SafetyMonitoringSystem;

			action generatePulse : GeneratePulse;
			action monitorImpedance : MonitorImpedance;
			action shutdownTherapy : ShutdownTherapy;

			connect panel.userOut to mcu.userIn;
			connect battery.powerOut to mcu.powerIn;
			connect battery.powerOut to pulseGen.powerIn;
			connect mcu.pulseCmdOut to pulseGen.cmdIn;
			connect pulseGen.electrodeOut to anode.pulseIn;
			connect pulseGen.electrodeOut to cathode.pulseIn;
			connect anode.impedanceOut to safety.senseIn;
			connect cathode.impedanceOut to safety.senseIn;
			connect safety.safetyOut to mcu.safetyIn;

			exhibit state deviceStates : DeviceStates {
				entry; then off;
				state off;
				accept PowerOn
					then standby;
				state standby;
				accept ModeSelect
					then active;
				accept IntensityAdjust
					then standby;
				accept PowerOff
					then off;
				state active {
					do generatePulse;
					do monitorImpedance;
				}
				accept ElectrodeFault
					do shutdownTherapy
					then fault;
				accept PowerOff
					then off;
				state fault;
				accept PowerOff
					then off;
			}
		}
	}

	package Usages {
		private import Definitions::*;

		part tensDevice : TENSDevice;
	}
}
