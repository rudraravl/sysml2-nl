package AvionicsSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def NavigationData {
		attribute latitude : Real;
		attribute longitude : Real;
		attribute altitude : LengthValue;
		attribute heading : Real;
		attribute groundSpeed : SpeedValue;
		attribute verticalSpeed : SpeedValue;
	}
	
	attribute def SensorData {
		attribute accelerationX : AccelerationValue;
		attribute accelerationY : AccelerationValue;
		attribute accelerationZ : AccelerationValue;
		attribute pitchRate : Real;
		attribute rollRate : Real;
		attribute yawRate : Real;
		attribute staticPressure : PressureValue;
		attribute dynamicPressure : PressureValue;
		attribute temperature : TemperatureValue;
	}
	
	attribute def FlightControlCommands {
		attribute elevatorDeflection : Real;
		attribute aileronDeflection : Real;
		attribute rudderDeflection : Real;
		attribute throttleSetting : Real;
	}
	
	attribute def DisplayData {
		attribute airspeed : SpeedValue;
		attribute altitude : LengthValue;
		attribute heading : Real;
		attribute verticalSpeed : SpeedValue;
		attribute attitudePitch : Real;
		attribute attitudeRoll : Real;
	}
	
	item def SensorReading;
	item def NavigationUpdate;
	item def ControlCommand;
	item def DisplayUpdate;
	item def RadioMessage;
	item def PowerOnSignal;
	item def PowerOffSignal;
	item def SystemFailureSignal;
	item def SystemRecoverySignal;
	
	port def SensorPort {
		out item sensorOutput : SensorReading;
	}
	
	port def NavigationPort {
		in item sensorInput : SensorReading;
		out item navOutput : NavigationUpdate;
	}
	
	port def ControlPort {
		in item navInput : NavigationUpdate;
		in item pilotInput : ControlCommand;
		out item controlOutput : ControlCommand;
	}
	
	port def DisplayPort {
		in item navInput : NavigationUpdate;
		out item displayOutput : DisplayUpdate;
	}
	
	port def CommunicationPort {
		in item messageIn : RadioMessage;
		out item messageOut : RadioMessage;
	}
	
	part def InertialNavigationSystem {
		port sensorIn : SensorPort;
		port navOut : NavigationPort;
		
		attribute currentPosition : NavigationData;
		attribute calibrationStatus : Boolean;
		
		perform action computeNavigation {
			in sensorData : SensorData;
			out navigationData : NavigationData;
		}
	}
	
	part def AirDataComputer {
		port sensorIn : SensorPort;
		
		attribute indicatedAirspeed : SpeedValue;
		attribute trueAirspeed : SpeedValue;
		attribute pressureAltitude : LengthValue;
		
		perform action processAirData {
			in rawSensorData : SensorData;
			out processedData : SensorData;
		}
	}
	
	part def FlightManagementSystem {
		port navIn : NavigationPort;
		port controlOut : ControlPort;
		
		attribute flightPlan : String[*] ordered;
		attribute currentWaypointIndex : Integer;
		attribute autopilotEngaged : Boolean;
		
		perform action manageFlightPath {
			in currentNav : NavigationData;
			out guidanceCommands : FlightControlCommands;
		}
	}
	
	part def FlightControlComputer {
		port navIn : NavigationPort;
		port fmsIn : ControlPort;
		port controlOut : ControlPort;
		
		attribute controlMode : String;
		attribute stabilityAugmentation : Boolean;
		
		perform action computeControlCommands {
			in navigationData : NavigationData;
			in pilotCommands : FlightControlCommands;
			in autopilotCommands : FlightControlCommands;
			out finalCommands : FlightControlCommands;
		}
	}
	
	part def PrimaryFlightDisplay {
		port navIn : DisplayPort;
		
		attribute displayBrightness : Real;
		attribute displayMode : String;
		
		perform action updateDisplay {
			in navData : NavigationData;
			out displayData : DisplayData;
		}
	}
	
	part def CommunicationSystem {
		port commPort : CommunicationPort;
		
		attribute vhfFrequency : Real;
		attribute transponderCode : Integer;
		
		perform action transmitMessage {
			in message : RadioMessage;
		}
		
		perform action receiveMessage {
			out message : RadioMessage;
		}
	}
	
	action def InitializeAvionics {
		first start;
		then action powerUpSequence;
		then action performSelfTest;
		then action calibrateSensors;
		then action loadConfiguration;
		then done;
	}
	
	action def MonitorSystemHealth {
		in currentNav : NavigationData;
		in sensorData : SensorData;
		out systemHealthy : Boolean;
		out alerts : String[*];
	}
	
	action def ExecuteFlightControl {
		in healthStatus : Boolean;
		out healthResult : Boolean;
		
		first start;
		then merge controlLoop;
		
		then action acquireSensorData {
			out sensors : SensorData;
		}
		
		then action updateNavigation {
			in sensorInput : SensorData;
			out navData : NavigationData;
		}
		
		then action computeGuidance {
			in navigation : NavigationData;
			out guidance : FlightControlCommands;
		}
		
		then action applyControlLaws {
			in guidanceCmd : FlightControlCommands;
			in pilotCmd : FlightControlCommands;
			out finalCmd : FlightControlCommands;
		}
		
		then action refreshDisplays {
			in navData : NavigationData;
		}
		
		then decide;
			if healthStatus == true then controlLoop;
			if healthStatus == false then emergencyMode;
		
		action emergencyMode {
			then action activateBackupSystems;
			then action alertCrew;
		}
		
		then done;
	}
	
	state def AvionicsOperationalStates {
		entry; then off;
		
		state off;
		transition off_to_startup
			first off
			accept powerOnEvent : PowerOnSignal
			then startup;
		
		state startup {
			entry; then initializing;
			state initializing;
			transition init_to_test
				first initializing
				then selfTest;
			state selfTest;
			transition test_to_ready
				first selfTest
				then ready;
			state ready;
		}
		transition startup_to_operational
			first startup.ready
			then operational;
		
		state operational {
			entry; then normalOperation;
			
			state normalOperation {
				do action executeControl : ExecuteFlightControl;
			}
			
			state degradedOperation;
			
			transition normal_to_degraded
				first normalOperation
				accept failureEvent : SystemFailureSignal
				then degradedOperation;
			
			transition degraded_to_normal
				first degradedOperation
				accept recoveryEvent : SystemRecoverySignal
				then normalOperation;
		}
		
		transition operational_to_shutdown
			first operational
			accept powerOffEvent : PowerOffSignal
			then shutdown;
		
		state shutdown;
		transition shutdown_to_off
			first shutdown
			then off;
	}
	
	part def IntegratedAvionicsSuite {
		part ins : InertialNavigationSystem;
		part adc : AirDataComputer;
		part fms : FlightManagementSystem;
		part fcc : FlightControlComputer;
		part pfd : PrimaryFlightDisplay;
		part comms : CommunicationSystem;
	}
	
	connection def SensorDataFlow {
		end source : NavigationPort;
		end target : NavigationPort;
	}
	
	connection def ControlDataFlow {
		end source : ControlPort;
		end target : ControlPort;
	}
	
	connection def NavigationDataFlow {
		end source : NavigationPort;
		end target : ControlPort;
	}
	
	connection def DisplayDataFlow {
		end source : NavigationPort;
		end target : DisplayPort;
	}
	
	part integratedAvionics : IntegratedAvionicsSuite {
		
		connection insToFms : SensorDataFlow
			connect ins.navOut to fms.navIn;
		
		connection fmsToFcc : ControlDataFlow
			connect fms.controlOut to fcc.fmsIn;
		
		connection insToFcc : NavigationDataFlow
			connect ins.navOut to fcc.navIn;
		
		connection insToPfd : DisplayDataFlow
			connect ins.navOut to pfd.navIn;
		
		perform action initializeSystem : InitializeAvionics;
		
		perform action monitorSystem : MonitorSystemHealth[*] {
			in currentNav;
			in sensorData;
			out systemHealthy;
			out alerts;
		}
		
		exhibit state operationalBehavior : AvionicsOperationalStates;
	}
	
	requirement def AvionicsSystemRequirements {
		doc /* The avionics system shall provide integrated flight control, navigation, 
		       communication, and display capabilities for safe aircraft operation. */
		
		requirement navigationAccuracy {
			doc /* The navigation system shall maintain position accuracy within 10 meters. */
		}
		
		requirement controlResponseTime {
			doc /* The flight control computer shall process control commands within 20 milliseconds. */
		}
		
		requirement displayUpdateRate {
			doc /* Primary flight displays shall update at minimum 30 Hz refresh rate. */
		}
		
		requirement systemReliability {
			doc /* The avionics system shall maintain operational availability of 99.9% during flight. */
		}
		
		requirement communicationRange {
			doc /* The communication system shall maintain VHF radio contact up to 200 nautical miles. */
		}
	}
	
	requirement avionicsRequirements : AvionicsSystemRequirements {
		doc /* The integrated avionics suite shall enable autonomous and pilot-assisted flight operations 
		       by fusing sensor data, computing navigation solutions, generating flight control commands, 
		       and presenting critical flight information to the crew. */
		subject integratedAvionics;
	}
}
