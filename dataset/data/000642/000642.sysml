package 'InhalerSpacerSystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	attribute def ParticleDiameter :> ISQ::LengthValue;
	attribute def DrugMass :> ISQ::MassValue;
	attribute def AirVolume :> ISQ::VolumeValue;
	attribute def InhalationFlowRate :> ISQ::VolumeValue;
	attribute def ResidenceTime :> ISQ::TimeValue;
	attribute def DepositionEfficiency :> Real;

	item def MedicationAerosol {
		attribute particleSize : ParticleDiameter;
		attribute drugDose : DrugMass;
		attribute velocity : ISQ::SpeedValue;
		attribute concentration : Real;
	}

	item def InhaledAir {
		attribute flowRate : InhalationFlowRate;
		attribute volume : AirVolume;
		attribute pressure : ISQ::PressureValue;
	}

	item def ExhaledAir {
		attribute volume : AirVolume;
		attribute humidity : Real;
	}

	port def AerosolInletPort {
		in item aerosolIn : MedicationAerosol;
	}

	port def AerosolOutletPort {
		out item aerosolOut : MedicationAerosol;
	}

	port def PatientInterfacePort {
		out item deliveredAerosol : MedicationAerosol;
		in item inhaledAir : InhaledAir;
		out item exhaledAir : ExhaledAir;
	}

	part def MeteredDoseInhaler {
		attribute canisterPressure : ISQ::PressureValue;
		attribute nominalDose : DrugMass;
		attribute actuationForce : ISQ::ForceValue;
		port nozzle : AerosolOutletPort;
	}

	part def SpacerChamber {
		attribute chamberVolume : AirVolume;
		attribute wallMaterial : String;
		attribute electrostaticCharge : Real;
		port inlet : AerosolInletPort;
		port outlet : AerosolOutletPort;
	}

	part def OneWayInspValve {
		attribute crackingPressure : ISQ::PressureValue;
		attribute flowResistance : Real;
		port upstream : AerosolInletPort;
		port downstream : AerosolOutletPort;
	}

	part def OneWayExpValve {
		attribute crackingPressure : ISQ::PressureValue;
		port inletSide : AerosolInletPort;
		port exhaustSide : AerosolOutletPort;
	}

	part def Mouthpiece {
		attribute innerDiameter : ISQ::LengthValue;
		attribute lipSealQuality : Real;
		port valveConnection : AerosolInletPort;
		port patientConnection : PatientInterfacePort;
	}

	part def InhalerSpacerAssembly {
		part mdi : MeteredDoseInhaler;
		part chamber : SpacerChamber {
			attribute :>> chamberVolume = 150.0;
		}
		part inspiratoryValve : OneWayInspValve {
			attribute :>> crackingPressure = 0.5;
		}
		part expiratoryValve : OneWayExpValve {
			attribute :>> crackingPressure = 1.0;
		}
		part mouthpiece : Mouthpiece;

		connect mdi.nozzle to chamber.inlet;
		connect chamber.outlet to inspiratoryValve.upstream;
		connect inspiratoryValve.downstream to mouthpiece.valveConnection;
		connect mouthpiece.patientConnection to expiratoryValve.inletSide;

		perform action deliverMedication;
	}

	action def ActuateInhaler {
		in attribute actuationForce : ISQ::ForceValue;
		out aerosol : MedicationAerosol;
	}

	action def SuspendAerosol {
		in aerosol : MedicationAerosol;
		in chamberVolume : AirVolume;
		in residenceTime : ResidenceTime;
		out suspendedAerosol : MedicationAerosol;
	}

	action def OpenInspiratoryValve {
		in inhalationFlow : InhalationFlowRate;
		in crackingPressure : ISQ::PressureValue;
		out valveOpen : Boolean;
	}

	action def InhaleAerosol {
		in suspendedAerosol : MedicationAerosol;
		in inhalationFlow : InhalationFlowRate;
		in inhalationVolume : AirVolume;
		out deliveredDose : DrugMass;
		out depositionEfficiency : DepositionEfficiency;
	}

	action def HoldBreath {
		in duration : ResidenceTime;
	}

	action def ExhaleThroughValve {
		in exhaledVolume : AirVolume;
		out exhaledAir : ExhaledAir;
	}

	action def DeliverMedication {
		doc /* Primary function: Coordinate actuation, suspension, and inhalation to deliver medication efficiently to patient lungs */
		
		in attribute targetDose : DrugMass;
		in attribute breathHoldDuration : ResidenceTime;
		out attribute actualDeliveredDose : DrugMass;
		out attribute efficiency : DepositionEfficiency;

		first start;

		then action actuate : ActuateInhaler {
			in actuationForce = 30.0;
			out aerosol;
		}

		then action suspend : SuspendAerosol {
			in aerosol = actuate.aerosol;
			in chamberVolume = 150.0;
			in residenceTime = 2.0;
			out suspendedAerosol;
		}

		then action openValve : OpenInspiratoryValve {
			in inhalationFlow = 30.0;
			in crackingPressure = 0.5;
			out valveOpen;
		}

		then action inhale : InhaleAerosol {
			in suspendedAerosol = suspend.suspendedAerosol;
			in inhalationFlow = 30.0;
			in inhalationVolume = 500.0;
			out deliveredDose;
			out depositionEfficiency;
		}

		then action hold : HoldBreath {
			in duration = breathHoldDuration;
		}

		then action exhale : ExhaleThroughValve {
			in exhaledVolume = 500.0;
			out exhaledAir;
		}

		then assign actualDeliveredDose := inhale.deliveredDose;
		then assign efficiency := inhale.depositionEfficiency;
		then done;
	}

	state def SpacerOperationStates {
		entry; then idle;

		state idle {
			doc /* Spacer ready for actuation */
		}
		accept ActuationEvent then aerosolCharged;

		state aerosolCharged {
			doc /* Chamber filled with medication aerosol */
		}
		accept InhalationStartEvent then inhalationActive;

		state inhalationActive {
			doc /* Patient actively inhaling through inspiratory valve */
		}
		accept InhalationCompleteEvent then breathHold;

		state breathHold {
			doc /* Patient holding breath for medication deposition */
		}
		accept ExhalationStartEvent then exhalationActive;

		state exhalationActive {
			doc /* Patient exhaling through expiratory valve */
		}
		accept ExhalationCompleteEvent then idle;
	}

	requirement def PrimaryFunctionRequirement {
		doc /* The inhaler spacer system shall deliver aerosolized medication from a metered-dose inhaler to the patient's respiratory tract by providing a holding chamber that reduces aerosol velocity, allows evaporation of propellant, and enables coordinated inhalation independent of actuation timing. */
		subject spacerSystem : InhalerSpacerAssembly;
	}

	requirement def AerosolSuspensionRequirement {
		doc /* The spacer chamber shall maintain at least 80% of the actuated aerosol in suspension for a minimum of 10 seconds to accommodate patient inhalation coordination. */
		subject chamber : SpacerChamber;
		require PrimaryFunctionRequirement;
	}

	requirement def ValveUnidirectionalityRequirement {
		doc /* The inspiratory valve shall permit airflow only during inhalation and the expiratory valve shall permit airflow only during exhalation, preventing cross-contamination and maintaining aerosol integrity. */
		subject inspiratoryValve : OneWayInspValve;
		subject expiratoryValve : OneWayExpValve;
		require PrimaryFunctionRequirement;
	}

	requirement def DepositionEfficiencyRequirement {
		doc /* The system shall achieve a lung deposition efficiency of at least 15% of the nominal metered dose under normal patient use conditions. */
		subject spacerSystem : InhalerSpacerAssembly;
		require PrimaryFunctionRequirement;
		require AerosolSuspensionRequirement;
	}
}
