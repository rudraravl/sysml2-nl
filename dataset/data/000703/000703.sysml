package NasalEPAPSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def RespiratoryPhase {
		attribute isInhalation : Boolean;
		attribute isExhalation : Boolean;
	}
	
	item def Airflow {
		attribute pressure : ISQ::PressureValue;
		attribute flowRate : ISQ::VolumeFlowValue;
		attribute phase : RespiratoryPhase;
	}
	
	item def PressureSetpoint {
		attribute targetEPAP : ISQ::PressureValue;
		attribute tolerance : ISQ::PressureValue;
	}
	
	port def AirflowPort {
		inout airstream : Airflow;
	}
	
	port def ControlPort {
		in setpoint : PressureSetpoint;
		out measuredPressure : ISQ::PressureValue;
	}
	
	part def RespiratoryMonitor {
		port airwayPort : AirflowPort;
		attribute currentPhase : RespiratoryPhase;
		attribute measuredPressure : ISQ::PressureValue;
		
		action def DetectBreathingPhase {
			in airstream : Airflow;
			out phase : RespiratoryPhase;
			out pressure : ISQ::PressureValue;
		}
	}
	
	part def ExpiratoryValve {
		port inletPort : AirflowPort;
		port outletPort : AirflowPort;
		attribute valveResistance : Real;
		attribute isRestricted : Boolean;
		
		action def OpenValve {
			out result : Boolean;
		}
		
		action def RestrictValve {
			out result : Boolean;
		}
	}
	
	part def NasalInterface {
		port devicePort : AirflowPort;
		port patientPort : AirflowPort;
		attribute sealEfficiency : Real;
		
		action def TransferAirflow {
			in deviceAir : Airflow;
			out patientAir : Airflow;
		}
	}
	
	part def PressureRegulator {
		port controlPort : ControlPort;
		attribute targetPressure : ISQ::PressureValue;
		attribute currentPressure : ISQ::PressureValue;
		
		action def RegulateEPAP {
			in setpoint : PressureSetpoint;
			in measured : ISQ::PressureValue;
			out adjustment : Real;
		}
	}
	
	part def SafetyMonitor {
		attribute maxPressure : ISQ::PressureValue;
		attribute minPressure : ISQ::PressureValue;
		attribute alarmActive : Boolean;
		
		action def CheckSafetyLimits {
			in currentPressure : ISQ::PressureValue;
			out withinLimits : Boolean;
			out alarmState : Boolean;
		}
	}
	
	part def Patient {
		port nasalAirway : AirflowPort;
		attribute breathingRate : Real;
		attribute airwayResistance : Real;
	}
	
	part def NasalEPAPDevice {
		part monitor : RespiratoryMonitor {
			perform epapTherapy.monitorBreathing;
		}
		
		part valve : ExpiratoryValve {
			perform epapTherapy.controlValve;
		}
		
		part interface : NasalInterface {
			perform epapTherapy.deliverAir;
		}
		
		part regulator : PressureRegulator {
			perform epapTherapy.regulatePressure;
		}
		
		part safety : SafetyMonitor {
			perform epapTherapy.monitorSafety;
		}
		
		connection monitorToValve connect monitor.airwayPort to valve.inletPort;
		connection valveToInterface connect valve.outletPort to interface.devicePort;
		
		perform action epapTherapy {
			first start;
			then merge continuousTherapy;
			
			action monitorBreathing : RespiratoryMonitor::DetectBreathingPhase {
				in airstream;
				out breathPhase : RespiratoryPhase;
				out airwayPressure : ISQ::PressureValue;
			}
			
			then action regulatePressure : PressureRegulator::RegulateEPAP {
				in setpoint;
				in measured = monitorBreathing.airwayPressure;
				out pressureAdjustment : Real;
			}
			
			then decide;
				if monitorBreathing.breathPhase.isExhalation then applyEPAP;
				if monitorBreathing.breathPhase.isInhalation then allowInhalation;
			
			action applyEPAP {
				doc /* During exhalation, valve restricts airflow to create positive pressure. */
			}
			then action controlValve : ExpiratoryValve::RestrictValve {
				out valveResult : Boolean;
			}
			then continuousTherapy;
			
			action allowInhalation {
				doc /* During inhalation, valve opens to minimize resistance. */
			}
			then action openValve : ExpiratoryValve::OpenValve {
				out valveResult : Boolean;
			}
			then continuousTherapy;
			
			action deliverAir : NasalInterface::TransferAirflow {
				in deviceAir;
				out patientAir;
			}
			
			action monitorSafety : SafetyMonitor::CheckSafetyLimits {
				in currentPressure = monitorBreathing.airwayPressure;
				out safetyStatus : Boolean;
				out alarm : Boolean;
			}
			
			then decide;
				if monitorSafety.safetyStatus == false then emergencyShutdown;
				if monitorSafety.safetyStatus == true then continuousTherapy;
			
			action emergencyShutdown {
				doc /* Terminate therapy if pressure exceeds safety limits. */
			}
			then done;
		}
	}
	
	part nasalEPAPSystem {
		part device : NasalEPAPDevice;
		part patient : Patient;
		
		connection deviceToPatient connect device.interface.patientPort to patient.nasalAirway;
	}
	
	requirement def TherapeuticRequirement;
	requirement def SafetyRequirement;
	requirement def PerformanceRequirement;
	
	requirement <'REQ-001'> maintainPositiveExpiratoryPressure : TherapeuticRequirement {
		doc /* The Nasal EPAP system shall maintain positive airway pressure during 
		     exhalation to prevent upper airway collapse and treat obstructive sleep apnea. */
		
		subject device : NasalEPAPDevice;
	}
	
	requirement <'REQ-002'> minimizeInspiratoryResistance : PerformanceRequirement {
		doc /* The system shall provide minimal resistance during inhalation to ensure 
		     patient comfort and natural breathing. */
		
		subject device : NasalEPAPDevice;
		refine maintainPositiveExpiratoryPressure;
	}
	
	requirement <'REQ-003'> ensurePatientSafety : SafetyRequirement {
		doc /* The system shall monitor airway pressure continuously and prevent 
		     excessive pressure that could cause discomfort or injury. */
		
		subject device : NasalEPAPDevice;
	}
	
	requirement <'REQ-004'> provideEPAPTherapy {
		doc /* The Nasal EPAP system shall deliver expiratory positive airway pressure 
		     therapy by creating controlled resistance during exhalation while allowing 
		     unrestricted inhalation, thereby maintaining upper airway patency throughout 
		     the respiratory cycle. */
		
		subject system : nasalEPAPSystem;
		
		assume constraint patientBreathing {
			doc /* Patient maintains spontaneous breathing with regular respiratory cycles. */
		}
		
		require maintainPositiveExpiratoryPressure;
		require minimizeInspiratoryResistance;
		require ensurePatientSafety;
		
		satisfy by device.epapTherapy;
	}
}
