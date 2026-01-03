package NuclearDensityGaugeSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def RadiationIntensity :> Real {
        doc /* Measured radiation intensity in counts per second */
    }
    
    attribute def MaterialDensity :> Real {
        doc /* Calculated material density in kg/m³ */
    }
    
    attribute def MoisturePercentage :> Real {
        doc /* Calculated moisture content as percentage by mass */
    }
    
    attribute def DepthSetting :> LengthValue {
        doc /* Measurement depth below surface */
    }
    
    item def GammaRay {
        attribute energy : EnergyValue;
        attribute intensity : RadiationIntensity;
    }
    
    item def ScatteredRadiation {
        attribute backscatterIntensity : RadiationIntensity;
        attribute transmissionIntensity : RadiationIntensity;
    }
    
    attribute def CalibrationParameters {
        attribute standardDensity : MaterialDensity;
        attribute standardCountRate : RadiationIntensity;
        attribute moistureCalibrationFactor : Real;
    }
    
    attribute def MeasurementMode {
        attribute backscatterMode : Boolean;
        attribute directTransmissionMode : Boolean;
    }
    
    attribute def OpenCommand;
    attribute def CloseCommand;
    attribute def AuthorizationCode;
    attribute def MeasurementStart;
    attribute def MeasurementComplete;
    
    port def RadiationEmissionPort {
        out gammaRays : GammaRay;
    }
    
    port def RadiationReceptionPort {
        in scatteredRadiation : ScatteredRadiation;
    }
    
    port def ControlPort {
        in measurementCommand : Boolean;
        in depthSetting : DepthSetting;
        in mode : MeasurementMode;
    }
    
    port def DataPort {
        out density : MaterialDensity;
        out moisture : MoisturePercentage;
        out status : String;
    }
    
    part def RadioactiveSource {
        doc /* Sealed radioactive isotope source (typically Cesium-137 or Americium-241) */
        attribute isotopeType : String;
        attribute sourceActivity : Real;
        attribute sourceHalfLife : TimeValue;
        port emissionPort : RadiationEmissionPort;
        
        action emitGammaRadiation {
            out emittedRays : GammaRay;
        }
    }
    
    part def RadiationShield {
        doc /* Lead or tungsten shielding with controlled shutter mechanism */
        attribute shutterPosition : ShutterState;
        attribute shieldThickness : LengthValue;
        
        state shutterControl {
            entry; then closed;
            
            state closed {
                entry assign shutterPosition := ShutterState::closed;
            }
            
            state opening;
            transition closed_to_opening
                first closed
                accept at openCmd : OpenCommand
                then opening;
            
            state open {
                entry assign shutterPosition := ShutterState::open;
            }
            transition opening_to_open
                first opening
                then open;
            
            state closing;
            transition open_to_closing
                first open
                accept at closeCmd : CloseCommand
                then closing;
            
            transition closing_to_closed
                first closing
                then closed;
        }
    }
    
    attribute def ShutterState {
        attribute closed : Boolean;
        attribute open : Boolean;
        attribute transitioning : Boolean;
    }
    
    part def ScintillationDetector {
        doc /* Geiger-Mueller tube or scintillation crystal detector */
        attribute detectorType : String;
        attribute detectionEfficiency : Real;
        port receptionPort : RadiationReceptionPort;
        
        action detectRadiation {
            in incidentRadiation : ScatteredRadiation;
            out countRate : RadiationIntensity;
        }
    }
    
    part def SignalProcessor {
        doc /* Amplifies and processes detector signals */
        attribute amplificationGain : Real;
        
        action processSignal {
            in rawCounts : RadiationIntensity;
            out processedCounts : RadiationIntensity;
        }
    }
    
    part def ComputationUnit {
        doc /* Microprocessor-based unit for density and moisture calculation */
        attribute calibration : CalibrationParameters;
        
        action calculateDensity {
            in detectedCounts : RadiationIntensity;
            in depth : DepthSetting;
            in calibrationData : CalibrationParameters;
            out density : MaterialDensity;
        }
        
        action calculateMoisture {
            in thermalNeutronCounts : RadiationIntensity;
            in calibrationData : CalibrationParameters;
            out moisture : MoisturePercentage;
        }
    }
    
    part def UserInterface {
        doc /* Display and control panel for operator interaction */
        attribute displayBrightness : Real;
        
        action displayResults {
            in density : MaterialDensity;
            in moisture : MoisturePercentage;
        }
        
        action acceptUserInput {
            out depth : DepthSetting;
            out mode : MeasurementMode;
            out startCommand : Boolean;
        }
    }
    
    part def SafetyInterlock {
        doc /* Safety system to prevent unauthorized radiation exposure */
        attribute interlockEngaged : Boolean;
        
        state safetyStateMachine {
            entry; then safe;
            
            state safe {
                entry assign interlockEngaged := true;
            }
            
            state armed;
            transition safe_to_armed
                first safe
                accept at authCode : AuthorizationCode
                then armed;
            
            state measuring {
                entry assign interlockEngaged := false;
            }
            transition armed_to_measuring
                first armed
                accept at measStart : MeasurementStart
                then measuring;
            
            transition measuring_to_safe
                first measuring
                accept at measComplete : MeasurementComplete
                then safe;
        }
    }
    
    part nuclearDensityGauge {
        doc /* Nuclear density gauge system for non-destructive measurement of material density and moisture content in soil, asphalt, and concrete */
        
        part gammaSource : RadioactiveSource {
            attribute isotopeType = "Cesium-137";
            attribute sourceActivity = 10.0;
            attribute sourceHalfLife = 30.17 [SI::yr];
        }
        
        part shield : RadiationShield {
            attribute shieldThickness = 50.0 [SI::mm];
        }
        
        part gammaDetector : ScintillationDetector {
            attribute detectorType = "NaI Scintillation Crystal";
            attribute detectionEfficiency = 0.85;
        }
        
        part signalProc : SignalProcessor {
            attribute amplificationGain = 100.0;
        }
        
        part computer : ComputationUnit {
            attribute calibration : CalibrationParameters {
                attribute standardDensity = 2400.0;
                attribute standardCountRate = 5000.0;
                attribute moistureCalibrationFactor = 1.2;
            }
        }
        
        part ui : UserInterface {
            attribute displayBrightness = 0.8;
        }
        
        part safetySystem : SafetyInterlock;
        
        port controlInterface : ControlPort;
        port dataInterface : DataPort;
        
        connect gammaSource.emissionPort to gammaDetector.receptionPort;
        
        action performDensityMeasurement {
            in measurementDepth : DepthSetting;
            in operationMode : MeasurementMode;
            out densityResult : MaterialDensity;
            out moistureResult : MoisturePercentage;
            
            first start;
            
            then action initializeSafety {
                send AuthorizationCode() to safetySystem;
            }
            
            then action openShutter {
                send OpenCommand() to shield;
            }
            
            then action emitRadiation {
                perform gammaSource.emitGammaRadiation {
                    out emittedRays;
                }
            }
            
            then action detectScatteredRadiation {
                perform gammaDetector.detectRadiation {
                    in incidentRadiation;
                    out detectedCountRate : RadiationIntensity;
                }
            }
            
            then action processDetectorSignal {
                perform signalProc.processSignal {
                    in rawCounts = detectScatteredRadiation.detectedCountRate;
                    out signalProcessedCounts : RadiationIntensity;
                }
            }
            
            then action computeDensity {
                perform computer.calculateDensity {
                    in detectedCounts = processDetectorSignal.signalProcessedCounts;
                    in depth = measurementDepth;
                    in calibrationData = computer.calibration;
                    out computedDensity : MaterialDensity;
                }
            }
            
            then action computeMoisture {
                perform computer.calculateMoisture {
                    in thermalNeutronCounts = processDetectorSignal.signalProcessedCounts;
                    in calibrationData = computer.calibration;
                    out computedMoisture : MoisturePercentage;
                }
            }
            
            then action displayMeasurements {
                perform ui.displayResults {
                    in density = computeDensity.computedDensity;
                    in moisture = computeMoisture.computedMoisture;
                }
                then assign densityResult := computeDensity.computedDensity;
                then assign moistureResult := computeMoisture.computedMoisture;
            }
            
            then action closeShutter {
                send CloseCommand() to shield;
            }
            
            then action completeSafety {
                send MeasurementComplete() to safetySystem;
            }
            
            then done;
        }
    }
    
    requirement <'NDG-REQ-001'> primaryFunction {
        doc /* The nuclear density gauge shall measure the in-situ density and moisture content 
               of construction materials including soil, asphalt, and concrete through controlled 
               emission and detection of gamma radiation and thermal neutrons in a non-destructive manner. */
        
        subject gauge : nuclearDensityGauge;
        
        require constraint densityMeasurementCapability {
            doc /* System shall measure material density within operational range */
            gauge.performDensityMeasurement.densityResult >= 1200.0 and
            gauge.performDensityMeasurement.densityResult <= 2800.0
        }
        
        require constraint moistureMeasurementCapability {
            doc /* System shall measure moisture content as percentage */
            gauge.performDensityMeasurement.moistureResult >= 0.0 and
            gauge.performDensityMeasurement.moistureResult <= 30.0
        }
        
        require constraint nonDestructiveTesting {
            doc /* Measurement shall not alter or damage the tested material */
            true
        }
    }
    
    requirement <'NDG-REQ-002'> measurementAccuracy {
        doc /* The system shall provide density measurements accurate to within ±1.5% 
               and moisture measurements accurate to within ±0.5% of actual values 
               under standard operating conditions. */
        
        subject gauge : nuclearDensityGauge;
    }
    
    requirement <'NDG-REQ-003'> radiationSafety {
        doc /* The system shall maintain radiation exposure levels below regulatory limits 
               through proper shielding and interlock mechanisms, with shutter closed 
               except during active measurement operations. */
        
        subject shield : RadiationShield;
        subject safetyInterlock : SafetyInterlock;
        
        require constraint shutterDefaultClosed {
            doc /* Shutter must default to closed position */
            shield.shutterPosition.closed == true
        }
        
        require constraint interlockEngagement {
            doc /* Safety interlock must be engaged when not measuring */
            safetyInterlock.interlockEngaged == true
        }
    }
    
    requirement <'NDG-REQ-004'> operationalDepthRange {
        doc /* The system shall support measurement depths from 50mm to 300mm 
               below the material surface for density determination. */
        
        subject gauge : nuclearDensityGauge;
    }
    
    action def OperateNuclearDensityGauge {
        in targetDepth : DepthSetting;
        in operationMode : MeasurementMode;
        out measuredDensity : MaterialDensity;
        out measuredMoisture : MoisturePercentage;
    }
    
    action operateGauge : OperateNuclearDensityGauge {
        in targetDepth : DepthSetting = 150.0 [SI::mm];
        in operationMode : MeasurementMode;
        out measuredDensity : MaterialDensity;
        out measuredMoisture : MoisturePercentage;
        
        first start;
        
        then action performSystemCheck {
            doc /* Verify system integrity and calibration status */
        }
        
        then action executeMeasurementSequence {
            perform nuclearDensityGauge.performDensityMeasurement {
                in measurementDepth = targetDepth;
                in operationMode = operationMode;
                out densityResult;
                out moistureResult;
            }
        }
        
        then action recordAndReportResults {
            assign measuredDensity := executeMeasurementSequence.densityResult;
            assign measuredMoisture := executeMeasurementSequence.moistureResult;
        }
        
        then done;
    }
}
