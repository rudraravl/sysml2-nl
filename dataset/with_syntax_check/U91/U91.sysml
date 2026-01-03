package 'Near-Infrared Vein Finder System' {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    attribute def Wavelength :> LengthValue {
        doc /* Near-infrared wavelength in nanometers */
    }

    attribute def OpticalPower :> PowerValue {
        doc /* Optical power output of illumination source */
    }

    attribute def FrameRate :> FrequencyValue {
        doc /* Image capture rate in frames per second */
    }

    attribute def VeinDepth :> LengthValue {
        doc /* Maximum detectable vein depth below skin surface */
    }

    attribute def ContrastRatio :> Real {
        doc /* Image contrast enhancement ratio */
    }

    attribute def BatteryCapacity :> EnergyValue {
        doc /* Battery energy storage capacity */
    }

    item def NIRPhotons {
        attribute wavelength : Wavelength;
        attribute intensity : OpticalPower;
    }

    item def RawVeinImage {
        attribute resolution : Integer;
        attribute captureTime : TimeValue;
        attribute signalStrength : Real;
    }

    item def ProcessedVeinMap {
        attribute enhancedContrast : ContrastRatio;
        attribute veinPositions : Real[*];
        attribute confidenceScore : Real;
    }

    item def ProjectedOverlay {
        attribute brightness : Real;
        attribute alignment : Real;
    }

    item def StartCommand;
    item def StopCommand;
    item def TriggerScan;
    item def ReleaseTrigger;
    item def SystemFault;
    item def ResetCommand;

    port def NIREmissionPort {
        out photons : NIRPhotons;
    }

    port def ImageInputPort {
        in reflectedPhotons : NIRPhotons;
        out rawImage : RawVeinImage;
    }

    port def ProcessingPort {
        in rawData : RawVeinImage;
        out veinMap : ProcessedVeinMap;
    }

    port def ProjectionPort {
        in veinData : ProcessedVeinMap;
        out overlay : ProjectedOverlay;
    }

    port def PowerPort {
        in powerSupply : PowerValue;
    }

    port def UserInterfacePort {
        in startCmd : StartCommand;
        in stopCmd : StopCommand;
        in brightnessAdjust : Real;
        out statusIndicator : Real;
    }

    part def NIRIlluminationModule {
        attribute emissionWavelength : Wavelength = 850 [nm];
        attribute opticalOutputPower : OpticalPower = 2.5 [W];
        attribute ledCount : Integer = 16;

        port emissionOutput : NIREmissionPort;
        port powerInput : PowerPort;

        action emitNIRLight {
            in power : PowerValue;
            out photonStream : NIRPhotons;
        }
    }

    part def NIRCameraModule {
        attribute sensorResolution : Integer = 1280;
        attribute captureFrameRate : FrameRate = 30 [Hz];
        attribute sensitivity : Real = 0.92;
        attribute exposureTime : TimeValue = 0.015 [s];

        port imageCapture : ImageInputPort;
        port powerInput : PowerPort;

        action captureNIRImage {
            in incomingPhotons : NIRPhotons;
            in exposureDuration : TimeValue;
            out capturedFrame : RawVeinImage;
        }
    }

    part def ImageProcessingUnit {
        attribute processorSpeed : FrequencyValue = 1500000000 [Hz];
        attribute algorithmVersion : String = "VeinDetect-3.2";
        attribute enhancementFactor : ContrastRatio = 4.5;

        port dataInput : ProcessingPort;
        port powerInput : PowerPort;

        action processVeinImage {
            in rawImage : RawVeinImage;
            in skinToneCalibration : Real;
            out enhancedMap : ProcessedVeinMap;

            first start;
            then action normalizeIntensity {
                in image = rawImage;
                out normalized : RawVeinImage;
            }
            then action applyContrastEnhancement {
                in image = normalizeIntensity.normalized;
                in factor = enhancementFactor;
                out enhanced : RawVeinImage;
            }
            then action detectVeinPatterns {
                in image = applyContrastEnhancement.enhanced;
                out patterns : ProcessedVeinMap;
            }
            then action filterArtifacts {
                in map = detectVeinPatterns.patterns;
                out cleanMap : ProcessedVeinMap;
            }
            then action calculateConfidence {
                in map = filterArtifacts.cleanMap;
                out scoredMap : ProcessedVeinMap;
            }
            then assign enhancedMap := calculateConfidence.scoredMap;
            then done;
        }
    }

    part def ProjectionModule {
        attribute projectorType : String = "DLP Visible Light";
        attribute projectionPower : PowerValue = 1.8 [W];
        attribute projectionArea : AreaValue = 80 [mm^2];
        attribute alignmentAccuracy : LengthValue = 0.5 [mm];

        port projectionInput : ProjectionPort;
        port powerInput : PowerPort;

        action projectVeinOverlay {
            in veinMap : ProcessedVeinMap;
            in brightnessLevel : Real;
            out projectedImage : ProjectedOverlay;
        }
    }

    part def PowerManagementSystem {
        attribute batteryVoltage : Real = 11.1;
        attribute batteryCurrent : Real = 3.0;
        attribute capacity : BatteryCapacity = 40 [W*h];
        attribute remainingCharge : Real = 100.0;

        port powerOutput : PowerPort;

        action distributePower {
            in totalDemand : PowerValue;
            out suppliedPower : PowerValue;
        }

        action monitorBattery {
            out chargeLevel : Real;
            out estimatedRuntime : TimeValue;
        }
    }

    part def SystemController {
        attribute firmwareVersion : String = "2.4.1";
        attribute calibrationProfile : String = "Standard";
        attribute operatingMode : String = "Continuous";
        attribute systemCheckPassed : Boolean;

        port userControl : UserInterfacePort;
        port powerInput : PowerPort;

        state def VeinFinderStates {
            entry; then powerOff;

            state powerOff {
                entry action shutdownAllModules;
            }

            transition powerOff_to_initialization
                first powerOff
                accept sc : StartCommand
                then initialization;

            state initialization {
                entry action performSystemCheck;
                do action calibrateSensors;
            }

            transition initialization_to_ready
                first initialization
                if systemCheckPassed
                then ready;

            state ready {
                entry action enableStandbyMode;
            }

            transition ready_to_activeScanning
                first ready
                accept ts : TriggerScan
                then activeScanning;

            state activeScanning parallel {
                state illuminationActive {
                    entry action activateNIRLEDs;
                    do action maintainIllumination;
                }

                state imagingActive {
                    do action continuousCapture;
                }

                state processingActive {
                    do action realTimeProcessing;
                }

                state projectionActive {
                    do action continuousProjection;
                }
            }

            transition activeScanning_to_ready
                first activeScanning
                accept rt : ReleaseTrigger
                then ready;

            transition ready_to_powerOff
                first ready
                accept stc : StopCommand
                then powerOff;

            transition activeScanning_to_error
                first activeScanning
                accept sf : SystemFault
                then errorState;

            state errorState {
                entry action logError;
                do action displayErrorCode;
            }

            transition error_to_powerOff
                first errorState
                accept rc : ResetCommand
                then powerOff;
        }
    }

    part def VeinFinderSystem {
        attribute maxDetectionDepth : VeinDepth;
        attribute operationalWavelength : Wavelength;
        attribute systemFrameRate : FrameRate;
        attribute totalPowerConsumption : PowerValue;

        part illuminator : NIRIlluminationModule;
        part camera : NIRCameraModule;
        part processor : ImageProcessingUnit;
        part projector : ProjectionModule;
        part powerSystem : PowerManagementSystem;
        part controller : SystemController;
    }

    part veinFinderDevice : VeinFinderSystem {
        doc /*
            Near-infrared vein finder system for medical venipuncture assistance.
            
            Primary Function:
            The system illuminates subcutaneous veins using near-infrared light at 850nm wavelength,
            which is preferentially absorbed by hemoglobin in blood vessels. The NIR camera captures
            the reflected light pattern, revealing veins as darker regions. Advanced image processing
            algorithms enhance vein contrast and filter noise. The processed vein map is then projected
            back onto the patient's skin surface in real-time as a visible light overlay, providing
            healthcare professionals with precise visual guidance for needle insertion during
            venipuncture procedures. The system operates continuously at 30 frames per second,
            ensuring real-time tracking of vein positions even with patient movement.
        */

        :>> maxDetectionDepth = 10 [mm];
        :>> operationalWavelength = 850 [nm];
        :>> systemFrameRate = 30 [Hz];
        :>> totalPowerConsumption = 12 [W];

        :>> illuminator {
            :>> emissionWavelength = veinFinderDevice::operationalWavelength;
        }

        :>> camera {
            :>> captureFrameRate = veinFinderDevice::systemFrameRate;
        }

        connection illuminationToSkin connect
            illuminator.emissionOutput to camera.imageCapture;

        connection cameraToProcessor connect
            camera.imageCapture to processor.dataInput;

        connection processorToProjector connect
            processor.dataInput to projector.projectionInput;

        connection powerDistribution1 connect
            powerSystem.powerOutput to illuminator.powerInput;

        connection powerDistribution2 connect
            powerSystem.powerOutput to camera.powerInput;

        connection powerDistribution3 connect
            powerSystem.powerOutput to processor.powerInput;

        connection powerDistribution4 connect
            powerSystem.powerOutput to projector.powerInput;

        connection powerDistribution5 connect
            powerSystem.powerOutput to controller.powerInput;

        perform action locateAndDisplayVeins {
            doc /*
                Primary system operation: continuous vein detection and projection cycle
            */

            in skinCalibration : Real;
            in userBrightness : Real;
            out veinVisualization : ProcessedVeinMap;

            first start;
            then merge continuousCycle;

            then action illuminate : illuminator.emitNIRLight {
                in power = illuminator.opticalOutputPower;
                out photonStream : NIRPhotons;
            }

            then action capture : camera.captureNIRImage {
                in incomingPhotons = illuminate.photonStream;
                in exposureDuration = camera.exposureTime;
                out capturedFrame : RawVeinImage;
            }

            then action process : processor.processVeinImage {
                in rawImage = capture.capturedFrame;
                in skinToneCalibration = skinCalibration;
                out enhancedMap : ProcessedVeinMap;
            }

            then action project : projector.projectVeinOverlay {
                in veinMap = process.enhancedMap;
                in brightnessLevel = userBrightness;
                out projectedImage : ProjectedOverlay;
            }

            then decide qualityCheck;
                if process.enhancedMap.confidenceScore >= 0.75
                    then acceptResult;
                if process.enhancedMap.confidenceScore < 0.75
                    then adjustSettings;

            action acceptResult {
                then assign veinVisualization := process.enhancedMap;
            }
            then continuousCycle;

            action adjustSettings {
                then assign skinCalibration := skinCalibration * 1.05;
            }
            then continuousCycle;
        }

        perform controller.VeinFinderStates;
    }

    requirement def FunctionalRequirement {
        doc /* System functional capabilities */
    }

    requirement def PerformanceRequirement {
        doc /* System performance specifications */
    }

    requirement def SafetyRequirement {
        doc /* Patient and operator safety requirements */
    }

    requirement def UsabilityRequirement {
        doc /* User interface and operational requirements */
    }

    requirement veinDetectionCapability : FunctionalRequirement {
        doc /*
            The system shall detect and visualize subcutaneous veins by projecting
            an enhanced real-time image overlay onto the patient's skin surface.
        */
    }

    requirement detectionDepthSpec : PerformanceRequirement {
        doc /*
            The system shall detect veins at depths up to 10 millimeters below
            the skin surface with minimum 75% confidence score.
        */
        require constraint {
            veinFinderDevice.maxDetectionDepth >= 10 [mm]
        }
    }

    requirement realTimePerformance : PerformanceRequirement {
        doc /*
            The system shall maintain a minimum frame rate of 30 Hz for
            real-time vein tracking and projection.
        */
        require constraint {
            veinFinderDevice.systemFrameRate >= 30 [Hz]
        }
    }

    requirement opticalSafety : SafetyRequirement {
        doc /*
            The NIR illumination power shall not exceed 5 Watts to ensure
            patient safety and comply with optical radiation exposure limits.
        */
        require constraint {
            veinFinderDevice.illuminator.opticalOutputPower <= 5 [W]
        }
    }

    requirement wavelengthCompliance : SafetyRequirement {
        doc /*
            The NIR emission wavelength shall be within the safe range of
            700-1000 nanometers for medical applications.
        */
        require constraint {
            veinFinderDevice.operationalWavelength >= 700 [nm] and
            veinFinderDevice.operationalWavelength <= 1000 [nm]
        }
    }

    requirement batteryLife : PerformanceRequirement {
        doc /*
            The power system shall provide minimum 3 hours of continuous
            operation at full system power consumption.
        */
        require constraint {
            veinFinderDevice.powerSystem.capacity / veinFinderDevice.totalPowerConsumption >= 3 [h]
        }
    }

    requirement projectionAccuracy : PerformanceRequirement {
        doc /*
            The projected vein overlay shall align with actual vein positions
            within 0.5 millimeters accuracy.
        */
        require constraint {
            veinFinderDevice.projector.alignmentAccuracy <= 0.5 [mm]
        }
    }

    requirement operationalReliability : UsabilityRequirement {
        doc /*
            The system shall achieve 95% uptime during active scanning sessions
            with automatic error recovery capabilities.
        */
    }

    requirement systemRequirements {
        doc /* Top-level system requirements specification */

        require veinDetectionCapability;
        require detectionDepthSpec;
        require realTimePerformance;
        require opticalSafety;
        require wavelengthCompliance;
        require batteryLife;
        require projectionAccuracy;
        require operationalReliability;
    }
}
