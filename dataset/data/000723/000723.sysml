package 'Oxygen Concentrator System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def OxygenConcentration :> Real;
	attribute def StartCommand;
	attribute def StopCommand;
	attribute def AlarmSignal;
	attribute def ValvePosition :> Real;
	
	item def AmbientAir {
		attribute oxygenContent : OxygenConcentration;
		attribute nitrogenContent : OxygenConcentration;
		attribute pressure : PressureValue;
		attribute temperature : TemperatureValue;
	}
	
	item def CompressedAir {
		attribute oxygenContent : OxygenConcentration;
		attribute pressure : PressureValue;
		attribute flowRate : VolumeFlowRateValue;
	}
	
	item def ConcentratedOxygen {
		attribute purity : OxygenConcentration;
		attribute flowRate : VolumeFlowRateValue;
		attribute pressure : PressureValue;
	}
	
	item def NitrogenWaste {
		attribute nitrogenContent : OxygenConcentration;
		attribute flowRate : VolumeFlowRateValue;
	}
	
	port def AirIntakePort {
		in item ambientAir : AmbientAir;
	}
	
	port def CompressedAirPort {
		out item compressedAir : CompressedAir;
	}
	
	port def OxygenDeliveryPort {
		out item concentratedOxygen : ConcentratedOxygen;
	}
	
	port def WastePort {
		out item nitrogenWaste : NitrogenWaste;
	}
	
	port def PowerPort {
		in attribute powerSupply : PowerValue;
	}
	
	part def AirCompressor {
		port airIn : AirIntakePort;
		port compressedOut : CompressedAirPort;
		port power : PowerPort;
		
		attribute compressionRatio : Real;
		attribute operatingPressure : PressureValue;
		attribute motorPower : PowerValue;
	}
	
	part def MolecularSieveBed {
		port compressedIn {
			in item compressedAir : CompressedAir;
		}
		port oxygenOut {
			out item enrichedOxygen : ConcentratedOxygen;
		}
		port wasteOut : WastePort;
		
		attribute zeoliteType : String;
		attribute bedCapacity : MassValue;
		attribute adsorptionEfficiency : Real;
		attribute regenerationCycleTime : TimeValue;
	}
	
	part def ProductTank {
		port oxygenIn {
			in item enrichedOxygen : ConcentratedOxygen;
		}
		port oxygenOut {
			out item storedOxygen : ConcentratedOxygen;
		}
		
		attribute storageVolume : VolumeValue;
		attribute currentVolume : VolumeValue;
		attribute tankPressure : PressureValue;
		attribute maxPressure : PressureValue;
	}
	
	part def FlowController {
		port oxygenIn {
			in item storedOxygen : ConcentratedOxygen;
		}
		port regulatedOut {
			out item regulatedOxygen : ConcentratedOxygen;
		}
		
		attribute targetFlowRate : VolumeFlowRateValue;
		attribute actualFlowRate : VolumeFlowRateValue;
		attribute valvePosition : ValvePosition;
	}
	
	part def OxygenSensor {
		port sensorInput {
			in item oxygen : ConcentratedOxygen;
		}
		port readingOutput {
			out attribute purityReading : OxygenConcentration;
			out attribute flowReading : VolumeFlowRateValue;
			out attribute pressureReading : PressureValue;
		}
		
		attribute accuracy : Real;
		attribute responseTime : TimeValue;
	}
	
	part def PSAController {
		port sensorInput {
			in attribute purity : OxygenConcentration;
			in attribute flow : VolumeFlowRateValue;
			in attribute pressure : PressureValue;
		}
		port controlOutput {
			out attribute valveCommand : ValvePosition;
			out attribute compressorSpeed : Real;
			out attribute bedSwitchSignal : Boolean;
		}
		
		attribute cycleTime : TimeValue;
		attribute switchingPressure : PressureValue;
		attribute targetPurity : OxygenConcentration;
	}
	
	part def SafetySystem {
		port monitorInput {
			in attribute oxygenPurity : OxygenConcentration;
			in attribute systemPressure : PressureValue;
			in attribute systemTemperature : TemperatureValue;
		}
		port alarmOutput {
			out attribute alarm : AlarmSignal;
			out attribute shutdownSignal : Boolean;
		}
		
		attribute minPurity : OxygenConcentration;
		attribute maxPressure : PressureValue;
		attribute maxTemperature : TemperatureValue;
	}
	
	action def IntakeAir {
		in ambientAir : AmbientAir;
		out filteredAir : AmbientAir;
	}
	
	action def CompressAir {
		in filteredAir : AmbientAir;
		in powerLevel : PowerValue;
		out compressedAir : CompressedAir;
	}
	
	action def SeparateOxygen {
		in compressedAir : CompressedAir;
		out enrichedOxygen : ConcentratedOxygen;
		out nitrogenWaste : NitrogenWaste;
	}
	
	action def BufferOxygen {
		in enrichedOxygen : ConcentratedOxygen;
		out storedOxygen : ConcentratedOxygen;
	}
	
	action def RegulateFlow {
		in storedOxygen : ConcentratedOxygen;
		in targetFlow : VolumeFlowRateValue;
		out regulatedOxygen : ConcentratedOxygen;
	}
	
	action def MonitorQuality {
		in oxygen : ConcentratedOxygen;
		out purity : OxygenConcentration;
		out flow : VolumeFlowRateValue;
		out pressure : PressureValue;
	}
	
	action def ControlPSA {
		in purity : OxygenConcentration;
		in flow : VolumeFlowRateValue;
		in pressure : PressureValue;
		out valveCmd : ValvePosition;
		out compressorCmd : Real;
		out bedSwitch : Boolean;
	}
	
	action def CheckSafety {
		in purity : OxygenConcentration;
		in pressure : PressureValue;
		in temperature : TemperatureValue;
		out safetyStatus : Boolean;
		out alarm : AlarmSignal;
	}
	
	action def ProduceOxygen {
		in ambientAir : AmbientAir;
		in powerSupply : PowerValue;
		in targetFlowRate : VolumeFlowRateValue;
		out deliveredOxygen : ConcentratedOxygen;
		out safetyAlarm : AlarmSignal;
		
		first accept startCmd : StartCommand;
		then action operationCycle {
			action intakeAir : IntakeAir {
				in ambientAir = ProduceOxygen::ambientAir;
				out filteredAir;
			}
			flow intakeAir.filteredAir to compressAir.filteredAir;
			action compressAir : CompressAir {
				in filteredAir;
				in powerLevel = powerSupply;
				out compressedAir;
			}
			flow compressAir.compressedAir to separateOxygen.compressedAir;
			action separateOxygen : SeparateOxygen {
				in compressedAir;
				out enrichedOxygen;
				out nitrogenWaste;
			}
			flow separateOxygen.enrichedOxygen to bufferOxygen.enrichedOxygen;
			action bufferOxygen : BufferOxygen {
				in enrichedOxygen;
				out storedOxygen;
			}
			flow bufferOxygen.storedOxygen to regulateFlow.storedOxygen;
			action regulateFlow : RegulateFlow {
				in storedOxygen;
				in targetFlow = targetFlowRate;
				out regulatedOxygen;
			}
			flow regulateFlow.regulatedOxygen to monitorQuality.oxygen;
			action monitorQuality : MonitorQuality {
				in oxygen;
				out purity;
				out flow;
				out pressure;
			}
			flow monitorQuality.purity to controlPSA.purity;
			flow monitorQuality.flow to controlPSA.flow;
			flow monitorQuality.pressure to controlPSA.pressure;
			action controlPSA : ControlPSA {
				in purity;
				in flow;
				in pressure;
				out valveCmd;
				out compressorCmd;
				out bedSwitch;
			}
			flow monitorQuality.purity to checkSafety.purity;
			flow monitorQuality.pressure to checkSafety.pressure;
			action checkSafety : CheckSafety {
				in purity;
				in pressure;
				in temperature = ProduceOxygen::ambientAir.temperature;
				out safetyStatus;
				out alarm;
			}
		}
		then accept stopCmd : StopCommand;
	}
	
	part def OxygenConcentrator {
		doc /* 
			An oxygen concentrator system that extracts and concentrates oxygen from ambient air
			using pressure swing adsorption (PSA) technology. The system continuously draws in
			ambient air, compresses it, separates oxygen from nitrogen using molecular sieve beds,
			and delivers medical-grade concentrated oxygen at controlled flow rates for respiratory therapy.
		*/
		
		port airIntake : AirIntakePort;
		port oxygenDelivery : OxygenDeliveryPort;
		port nitrogenExhaust : WastePort;
		port powerInput : PowerPort;
		
		part compressor : AirCompressor {
			port airIn = OxygenConcentrator::airIntake;
		}
		
		part sieveBedA : MolecularSieveBed;
		part sieveBedB : MolecularSieveBed;
		
		part productTank : ProductTank;
		
		part flowController : FlowController {
			port regulatedOut = OxygenConcentrator::oxygenDelivery;
		}
		
		part oxygenSensor : OxygenSensor;
		
		part psaController : PSAController;
		
		part safetySystem : SafetySystem;
		
		connection compressorToSieveA connect 
			compressor.compressedOut to sieveBedA.compressedIn;
		
		connection compressorToSieveB connect 
			compressor.compressedOut to sieveBedB.compressedIn;
		
		connection sieveAToTank connect 
			sieveBedA.oxygenOut to productTank.oxygenIn;
		
		connection sieveBToTank connect 
			sieveBedB.oxygenOut to productTank.oxygenIn;
		
		connection tankToFlowController connect 
			productTank.oxygenOut to flowController.oxygenIn;
		
		connection flowControllerToSensor connect 
			flowController.regulatedOut to oxygenSensor.sensorInput;
		
		connection sensorToController connect 
			oxygenSensor.readingOutput to psaController.sensorInput;
		
		connection sensorToSafety connect 
			oxygenSensor.readingOutput to safetySystem.monitorInput;
		
		connection sieveAWaste connect 
			sieveBedA.wasteOut to nitrogenExhaust;
		
		connection sieveBWaste connect 
			sieveBedB.wasteOut to nitrogenExhaust;
		
		perform action produceOxygen : ProduceOxygen {
			in ambientAir;
			in powerSupply;
			in targetFlowRate;
			out deliveredOxygen;
			out safetyAlarm;
		}
		
		state machine operationalStates {
			initial state Standby;
			state Operating {
				state Adsorption;
				state Desorption;
				transition from Adsorption to Desorption;
				transition from Desorption to Adsorption;
			}
			state Alarm;
			
			transition from Standby to Operating;
			transition from Operating to Standby;
			transition from Operating to Alarm;
			transition from Alarm to Standby;
		}
	}
	
	requirement def PrimaryFunctionRequirement {
		doc /* 
			The oxygen concentrator shall extract oxygen from ambient air and deliver
			concentrated oxygen at medical-grade purity for respiratory therapy applications.
		*/
		subject system : OxygenConcentrator;
	}
	
	requirement def OxygenPurityRequirement {
		doc /* The delivered oxygen concentration shall be at least 90% by volume. */
		subject oxygen : ConcentratedOxygen;
		require constraint {
			oxygen.purity >= 90.0
		}
	}
	
	requirement def FlowRateRequirement {
		doc /* The system shall deliver oxygen at adjustable flow rates between 0.5 and 5 liters per minute. */
		subject output : ConcentratedOxygen;
		require constraint {
			output.flowRate >= 0.5 and output.flowRate <= 5.0
		}
	}
	
	requirement def ContinuousOperationRequirement {
		doc /* The system shall operate continuously for at least 24 hours without interruption. */
		subject system : OxygenConcentrator;
	}
	
	requirement def SafetyMonitoringRequirement {
		doc /* 
			The system shall continuously monitor oxygen purity, pressure, and temperature,
			and activate alarms if safety thresholds are exceeded.
		*/
		subject safety : SafetySystem;
		require constraint {
			safety.minPurity >= 85.0 and
			safety.maxPressure <= 350.0 and
			safety.maxTemperature <= 323.15
		}
	}
	
	requirement <'OC-SYS-001'> oxygenConcentratorSystemRequirement {
		doc /* 
			The oxygen concentrator system shall continuously extract oxygen from ambient air
			using pressure swing adsorption technology and deliver medical-grade concentrated
			oxygen at controlled flow rates to support patients requiring respiratory therapy.
		*/
		
		requirement primaryFunction : PrimaryFunctionRequirement;
		requirement oxygenPurity : OxygenPurityRequirement;
		requirement flowRate : FlowRateRequirement;
		requirement continuousOperation : ContinuousOperationRequirement;
		requirement safetyMonitoring : SafetyMonitoringRequirement;
	}
	
	part concentratorSystem : OxygenConcentrator {
		satisfy oxygenConcentratorSystemRequirement;
	}
}
