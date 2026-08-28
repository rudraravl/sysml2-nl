package NPA_System {
    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    // ===== Value Types with Units =====
    value def Length :> Real { unit = 'mm'; }
    value def Diameter :> Real { unit = 'mm'; }
    value def OxygenSaturation :> Real { unit = '%'; }
    value def InsertionForce :> Real { unit = 'N'; }
    value def Volume :> Real { unit = 'mL'; }
    value def FlowRate :> Real { unit = 'L/min'; }

    // ===== Item Types =====
    item def Air;
    item def WaterBasedLubricant;
    item def BodilySecretion;

    // ===== Enumeration =====
    enum def DeviceState { stored; prepared; inserted; functioning; removed; }
    enum def PatientState { conscious; semiconscious; unconscious; }
    enum def TubeMaterial { medicalGradeSilicone; pvc; polyurethane; }
    enum def TubeSize { small; medium; large; }

    // ===== Requirements =====
    requirement def AirwayPatencyRequirement {
        doc { The NPA shall establish and maintain an open airway for an unconscious or semiconscious patient. }
        subject device : NasopharyngealAirway;
        objective {
            doc { The device shall bypass upper airway obstruction caused by tongue displacement. }
        }
    }

    requirement def BiocompatibilityRequirement {
        doc { The NPA tube shall be made of medical-grade silicone. }
        subject tube : Tube;
        constraint { tube.material == TubeMaterial::medicalGradeSilicone }
    }

    requirement def BeveledTipRequirement {
        doc { The tube tip shall be beveled to reduce insertion trauma. }
        subject tube : Tube;
        constraint { tube.beveled == true }
    }

    requirement def FlangeSafetyRequirement {
        doc { The flange shall prevent over-insertion of the tube into the airway. }
        subject flange : Flange;
        constraint { flange.outerDiameter > 12.0 [mm] }
    }

    requirement def OxygenSaturationRequirement {
        doc { The patient's oxygen saturation shall be continuously monitored while the device is functioning. }
        subject patient : Patient;
        constraint { patient.oxygenSaturation >= 90.0 [%] }
    }

    requirement def SizeSelectionRequirement {
        doc { The caregiver shall select an appropriately sized NPA based on patient assessment. }
        subject caregiver : Caregiver;
    }

    // ===== Part Definitions =====
    part def NasopharyngealAirway {
        attribute manufacturer : String;
        attribute modelNumber : String;
        attribute size : TubeSize;
        attribute state : DeviceState = DeviceState::stored;

        part tube : Tube;
        part flange : Flange;

        port airflowIn : AirPort;
        port airflowOut : AirPort;

        flow airflow : Flow {
            in item : Air @ airflowIn;
            out item : Air @ airflowOut;
        }

        requirement satisfaction {
            satisfy AirwayPatencyRequirement by self;
            satisfy BiocompatibilityRequirement by tube;
            satisfy BeveledTipRequirement by tube;
            satisfy FlangeSafetyRequirement by flange;
        }

        exhibit state deviceStateMachine {
            entry; then stored;

            state stored {
                entry { self.state = DeviceState::stored; }
            }

            state prepared {
                entry { self.state = DeviceState::prepared; }
            }

            state inserted {
                entry { self.state = DeviceState::inserted; }
            }

            state functioning {
                entry { self.state = DeviceState::functioning; }
            }

            state removed {
                entry { self.state = DeviceState::removed; }
            }

            transition stored -> prepared
                when caregiver.triggerPrepare();
            transition prepared -> inserted
                when caregiver.triggerInsert();
            transition inserted -> functioning
                when patient.airwayPatent == true;
            transition functioning -> inserted
                when caregiver.triggerAdjust();
            transition functioning -> removed
                when caregiver.triggerRemove();
            transition inserted -> removed
                when caregiver.triggerRemove();
        }
    }

    part def Tube {
        attribute material : TubeMaterial = TubeMaterial::medicalGradeSilicone;
        attribute beveled : Boolean = true;
        attribute length : Length = 80.0 [mm];
        attribute innerDiameter : Diameter = 7.0 [mm];
        attribute outerDiameter : Diameter = 9.0 [mm];
        attribute lubricantApplied : Boolean = false;

        port distalTip : AirPort;
        port proximalEnd : AirPort;

        flow airConduction : Flow {
            in item : Air @ distalTip;
            out item : Air @ proximalEnd;
        }

        action applyLubricant(in lubricant : WaterBasedLubricant) {
            this.lubricantApplied = true;
        }
    }

    part def Flange {
        attribute outerDiameter : Diameter = 15.0 [mm];
        attribute flared : Boolean = true;
        attribute color : String;

        action secureAgainstNostril() {
            doc { The flange rests against the nostril to prevent over-insertion. }
        }
    }

    part def Patient {
        attribute patientId : String;
        attribute condition : PatientState;
        attribute oxygenSaturation : OxygenSaturation = 98.0 [%];
        attribute airwayPatent : Boolean = false;

        part nostril : Nostril;
        part nasalPassage : NasalPassage;
        part pharynx : Pharynx;
        part tongue : Tongue;
        part lung : Lung;

        port externalNare : BodyPort;
        port trachealOpening : BodyPort;

        flow respiration : Flow {
            in item : Air @ externalNare;
            out item : Air @ trachealOpening;
        }

        action monitorOxygenSaturation() : OxygenSaturation {
            return this.oxygenSaturation;
        }

        action assessAirwayObstruction() : Boolean {
            return this.tongue.displaced;
        }
    }

    part def Nostril {
        attribute diameter : Diameter = 8.0 [mm];
        port nareOpening : BodyPort;
    }

    part def NasalPassage {
        attribute length : Length = 60.0 [mm];
        port inlet : BodyPort;
        port outlet : BodyPort;
    }

    part def Pharynx {
        attribute depth : Length = 30.0 [mm];
        port upper : BodyPort;
        port lower : BodyPort;
    }

    part def Tongue {
        attribute displaced : Boolean = false;
        action fallBack() {
            this.displaced = true;
        }
    }

    part def Lung {
        attribute tidalVolume : Volume = 500.0 [mL];
        attribute respiratoryRate : Real = 12.0;
        port bronchus : BodyPort;

        action ventilate(in air : Air) {
            doc { Air travels from pharynx to lungs. }
        }
    }

    part def Caregiver {
        attribute name : String;
        attribute role : String;

        action assessPatient(in patient : Patient) : Boolean {
            doc { Determine if NPA is needed based on patient condition. }
            return patient.condition != PatientState::conscious;
        }

        action selectSize(in patient : Patient) : TubeSize {
            doc { Select appropriate NPA size based on patient nostril diameter. }
            if patient.nostril.diameter < 7.0 [mm] {
                return TubeSize::small;
            } else if patient.nostril.diameter < 9.0 [mm] {
                return TubeSize::medium;
            } else {
                return TubeSize::large;
            }
        }

        action prepareDevice(in device : NasopharyngealAirway, in lubricant : WaterBasedLubricant) {
            device.tube.applyLubricant(lubricant);
        }

        action insertDevice(in device : NasopharyngealAirway, in patient : Patient) {
            doc { Insert NPA through nostril until tip rests in pharynx. }
            patient.airwayPatent = true;
        }

        action monitorPatient(in patient : Patient) {
            doc { Continuously monitor oxygen saturation. }
            patient.monitorOxygenSaturation();
        }

        action adjustDevice(in device : NasopharyngealAirway) {
            doc { Adjust device position if issues arise. }
        }

        action removeDevice(in device : NasopharyngealAirway, in patient : Patient) {
            doc { Remove NPA when no longer required. }
            patient.airwayPatent = false;
        }

        event triggerPrepare() : Boolean;
        event triggerInsert() : Boolean;
        event triggerAdjust() : Boolean;
        event triggerRemove() : Boolean;
    }

    // ===== Port Definitions =====
    port def AirPort {
        in item : Air;
        out item : Air;
    }

    port def BodyPort {
        in item : Air;
        out item : Air;
    }

    // ===== Usage: NPA Procedure Context =====
    part def NPAProcedure {
        part npa : NasopharyngealAirway {
            attribute size = TubeSize::medium;
        }
        part patient : Patient {
            attribute condition = PatientState::unconscious;
        }
        part caregiver : Caregiver;
        item lubricant : WaterBasedLubricant;

        connection npa.airflowOut to patient.externalNare;
        connection npa.tube.distalTip to patient.nasalPassage.outlet;
        connection patient.nasalPassage.outlet to patient.pharynx.upper;
        connection patient.pharynx.lower to patient.lung.bronchus;

        exhibit action procedureFlow {
            action assess : Caregiver::assessPatient(in patient);
            action select : Caregiver::selectSize(in patient);
            action prepare : Caregiver::prepareDevice(in npa, in lubricant);
            action insert : Caregiver::insertDevice(in npa, in patient);
            action monitor : Caregiver::monitorPatient(in patient);
            action remove : Caregiver::removeDevice(in npa, in patient);

            then assess;
            then select;
            then prepare;
            then insert;
            then monitor;
            then remove;
        }

        requirement satisfaction {
            satisfy OxygenSaturationRequirement by patient;
            satisfy SizeSelectionRequirement by caregiver;
        }
    }
}
