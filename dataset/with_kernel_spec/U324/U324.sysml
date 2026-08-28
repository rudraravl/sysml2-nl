package NasopharyngealAirwaySystem {
	private import ScalarValues::*;
	private import SI::*;
	private import ISQ::*;

	item def Air;
	item def Lubricant {
		attribute type : String = "water-based";
	}

	occurrence def DevicePrepared;
	occurrence def DeviceInserted;
	occurrence def PatencyConfirmed;
	occurrence def DeviceRemoved;

	port def AirPort {
		item air : Air;
	}

	port def MonitoringPort {
		attribute oxygenSaturation : Real;
	}

	part def Tube;
	part def Flange;

	part def NasopharyngealAirway {
		attribute material : String = "medical-grade silicone";
		attribute length : ISQ::Length;
		attribute diameter : ISQ::Length;

		part tube : Tube {
			attribute tipType : String = "beveled";
		}
		part flange : Flange {
			attribute shape : String = "flared";
		}

		port airIn : AirPort;
		port airOut : AirPort;
		port monitorOut : MonitoringPort;
		flow airFlow : Air from airIn to airOut;

		state def Operation {
			state stored;
			accept DevicePrepared then prepared;
			state prepared;
			accept DeviceInserted then inserted;
			state inserted;
			accept PatencyConfirmed then functioning;
			state functioning;
			accept DeviceRemoved then removed;
			state removed;
		}
		perform op : Operation;
	}

	part def Patient {
		attribute oxygenSaturation : Real;
		port nostril : AirPort;
		port pharynx : AirPort;
		port lungs : AirPort;
		port monitorIn : MonitoringPort;
		flow airway : Air from nostril to lungs;
	}

	part def Caregiver {
		action assessPatient;
		action selectDevice;
		action prepareDevice;
		action insertDevice;
		action monitorPatient;
		action removeDevice;
	}

	connection def AirFlowLink {
		end source : AirPort;
		end target : AirPort;
	}

	connection def MonitoringLink {
		end source : MonitoringPort;
		end target : MonitoringPort;
	}

	action def NPAProcedure {
		part caregiver : Caregiver;
		part device : NasopharyngealAirway;
		ref part patient : Patient;

		action assess { perform caregiver.assessPatient; }
		action prepare { perform caregiver.prepareDevice; }
		action insert { perform caregiver.insertDevice; }
		action monitor { perform caregiver.monitorPatient; }
		action remove { perform caregiver.removeDevice; }
	}

	requirement def MaintainAirwayPatency {
		subject device : NasopharyngealAirway;
		ref part patient : Patient;
		requirement {
			doc /* The NPA shall bypass upper airway obstruction caused by the tongue and maintain an open airway. */
		}
	}

	requirement def PreventOverInsertion {
		subject device : NasopharyngealAirway;
		requirement {
			doc /* The flange shall prevent over-insertion into the airway and rest securely against the nostril. */
		}
	}

	requirement def CorrectSizing {
		subject caregiver : Caregiver;
		requirement {
			doc /* The caregiver shall assess the patient and select the appropriate size to ensure effective airway management. */
		}
	}

	part npaSystem {
		part device : NasopharyngealAirway;
		ref part patient : Patient;
		part caregiver : Caregiver;

		connection externalAir : AirFlowLink connect device.airIn to patient.nostril;
		connection internalAir : AirFlowLink connect device.airOut to patient.pharynx;
		connection patientAirway : AirFlowLink connect patient.pharynx to patient.lungs;
		connection monitorConn : MonitoringLink connect device.monitorOut to patient.monitorIn;

		perform procedure : NPAProcedure {
			caregiver :> caregiver;
			device :> device;
			patient :> patient;
		}

		satisfy MaintainAirwayPatency by device;
		satisfy PreventOverInsertion by device.flange;
		satisfy CorrectSizing by caregiver;
	}
}
