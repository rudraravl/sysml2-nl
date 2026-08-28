package DryEyeTreatmentSystem {
    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types =====
    value type Length :> Real { unit "mm"; }
    value type Diameter :> Real { unit "mm"; }
    value type Volume :> Real { unit "uL"; }
    value type FlowRate :> Real { unit "uL/min"; }
    value type Efficiency :> Real { unit "%"; }
    value type Pressure :> Real { unit "Pa"; }
    value type Duration :> Real { unit "min"; }

    // ===== Item Types =====
    item def Tear;
    item def Silicone;
    item def Collagen;
    item def Hydrogel;

    item def PlugMaterial {
        attribute biocompatibility : Boolean;
        attribute degradationRate : Real;
    }

    // ===== Enumerations =====
    enum def PlugState {
        uninserted,
        inserting,
        seated,
        displaced,
        removed
    }

    enum def PunctumLocation {
        lower,
        upper
    }

    // ===== Requirements =====
    requirement def OcclusionRequirement {
        doc "The plug must occlude the punctum to reduce tear drainage.";
        attribute minEfficiency : Efficiency = 70;
        require occlusionEfficiency >= minEfficiency;
    }

    requirement def SizingRequirement {
        doc "The plug must be correctly sized for the patient's punctum.";
        attribute targetDiameter : Diameter;
        attribute targetLength : Length;
        require plugDiameter <= targetDiameter and plugDiameter >= targetDiameter * 0.9;
        require plugLength <= targetLength and plugLength >= targetLength * 0.9;
    }

    requirement def TherapeuticTearVolumeRequirement {
        doc "The plug must raise tear film volume to a therapeutic level.";
        attribute targetTearVolume : Volume = 7.0;
        require tearFilmVolume >= targetTearVolume;
    }

    requirement def BiocompatibilityRequirement {
        doc "The plug material must be biocompatible.";
        require material.biocompatibility == true;
    }

    requirement def StabilityRequirement {
        doc "The plug must remain seated under normal physiological conditions.";
        attribute minRetentionDuration : Duration = 180;
        require seatedDuration >= minRetentionDuration;
    }

    // ===== Port Definitions =====
    port def PunctumInterface {
        out item tearDrainage : Tear;
        attribute drainageRate : FlowRate;
    }

    port def PlugOcclusionPort {
        in item tearFlow : Tear;
        attribute occlusionEfficiency : Efficiency;
    }

    port def InsertionPort {
        attribute insertionForce : Pressure;
        attribute insertionStatus : PlugState;
    }

    // ===== Part Definitions =====
    part def PunctalPlug {
        attribute plugDiameter : Diameter = 0.4;
        attribute plugLength : Length = 1.5;
        attribute material : PlugMaterial;
        attribute occlusionEfficiency : Efficiency = 85;
        attribute state : PlugState = PlugState::uninserted;

        port occlusionPort : PlugOcclusionPort;
        port insertionPort : InsertionPort;

        requirement occlusionReq : OcclusionRequirement {
            occlusionEfficiency = PunctalPlug::occlusionEfficiency;
        }

        requirement biocompatReq : BiocompatibilityRequirement {
            material = PunctalPlug::material;
        }

        state def PlugLifecycle {
            entry; then uninserted;

            state uninserted;
            transition uninserted to inserting
                when insertionPort.insertionStatus == PlugState::inserting;

            state inserting {
                entry { send InsertionStarted; }
                do { perform InsertionProcedure; }
                exit { send InsertionCompleted; }
            }
            transition inserting to seated
                when occlusionPort.occlusionEfficiency >= 70;
            transition inserting to displaced
                when occlusionPort.occlusionEfficiency < 70;

            state seated {
                entry { send PlugSeated; }
                do { perform OcclusionFunction; }
            }
            transition seated to displaced
                when occlusionPort.occlusionEfficiency < 50;
            transition seated to removed
                when receive RemovalCommand;

            state displaced {
                entry { send DisplacementAlert; }
            }
            transition displaced to removed
                when receive RemovalCommand;
            transition displaced to inserting
                when receive ReinsertionCommand;

            state removed {
                entry { send PlugRemoved; }
            }
        }

        action def InsertionProcedure {
            in plug : PunctalPlug;
            out success : Boolean;
            perform {
                first AssessPunctumSize;
                then SelectPlugSize;
                then InsertPlug;
                then VerifySeating;
                fork
                    if (seatingVerified) { success = true; }
                    else { success = false; }
            }
        }

        action def OcclusionFunction {
            in plug : PunctalPlug;
            out occludedFlow : FlowRate;
            perform {
                first ReceiveTearFlow;
                then ReduceFlowRate;
                then OutputResidualFlow;
            }
        }
    }

    part def Punctum {
        attribute location : PunctumLocation = PunctumLocation::lower;
        attribute punctumDiameter : Diameter = 0.5;
        attribute punctumDepth : Length = 2.0;
        attribute baselineDrainageRate : FlowRate = 1.2;

        port punctumInterface : PunctumInterface;

        requirement sizingReq : SizingRequirement {
            targetDiameter = Punctum::punctumDiameter;
            targetLength = Punctum::punctumDepth;
        }
    }

    part def TearFilm {
        attribute tearFilmVolume : Volume = 5.0;
        attribute targetVolume : Volume = 7.0;
        attribute productionRate : FlowRate = 1.0;
        attribute evaporationRate : FlowRate = 0.3;

        port tearInput : PunctumInterface;

        requirement therapeuticReq : TherapeuticTearVolumeRequirement {
            tearFilmVolume = TearFilm::tearFilmVolume;
        }

        action def UpdateTearVolume {
            in production : FlowRate;
            in drainage : FlowRate;
            in evaporation : FlowRate;
            out newVolume : Volume;
            perform {
                newVolume = tearFilmVolume + (production - drainage - evaporation) * 1.0;
            }
        }
    }

    part def LacrimalDrainageSystem {
        attribute totalDrainageCapacity : FlowRate = 2.0;
        in item tears : Tear;
        port drainageInput : PunctumInterface;
    }

    part def Eye {
        attribute eyeID : String;
        part punctum : Punctum[1..2];
        part tearFilm : TearFilm;
        part lacrimalSystem : LacrimalDrainageSystem;

        connection tearProduction : TearFilm.tearInput to Punctum.punctumInterface;
        connection drainagePath : Punctum.punctumInterface to LacrimalDrainageSystem.drainageInput;
    }

    part def Patient {
        attribute patientID : String;
        attribute age : Integer;
        part eyes : Eye[2];

        requirement patientTherapeuticReq : TherapeuticTearVolumeRequirement {
            tearFilmVolume = Patient::eyes.tearFilm.tearFilmVolume;
        }
    }

    part def Clinician {
        attribute clinicianID : String;
        action def PerformInsertion {
            in patient : Patient;
            in plug : PunctalPlug;
            out result : Boolean;
            perform {
                first ExaminePatient;
                then MeasurePunctum;
                then SelectPlug;
                then InsertPlug;
                then ConfirmSeating;
            }
        }

        action def PerformRemoval {
            in plug : PunctalPlug;
            out removed : Boolean;
            perform {
                first GraspPlug;
                then ExtractPlug;
                then DocumentRemoval;
            }
        }
    }

    // ===== System Assembly =====
    part def DryEyeTreatmentSystem {
        attribute systemID : String;
        part patient : Patient;
        part clinician : Clinician;
        part plug : PunctalPlug {
            attribute material : PlugMaterial {
                biocompatibility = true;
                degradationRate = 0.0;
            }
        }

        connection plugInsertion : PlugOcclusionPort to Punctum.punctumInterface {
            // Plug occludes punctum when seated
        }

        connection clinicianToPlug : Clinician.PerformInsertion.plug to PunctalPlug.insertionPort;

        requirement systemOcclusionReq : OcclusionRequirement {
            occlusionEfficiency = plug.occlusionEfficiency;
        }

        requirement systemStabilityReq : StabilityRequirement {
            seatedDuration = 180;
        }

        state def SystemOperation {
            entry; then monitoring;

            state monitoring {
                do { perform MonitorTearRetention; }
            }
            transition monitoring to intervention
                when plug.state == PlugState::displaced;

            state intervention {
                entry { send InterventionRequired; }
                do { perform Clinician.PerformRemoval; }
            }
            transition intervention to monitoring
                when plug.state == PlugState::seated;
        }
    }
}
