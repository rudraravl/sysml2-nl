package NdYAGLaserSystem {
	private import ScalarValues::*;
	private import ISQ::*;

	package Definitions {
		item def ACPower {
			attribute voltage : Real = 220;
			attribute frequency : Real = 50;
		}

		item def DCPower {
			attribute voltage : Real;
			attribute current : Real;
		}

		item def PumpLight {
			attribute intensity : Real;
		}

		item def LaserBeam {
			attribute power : Real;
			attribute wavelength : Real = 1064;
		}

		item def Coolant {
			attribute temperature : Real;
			attribute flowRate : Real;
		}

		item def ControlCommand {
			attribute mode : String;
			attribute setpoint : Real;
		}

		item def FeedbackSignal {
			attribute measuredPower : Real;
			attribute temperature : Real;
			attribute faultFlag : Boolean;
		}

		attribute def InitSignal;
		attribute def InitCompleteSignal;
		attribute def ActiveSignal;
		attribute def StopSignal;
		attribute def CoolingCompleteSignal;
		attribute def FaultSignal;
		attribute def ResetSignal;

		action def ConvertPower {
			in ac : ACPower;
			out dc : DCPower;
		}

		action def GeneratePumpLight {
			in dc : DCPower;
			out pump : PumpLight;
		}

		action def AmplifyLight {
			in pump : PumpLight;
			out beam : LaserBeam;
		}

		action def QSwitchPulse {
			in inBeam : LaserBeam;
			out outBeam : LaserBeam;
		}

		action def DeliverBeam {
			in inBeam : LaserBeam;
			out outBeam : LaserBeam;
		}

		action def MeasureBeam {
			in beam : LaserBeam;
			out feedback : FeedbackSignal;
		}

		action def CoolSystem {
			out coolant : Coolant;
		}

		action def RegulatePower {
			in feedback : FeedbackSignal;
			out command : ControlCommand;
		}

		action def InitializeSystem;
		action def ShutdownSystem;
		action def ReportFault;

		state def LaserControllerStates;

		part def PowerSupply {
			port acIn { in acPower : ACPower; }
			port dcOut { out dcPower : DCPower; }
			port controlIn { in command : ControlCommand; }
			perform action convertPower : ConvertPower;
		}

		part def XenonFlashlamp {
			port dcIn { in dcPower : DCPower; }
			port pumpLightOut { out pumpLight : PumpLight; }
			port coolantIn { in coolant : Coolant; }
			port coolantOut { out coolant : Coolant; }
			port controlIn { in command : ControlCommand; }
			perform action generatePump : GeneratePumpLight;
		}

		part def NdYAGCrystal {
			port pumpLightIn { in pumpLight : PumpLight; }
			port laserBeamOut { out laserBeam : LaserBeam; }
			port coolantIn { in coolant : Coolant; }
			port coolantOut { out coolant : Coolant; }
			perform action amplify : AmplifyLight;
		}

		part def QSwitch {
			port beamIn { in inBeam : LaserBeam; }
			port beamOut { out outBeam : LaserBeam; }
			port controlIn { in command : ControlCommand; }
			perform action pulse : QSwitchPulse;
		}

		part def OpticalResonator {
			port beamOut { out rawBeam : LaserBeam; }
			port electricalIn { in dcPower : DCPower; }
			port controlIn { in command : ControlCommand; }
			port coolantIn { in coolant : Coolant; }
			port coolantOut { out coolant : Coolant; }

			part crystal : NdYAGCrystal;
			part flashlamp : XenonFlashlamp;
			part qSwitch : QSwitch;

			flow pumpFlow of PumpLight
				from flashlamp.pumpLightOut.pumpLight to crystal.pumpLightIn.pumpLight;
			flow beamFlow1 of LaserBeam
				from crystal.laserBeamOut.laserBeam to qSwitch.beamIn.inBeam;
			flow beamFlow2 of LaserBeam
				from qSwitch.beamOut.outBeam to beamOut.rawBeam;
			flow powerFlow of DCPower
				from electricalIn.dcPower to flashlamp.dcIn.dcPower;
			flow controlToFlashlamp of ControlCommand
				from controlIn.command to flashlamp.controlIn.command;
			flow controlToQSwitch of ControlCommand
				from controlIn.command to qSwitch.controlIn.command;
			flow coolantToCrystal of Coolant
				from coolantIn.coolant to crystal.coolantIn.coolant;
			flow coolantFromCrystal of Coolant
				from crystal.coolantOut.coolant to coolantOut.coolant;
			flow coolantToFlashlamp of Coolant
				from coolantIn.coolant to flashlamp.coolantIn.coolant;
			flow coolantFromFlashlamp of Coolant
				from flashlamp.coolantOut.coolant to coolantOut.coolant;
		}

		part def BeamDelivery {
			port beamIn { in rawBeam : LaserBeam; }
			port beamOut { out outputBeam : LaserBeam; }
			perform action deliver : DeliverBeam;
		}

		part def PowerMeter {
			port beamIn { in outputBeam : LaserBeam; }
			port feedbackOut { out feedback : FeedbackSignal; }
			perform action measure : MeasureBeam;
		}

		part def CoolingSystem {
			port coolantOut { out coolant : Coolant; }
			port coolantReturn { in coolant : Coolant; }
			port controlIn { in command : ControlCommand; }
			perform action cool : CoolSystem;
		}

		part def LaserController {
			port feedbackIn { in feedback : FeedbackSignal; }
			port controlOut { out command : ControlCommand; }
			port userCmdIn { in userCmd : ControlCommand; }

			perform action regulate : RegulatePower;
			perform action initialize : InitializeSystem;
			perform action shutdown : ShutdownSystem;
			perform action reportFault : ReportFault;

			exhibit state 'controller states' : LaserControllerStates parallel {
				state 'operational states' {
					entry; then off;

					state off;
					accept InitSignal
						do initialize
						then initializing;

					state initializing;
					accept InitCompleteSignal
						then standby;

					state standby;
					accept ActiveSignal
						then active;
					accept StopSignal
						then off;

					state active {
						do regulate;
					}
					accept StopSignal
						do shutdown
						then cooling;

					state cooling;
					accept CoolingCompleteSignal
						then standby;
				}

				state 'safety states' {
					entry; then normal;

					state normal;
					accept FaultSignal
						do reportFault
						then fault;

					state fault;
					accept ResetSignal
						then normal;
				}
			}
		}

		part def NdYAGLaserSystem {
			port acInput { in acPower : ACPower; }
			port laserOutput { out outputBeam : LaserBeam; }

			part powerSupply : PowerSupply;
			part resonator : OpticalResonator;
			part beamDelivery : BeamDelivery;
			part powerMeter : PowerMeter;
			part coolingSystem : CoolingSystem;
			part controller : LaserController;

			flow acFlow of ACPower
				from acInput.acPower to powerSupply.acIn.acPower;
			flow dcFlow of DCPower
				from powerSupply.dcOut.dcPower to resonator.electricalIn.dcPower;
			flow rawBeamFlow of LaserBeam
				from resonator.beamOut.rawBeam to beamDelivery.beamIn.rawBeam;
			flow outputBeamFlow of LaserBeam
				from beamDelivery.beamOut.outputBeam to laserOutput.outputBeam;
			flow sampleBeamFlow of LaserBeam
				from beamDelivery.beamOut.outputBeam to powerMeter.beamIn.outputBeam;
			flow feedbackFlow of FeedbackSignal
				from powerMeter.feedbackOut.feedback to controller.feedbackIn.feedback;
			flow coolantFlow of Coolant
				from coolingSystem.coolantOut.coolant to resonator.coolantIn.coolant;
			flow coolantReturnFlow of Coolant
				from resonator.coolantOut.coolant to coolingSystem.coolantReturn.coolant;
			flow controlFlowPS of ControlCommand
				from controller.controlOut.command to powerSupply.controlIn.command;
			flow controlFlowRes of ControlCommand
				from controller.controlOut.command to resonator.controlIn.command;
			flow controlFlowCool of ControlCommand
				from controller.controlOut.command to coolingSystem.controlIn.command;
		}

		requirement def LaserSystemRequirements {
			doc "High-power Nd:YAG laser system requirements.";

			requirement WavelengthRequirement {
				doc "The laser output wavelength shall be 1064 nm.";
				subject beam : LaserBeam;
				constraint { beam.wavelength == 1064 }
			}

			requirement PowerRegulationRequirement {
				doc "The controller shall regulate output power based on real-time feedback.";
			}

			requirement SafetyRequirement {
				doc "The system shall enter a fault state upon detecting critical faults.";
			}

			requirement CoolingRequirement {
				doc "A closed-loop cooling system shall maintain stable operating temperature.";
			}
		}
	}

	package Usages {
		private import Definitions::*;

		part laserSystem : NdYAGLaserSystem;

		requirement 'laser system requirements' : LaserSystemRequirements;
	}
}
