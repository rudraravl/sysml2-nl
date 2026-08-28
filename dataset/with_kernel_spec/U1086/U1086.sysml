package 'Autonomous Planetary Drilling System' {
	private import ScalarValues::Real;
	private import ScalarValues::Boolean;
	private import ScalarValues::Integer;

	unit degC;
	unit watt;
	unit meter;
	unit gram;

	value def Temperature :> Real { unit = degC; }
	value def Power :> Real { unit = watt; }
	value def Length :> Real { unit = meter; }
	value def Mass :> Real { unit = gram; }

	item def ElectricalPower;
	item def Command {
		attribute targetDepth : Length;
		attribute deploy : Boolean;
		attribute startDrill : Boolean;
		attribute retract : Boolean;
	}
	item def Status {
		attribute temperature : Temperature;
		attribute powerConsumption : Power;
		attribute drillDepth : Length;
		attribute sampleMass : Mass;
		attribute errorCode : Integer;
	}
	item def RegolithSample {
		attribute mass : Mass;
		attribute isPristine : Boolean = true;
	}
	item def MechanicalPosition {
		attribute depth : Length;
	}
	item def ThermalReading {
		attribute temperature : Temperature;
	}

	port def PowerPort {
		out item power : ElectricalPower;
	}
	port def CommandPort {
		out item command : Command;
	}
	port def StatusPort {
		out item status : Status;
	}
	port def SamplePort {
		out item sample : RegolithSample;
	}
	port def MechanicalPort {
		out item position : MechanicalPosition;
	}
	port def ThermalPort {
		out item reading : ThermalReading;
	}

	requirement def OperationalTempRange {
		attribute temp : Temperature;
		attribute minTemp : Temperature = -150;
		attribute maxTemp : Temperature = 70;
		constraint { temp >= minTemp and temp <= maxTemp }
	}
	requirement def PowerLimit {
		attribute power : Power;
		attribute maxPower : Power = 150;
		constraint { power <= maxPower }
	}
	requirement def DrillDepthRange {
		attribute depth : Length;
		attribute minDepth : Length = 0.05;
		attribute maxDepth : Length = 1.0;
		constraint { depth >= minDepth and depth <= maxDepth }
	}
	requirement def SampleMassRequirement {
		attribute mass : Mass;
		attribute minMass : Mass = 30;
		constraint { mass >= minMass }
	}
	requirement def SamplePristineRequirement {
		attribute sample : RegolithSample;
		constraint { sample.isPristine == true }
	}

	action def DeployDrill {
		in command : Command;
		out deployed : Boolean;
	}
	action def PositionBit {
		in targetDepth : Length;
		out positioned : Boolean;
	}
	action def DrillToDepth {
		in targetDepth : Length;
		out sample : RegolithSample;
		out currentDepth : Length;
	}
	action def RetractAssembly {
		out retracted : Boolean;
	}
	action def TransferSample {
		in sample : RegolithSample;
		out transferred : Boolean;
	}

	part def ControllerUnit {
		port powerIn : ~PowerPort;
		port commandOut : CommandPort;
		port statusIn : ~StatusPort;
		port thermalIn : ~ThermalPort;
		attribute currentTemp : Temperature;
	}

	part def PowerDistributionUnit {
		port mainPowerIn : ~PowerPort;
		port powerOutController : PowerPort;
		port powerOutMotor : PowerPort;
		port powerOutActuator : PowerPort;
		port powerOutHeater : PowerPort;
		attribute totalPowerConsumption : Power;
	}

	part def LinearActuator {
		port powerIn : ~PowerPort;
		port commandIn : ~CommandPort;
		port mechanicalOut : MechanicalPort;
		port statusOut : StatusPort;
		attribute currentDepth : Length;

		perform action deploy : DeployDrill {
			in command = commandIn.command;
		}
		perform action retract : RetractAssembly;
	}

	part def DrillMotorAssembly {
		port powerIn : ~PowerPort;
		port commandIn : ~CommandPort;
		port statusOut : StatusPort;
		attribute torque : Real;
		attribute speed : Real;

		perform action drill : DrillToDepth {
			in targetDepth = commandIn.command.targetDepth;
		}
	}

	part def DrillBitAssembly {
		port mechanicalIn : ~MechanicalPort;
		port sampleOut : SamplePort;
		attribute collectedMass : Mass;
	}

	part def SampleContainer {
		attribute isSealed : Boolean = false;
		item storedSample : RegolithSample[0..1];
	}

	part def SampleCacheSystem {
		port sampleIn : ~SamplePort;
		port statusOut : StatusPort;
		part containers : SampleContainer[1..*];

		perform action transfer : TransferSample {
			in sample = sampleIn.sample;
		}
	}

	part def ThermalManagementSystem {
		port powerIn : ~PowerPort;
		port thermalOut : ThermalPort;
		attribute heaterEnabled : Boolean = false;
		attribute targetTemp : Temperature = 20;
	}

	state def DrillingStateMachine {
		state stowed;
		transition first stowed then deploying;
		state deploying;
		transition first deploying then positioning;
		state positioning;
		transition first positioning then drilling;
		state drilling;
		transition first drilling then retracting;
		state retracting;
		transition first retracting then transferring;
		state transferring;
		transition first transferring then complete;
		state complete;
	}

	part def DrillingSystem {
		part controller : ControllerUnit;
		part pdu : PowerDistributionUnit;
		part actuator : LinearActuator;
		part motor : DrillMotorAssembly;
		part bit : DrillBitAssembly;
		part cache : SampleCacheSystem;
		part thermal : ThermalManagementSystem;

		flow of power : ElectricalPower from pdu.powerOutController.power to controller.powerIn.power;
		flow of power : ElectricalPower from pdu.powerOutMotor.power to motor.powerIn.power;
		flow of power : ElectricalPower from pdu.powerOutActuator.power to actuator.powerIn.power;
		flow of power : ElectricalPower from pdu.powerOutHeater.power to thermal.powerIn.power;

		flow of command : Command from controller.commandOut.command to motor.commandIn.command;
		flow of command : Command from controller.commandOut.command to actuator.commandIn.command;

		flow of status : Status from actuator.statusOut.status to controller.statusIn.status;
		flow of status : Status from motor.statusOut.status to controller.statusIn.status;
		flow of status : Status from cache.statusOut.status to controller.statusIn.status;

		flow of reading : ThermalReading from thermal.thermalOut.reading to controller.thermalIn.reading;

		flow of position : MechanicalPosition from actuator.mechanicalOut.position to bit.mechanicalIn.position;

		flow of sample : RegolithSample from bit.sampleOut.sample to cache.sampleIn.sample;

		exhibit drillingStates : DrillingStateMachine;
	}

	part system : DrillingSystem;

	part satisfactionContext {
		ref :>> system;
		satisfy requirement opTemp : OperationalTempRange by system.thermal;
		satisfy requirement pwrLimit : PowerLimit by system.pdu;
		satisfy requirement depthRange : DrillDepthRange by system.actuator;
		satisfy requirement sampleMass : SampleMassRequirement by system.bit;
		satisfy requirement samplePristine : SamplePristineRequirement by system.cache;
	}
}
