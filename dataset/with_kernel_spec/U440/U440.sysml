package VaginalDilationTherapySystem {
    private import ISQ::*;
    private import ScalarValues::*;

    attribute def Diameter :> ISQ::length;
    attribute def SessionDuration :> ISQ::time;
    attribute def FrequencyPerWeek :> Real;
    attribute def ComfortLevel :> Real;

    item def Lubricant {
        attribute pH : Real = 4.5;
        attribute isWaterBased : Boolean = true;
        attribute volume :> ISQ::volume;
    }

    item def Coating {
        attribute isHypoallergenic : Boolean = true;
        attribute isBiocompatible : Boolean = true;
        attribute material : String = "medical-grade silicone";
    }

    part def Dilator {
        attribute diameter : Diameter;
        attribute length :> ISQ::length;
        attribute materialGrade : String = "medical-grade silicone";
        attribute isSterilized : Boolean = true;
        attribute isClean : Boolean = true;
        attribute hasLubricant : Boolean = false;
        part coating : Coating;
        port handlePort {
            out gripSignal : Boolean;
        }
        port bodyPort {
            in appliedLubricant : Lubricant;
            out insertionForce :> ISQ::force;
        }
    }

    part def DilatorSet {
        part dilators : Dilator[5] {
            ordered;
        }
        assert constraint {
            dilators->size() == 5 and
            dilators#(1).diameter < dilators#(2).diameter and
            dilators#(2).diameter < dilators#(3).diameter and
            dilators#(3).diameter < dilators#(4).diameter and
            dilators#(4).diameter < dilators#(5).diameter
        }
    }

    part def Patient {
        attribute comfort : ComfortLevel;
        attribute isCleared : Boolean;
        attribute tissueResponse : ComfortLevel;
        port tissuePort {
            in dilationForce :> ISQ::force;
            out tissueResponseOut : ComfortLevel;
        }
    }

    part def LubricantSupply {
        attribute lubricant : Lubricant;
        port applicatorPort {
            out dispensedLubricant : Lubricant;
        }
    }

    part def TherapyProtocol {
        attribute minDuration : SessionDuration;
        attribute recommendedFrequency : FrequencyPerWeek;
        attribute maxDilatorIndex : Integer = 5;
        attribute progressionSchedule :> ISQ::time[*];
    }

    action def PrepareDilator {
        in dilator : Dilator;
        in lubricant : Lubricant;
        out preparedDilator : Dilator;
    }

    action def ComfortAssessment {
        in patient : Patient;
        out isComfortable : Boolean;
        assign isComfortable := patient.comfort >= 0.5;
    }

    action def InsertAndDilate {
        in dilator : Dilator;
        in patient : Patient;
        in duration : SessionDuration;
        out tissueResponse : ComfortLevel;
    }

    action def RemoveAndClean {
        in dilator : Dilator;
        out cleanedDilator : Dilator;
    }

    action def PostponeSession {
        out status : String;
        assign status := "Postponed";
    }

    action def TherapySession {
        in dilator : Dilator;
        in lubricant : Lubricant;
        in patient : Patient;
        in protocol : TherapyProtocol;
        in duration : SessionDuration;
        out sessionSuccess : Boolean;
        out tissueResponse : ComfortLevel;
        out cleanedDilator : Dilator;

        assert constraint {
            duration >= protocol.minDuration
        }

        perform prepare : PrepareDilator {
            in dilator = dilator;
            in lubricant = lubricant;
        }
        then perform assess : ComfortAssessment {
            in patient = patient;
        }
        then if assess.isComfortable {
            perform dilate : InsertAndDilate {
                in dilator = prepare.preparedDilator;
                in patient = patient;
                in duration = duration;
            }
            then assign tissueResponse := dilate.tissueResponse;
            then perform clean : RemoveAndClean {
                in dilator = prepare.preparedDilator;
            }
            then assign cleanedDilator := clean.cleanedDilator;
            then assign sessionSuccess := true;
        } else {
            perform postpone : PostponeSession {}
            then assign cleanedDilator := prepare.preparedDilator;
            then assign sessionSuccess := false;
        }
    }

    requirement def SafetyRequirement {
        doc /* The system must ensure patient safety and comfort at all times. */
        subject patient : Patient;
        constraint { patient.comfort >= 0.5 }
    }

    requirement def BiocompatibilityRequirement {
        doc /* All dilators must have a biocompatible, hypoallergenic coating. */
        subject dilator : Dilator;
        constraint { dilator.coating.isHypoallergenic == true }
        constraint { dilator.coating.isBiocompatible == true }
    }

    requirement def ProgressiveSizingRequirement {
        doc /* The dilator set must contain five progressively larger dilators. */
        subject dilatorSet : DilatorSet;
        constraint { dilatorSet.dilators->size() == 5 }
        constraint {
            dilatorSet.dilators#(1).diameter < dilatorSet.dilators#(2).diameter and
            dilatorSet.dilators#(2).diameter < dilatorSet.dilators#(3).diameter and
            dilatorSet.dilators#(3).diameter < dilatorSet.dilators#(4).diameter and
            dilatorSet.dilators#(4).diameter < dilatorSet.dilators#(5).diameter
        }
    }

    requirement def ProtocolAdherenceRequirement {
        doc /* Each therapy session must adhere to the prescribed protocol duration. */
        subject session : TherapySession;
        constraint { session.duration >= session.protocol.minDuration }
    }

    requirement def SterilizationRequirement {
        doc /* Dilators must be sterilized after each use. */
        subject dilator : Dilator;
        constraint { dilator.isSterilized == true }
    }

    state machine def TherapyProgression {
        in patient : Patient;
        in protocol : TherapyProtocol;
        in dilatorSet : DilatorSet;

        state Idle;
        state Preparing;
        state Assessing;
        state Dilating;
        state Cleaning;
        state Postponed;

        transition from Idle to Preparing
            when patient.isCleared;

        transition from Preparing to Assessing;

        transition from Assessing to Dilating
            when patient.comfort >= 0.5;

        transition from Assessing to Postponed
            when patient.comfort < 0.5;

        transition from Dilating to Cleaning
            after protocol.minDuration;

        transition from Cleaning to Idle;

        transition from Postponed to Idle;
    }

    part def VaginalDilationTherapySystem {
        part dilatorSet : DilatorSet;
        part patient : Patient;
        part lubricantSupply : LubricantSupply;
        part protocol : TherapyProtocol {
            attribute :>> minDuration = 10 [min];
            attribute :>> recommendedFrequency = 3.0;
        }
        port therapyPort {
            in sessionRequest : Boolean;
            out sessionResult : Boolean;
        }
        connect lubricantSupply.applicatorPort to dilatorSet.dilators[1].bodyPort;
        connect dilatorSet.dilators[1].bodyPort to patient.tissuePort;
        perform session : TherapySession {
            in dilator = dilatorSet.dilators[1];
            in lubricant = lubricantSupply.lubricant;
            in patient = patient;
            in protocol = protocol;
            in duration = protocol.minDuration;
            out sessionSuccess = therapyPort.sessionResult;
        }
        state progression : TherapyProgression {
            in patient = patient;
            in protocol = protocol;
            in dilatorSet = dilatorSet;
        }
        satisfy SafetyRequirement by session;
        satisfy BiocompatibilityRequirement by dilatorSet.dilators[1];
        satisfy SterilizationRequirement by dilatorSet.dilators[1];
        satisfy ProgressiveSizingRequirement by dilatorSet;
    }

    part therapySystem : VaginalDilationTherapySystem {
        part :>> dilatorSet {
            part :>> dilators[1] {
                attribute :>> diameter = 1.5 [cm];
                attribute :>> length = 10 [cm];
            }
            part :>> dilators[2] {
                attribute :>> diameter = 2.0 [cm];
                attribute :>> length = 11 [cm];
            }
            part :>> dilators[3] {
                attribute :>> diameter = 2.5 [cm];
                attribute :>> length = 12 [cm];
            }
            part :>> dilators[4] {
                attribute :>> diameter = 3.0 [cm];
                attribute :>> length = 13 [cm];
            }
            part :>> dilators[5] {
                attribute :>> diameter = 3.5 [cm];
                attribute :>> length = 14 [cm];
            }
        }
        part :>> patient {
            attribute :>> comfort = 0.8;
            attribute :>> isCleared = true;
        }
        part :>> lubricantSupply {
            attribute :>> lubricant {
                attribute :>> pH = 4.5;
                attribute :>> isWaterBased = true;
                attribute :>> volume = 100 [mL];
            }
        }
    }
}
