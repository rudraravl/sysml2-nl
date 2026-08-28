package TactileSensitivityTestingSystem {
    doc /* This package defines a sensory testing system for quantitatively measuring tactile sensitivity and pain thresholds in biological subjects using Von Frey hairs. */
    private import SI::*;
    private import ISQ::*;
    private import ScalarValues::*;

    package Definitions {
        enum def FilamentMaterial {
            nylon;
            stainlessSteel;
        }

        enum def ResponseKind {
            none;
            withdrawal;
            flinch;
            vocalization;
        }

        part def Handle {
            attribute length :> ISQ::length;
        }

        part def Instrument;

        part def Filament {
            attribute material : FilamentMaterial;
            attribute diameter :> ISQ::length;
            attribute bucklingForce :> ISQ::force;
            attribute currentForce :> ISQ::force = 0 [N];
            assert constraint { bucklingForce > 0 [N] }
            state bucklingState {
                state unbuckled;
                state buckled;
                transition unbuckled to buckled when (currentForce >= bucklingForce);
                transition buckled to unbuckled when (currentForce < bucklingForce);
            }
        }

        connection def HandleFilamentLink {
            end handleEnd : Handle;
            end filamentEnd : Filament;
        }

        port def TipPort {
            out attribute appliedForce :> ISQ::force;
        }

        port def SkinPort {
            in attribute receivedForce :> ISQ::force;
            out attribute response : ResponseKind;
        }

        connection def StimulusConnection {
            end tipEnd : TipPort;
            end skinEnd : SkinPort;
        }

        part def BiologicalSubject {
            attribute subjectId : String;
            attribute sensitivityThreshold :> ISQ::force;
            port skin : SkinPort;
            attribute currentResponse : ResponseKind = ResponseKind::none;
        }

        part def VonFreyHair :> Instrument {
            attribute hairId : String;
            part handle : Handle;
            part filament : Filament;
            connection handleFilamentLink : HandleFilamentLink connect handle to filament;
            port tip : TipPort {
                :>> appliedForce = filament.bucklingForce;
            }
        }

        part def TactileTestingSystem;

        requirement def BucklingCalibrationRequirement {
            doc /* Each filament shall buckle at its specified calibrated force within tolerance. */
            attribute specifiedForce :> ISQ::force;
            attribute measuredForce :> ISQ::force;
            attribute tolerance :> ISQ::force;
            require constraint { measuredForce >= specifiedForce - tolerance and measuredForce <= specifiedForce + tolerance }
        }

        requirement def StimulusConsistencyRequirement {
            doc /* The force delivered to the subject shall not exceed the filament's buckling force. */
            attribute deliveredForce :> ISQ::force;
            attribute bucklingForce :> ISQ::force;
            require constraint { deliveredForce <= bucklingForce }
        }

        requirement def ThresholdDeterminationRequirement {
            doc /* The sensitivity threshold is the lowest force consistently eliciting a response. */
            attribute thresholdForce :> ISQ::force;
            require constraint { thresholdForce > 0 [N] }
        }

        action def SelectNextFilament {
            in part currentHair : VonFreyHair;
            out part nextHair : VonFreyHair;
        }

        action def PositionInstrument {
            in part hair : VonFreyHair;
            in part bioSubject : BiologicalSubject;
        }

        action def ApplyForceUntilBuckle {
            in part hair : VonFreyHair;
            in part bioSubject : BiologicalSubject;
            out buckled : Boolean;
        }

        action def ObserveResponse {
            in part bioSubject : BiologicalSubject;
            out response : ResponseKind;
        }

        action def RecordOutcome {
            in part hair : VonFreyHair;
            in response : ResponseKind;
            out thresholdFound : Boolean;
            out thresholdForce :> ISQ::force;
        }

        part def TestOperator {
            perform selecting : SelectNextFilament;
            perform positioning : PositionInstrument;
            perform applying : ApplyForceUntilBuckle;
            perform observing : ObserveResponse;
        }

        state def TactileTestControl {
            attribute responseDetected : Boolean = false;
            attribute thresholdForce :> ISQ::force;

            state selectingFilament;
            state positioningInstrument;
            state applyingForce;
            state observingResponse;
            state recordingOutcome;
            state complete;

            transition initial to selectingFilament;
            transition selectingFilament to positioningInstrument;
            transition positioningInstrument to applyingForce;
            transition applyingForce to observingResponse;
            transition observingResponse to recordingOutcome;
            transition recordingOutcome to complete when (responseDetected == true);
            transition recordingOutcome to selectingFilament when (responseDetected == false);
        }

        verification def TactileSensitivityTest {
            subject testSubject : BiologicalSubject;
            objective thresholdObjective {
                verify requirement thresholdRequirement : ThresholdDeterminationRequirement;
            }
        }
    }

    package Usages {
        private import Definitions::*;

        requirement <'BC.1'> filamentCalibration : BucklingCalibrationRequirement {
            doc /* All filaments in the test set shall be calibrated to their specified buckling forces. */
            :>> tolerance = 0.0005 [N];
        }

        requirement <'SC.1'> stimulusConsistency : StimulusConsistencyRequirement {
            doc /* The delivered force shall not exceed the filament's calibrated buckling force. */
        }

        requirement <'TD.1'> thresholdDetermination : ThresholdDeterminationRequirement {
            doc /* The threshold shall be the lowest force consistently eliciting a response. */
        }

        verification tactileTest : TactileSensitivityTest {
            subject testSubject : BiologicalSubject;
            in part testHair : VonFreyHair;
            objective tactileThresholdObjective {
                verify thresholdDetermination :>> thresholdRequirement;
            }
            action positionInstrument {
                in part hair : VonFreyHair = tactileTest.testHair;
                in part bioSubject : BiologicalSubject = tactileTest.testSubject;
            }
            action applyForce {
                in part hair : VonFreyHair = positionInstrument.hair;
                in part bioSubject : BiologicalSubject = positionInstrument.bioSubject;
                out buckled : Boolean;
            }
            action observeResponse {
                in part bioSubject : BiologicalSubject = applyForce.bioSubject;
                out response : ResponseKind;
            }
            action recordOutcome {
                in part hair : VonFreyHair = applyForce.hair;
                in response : ResponseKind = observeResponse.response;
                out thresholdFound : Boolean;
                out thresholdForce :> ISQ::force;
            }
            return thresholdForce : ISQ::force = recordOutcome.thresholdForce;
        }

        part testingSystem : TactileTestingSystem {
            perform tactileTest;
            ref part subjectUnderTest : BiologicalSubject;
            part operator : TestOperator;
            part hair1 : VonFreyHair {
                :>> hairId = "VF-1";
                :>> handle { :>> length = 150 [mm]; }
                :>> filament {
                    :>> material = FilamentMaterial::nylon;
                    :>> diameter = 0.127 [mm];
                    :>> bucklingForce = 0.006 [N];
                }
            }
            part hair2 : VonFreyHair {
                :>> hairId = "VF-2";
                :>> handle { :>> length = 150 [mm]; }
                :>> filament {
                    :>> material = FilamentMaterial::nylon;
                    :>> diameter = 0.152 [mm];
                    :>> bucklingForce = 0.016 [N];
                }
            }
            part hair3 : VonFreyHair {
                :>> hairId = "VF-3";
                :>> handle { :>> length = 150 [mm]; }
                :>> filament {
                    :>> material = FilamentMaterial::nylon;
                    :>> diameter = 0.203 [mm];
                    :>> bucklingForce = 0.040 [N];
                }
            }
            part hair4 : VonFreyHair {
                :>> hairId = "VF-4";
                :>> handle { :>> length = 150 [mm]; }
                :>> filament {
                    :>> material = FilamentMaterial::nylon;
                    :>> diameter = 0.254 [mm];
                    :>> bucklingForce = 0.070 [N];
                }
            }
            part hair5 : VonFreyHair {
                :>> hairId = "VF-5";
                :>> handle { :>> length = 150 [mm]; }
                :>> filament {
                    :>> material = FilamentMaterial::nylon;
                    :>> diameter = 0.305 [mm];
                    :>> bucklingForce = 0.160 [N];
                }
            }
            part hair6 : VonFreyHair {
                :>> hairId = "VF-6";
                :>> handle { :>> length = 150 [mm]; }
                :>> filament {
                    :>> material = FilamentMaterial::nylon;
                    :>> diameter = 0.381 [mm];
                    :>> bucklingForce = 0.400 [N];
                }
            }
            connection stimulusLink : StimulusConnection connect hair1.tip to subjectUnderTest.skin;
        }

        individual def TestSubject1 :> BiologicalSubject;
        individual def TestSystem :> TactileTestingSystem;

        individual testSystem : TestSystem :> testingSystem {
            timeslice testWithHair1 {
                perform action :>> tactileTest {
                    in individual :>> testSubject : TestSubject1 {
                        :>> subjectId = "Subject-001";
                    }
                    in part :>> testHair = hair1;
                }
            }
            then timeslice testWithHair2 {
                perform action :>> tactileTest {
                    in individual :>> testSubject : TestSubject1 {
                        :>> subjectId = "Subject-001";
                    }
                    in part :>> testHair = hair2;
                }
            }
            then timeslice testWithHair3 {
                perform action :>> tactileTest {
                    in individual :>> testSubject : TestSubject1 {
                        :>> subjectId = "Subject-001";
                    }
                    in part :>> testHair = hair3;
                }
            }
        }
    }
}
