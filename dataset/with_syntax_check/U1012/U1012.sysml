package 'Clothes Dryer System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	doc /* 
	This model describes a household clothes dryer system designed to remove moisture 
	from wet fabrics through controlled heating and mechanical tumbling. The system 
	operates by drawing ambient air, heating it to a specified temperature, circulating 
	it through a rotating drum containing wet clothes, and exhausting the moisture-laden 
	air. The primary function is to automatically dry a load of laundry by monitoring 
	moisture levels and adjusting heat and airflow until the clothes reach a target 
	dryness level, then safely cooling down before completing the cycle.
	*/
	
	// Value and Attribute Definitions
	
	attribute def MoistureLevel :> Real {
		doc /* Dimensionless ratio representing moisture content (0.0 = completely dry, 1.0 = saturated) */
	}
	
	attribute def CycleType {
		attribute cycleName : String;
		attribute targetTemperature : TemperatureValue;
		attribute targetMoisture : MoistureLevel;
		attribute maxDuration : TimeValue;
	}
	
	attribute def DoorStatus {
		attribute isOpen : Boolean;
		attribute isLocked : Boolean;
	}
	
	// Item Definitions
	
	item def LaundryLoad {
		attribute currentMoisture : MoistureLevel;
		attribute mass : MassValue;
		attribute fabricType : String;
	}
	
	item def AirFlow {
		attribute temperature : TemperatureValue;
		attribute humidity : MoistureLevel;
		attribute volumeFlowRate : VolumeFlowRateValue;
	}
	
	item def LintMaterial {
		attribute accumulatedMass : MassValue;
	}
	
	// Port Definitions
	
	port def ElectricalPowerPort {
		in attribute voltage : ElectricPotentialValue;
		in attribute current : ElectricCurrentValue;
	}
	
	port def AirFlowPort {
		inout item airStream : AirFlow;
	}
	
	port def MechanicalDrivePort {
		in attribute torque : TorqueValue;
		in attribute rotationalSpeed : AngularVelocityValue;
	}
	
	port def SensorDataPort {
		out attribute sensorReading : Real;
	}
	
	port def ControlSignalPort {
		in attribute commandSignal : Real;
	}
	
	// Part Definitions
	
	part def HeatingElement {
		port powerInput : ElectricalPowerPort;
		port airIn : AirFlowPort;
		port airOut : AirFlowPort;
		port controlInput : ControlSignalPort;
		
		attribute ratedPower : PowerValue;
		attribute currentTemperature : TemperatureValue;
		attribute heatingEfficiency : Real;
	}
	
	part def DrumAssembly {
		port driveInput : MechanicalDrivePort;
		port airCirculation : AirFlowPort;
		port laundryAccess;
		
		attribute drumCapacity : VolumeValue;
		attribute currentLoad : MassValue;
		attribute rotationSpeed : AngularVelocityValue;
	}
	
	part def DriveMotor {
		port powerInput : ElectricalPowerPort;
		port driveOutput : MechanicalDrivePort;
		port controlInput : ControlSignalPort;
		
		attribute motorPower : PowerValue;
		attribute outputTorque : TorqueValue;
		attribute operatingSpeed : AngularVelocityValue;
	}
	
	part def Blower {
		port powerInput : ElectricalPowerPort;
		port airIntake : AirFlowPort;
		port airDischarge : AirFlowPort;
		port controlInput : ControlSignalPort;
		
		attribute fanSpeed : AngularVelocityValue;
		attribute airFlowCapacity : VolumeFlowRateValue;
	}
	
	part def MoistureSensor {
		port sensingProbes : SensorDataPort;
		port drumInterface;
		
		attribute sensitivity : Real;
		attribute calibrationFactor : Real;
	}
	
	part def TemperatureSensor {
		port sensingElement : SensorDataPort;
		port measurementPoint;
		
		attribute measurementRange : TemperatureValue[2];
		attribute accuracy : TemperatureValue;
	}
	
	part def LintFilter {
		port airPassage : AirFlowPort;
		
		attribute filterArea : AreaValue;
		attribute capturedLint : MassValue;
		attribute filtrationEfficiency : Real;
	}
	
	part def ExhaustDuct {
		port ductInput : AirFlowPort;
		port externalVent;
		
		attribute ductDiameter : LengthValue;
		attribute ductLength : LengthValue;
	}
	
	part def DoorMechanism {
		port latchInterface;
		port safetySwitch;
		
		attribute doorStatus : DoorStatus;
	}
	
	part def UserInterface {
		port displayOutput;
		port buttonInput;
		
		attribute selectedCycle : CycleType;
		attribute startCommand : Boolean;
		attribute stopCommand : Boolean;
		attribute displayStatus : String;
	}
	
	part def ControlModule {
		port moistureSensorInput : SensorDataPort;
		port temperatureSensorInput : SensorDataPort;
		port doorSwitchInput;
		port userInterfaceInput;
		port heaterControl : ControlSignalPort;
		port motorControl : ControlSignalPort;
		port blowerControl : ControlSignalPort;
		
		attribute activeCycle : CycleType;
		attribute systemState : String;
		attribute elapsedTime : TimeValue;
	}
	
	// Action Definitions
	
	action def HeatAir {
		in targetTemperature : TemperatureValue;
		in ambientAir : AirFlow;
		out heatedAir : AirFlow;
		out powerConsumed : PowerValue;
	}
	
	action def TumbleLaundry {
		in drumSpeed : AngularVelocityValue;
		in laundryMass : MassValue;
		out mechanicalAction : TorqueValue;
	}
	
	action def CirculateAir {
		in blowerSpeed : AngularVelocityValue;
		out airMovement : VolumeFlowRateValue;
	}
	
	action def SenseMoisture {
		in laundryLoad : LaundryLoad;
		out moistureReading : MoistureLevel;
	}
	
	action def MonitorTemperature {
		in airStream : AirFlow;
		out temperatureReading : TemperatureValue;
	}
	
	action def VerifyDoorClosed {
		in doorMech : DoorMechanism;
		out isSafeToOperate : Boolean;
	}
	
	action def FilterLint {
		in moistAir : AirFlow;
		out filteredAir : AirFlow;
		out capturedLint : LintMaterial;
	}
	
	action def ExecuteDryingCycle {
		in laundry : LaundryLoad;
		in cycle : CycleType;
		out driedLaundry : LaundryLoad;
		
		first start;
		
		then action verifyDoor : VerifyDoorClosed {
			in doorMech;
			out isSafeToOperate;
		}
		
		then decide;
			if verifyDoor.isSafeToOperate then beginDrying;
			if not verifyDoor.isSafeToOperate then abortCycle;
		
		action beginDrying {
			first initializeCycle;
			
			action initializeCycle {
				attribute cycleStartTime : TimeValue;
				attribute initialMoisture : MoistureLevel;
			}
			
			then merge dryingLoop;
			
			then action measureConditions {
				action checkMoisture : SenseMoisture {
					in laundryLoad = laundry;
					out moistureReading;
				}
				
				action checkTemp : MonitorTemperature {
					in airStream;
					out temperatureReading;
				}
			}
			
			then decide;
				if measureConditions.checkMoisture.moistureReading > cycle.targetMoisture then continueHeating;
				if measureConditions.checkMoisture.moistureReading <= cycle.targetMoisture then coolDown;
			
			action continueHeating {
				action heating : HeatAir {
					in targetTemperature = cycle.targetTemperature;
					in ambientAir;
					out heatedAir;
					out powerConsumed;
				}
				
				action tumbling : TumbleLaundry {
					in drumSpeed = 0.524 [rad/s];
					in laundryMass = laundry.mass;
					out mechanicalAction;
				}
				
				action airCirculation : CirculateAir {
					in blowerSpeed = 157.08 [rad/s];
					out airMovement;
				}
				
				action lintCapture : FilterLint {
					in moistAir = heating.heatedAir;
					out filteredAir;
					out capturedLint;
				}
			}
			
			then dryingLoop;
			
			action coolDown {
				first stopHeating;
				
				action stopHeating {
					attribute heaterOff : Boolean := true;
				}
				
				then action coolTumble : TumbleLaundry {
					in drumSpeed = 0.314 [rad/s];
					in laundryMass = laundry.mass;
					out mechanicalAction;
				}
				
				then action coolAir : CirculateAir {
					in blowerSpeed = 104.72 [rad/s];
					out airMovement;
				}
				
				then finalizeCycle;
				
				action finalizeCycle {
					attribute finalMoisture : MoistureLevel;
					attribute cycleComplete : Boolean := true;
				}
			}
			
			then done;
		}
		
		action abortCycle {
			attribute abortReason : String := "Door not closed";
		}
		
		then done;
	}
	
	// System Part Definition
	
	part def ClothesDryer {
		doc /* Complete clothes dryer system integrating all subsystems */
		
		port mainPower : ElectricalPowerPort;
		port ambientAirIntake : AirFlowPort;
		port exhaustVent : AirFlowPort;
		
		part heatingElement : HeatingElement {
			attribute :>> ratedPower = 5000.0 [W];
			attribute :>> heatingEfficiency = 0.92;
		}
		
		part drum : DrumAssembly {
			attribute :>> drumCapacity = 0.18 [m^3];
		}
		
		part drumMotor : DriveMotor {
			attribute :>> motorPower = 750.0 [W];
		}
		
		part airBlower : Blower {
			attribute :>> airFlowCapacity = 0.08 [m^3/s];
		}
		
		part moistureSensor : MoistureSensor {
			attribute :>> sensitivity = 0.01;
		}
		
		part temperatureSensor : TemperatureSensor {
			attribute :>> accuracy = 2.0 [K];
		}
		
		part lintFilter : LintFilter {
			attribute :>> filtrationEfficiency = 0.95;
		}
		
		part exhaustDuct : ExhaustDuct {
			attribute :>> ductDiameter = 0.1 [m];
			attribute :>> ductLength = 2.0 [m];
		}
		
		part door : DoorMechanism;
		
		part controlPanel : UserInterface;
		
		part controller : ControlModule;
		
		connect mainPower to heatingElement.powerInput;
		connect mainPower to drumMotor.powerInput;
		connect mainPower to airBlower.powerInput;
		
		connect ambientAirIntake to airBlower.airIntake;
		connect airBlower.airDischarge to heatingElement.airIn;
		connect heatingElement.airOut to drum.airCirculation;
		connect drum.airCirculation to lintFilter.airPassage;
		connect lintFilter.airPassage to exhaustDuct.ductInput;
		connect exhaustDuct.externalVent to exhaustVent;
		
		connect drumMotor.driveOutput to drum.driveInput;
		
		connect moistureSensor.sensingProbes to controller.moistureSensorInput;
		connect temperatureSensor.sensingElement to controller.temperatureSensorInput;
		connect door.safetySwitch to controller.doorSwitchInput;
		connect controlPanel.buttonInput to controller.userInterfaceInput;
		
		connect controller.heaterControl to heatingElement.controlInput;
		connect controller.motorControl to drumMotor.controlInput;
		connect controller.blowerControl to airBlower.controlInput;
	}
	
	part clothesDryer : ClothesDryer {
		perform action dryingOperation : ExecuteDryingCycle {
			in laundry;
			in cycle = controlPanel.selectedCycle;
			out driedLaundry;
		}
	}
	
	requirement <'DR-001'> primaryDryingFunction {
		doc /* 
		The clothes dryer system shall remove moisture from wet laundry by heating 
		and circulating air through a rotating drum until the moisture content reaches 
		the target level specified by the selected drying cycle, then perform a cool-down 
		phase before completing the cycle.
		*/
		
		subject dryerSystem : ClothesDryer;
		
		require constraint moistureReduction {
			doc /* Final moisture level shall be less than or equal to target moisture level */
		}
		
		require constraint temperatureControl {
			doc /* Air temperature shall be maintained within ±5°C of target temperature during heating phase */
		}
		
		require constraint coolDownPhase {
			doc /* System shall perform cool-down tumbling for minimum 5 minutes after heating stops */
		}
	}
	
	requirement <'DR-002'> safetyRequirements {
		doc /* 
		The dryer shall incorporate safety mechanisms to prevent operation when unsafe 
		conditions exist and to protect against overheating.
		*/
		
		assume constraint doorMustBeClosed {
			doc /* Door must be fully closed and latched before operation begins */
		}
		
		require constraint drumStopsWhenDoorOpens {
			doc /* Drum rotation shall cease within 2 seconds of door opening */
		}
		
		require constraint temperatureLimit {
			doc /* Maximum air temperature shall not exceed 85°C to prevent fabric damage */
		}
		
		require constraint thermalCutoff {
			doc /* Heating element shall deactivate if temperature exceeds 90°C */
		}
	}
	
	requirement <'DR-003'> energyEfficiency {
		doc /* 
		The dryer shall optimize energy consumption through moisture-based cycle 
		termination and efficient heat transfer.
		*/
		
		require constraint moistureBasedTermination {
			doc /* Drying cycle shall terminate based on moisture sensor reading, not fixed time */
		}
		
		require constraint heatingEfficiency {
			doc /* Heating element efficiency shall be at least 90% */
		}
		
		require constraint lintFilterEfficiency {
			doc /* Lint filter shall capture at least 95% of airborne lint particles */
		}
	}
	
	requirement <'DR-004'> operationalPerformance {
		doc /* 
		The dryer shall achieve specified performance targets for drying capacity 
		and cycle duration.
		*/
		
		require constraint standardLoadCapacity {
			doc /* System shall accommodate laundry loads up to 8 kg */
		}
		
		require constraint typicalCycleDuration {
			doc /* Standard cotton cycle shall complete in 45-75 minutes for typical 6 kg load */
		}
		
		require constraint airFlowRate {
			doc /* Minimum air circulation rate shall be 0.08 m³/s */
		}
	}
}
