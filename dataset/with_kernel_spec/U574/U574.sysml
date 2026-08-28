package 'Fluid Pumping Subsystem' {
	attribute def RotationalSpeed;
	attribute def Pressure;
	attribute def VolumeFlowRate;
	attribute def Temperature;
	
	item def Fluid;
	item def ElectricalPower;
	item def ControlCommand {
		attribute targetSpeed : RotationalSpeed;
	}
	item def TelemetryData {
		attribute currentSpeed : RotationalSpeed;
		attribute dischargePressure : Pressure;
		attribute flowRate : VolumeFlowRate;
		attribute motorTemperature : Temperature;
	}
	
	port def FluidPort {
		in item fluidIn : Fluid;
		out item fluidOut : Fluid;
	}
	port def PowerPort {
		in item powerIn : ElectricalPower;
		out item powerOut : ElectricalPower;
	}
	port def CommandPort {
		in item commandIn : ControlCommand;
		out item commandOut : ControlCommand;
	}
	port def TelemetryPort {
		in item telemetryIn : TelemetryData;
		out item telemetryOut : TelemetryData;
	}
	
	part def ElectricMotor {
		attribute temperature : Temperature;
	}
	part def TitaniumAlloyShaft;
	part def SixBladedImpeller {
		attribute nominalSpeed : RotationalSpeed;
	}
	part def CeramicBallBearing;
	part def OilMistSystem;
	part def MechanicalFaceSeal;
	part def StainlessSteelHousing;
	
	part def Turbopump {
		port fluidInPort : FluidPort;
		port fluidOutPort : FluidPort;
		port powerInPort : PowerPort;
		port commandInPort : CommandPort;
		port telemetryOutPort : TelemetryPort;
		
		part motor : ElectricMotor;
		part shaft : TitaniumAlloyShaft;
		part impeller : SixBladedImpeller;
		part bearing1 : CeramicBallBearing;
		part bearing2 : CeramicBallBearing;
		part lubrication : OilMistSystem;
		part seal : MechanicalFaceSeal;
		part housing : StainlessSteelHousing;
	}
	
	part def FluidSupplyTank {
		port fluidOutPort : FluidPort;
	}
	part def ReceiverTank {
		port fluidInPort : FluidPort;
	}
	part def PowerSupply {
		port powerOutPort : PowerPort;
	}
	part def Controller {
		port commandOutPort : CommandPort;
		port telemetryInPort : TelemetryPort;
	}
	
	action def StartMotor {
		in power : ElectricalPower;
	}
	action def AccelerateImpeller {
		in power : ElectricalPower;
		out speed : RotationalSpeed;
	}
	action def EstablishSteadyFlow {
		in speed : RotationalSpeed;
		out pressure : Pressure;
		out flowRate : VolumeFlowRate;
	}
	action def MonitorAndAdjust {
		in command : ControlCommand;
		in telemetry : TelemetryData;
		out adjustedCommand : ControlCommand;
	}
	
	action def PumpOperation {
		in power : ElectricalPower;
		in command : ControlCommand;
		out telemetry : TelemetryData;
		
		action startMotor : StartMotor {
			in power = PumpOperation::power;
		}
		then action accelerateImpeller : AccelerateImpeller {
			in power = PumpOperation::power;
			out speed : RotationalSpeed;
		}
		then action establishSteadyFlow : EstablishSteadyFlow {
			in speed = accelerateImpeller.speed;
			out pressure : Pressure;
			out flowRate : VolumeFlowRate;
		}
		then action monitorAndAdjust : MonitorAndAdjust {
			in command = PumpOperation::command;
			in telemetry : TelemetryData;
			out adjustedCommand : ControlCommand;
		}
	}
	
	requirement def PumpPerformanceRequirement {
		doc /* The turbopump must achieve a nominal impeller speed of 3600 RPM for high-performance fluid pumping. The stainless steel housing must safely contain pressures well beyond the normal operating range. A mechanical face seal must prevent fluid leakage along the drive shaft. The oil mist system must lubricate the ceramic ball bearings to handle high loads and speeds. */
		subject pump : Turbopump;
	}
	
	part def PumpingSubsystem {
		part supplyTank : FluidSupplyTank;
		part receiverTank : ReceiverTank;
		part powerSupply : PowerSupply;
		part controller : Controller;
		part turbopump : Turbopump;
		
		flow fluidSupplyFlow of Fluid 
			from supplyTank.fluidOutPort.fluidOut to turbopump.fluidInPort.fluidIn;
		flow fluidDeliveryFlow of Fluid 
			from turbopump.fluidOutPort.fluidOut to receiverTank.fluidInPort.fluidIn;
		flow powerFlow of ElectricalPower 
			from powerSupply.powerOutPort.powerOut to turbopump.powerInPort.powerIn;
		flow commandFlow of ControlCommand 
			from controller.commandOutPort.commandOut to turbopump.commandInPort.commandIn;
		flow telemetryFlow of TelemetryData 
			from turbopump.telemetryOutPort.telemetryOut to controller.telemetryInPort.telemetryIn;
	}
	
	part pumpingSubsystem : PumpingSubsystem;
	
	requirement pumpPerformance : PumpPerformanceRequirement {
		subject :>> pump = pumpingSubsystem.turbopump;
	}
}
