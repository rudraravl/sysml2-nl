package PhotoswitchSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def IlluminanceLevel {
		attribute value : Real;
	}
	
	enum def SwitchPosition {
		open;
		closed;
	}
	
	item def LightMeasurement {
		attribute illuminance : ISQ::IlluminanceValue;
		attribute timestamp : ISQ::TimeValue;
	}
	
	item def SwitchCommand {
		attribute position : SwitchPosition;
		attribute requestTime : ISQ::TimeValue;
	}
	
	port def SensorPort {
		out lightReading : LightMeasurement;
	}
	
	port def ControlPort {
		in lightData : LightMeasurement;
		out switchControl : SwitchCommand;
	}
	
	port def ActuatorPort {
		in controlSignal : SwitchCommand;
	}
	
	port def PowerPort {
		attribute voltage : ISQ::PotentialValue;
		attribute current : ISQ::ElectricCurrentValue;
	}
	
	part def PhotosensitiveElement {
		doc /* Detects ambient light levels and converts them to electrical signals. */
		
		port sensorOutput : SensorPort;
		attribute sensitivity : ISQ::IlluminanceValue = 10.0[lx];
		attribute responseTime : ISQ::TimeValue = 0.05[s];
		
		action measureAmbientLight {
			out measurement : LightMeasurement;
		}
	}
	
	part def ControlUnit {
		doc /* Processes light measurements and determines switch state based on threshold logic. */
		
		port sensorInput : ~ControlPort;
		port actuatorOutput : ControlPort;
		
		attribute activationThreshold : ISQ::IlluminanceValue = 50.0[lx];
		attribute deactivationThreshold : ISQ::IlluminanceValue = 100.0[lx];
		attribute hysteresisMargin : ISQ::IlluminanceValue = 10.0[lx];
		
		private attribute currentIlluminance : ISQ::IlluminanceValue;
		private attribute switchState : SwitchPosition = SwitchPosition::open;
		
		action processLightData;
	}
	
	state def RelayBehavior {
		entry; then relayOpen;
		
		state relayOpen {
			doc /* Relay contacts are open, load is de-energized. */
			entry assign loadPowerState = false;
		}
		
		state relayClosed {
			doc /* Relay contacts are closed, load is energized. */
			entry assign loadPowerState = true;
		}
		
		transition openToClosed
			first relayOpen
			accept closeCommand : SwitchCommand
			if closeCommand.position == SwitchPosition::closed
			then relayClosed;
		
		transition closedToOpen
			first relayClosed
			accept openCommand : SwitchCommand
			if openCommand.position == SwitchPosition::open
			then relayOpen;
		
		attribute loadPowerState : Boolean = false;
	}
	
	part def SwitchRelay {
		doc /* Electromechanical relay that opens or closes electrical circuit based on control signals. */
		
		port controlInput : ActuatorPort;
		port loadPower : PowerPort;
		
		attribute nominalVoltage : ISQ::PotentialValue = 120.0[V];
		attribute maxCurrent : ISQ::ElectricCurrentValue = 10.0[A];
		attribute switchingTime : ISQ::TimeValue = 0.01[s];
		
		private attribute relayPosition : SwitchPosition = SwitchPosition::open;
		
		exhibit state relayStateMachine : RelayBehavior;
	}
	
	part def LoadCircuit {
		doc /* Electrical load controlled by the photoswitch, such as lighting or equipment. */
		
		port powerInput : ~PowerPort;
		
		attribute ratedPower : ISQ::PowerValue = 500.0[W];
		attribute ratedVoltage : ISQ::PotentialValue = 120.0[V];
		attribute powerFactor : Real = 0.95;
	}
	
	part def Photoswitch {
		doc /* Automatic light-activated switch that controls electrical loads based on ambient illumination. */
		
		part sensor : PhotosensitiveElement;
		part controller : ControlUnit;
		part relay : SwitchRelay;
		part load : LoadCircuit;
		
		connect sensor.sensorOutput to controller.sensorInput;
		connect controller.actuatorOutput to relay.controlInput;
		connect relay.loadPower to load.powerInput;
	}
	
	action def MeasureLight {
		in sensorSensitivity : ISQ::IlluminanceValue;
		out lightLevel : ISQ::IlluminanceValue;
		out measurement : LightMeasurement;
	}
	
	action def EvaluateThreshold {
		in currentLight : ISQ::IlluminanceValue;
		in activationLevel : ISQ::IlluminanceValue;
		in deactivationLevel : ISQ::IlluminanceValue;
		in currentState : SwitchPosition;
		out newState : SwitchPosition;
		out command : SwitchCommand;
	}
	
	action def ActuateRelay {
		in command : SwitchCommand;
		out relayPosition : SwitchPosition;
	}
	
	action def ControlLogic {
		first start;
		then merge continuousMonitoring;
		
		then action measure : MeasureLight {
			in sensorSensitivity;
			out lightLevel;
			out measurement;
		}
		
		then action evaluate : EvaluateThreshold {
			in currentLight = measure.lightLevel;
			in activationLevel;
			in deactivationLevel;
			in currentState;
			out newState;
			out command;
		}
		
		then decide;
			if evaluate.newState != evaluate.currentState then sendCommand;
			else continuousMonitoring;
		
		action sendCommand : ActuateRelay {
			in command = evaluate.command;
			out relayPosition;
		}
		
		then continuousMonitoring;
	}
	
	action def PhotoswitchOperation {
		doc /* Primary operational sequence of the photoswitch system. */
		
		first start;
		then merge monitoringCycle;
		
		then action sensorReading {
			doc /* Sensor continuously measures ambient light. */
		}
		
		then action controlDecision {
			doc /* Controller evaluates light level against thresholds. */
		}
		
		then decide;
			if true then closeSwitch;
			else openSwitch;
		
		action closeSwitch {
			doc /* Activate relay to energize load. */
		}
		
		action openSwitch {
			doc /* Deactivate relay to de-energize load. */
		}
		
		then monitoringCycle;
	}
	
	part photoswitchSystem : Photoswitch {
		part :>> sensor {
			attribute :>> sensitivity = 5.0[lx];
			attribute :>> responseTime = 0.1[s];
		}
		
		part :>> controller {
			attribute :>> activationThreshold = 30.0[lx];
			attribute :>> deactivationThreshold = 80.0[lx];
			attribute :>> hysteresisMargin = 15.0[lx];
		}
		
		part :>> relay {
			attribute :>> nominalVoltage = 120.0[V];
			attribute :>> maxCurrent = 15.0[A];
		}
		
		part :>> load {
			attribute :>> ratedPower = 1000.0[W];
			attribute :>> ratedVoltage = 120.0[V];
		}
		
		perform action operation : PhotoswitchOperation;
	}
	
	requirement def <'REQ-001'> PrimaryFunctionRequirement {
		doc /* The photoswitch shall automatically control electrical loads based on ambient light conditions. */
		
		subject photoswitchDevice : Photoswitch;
		
		require constraint automaticActivation {
			doc /* The system shall close the relay when ambient illuminance falls below the activation threshold. */
		}
		
		require constraint automaticDeactivation {
			doc /* The system shall open the relay when ambient illuminance rises above the deactivation threshold. */
		}
	}
	
	requirement def <'REQ-002'> ThresholdConfigurationRequirement {
		doc /* The photoswitch shall provide configurable activation and deactivation thresholds with hysteresis. */
		
		subject controlUnit : ControlUnit;
		
		require constraint thresholdRange {
			doc /* Activation threshold shall be adjustable from 5 lx to 200 lx. */
		}
		
		require constraint hysteresisPresent {
			doc /* Deactivation threshold shall exceed activation threshold by at least 10 lx to prevent oscillation. */
			controlUnit.deactivationThreshold >= controlUnit.activationThreshold + 10.0[lx]
		}
	}
	
	requirement def <'REQ-003'> ResponseTimeRequirement {
		doc /* The photoswitch shall respond to light level changes within specified time limits. */
		
		subject photoswitchDevice : Photoswitch;
		
		require constraint sensorResponse {
			doc /* Sensor shall detect light changes within 100 milliseconds. */
			photoswitchDevice.sensor.responseTime <= 0.1[s]
		}
		
		require constraint relaySwitching {
			doc /* Relay shall complete switching action within 50 milliseconds of command. */
			photoswitchDevice.relay.switchingTime <= 0.05[s]
		}
	}
	
	requirement def <'REQ-004'> ElectricalSpecificationRequirement {
		doc /* The photoswitch shall meet specified electrical ratings and safety standards. */
		
		subject relayComponent : SwitchRelay;
		
		require constraint voltageRating {
			doc /* Relay shall be rated for 120V AC nominal operation. */
			relayComponent.nominalVoltage == 120.0[V]
		}
		
		require constraint currentCapacity {
			doc /* Relay shall handle continuous current up to 10A without degradation. */
			relayComponent.maxCurrent >= 10.0[A]
		}
	}
	
	requirement <'REQ-SYS-001'> systemPrimaryFunction : PrimaryFunctionRequirement {
		subject photoswitchDevice = photoswitchSystem;
		
		assume constraint ambientLightPresent {
			doc /* Ambient light source varies naturally or artificially in the operating environment. */
		}
		
		assume constraint powerSupplyAvailable {
			doc /* Stable electrical power supply is available at rated voltage. */
		}
	}
	
	requirement <'REQ-SYS-002'> systemThresholdConfiguration : ThresholdConfigurationRequirement {
		subject controlUnit = photoswitchSystem.controller;
	}
	
	requirement <'REQ-SYS-003'> systemResponseTime : ResponseTimeRequirement {
		subject photoswitchDevice = photoswitchSystem;
	}
	
	requirement <'REQ-SYS-004'> systemElectricalSpec : ElectricalSpecificationRequirement {
		subject relayComponent = photoswitchSystem.relay;
	}
	
	occurrence def PhotoswitchOperationScenario {
		doc /* Typical operational scenario demonstrating photoswitch primary function during day-night transition. */
		
		ref part system : Photoswitch = photoswitchSystem;
		
		event occurrence daylight {
			doc /* Initial condition: bright ambient light, relay open, load de-energized. */
		}
		
		then event occurrence duskBegins {
			doc /* Ambient illuminance begins decreasing as daylight fades. */
		}
		
		then message lightMeasurement1 of LightMeasurement
			from system.sensor.sensorOutput
			to system.controller.sensorInput {
			doc /* Sensor reports decreasing light level to controller. */
		}
		
		then event occurrence thresholdCrossed {
			doc /* Illuminance falls below activation threshold. */
		}
		
		then message activationCommand of SwitchCommand
			from system.controller.actuatorOutput
			to system.relay.controlInput {
			doc /* Controller commands relay to close. */
			require constraint { self.position == SwitchPosition::closed }
		}
		
		then event occurrence relayCloses {
			doc /* Relay contacts close, energizing the load. */
		}
		
		then event occurrence loadEnergized {
			doc /* Electrical load operates, providing illumination or other function. */
		}
		
		then event occurrence nightOperation {
			doc /* System maintains load energized throughout low-light period. */
		}
		
		then event occurrence dawnBegins {
			doc /* Ambient illuminance begins increasing as daylight returns. */
		}
		
		then message lightMeasurement2 of LightMeasurement
			from system.sensor.sensorOutput
			to system.controller.sensorInput {
			doc /* Sensor reports increasing light level to controller. */
		}
		
		then event occurrence deactivationThresholdCrossed {
			doc /* Illuminance rises above deactivation threshold. */
		}
		
		then message deactivationCommand of SwitchCommand
			from system.controller.actuatorOutput
			to system.relay.controlInput {
			doc /* Controller commands relay to open. */
			require constraint { self.position == SwitchPosition::open }
		}
		
		then event occurrence relayOpens {
			doc /* Relay contacts open, de-energizing the load. */
		}
		
		then event occurrence loadDeenergized {
			doc /* Electrical load ceases operation, conserving energy during daylight. */
		}
	}
}
