package MachineSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def OperationalState {
		attribute isActive : Boolean;
		attribute currentSpeed : Real;
		attribute operatingTemperature : TemperatureValue;
		attribute powerConsumption : PowerValue;
	}
	
	attribute def ProcessingRate :> MassFlowRateValue;
	attribute def EfficiencyRating :> Real;
	
	item def RawMaterial {
		attribute mass : MassValue;
		attribute temperature : TemperatureValue;
	}
	
	item def ProcessedProduct {
		attribute mass : MassValue;
		attribute quality : Real;
		attribute temperature : TemperatureValue;
	}
	
	item def ElectricalPower {
		attribute voltage : ElectricPotentialDifferenceValue;
		attribute current : ElectricCurrentValue;
		attribute frequency : FrequencyValue;
	}
	
	item def CoolantFluid {
		attribute flowRate : VolumeFlowRateValue;
		attribute inletTemperature : TemperatureValue;
		attribute outletTemperature : TemperatureValue;
	}
	
	port def MaterialInputPort {
		in item rawInput : RawMaterial;
	}
	
	port def ProductOutputPort {
		out item processedOutput : ProcessedProduct;
	}
	
	port def PowerPort {
		in item power : ElectricalPower;
	}
	
	port def CoolantPort {
		in item coolantIn : CoolantFluid;
		out item coolantOut : CoolantFluid;
	}
	
	port def ControlInterfacePort {
		in attribute commandSpeed : Real;
		in attribute commandMode : OperatingMode;
		out attribute currentState : OperationalState;
		out attribute diagnostics : DiagnosticData;
	}
	
	enum def OperatingMode {
		enum idle;
		enum startup;
		enum production;
		enum shutdown;
		enum maintenance;
	}
	
	attribute def DiagnosticData {
		attribute errorCode : Integer;
		attribute warningFlags : Boolean[*];
		attribute lastMaintenanceTime : TimeValue;
	}
	
	part def PowerSupplyUnit {
		port powerOutput : PowerPort;
		attribute ratedVoltage : ElectricPotentialDifferenceValue;
		attribute ratedCurrent : ElectricCurrentValue;
		attribute maxPower : PowerValue;
	}
	
	part def CoolingSystem {
		port coolantSupply : CoolantPort;
		attribute coolingCapacity : PowerValue;
		attribute pumpFlowRate : VolumeFlowRateValue;
		
		action def CirculateCoolant {
			in requiredFlowRate : VolumeFlowRateValue;
			out actualFlowRate : VolumeFlowRateValue;
			out coolingEfficiency : Real;
		}
	}
	
	part def MaterialFeeder {
		port materialOutput : MaterialInputPort;
		attribute feedRate : ProcessingRate;
		
		action def FeedMaterial {
			in targetRate : ProcessingRate;
			out actualRate : ProcessingRate;
			out materialAvailable : Boolean;
		}
	}
	
	part def ProductCollector {
		port productInput : ProductOutputPort;
		attribute storageCapacity : MassValue;
		
		action def CollectProduct {
			in incomingProduct : ProcessedProduct;
			out storageLevel : Real;
		}
	}
	
	part def ControlSystem {
		port controlInterface : ControlInterfacePort;
		
		action def MonitorMachine {
			in currentState : OperationalState;
			out speedDeviation : Real;
			out temperatureStatus : Boolean;
			out powerStatus : Boolean;
		}
		
		action def AdjustOperatingParameters {
			in targetSpeed : Real;
			in currentSpeed : Real;
			in temperatureReading : TemperatureValue;
			out speedCommand : Real;
			out coolingCommand : VolumeFlowRateValue;
		}
		
		action def ControlLoop {
			in targetSpeed : Real;
			in maxTemperature : TemperatureValue;
			out operatingCommand : OperationalState;
			
			first start;
			then merge continueMonitoring;
			then action monitor : MonitorMachine {
				in currentState;
				out speedDeviation;
				out temperatureStatus;
				out powerStatus;
			}
			then decide;
				if monitor.temperatureStatus == false then emergencyShutdown;
				if monitor.powerStatus == false then emergencyShutdown;
				if monitor.speedDeviation > 5.0 then adjust;
				if monitor.speedDeviation <= 5.0 then continueMonitoring;
			action adjust : AdjustOperatingParameters {
				in targetSpeed = targetSpeed;
				in currentSpeed = monitor.currentState.currentSpeed;
				in temperatureReading = monitor.currentState.operatingTemperature;
				out speedCommand;
				out coolingCommand;
			}
			then continueMonitoring;
			action emergencyShutdown;
			then done;
		}
	}
	
	signal def StartupCommand;
	signal def ProcessCommand;
	signal def PauseCommand;
	signal def ShutdownCommand;
	signal def ResetCommand;
	
	part def ProcessingCore {
		port powerInput : PowerPort;
		port coolingInput : CoolantPort;
		port materialIn : MaterialInputPort;
		port productOut : ProductOutputPort;
		
		attribute ratedCapacity : ProcessingRate;
		attribute maxOperatingTemp : TemperatureValue;
		attribute efficiency : EfficiencyRating;
		
		state processingStates {
			entry; then offline;
			
			state offline {
				entry assign operationalState.isActive := false;
				entry assign operationalState.currentSpeed := 0.0;
			}
			
			transition offline_to_initializing
				first offline
				accept StartupCommand
				then initializing;
			
			state initializing {
				entry assign operationalState.isActive := true;
				do action warmup {
					in targetTemperature : TemperatureValue;
					out currentTemperature : TemperatureValue;
				}
			}
			
			transition initializing_to_ready
				first initializing
				if operationalState.operatingTemperature >= minimumOperatingTemp
				then ready;
			
			state ready {
				do action standby;
			}
			
			transition ready_to_processing
				first ready
				accept ProcessCommand
				then processing;
			
			state processing {
				do action transformMaterial {
					in rawMaterial : RawMaterial;
					in processingSpeed : Real;
					out product : ProcessedProduct;
					out energyUsed : PowerValue;
				}
			}
			
			transition processing_to_ready
				first processing
				accept PauseCommand
				then ready;
			
			transition processing_to_stopping
				first processing
				accept ShutdownCommand
				then stopping;
			
			transition processing_to_fault
				first processing
				if operationalState.operatingTemperature > maxOperatingTemp
				then fault;
			
			state stopping {
				entry assign operationalState.isActive := false;
				do action cooldown {
					in currentTemp : TemperatureValue;
					out safeTemp : TemperatureValue;
				}
			}
			
			transition stopping_to_offline
				first stopping
				if operationalState.operatingTemperature < safeShutdownTemp
				then offline;
			
			state fault {
				entry assign operationalState.isActive := false;
			}
			
			transition fault_to_offline
				first fault
				accept ResetCommand
				if operationalState.operatingTemperature < safeShutdownTemp
				then offline;
		}
		
		private attribute minimumOperatingTemp : TemperatureValue;
		private attribute safeShutdownTemp : TemperatureValue;
		private attribute operationalState : OperationalState;
	}
	
	part def Machine {
		port powerConnection : PowerPort;
		port coolantConnection : CoolantPort;
		port materialInput : MaterialInputPort;
		port productOutput : ProductOutputPort;
		port controlConnection : ControlInterfacePort;
		
		part core : ProcessingCore {
			attribute :>> ratedCapacity = 100.0 [kg/h];
			attribute :>> maxOperatingTemp = 423.15 [K];
			attribute :>> efficiency = 0.85;
		}
		
		part controller : ControlSystem;
		
		connect powerConnection to core.powerInput;
		connect coolantConnection to core.coolingInput;
		connect materialInput to core.materialIn;
		connect productOutput to core.productOut;
		connect controlConnection to controller.controlInterface;
		
		attribute totalMass : MassValue;
		attribute footprint : AreaValue;
		attribute operatingTemperatureRange : TemperatureValue[2];
	}
	
	requirement def FunctionalRequirement {
		doc /* The machine shall perform its primary function of transforming raw material into processed product. */
		
		require constraint processingCapability {
			doc /* The machine shall process raw material at a minimum rate of 80 kg/hr. */
		}
		
		require constraint productQuality {
			doc /* The machine shall produce output with quality rating of at least 0.95. */
		}
	}
	
	requirement def PerformanceRequirement {
		doc /* The machine shall meet specified performance criteria during operation. */
		
		require constraint operationalEfficiency {
			doc /* The machine shall operate at minimum 80% efficiency at rated capacity. */
		}
		
		require constraint speedStability {
			doc /* Operating speed shall remain within 3% of commanded value during steady state. */
		}
		
		require constraint thermalManagement {
			doc /* Operating temperature shall not exceed maximum rated temperature. */
		}
	}
	
	requirement def SafetyRequirement {
		doc /* The machine shall operate safely under all conditions. */
		
		require constraint emergencyStop {
			doc /* The machine shall cease processing within 10 seconds of emergency stop command. */
		}
		
		require constraint overtemperatureProtection {
			doc /* The machine shall automatically shut down if temperature exceeds safe limit. */
		}
		
		require constraint powerFailureResponse {
			doc /* The machine shall enter safe state upon power interruption. */
		}
	}
	
	requirement machineSystemRequirements {
		subject machine : Machine;
		
		require functionalRequirement : FunctionalRequirement;
		require performanceRequirement : PerformanceRequirement;
		require safetyRequirement : SafetyRequirement;
	}
	
	action def ProcessMaterialBatch {
		in batchSize : MassValue;
		in targetSpeed : Real;
		in operatingDuration : TimeValue;
		out totalProcessed : MassValue;
		out averageQuality : Real;
		
		first start;
		then action initializeSystem {
			out systemReady : Boolean;
		}
		then action rampUpToSpeed {
			in startSpeed = 0.0;
			in endSpeed = targetSpeed;
			out achievedSpeed : Real;
		}
		then action processBatch {
			in duration = operatingDuration;
			in processingSpeed = targetSpeed;
			in inputMass = batchSize;
			out outputMass : MassValue;
			out qualityMetric : Real;
		}
		then action shutdownSequence {
			out shutdownComplete : Boolean;
		}
		then assign totalProcessed := processBatch.outputMass;
		then assign averageQuality := processBatch.qualityMetric;
		then done;
	}
	
	part machineSystem : Machine {
		attribute :>> totalMass = 2500.0 [kg];
		attribute :>> footprint = 12.0 [m^2];
		attribute :>> operatingTemperatureRange = (293.15 [K], 423.15 [K]);
		
		perform action operation[*] ordered : ProcessMaterialBatch;
		
		part powerSupply : PowerSupplyUnit {
			attribute :>> ratedVoltage = 480.0 [V];
			attribute :>> ratedCurrent = 200.0 [A];
			attribute :>> maxPower = 96000.0 [W];
		}
		
		part coolingSystem : CoolingSystem {
			attribute :>> coolingCapacity = 50000.0 [W];
			attribute :>> pumpFlowRate = 20.0 [L/min];
		}
		
		part feeder : MaterialFeeder {
			attribute :>> feedRate = 120.0 [kg/h];
		}
		
		part collector : ProductCollector {
			attribute :>> storageCapacity = 500.0 [kg];
		}
		
		connect powerSupply.powerOutput to machineSystem.powerConnection;
		connect coolingSystem.coolantSupply to machineSystem.coolantConnection;
		connect feeder.materialOutput to machineSystem.materialInput;
		connect machineSystem.productOutput to collector.productInput;
		
		satisfy machineSystemRequirements;
	}
}
