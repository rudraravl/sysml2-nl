package WaterWellSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	item def WaterVolume {
		attribute volume : VolumeValue;
		attribute flowRate : VolumetricFlowRateValue;
		attribute pressure : PressureValue;
		attribute temperature : ThermodynamicTemperatureValue;
	}
	
	attribute def WaterDepth :> LengthValue;
	attribute def PumpSpeed :> AngularVelocityValue;
	attribute def ElectricalPower :> PowerValue;
	
	port def WaterFlowPort {
		out item waterFlow : WaterVolume;
	}
	
	port def PowerPort {
		in attribute voltage : ElectricPotentialValue;
		in attribute current : ElectricCurrentValue;
	}
	
	port def ControlPort {
		in attribute commandSignal : Boolean;
		out attribute statusSignal : Boolean;
	}
	
	part def UndergroundAquifer {
		attribute waterTableDepth : WaterDepth;
		attribute aquiferCapacity : VolumeValue;
		attribute naturalRechargeRate : VolumetricFlowRateValue;
		
		port waterSource : WaterFlowPort;
	}
	
	part def WellBore {
		attribute boreholeDepth : LengthValue;
		attribute boreholeDiameter : LengthValue;
		attribute casingMaterial : String;
		
		port waterIntake;
		port waterDischarge;
	}
	
	part def SubmersiblePump {
		attribute ratedFlowCapacity : VolumetricFlowRateValue;
		attribute maximumHead : LengthValue;
		attribute motorPower : ElectricalPower;
		attribute efficiency : Real;
		attribute isPumping : Boolean;
		attribute isOperational : Boolean;
		
		port waterInlet;
		port waterOutlet;
		port powerSupply : PowerPort;
		port control : ControlPort;
		
		state pumpState {
			entry; then off;
			
			state off {
				entry assign isPumping := false;
			}
			
			state on {
				entry assign isPumping := true;
				do action pumpOperation;
			}
			
			state maintenance {
				entry assign isOperational := false;
			}
			
			transition off_to_on
				first off
				accept control.commandSignal
				then on;
			
			transition on_to_off
				first on
				accept control.commandSignal
				then off;
			
			transition any_to_maintenance
				accept at control.commandSignal
				then maintenance;
		}
	}
	
	part def RisingPipe {
		attribute pipeLength : LengthValue;
		attribute pipeDiameter : LengthValue;
		attribute pipeMaterial : String;
		
		port inlet;
		port outlet;
	}
	
	part def PressureVessel {
		attribute tankCapacity : VolumeValue;
		attribute maxPressure : PressureValue;
		attribute currentVolume : VolumeValue;
		attribute currentPressure : PressureValue;
		attribute preChargePressure : PressureValue;
		
		port waterInlet;
		port waterOutlet : WaterFlowPort;
	}
	
	part def PressureController {
		attribute lowPressureSetpoint : PressureValue;
		attribute highPressureSetpoint : PressureValue;
		attribute hysteresis : PressureValue;
		
		port pressureInput;
		port pumpControl : ControlPort;
		
		perform action controlLogic : PressureControlAction;
	}
	
	part def NonReturnValve {
		attribute minimumOpeningPressure : PressureValue;
		
		port inlet;
		port outlet;
	}
	
	part def WaterDistributionNetwork {
		attribute totalPipeLength : LengthValue;
		attribute numberOfOutlets : Integer;
		attribute designFlowRate : VolumetricFlowRateValue;
		
		port supplyInlet;
		port deliveryOutlets[1..*];
	}
	
	part def WaterLevelSensor {
		attribute sensorDepth : LengthValue;
		attribute measurementAccuracy : LengthValue;
		
		port levelOutput;
	}
	
	action def MonitorWaterLevel {
		in aquiferDepth : WaterDepth;
		in criticalDepth : WaterDepth;
		out levelSafe : Boolean;
	}
	
	action def MeasureTankPressure {
		in vesselPressure : PressureValue;
		out pressureReading : PressureValue;
	}
	
	action def ControlPumpOperation {
		in pressureReading : PressureValue;
		in lowSetpoint : PressureValue;
		in highSetpoint : PressureValue;
		out pumpCommand : Boolean;
	}
	
	action def ExtractGroundwater {
		in pumpCapacity : VolumetricFlowRateValue;
		in operationTime : TimeValue;
		out extractedVolume : VolumeValue;
	}
	
	action def PressurizeStorage {
		in incomingFlow : VolumetricFlowRateValue;
		in currentVolume : VolumeValue;
		in tankCapacity : VolumeValue;
		out resultingPressure : PressureValue;
	}
	
	action def DistributeWater {
		in sourcePressure : PressureValue;
		in demandRate : VolumetricFlowRateValue;
		out deliveredVolume : VolumeValue;
	}
	
	action def PressureControlAction {
		in vesselPressure : PressureValue;
		in aquiferDepth : WaterDepth;
		in criticalDepth : WaterDepth;
		in lowSetpoint : PressureValue;
		in highSetpoint : PressureValue;
		out pumpCommand : Boolean;
		
		first start;
		then merge operationLoop;
		
		then action measurePressure : MeasureTankPressure {
			in vesselPressure = vesselPressure;
			out pressureReading;
		}
		
		then action checkLevel : MonitorWaterLevel {
			in aquiferDepth = aquiferDepth;
			in criticalDepth = criticalDepth;
			out levelSafe;
		}
		
		then decide;
			if not checkLevel.levelSafe then emergencyShutdown;
			if checkLevel.levelSafe then controlPump;
		
		action controlPump : ControlPumpOperation {
			in pressureReading = measurePressure.pressureReading;
			in lowSetpoint = lowSetpoint;
			in highSetpoint = highSetpoint;
			out pumpCommand;
		}
		then operationLoop;
		
		action emergencyShutdown {
			then assign pumpCommand := false;
		}
		then done;
	}
	
	action def WellSystemOperation {
		in aquiferDepth : WaterDepth;
		in criticalDepth : WaterDepth;
		in vesselPressure : PressureValue;
		in lowPressure : PressureValue;
		in highPressure : PressureValue;
		in pumpCapacity : VolumetricFlowRateValue;
		in operationTime : TimeValue;
		in incomingFlow : VolumetricFlowRateValue;
		in currentVolume : VolumeValue;
		in tankCapacity : VolumeValue;
		
		first start;
		then merge continuousOperation;
		
		then action monitorAquifer : MonitorWaterLevel {
			in aquiferDepth = aquiferDepth;
			in criticalDepth = criticalDepth;
			out levelSafe;
		}
		
		then decide;
			if not monitorAquifer.levelSafe then shutdown;
			if monitorAquifer.levelSafe then checkPressure;
		
		action checkPressure : MeasureTankPressure {
			in vesselPressure = vesselPressure;
			out pressureReading;
		}
		
		then decide;
			if checkPressure.pressureReading < lowPressure then startPumping;
			if checkPressure.pressureReading >= highPressure then stopPumping;
			if checkPressure.pressureReading >= lowPressure and 
			   checkPressure.pressureReading < highPressure then continuousOperation;
		
		action startPumping {
			then action extract : ExtractGroundwater {
				in pumpCapacity = pumpCapacity;
				in operationTime = operationTime;
				out extractedVolume;
			}
			
			then action pressurize : PressurizeStorage {
				in incomingFlow = incomingFlow;
				in currentVolume = currentVolume;
				in tankCapacity = tankCapacity;
				out resultingPressure;
			}
			
			then continuousOperation;
		}
		
		action stopPumping {
			then continuousOperation;
		}
		
		action shutdown;
		then done;
	}
	
	part def WaterWellSystem {
		doc /* An automated groundwater extraction and distribution system that 
		       maintains pressurized water supply by pumping from an underground 
		       aquifer into a storage vessel and delivering to end users. */
		
		part aquifer : UndergroundAquifer {
			attribute :>> waterTableDepth = 25.0 [SI::m];
			attribute :>> aquiferCapacity = 500000.0 [SI::m^3];
			attribute :>> naturalRechargeRate = 0.2 [SI::m^3/SI::s];
		}
		
		part wellBore : WellBore {
			attribute :>> boreholeDepth = 35.0 [SI::m];
			attribute :>> boreholeDiameter = 0.2 [SI::m];
			attribute :>> casingMaterial = "Steel";
		}
		
		part pump : SubmersiblePump {
			attribute :>> ratedFlowCapacity = 0.015 [SI::m^3/SI::s];
			attribute :>> maximumHead = 100.0 [SI::m];
			attribute :>> motorPower = 2200.0 [SI::W];
			attribute :>> efficiency = 0.75;
		}
		
		part risingPipe : RisingPipe {
			attribute :>> pipeLength = 40.0 [SI::m];
			attribute :>> pipeDiameter = 0.05 [SI::m];
			attribute :>> pipeMaterial = "HDPE";
		}
		
		part checkValve : NonReturnValve {
			attribute :>> minimumOpeningPressure = 10000.0 [SI::Pa];
		}
		
		part pressureVessel : PressureVessel {
			attribute :>> tankCapacity = 0.3 [SI::m^3];
			attribute :>> maxPressure = 600000.0 [SI::Pa];
			attribute :>> currentVolume = 0.15 [SI::m^3];
			attribute :>> currentPressure = 300000.0 [SI::Pa];
			attribute :>> preChargePressure = 150000.0 [SI::Pa];
		}
		
		part pressureController : PressureController {
			attribute :>> lowPressureSetpoint = 250000.0 [SI::Pa];
			attribute :>> highPressureSetpoint = 400000.0 [SI::Pa];
			attribute :>> hysteresis = 10000.0 [SI::Pa];
		}
		
		part levelSensor : WaterLevelSensor {
			attribute :>> sensorDepth = 30.0 [SI::m];
			attribute :>> measurementAccuracy = 0.1 [SI::m];
		}
		
		part distribution : WaterDistributionNetwork {
			attribute :>> totalPipeLength = 100.0 [SI::m];
			attribute :>> numberOfOutlets = 5;
			attribute :>> designFlowRate = 0.01 [SI::m^3/SI::s];
		}
		
		connect aquifer.waterSource to wellBore.waterIntake;
		connect wellBore.waterDischarge to pump.waterInlet;
		connect pump.waterOutlet to risingPipe.inlet;
		connect risingPipe.outlet to checkValve.inlet;
		connect checkValve.outlet to pressureVessel.waterInlet;
		connect pressureVessel.waterOutlet to distribution.supplyInlet;
		
		bind pressureController.pumpControl to pump.control;
		bind levelSensor.levelOutput to pressureController.pressureInput;
		
		perform action systemOperation : WellSystemOperation;
	}
	
	part waterWell : WaterWellSystem {
		perform systemOperation;
		
		part :>> pump {
			perform systemOperation.startPumping.extract;
		}
		
		part :>> pressureController {
			perform controlLogic;
		}
		
		part :>> pressureVessel {
			perform systemOperation.startPumping.pressurize;
		}
		
		part :>> distribution {
			perform action deliverWater : DistributeWater;
		}
	}
	
	requirement def SystemFunctionRequirement;
	requirement def PerformanceRequirement;
	requirement def SafetyRequirement;
	requirement def ReliabilityRequirement;
	
	requirement <'WW-001'> primaryFunction : SystemFunctionRequirement {
		doc /* The water well system shall extract groundwater from the aquifer and 
		       deliver it to end users at adequate pressure and flow rate. */
		
		subject waterWell;
		
		require minimumFlowDelivery;
		require pressureMaintenance;
		require aquiferProtection;
	}
	
	requirement <'WW-002'> minimumFlowDelivery : PerformanceRequirement {
		doc /* The system shall deliver a minimum flow rate of 0.01 cubic meters 
		       per second to the distribution network. */
		
		subject waterWell;
		
		assume constraint {
			waterWell.pump.ratedFlowCapacity >= 0.015 [SI::m^3/SI::s]
		}
		
		require constraint {
			waterWell.distribution.designFlowRate >= 0.01 [SI::m^3/SI::s]
		}
	}
	
	requirement <'WW-003'> pressureMaintenance : PerformanceRequirement {
		doc /* The system shall maintain water pressure in the storage vessel 
		       between 250 kPa and 400 kPa during normal operation. */
		
		subject waterWell;
		
		require constraint {
			waterWell.pressureVessel.currentPressure >= 250000.0 [SI::Pa] and
			waterWell.pressureVessel.currentPressure <= 400000.0 [SI::Pa]
		}
	}
	
	requirement <'WW-004'> aquiferProtection : SafetyRequirement {
		doc /* The system shall prevent pump operation when aquifer water level 
		       falls below the critical depth to avoid pump damage and aquifer depletion. */
		
		subject waterWell;
		
		require constraint {
			if waterWell.aquifer.waterTableDepth > waterWell.levelSensor.sensorDepth
			then waterWell.pump.control.commandSignal == false
		}
	}
	
	requirement <'WW-005'> systemReliability : ReliabilityRequirement {
		doc /* The system shall achieve 99% operational availability over a 
		       12-month period under normal operating conditions. */
		
		subject waterWell;
		
		require constraint {
			waterWell.pump.efficiency >= 0.70 and
			waterWell.pressureVessel.currentPressure <= waterWell.pressureVessel.maxPressure
		}
	}
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import WaterWellSystem::*;

    action orchestrator {
        attribute testPressureReading : PressureValue;
        attribute testLowSetpoint : PressureValue;
        attribute testHighSetpoint : PressureValue;
        action controlPumpProbe : ControlPumpOperation {
            in pressureReading = testPressureReading;
            in lowSetpoint = testLowSetpoint;
            in highSetpoint = testHighSetpoint;
        }
        first controlPumpProbe;
    }
}
