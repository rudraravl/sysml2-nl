package IonacoSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def IonConcentration {
		attribute value : Real;
	}
	
	attribute def AirQualityIndex {
		attribute value : Real;
	}
	
	attribute def FilterEfficiency {
		attribute value : Real;
	}
	
	item def AmbientAir {
		attribute temperature : ThermodynamicTemperatureValue;
		attribute humidity : Real;
		attribute qualityIndex : AirQualityIndex;
	}
	
	item def IonizedAir {
		attribute ionConcentration : IonConcentration;
		attribute qualityIndex : AirQualityIndex;
		attribute temperature : ThermodynamicTemperatureValue;
	}
	
	item def ElectricalPower {
		attribute voltage : ElectricPotentialValue;
		attribute current : ElectricCurrentValue;
		attribute power : PowerValue;
	}
	
	item def ControlSignal {
		attribute targetIonLevel : IonConcentration;
		attribute fanSpeed : Real;
		attribute operatingMode : OperatingMode;
	}
	
	enum def OperatingMode {
		off;
		standby;
		low;
		medium;
		high;
		auto;
	}
	
	port def AirInletPort {
		in item ambientAir : AmbientAir;
	}
	
	port def AirOutletPort {
		out item ionizedAir : IonizedAir;
	}
	
	port def PowerInputPort {
		in item electricalPower : ElectricalPower;
	}
	
	port def ControlInterfacePort {
		in attribute controlSignal : ControlSignal;
		out attribute statusFeedback : SystemStatus;
	}
	
	attribute def SystemStatus {
		attribute currentMode : OperatingMode;
		attribute currentIonLevel : IonConcentration;
		attribute airQuality : AirQualityIndex;
		attribute powerConsumption : PowerValue;
	}
	
	part def AirIntakeFan {
		attribute maxFlowRate : VolumeFlowRateValue;
		attribute currentSpeed : Real;
		attribute outputAir : AmbientAir;
		
		port airIn : AirInletPort;
		port powerIn : PowerInputPort;
		
		perform action drawAir {
			in attribute speed : Real;
			in attribute inputAir : AmbientAir;
			out attribute fanOutputAir : AmbientAir;
		}
	}
	
	part def PreFilter {
		attribute filterType : String;
		attribute efficiency : FilterEfficiency;
		attribute rawAir : AmbientAir;
		attribute filteredAir : AmbientAir;
		
		perform action filterParticulates {
			in attribute inputRawAir : AmbientAir;
			out attribute outputFilteredAir : AmbientAir;
		}
	}
	
	part def IonizationModule {
		attribute electrodeVoltage : ElectricPotentialValue;
		attribute ionGenerationRate : Real;
		attribute maxIonOutput : IonConcentration;
		attribute inputAir : AmbientAir;
		attribute ionizedAir : IonizedAir;
		
		port powerIn : PowerInputPort;
		
		perform action generateIons {
			in attribute moduleInputAir : AmbientAir;
			in attribute targetLevel : IonConcentration;
			out attribute moduleIonizedAir : IonizedAir;
		}
	}
	
	part def AirQualitySensor {
		attribute sensorAccuracy : Real;
		attribute measurementRange : AirQualityIndex;
		
		perform action measureQuality {
			in attribute airSample : IonizedAir;
			out attribute qualityReading : AirQualityIndex;
		}
	}
	
	part def IonSensor {
		attribute sensorPrecision : Real;
		attribute detectionRange : IonConcentration;
		
		perform action measureIonLevel {
			in attribute airSample : IonizedAir;
			out attribute ionReading : IonConcentration;
		}
	}
	
	part def ControlProcessor {
		attribute processingFrequency : FrequencyValue;
		attribute controlAlgorithm : String;
		
		port controlInterface : ControlInterfacePort;
		
		perform action regulateOperation {
			in attribute targetLevel : IonConcentration;
			in attribute currentLevel : IonConcentration;
			in attribute airQuality : AirQualityIndex;
			out attribute voltageCommand : ElectricPotentialValue;
			out attribute fanCommand : Real;
		}
	}
	
	part def PowerManagementUnit {
		attribute inputVoltage : ElectricPotentialValue;
		attribute maxOutputPower : PowerValue;
		attribute efficiency : Real;
		attribute ionizationPower : ElectricalPower;
		attribute fanPower : ElectricalPower;
		attribute controlPower : ElectricalPower;
		
		port powerInput : PowerInputPort;
		
		perform action distributePower {
			in attribute totalDemand : PowerValue;
			out attribute ionizationPowerOut : ElectricalPower;
			out attribute fanPowerOut : ElectricalPower;
			out attribute controlPowerOut : ElectricalPower;
		}
	}
	
	part def AirDistributionFan {
		attribute flowPattern : String;
		attribute currentSpeed : Real;
		
		port airIn : AirInletPort;
		port airOut : AirOutletPort;
		port powerIn : PowerInputPort;
		
		perform action distributeAir {
			in attribute ionizedAir : IonizedAir;
			in attribute speed : Real;
			out attribute distributedAir : IonizedAir;
		}
	}
	
	state def IonacoOperationalStates {
		in attribute systemActive : Boolean;
		in attribute initializationComplete : Boolean;
		in attribute currentMode : OperatingMode;
		in attribute airQualityIndex : AirQualityIndex;
		
		entry; then powerOff;
		
		state powerOff;
		
		transition powerOff_to_initialization
			first powerOff
			accept PowerOnCommand
			then initialization;
		
		state initialization;
		
		transition initialization_to_standby
			first initialization
			then standby;
		
		state standby;
		
		transition standby_to_active
			first standby
			accept ActivateCommand
			then activeOperation;
		
		state activeOperation {
			state lowMode;
			state mediumMode;
			state highMode;
			state autoMode;
		}
		
		transition active_to_standby
			first activeOperation
			accept DeactivateCommand
			then standby;
		
		transition active_to_maintenance
			first activeOperation
			accept MaintenanceRequest
			then maintenance;
		
		state maintenance;
		
		transition maintenance_to_standby
			first maintenance
			accept MaintenanceComplete
			then standby;
		
		transition standby_to_powerOff
			first standby
			accept PowerOffCommand
			then shutdown;
		
		state shutdown;
		
		transition shutdown_to_powerOff
			first shutdown
			then powerOff;
	}
	
	action def PowerOnCommand;
	action def PowerOffCommand;
	action def ActivateCommand;
	action def DeactivateCommand;
	action def SetLowModeCommand;
	action def SetMediumModeCommand;
	action def SetHighModeCommand;
	action def SetAutoModeCommand;
	action def MaintenanceRequest;
	action def MaintenanceComplete;
	
	part def Ionaco {
		attribute systemActive : Boolean;
		attribute initializationComplete : Boolean;
		attribute currentMode : OperatingMode;
		attribute airQualityIndex : AirQualityIndex;
		attribute currentIonLevel : IonConcentration;
		
		part intakeFan : AirIntakeFan {
			:>> maxFlowRate = 150.0 [m^3/h];
			:>> currentSpeed = 0.0;
		}
		
		part preFilter : PreFilter {
			:>> filterType = "HEPA";
			:>> efficiency = FilterEfficiency { value = 0.995; }
		}
		
		part ionizationModule : IonizationModule {
			:>> electrodeVoltage = 7500.0 [V];
			:>> ionGenerationRate = 5000000.0;
			:>> maxIonOutput = IonConcentration { value = 10000000.0; }
		}
		
		part airQualitySensor : AirQualitySensor {
			:>> sensorAccuracy = 0.98;
			:>> measurementRange = AirQualityIndex { value = 500.0; }
		}
		
		part ionSensor : IonSensor {
			:>> sensorPrecision = 0.95;
			:>> detectionRange = IonConcentration { value = 20000000.0; }
		}
		
		part controlProcessor : ControlProcessor {
			:>> processingFrequency = 100.0 [Hz];
			:>> controlAlgorithm = "PID";
		}
		
		part powerManagement : PowerManagementUnit {
			:>> inputVoltage = 230.0 [V];
			:>> maxOutputPower = 150.0 [W];
			:>> efficiency = 0.92;
		}
		
		part distributionFan : AirDistributionFan {
			:>> flowPattern = "Oscillating";
			:>> currentSpeed = 0.0;
		}
		
		port systemAirInlet : AirInletPort;
		port systemAirOutlet : AirOutletPort;
		port systemPowerInput : PowerInputPort;
		port systemControl : ControlInterfacePort;
		
		connection powerToPMU connect systemPowerInput to powerManagement.powerInput;
		connection pmuToIonization connect powerManagement.powerIn to ionizationModule.powerIn;
		connection pmuToIntakeFan connect powerManagement.powerIn to intakeFan.powerIn;
		connection pmuToDistributionFan connect powerManagement.powerIn to distributionFan.powerIn;
		
		connection airIntakeToFan connect systemAirInlet to intakeFan.airIn;
		connection fanToFilter connect intakeFan.airIn to preFilter.airIn;
		connection filterToIonization connect preFilter.airOut to ionizationModule.airIn;
		connection ionizationToDistribution connect ionizationModule.airOut to distributionFan.airIn;
		connection distributionToOutlet connect distributionFan.airOut to systemAirOutlet;
		
		connection controlToProcessor connect systemControl to controlProcessor.controlInterface;
		
		perform action purifyAndIonizeAir {
			first start;
			
			then action intakeAmbientAir {
				out attribute rawAir : AmbientAir;
			}
			
			then action filterAir {
				in attribute inputAir : AmbientAir = intakeAmbientAir.rawAir;
				out attribute cleanedAir : AmbientAir;
			}
			
			then action measureInputQuality {
				in attribute airSample : AmbientAir = filterAir.cleanedAir;
				out attribute initialQuality : AirQualityIndex;
			}
			
			then action determineIonizationTarget {
				in attribute currentQuality : AirQualityIndex = measureInputQuality.initialQuality;
				in attribute operatingMode : OperatingMode;
				out attribute targetIonLevel : IonConcentration;
			}
			
			then action performIonization {
				in attribute cleanAir : AmbientAir = filterAir.cleanedAir;
				in attribute targetLevel : IonConcentration = determineIonizationTarget.targetIonLevel;
				out attribute ionizedOutput : IonizedAir;
			}
			
			then action measureOutputIonLevel {
				in attribute ionizedAir : IonizedAir = performIonization.ionizedOutput;
				out attribute actualIonLevel : IonConcentration;
			}
			
			then action measureOutputQuality {
				in attribute ionizedAir : IonizedAir = performIonization.ionizedOutput;
				out attribute finalQuality : AirQualityIndex;
			}
			
			then decide;
				if measureOutputIonLevel.actualIonLevel.value < determineIonizationTarget.targetIonLevel.value * 0.9 then adjustIonization;
				if measureOutputIonLevel.actualIonLevel.value >= determineIonizationTarget.targetIonLevel.value * 0.9 then distributeAir;
			
			action adjustIonization {
				in attribute levelDeficit : Real;
				out attribute adjustedVoltage : ElectricPotentialValue;
			}
			then merge feedbackLoop;
			then performIonization;
			
			action distributeAir {
				in attribute processedAir : IonizedAir = performIonization.ionizedOutput;
				in attribute fanSpeed : Real;
				out attribute distributedAir : IonizedAir;
			}
			then done;
			
			merge feedbackLoop;
		}
		
		exhibit state operationalBehavior : IonacoOperationalStates {
			in systemActive = systemActive;
			in initializationComplete = initializationComplete;
			in currentMode = currentMode;
			in airQualityIndex = airQualityIndex;
		}
	}
	
	requirement def AirPurificationRequirement {
		doc /* The Ionaco system shall purify and ionize ambient air to improve indoor air quality. */
		
		subject ionacoSystem : Ionaco;
		
		require constraint ionizationEffectiveness {
			ionacoSystem.currentIonLevel.value >= 1000000.0
		}
		
		require constraint airQualityImprovement {
			ionacoSystem.systemAirOutlet.ionizedAir.qualityIndex.value >= 
				ionacoSystem.systemAirInlet.ambientAir.qualityIndex.value * 1.3
		}
		
		require constraint filterEfficiency {
			ionacoSystem.preFilter.efficiency.value >= 0.99
		}
	}
	
	requirement def SafetyRequirement {
		doc /* The Ionaco system shall operate within safe electrical and environmental parameters. */
		
		subject ionacoSystem : Ionaco;
		
		require constraint voltageLimit {
			ionacoSystem.ionizationModule.electrodeVoltage <= 10000.0 [V]
		}
		
		require constraint powerLimit {
			ionacoSystem.powerManagement.maxOutputPower <= 200.0 [W]
		}
		
		require constraint ionConcentrationLimit {
			ionacoSystem.currentIonLevel.value <= 20000000.0
		}
	}
	
	requirement def PerformanceRequirement {
		doc /* The Ionaco system shall maintain efficient and responsive operation across all modes. */
		
		subject ionacoSystem : Ionaco;
		
		require constraint continuousOperation {
			ionacoSystem.systemActive == true
		}
		
		require constraint sensorAccuracy {
			ionacoSystem.airQualitySensor.sensorAccuracy >= 0.95 and
			ionacoSystem.ionSensor.sensorPrecision >= 0.90
		}
		
		require constraint powerEfficiency {
			ionacoSystem.powerManagement.efficiency >= 0.85
		}
		
		require constraint airFlowRate {
			ionacoSystem.intakeFan.maxFlowRate >= 100.0 [m^3/h]
		}
	}
	
	requirement def OperationalRequirement {
		doc /* The Ionaco system shall provide multiple operating modes for different air quality conditions. */
		
		subject ionacoSystem : Ionaco;
		
		require constraint modeAvailability {
			ionacoSystem.currentMode == OperatingMode::low or
			ionacoSystem.currentMode == OperatingMode::medium or
			ionacoSystem.currentMode == OperatingMode::high or
			ionacoSystem.currentMode == OperatingMode::auto
		}
		
		require constraint autoModeAdaptation {
			ionacoSystem.currentMode == OperatingMode::auto implies
			ionacoSystem.airQualityIndex.value > 0.0
		}
	}
	
	requirement <'IONACO-SYS-001'> ionacoSystemRequirement {
		doc /* 
			The Ionaco system shall continuously purify and ionize ambient air through 
			multi-stage filtration and controlled ionization, automatically adapting 
			ionization levels based on real-time air quality measurements to optimize 
			indoor environmental health while maintaining safe operating conditions 
			and energy efficiency.
		*/
		
		subject primarySystem : Ionaco;
		
		assume constraint ambientAirAvailable {
			primarySystem.systemAirInlet.ambientAir.qualityIndex.value > 0.0
		}
		
		assume constraint powerAvailable {
			primarySystem.systemPowerInput.electricalPower.voltage >= 220.0 [V] and
			primarySystem.systemPowerInput.electricalPower.voltage <= 240.0 [V]
		}
		
		require airPurificationReq : AirPurificationRequirement {
			:>> subject ionacoSystem = primarySystem;
		}
		
		require safetyReq : SafetyRequirement {
			:>> subject ionacoSystem = primarySystem;
		}
		
		require performanceReq : PerformanceRequirement {
			:>> subject ionacoSystem = primarySystem;
		}
		
		require operationalReq : OperationalRequirement {
			:>> subject ionacoSystem = primarySystem;
		}
	}
	
	part ionacoInstance : Ionaco {
		:>> systemActive = false;
		:>> initializationComplete = false;
		:>> currentMode = OperatingMode::off;
		:>> airQualityIndex = AirQualityIndex { value = 100.0; }
		:>> currentIonLevel = IonConcentration { value = 0.0; }
	}
}
