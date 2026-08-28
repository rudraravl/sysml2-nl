package MedicalGasDeliverySystem {
	private import ScalarValues::*;
	private import ISQ::*;
	
	package Definitions {
		attribute def PrimaryLowPressureAlert;
		attribute def SecondaryLowPressureAlert;
		attribute def SecondaryActivatedAlert;
		attribute def MaintenanceCompleteSignal;
		
		item def MedicalOxygen;
		
		port def GasOutPort {
			attribute pressure : PressureValue;
			out item gasSupply : MedicalOxygen;
		}
		
		port def GasInPort {
			attribute pressure : PressureValue;
			in item gasSupply : MedicalOxygen;
		}
		
		port def AlarmOutPort {
			out attribute alarmActive : Boolean;
		}
		
		port def AlarmInPort {
			in attribute alarmActive : Boolean;
		}
		
		part def CylinderBank {
			attribute currentPressure : PressureValue;
			attribute lowPressureThreshold : PressureValue;
			attribute criticalPressureThreshold : PressureValue;
			attribute isActive : Boolean default false;
			port gasOutput : GasOutPort;
		}
		
		part def ManifoldController {
			attribute primaryThreshold : PressureValue;
			attribute secondaryThreshold : PressureValue;
			attribute activeSupply : Boolean default true;
			port primaryInput : GasInPort;
			port secondaryInput : GasInPort;
			port regulatorOutput : GasOutPort;
			port switchoverAlarmOut : AlarmOutPort;
			port criticalAlarmOut : AlarmOutPort;
		}
		
		part def PressureRegulator {
			attribute inletPressure : PressureValue;
			attribute outletPressure : PressureValue;
			attribute regulatedSetpoint : PressureValue;
			port highPressureInlet : GasInPort;
			port regulatedOutlet : GasOutPort;
			perform action regulatePressure : RegulatePressure;
		}
		
		part def DistributionPipeline {
			attribute pipelinePressure : PressureValue;
			port supplyInlet : GasInPort;
			port operatingRoomOutlet : GasOutPort;
			port icuOutlet : GasOutPort;
			port emergencyRoomOutlet : GasOutPort;
		}
		
		part def OutletTerminal {
			attribute location : String;
			attribute terminalPressure : PressureValue;
			port gasConnection : GasInPort;
		}
		
		part def AlarmPanel {
			port switchoverAlarmIn : AlarmInPort;
			port criticalAlarmIn : AlarmInPort;
		}
		
		part def MedicalGasSystem {
			attribute nominalCylinderPressure : PressureValue;
			attribute primarySwitchoverThreshold : PressureValue;
			attribute secondaryCriticalThreshold : PressureValue;
			attribute distributionPressure : PressureValue;
			
			part primaryBank : CylinderBank;
			part secondaryBank : CylinderBank;
			part manifoldController : ManifoldController;
			part regulator : PressureRegulator;
			part pipeline : DistributionPipeline;
			part alarmPanel : AlarmPanel;
			part operatingRoomTerminal : OutletTerminal;
			part icuTerminal : OutletTerminal;
			part emergencyRoomTerminal : OutletTerminal;
			
			exhibit state systemControlStates : SystemControlStates;
			exhibit state systemAlarmStates : SystemAlarmStates;
		}
		
		action def MonitorPressure {
			in bank : CylinderBank;
			out measuredPressure : PressureValue;
		}
		
		action def SwitchSupply {
			in fromBank : CylinderBank;
			in toBank : CylinderBank;
		}
		
		action def RegulatePressure {
			in highPressureGas : MedicalOxygen;
			in inletPressure : PressureValue;
			out regulatedGas : MedicalOxygen;
			out outletPressure : PressureValue;
		}
		
		action def IssueAlarm {
			in alarmType : String;
		}
		
		state def SystemControlStates;
		state def SystemAlarmStates;
		
		requirement def ContinuousSupplyRequirement {
			subject system : MedicalGasSystem;
			doc
			/*
			 * The system shall provide continuous supply of medical-grade
			 * oxygen to all patient care areas without interruption.
			 */
		}
		
		requirement def AutomaticSwitchoverRequirement {
			subject system : MedicalGasSystem;
			doc
			/*
			 * The manifold controller shall automatically switch from primary
			 * to secondary bank when primary pressure drops below threshold.
			 */
		}
		
		requirement def RegulatedPressureRequirement {
			subject regulator : PressureRegulator;
			doc
			/*
			 * The pressure regulator shall maintain distribution pressure
			 * at a safe, standardized level for hospital use.
			 */
		}
		
		requirement def AlarmNotificationRequirement {
			subject system : MedicalGasSystem;
			doc
			/*
			 * The alarm panel shall alert staff when switchover occurs
			 * and when secondary bank pressure becomes critically low.
			 */
		}
	}
	
	package Usages {
		private import Definitions::*;
		
		action monitorPrimaryPressure : MonitorPressure;
		action monitorSecondaryPressure : MonitorPressure;
		action switchToSecondary : SwitchSupply;
		action switchToPrimary : SwitchSupply;
		action regulatePressure : RegulatePressure;
		action issueSwitchoverAlarm : IssueAlarm;
		action issueCriticalAlarm : IssueAlarm;
		
		state systemControlStates : SystemControlStates parallel {
			state supplySelectionStates {
				entry; then supplyingFromPrimary;
				
				state supplyingFromPrimary {
					entry action activatePrimary {
						assign medicalGasSystem.primaryBank.isActive := true;
						assign medicalGasSystem.secondaryBank.isActive := false;
					}
					do monitorPrimaryPressure {
						in bank = medicalGasSystem.primaryBank;
						out measuredPressure;
					}
				}
				
				accept when monitorPrimaryPressure.measuredPressure < medicalGasSystem.primarySwitchoverThreshold
					do switchToSecondary {
						in fromBank = medicalGasSystem.primaryBank;
						in toBank = medicalGasSystem.secondaryBank;
					}
					do send new SecondaryActivatedAlert() to medicalGasSystem.alarmPanel
					then supplyingFromSecondary;
				
				state supplyingFromSecondary {
					entry action activateSecondary {
						assign medicalGasSystem.primaryBank.isActive := false;
						assign medicalGasSystem.secondaryBank.isActive := true;
					}
					do monitorSecondaryPressure {
						in bank = medicalGasSystem.secondaryBank;
						out measuredPressure;
					}
				}
				
				accept MaintenanceCompleteSignal
					if medicalGasSystem.primaryBank.currentPressure > medicalGasSystem.primarySwitchoverThreshold
					do switchToPrimary {
						in fromBank = medicalGasSystem.secondaryBank;
						in toBank = medicalGasSystem.primaryBank;
					}
					then supplyingFromPrimary;
			}
			
			state secondaryMonitoringStates {
				entry; then monitoringSecondary;
				
				state monitoringSecondary {
					do monitorSecondaryPressure {
						in bank = medicalGasSystem.secondaryBank;
						out measuredPressure;
					}
				}
				
				accept when monitorSecondaryPressure.measuredPressure < medicalGasSystem.secondaryCriticalThreshold
					do send new SecondaryLowPressureAlert() to medicalGasSystem.alarmPanel
					then criticalLowPressure;
				
				state criticalLowPressure {
					entry issueCriticalAlarm {
						in alarmType = "Critical Low Pressure Emergency";
					}
				}
				
				accept MaintenanceCompleteSignal
					if medicalGasSystem.secondaryBank.currentPressure > medicalGasSystem.secondaryCriticalThreshold
					then monitoringSecondary;
			}
		}
		
		state systemAlarmStates : SystemAlarmStates parallel {
			state switchoverAlarmStates {
				entry; then normal;
				
				state normal;
				
				accept SecondaryActivatedAlert
					then switchoverActive;
				
				state switchoverActive {
					entry issueSwitchoverAlarm {
						in alarmType = "Secondary Bank Active - Replace Primary";
					}
				}
				
				accept MaintenanceCompleteSignal
					then normal;
			}
			
			state criticalAlarmStates {
				entry; then safeLevel;
				
				state safeLevel;
				
				accept SecondaryLowPressureAlert
					then emergencyLevel;
				
				state emergencyLevel {
					entry issueCriticalAlarm {
						in alarmType = "Critical Low Pressure";
					}
				}
				
				accept MaintenanceCompleteSignal
					then safeLevel;
			}
		}
		
		part medicalGasSystem : MedicalGasSystem {
			:>> nominalCylinderPressure = 13800000.0;
			:>> primarySwitchoverThreshold = 2800000.0;
			:>> secondaryCriticalThreshold = 1400000.0;
			:>> distributionPressure = 410000.0;
			
			part primaryBank : CylinderBank {
				:>> currentPressure = 13800000.0;
				:>> lowPressureThreshold = 2800000.0;
				:>> criticalPressureThreshold = 1400000.0;
				:>> isActive = true;
			}
			
			part secondaryBank : CylinderBank {
				:>> currentPressure = 13800000.0;
				:>> lowPressureThreshold = 2800000.0;
				:>> criticalPressureThreshold = 1400000.0;
				:>> isActive = false;
			}
			
			part manifoldController : ManifoldController {
				:>> primaryThreshold = 2800000.0;
				:>> secondaryThreshold = 1400000.0;
				:>> activeSupply = true;
			}
			
			part regulator : PressureRegulator {
				:>> regulatedSetpoint = 410000.0;
			}
			
			part pipeline : DistributionPipeline {
				:>> pipelinePressure = 410000.0;
			}
			
			part operatingRoomTerminal : OutletTerminal {
				:>> location = "Operating Room 1";
			}
			
			part icuTerminal : OutletTerminal {
				:>> location = "ICU Ward 2";
			}
			
			part emergencyRoomTerminal : OutletTerminal {
				:>> location = "Emergency Room Bay 3";
			}
			
			connect primaryBank.gasOutput to manifoldController.primaryInput;
			connect secondaryBank.gasOutput to manifoldController.secondaryInput;
			connect manifoldController.regulatorOutput to regulator.highPressureInlet;
			connect regulator.regulatedOutlet to pipeline.supplyInlet;
			connect pipeline.operatingRoomOutlet to operatingRoomTerminal.gasConnection;
			connect pipeline.icuOutlet to icuTerminal.gasConnection;
			connect pipeline.emergencyRoomOutlet to emergencyRoomTerminal.gasConnection;
			
			bind manifoldController.switchoverAlarmOut.alarmActive = alarmPanel.switchoverAlarmIn.alarmActive;
			bind manifoldController.criticalAlarmOut.alarmActive = alarmPanel.criticalAlarmIn.alarmActive;
		}
		
		requirement continuousSupply : ContinuousSupplyRequirement {
			subject system = medicalGasSystem;
		}
		
		requirement automaticSwitchover : AutomaticSwitchoverRequirement {
			subject system = medicalGasSystem;
		}
		
		requirement regulatedPressure : RegulatedPressureRequirement {
			subject regulator = medicalGasSystem.regulator;
		}
		
		requirement alarmNotification : AlarmNotificationRequirement {
			subject system = medicalGasSystem;
		}
	}
}
