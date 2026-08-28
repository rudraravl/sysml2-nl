package 'HighPressureMudPumpingSystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	package Definitions {
		item def DrillingMud {
			attribute density : MassDensityValue;
			attribute viscosity : DynamicViscosityValue;
			attribute flowRate : VolumeFlowRateValue;
		}

		item def Power;

		attribute def 'StartCommand';
		attribute def 'PumpStarted';
		attribute def 'StopCommand';
		attribute def 'PumpStopped';
		attribute def 'PressureNormalized';
		attribute def 'EmergencyStop';

		port def MudPort {
			out item mud : DrillingMud;
		}

		port def MechanicalPowerPort {
			out item power : Power;
			out torque : TorqueValue;
			out rotationalSpeed : Real;
		}

		part def MudPit {
			port mudOutPort : MudPort;
			attribute volume : VolumeValue;
		}

		part def SuctionLine {
			port mudInPort : ~MudPort;
			port mudOutPort : MudPort;
			attribute diameter : LengthValue;
		}

		part def PistonAssembly {
			part piston;
			part liner;
			part valve;
		}

		part def FluidEnd {
			port mudInPort : ~MudPort;
			port mudOutPort : MudPort;
			port mechanicalInPort : ~MechanicalPowerPort;
			part pistonAssemblies : PistonAssembly[3];
		}

		part def PowerEnd {
			port powerInPort : ~MechanicalPowerPort;
			port powerOutPort : MechanicalPowerPort;
		}

		part def MudPump {
			port mudInPort : ~MudPort;
			port mudOutPort : MudPort;
			port powerInPort : ~MechanicalPowerPort;
			part powerEnd : PowerEnd;
			part fluidEnd : FluidEnd;
			attribute dischargePressure : PressureValue;
			attribute maxPressure : PressureValue;

			bind powerInPort = powerEnd.powerInPort;
			bind powerEnd.powerOutPort = fluidEnd.mechanicalInPort;
			bind mudInPort = fluidEnd.mudInPort;
			bind mudOutPort = fluidEnd.mudOutPort;
		}

		part def PrimeDriver {
			port powerOutPort : MechanicalPowerPort;
			attribute maxPower : PowerValue;
		}

		part def DischargeLine {
			port mudInPort : ~MudPort;
			port mudOutPort : MudPort;
			attribute pressureRating : PressureValue;
		}

		part def Wellbore {
			port mudInPort : ~MudPort;
			attribute depth : LengthValue;
		}

		part def MudPumpingSystem {
			part mudPit : MudPit;
			part suctionLine : SuctionLine;
			part mudPump : MudPump;
			part primeDriver : PrimeDriver;
			part dischargeLine : DischargeLine;
			part wellbore : Wellbore;

			flow of mud : DrillingMud from mudPit.mudOutPort.mud to suctionLine.mudInPort.mud;
			flow of mud : DrillingMud from suctionLine.mudOutPort.mud to mudPump.mudInPort.mud;
			flow of mud : DrillingMud from mudPump.mudOutPort.mud to dischargeLine.mudInPort.mud;
			flow of mud : DrillingMud from dischargeLine.mudOutPort.mud to wellbore.mudInPort.mud;

			flow of power : Power from primeDriver.powerOutPort.power to mudPump.powerInPort.power;
		}

		action def 'Pump Mud' {
			in mudIn : DrillingMud;
			out mudOut : DrillingMud;
			out dischargePressure : PressureValue;
		}

		action def 'Control Flow Rate' {
			in targetFlowRate : VolumeFlowRateValue;
			in actualFlowRate : VolumeFlowRateValue;
			out speedAdjustment : Real;
		}

		state def 'System Operation States';

		requirement def 'Circulate Mud Requirement' {
			doc /* The system shall circulate drilling mud from the mud pit to the wellbore. */
			subject system : MudPumpingSystem;
		}

		requirement def 'Discharge Pressure Requirement' {
			doc /* The discharge line shall withstand the maximum operating pressure. */
			subject dischargeLine : DischargeLine;
			attribute maxOperatingPressure : PressureValue;
			require constraint { dischargeLine.pressureRating >= maxOperatingPressure }
		}

		requirement def 'Flow Rate Control Requirement' {
			doc /* The system shall maintain the target flow rate by adjusting pump speed. */
			subject controlLoop : 'Control Flow Rate';
			attribute targetFlowRate : VolumeFlowRateValue;
			attribute tolerance : VolumeFlowRateValue;
			require constraint { controlLoop.actualFlowRate - controlLoop.targetFlowRate <= tolerance and controlLoop.targetFlowRate - controlLoop.actualFlowRate <= tolerance }
		}
	}

	package Usages {
		private import Definitions::*;

		part systemContext : MudPumpingSystem {
			attribute 'Max Pressure Limit' : PressureValue = 500000000[Pa];

			part mudPit : MudPit {
				attribute volume : VolumeValue = 100[m**3];
			}

			part suctionLine : SuctionLine {
