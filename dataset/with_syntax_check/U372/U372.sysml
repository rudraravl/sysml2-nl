package 'SAHRA_Mechanical_Respirator_System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	package 'Domain_Definitions' {
		attribute def TidalVolume :> ISQ::VolumeValue;
		attribute def RespiratoryRate :> ISQ::FrequencyValue;
		attribute def AirwayPressure :> ISQ::PressureValue;
		attribute def FlowRate :> ISQ::VolumeFlowValue;
		attribute def OxygenConcentration :> Real;

		item def MedicalAir;
		item def OxygenEnrichedAir;
		item def ExhaledGas;

		attribute def StartVentilationCmd;
		attribute def StopVentilationCmd;
		attribute def EmergencyStopCmd;
		attribute def AlarmSignal;

		enum def VentilationPhase {
			enum inspiration;
			enum expiration;
			enum hold;
		}
	}

	package 'System_Requirements' {
		import 'Domain_Definitions'::*;

		requirement def FunctionalRequirement;
		requirement def PerformanceRequirement;
		requirement def SafetyRequirement;

		requirement <'SAHRA-REQ-001'> primaryVentilationFunction : FunctionalRequirement {
			doc /* The SAHRA Mechanical Respirator shall provide controlled mechanical ventilation 
			     to support or replace spontaneous breathing in patients with respiratory insufficiency. */
		}

		requirement <'SAHRA-REQ-002'> deliverControlledBreaths : FunctionalRequirement {
			doc /* The system shall deliver breaths with controlled tidal volume, respiratory rate, 
			     and inspiratory/expiratory timing. */
			subject respirator : SAHRARespirator;
		}

		requirement <'SAHRA-REQ-003'> tidalVolumeRange : PerformanceRequirement {
			doc /* The system shall deliver tidal volumes between 200 mL and 800 mL. */
			subject respirator : SAHRARespirator;
			require constraint {
				respirator.tidalVolumeSetting >= 0.0002[m^3] and
				respirator.tidalVolumeSetting <= 0.0008[m^3]
			}
		}

		requirement <'SAHRA-REQ-004'> respiratoryRateRange : PerformanceRequirement {
			doc /* The system shall support respiratory rates between 8 and 30 breaths per minute. */
			subject respirator : SAHRARespirator;
			require constraint {
				respirator.respiratoryRateSetting >= 0.133[Hz] and
				respirator.respiratoryRateSetting <= 0.5[Hz]
			}
		}

		requirement <'SAHRA-REQ-005'> pressureSafetyLimit : SafetyRequirement {
			doc /* The system shall prevent airway pressure from exceeding 40 cmH2O to avoid barotrauma. */
			subject respirator : SAHRARespirator;
			require constraint {
				respirator.currentAirwayPressure <= 3922.6[Pa]
			}
		}

		requirement <'SAHRA-REQ-006'> oxygenConcentrationControl : PerformanceRequirement {
			doc /* The system shall provide adjustable oxygen concentration from 21% to 100%. */
			subject respirator : SAHRARespirator;
			require constraint {
				respirator.oxygenConcentrationSetting >= 0.21 and
				respirator.oxygenConcentrationSetting <= 1.0
			}
		}

		requirement <'SAHRA-REQ-007'> alarmSystem : SafetyRequirement {
			doc /* The system shall activate alarms when pressure limits are exceeded or disconnection is detected. */
		}
	}

	package 'Component_Definitions' {
		import 'Domain_Definitions'::*;

		port def AirIntakePort {
			in item ambientAir : MedicalAir;
		}

		port def OxygenSupplyPort {
			in item oxygenSupply : MedicalAir;
		}

		port def GasDeliveryPort {
			out item deliveredGas : OxygenEnrichedAir;
		}

		port def ExhalationPort {
			in item exhaledGas : ExhaledGas;
			out item ventedGas : ExhaledGas;
		}

		port def PressureMonitorPort {
			out pressureReading : AirwayPressure;
		}

		port def FlowMonitorPort {
			out flowReading : FlowRate;
		}

		part def AirCompressor {
			port airInlet : AirIntakePort;
			port compressedAirOutlet {
				out item compressedAir : MedicalAir;
				out outputPressure : AirwayPressure;
			}
			attribute maxPressure : AirwayPressure;
			attribute compressionRatio : Real;
		}

		part def OxygenBlender {
			port airInput {
				in item compressedAir : MedicalAir;
			}
			port oxygenInput : OxygenSupplyPort;
			port blendedGasOutput {
				out item blendedGas : OxygenEnrichedAir;
				out actualO2Concentration : OxygenConcentration;
			}
			attribute targetO2Concentration : OxygenConcentration;
		}

		part def InspiratoryValve {
			port gasInput {
				in item inputGas : OxygenEnrichedAir;
			}
			port gasOutput : GasDeliveryPort;
			attribute valvePosition : Real;
			attribute isOpen : Boolean;
		}

		part def ExpiratoryValve {
			port gasInput {
				in item exhaledGas : ExhaledGas;
			}
			port gasOutput {
				out item ventedGas : ExhaledGas;
			}
			attribute valvePosition : Real;
			attribute peepSetting : AirwayPressure;
		}

		part def PressureSensor {
			port measurementPoint {
				in item gasFlow : OxygenEnrichedAir;
			}
			port dataOutput : PressureMonitorPort;
			attribute accuracy : Real;
		}

		part def FlowSensor {
			port measurementPoint {
				in item gasFlow : OxygenEnrichedAir;
			}
			port dataOutput : FlowMonitorPort;
			attribute accuracy : Real;
		}

		part def PatientCircuit {
			port ventilatorConnection : GasDeliveryPort;
			port patientConnection {
				out item deliveredBreath : OxygenEnrichedAir;
				in item patientExhalation : ExhaledGas;
			}
			port exhalationConnection : ExhalationPort;
			attribute circuitCompliance : Real;
			attribute circuitResistance : Real;
		}

		part def VentilationController {
			port sensorInputs {
				in pressureData : AirwayPressure;
				in flowData : FlowRate;
			}
			port controlOutputs {
				out inspiratoryValveCmd : Real;
				out expiratoryValveCmd : Real;
				out compressorCmd : Real;
			}
			port userSettings {
				in tidalVolume : TidalVolume;
				in respiratoryRate : RespiratoryRate;
				in oxygenConcentration : OxygenConcentration;
			}
			port alarmOutput {
				out alarmSignal : AlarmSignal;
			}
			attribute currentPhase : VentilationPhase;
			attribute cycleStartTime : ISQ::TimeValue;
		}

		part def AlarmModule {
			port monitoringInputs {
				in pressureMonitor : AirwayPressure;
				in flowMonitor : FlowRate;
			}
			port alarmOutputs {
				out audioAlarm : Boolean;
				out visualAlarm : Boolean;
				out alarmType : Real;
			}
			attribute highPressureLimit : AirwayPressure;
			attribute lowPressureLimit : AirwayPressure;
			attribute disconnectionThreshold : FlowRate;
		}

		action def CompressAmbientAir {
			in ambientAir : MedicalAir;
			in targetPressure : AirwayPressure;
			out compressedAir : MedicalAir;
			out achievedPressure : AirwayPressure;
		}

		action def BlendOxygen {
			in compressedAir : MedicalAir;
			in oxygenSupply : MedicalAir;
			in targetConcentration : OxygenConcentration;
			out blendedGas : OxygenEnrichedAir;
			out actualConcentration : OxygenConcentration;
		}

		action def DeliverInspiration {
			in blendedGas : OxygenEnrichedAir;
			in targetVolume : TidalVolume;
			in inspiratoryTime : ISQ::TimeValue;
			out deliveredVolume : TidalVolume;
			out peakPressure : AirwayPressure;
		}

		action def AllowExpiration {
			in exhaledGas : ExhaledGas;
			in expiratoryTime : ISQ::TimeValue;
			in peepPressure : AirwayPressure;
			out exhaledVolume : TidalVolume;
		}

		action def MonitorPressure {
			in gasStream : OxygenEnrichedAir;
			out pressureReading : AirwayPressure;
		}

		action def MonitorFlow {
			in gasStream : OxygenEnrichedAir;
			out flowReading : FlowRate;
		}

		action def CheckSafetyLimits {
			in currentPressure : AirwayPressure;
			in currentFlow : FlowRate;
			in pressureLimit : AirwayPressure;
			out alarmCondition : Boolean;
			out alarmType : Real;
		}

		action def ControlVentilationCycle {
			in tidalVolume : TidalVolume;
			in respiratoryRate : RespiratoryRate;
			in oxygenConcentration : OxygenConcentration;
			in pressureReading : AirwayPressure;
			in flowReading : FlowRate;
			out inspiratoryValveControl : Real;
			out expiratoryValveControl : Real;
			out compressorControl : Real;
			out currentPhase : VentilationPhase;
		}
	}

	package 'Behavior_Definitions' {
		import 'Domain_Definitions'::*;
		import 'Component_Definitions'::*;

		state def VentilationCycleStateMachine {
			attribute tidalVolumeSetting : TidalVolume;
			attribute respiratoryRateSetting : RespiratoryRate;
			attribute inspiratoryTime : ISQ::TimeValue;
			attribute expiratoryTime : ISQ::TimeValue;
			attribute currentPressure : AirwayPressure;
			attribute pressureLimit : AirwayPressure;
			attribute currentPhase : VentilationPhase;
			attribute alarmActive : Boolean;

			initial state Standby;

			state Inspiration {
				entry assign currentPhase := VentilationPhase::inspiration;
			}

			state Expiration {
				entry assign currentPhase := VentilationPhase::expiration;
			}

			state Alarm {
				entry assign alarmActive := true;
			}

			transition standbyToInspiration
				first Standby
				accept startCmd : StartVentilationCmd
				then Inspiration;

			transition inspirationToExpiration
				first Inspiration
				then Expiration;

			transition expirationToInspiration
				first Expiration
				then Inspiration;

			transition toAlarm
				first Inspiration
				then Alarm;

			transition alarmToStandby
				first Alarm
				accept stopCmd : StopVentilationCmd
				then Standby;

			transition emergencyStop
				accept emergencyCmd : EmergencyStopCmd
				then Standby;
		}

		action def ProvideMechanicalVentilation {
			in tidalVolume : TidalVolume;
			in respiratoryRate : RespiratoryRate;
			in oxygenConcentration : OxygenConcentration;
			out ventilationStatus : Real;

			first start;
			then action initializeSystem {
				action performSelfTest;
				then action calibrateSensors;
			}
			then merge ventilationLoop;

			action ventilationLoop {
				action compressAir : CompressAmbientAir {
					in targetPressure : AirwayPressure;
					out compressedAir;
					out achievedPressure;
				}

				flow compressAir.compressedAir to blendOxygen.compressedAir;

				action blendOxygen : BlendOxygen {
					in targetConcentration = oxygenConcentration;
					out blendedGas;
					out actualConcentration;
				}

				flow blendOxygen.blendedGas to monitorPressure.gasStream;

				action monitorPressure : MonitorPressure {
					out pressureReading;
				}

				action monitorFlow : MonitorFlow {
					out flowReading;
				}

				flow monitorPressure.pressureReading to controlCycle.pressureReading;
				flow monitorFlow.flowReading to controlCycle.flowReading;

				action controlCycle : ControlVentilationCycle {
					in tidalVolume = tidalVolume;
					in respiratoryRate = respiratoryRate;
					in oxygenConcentration = oxygenConcentration;
					out inspiratoryValveControl;
					out expiratoryValveControl;
					out compressorControl;
					out currentPhase;
				}

				action deliverInspiration : DeliverInspiration {
					in blendedGas = blendOxygen.blendedGas;
					in inspiratoryTime : ISQ::TimeValue;
					out deliveredVolume;
					out peakPressure;
				}

				flow deliverInspiration.peakPressure to checkSafety.currentPressure;

				action checkSafety : CheckSafetyLimits {
					in currentPressure;
					in currentFlow = monitorFlow.flowReading;
					in pressureLimit : AirwayPressure;
					out alarmCondition;
					out alarmType;
				}

				then decide;
					if checkSafety.alarmCondition then handleAlarm;
					if not checkSafety.alarmCondition then allowExpiration;

				action allowExpiration : AllowExpiration {
					in expiratoryTime : ISQ::TimeValue;
					in peepPressure : AirwayPressure;
					out exhaledVolume;
				}

				then ventilationLoop;

				action handleAlarm {
					action activateAlarm;
					then action enterSafeMode;
					then done;
				}
			}
		}
	}

	package 'System_Implementation' {
		import 'Domain_Definitions'::*;
		import 'Component_Definitions'::*;
		import 'Behavior_Definitions'::*;
		import 'System_Requirements'::*;

		part def SAHRARespirator {
			doc /* SAHRA (Simple Affordable High-quality Respirator for All) Mechanical Respirator System.
			     Provides controlled mechanical ventilation for patients with respiratory insufficiency. */

			satisfy primaryVentilationFunction;
			satisfy deliverControlledBreaths;
			satisfy tidalVolumeRange;
			satisfy respiratoryRateRange;
			satisfy pressureSafetyLimit;
			satisfy oxygenConcentrationControl;
			satisfy alarmSystem;

			attribute tidalVolumeSetting : TidalVolume = 0.0005[m^3];
			attribute respiratoryRateSetting : RespiratoryRate = 0.25[Hz];
			attribute oxygenConcentrationSetting : OxygenConcentration = 0.5;
			attribute currentAirwayPressure : AirwayPressure;
			attribute currentFlowRate : FlowRate;

			port ambientAirIntake : AirIntakePort;
			port oxygenSupply : OxygenSupplyPort;
			port patientInterface {
				out item deliveredBreath : OxygenEnrichedAir;
				in item patientExhalation : ExhaledGas;
			}

			part compressor : AirCompressor {
				attribute :>> maxPressure = 4903.25[Pa];
				attribute :>> compressionRatio = 3.5;
			}

			part blender : OxygenBlender {
				attribute :>> targetO2Concentration = oxygenConcentrationSetting;
			}

			part inspiratoryValve : InspiratoryValve {
				attribute :>> isOpen = false;
			}

			part expiratoryValve : ExpiratoryValve {
				attribute :>> peepSetting = 490.325[Pa];
			}

			part pressureSensor : PressureSensor {
				attribute :>> accuracy = 0.02;
			}

			part flowSensor : FlowSensor {
				attribute :>> accuracy = 0.05;
			}

			part patientCircuit : PatientCircuit {
				attribute :>> circuitCompliance = 0.002;
				attribute :>> circuitResistance = 5.0;
			}

			part controller : VentilationController {
				attribute :>> currentPhase = VentilationPhase::expiration;
			}

			part alarmModule : AlarmModule {
				attribute :>> highPressureLimit = 3922.6[Pa];
				attribute :>> lowPressureLimit = 196.13[Pa];
			}

			connection airSupply connect ambientAirIntake to compressor.airInlet;
			connection compressedAirToBlender connect compressor.compressedAirOutlet to blender.airInput;
			connection oxygenToBlender connect oxygenSupply to blender.oxygenInput;
			connection blendedGasToValve connect blender.blendedGasOutput to inspiratoryValve.gasInput;
			connection valveToCircuit connect inspiratoryValve.gasOutput to patientCircuit.ventilatorConnection;
			connection circuitToPatient connect patientCircuit.patientConnection to patientInterface;
			connection exhalationPath connect patientCircuit.exhalationConnection to expiratoryValve.gasInput;

			connection pressureMonitoring connect patientCircuit.ventilatorConnection to pressureSensor.measurementPoint;
			connection flowMonitoring connect patientCircuit.ventilatorConnection to flowSensor.measurementPoint;

			connection pressureToController connect pressureSensor.dataOutput to controller.sensorInputs;
			connection flowToController connect flowSensor.dataOutput to controller.sensorInputs;

			connection pressureToAlarm connect pressureSensor.dataOutput to alarmModule.monitoringInputs;
			connection flowToAlarm connect flowSensor.dataOutput to alarmModule.monitoringInputs;

			bind currentAirwayPressure = pressureSensor.dataOutput.pressureReading;
			bind currentFlowRate = flowSensor.dataOutput.flowReading;

			perform action provideMechanicalVentilation : ProvideMechanicalVentilation {
				in tidalVolume = tidalVolumeSetting;
				in respiratoryRate = respiratoryRateSetting;
				in oxygenConcentration = oxygenConcentrationSetting;
				out ventilationStatus;
			}

			exhibit state ventilationCycle : VentilationCycleStateMachine {
				:>> tidalVolumeSetting = tidalVolumeSetting;
				:>> respiratoryRateSetting = respiratoryRateSetting;
				:>> currentPressure = currentAirwayPressure;
				:>> pressureLimit = 3922.6[Pa];
			}
		}

		part sahraRespirator : SAHRARespirator {
			doc /* Instance of the SAHRA Mechanical Respirator configured for standard adult ventilation. */
		}
	}
}
