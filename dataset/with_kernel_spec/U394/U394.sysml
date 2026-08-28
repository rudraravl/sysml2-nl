package EmergencyMedicalResponse {
	private import ISQ::FrequencyValue;
	private import ISQ::PressureValue;
	private import ISQ::DurationValue;
	private import ScalarValues::String;
	private import ScalarValues::Integer;
	private import ScalarValues::Boolean;
	private import SI::min;

	attribute def DispatchSignal {
		attribute location : String;
		attribute incidentType : String;
		attribute priority : Integer;
	}
	attribute def PatientAssessed {
		attribute severity : String;
	}
	attribute def Stabilized;
	attribute def TransferComplete;
	attribute def CareTransferred;
	attribute def ReturnToStation;
	attribute def HospitalOrders {
		attribute procedure : String;
		attribute authorized : Boolean;
	}

	item def Patient;
	item def MedicalEquipment;
	item def Defibrillator :> MedicalEquipment;
	item def DisposableSupply;
	item def RescueTool;

	item def VitalSigns {
		attribute heartRate : FrequencyValue;
		attribute bloodPressureSystolic : PressureValue;
		attribute bloodPressureDiastolic : PressureValue;
	}

	port def DispatchPort {
		out dispatch : DispatchSignal;
	}
	port def HospitalCommPort {
		in vitals : VitalSigns;
		out orders : HospitalOrders;
	}
	port def SquadCommPort {
		in dispatch : DispatchSignal;
		out vitals : VitalSigns;
		in orders : HospitalOrders;
	}

	part def Paramedic {
		attribute name : String;
		attribute certification : String;
	}
	part def ParamedicCaptain :> Paramedic {
		attribute hasCommandAuthority : Boolean = true;
	}
	part def ParamedicTeam {
		part captain : ParamedicCaptain [1];
		part members : Paramedic [2..*];
	}
	part def RescueVehicle {
		attribute vehicleId : String;
		attribute maxSpeed : Integer;
		part equipment : MedicalEquipment [0..*];
		part defibrillators : Defibrillator [1..*];
		part supplies : DisposableSupply [10..*];
		part rescueTools : RescueTool [3..*];
	}
	part def Squad51 {
		attribute unitName : String = "Squad 51";
		attribute responseTime : DurationValue;
		port dispatchPort : SquadCommPort;
		port hospitalPort : SquadCommPort;
		part team : ParamedicTeam;
		part vehicle : RescueVehicle;
	}
	part def DispatchCenter {
		attribute name : String;
		port squadDispatch : DispatchPort;
	}
	part def BaseHospital {
		attribute name : String = "Rampart General";
		port fieldComm : HospitalCommPort;
	}

	connection def DispatchLink {
		end dispatchCenter : DispatchCenter;
		end squad : Squad51;
	}
	connection def HospitalLink {
		end squad : Squad51;
		end hospital : BaseHospital;
	}

	action respondToScene;
	action assessPatient { out assessment : PatientAssessed; }
	action provideStandardCare;
	action requestAdvancedOrders;
	action provideAdvancedCare;
	action stabilizePatient;
	action transportPatient;
	action transferPatientCare;
	action returnToStationAction;

	state operationalStates {
		in squad : Squad51;
		in dispatch : DispatchCenter;
		in hospital : BaseHospital;

		entry; then inService;

		state inService;
		transition first inService accept d : DispatchSignal then dispatched;

		state dispatched {
			do respondToScene;
		}
		transition first dispatched accept a : PatientAssessed then onScene;

		state onScene {
			do assessPatient;
		}
		transition first onScene accept a : PatientAssessed if a.severity == "standard" do provideStandardCare then stabilizing;
		transition first onScene accept a : PatientAssessed if a.severity == "advanced" do requestAdvancedOrders then awaitingOrders;

		state awaitingOrders {
			do send new VitalSigns() to hospital;
		}
		transition first awaitingOrders accept o : HospitalOrders do provideAdvancedCare then stabilizing;

		state stabilizing {
			do stabilizePatient;
		}
		transition first stabilizing accept Stabilized then transporting;

		state transporting {
			do transportPatient;
		}
		transition first transporting accept TransferComplete then atHospital;

		state atHospital {
			do transferPatientCare;
		}
		transition first atHospital accept CareTransferred then returning;

		state returning {
			do returnToStationAction;
		}
		transition first returning accept ReturnToStation then inService;
	}

	requirement def RapidResponseRequirement {
		subject squad : Squad51;
		constraint { squad.responseTime <= 10 [min] }
	}
	requirement def MinimumCrewRequirement {
		subject team : ParamedicTeam;
		doc /* The paramedic team must include a captain with command authority and at least two paramedics. */
	}
	requirement def EquipmentReadinessRequirement {
		subject vehicle : RescueVehicle;
		doc /* The rescue vehicle must carry at least one defibrillator and adequate supplies. */
	}

	part emergencyResponseSystem {
		part dispatchCenter : DispatchCenter;

		part squad51 : Squad51 {
			part team : ParamedicTeam {
				part captain : ParamedicCaptain {
					:>> name = "Captain Stanley";
					:>> certification = "Paramedic Captain";
				}
			}
			part vehicle : RescueVehicle {
				:>> vehicleId = "Squad51";
				:>> maxSpeed = 120;
				part defibrillators : Defibrillator [2];
				part supplies : DisposableSupply [20];
				part rescueTools : RescueTool [5];
			}
			:>> responseTime = 8 [min];
		}

		part rampartGeneral : BaseHospital;

		connect dispatchCenter.squadDispatch to squad51.dispatchPort;
		connect squad51.hospitalPort to rampartGeneral.fieldComm;

		requirement rapidResponse : RapidResponseRequirement {
			:>> squad = squad51;
		}
		requirement crewReq : MinimumCrewRequirement {
			:>> team = squad51.team;
		}
		requirement equipReq : EquipmentReadinessRequirement {
			:>> vehicle = squad51.vehicle;
		}
	}
}
