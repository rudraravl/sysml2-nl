package 'Froth Pumping Subsystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	package Definitions {
		item def Froth {
			attribute gasVolumeFraction : Real;
			attribute solidMassFraction : Real;
		}

		item def MechanicalPower;
		item def ControlSignal;

		port def FrothPort {
			out item froth : Froth;
		}

		port def MechanicalShaftPort {
			out item mechanicalPower : MechanicalPower;
		}

		port def ControlSignalPort {
			out item signal : ControlSignal;
		}

		part def SupplyTank {
			port frothOut : FrothPort;
		}

		part def ReceivingTank {
			port frothIn : ~FrothPort;
		}

		part def SuctionPipe {
			port frothIn : ~FrothPort;
			port frothOut : FrothPort;
			attribute innerDiameter : LengthValue = 0.3 [m];
			attribute liningMaterial : String = "rubber-lined steel";
		}

		part def DischargePipe {
			port frothIn : ~FrothPort;
			port frothOut : FrothPort;
			attribute innerDiameter : LengthValue = 0.15 [m];
			attribute liningMaterial : String = "rubber-lined steel";
		}

		part def ControlValve {
			port frothIn : ~FrothPort;
			port frothOut : FrothPort;
			port controlIn : ~ControlSignalPort;
			attribute openingFraction : Real = 0.5;
		}

		part def FrothPump {
			port frothIn : ~FrothPort;
			port frothOut : FrothPort;
			port driveShaft : ~MechanicalShaftPort;
			attribute casingMaterial : String = "high-chrome white iron";
			attribute impellerBlades : Integer = 3;
			attribute sealType : String = "double mechanical seal";
		}

		part def ElectricMotor {
			port shaftOut : MechanicalShaftPort;
			port controlIn : ~ControlSignalPort;
			attribute ratedPower : PowerValue = 250 [kW];
		}

		part def PressureGauge {
			attribute reading : PressureValue;
		}

		part def FlowMeter {
			attribute flowRateReading : VolumeFlowRateValue;
		}

		part def PumpController {
			port commandValveOut : ControlSignalPort;
			port commandMotorOut : ControlSignalPort;
		}

		action def PrimePump;
		action def AccelerateMotor;
		action def MonitorConditions;
		action def NormalShutdown;
		action def EmergencyShutdown;
		action def TriggerAlarm;

		attribute def StartCommand;
		attribute def PrimeComplete;
		attribute def TargetSpeedReached;
		attribute def NormalStopCommand;
		attribute def EmergencyStopCommand;
		attribute def ShutdownComplete;
		attribute def EmergencyReset;
		attribute def LowFlowAlert;
		attribute def HighPressureAlert;
		attribute def CavitationAlert;

		state def PumpStates;

		requirement def TransportFroth {
			/* The system shall transport froth from the supply tank to the receiving tank through a network of pipes. */
		}

		requirement def HandleAbrasiveAeratedFluid {
			/* The pump shall handle abrasive and aerated froth without clogging using a wear-resistant high-chrome white iron casing and a three-blade impeller. */
		}

		requirement def PreventLeaks {
			/* The pump shall use a double mechanical seal to prevent leaks. */
		}

		requirement def MonitorAdverseConditions {
			/* The control system shall monitor low flow, excessive discharge pressure, and cavitation during operation. */
		}

		requirement def ProvideShutdownProcedures {
			/* The system shall provide normal and emergency shutdown procedures. */
		}

		requirement def InstrumentationRequirement {
			/* Pressure gauges shall be installed on suction and discharge sides; a flow meter shall measure discharge output. */
		}
	}

	package Usages {
		private import Definitions::*;

		part pumpingSubsystem {
			part supplyTank : SupplyTank;
			part suctionPipe : SuctionPipe;
			part frothPump : FrothPump;
			part dischargePipe : DischargePipe;
			part controlValve : ControlValve;
			part receivingTank : ReceivingTank;
			part electricMotor : ElectricMotor;
			part suctionPressureGauge : PressureGauge;
			part dischargePressureGauge : PressureGauge;
			part dischargeFlowMeter : FlowMeter;
			part controller : PumpController;

			flow of froth : Froth
				from supplyTank.frothOut.froth to suctionPipe.frothIn.froth;
			flow of froth : Froth
				from suctionPipe.frothOut.froth to frothPump.frothIn.froth;
			flow of froth : Froth
				from frothPump.frothOut.froth to dischargePipe.frothIn.froth;
			flow of froth : Froth
				from dischargePipe.frothOut.froth to controlValve.frothIn.froth;
			flow of froth : Froth
				from controlValve.frothOut.froth to receivingTank.frothIn.froth;

			flow of mechanicalPower : MechanicalPower
				from electricMotor.shaftOut.mechanicalPower to frothPump.driveShaft.mechanicalPower;

			flow of controlSignal : ControlSignal
				from controller.commandValveOut.signal to controlValve.controlIn.signal;
			flow of controlSignal : ControlSignal
				from controller.commandMotorOut.signal to electricMotor.controlIn.signal;

			requirement req1 : TransportFroth;
			requirement req2 : HandleAbrasiveAeratedFluid;
			requirement req3 : PreventLeaks;
			requirement req4 : MonitorAdverseConditions;
			requirement req5 : ProvideShutdownProcedures;
			requirement req6 : InstrumentationRequirement;

			satisfy req1 by pumpingSubsystem;
			satisfy req2 by frothPump;
			satisfy req3 by frothPump;
			satisfy req4 by controller;
			satisfy req5 by controller;
			satisfy req6 by pumpingSubsystem;

			state pumpStates : PumpStates {
				entry; then stopped;

				state stopped;
				accept StartCommand
					do PrimePump
					then priming;

				state priming;
				accept PrimeComplete
					then accelerating;

				state accelerating;
				accept TargetSpeedReached
					then running;

				state running {
					do action monitorConditions : MonitorConditions;
				}
				accept LowFlowAlert
					do TriggerAlarm
					then emergencyShutdown;
				accept HighPressureAlert
					do TriggerAlarm
					then emergencyShutdown;
				accept CavitationAlert
					do TriggerAlarm
					then emergencyShutdown;
				accept NormalStopCommand
					then normalShutdown;

				state normalShutdown {
					do NormalShutdown;
				}
				accept ShutdownComplete
					then stopped;

				accept EmergencyStopCommand
					then emergencyShutdown;

				state emergencyShutdown {
					do EmergencyShutdown;
				}
				accept EmergencyReset
					then stopped;
			}
		}
	}
}
