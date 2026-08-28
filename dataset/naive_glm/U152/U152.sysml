package ClinicalChemistryAnalyzer {
    import ScalarValues::*;

    // ---- Value types with units ----
    value type Volume :> Real { unit 'mL'; }
    value type Temperature :> Real { unit 'degC'; }
    value type Wavelength :> Real { unit 'nm'; }
    value type Absorbance :> Real { unit 'AU'; }
    value type Concentration :> Real { unit 'mg/dL'; }
    value type Duration :> Real { unit 's'; }
    value type FlowRate :> Real { unit 'mL/min'; }
    value type Power :> Real { unit 'W'; }

    // ---- Item definitions ----
    item def BiologicalSample {
        attribute sampleId : String;
        attribute sampleType : String;   // "blood", "urine", etc.
        attribute volume : Volume;
        attribute priority : Integer = 0;
    }

    item def Reagent {
        attribute reagentId : String;
        attribute reagentName : String;
        attribute volume : Volume;
        attribute targetWavelength : Wavelength;
        attribute storageTemp : Temperature;
    }

    item def ReactionMixture {
        attribute mixtureId : String;
        attribute sampleId : String;
        attribute reagentId : String;
        attribute volume : Volume;
        attribute temperature : Temperature;
    }

    item def WasteMixture {
        attribute mixtureId : String;
        attribute volume : Volume;
        attribute hazardLevel : String;
        attribute containedAt : String;
    }

    item def AbsorbanceReading {
        attribute readingId : String;
        attribute mixtureId : String;
        attribute wavelength : Wavelength;
        attribute absorbance : Absorbance;
        attribute timestamp : String;
    }

    item def AnalysisResult {
        attribute resultId : String;
        attribute sampleId : String;
        attribute analyte : String;
        attribute concentration : Concentration;
        attribute absorbance : Absorbance;
        attribute qualityFlag : String;
        attribute passedQC : Boolean;
    }

    item def CalibrationCurve {
        attribute analyte : String;
        attribute slope : Real;
        attribute intercept : Real;
        attribute validRangeMin : Absorbance;
        attribute validRangeMax : Absorbance;
    }

    // ---- Port definitions ----
    port def SampleOutPort {
        out item samples : BiologicalSample[0..*];
    }

    port def ReagentOutPort {
        out item reagent : Reagent;
    }

    port def MixtureOutPort {
        out item mixture : ReactionMixture;
    }

    port def WasteInPort {
        in item waste : WasteMixture;
    }

    port def ReadingOutPort {
        out item reading : AbsorbanceReading;
    }

    port def ResultOutPort {
        out item result : AnalysisResult;
    }

    port def CommandPort {
        in item command : String;
        out item status : String;
        out item error : String;
    }

    // ---- Sample Intake Module ----
    part def SampleIntakeModule {
        port sampleOut : SampleOutPort;
        port control : CommandPort;

        attribute queueCapacity : Integer = 100;
        attribute currentQueueSize : Integer = 0;
        attribute loadingRate : FlowRate = 2.0;

        item queue : BiologicalSample[0..*] = ();

        action def LoadSample {
            in sample : BiologicalSample;
            out delivered : BiologicalSample;
            perform {
                delivered = sample;
            }
        }

        state def SampleIntakeStates {
            entry action { currentQueueSize = queue->size(); }

            state Idle {
                transition to Loading
                    on control.command->select(c | c == "load")
                    if currentQueueSize > 0;
            }

            state Loading {
                entry action {
                    currentQueueSize = queue->size();
                }
                do action {
                    if (queue->size() > 0) {
                        sampleOut.samples->send(queue->first());
                    }
                }
                transition to Idle
                    on sampleOut.samples->send();
            }

            transition Loading->Idle
                on control.command->select(c | c == "abort");

            initial -> Idle;
        }

        exhibit SampleIntakeStates;
    }

    // ---- Reagent Delivery Module ----
    part def ReagentDeliveryModule {
        port reagentOut : ReagentOutPort;
        port control : CommandPort;

        attribute reservoirCount : Integer = 8;
        attribute dispenseVolume : Volume = 0.5;
        attribute pumpPrecision : Real = 0.01;  // mL tolerance
        attribute reservoirLevels : Volume[0..*] = ();

        item reservoirs : Reagent[0..*] = ();

        action def DispenseReagent {
            in requestedReagentId : String;
            out dispensed : Reagent;
            perform {
                for r in reservoirs {
                    if (r.reagentId == requestedReagentId) {
                        dispensed = Reagent {
                            reagentId = r.reagentId;
                            reagentName = r.reagentName;
                            volume = dispenseVolume;
                            targetWavelength = r.targetWavelength;
                            storageTemp = r.storageTemp;
                        };
                    }
                }
            }
        }

        state def ReagentDeliveryStates {
            state Idle {
                transition to Dispensing
                    on control.command->select(c | c == "dispense");
            }

            state Dispensing {
                do action {
                    reagentOut.reagent->send();
                }
                transition to Idle
                    on reagentOut.reagent->send();
            }

            transition Dispensing->Idle
                on control.error->select(e | e == "low_reagent");

            initial -> Idle;
        }

        exhibit ReagentDeliveryStates;
    }

    // ---- Mixing Chamber ----
    part def MixingChamber {
        port mixtureOut : MixtureOutPort;
        port control : CommandPort;

        attribute chamberVolume : Volume = 5.0;
        attribute mixDuration : Duration = 30.0;
        attribute mixSpeed : Integer = 1200;  // RPM

        action def MixSampleAndReagent {
            in sample : BiologicalSample;
            in reagent : Reagent;
            out mixture : ReactionMixture;
            perform {
                mixture = ReactionMixture {
                    mixtureId = "MIX-" + sample.sampleId;
                    sampleId = sample.sampleId;
                    reagentId = reagent.reagentId;
                    volume = sample.volume + reagent.volume;
                    temperature = 25.0;
                };
            }
        }

        state def MixingStates {
            state Idle {
                transition to Mixing
                    on control.command->select(c | c == "mix");
            }

            state Mixing {
                do action {
                    mixtureOut.mixture->send();
                }
                transition to Idle
                    on mixtureOut.mixture->send();
            }

            initial -> Idle;
        }

        exhibit MixingStates;
    }

    // ---- Incubation Unit ----
    part def IncubationUnit {
        port mixtureOut : MixtureOutPort;
        port control : CommandPort;

        attribute targetTemp : Temperature = 37.0;
        attribute incubationDuration : Duration = 300.0;
        attribute currentTemp : Temperature = 25.0;
        attribute elapsedTime : Duration = 0.0;
        attribute heaterPower : Power = 50.0;
        attribute tolerance : Temperature = 0.5;

        action def HeatMixture {
            in mixtureIn : ReactionMixture;
            out mixtureOut : ReactionMixture;
            perform {
                mixtureOut = ReactionMixture {
                    mixtureId = mixtureIn.mixtureId;
                    sampleId = mixtureIn.sampleId;
                    reagentId = mixtureIn.reagentId;
                    volume = mixtureIn.volume;
                    temperature = targetTemp;
                };
            }
        }

        state def IncubationStates {
            entry action {
                currentTemp = 25.0;
                elapsedTime = 0.0;
            }

            state HeatingUp {
                do action {
                    currentTemp = currentTemp + 0.5;
                }
                transition to Maintaining
                    when currentTemp >= (targetTemp - tolerance);
            }

            state Maintaining {
                entry action {
                    currentTemp = targetTemp;
                }
                do action {
                    elapsedTime = elapsedTime + 1.0;
                }
                transition to Completing
                    when elapsedTime >= incubationDuration;
            }

            state Completing {
                entry action {
                    mixtureOut.mixture->send();
                }
                transition to HeatingUp
                    on control.command->select(c | c == "reset");
            }

            transition Maintaining->Completing
                on control.command->select(c | c == "abort");

            initial -> HeatingUp;
        }

        exhibit IncubationStates;
    }

    // ---- Spectrophotometer Module ----
    part def SpectrophotometerModule {
        port readingOut : ReadingOutPort;
        port control : CommandPort;

        attribute wavelength : Wavelength = 540.0;
        attribute pathLength : Real = 1.0;  // cm
        attribute lightSourceIntensity : Real = 100.0;
        attribute detectorRange : Absorbance = 3.0;

        action def MeasureAbsorbance {
            in mixture : ReactionMixture;
            out reading : AbsorbanceReading;
            attribute measured : Absorbance;
            perform {
                measured = 0.0;  // placeholder for actual photodetector reading
                reading = AbsorbanceReading {
                    readingId = "RD-" + mixture.mixtureId;
                    mixtureId = mixture.mixtureId;
                    wavelength = wavelength;
                    absorbance = measured;
                    timestamp = "now";
                };
            }
        }

        state def SpectrophotometerStates {
            state Idle {
                transition to Measuring
                    on control.command->select(c | c == "measure");
            }

            state Measuring {
                do action {
                    readingOut.reading->send();
                }
                transition to Idle
                    on readingOut.reading->send();
            }

            transition Measuring->Idle
                on control.error->select(e | e == "lamp_failure");

            initial -> Idle;
        }

        exhibit SpectrophotometerStates;
    }

    // ---- Data Analysis Module ----
    part def DataAnalysisModule {
        port resultOut : ResultOutPort;
        port control : CommandPort;

        attribute calibrationCurves : CalibrationCurve[0..*] = ();
        attribute qcMinAbsorbance : Absorbance = 0.05;
        attribute qcMaxAbsorbance : Absorbance = 2.5;

        action def AnalyzeReading {
            in reading : AbsorbanceReading;
            in calibration : CalibrationCurve;
            out result : AnalysisResult;
            attribute rawConcentration : Concentration;
            attribute passedQC : Boolean;
            perform {
                rawConcentration = (reading.absorbance - calibration.intercept) / calibration.slope;
                passedQC = (reading.absorbance >= qcMinAbsorbance)
                    and (reading.absorbance <= qcMaxAbsorbance)
                    and (reading.absorbance >= calibration.validRangeMin)
                    and (reading.absorbance <= calibration.validRangeMax);
                result = AnalysisResult {
                    resultId = "RES-" + reading.mixtureId;
                    sampleId = reading.mixtureId;
                    analyte = calibration.analyte;
                    concentration = rawConcentration;
                    absorbance = reading.absorbance;
                    qualityFlag = if passedQC then "PASS" else "FAIL";
                    passedQC = passedQC;
                };
            }
        }

        action def SelectCalibration {
            in analyte : String;
            out selected : CalibrationCurve;
            perform {
                for c in calibrationCurves {
                    if (c.analyte == analyte) {
                        selected = c;
                    }
                }
            }
        }

        state def DataAnalysisStates {
            state Idle {
                transition to Analyzing
                    on control.command->select(c | c == "analyze");
            }

            state Analyzing {
                do action {
                    resultOut.result->send();
                }
                transition to Idle
                    on resultOut.result->send();
            }

            initial -> Idle;
        }

        exhibit DataAnalysisStates;
    }

    // ---- Waste Management Module ----
    part def WasteManagementModule {
        port wasteIn : WasteInPort;
        port control : CommandPort;

        attribute capacity : Volume = 5000.0;
        attribute currentLevel : Volume = 0.0;
        attribute containmentType : String = "biohazard";

        action def CollectWaste {
            in waste : WasteMixture;
            perform {
                currentLevel = currentLevel + waste.volume;
            }
        }

        state def WasteStates {
            state Normal {
                do action {
                    if (wasteIn.waste->isReceived()) {
                        currentLevel = currentLevel + wasteIn.waste->received().volume;
                    }
                }
                transition to Full
                    when currentLevel >= (capacity * 0.95);
            }

            state Full {
                entry action {
                    control.error->send("waste_container_full");
                }
                transition to Normal
                    on control.command->select(c | c == "emptied");
            }

            initial -> Normal;
        }

        exhibit WasteStates;
    }

    // ---- System Controller ----
    part def SystemController {
        port sampleIntakeCtrl : CommandPort;
        port reagentCtrl : CommandPort;
        port mixingCtrl : CommandPort;
        port incubationCtrl : CommandPort;
        port spectroCtrl : CommandPort;
        port analysisCtrl : CommandPort;
        port wasteCtrl : CommandPort;

        attribute throughputTarget : Integer = 120;  // tests/hour
        attribute activeTests : Integer = 0;
        attribute completedTests : Integer = 0;
        attribute errorLog : String[0..*] = ();

        action def OrchestrateTest {
            attribute testId : String;
            perform {
                sampleIntakeCtrl.command->send("load");
                reagentCtrl.command->send("dispense");
                mixingCtrl.command->send("mix");
                incubationCtrl.command->send("incubate");
                spectroCtrl.command->send("measure");
                analysisCtrl.command->send("analyze");
                wasteCtrl.command->send("collect");
                completedTests = completedTests + 1;
            }
        }

        action def HandleError {
            in errorMessage : String;
            in sourceModule : String;
            perform {
                errorLog = errorLog.append(sourceModule + ": " + errorMessage);
            }
        }

        state def ControllerStates {
            state Idle {
                transition to Running
                    on sampleIntakeCtrl.command->select(c | c == "start");
            }

            state Running {
                do action {
                    OrchestrateTest();
                }
                transition to ErrorHandling
                    on sampleIntakeCtrl.error->select(e | e != "");
                transition to ErrorHandling
                    on reagentCtrl.error->select(e | e != "");
                transition to ErrorHandling
                    on incubationCtrl.error->select(e | e != "");
                transition to ErrorHandling
                    on spectroCtrl.error->select(e | e != "");
                transition to ErrorHandling
                    on wasteCtrl.error->select(e | e != "");
                transition to Idle
                    on sampleIntakeCtrl.command->select(c | c == "stop");
            }

            state ErrorHandling {
                entry action {
                    HandleError("module_error", "system");
                }
                transition to Running
                    on sampleIntakeCtrl.command->select(c | c == "resume");
                transition to Idle
                    on sampleIntakeCtrl.command->select(c | c == "shutdown");
            }

            initial -> Idle;
        }

        exhibit ControllerStates;
    }

    // ---- Top-level Analyzer Assembly ----
    part def ClinicalChemistryAnalyzer {
        part sampleIntake : SampleIntakeModule;
        part reagentDelivery : ReagentDeliveryModule;
        part mixingChamber : MixingChamber;
        part incubationUnit : IncubationUnit;
        part spectrophotometer : SpectrophotometerModule;
        part dataAnalysis : DataAnalysisModule;
        part wasteManagement : WasteManagementModule;
        part controller : SystemController;

        // Controller connections to each module
        connection controller.sampleIntakeCtrl to sampleIntake.control;
        connection controller.reagentCtrl to reagentDelivery.control;
        connection controller.mixingCtrl to mixingChamber.control;
        connection controller.incubationCtrl to incubationUnit.control;
        connection controller.spectroCtrl to spectrophotometer.control;
        connection controller.analysisCtrl to dataAnalysis.control;
        connection controller.wasteCtrl to wasteManagement.control;

        // Process flow connections
        connection sampleIntake.sampleOut to mixingChamber.mixtureOut;  // sample flows to mixing
        connection reagentDelivery.reagentOut to mixingChamber.mixtureOut;  // reagent flows to mixing
        connection mixingChamber.mixtureOut to incubationUnit.mixtureOut;
        connection incubationUnit.mixtureOut to spectrophotometer.mixtureOut;  // mixture to spectro
        connection spectrophotometer.readingOut to dataAnalysis.resultOut;  // reading to analysis
        connection incubationUnit.mixtureOut to wasteManagement.wasteIn;  // waste routing

        // Calibration data initialization
        item glucoseCalibration : CalibrationCurve = CalibrationCurve {
            analyte = "glucose";
            slope = 0.45;
            intercept = 0.02;
            validRangeMin = 0.05;
            validRangeMax = 2.5;
        };

        attribute systemSerial : String = "CCA-2024-001";
        attribute maxThroughput : Integer = 120;
        attribute operationalStatus : String = "standby";
    }

    // ---- Requirements ----
    requirement def ThroughputRequirement {
        attribute minTestsPerHour : Integer = 100;
        subject analyzer : ClinicalChemistryAnalyzer;
        requirement {
            doc /* The analyzer shall support a minimum throughput of 100 tests per hour. */
            assert analyzer.maxThroughput >= minTestsPerHour;
        }
    }

    requirement def AccuracyRequirement {
        attribute maxCV : Real = 0.05;  // coefficient of variation
        subject analyzer : ClinicalChemistryAnalyzer;
        requirement {
            doc /* The analyzer shall achieve analytical precision with CV <= 5%. */
        }
    }

    requirement def IncubationStabilityRequirement {
        attribute tempStability : Temperature = 0.5;
        subject incubation : IncubationUnit;
        requirement {
            doc /* Incubation temperature shall be maintained within +/- 0.5 degC of target. */
            assert incubation.tolerance <= tempStability;
        }
    }

    requirement def ReagentDispensePrecisionRequirement {
        attribute maxDispenseError : Real = 0.02;  // mL
        subject reagentModule : ReagentDeliveryModule;
        requirement {
            doc /* Reagent dispensing shall be accurate within +/- 0.02 mL. */
            assert reagentModule.pumpPrecision <= maxDispenseError;
        }
    }

    requirement def WasteContainmentRequirement {
        attribute minCapacity : Volume = 4000.0;
        subject waste : WasteManagementModule;
        requirement {
            doc /* Waste container shall have minimum capacity of 4000 mL. */
            assert waste.capacity >= minCapacity;
        }
    }

    requirement def SampleIntakeQueueRequirement {
        attribute minQueueCapacity : Integer = 50;
        subject intake : SampleIntakeModule;
        requirement {
            doc /* Sample intake shall queue at least 50 samples. */
            assert intake.queueCapacity >= minQueueCapacity;
        }
    }

    requirement def EndToEndAutomationRequirement {
        subject analyzer : ClinicalChemistryAnalyzer;
        requirement {
            doc /* The analyzer shall fully automate the process from sample intake to result delivery without human intervention. */
        }
    }

    requirement package AnalyzerRequirements {
        requirement throughputReq : ThroughputRequirement;
        requirement accuracyReq : AccuracyRequirement;
        requirement incubationStabilityReq : IncubationStabilityRequirement;
        requirement reagentPrecisionReq : ReagentDispensePrecisionRequirement;
        requirement wasteContainmentReq : WasteContainmentRequirement;
        requirement sampleQueueReq : SampleIntakeQueueRequirement;
        requirement endToEndReq : EndToEndAutomationRequirement;
    }

    // ---- Verification ----
    verification def VerifyThroughput {
        subject analyzer : ClinicalChemistryAnalyzer;
        objective {
            doc /* Verify throughput meets minimum requirement. */
        }
    }

    verification def VerifyIncubationStability {
        subject incubation : IncubationUnit;
        objective {
            doc /* Verify incubation maintains target temperature within tolerance. */
        }
    }

    verification def VerifyReagentDispense {
        subject reagentModule : ReagentDeliveryModule;
        objective {
            doc /* Verify reagent dispensing accuracy. */
        }
    }
}
