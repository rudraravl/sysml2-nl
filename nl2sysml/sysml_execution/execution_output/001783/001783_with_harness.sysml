package 'Fuel Injection System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def FuelPressure :> PressureValue {
		attribute :>> num : Real;
		attribute :>> mRef : PressureUnit;
	}
	
	attribute def FuelFlowRate :> VolumeFlowRateValue {
		attribute :>> num : Real;
		attribute :>> mRef : VolumeFlowRateUnit;
	}
	
	attribute def EngineRPM :> Real {
		attribute value : Real;
	}
	
	attribute def ThrottlePosition :> Real {
		attribute value : Real;
	}
	
	attribute def AirMassFlow :> MassFlowRateValue {
		attribute :>> num : Real;
		attribute :>> mRef : MassFlowRateUnit;
	}
	
	attribute def InjectionDuration :> TimeValue {
		attribute :>> num : Real;
		attribute :>> mRef : TimeUnit;
	}
	
	attribute def OxygenLevel :> Real {
		attribute value : Real;
	}
	
	item def Fuel {
		attribute octaneRating : Real;
		attribute temperature : TemperatureValue;
	}
	
	item def Air {
		attribute temperature : TemperatureValue;
		attribute pressure : PressureValue;
	}
	
	item def AirFuelMixture {
		attribute ratio : Real;
		attribute temperature : TemperatureValue;
	}
	
	attribute def InjectorCommand {
		attribute pulseWidth : InjectionDuration;
		attribute timing : TimeValue;
		attribute injectorId : Integer;
	}
	
	attribute def SensorData {
		attribute rpm : EngineRPM;
		attribute throttlePos : ThrottlePosition;
		attribute airMass : AirMassFlow;
		attribute oxygenLevel : OxygenLevel;
	}
	
	port def FuelSupplyPort {
		attribute pressure : FuelPressure;
		in item fuelIn : Fuel;
	}
	
	port def FuelDeliveryPort {
		attribute pressure : FuelPressure;
		out item fuelOut : Fuel;
	}
	
	port def AirIntakePort {
		in item airIn : Air;
		attribute flowRate : AirMassFlow;
	}
	
	port def MixtureOutputPort {
		out item mixtureOut : AirFuelMixture;
	}
	
	port def SensorOutputPort {
		out attribute sensorData : SensorData;
	}
	
	port def InjectorControlPort {
		in attribute command : InjectorCommand;
	}
	
	part def FuelTank {
		port fuelOutlet : FuelDeliveryPort;
		attribute capacity : VolumeValue;
		attribute currentLevel : VolumeValue;
	}
	
	part def FuelPump {
		port fuelInlet : FuelSupplyPort;
		port fuelOutlet : FuelDeliveryPort;
		attribute targetPressure : FuelPressure;
		attribute currentPressure : FuelPressure;
		
		action pumpFuel {
			in fuelInput : Fuel;
			out fuelOutput : Fuel;
			out deliveryPressure : FuelPressure;
		}
	}
	
	part def FuelFilter {
		port fuelInlet : FuelSupplyPort;
		port fuelOutlet : FuelDeliveryPort;
		attribute filterEfficiency : Real;
		
		action filterFuel {
			in fuelInput : Fuel;
			out fuelOutput : Fuel;
		}
	}
	
	part def FuelRail {
		port fuelInput : FuelSupplyPort;
		port injector1Port : FuelDeliveryPort;
		port injector2Port : FuelDeliveryPort;
		port injector3Port : FuelDeliveryPort;
		port injector4Port : FuelDeliveryPort;
		attribute railPressure : FuelPressure;
		
		action distributeFuel {
			in fuelSupply : Fuel;
			out fuelToInjector1 : Fuel;
			out fuelToInjector2 : Fuel;
			out fuelToInjector3 : Fuel;
			out fuelToInjector4 : Fuel;
		}
	}
	
	part def PressureRegulator {
		port fuelInlet : FuelSupplyPort;
		port fuelOutlet : FuelDeliveryPort;
		attribute targetPressure : FuelPressure;
		
		action regulatePressure {
			in fuelInput : Fuel;
			in target : FuelPressure;
			out fuelOutput : Fuel;
			out actualPressure : FuelPressure;
		}
	}
	
	part def FuelInjector {
		port fuelPort : FuelSupplyPort;
		port controlPort : InjectorControlPort;
		port sprayPort : FuelDeliveryPort;
		attribute isOpen : Boolean;
		attribute flowRate : FuelFlowRate;
		
		action injectFuel {
			in fuelSupply : Fuel;
			in command : InjectorCommand;
			out sprayedFuel : Fuel;
			
			first start;
			then action openValve {
				in cmd : InjectorCommand = command;
			}
			then action sprayFuel {
				in fuel : Fuel = fuelSupply;
				out spray : Fuel;
			}
			then action closeValve;
			then done;
		}
	}
	
	part def ThrottleBody {
		port airInPort : AirIntakePort;
		port airOutPort : AirIntakePort;
		attribute position : ThrottlePosition;
		attribute airFlow : AirMassFlow;
		
		action regulateAirflow {
			in airInput : Air;
			in throttlePos : ThrottlePosition;
			out airOutput : Air;
			out measuredFlow : AirMassFlow;
		}
	}
	
	part def IntakeManifold {
		port airPort : AirIntakePort;
		port fuelPort1 : FuelSupplyPort;
		port fuelPort2 : FuelSupplyPort;
		port fuelPort3 : FuelSupplyPort;
		port fuelPort4 : FuelSupplyPort;
		port mixturePort : MixtureOutputPort;
		
		action mixAirFuel {
			in air : Air;
			in fuel1 : Fuel;
			in fuel2 : Fuel;
			in fuel3 : Fuel;
			in fuel4 : Fuel;
			out mixture : AirFuelMixture;
		}
	}
	
	part def MassAirFlowSensor {
		port airPort : AirIntakePort;
		port sensorPort : SensorOutputPort;
		attribute measuredFlow : AirMassFlow;
		
		action measureAirflow {
			in air : Air;
			out flowReading : AirMassFlow;
		}
	}
	
	part def ThrottlePositionSensor {
		port sensorPort : SensorOutputPort;
		attribute measuredPosition : ThrottlePosition;
		
		action measurePosition {
			out positionReading : ThrottlePosition;
		}
	}
	
	part def CrankshaftPositionSensor {
		port sensorPort : SensorOutputPort;
		attribute measuredRPM : EngineRPM;
		
		action measureRPM {
			out rpmReading : EngineRPM;
		}
	}
	
	part def OxygenSensor {
		port sensorPort : SensorOutputPort;
		attribute measuredOxygen : OxygenLevel;
		
		action measureOxygen {
			out oxygenReading : OxygenLevel;
		}
	}
	
	part def EngineControlUnit {
		port sensorInputPort : SensorOutputPort;
		port injector1Control : InjectorControlPort;
		port injector2Control : InjectorControlPort;
		port injector3Control : InjectorControlPort;
		port injector4Control : InjectorControlPort;
		attribute targetAirFuelRatio : Real;
		attribute calculatedPulseWidth : InjectionDuration;
		
		action calculateInjection {
			in sensors : SensorData;
			out injectorCmd1 : InjectorCommand;
			out injectorCmd2 : InjectorCommand;
			out injectorCmd3 : InjectorCommand;
			out injectorCmd4 : InjectorCommand;
			
			first start;
			then action readSensors {
				in sensorInput : SensorData = sensors;
				out rpm : EngineRPM;
				out throttle : ThrottlePosition;
				out airMass : AirMassFlow;
				out oxygen : OxygenLevel;
			}
			then action computeFuelRequirement {
				in engineRPM : EngineRPM = readSensors.rpm;
				in throttlePos : ThrottlePosition = readSensors.throttle;
				in airMassFlow : AirMassFlow = readSensors.airMass;
				in oxygenLevel : OxygenLevel = readSensors.oxygen;
				out requiredFuelMass : Real;
			}
			then action determinePulseWidth {
				in fuelMass : Real = computeFuelRequirement.requiredFuelMass;
				out pulseWidth : InjectionDuration;
			}
			then action calculateTiming {
				in rpm : EngineRPM = readSensors.rpm;
				out injectionTiming : TimeValue;
			}
			then action generateCommands {
				in pulse : InjectionDuration = determinePulseWidth.pulseWidth;
				in timing : TimeValue = calculateTiming.injectionTiming;
				out cmd1 : InjectorCommand;
				out cmd2 : InjectorCommand;
				out cmd3 : InjectorCommand;
				out cmd4 : InjectorCommand;
			}
			then done;
		}
	}
	
	part fuelInjectionSystem {
		part fuelTank : FuelTank;
		part fuelPump : FuelPump;
		part fuelFilter : FuelFilter;
		part pressureRegulator : PressureRegulator;
		part fuelRail : FuelRail;
		part injector1 : FuelInjector;
		part injector2 : FuelInjector;
		part injector3 : FuelInjector;
		part injector4 : FuelInjector;
		part throttleBody : ThrottleBody;
		part intakeManifold : IntakeManifold;
		part mafSensor : MassAirFlowSensor;
		part tpsSensor : ThrottlePositionSensor;
		part crankSensor : CrankshaftPositionSensor;
		part o2Sensor : OxygenSensor;
		part ecu : EngineControlUnit;
		
		connection tankToPump connect fuelTank.fuelOutlet to fuelPump.fuelInlet;
		connection pumpToFilter connect fuelPump.fuelOutlet to fuelFilter.fuelInlet;
		connection filterToRegulator connect fuelFilter.fuelOutlet to pressureRegulator.fuelInlet;
		connection regulatorToRail connect pressureRegulator.fuelOutlet to fuelRail.fuelInput;
		connection railToInjector1 connect fuelRail.injector1Port to injector1.fuelPort;
		connection railToInjector2 connect fuelRail.injector2Port to injector2.fuelPort;
		connection railToInjector3 connect fuelRail.injector3Port to injector3.fuelPort;
		connection railToInjector4 connect fuelRail.injector4Port to injector4.fuelPort;
		connection injector1ToManifold connect injector1.sprayPort to intakeManifold.fuelPort1;
		connection injector2ToManifold connect injector2.sprayPort to intakeManifold.fuelPort2;
		connection injector3ToManifold connect injector3.sprayPort to intakeManifold.fuelPort3;
		connection injector4ToManifold connect injector4.sprayPort to intakeManifold.fuelPort4;
		connection throttleToManifold connect throttleBody.airOutPort to intakeManifold.airPort;
		connection mafToECU connect mafSensor.sensorPort to ecu.sensorInputPort;
		connection tpsToECU connect tpsSensor.sensorPort to ecu.sensorInputPort;
		connection crankToECU connect crankSensor.sensorPort to ecu.sensorInputPort;
		connection o2ToECU connect o2Sensor.sensorPort to ecu.sensorInputPort;
		connection ecuToInjector1 connect ecu.injector1Control to injector1.controlPort;
		connection ecuToInjector2 connect ecu.injector2Control to injector2.controlPort;
		connection ecuToInjector3 connect ecu.injector3Control to injector3.controlPort;
		connection ecuToInjector4 connect ecu.injector4Control to injector4.controlPort;
		
		perform action deliverPreciseFuelAirMixture;
	}
	
	action def MonitorEngineConditions {
		out sensorReadings : SensorData;
	}
	
	action def CalculateOptimalFuel {
		in sensorData : SensorData;
		out fuelCommands : InjectorCommand[4];
	}
	
	action def InjectFuelPrecisely {
		in commands : InjectorCommand[4];
		in fuelSupply : Fuel;
		out sprayedFuel : Fuel[4];
	}
	
	action def MixWithAir {
		in air : Air;
		in fuel : Fuel[4];
		out combustibleMixture : AirFuelMixture;
	}
	
	action deliverPreciseFuelAirMixture {
		in airInput : Air;
		in fuelInput : Fuel;
		out mixture : AirFuelMixture;
		
		first start;
		then merge continuousOperation;
		then action monitorConditions : MonitorEngineConditions {
			out currentSensors : SensorData;
		}
		then action calculateFuel : CalculateOptimalFuel {
			in sensorData = monitorConditions.currentSensors;
			out injectionCommands : InjectorCommand[4];
		}
		then action injectFuel : InjectFuelPrecisely {
			in commands = calculateFuel.injectionCommands;
			in fuelSupply = fuelInput;
			out fuelSprays : Fuel[4];
		}
		then action mixFuelAir : MixWithAir {
			in air = airInput;
			in fuel = injectFuel.fuelSprays;
			out finalMixture : AirFuelMixture;
		}
		then continuousOperation;
	}
	
	requirement def OptimalCombustionRequirement {
		doc /* The fuel injection system shall deliver a precise air-fuel mixture 
		       to enable optimal combustion efficiency across all engine operating conditions. */
		
		subject fuelInjectionSystem;
		
		require targetAirFuelRatio : Real;
		assume engineOperatingRange : EngineRPM;
		
		requirement preciseMetering {
			doc /* Fuel shall be metered with accuracy within 2% of target value. */
		}
		
		requirement responsiveness {
			doc /* System shall adjust injection parameters within 20 milliseconds 
			       of detecting changes in engine conditions. */
		}
		
		requirement pressureRegulation {
			doc /* Fuel rail pressure shall be maintained at target pressure 
			       with variation less than 5%. */
		}
	}
	
	requirement systemRequirement : OptimalCombustionRequirement {
		subject system = fuelInjectionSystem;
		assume system.ecu.targetAirFuelRatio == 14.7;
	}
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import 'Fuel Injection System'::*;
}
