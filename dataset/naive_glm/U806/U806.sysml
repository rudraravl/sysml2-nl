package PhaseUnwrappingSystem {
    import ScalarValues::*;

    package Units {
        unit rad;
        unit deg;
        unit one;
        unit second;

        value type PhaseAngle :> Real {
            unit rad;
        }
        value type CoherenceValue :> Real {
            unit one;
        }
        value type QualityScore :> Real {
            unit one;
        }
        value type ResidualErrorValue :> Real {
            unit rad;
        }
        value type TimeDuration :> Real {
            unit second;
        }
    }

    package DataTypes {
        item def PixelCoordinate {
            attribute x : Integer;
            attribute y : Integer;
        }

        item def PhaseMap {
            attribute width : Integer;
            attribute height : Integer;
            attribute values : PhaseAngle[0..*] ordered;
        }

        item def WrappedPhaseMap :> PhaseMap {
            attribute minRange : PhaseAngle = -3.14159265359;
            attribute maxRange : PhaseAngle = 3.14159265359;
        }

        item def UnwrappedPhaseMap :> PhaseMap {
            attribute isUnwrapped : Boolean = true;
        }

        item def QualityMap {
            attribute width : Integer;
            attribute height : Integer;
            attribute coherence : CoherenceValue[0..*] ordered;
            attribute quality : QualityScore[0..*] ordered;
        }

        item def SeedPoint {
            attribute position : PixelCoordinate;
            attribute quality : QualityScore;
            attribute coherence : CoherenceValue;
        }

        item def ValidationReport {
            attribute residualError : ResidualErrorValue;
            attribute maxResidual : ResidualErrorValue;
            attribute meanResidual : ResidualErrorValue;
            attribute consistencyPassed : Boolean;
            attribute wrappedDifferences : Integer;
            attribute processedPixels : Integer;
            attribute totalPixels : Integer;
        }
    }

    package Actions {
        action def AcquirePhaseData {
            in wrappedMap : DataTypes::WrappedPhaseMap;
            out acquiredMap : DataTypes::WrappedPhaseMap;
            first action validateInput {
                in map : WrappedPhaseMap;
            }
            then action bufferFrame {
                in map : WrappedPhaseMap;
                out buffered : WrappedPhaseMap;
            }
            then action emitAcquired {
                in buffered : WrappedPhaseMap;
                out acquired : WrappedPhaseMap;
            }
        }

        action def AssessQuality {
            in wrappedMap : DataTypes::WrappedPhaseMap;
            out qualityMap : DataTypes::QualityMap;
            first action computeCoherence {
                in map : WrappedPhaseMap;
                out coherence : CoherenceValue[0..*];
            }
            then action computeGradients {
                in map : WrappedPhaseMap;
                out gradients : Real[0..*];
            }
            then action computeNoiseLevel {
                in map : WrappedPhaseMap;
                out noise : Real[0..*];
            }
            then action assembleQuality {
                in coherence : CoherenceValue[0..*];
                in gradients : Real[0..*];
                in noise : Real[0..*];
                out quality : QualityScore[0..*];
            }
            then action emitQualityMap {
                in coherence : CoherenceValue[0..*];
                in quality : QualityScore[0..*];
                out qmap : QualityMap;
            }
        }

        action def IdentifySeedPoints {
            in qualityMap : DataTypes::QualityMap;
            in threshold : QualityScore;
            out seedPoints : DataTypes::SeedPoint[0..*] ordered;
            first action scanHighQualityPixels {
                in qualityMap : QualityMap;
                in threshold : QualityScore;
                out candidates : SeedPoint[0..*];
            }
            then action sortCandidatesByQuality {
                in candidates : SeedPoint[0..*];
                out sorted : SeedPoint[0..*] ordered;
            }
            then action selectTopSeeds {
                in sorted : SeedPoint[0..*] ordered;
                out seedPoints : SeedPoint[0..*] ordered;
            }
        }

        action def PropagateUnwrap {
            in wrappedMap : DataTypes::WrappedPhaseMap;
            in qualityMap : DataTypes::QualityMap;
            in seedPoints : DataTypes::SeedPoint[0..*] ordered;
            out unwrappedMap : DataTypes::UnwrappedPhaseMap;
            first action initializeUnwrapped {
                in wrappedMap : WrappedPhaseMap;
                in seedPoints : SeedPoint[0..*] ordered;
                out initialized : UnwrappedPhaseMap;
            }
            then action buildPropagationQueue {
                in qualityMap : QualityMap;
                out queue : PixelCoordinate[0..*] ordered;
            }
            then action processNextPixel {
                in wrappedMap : WrappedPhaseMap;
                in unwrapped : UnwrappedPhaseMap;
                in queue : PixelCoordinate[0..*] ordered;
                out updated : UnwrappedPhaseMap;
                out remaining : PixelCoordinate[0..*] ordered;
            }
            then action correctPhaseJumps {
                in unwrapped : UnwrappedPhaseMap;
                out corrected : UnwrappedPhaseMap;
            }
            then action emitUnwrapped {
                in corrected : UnwrappedPhaseMap;
                out unwrappedMap : UnwrappedPhaseMap;
            }
        }

        action def ValidateConsistency {
            in unwrappedMap : DataTypes::UnwrappedPhaseMap;
            in originalWrapped : DataTypes::WrappedPhaseMap;
            out report : DataTypes::ValidationReport;
            first action rewrapUnwrapped {
                in unwrapped : UnwrappedPhaseMap;
                out rewrapped : WrappedPhaseMap;
            }
            then action computeDifferences {
                in rewrapped : WrappedPhaseMap;
                in original : WrappedPhaseMap;
                out differences : Real[0..*];
            }
            then action computeResidualStatistics {
                in differences : Real[0..*];
                out maxResidual : ResidualErrorValue;
                out meanResidual : ResidualErrorValue;
                out count : Integer;
            }
            then action assembleReport {
                in maxResidual : ResidualErrorValue;
                in meanResidual : ResidualErrorValue;
                in count : Integer;
                out report : ValidationReport;
            }
        }
    }

    package Subsystems {
        part def PhaseAcquisitionModule {
            port in wrappedInput : DataTypes::WrappedPhaseMap;
            port out wrappedOutput : DataTypes::WrappedPhaseMap;

            attribute frameCount : Integer = 0;
            attribute bufferSize : Integer = 1024;
            attribute maxLatency : TimeDuration = 0.1;

            action acquire : Actions::AcquirePhaseData;

            state acquisitionState {
                state idle;
                state receiving;
                state buffering;
                state validating;
                state ready;
                transition idle -> receiving;
                transition receiving -> buffering;
                transition buffering -> validating;
                transition validating -> ready;
                transition ready -> idle;
            }
        }

        part def QualityAssessmentModule {
            port in wrappedInput : DataTypes::WrappedPhaseMap;
            port out qualityOutput : DataTypes::QualityMap;

            attribute coherenceThreshold : CoherenceValue = 0.5;
            attribute gradientWeight : Real = 0.3;
            attribute noiseWeight : Real = 0.7;

            action assess : Actions::AssessQuality;

            state assessmentState {
                state waiting;
                state computingCoherence;
                state computingGradients;
                state computingNoiseLevel;
                state computingQuality;
                state complete;
                transition waiting -> computingCoherence;
                transition computingCoherence -> computingGradients;
                transition computingGradients -> computingNoiseLevel;
                transition computingNoiseLevel -> computingQuality;
                transition computingQuality -> complete;
                transition complete -> waiting;
            }
        }

        part def UnwrappingProcessorModule {
            port in wrappedInput : DataTypes::WrappedPhaseMap;
            port in qualityInput : DataTypes::QualityMap;
            port out unwrappedOutput : DataTypes::UnwrappedPhaseMap;

            attribute seedThreshold : QualityScore = 0.75;
            attribute maxPropagationSteps : Integer = 1000000;
            attribute phaseJumpsCorrected : Integer = 0;

            action identifySeeds : Actions::IdentifySeedPoints;
            action propagate : Actions::PropagateUnwrap;

            state processorState {
                state idle;
                state identifyingSeeds;
                state sortingSeedQueue;
                state propagating;
                state correctingJumps;
                state complete;
                transition idle -> identifyingSeeds;
                transition identifyingSeeds -> sortingSeedQueue;
                transition sortingSeedQueue -> propagating;
                transition propagating -> correctingJumps;
                transition correctingJumps -> complete;
                transition complete -> idle;
            }
        }

        part def ValidationModule {
            port in unwrappedInput : DataTypes::UnwrappedPhaseMap;
            port in wrappedInput : DataTypes::WrappedPhaseMap;
            port out reportOutput : DataTypes::ValidationReport;

            attribute maxAcceptableResidual : ResidualErrorValue = 0.01;

            action validate : Actions::ValidateConsistency;

            state validationState {
                state idle;
                state rewrapping;
                state comparing;
                state computingResiduals;
                state generatingReport;
                state done;
                transition idle -> rewrapping;
                transition rewrapping -> comparing;
                transition comparing -> computingResiduals;
                transition computingResiduals -> generatingReport;
                transition generatingReport -> done;
                transition done -> idle;
            }
        }
    }

    part def PhaseUnwrappingSystem {
        port in systemInput : DataTypes::WrappedPhaseMap;
        port out systemReport : DataTypes::ValidationReport;
        port out systemUnwrapped : DataTypes::UnwrappedPhaseMap;

        part acquisition : Subsystems::PhaseAcquisitionModule;
        part assessment : Subsystems::QualityAssessmentModule;
        part processor : Subsystems::UnwrappingProcessorModule;
        part validation : Subsystems::ValidationModule;

        connection systemToAcquisition : systemInput to acquisition.wrappedInput;
        connection acquisitionToAssessment : acquisition.wrappedOutput to assessment.wrappedInput;
        connection acquisitionToProcessor : acquisition.wrappedOutput to processor.wrappedInput;
        connection assessmentToProcessor : assessment.qualityOutput to processor.qualityInput;
        connection acquisitionToValidation : acquisition.wrappedOutput to validation.wrappedInput;
        connection processorToValidation : processor.unwrappedOutput to validation.unwrappedInput;
        connection validationToSystem : validation.reportOutput to systemReport;
        connection processorToSystemUnwrapped : processor.unwrappedOutput to systemUnwrapped;

        state systemState {
            state standby;
            state acquiring;
            state assessingQuality;
            state unwrapping;
            state validating;
            state complete;
            transition standby -> acquiring;
            transition acquiring -> assessingQuality;
            transition assessingQuality -> unwrapping;
            transition unwrapping -> validating;
            transition validating -> complete;
            transition complete -> standby;
        }
    }

    package Requirements {
        requirement def ReconstructContinuousPhase {
            doc /* The system shall reconstruct a continuous phase map from a wrapped phase input. */;
            subject wrappedPhase : DataTypes::WrappedPhaseMap;
            subject unwrappedPhase : DataTypes::UnwrappedPhaseMap;
        }

        requirement def AcceptWrappedPhaseInput {
            doc /* The system shall accept a wrapped phase map with values in the range -pi to +pi radians. */;
            subject input : DataTypes::WrappedPhaseMap;
            attribute minRange : PhaseAngle = -3.14159265359;
            attribute maxRange : PhaseAngle = 3.14159265359;
        }

        requirement def GenerateQualityMap {
            doc /* The system shall produce a quality map indicating per-pixel coherence and quality. */;
            subject qualityMap : DataTypes::QualityMap;
            attribute minCoherence : CoherenceValue = 0.0;
            attribute maxCoherence : CoherenceValue = 1.0;
        }

        requirement def IdentifySeedPointsFromQuality {
            doc /* The system shall identify seed points based on quality thresholds. */;
            subject seedPoints : DataTypes::SeedPoint;
            attribute minSeedQuality : QualityScore = 0.7;
        }

        requirement def PropagateQualityGuided {
            doc /* The system shall propagate unwrapping from seed points using quality-guided ordering. */;
            subject unwrappedMap : DataTypes::UnwrappedPhaseMap;
        }

        requirement def ValidateConsistencyOfUnwrap {
            doc /* The system shall validate the unwrapped phase against the original wrapped phase by computing residual error. */;
            subject report : DataTypes::ValidationReport;
            attribute maxAcceptableResidual : ResidualErrorValue = 0.01;
        }

        requirement def ProcessWithinTimeLimit {
            doc /* The system shall process a phase map within a specified time limit. */;
            attribute maxProcessingTime : TimeDuration = 60.0;
        }

        requirement def HandleNoisyData {
            doc /* The system shall handle noisy phase data without introducing artificial discontinuities. */;
            subject noisyPhase : DataTypes::WrappedPhaseMap;
            attribute maxNoiseTolerance : CoherenceValue = 0.5;
        }

        requirement def SystemRequirements {
            requirement acceptInput : AcceptWrappedPhaseInput;
            requirement generateQuality : GenerateQualityMap;
            requirement identifySeeds : IdentifySeedPointsFromQuality;
            requirement propagate : PropagateQualityGuided;
            requirement validate : ValidateConsistencyOfUnwrap;
            requirement reconstruct : ReconstructContinuousPhase;
            requirement timeLimit : ProcessWithinTimeLimit;
            requirement noiseHandling : HandleNoisyData;
        }
    }

    package Verifications {
        verification reconstructTest : Requirements::ReconstructContinuousPhase {
            doc /* Verify that the unwrapped phase is continuous with no artificial jumps. */;
        }
        verification wrappedInputTest : Requirements::AcceptWrappedPhaseInput {
            doc /* Verify that the system accepts wrapped phase values in the specified range. */;
        }
        verification qualityMapTest : Requirements::GenerateQualityMap {
            doc /* Verify that a quality map is generated with valid coherence values. */;
        }
        verification seedPointsTest : Requirements::IdentifySeedPointsFromQuality {
            doc /* Verify that seed points are identified based on quality threshold. */;
        }
        verification propagationTest : Requirements::PropagateQualityGuided {
            doc /* Verify that unwrapping propagates from seeds in quality-guided order. */;
        }
        verification consistencyTest : Requirements::ValidateConsistencyOfUnwrap {
            doc /* Verify that the residual error is within acceptable limits. */;
        }
        verification timeTest : Requirements::ProcessWithinTimeLimit {
            doc /* Verify that processing completes within the time limit. */;
        }
        verification noiseTest : Requirements::HandleNoisyData {
            doc /* Verify that noisy phase data is handled without introducing discontinuities. */;
        }
    }

    package Allocations {
        allocation reconstructAlloc : Requirements::ReconstructContinuousPhase to PhaseUnwrappingSystem;
        allocation acquireAlloc : Requirements::AcceptWrappedPhaseInput to Subsystems::PhaseAcquisitionModule;
        allocation qualityAlloc : Requirements::GenerateQualityMap to Subsystems::QualityAssessmentModule;
        allocation seedAlloc : Requirements::IdentifySeedPointsFromQuality to Subsystems::UnwrappingProcessorModule;
        allocation propagateAlloc : Requirements::PropagateQualityGuided to Subsystems::UnwrappingProcessorModule;
        allocation validateAlloc : Requirements::ValidateConsistencyOfUnwrap to Subsystems::ValidationModule;
    }
}
