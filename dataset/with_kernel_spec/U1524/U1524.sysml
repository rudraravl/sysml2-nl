package 'Automated Liquid Cooling System' {
	private import ScalarValues::*;

	package Definitions {
		item def Coolant;
		item def Heat;
		item def Air;

		attribute def Temperature :> Real;
		attribute def FlowRate :> Real;
		attribute def Speed :> Real;
		attribute def Level :> Real;

		port def CoolantPort {
			out item coolant : Coolant;
		}

		port def HeatPort {
			out item heat : Heat;
		}

		port def AirPort {
			out item air : Air;
		}

		port def SensorDataPort {
			out attribute reading : Real;
		}

		port def ControlSignalPort {
			out attribute speedCommand : Speed;
		}

		part def HeatSource {
			port heatOut : HeatPort;
			attribute currentTemp : Temperature;
			attribute maxSafeTemp : Temperature = 90.0;
		}

		part def WaterBlock {
			port heatIn : ~HeatPort;
			port coolantIn : ~CoolantPort;
			port coolantOut : CoolantPort;
		}

		part def Pump {
			port coolantIn : ~CoolantPort;
			port coolantOut : CoolantPort;
			port controlIn : ~ControlSignalPort;
			attribute currentSpeed : Speed;
		}

		part def Radiator {
			port coolantIn : ~CoolantPort;
			port coolantOut : CoolantPort;
			port heatOut : HeatPort;
			port airIn : ~AirPort;
		}

		part def Fan {
			port controlIn : ~ControlSignalPort;
			port airOut : AirPort;
			attribute currentSpeed : Speed;
		}

		part def Reservoir {
			port coolantIn : ~CoolantPort;
			port coolantOut : CoolantPort;
			attribute coolantLevel : Level;
			attribute minLevel : Level = 10.0;
			attribute maxCapacity : Level = 100.0;
		}

		part def TemperatureSensor {
			port heatIn : ~HeatPort;
			port dataOut : SensorDataPort;
			attribute reading : Temperature;
		}

		part def FlowSensor {
			port coolantIn : ~CoolantPort;
			port coolantOut : CoolantPort;
			port dataOut : SensorDataPort;
			attribute reading : FlowRate;
		}

		part def LevelSensor {
			port dataOut : SensorDataPort;
			attribute reading : Level;
		}

		part def Controller {
			port tempDataIn : ~SensorDataPort;
			port flowDataIn : ~SensorDataPort;
			port levelDataIn : ~SensorDataPort;
			port pumpControlOut : ControlSignalPort;
			port fanControlOut : ControlSignalPort;
			attribute targetTemp : Temperature = 50.0;
			attribute maxSafeTemp : Temperature = 90.0;
			attribute lowLevelThreshold : Level = 10.0;
		}

		part def AmbientEnvironment {
			port heatIn : ~HeatPort;
		}

		attribute def StartSignal;
		attribute def StopSignal;
		attribute def ResetSignal;
		attribute def FaultSignal;

		action def SetStandbySpeeds {
			out pumpSpeedCommand : Speed;
			out fanSpeedCommand : Speed;
		}

		action def MonitorSensors {
			in tempReading : Temperature;
			in flowReading : FlowRate;
			in levelReading : Level;
			in targetTemp : Temperature;
			out pumpSpeedCommand : Speed;
			out fanSpeedCommand : Speed;
		}

		action def EmergencyShutdownAction {
			out pumpSpeedCommand : Speed;
			out fanSpeedCommand : Speed;
		}

		state def CoolingSystemStates {
			in controller : Controller;
			in reservoir : Reservoir;
			in heatSource : HeatSource;
			in tempSensor : TemperatureSensor;
			in flowSensor : FlowSensor;
			in levelSensor : LevelSensor;
			in pump : Pump;
			in fan : Fan;

			entry; then standby;

			state standby;
			accept StartSignal then activeCooling;

			state activeCooling;
			accept StopSignal then standby;
			accept FaultSignal then fault;

			state fault;
			accept ResetSignal then standby;
		}

		requirement def MaintainOperatingTemperature {
			doc /* The system shall maintain the heat source temperature at or below the target temperature during active cooling. */
		}

		requirement def FaultDetection {
			doc /* The system shall enter a fault state if the coolant level drops below the minimum threshold or the temperature exceeds the safe limit. */
		}

		requirement def ClosedLoopCooling {
			doc /* The cooling loop shall operate as a closed circuit transferring thermal energy from the heat source to the ambient air. */
		}
	}

	package Usages {
		private import Definitions::*;

		part coolingSystem {
			part heatSource : HeatSource;
			part waterBlock : WaterBlock;
			part pump : Pump;
			part radiator : Radiator;
			part fan : Fan;
			part reservoir : Reservoir;
			part tempSensor : TemperatureSensor;
			part flowSensor : FlowSensor;
			part levelSensor : LevelSensor;
			part controller : Controller;
			part ambient : AmbientEnvironment;

			flow of heat : Heat
				from heatSource.heatOut.heat to waterBlock.heatIn.heat;

			flow of heat : Heat
				from heatSource.heatOut.heat to tempSensor.heatIn.heat;

			flow of coolant : Coolant
				from reservoir.coolantOut.coolant to pump.coolantIn.coolant;

			flow of coolant : Coolant
				from pump.coolantOut.coolant to waterBlock.coolantIn.coolant;

			flow of coolant : Coolant
				from waterBlock.coolantOut.coolant to flowSensor.coolantIn.coolant;

			flow of coolant : Coolant
				from flowSensor.coolantOut.coolant to radiator.coolantIn.coolant;

			flow of coolant : Coolant
				from radiator.coolantOut.coolant to reservoir.coolantIn.coolant;

			flow of air : Air
				from fan.airOut.air to radiator.airIn.air;

			flow of heat : Heat
				from radiator.heatOut.heat to ambient.heatIn.heat;

			connect controller.tempDataIn to tempSensor.dataOut;
			connect controller.flowDataIn to flowSensor.dataOut;
			connect controller.levelDataIn to levelSensor.dataOut;
			connect controller.pumpControlOut to pump.controlIn;
			connect controller.fanControlOut to fan.controlIn;

			bind tempSensor.reading = heatSource.currentTemp;
			bind levelSensor.reading = reservoir.coolantLevel;

			exhibit systemStates : CoolingSystemStates {
				in controller = controller;
				in reservoir = reservoir;
				in heatSource = heatSource;
				in tempSensor = tempSensor;
				in flowSensor = flowSensor;
				in levelSensor = levelSensor;
				in pump = pump;
				in fan = fan;
			}

			satisfy MaintainOperatingTemperature;
			satisfy FaultDetection;
			satisfy ClosedLoopCooling;
		}
	}
}
