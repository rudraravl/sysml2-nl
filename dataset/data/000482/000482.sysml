package 'Organ Care System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def SystemMode;
	attribute def OrganType;
	attribute def ViabilityStatus;
	attribute def AlarmCondition;
	
	attribute def TemperatureSetpoint {
		attribute nominal : TemperatureValue;
		attribute tolerance : TemperatureValue;
	}
	
	attribute def PressureSetpoint {
		attribute nominal : PressureValue;
		attribute tolerance : PressureValue;
	}
	
	attribute def FlowSetpoint {
		attribute nominal : VolumeFlowRateValue;
		attribute tolerance : VolumeFlowRateValue;
	}
	
	item def PreservationSolution {
		attribute oxygenSaturation : Real;
		attribute nutrientLevel : Real;
		attribute temperature : TemperatureValue;
		attribute pH : Real;
	}
	
	item def DonorOrgan {
		attribute organType : OrganType;
		attribute viabilityScore : Real;
		attribute ischemicTime : DurationValue;
		attribute metabolicActivity : Real;
	}
	
	port def FluidInterfacePort {
		in flowRateIn : VolumeFlowRateValue;
		in pressureIn : PressureValue;
		in temperatureIn : TemperatureValue;
		out flowRateOut : VolumeFlowRateValue;
		out pressureOut : PressureValue;
		out temperatureOut : TemperatureValue;
	}
	
	port def SensorDataPort {
		out temperature : TemperatureValue;
		out pressure : PressureValue;
		out flowRate : VolumeFlowRateValue;
		out oxygenLevel : Real;
		out lactateLevel : Real;
	}
	
	port def ControlCommandPort {
		in targetTemperature : TemperatureValue;
		in targetPressure : PressureValue;
		in targetFlowRate : VolumeFlowRateValue;
		out actualTemperature : TemperatureValue;
		out actualPressure : PressureValue;
		out actualFlowRate : VolumeFlowRateValue;
	}
	
	attribute def SystemStartSignal;
	attribute def PrimingCompleteSignal;
	attribute def StabilizationAchievedSignal;
	attribute def CriticalParameterSignal;
	attribute def ParameterNormalizedSignal;
	attribute def TransportCompleteSignal;
	
	part def FluidReservoir {
		port outlet : FluidInterfacePort;
		attribute capacity : VolumeValue;
		attribute currentLevel : VolumeValue;
		ref item solution : PreservationSolution;
		
		action dispenseSolution {
			in requestedVolume : VolumeValue;
			out deliveredVolume : VolumeValue;
		}
	}
	
	part def CirculationPump {
		port inlet : FluidInterfacePort;
		port outlet : FluidInterfacePort;
		port control : ControlCommandPort;
		attribute pumpSpeed : Real;
		attribute efficiency : Real;
		
		action circulateFluid {
			in commandedFlow : VolumeFlowRateValue;
			in inletPressure : PressureValue;
			out outletPressure : PressureValue;
			out actualFlow : VolumeFlowRateValue;
		}
	}
	
	part def OxygenationModule {
		port fluidIn : FluidInterfacePort;
		port fluidOut : FluidInterfacePort;
		attribute oxygenSupply : VolumeFlowRateValue;
		attribute membraneArea : AreaValue;
		attribute transferEfficiency : Real;
		
		action oxygenate {
			in inflowRate : VolumeFlowRateValue;
			in currentSaturation : Real;
			out targetSaturation : Real;
			out outflowRate : VolumeFlowRateValue;
		}
	}
	
	part def ThermalRegulator {
		port fluidIn : FluidInterfacePort;
		port fluidOut : FluidInterfacePort;
		port control : ControlCommandPort;
		attribute heatingPower : PowerValue;
		attribute coolingPower : PowerValue;
		
		action regulateTemperature {
			in inletTemp : TemperatureValue;
			in targetTemp : TemperatureValue;
			out outletTemp : TemperatureValue;
			out powerUsed : PowerValue;
		}
	}
	
	part def PerfusionChamber {
		port fluidInlet : FluidInterfacePort;
		port fluidOutlet : FluidInterfacePort;
		port monitoring : SensorDataPort;
		attribute chamberVolume : VolumeValue;
		attribute internalPressure : PressureValue;
		ref item organ : DonorOrgan;
		
		action perfuseOrgan {
			in solution : PreservationSolution;
			in flowRate : VolumeFlowRateValue;
			in organ : DonorOrgan;
			out perfusedOrgan : DonorOrgan;
			out metabolicWaste : Real;
		}
	}
	
	part def BioSensorArray {
		port sensorOutput : SensorDataPort;
		attribute samplingRate : Real;
		attribute calibrationStatus : Boolean;
		
		action measureParameters {
			in solutionSample : PreservationSolution;
			out temperature : TemperatureValue;
			out pressure : PressureValue;
			out oxygenLevel : Real;
			out lactateLevel : Real;
		}
	}
	
	part def ControlProcessor {
		port sensorInput : SensorDataPort[*];
		port pumpControl : ControlCommandPort;
		port thermalControl : ControlCommandPort;
		attribute controlAlgorithm : String;
		
		action processData {
			in sensorReadings : SensorDataPort;
			out pumpCommand : ControlCommandPort;
			out thermalCommand : ControlCommandPort;
			out systemStatus : ViabilityStatus;
		}
		
		state controlStateMachine {
			entry action initializeController;
			
			state idle;
			state priming;
			state activePerfusion;
			state monitoring;
			state alarm;
			state shutdown;
			
			transition idle_to_priming
				first idle
				accept systemStart : SystemStartSignal
				then priming;
			
			transition priming_to_active
				first priming
				accept primingComplete : PrimingCompleteSignal
				then activePerfusion;
			
			transition active_to_monitoring
				first activePerfusion
				accept stabilizationAchieved : StabilizationAchievedSignal
				then monitoring;
			
			transition monitoring_to_alarm
				first monitoring
				accept criticalParameter : CriticalParameterSignal
				then alarm;
			
			transition alarm_to_monitoring
				first alarm
				accept parameterNormalized : ParameterNormalizedSignal
				then monitoring;
			
			transition monitoring_to_shutdown
				first monitoring
				accept transportComplete : TransportCompleteSignal
				then shutdown;
		}
	}
	
	part def UserInterface {
		attribute displayMode : String;
		attribute alarmActive : Boolean;
		
		action displayStatus {
			in systemData : ViabilityStatus;
			out userNotification : String;
		}
		
		action handleAlarm {
			in alarmCondition : AlarmCondition;
			out alarmResponse : String;
		}
	}
	
	part def OrganCareSystem {
		attribute operationalMode : SystemMode;
		attribute totalRuntime : DurationValue;
		attribute targetOrganType : OrganType;
		
		part reservoir : FluidReservoir {
			attribute capacity = 3.0 [L];
			attribute currentLevel = 2.5 [L];
		}
		
		part pump : CirculationPump {
			attribute efficiency = 0.92;
		}
		
		part oxygenator : OxygenationModule {
			attribute transferEfficiency = 0.95;
			attribute membraneArea = 0.5 [m^2];
		}
		
		part thermalUnit : ThermalRegulator {
			attribute heatingPower = 200.0 [W];
			attribute coolingPower = 200.0 [W];
		}
		
		part chamber : PerfusionChamber {
			attribute chamberVolume = 0.5 [L];
		}
		
		part sensors : BioSensorArray {
			attribute samplingRate = 1.0;
			attribute calibrationStatus = true;
		}
		
		part controller : ControlProcessor {
			attribute controlAlgorithm = "PID";
		}
		
		part userInterface : UserInterface {
			attribute displayMode = "normal";
			attribute alarmActive = false;
		}
		
		connection fluidPath1 connect reservoir.outlet to pump.inlet;
		connection fluidPath2 connect pump.outlet to oxygenator.fluidIn;
		connection fluidPath3 connect oxygenator.fluidOut to thermalUnit.fluidIn;
		connection fluidPath4 connect thermalUnit.fluidOut to chamber.fluidInlet;
		connection fluidPath5 connect chamber.fluidOutlet to reservoir.outlet;
		
		connection sensorLink connect chamber.monitoring to sensors.sensorOutput;
		connection dataLink connect sensors.sensorOutput to controller.sensorInput;
		connection pumpControlLink connect controller.pumpControl to pump.control;
		connection thermalControlLink connect controller.thermalControl to thermalUnit.control;
		
		perform action maintainOrganViability {
			first start;
			
			then action initializeSystem {
				action loadOrgan;
				then action fillCircuit;
				then action calibrateSensors;
				then action primePump;
			}
			
			then merge continuousPerfusion;
			
			then action perfusionCycle {
				action pumpOperation : pump.circulateFluid {
					in commandedFlow = 300.0 [mL/min];
					in inletPressure;
					out outletPressure;
					out actualFlow;
				}
				
				flow pumpOperation.actualFlow to oxygenation.inflowRate;
				
				action oxygenation : oxygenator.oxygenate {
					in inflowRate;
					in currentSaturation;
					out targetSaturation = 0.98;
					out outflowRate;
				}
				
				flow oxygenation.outflowRate to temperatureControl.inletTemp;
				
				action temperatureControl : thermalUnit.regulateTemperature {
					in inletTemp;
					in targetTemp = 277.15 [K];
					out outletTemp;
					out powerUsed;
				}
				
				flow temperatureControl.outletTemp to organPerfusion.solution;
				
				action organPerfusion : chamber.perfuseOrgan {
					in solution;
					in flowRate = pumpOperation.actualFlow;
					in organ;
					out perfusedOrgan;
					out metabolicWaste;
				}
			}
			
			then action monitoringCycle : sensors.measureParameters {
				in solutionSample;
				out temperature;
				out pressure;
				out oxygenLevel;
				out lactateLevel;
			}
			
			then action controlCycle : controller.processData {
				in sensorReadings;
				out pumpCommand;
				out thermalCommand;
				out systemStatus;
			}
			
			then decide;
				if controlCycle.systemStatus == "optimal" then continuousPerfusion;
				if controlCycle.systemStatus == "suboptimal" then adjustParameters;
				if controlCycle.systemStatus == "critical" then emergencyProtocol;
			
			action adjustParameters {
				action modifyFlowRate;
				then action modifyTemperature;
				then action modifyOxygenation;
			}
			then continuousPerfusion;
			
			action emergencyProtocol {
				action raiseAlarm;
				then action stabilizeConditions;
			}
			then decide;
				if stabilizeConditions == "successful" then continuousPerfusion;
				if stabilizeConditions == "failed" then safeShutdown;
			
			action safeShutdown;
			then done;
		}
	}
	
	part organCareSystem : OrganCareSystem;
	
	requirement def OrganPreservationRequirement {
		doc /* The system shall preserve donor organ viability during ex vivo transport. */
		subject ocs : OrganCareSystem;
		require constraint preservationDuration {
			ocs.totalRuntime >= 8.0 [h]
		}
	}
	
	requirement def TemperatureMaintenanceRequirement {
		doc /* The system shall maintain organ temperature within hypothermic range. */
		subject thermal : ThermalRegulator;
		require constraint temperatureBounds {
			thermal.regulateTemperature.outletTemp >= 275.15 [K] and
			thermal.regulateTemperature.outletTemp <= 279.15 [K]
		}
	}
	
	requirement def PerfusionFlowRequirement {
		doc /* The system shall maintain continuous perfusion flow within physiological range. */
		subject pumpSys : CirculationPump;
		require constraint flowBounds {
			pumpSys.circulateFluid.actualFlow >= 250.0 [mL/min] and
			pumpSys.circulateFluid.actualFlow <= 350.0 [mL/min]
		}
	}
	
	requirement def OxygenationRequirement {
		doc /* The system shall maintain preservation solution oxygen saturation above threshold. */
		subject oxygenSys : OxygenationModule;
		require constraint oxygenSaturation {
			oxygenSys.oxygenate.targetSaturation >= 0.95
		}
	}
	
	requirement def MonitoringRequirement {
		doc /* The system shall continuously monitor critical organ parameters. */
		subject sensorSys : BioSensorArray;
		require constraint continuousMonitoring {
			sensorSys.samplingRate >= 0.5 and
			sensorSys.calibrationStatus == true
		}
	}
	
	requirement systemLevelRequirements {
		doc /* Top-level requirements for organ care system ensuring safe transport and preservation. */
		require preservationReq : OrganPreservationRequirement;
		require tempReq : TemperatureMaintenanceRequirement;
		require flowReq : PerfusionFlowRequirement;
		require oxygenReq : OxygenationRequirement;
		require monitorReq : MonitoringRequirement;
	}
}
