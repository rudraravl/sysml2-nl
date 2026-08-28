package TruenatPlatform {

    package ValueTypes {
        value def Temperature :> Real { unit 'K'; }
        value def TemperatureCelsius :> Real { unit 'degC'; }
        value def Duration :> Real { unit 's'; }
        value def Volume :> Real {> Real { unit 'mL'; }
        value def FluorescenceIntensity :> Real { unit 'a.u.'; }
        value def ThresholdCycle :> Real { unit '1'; }
        value def Power :> Real { unit 'W'; }
        value def BatteryCharge :> Real { unit 'J'; }
        value def Percentage :> Real { unit '%'; }
        value def Frequency :> Real { unit 'Hz'; }
    }

    package Items {
        item def BiologicalSample {
            attribute sampleId : String;
            attribute sampleType : String;
            attribute collectionTime : DateTime;
        }
        item def LysisBuffer {
            attribute volume : Volume;
        }
        item def NucleicAcid {
            attribute type : String; // "DNA" or "RNA"
            attribute concentration : Real;
        }
        item def TruenatChip {
            attribute chipId : String;
            attribute targetPathogen : String;
            attribute lotNumber : String;
            attribute expirationDate : DateTime;
            attribute isUsed : Boolean := false;
        }
        item def FluorescentSignal {
            attribute intensity : FluorescenceIntensity;
            attribute cycle : Integer;
            attribute timestamp : DateTime;
        }
        item def DiagnosticResult {
            attribute outcome : DiagnosticOutcome;
            attribute pathogen : String;
            attribute ctValue : ThresholdCycle;
            attribute testTimestamp : DateTime;
        }
        enum DiagnosticOutcome {
            detected;
            notDetected;
            invalid;
        }
        item def Waste {
            attribute biohazard : Boolean := true;
        }
    }

    package Requirements {
        requirement def PortabilityRequirement {
            doc "The system shall be portable and battery-operated for field deployment.";
            attribute mass : Mass;
            constraint { mass.value <= 5.0; }
            attribute batteryLife : Duration;
            constraint { batteryLife.value >= 14400; } // 4 hours
        }
        requirement def TestTimeRequirement {
            doc "The system shall complete a diagnostic test in under one hour.";
            attribute maxTestDuration : Duration := 3600 [s];
            constraint { maxTestDuration.value <= 3600; }
        }
        requirement def DetectionAccuracyRequirement {
            doc "The system shall correctly classify diagnostic outcomes as detected, not detected, or invalid.";
            attribute sensitivity : Percentage;
            constraint { sensitivity.value >= 95.0; }
            attribute specificity : Percentage;
            constraint { specificity.value >= 98.0; }
        }
        requirement def ContainmentRequirement {
            doc "The chip-based architecture shall minimize contamination risk.";
            attribute sealedOperation : Boolean := true;
            constraint { sealedOperation == true; }
        }
        requirement def UsabilityRequirement {
            doc "The system shall be operable by users without specialized laboratory training.";
            attribute maxOperatorSteps : Integer;
            constraint { maxOperatorSteps <= 5; }
        }
        requirement def ThermalCyclingRequirement {
            doc "The thermal management unit shall perform rapid heating and cooling cycles for real-time PCR.";
            attribute heatingRate : Real; // degC/s
            constraint { heatingRate >= 2.0; }
            attribute coolingRate : Real;
            constraint { coolingRate >= 2.0; }
        }
        requirement def OpticalSensitivityRequirement {
            doc "The optical detection unit shall detect fluorescence above a defined threshold.";
            attribute detectionThreshold : FluorescenceIntensity := 100 [a.u.];
            constraint { detectionThreshold.value >= 100; }
        }
    }

    package Ports {
        port def SampleInPort {
            in item sample : Items::BiologicalSample;
        }
        port def ChipInPort {
            in item chip : Items::TruenatChip;
        }
        port def NucleicAcidOutPort {
            out item nucleicAcid : Items::NucleicAcid;
        }
        port def ChipTransferPort {
            in item chip : Items::TruenatChip;
            out item chipOut : Items::TruenatChip;
        }
        port def ThermalControlPort {
            out attribute targetTemp : ValueTypes::TemperatureCelsius;
            in attribute measuredTemp : ValueTypes::TemperatureCelsius;
        }
        port def OpticalSignalPort {
            out item signal : Items::FluorescentSignal;
        }
        port def CommandPort {
            in attribute command : String;
            out attribute status : String;
        }
        port def DisplayPort {
            out attribute message : String;
            out attribute progress : ValueTypes::Percentage;
            out item result : Items::DiagnosticResult;
        }
        port def PowerPort {
            out attribute power : ValueTypes::Power;
            in attribute charge : ValueTypes::BatteryCharge;
        }
        port def WastePort {
            out item waste : Items::Waste;
        }
    }

    package Modules {

        part def SamplePreparationUnit {
            attribute processingTime : ValueTypes::Duration := 600 [s];
            port sampleIn : Ports::SampleInPort;
            port chipIn : Ports::ChipInPort;
            port nucleicAcidOut : Ports::NucleicAcidOutPort;
            port wasteOut : Ports::WastePort;
            port command : Ports::CommandPort;

            part lysisChamber {
                attribute volume : ValueTypes::Volume := 2 [mL];
                attribute temperature : ValueTypes::TemperatureCelsius := 25 [degC];
            }
            part purificationColumn {
                attribute bindingCapacity : Real;
            }
            part pipettingMechanism {
                attribute precision : ValueTypes::Volume := 0.01 [mL];
            }

            action def PerformExtraction {
                in sample : Items::BiologicalSample;
                in chip : Items::TruenatChip;
                out nucleicAcid : Items::NucleicAcid;
                out waste : Items::Waste;

                action mixWithLysisBuffer {
                    in sample;
                    in buffer : Items::LysisBuffer;
                }
                action incubateLysis {
                    in mixture;
                    attribute duration : ValueTypes::Duration := 120 [s];
                }
                action bindNucleicAcids;
                action wash;
                action elute {
                    out nucleicAcid;
                }
                action disposeWaste {
                    out waste;
                }
                flow mixWithLysisBuffer.mixture -> incubateLysis.mixture;
                flow incubateLysis.lysed -> bindNucleicAcids.lysed;
                flow bindNucleicAcids.bound -> wash.bound;
                flow wash.washed -> elute.washed;
            }

            state extractionBehavior {
                entry; then idle;
                state idle;
                state lysing;
                state purifying;
                state loading;
                transition idle -> lysing when command.command == "startExtraction";
                transition lysing -> purifying when lysisComplete;
                transition purifying -> loading when purificationComplete;
                transition loading -> idle when loadingComplete;
            }
        }

        part def ThermalManagementUnit {
            attribute currentTemp : ValueTypes::TemperatureCelsius := 25 [degC];
            attribute heatingRate : Real := 3.0; // degC/s
            attribute coolingRate : Real := 2.5; // degC/s
            port thermalControl : Ports::ThermalControlPort;
            port command : Ports::CommandPort;
            port power : Ports::PowerPort;

            part heater {
                attribute maxTemp : ValueTypes::TemperatureCelsius := 95 [degC];
                attribute powerRating : ValueTypes::Power := 50 [W];
            }
            part cooler {
                attribute minTemp : ValueTypes::TemperatureCelsius := 4 [degC];
                attribute powerRating : ValueTypes::Power := 30 [W];
            }
            part temperatureSensor {
                attribute accuracy : ValueTypes::TemperatureCelsius := 0.1 [degC];
            }

            action def ThermalCycle {
                in targetDenaturation : ValueTypes::TemperatureCelsius := 95 [degC];
                in targetAnnealing : ValueTypes::TemperatureCelsius := 55 [degC];
                in targetExtension : ValueTypes::TemperatureCelsius := 72 [degC];
                in cycleCount : Integer;
                attribute cycleDuration : ValueTypes::Duration := 30 [s];

                action heatToDenaturation;
                action holdDenaturation {
                    attribute duration : ValueTypes::Duration := 10 [s];
                }
                action coolToAnnealing;
                action holdAnnealing {
                    attribute duration : ValueTypes::Duration := 15 [s];
                }
                action heatToExtension;
                action holdExtension {
                    attribute duration : ValueTypes::Duration := 20 [s];
                }
                flow heatToDenaturation.reached -> holdDenaturation.start;
                flow holdDenaturation.done -> coolToAnnealing.start;
                flow coolToAnnealing.reached -> holdAnnealing.start;
                flow holdAnnealing.done -> heatToExtension.start;
                flow heatToExtension.reached -> holdExtension.start;
            }

            state thermalControlState {
                entry; then standby;
                state standby;
                state heating;
                state cooling;
                state holding;
                transition standby -> heating when thermalControl.targetTemp > currentTemp;
                transition standby -> cooling when thermalControl.targetTemp < currentTemp;
                transition heating -> holding when currentTemp >= thermalControl.targetTemp;
                transition cooling -> holding when currentTemp <= thermalControl.targetTemp;
                transition holding -> standby when command.command == "stopThermal";
            }
        }

        part def AmplificationUnit {
            attribute cycleCount : Integer := 40;
            attribute amplificationTime : ValueTypes::Duration := 1800 [s];
            port chipIn : Ports::ChipTransferPort;
            port thermalControl : Ports::ThermalControlPort;
            port command : Ports::CommandPort;

            part reactionChamber {
                attribute volume : ValueTypes::Volume := 0.02 [mL];
                attribute reagentMix : String;
            }
            part pcrProcessor {
                attribute targetPathogen : String;
            }

            action def PerformPCR {
                in chip : Items::TruenatChip;
                in nucleicAcid : Items::NucleicAcid;
                out amplifiedProduct : Items::NucleicAcid;
                attribute cycle : Integer := 0;

                action initializeReaction;
                action runCycles {
                    attribute count : Integer := 40;
                }
                action finalize;
                flow initializeReaction.ready -> runCycles.start;
                flow runCycles.complete -> finalize.start;
            }

            state amplificationState {
                entry; then ready;
                state ready;
                state initializing;
                state cycling;
                state finalizing;
                transition ready -> initializing when command.command == "startPCR";
                transition initializing -> cycling when reactionReady;
                transition cycling -> finalizing when cycleCount >= 40;
                transition finalizing -> ready when amplificationComplete;
            }
        }

        part def OpticalDetectionUnit {
            attribute detectionThreshold : ValueTypes::FluorescenceIntensity := 100 [a.u.];
            attribute samplingRate : ValueTypes::Frequency := 10 [Hz];
            port signalOut : Ports::OpticalSignalPort;
            port command : Ports::CommandPort;
            port power : Ports::PowerPort;

            part excitationSource {
                attribute wavelength : Real := 470; // nm
                attribute power : ValueTypes::Power := 0.5 [W];
            }
            part fluorescenceDetector {
                attribute wavelength : Real := 520; // nm
                attribute sensitivity : ValueTypes::FluorescenceIntensity := 1 [a.u.];
            }
            part opticalFilter {
                attribute bandpass : Real := 30; // nm
            }

            action def MonitorFluorescence {
                in chip : Items::TruenatChip;
                out signals : Items::FluorescentSignal[*];
                attribute cycle : Integer := 0;

                action excite;
                action capture {
                    out signal : Items::FluorescentSignal;
                }
                action record {
                    in signal;
                    out signals;
                }
                flow excite.emitted -> capture.excited;
                flow capture.signal -> record.signal;
            }

            state detectionState {
                entry; then inactive;
                state inactive;
                state monitoring;
                state analyzing;
                transition inactive -> monitoring when command.command == "startDetection";
                transition monitoring -> analyzing when command.command == "stopDetection";
                transition analyzing -> inactive when analysisComplete;
            }
        }

        part def ControlAndProcessingUnit {
            port opticalIn : Ports::OpticalSignalPort;
            port samplePrepCmd : Ports::CommandPort;
            port amplificationCmd : Ports::CommandPort;
            port thermalCmd : Ports::CommandPort;
            port opticalCmd : Ports::CommandPort;
            port uiOut : Ports::DisplayPort;
            port power : Ports::PowerPort;

            part processor {
                attribute clockSpeed : ValueTypes::Frequency := 1000 [Hz];
                attribute memory : Real := 512; // MB
            }
            part dataAnalyzer {
                attribute algorithm : String := "thresholdCycle";
            }
            part resultInterpreter {
                attribute threshold : ValueTypes::FluorescenceIntensity := 100 [a.u.];
            }

            action def AnalyzeResult {
                in signals : Items::FluorescentSignal[*];
                out result : Items::DiagnosticResult;
                attribute ctValue : ValueTypes::ThresholdCycle;

                action computeBaseline;
                action detectThresholdCrossing {
                    out ctValue;
                }
                action classifyOutcome {
                    in ctValue;
                    out result;
                }
                flow computeBaseline.baseline -> detectThresholdCrossing.baseline;
                flow detectThresholdCrossing.ctValue -> classifyOutcome.ctValue;
            }

            action def CoordinateWorkflow {
                in sample : Items::BiologicalSample;
                in chip : Items::TruenatChip;
                out result : Items::DiagnosticResult;

                action startSamplePrep {
                    out cmd : String := "startExtraction";
                }
                action waitForPrep;
                action startAmplification {
                    out cmd : String := "startPCR";
                }
                action startThermal {
                    out cmd : String := "startThermal";
                }
                action startDetection {
                    out cmd : String := "startDetection";
                }
                action waitForCompletion;
                action analyze {
                    out result;
                }
                action report {
                    in result;
                }
                flow startSamplePrep.cmd -> waitForPrep.trigger;
                flow waitForPrep.done -> startAmplification.trigger;
                flow startAmplification.cmd -> startThermal.trigger;
                flow startThermal.cmd -> startDetection.trigger;
                flow startDetection.cmd -> waitForCompletion.trigger;
                flow waitForCompletion.done -> analyze.trigger;
                flow analyze.result -> report.result;
            }

            state systemState {
                entry; then standby;
                state standby {
                    entry; }
                state processing {
                    entry; }
                state reporting {
                    entry; }
                state error {
                    entry; }
                transition standby -> processing when uiOut.message == "startTest";
                transition processing -> reporting when analysisComplete;
                transition reporting -> standby when resultAcknowledged;
                transition standby -> error when faultDetected;
                transition processing -> error when faultDetected;
                transition error -> standby when faultCleared;
            }
        }

        part def UserInterfaceModule {
            port display : Ports::DisplayPort;
            port command : Ports::CommandPort;
            port power : Ports::PowerPort;

            part displayScreen {
                attribute resolution : String;
                attribute backlight : Boolean := true;
            }
            part inputButtons {
                attribute count : Integer := 4;
            }
            part speaker {
                attribute volume : Real;
            }

            action def DisplayProgress {
                in progress : ValueTypes::Percentage;
                in message : String;
                action updateScreen;
                action updateSpeaker;
            }

            action def PresentResult {
                in result : Items::DiagnosticResult;
                action showOutcome;
                action announceCompletion;
            }

            state uiState {
                entry; then mainScreen;
                state mainScreen;
                state testProgress;
                state resultScreen;
                transition mainScreen -> testProgress when command.command == "startTest";
                transition testProgress -> resultScreen when display.result != null;
                transition resultScreen -> mainScreen when command.command == "acknowledge";
            }
        }

        part def PowerSupply {
            attribute batteryCapacity : ValueTypes::BatteryCharge := 50000 [J];
            attribute currentCharge : ValueTypes::BatteryCharge := 50000 [J];
            attribute outputVoltage : Real := 12; // V
            port powerOut : Ports::PowerPort;

            part battery {
                attribute chemistry : String := "Li-ion";
                attribute cycles : Integer := 500;
            }
            part powerManagement {
                attribute efficiency : ValueTypes::Percentage := 90 [%];
            }

            state powerState {
                entry; then charged;
                state charged;
                state discharging;
                state lowBattery;
                state depleted;
                transition charged -> discharging when loadConnected;
                transition discharging -> lowBattery when currentCharge.value <= 10000;
                transition lowBattery -> depleted when currentCharge.value <= 0;
                transition depleted -> charged when chargingComplete;
            }
        }
    }

    package System {

        part def TruenatMolecularDiagnosticPlatform {
            doc "Portable, battery-operated molecular diagnostic platform for point-of-care infectious disease testing.";

            attribute mass : Mass := 3.5 [kg];
            attribute dimensions : String := "250mm x 200mm x 150mm";
            attribute operatingTempRange : String := "5-40 degC";

            part samplePreparationUnit : Modules::SamplePreparationUnit;
            part amplificationUnit : Modules::AmplificationUnit;
            part thermalManagementUnit : Modules::ThermalManagementUnit;
            part opticalDetectionUnit : Modules::OpticalDetectionUnit;
            part controlAndProcessingUnit : Modules::ControlAndProcessingUnit;
            part userInterface : Modules::UserInterfaceModule;
            part powerSupply : Modules::PowerSupply;

            connection samplePrepToAmplification connect samplePreparationUnit.nucleicAcidOut to amplificationUnit.chipIn;
            connection thermalToAmplification connect thermalManagementUnit.thermalControl to amplificationUnit.thermalControl;
            connection opticalToControl connect opticalDetectionUnit.signalOut to controlAndProcessingUnit.opticalIn;
            connection controlToSamplePrep connect controlAndProcessingUnit.samplePrepCmd to samplePreparationUnit.command;
            connection controlToAmplification connect controlAndProcessingUnit.amplificationCmd to amplificationUnit.command;
            connection controlToThermal connect controlAndProcessingUnit.thermalCmd to thermalManagementUnit.command;
            connection controlToOptical connect controlAndProcessingUnit.opticalCmd to opticalDetectionUnit.command;
            connection controlToUI connect controlAndProcessingUnit.uiOut to userInterface.display;
            connection uiToControl connect userInterface.command to controlAndProcessingUnit.uiOut;
            connection powerToControl connect powerSupply.powerOut to controlAndProcessingUnit.power;
            connection powerToThermal connect powerSupply.powerOut to thermalManagementUnit.power;
            connection powerToOptical connect powerSupply.powerOut to opticalDetectionUnit.power;
            connection powerToUI connect powerSupply.powerOut to userInterface.power;

            requirement portability : Requirements::PortabilityRequirement {
                attribute redefines mass := self.mass;
                attribute redefines batteryLife := 18000 [s];
            }
            requirement testTime : Requirements::TestTimeRequirement;
            requirement accuracy : Requirements::DetectionAccuracyRequirement;
            requirement containment : Requirements::ContainmentRequirement;
            requirement usability : Requirements::UsabilityRequirement {
                attribute redefines maxOperatorSteps := 3;
            }

            state operationalState {
                entry; then poweredOff;
                state poweredOff;
                state standby;
                state running;
                state resultReady;
                state maintenance;
                transition poweredOff -> standby when powerOn;
                transition standby -> running when testStarted;
                transition running -> resultReady when testComplete;
                transition resultReady -> standby when resultAcknowledged;
                transition standby -> maintenance when maintenanceRequested;
                transition maintenance -> standby when maintenanceComplete;
                transition standby -> poweredOff when powerOff;
            }
        }
    }
}
