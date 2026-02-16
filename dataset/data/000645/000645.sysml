package DermatologyInstrumentSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def WavelengthValue :> ISQ::LengthValue;
    attribute def PowerDensityValue :> ISQ::PowerValue;
    attribute def MagnificationFactor :> Real;
    attribute def ImageResolutionValue :> Integer;
    attribute def TissueDepthValue :> ISQ::LengthValue;
    attribute def SkinTemperatureValue :> ISQ::TemperatureValue;

    item def LesionImageData {
        attribute resolution : ImageResolutionValue;
        attribute magnification : MagnificationFactor;
        attribute captureTimestamp : ISQ::TimeValue;
        attribute colorDepth : Integer;
    }

    item def DiagnosticAssessment {
        attribute asymmetryScore : Real;
        attribute borderIrregularity : Real;
        attribute colorVariation : Real;
        attribute diameterMeasurement : ISQ::LengthValue;
        attribute riskLevel : String;
    }

    item def TreatmentProtocol {
        attribute laserWavelength : WavelengthValue;
        attribute powerDensity : PowerDensityValue;
        attribute pulseDuration : ISQ::TimeValue;
        attribute numberOfPulses : Integer;
        attribute targetDepth : TissueDepthValue;
    }

    item def CryotherapyParameters {
        attribute freezeTemperature : SkinTemperatureValue;
        attribute freezeDuration : ISQ::TimeValue;
        attribute numberOfCycles : Integer;
    }

    item def SafetyMonitoringData {
        attribute currentTemperature : SkinTemperatureValue;
        attribute powerOutput : PowerDensityValue;
        attribute emergencyStopActive : Boolean;
        attribute coolingSystemActive : Boolean;
    }

    port def ImagingDataPort {
        out item imageData : LesionImageData;
    }

    port def DiagnosticPort {
        in item imageData : LesionImageData;
        out item assessment : DiagnosticAssessment;
    }

    port def LaserControlPort {
        in item protocol : TreatmentProtocol;
        out item safetyData : SafetyMonitoringData;
    }

    port def CryoControlPort {
        in item cryoParams : CryotherapyParameters;
        out item temperature : SkinTemperatureValue;
    }

    part def DermatoscopeModule {
        attribute opticalMagnification : MagnificationFactor;
        attribute illuminationWavelength : WavelengthValue;
        attribute imageResolution : ImageResolutionValue;
        
        port imagingOutput : ImagingDataPort;

        part opticalSystem {
            attribute lensConfiguration : String;
            attribute polarizationFilter : Boolean;
        }

        part illuminationSource {
            attribute ledType : String;
            attribute intensityLevel : PowerDensityValue;
        }

        part imageSensor {
            attribute sensorType : String;
            attribute pixelCount : ImageResolutionValue;
        }

        action def CaptureHighResolutionImage {
            in targetArea : ISQ::LengthValue;
            in magnificationLevel : MagnificationFactor;
            out capturedImage : LesionImageData;
        }

        perform action imagingSequence : CaptureHighResolutionImage[*] ordered;
    }

    part def DiagnosticAnalysisUnit {
        port diagnosticInput : DiagnosticPort;

        part imageProcessor {
            attribute processingAlgorithm : String;
            attribute analysisMode : String;
        }

        part patternRecognitionEngine {
            attribute aiModelVersion : String;
            attribute confidenceThreshold : Real;
        }

        action def AnalyzeLesionCharacteristics {
            in lesionImage : LesionImageData;
            out diagnosticResult : DiagnosticAssessment;
        }

        action def GenerateRiskAssessment {
            in characteristics : DiagnosticAssessment;
            out riskClassification : String;
        }

        perform action diagnosticWorkflow : AnalyzeLesionCharacteristics[*] ordered;
    }

    part def LaserTherapyUnit {
        attribute maxPowerOutput : PowerDensityValue;
        attribute operatingWavelengths : WavelengthValue[*];
        
        port laserControl : LaserControlPort;

        part laserSource {
            attribute laserType : String;
            attribute currentWavelength : WavelengthValue;
            attribute currentPower : PowerDensityValue;
        }

        part beamDeliverySystem {
            attribute fiberOpticDiameter : ISQ::LengthValue;
            attribute focusingLens : Boolean;
        }

        part safetyInterlock {
            attribute interlockStatus : Boolean;
            attribute emergencyShutoff : Boolean;
        }

        part coolingSystem {
            attribute coolantType : String;
            attribute coolingCapacity : ISQ::PowerValue;
            attribute activeStatus : Boolean;
        }

        action def DeliverLaserTreatment {
            in treatmentParams : TreatmentProtocol;
            out safetyStatus : SafetyMonitoringData;
        }

        action def MonitorTreatmentSafety {
            in currentPower : PowerDensityValue;
            in skinTemp : SkinTemperatureValue;
            out safetyCheck : Boolean;
        }

        perform action treatmentExecution : DeliverLaserTreatment[*] ordered;
    }

    part def CryotherapyUnit {
        attribute minimumTemperature : SkinTemperatureValue;
        attribute maxFreezeDuration : ISQ::TimeValue;
        
        port cryoControl : CryoControlPort;

        part refrigerantSystem {
            attribute refrigerantType : String;
            attribute pressureLevel : ISQ::PressureValue;
        }

        part applicatorProbe {
            attribute probeDiameter : ISQ::LengthValue;
            attribute thermalConductivity : Real;
        }

        part temperatureSensor {
            attribute sensorAccuracy : ISQ::TemperatureValue;
            attribute responseTime : ISQ::TimeValue;
        }

        action def ApplyCryotherapy {
            in freezeParams : CryotherapyParameters;
            out finalTemperature : SkinTemperatureValue;
        }

        perform action cryoApplication : ApplyCryotherapy[*] ordered;
    }

    part def ControlAndMonitoringSystem {
        attribute operatingMode : String;
        attribute systemStatus : String;

        part userInterface {
            attribute displayType : String;
            attribute touchscreenEnabled : Boolean;
        }

        part dataLogger {
            attribute storageCapacity : Real;
            attribute recordingActive : Boolean;
        }

        action def SelectOperatingMode {
            in modeSelection : String;
            out modeConfirmed : Boolean;
        }

        action def MonitorSystemStatus {
            out statusReport : String;
        }

        action def InitiateTreatmentSequence {
            in diagnosticData : DiagnosticAssessment;
            out treatmentPlan : TreatmentProtocol;
        }

        action def VerifyPatientSafety {
            in safetyData : SafetyMonitoringData;
            out safetyApproved : Boolean;
        }
    }

    part dermatologyInstrumentSystem {
        part dermatoscope : DermatoscopeModule {
            attribute :>> opticalMagnification = 10.0;
            attribute :>> illuminationWavelength = 400.0e-9;
            attribute :>> imageResolution = 4096;
        }

        part diagnosticUnit : DiagnosticAnalysisUnit {
            part :>> imageProcessor {
                attribute :>> processingAlgorithm = "ABCDE Analysis";
                attribute :>> analysisMode = "Automated";
            }
        }

        part laserUnit : LaserTherapyUnit {
            attribute :>> maxPowerOutput = 100.0;
            attribute :>> operatingWavelengths = (532.0e-9, 755.0e-9, 1064.0e-9);
        }

        part cryoUnit : CryotherapyUnit {
            attribute :>> minimumTemperature = 193.15;
            attribute :>> maxFreezeDuration = 60.0;
        }

        part controlSystem : ControlAndMonitoringSystem {
            attribute :>> operatingMode = "Diagnostic";
            attribute :>> systemStatus = "Ready";
        }

        connection imagingDataFlow connect 
            dermatoscope.imagingOutput to diagnosticUnit.diagnosticInput;

        connection laserControlFlow connect 
            controlSystem to laserUnit.laserControl;

        connection cryoControlFlow connect 
            controlSystem to cryoUnit.cryoControl;

        perform action executeDermatologicalProcedure {
            doc /* Primary function: Perform comprehensive skin lesion diagnosis and treatment
                   through integrated imaging, analysis, and therapeutic modalities */

            first start;
            then merge procedureCycle;

            then action captureImage : dermatoscope::CaptureHighResolutionImage {
                in targetArea = 0.01;
                in magnificationLevel = 10.0;
                out lesionImage : LesionImageData;
            }

            then action analyzeLesion : diagnosticUnit::AnalyzeLesionCharacteristics {
                in lesionImage = captureImage.lesionImage;
                out diagnosticAssessment : DiagnosticAssessment;
            }

            then action assessRisk : diagnosticUnit::GenerateRiskAssessment {
                in characteristics = analyzeLesion.diagnosticAssessment;
                out riskCategory : String;
            }

            then decide;
                if assessRisk.riskCategory == "Benign" then documentOnly;
                if assessRisk.riskCategory == "Suspicious" then selectTreatment;
                if assessRisk.riskCategory == "Emergency" then emergencyProtocol;

            action selectTreatment : controlSystem::InitiateTreatmentSequence {
                in diagnosticData = analyzeLesion.diagnosticAssessment;
                out selectedProtocol : TreatmentProtocol;
            }

            then decide;
                if selectTreatment.selectedProtocol.laserWavelength > 0.0 then performLaser;
                if selectTreatment.selectedProtocol.laserWavelength <= 0.0 then performCryo;

            action performLaser : laserUnit::DeliverLaserTreatment {
                in treatmentParams = selectTreatment.selectedProtocol;
                out laserSafety : SafetyMonitoringData;
            }

            then action verifySafety : controlSystem::VerifyPatientSafety {
                in safetyData = performLaser.laserSafety;
                out safetyStatus : Boolean;
            }

            then decide;
                if verifySafety.safetyStatus == true then documentOnly;
                if verifySafety.safetyStatus == false then emergencyProtocol;

            action performCryo : cryoUnit::ApplyCryotherapy {
                in freezeParams : CryotherapyParameters;
                out cryoTemp : SkinTemperatureValue;
            }

            then documentOnly;

            action documentOnly : controlSystem::MonitorSystemStatus {
                out finalStatus : String;
            }

            then procedureCycle;

            action emergencyProtocol {
                then action emergencyStop : controlSystem::MonitorSystemStatus {
                    out emergencyStatus : String;
                }
                then done;
            }
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The dermatology instrument system shall provide integrated capabilities for 
               high-resolution skin lesion imaging, automated diagnostic analysis using pattern 
               recognition, and selective therapeutic intervention through laser or cryotherapy 
               modalities to support early detection and treatment of dermatological conditions */

        subject system : dermatologyInstrumentSystem;

        require constraint imagingCapability {
            system.dermatoscope.imageResolution >= 4000
        }

        require constraint diagnosticAccuracy {
            system.diagnosticUnit.patternRecognitionEngine.confidenceThreshold >= 0.85
        }

        require constraint treatmentSafety {
            system.laserUnit.safetyInterlock.interlockStatus == true
        }
    }

    requirement def ImagingResolutionRequirement {
        doc /* The dermatoscope shall capture images with minimum 4000 pixel resolution 
               at 10x magnification for detailed lesion analysis */

        subject scope : DermatoscopeModule;

        require constraint {
            scope.imageResolution >= 4000 and scope.opticalMagnification >= 10.0
        }
    }

    requirement def TreatmentSafetyRequirement {
        doc /* The laser therapy unit shall maintain continuous safety monitoring with 
               automatic shutdown capability if skin temperature exceeds 318K or power 
               output exceeds specified limits */

        subject laser : LaserTherapyUnit;

        require constraint {
            laser.safetyInterlock.emergencyShutoff == true or
            laser.coolingSystem.activeStatus == true
        }
    }

    requirement def DiagnosticAccuracyRequirement {
        doc /* The diagnostic analysis unit shall achieve minimum 85% confidence threshold 
               in lesion classification using validated pattern recognition algorithms */

        subject diagnostic : DiagnosticAnalysisUnit;

        require constraint {
            diagnostic.patternRecognitionEngine.confidenceThreshold >= 0.85
        }
    }

    requirement systemRequirement : PrimaryFunctionRequirement {
        subject instrumentSystem = dermatologyInstrumentSystem;
    }

    satisfy systemRequirement.imagingCapability by dermatologyInstrumentSystem.dermatoscope;
    satisfy systemRequirement.diagnosticAccuracy by dermatologyInstrumentSystem.diagnosticUnit;
    satisfy systemRequirement.treatmentSafety by dermatologyInstrumentSystem.laserUnit;
}
