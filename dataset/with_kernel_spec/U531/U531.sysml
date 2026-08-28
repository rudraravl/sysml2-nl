package 'Knudsen Pump Subsystem' {
	private import ISQ::*;
	private import ScalarValues::*;

	item def Gas;
	item def ElectricalPower;

	attribute def StartCommand;
	attribute def StopCommand;
	attribute def ResetCommand;
	attribute def FaultDetected;
	attribute def TargetTempReached;
	attribute def CooldownComplete;

	port def GasPort {
		item flow gas : Gas;
	}
	port def PowerPort {
		item flow power : ElectricalPower;
	}
	port def TempSignalPort {
		out temp : TemperatureValue;
	}
	port def PressureSignalPort {
		out pressure : PressureValue;
	}
	port def FlowSignalPort {
		out flowRate : VolumeFlowRateValue;
	}
	port def ControlSignalPort {
		in cmd : String;
	}

	part def Reservoir {
		port gasPort : GasPort;
		attribute pressure : PressureValue;
		attribute volume : VolumeValue;
	}

	part def MicroChannelArray {
		port gasIn : GasPort;
		port gasOut : GasPort;
		port hotSide : TempSignalPort;
		port coldSide : TempSignalPort;
		attribute channelCount : Integer;
		attribute channelDiameter : LengthValue;
		attribute channelLength : LengthValue;
	}

	part def HeatingElement {
		port powerIn : PowerPort;
		port controlIn : ControlSignalPort;
		attribute powerRating : PowerValue;
	}

	part def CoolingElement {
		port controlIn : ControlSignalPort;
		attribute coolingCapacity : PowerValue;
	}

	part def PowerSupply {
		port powerOut : PowerPort;
		attribute outputPower : PowerValue;
		attribute outputVoltage : ElectricPotentialDifferenceValue;
	}

	part def PressureSensor {
		port gasSense : GasPort;
		port signalOut : PressureSignalPort;
		attribute reading : PressureValue;
	}

	part def TemperatureSensor {
		port tempSense : TempSignalPort;
		port signalOut : TempSignalPort;
		attribute reading : TemperatureValue;
	}

	part def FlowMeter {
		port gasSense : GasPort;
		port signalOut : FlowSignalPort;
		attribute reading : VolumeFlowRateValue;
	}

	action def ActivateHeater;
	action def DeactivateHeater;
	action def DissipateHeat;
	action def MonitorAndRegulate {
		in inletPressure : PressureValue;
		in outletPressure : PressureValue;
		in hotTemp : TemperatureValue;
		in coldTemp : TemperatureValue;
		in flowRate : VolumeFlowRateValue;
	}
	action def PumpGas;
	action def TriggerAlarm;

	part def PumpingUnit {
		port gasIn : GasPort;
		port gasOut : GasPort;
		port powerIn : PowerPort;
		port heaterCmd : ControlSignalPort;
		port coolerCmd : ControlSignalPort;
		port hotTemp : TempSignalPort;
		port coldTemp : TempSignalPort;

		part channels : MicroChannelArray;
		part heater : HeatingElement;
		part cooler : CoolingElement;

		connect channels.gasIn to gasIn;
		connect channels.gasOut to gasOut;
		connect channels.hotSide to hotTemp;
		connect channels.coldSide to coldTemp;
		connect heater.powerIn to powerIn;
		connect heater.controlIn to heaterCmd;
		connect cooler.controlIn to coolerCmd;
	}

	state def PumpControlStates {
		entry; then off;

		state off;
		transition off_to_warmup
			first off
			accept StartCommand
			then warmup;

		state warmup {
			entry action activateHeater : ActivateHeater;
		}
		transition warmup_to_operating
			first warmup
			accept TargetTempReached
			then operating;

		state operating {
			entry action monitorAndRegulate : MonitorAndRegulate;
			do action pumpGas : PumpGas;
		}
		transition operating_to_cooldown
			first operating
			accept StopCommand
			then cooldown;

		state cooldown {
			entry action deactivateHeater : DeactivateHeater;
			do action dissipateHeat : DissipateHeat;
		}
		transition cooldown_to_off
			first cooldown
			accept CooldownComplete
			then off;

		state fault {
			entry action triggerAlarm : TriggerAlarm;
		}
		transition off_to_fault
			first off
			accept FaultDetected
			then fault;
		transition warmup_to_fault
			first warmup
			accept FaultDetected
			then fault;
		transition operating_to_fault
			first operating
			accept FaultDetected
			then fault;
		transition cooldown_to_fault
			first cooldown
			accept FaultDetected
			then fault;
		transition fault_to_off
			first fault
			accept ResetCommand
			then off;
	}

	part def PumpController {
		port cmdIn : ControlSignalPort;
		port heaterCmd : ControlSignalPort;
		port coolerCmd : ControlSignalPort;
		port inletPressure : PressureSignalPort;
		port outletPressure : PressureSignalPort;
		port hotTemp : TempSignalPort;
		port coldTemp : TempSignalPort;
		port outletFlow : FlowSignalPort;

		exhibit state 'pump control states' : PumpControlStates;
	}

	requirement def 'Thermal Transpiration Principle' {
		doc /* The pump shall move gas using thermal transpiration without mechanical moving parts. */
	}
	requirement def 'Pressure Increase' {
		doc /* The pump shall deliver gas to the destination reservoir at a higher pressure than the source. */
		attribute minPressureRatio : Real = 1.5;
	}
	requirement def 'Temperature Gradient' {
		doc /* A temperature difference of at least 30 K shall be maintained across the microchannels. */
		attribute minDeltaT : TemperatureValue;
	}
	requirement def 'Low Pressure Operation' {
		doc /* Source pressure shall not exceed 100 Pa during normal operation. */
		attribute maxSourcePressure : PressureValue;
	}
	requirement def 'Sensor Coverage' {
		doc /* The system shall monitor inlet pressure, outlet pressure, hot side temperature, cold side temperature, and outlet flow rate. */
	}

	requirement 'Thermal Transpiration Req' : 'Thermal Transpiration Principle';
	requirement 'Pressure Increase Req' : 'Pressure Increase';
	requirement 'Temperature Gradient Req' : 'Temperature Gradient';
	requirement 'Low Pressure Operation Req' : 'Low Pressure Operation';
	requirement 'Sensor Coverage Req' : 'Sensor Coverage';

	part 'Knudsen Pump System' {
		part sourceReservoir : Reservoir;
		part destinationReservoir : Reservoir;
		part pumpingUnit : PumpingUnit;
		part powerSupply : PowerSupply;
		part inletPressureSensor : PressureSensor;
		part outletPressureSensor : PressureSensor;
		part hotSideTempSensor : TemperatureSensor;
		part coldSideTempSensor : TemperatureSensor;
		part outletFlowMeter : FlowMeter;
		part controller : PumpController;

		connect sourceReservoir.gasPort to pumpingUnit.gasIn;
		connect pumpingUnit.gasOut to destinationReservoir.gasPort;
		connect powerSupply.powerOut to pumpingUnit.powerIn;

		connect inletPressureSensor.gasSense to pumpingUnit.gasIn;
		connect outletPressureSensor.gasSense to pumpingUnit.gasOut;
		connect outletFlowMeter.gasSense to pumpingUnit.gasOut;
		connect hotSideTempSensor.tempSense to pumpingUnit.hotTemp;
		connect coldSideTempSensor.tempSense to pumpingUnit.coldTemp;

		connect inletPressureSensor.signalOut to controller.inletPressure;
		connect outletPressureSensor.signalOut to controller.outletPressure;
		connect hotSideTempSensor.signalOut to controller.hotTemp;
		connect coldSideTempSensor.signalOut to controller.coldTemp;
		connect outletFlowMeter.signalOut to controller.outletFlow;
		connect controller.heaterCmd to pumpingUnit.heaterCmd;
		connect controller.coolerCmd to pumpingUnit.coolerCmd;

		satisfy 'Thermal Transpiration Req' by self;
		satisfy 'Pressure Increase Req' by self;
		satisfy 'Temperature Gradient Req' by self;
		satisfy 'Low Pressure Operation Req' by self;
		satisfy 'Sensor Coverage Req' by self;
	}
}
