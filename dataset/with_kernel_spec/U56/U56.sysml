package DigitalPillAdherenceSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import Time::DateTime;

	attribute def pHLevel :> Real;
	attribute def BodyTemperature :> ISQ::TemperatureValue;
	attribute def PillIdentifier :> String;
	attribute def PatientIdentifier :> String;

	item def TelemetryPacket {
		attribute pillId : PillIdentifier;
		attribute patientId : PatientIdentifier;
		attribute timestamp : DateTime;
		attribute temperature : BodyTemperature;
		attribute ph : pHLevel;
	}

	item def AdherenceConfirmation {
		attribute pillId : PillIdentifier;
		attribute patientId : PatientIdentifier;
		attribute timestamp : DateTime;
		attribute confirmed : Boolean;
	}

	port def RadioOutPort {
		out item telemetry : TelemetryPacket;
	}
	port def RadioInPort {
		in item telemetry : TelemetryPacket;
	}
	port def DataOutPort {
		out item confirmation : AdherenceConfirmation;
	}
	port def DataInPort {
		in item confirmation : AdherenceConfirmation;
	}

	attribute def ContactWithStomachFluid;
	attribute def PowerDepleted;
	attribute def TelemetrySent;
	attribute def ChargeGenerated;
	attribute def MeasurementComplete;

	part def DigitalPill {
		attribute pillId : PillIdentifier;
		attribute patientId : PatientIdentifier;
		attribute materialBiocompatible : Boolean = true;
		part medication;
		part electronics {
			part galvanicCell {
				attribute chargeGenerated : Boolean = false;
				action generateCharge {
					first start;
					then action activateGalvanicCell {
						out attribute charge : Boolean = true;
					}
					then done;
				}
			}
			part sensor {
				attribute temperature : BodyTemperature;
				attribute ph : pHLevel;
				action measurePhysiology {
					out attribute temperature : BodyTemperature;
					out attribute ph : pHLevel;
					first start;
					then action readTemperature;
					then action readPH;
					then done;
				}
			}
			part transmitter {
				port radioOut : RadioOutPort;
				action transmitTelemetry {
					in item telemetry : TelemetryPacket;
					first start;
					then action encodePacket;
					then action sendPacket;
					then done;
				}
			}
		}
		port radioOut : RadioOutPort;

		state pillLifecycle {
			entry; then inactive;
			state inactive;
			accept ContactWithStomachFluid then active;
			state active {
				entry {
					perform electronics.galvanicCell.generateCharge;
				}
			}
			accept ChargeGenerated then sensing;
			state sensing {
				entry {
					perform electronics.sensor.measurePhysiology;
				}
			}
			accept MeasurementComplete then transmitting;
			state transmitting {
				entry {
					perform electronics.transmitter.transmitTelemetry;
				}
			}
			accept TelemetrySent then depleted;
			state depleted;
			accept PowerDepleted then expelled;
			state expelled;
		}
	}

	part def WearablePatch {
		port radioIn : RadioInPort;
		port dataOut : DataOutPort;
		attribute wornOnTorso : Boolean = true;
		action relayData {
			in item telemetry : TelemetryPacket;
			out item confirmation : AdherenceConfirmation;
			first start;
			then action receive {
				in item telemetry : TelemetryPacket;
			}
			then action forward {
				out item confirmation : AdherenceConfirmation;
			}
			then done;
		}
	}

	part def MobileApp {
		port dataIn : DataInPort;
		port cloudOut : DataOutPort;
		attribute adherenceLog : AdherenceConfirmation[*];
		action processAdherence {
			in item confirmation : AdherenceConfirmation;
			first start;
			then action receive;
			then action verify {
				in item confirmation : AdherenceConfirmation;
			}
			then action log {
				in item confirmation : AdherenceConfirmation;
			}
			then action upload {
				out item confirmation : AdherenceConfirmation;
			}
			then done;
		}
	}

	part def CloudPlatform {
		port cloudIn : DataInPort;
		attribute adherenceHistory : AdherenceConfirmation[*];
		action storeAdherence {
			in item confirmation : AdherenceConfirmation;
			first start;
			then action receive;
			then action store {
				in item confirmation : AdherenceConfirmation;
			}
			then done;
		}
	}

	part digitalPillAdherenceSystem {
		part pill : DigitalPill;
		part patch : WearablePatch;
		part app : MobileApp;
		part cloud : CloudPlatform;

		connection pillToPatch connect pill.radioOut to patch.radioIn {
			item flow telemetry : TelemetryPacket;
		}
		connection patchToApp connect patch.dataOut to app.dataIn {
			item flow confirmation : AdherenceConfirmation;
		}
		connection appToCloud connect app.cloudOut to cloud.cloudIn {
			item flow confirmation : AdherenceConfirmation;
		}
	}

	requirement def IngestionVerification {
		subject pill : DigitalPill;
		objective {
			doc /* The system shall verify that a patient has successfully ingested their prescribed medication. */
		}
	}

	requirement def Biocompatibility {
		subject pill : DigitalPill;
		objective {
			doc /* The digital pill shall be constructed from biocompatible materials that allow it to pass safely through the digestive tract and be naturally expelled. */
		}
	}

	requirement def TelemetryTransmission {
		subject pill : DigitalPill;
		objective {
			doc /* Upon activation by stomach fluids, the pill shall transmit a telemetry packet containing sensor readings, a unique pill identifier, a patient identifier, and a precise timestamp. */
		}
	}

	requirement def AutomatedAdherenceRecord {
		subject system : digitalPillAdherenceSystem;
		objective {
			doc /* The system shall provide a reliable, automated record of when a dose is taken, accessible by healthcare providers via the cloud platform. */
		}
	}

	requirement def PowerAutonomy {
		subject pill : DigitalPill;
		objective {
			doc /* The digital pill shall power itself using a built-in galvanic cell that generates electric charge from the digestive environment, eliminating the need for a pre-charged battery. */
		}
	}

	requirement ingestionVerificationReq : IngestionVerification {
		subject :>> pill = digitalPillAdherenceSystem.pill;
	}

	requirement biocompatibilityReq : Biocompatibility {
		subject :>> pill = digitalPillAdherenceSystem.pill;
	}

	requirement telemetryTransmissionReq : TelemetryTransmission {
		subject :>> pill = digitalPillAdherenceSystem.pill;
	}

	requirement automatedAdherenceRecordReq : AutomatedAdherenceRecord {
		subject :>> system = digitalPillAdherenceSystem;
	}

	requirement powerAutonomyReq : PowerAutonomy {
		subject :>> pill = digitalPillAdherenceSystem.pill;
	}
}
