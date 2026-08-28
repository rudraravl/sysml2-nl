package BiosensorDevice {
    import ScalarValues::*;
    import ScalarFunctions::*;

    // ===== Value Types and Units =====

    value def Voltage :> Real {
        :>> unit = VoltageUnit::mV;
    }

    unit def VoltageUnit {
        attribute mV : SI::Millivolt;
    }

    value def Current :> Real {
        :>> unit = CurrentUnit::nA;
    }

    unit def CurrentUnit {
        attribute nA : Real = 1e-9;
    }

    value def Concentration :> Real {
        :>> unit = ConcentrationUnit::mgPerdL;
    }

    unit def ConcentrationUnit {
        attribute mgPerdL : Real;
        attribute symbol : String = "mg/dL";
    }

    value def TimeValue :> Real {
        :>> unit = TimeUnit::s;
    }

    unit def TimeUnit {
        attribute s : Real;
        attribute symbol : String = "s";
    }

    value def ConfidenceScore :> Real {
        :>> unit = DimensionlessUnit::percent;
    }

    unit def DimensionlessUnit {
        attribute percent : Real;
    }

    value def Energy :> Real {
        :>> unit = EnergyUnit::Wh;
    }

    unit def EnergyUnit {
        attribute Wh : Real;
        attribute symbol : String = "Wh";
    }

    value def Temperature :> Real {
        :>> unit = TemperatureUnit::degC;
    }

    unit def TemperatureUnit {
        attribute degC : Real;
        attribute symbol : String = "°C";
    }

    // ===== Item Definitions =====

    item def BiologicalSample {
        attribute sampleType : SampleType;
        attribute volume : Voltage; // placeholder corrected below
        attribute temperature : Temperature;
    }

    enum def SampleType {
        blood;
        urine;
        saliva;
    }

    item def PreparedSample :> BiologicalSample {
        attribute isPrepared : Boolean = false;
        attribute pH : Real;
    }

    item def TargetSubstance {
        attribute name : String;
        attribute expectedRange : Concentration;
    }

    item def BindingEvent {
        attribute substanceName : String;
        attribute bindingStrength : Real;
        attribute timestamp : TimeValue;
    }

    item def AnalogSignal {
        attribute amplitude : Voltage;
        attribute noiseLevel : Voltage;
        attribute timestamp : TimeValue;
    }

    item def AmplifiedSignal :> AnalogSignal {
        :>> amplitude : Voltage;
        attribute gain : Real;
    }

    item def DigitalData {
        attribute rawValue : Integer;
        attribute bitDepth : Integer = 16;
        attribute timestamp : TimeValue;
    }

    item def MeasurementResult {
        attribute concentration : Concentration;
        attribute confidence : ConfidenceScore;
        attribute timestamp : TimeValue;
        attribute substanceName : String;
    }

    item def PowerCommand {
        attribute targetComponent : String;
        attribute powerLevel : Real;
    }

    item def DiagnosticStatus {
        attribute code : Integer;
        attribute message : String;
        attribute severity : SeverityLevel;
    }

    enum def SeverityLevel {
        info;
        warning;
        error;
        critical;
    }

    // ===== Port Definitions =====

    port def SamplePort {
        out item sample : BiologicalSample;
    }

    port def PreparedSamplePort {
        in item preparedSample : PreparedSample;
    }

    port def BindingPort {
        out item bindingEvent : BindingEvent;
    }

    port def AnalogSignalPort {
        out item signal : AnalogSignal;
    }

    port def AmplifiedSignalPort {
        in item amplified : AmplifiedSignal;
    }

    port def DigitalDataPort {
        out item data : DigitalData;
    }

    port def ResultPort {
        out item result : MeasurementResult;
    }

    port def DisplayPort {
        in item displayResult : MeasurementResult;
    }

    port def PowerPort {
        in item command : PowerCommand;
        out attribute voltage : Voltage;
        out attribute current : Current;
    }

    port def StatusPort {
        out item status : DiagnosticStatus;
    }

    // ===== Part Definitions =====

    part def SamplePreparationUnit {
        port in sampleIn : SamplePort;
        port out sampleOut : PreparedSamplePort;
        port pwr : PowerPort;
        port out status : StatusPort;

        attribute throughput : Real = 0.5; // mL/min
        attribute preparationTime : TimeValue = 5.0;

        action def PrepareSample {
            in rawSample : BiologicalSample;
            out prepared : PreparedSample;
            // Filtration, dilution, temperature stabilization
        }

        perform PrepareSample;

        state def PreparationStates {
            initial idle;
            state processing {
                entry { /* begin filtration and dilution */ }
                do { send PreparedSample(); }
                exit { /* signal completion */ }
            }
            state cleaning;
            transition idle to processing when sampleIn.sample != null;
            transition processing to cleaning when preparationTime >= 5.0;
            transition cleaning to idle;
        }

        exhibit PreparationStates;
    }

    part def BiorecognitionLayer {
        port in sampleIn : PreparedSamplePort;
        port out bindingOut : BindingPort;
        port pwr : PowerPort;
        port out status : StatusPort;

        attribute targetName : String = "Glucose";
        attribute bindingSites : Integer = 1000000;
        attribute specificity : Real = 0.98;
        attribute operatingTemperature : Temperature = 37.0;

        action def DetectBinding {
            in prepared : PreparedSample;
            out event : BindingEvent;
            // Selective binding of target substance to surface
        }

        perform DetectBinding;

        state def RecognitionStates {
            initial ready;
            state binding {
                do { /* biochemical interaction */ }
            }
            state saturated;
            state regenerating;
            transition ready to binding when sampleIn.preparedSample != null;
            transition binding to saturated when bindingSites <= 0;
            transition saturated to regenerating;
            transition regenerating to ready;
        }

        exhibit RecognitionStates;
    }

    part def Transducer {
        port in bindingIn : BindingPort;
        port out signalOut : AnalogSignalPort;
        port pwr : PowerPort;
        port out status : StatusPort;

        attribute sensitivity : Real = 0.1; // mV per binding event
        attribute transductionType : String = "Electrochemical";

        action def ConvertBindingToSignal {
            in event : BindingEvent;
            out signal : AnalogSignal;
        }

        perform ConvertBindingToSignal;
    }

    part def SignalAmplifier {
        port in signalIn : AnalogSignalPort;
        port out signalOut : AmplifiedSignalPort;
        port pwr : PowerPort;
        port out status : StatusPort;

        attribute gain : Real = 1000.0;
        attribute bandwidth : Real = 10000.0; // Hz
        attribute noiseFloor : Voltage = 0.001;

        action def Amplify {
            in input : AnalogSignal;
            out output : AmplifiedSignal;
        }

        perform Amplify;
    }

    part def AnalogToDigitalConverter {
        port in analogIn : AmplifiedSignalPort;
        port out digitalOut : DigitalDataPort;
        port pwr : PowerPort;
        port out status : StatusPort;

        attribute resolution : Integer = 16;
        attribute samplingRate : Real = 1000.0; // Hz
        attribute referenceVoltage : Voltage = 3.3;

        action def Convert {
            in analog : AmplifiedSignal;
            out digital : DigitalData;
        }

        perform Convert;
    }

    part def DataProcessor {
        port in dataIn : DigitalDataPort;
        port out resultOut : ResultPort;
        port pwr : PowerPort;
        port out status : StatusPort;

        attribute clockSpeed : Real = 48.0; // MHz
        attribute calibrationCurve : Real[2] = [0.0, 1.0];
        attribute algorithmVersion : String = "v2.1";

        action def ProcessData {
            in digital : DigitalData;
            out result : MeasurementResult;
            // Apply calibration, compute concentration and confidence
        }

        action def RunSelfTest {
            out status : DiagnosticStatus;
        }

        perform ProcessData;
    }

    part def DisplayInterface {
        port in resultIn : DisplayPort;
        port pwr : PowerPort;
        port out status : StatusPort;

        attribute displayType : String = "LCD";
        attribute resolution : String = "128x64";
        attribute backlight : Boolean = true;

        action def RenderResult {
            in result : MeasurementResult;
            // Render concentration, confidence, timestamp
        }

        perform RenderResult;
    }

    part def Battery {
        port out powerOut : PowerPort;
        port out status : StatusPort;

        attribute capacity : Energy = 5.0; // Wh
        attribute currentCharge : Energy = 5.0;
        attribute nominalVoltage : Voltage = 3.7;
        attribute chargeCycles : Integer = 0;

        state def BatteryStates {
            initial full;
            state discharging;
            state low;
            state depleted;
            transition full to discharging when currentCharge < capacity;
            transition discharging to low when currentCharge < (capacity * 0.2);
            transition low to depleted when currentCharge <= 0.0;
        }

        exhibit BatteryStates;
    }

    part def PowerManagementUnit {
        port in batteryIn : PowerPort;
        port out samplePrepPwr : PowerPort;
        port out biorecogPwr : PowerPort;
        port out transducerPwr : PowerPort;
        port out amplifierPwr : PowerPort;
        port out adcPwr : PowerPort;
        port out processorPwr : PowerPort;
        port out displayPwr : PowerPort;
        port out status : StatusPort;

        attribute efficiency : Real = 0.92;
        attribute totalPowerBudget : Current = 500.0; // mA
        attribute powerDistribution : Real = 0.0;

        action def DistributePower {
            in command : PowerCommand;
            out voltage : Voltage;
            out current : Current;
        }

        perform DistributePower;
    }

    // ===== Top-level Biosensor Device =====

    part def PortableBiosensorDevice {
        port in sampleIntake : SamplePort;
        port out userDisplay : DisplayPort;
        port out deviceStatus : StatusPort;

        attribute deviceName : String = "BioSense Pro";
        attribute firmwareVersion : String = "3.0.1";
        attribute serialNumber : String;
        attribute measurementInterval : TimeValue = 60.0; // for continuous monitoring
        attribute continuousMode : Boolean = false;

        part samplePreparation : SamplePreparationUnit {
            :>> sampleIn = sampleIntake;
        }

        part biorecognition : BiorecognitionLayer;
        part transducer : Transducer;
        part amplifier : SignalAmplifier;
        part adc : AnalogToDigitalConverter;
        part processor : DataProcessor;
        part display : DisplayInterface;
        part battery : Battery;
        part powerManagement : PowerManagementUnit;

        // Power connections
        connection battery.powerOut to powerManagement.batteryIn;
        connection powerManagement.samplePrepPwr to samplePreparation.pwr;
        connection powerManagement.biorecogPwr to biorecognition.pwr;
        connection powerManagement.transducerPwr to transducer.pwr;
        connection powerManagement.amplifierPwr to amplifier.pwr;
        connection powerManagement.adcPwr to adc.pwr;
        connection powerManagement.processorPwr to processor.pwr;
        connection powerManagement.displayPwr to display.pwr;

        // Signal chain connections
        connection samplePreparation.sampleOut to biorecognition.sampleIn;
        connection biorecognition.bindingOut to transducer.bindingIn;
        connection transducer.signalOut to amplifier.signalIn;
        connection amplifier.signalOut to adc.analogIn;
        connection adc.digitalOut to processor.dataIn;
        connection processor.resultOut to display.resultIn;
        connection display.resultIn to userDisplay;

        // Status aggregation
        connection samplePreparation.status to deviceStatus;
        connection biorecognition.status to deviceStatus;
        connection transducer.status to deviceStatus;
        connection amplifier.status to deviceStatus;
        connection adc.status to deviceStatus;
        connection processor.status to deviceStatus;
        connection display.status to deviceStatus;
        connection battery.status to deviceStatus;
        connection powerManagement.status to deviceStatus;

        // ===== Device-level State Machine =====

        state def DeviceOperation {
            attribute measurementCount : Integer = 0;
            attribute lastMeasurementTime : TimeValue = 0.0;
            attribute lastResult : MeasurementResult;

            initial initialization {
                entry {
                    /* Run self-tests on all subsystems */
                    /* Verify power, sensor integrity, calibration data */
                }
                do {
                    /* Execute RunSelfTest on processor */
                    /* Check battery level */
                    /* Load calibration parameters */
                }
                exit {
                    /* Transition to ready if all tests pass */
                }
            }

            state ready {
                entry { /* Clear display, show "Insert Sample" prompt */ }
                do { /* Wait for sample insertion or continuous mode trigger */ }
            }

            state measuring {
                entry { /* Start measurement sequence */ }
                do {
                    /* Sample preparation -> biorecognition -> transduction */
                    /* Amplification -> ADC -> processing -> display */
                }
                exit {
                    measurementCount = measurementCount + 1;
                    lastMeasurementTime = 0.0;
                }
            }

            state resultDisplay {
                entry { /* Render result on display */ }
                do { /* Hold result for user review */ }
            }

            state error {
                entry { /* Log error, display diagnostic message */ }
                do { /* Await user acknowledgment or reset */ }
                exit { /* Clear error condition */ }
            }

            state continuousMonitoring {
                entry { continuousMode = true; }
                do {
                    /* Automatically trigger measurements at measurementInterval */
                }
                exit { continuousMode = false; }
            }

            state powerSave {
                entry { /* Reduce power to non-essential components */ }
                do { /* Maintain minimal operation */ }
            }

            transition initialization to ready when selfTestPassed == true;
            transition initialization to error when selfTestPassed == false;
            transition ready to measuring when sampleIntake.sample != null;
            transition ready to continuousMonitoring when continuousModeRequested == true;
            transition measuring to resultDisplay when measurementComplete == true;
            transition measuring to error when faultDetected == true;
            transition resultDisplay to ready when userAcknowledged == true;
            transition resultDisplay to continuousMonitoring when continuousMode == true;
            transition continuousMonitoring to measuring when timerExpired == true;
            transition continuousMonitoring to ready when stopRequested == true;
            transition error to ready when errorResolved == true;
            transition ready to powerSave when battery.currentCharge < (battery.capacity * 0.15);
            transition powerSave to ready when battery.currentCharge > (battery.capacity * 0.25);
            transition any to error when criticalFault == true;
        }

        exhibit DeviceOperation;

        // ===== Measurement Action Sequence =====

        action def PerformMeasurement {
            in sample : BiologicalSample;
            out result : MeasurementResult;

            action prepare : SamplePreparationUnit::PrepareSample {
                in rawSample = sample;
            }
            flow prepared.sampleOut to detect.sampleIn;

            action detect : BiorecognitionLayer::DetectBinding {
                in prepared = prepare.prepared;
            }
            flow detect.bindingOut to convert.bindingIn;

            action convert : Transducer::ConvertBindingToSignal {
                in event = detect.event;
            }
            flow convert.signalOut to amplify.signalIn;

            action amplify : SignalAmplifier::Amplify {
                in input = convert.signal;
            }
            flow amplify.signalOut to digitize.analogIn;

            action digitize : AnalogToDigitalConverter::Convert {
                in analog = amplify.output;
            }
            flow digitize.digitalOut to process.dataIn;

            action process : DataProcessor::ProcessData {
                in digital = digitize.digital;
            }
            flow process.resultOut to result;
        }
    }

    // ===== Requirements =====

    requirement def BiosensorRequirement {
        attribute id : String;
        attribute text : String;
    }

    requirement def AccuracyRequirement :> BiosensorRequirement {
        :>> id = "REQ-001";
        :>> text = "The biosensor shall measure target substance concentration with an accuracy of ±5% of the true value across the operating range.";
        attribute maxErrorPercent : Real = 5.0;
        attribute operatingRangeMin : Concentration = 10.0;
        attribute operatingRangeMax : Concentration = 500.0;
    }

    requirement def ResponseTimeRequirement :> BiosensorRequirement {
        :>> id = "REQ-002";
        :>> text = "The biosensor shall complete a single measurement in under 30 seconds from sample introduction to result display.";
        attribute maxResponseTime : TimeValue = 30.0;
    }

    requirement def BatteryLifeRequirement :> BiosensorRequirement {
        :>> id = "REQ-003";
        :>> text = "The biosensor shall support at least 8 hours of continuous operation on a full battery charge.";
        attribute minOperatingTime : TimeValue = 28800.0; // 8 hours in seconds
        attribute minBatteryCapacity : Energy = 4.0;
    }

    requirement def SpecificityRequirement :> BiosensorRequirement {
        :>> id = "REQ-004";
        :>> text = "The biorecognition layer shall selectively bind the target substance with a specificity of at least 95%.";
        attribute minSpecificity : Real = 0.95;
    }

    requirement def ConfidenceScoreRequirement :> BiosensorRequirement {
        :>> id = "REQ-005";
        :>> text = "The data processor shall compute a confidence score for each measurement result.";
        attribute minConfidence : ConfidenceScore = 80.0;
    }

    requirement def ContinuousMonitoringRequirement :> BiosensorRequirement {
        :>> id = "REQ-006";
        :>> text = "The biosensor shall support continuous monitoring mode with configurable measurement intervals.";
        attribute minInterval : TimeValue = 10.0;
        attribute maxInterval : TimeValue = 3600.0;
    }

    requirement def SelfTestRequirement :> BiosensorRequirement {
        :>> id = "REQ-007";
        :>> text = "The biosensor shall perform self-diagnostics during initialization and report any detected faults.";
        attribute maxSelfTestDuration : TimeValue = 5.0;
    }

    requirement def PortabilityRequirement :> BiosensorRequirement {
        :>> id = "REQ-008";
        :>> text = "The biosensor shall be portable and self-contained with internal power.";
        attribute maxMass : Real = 0.5; // kg
        attribute maxVolume : Real = 500.0; // cm³
    }

    // ===== Requirement Satisfaction =====

    part def BiosensorSystem :> PortableBiosensorDevice {
        satisfy AccuracyRequirement {
            :>> maxErrorPercent = 3.0;
        }
        satisfy ResponseTimeRequirement {
            :>> maxResponseTime = 25.0;
        }
        satisfy BatteryLifeRequirement {
            :>> minOperatingTime = 28800.0;
            :>> minBatteryCapacity = 5.0;
        }
        satisfy SpecificityRequirement {
            :>> minSpecificity = 0.98;
        }
        satisfy ConfidenceScoreRequirement {
            :>> minConfidence = 85.0;
        }
        satisfy ContinuousMonitoringRequirement {
            :>> minInterval = 30.0;
            :>> maxInterval = 1800.0;
        }
        satisfy SelfTestRequirement {
            :>> maxSelfTestDuration = 3.0;
        }
        satisfy PortabilityRequirement {
            :>> maxMass = 0.35;
            :>> maxVolume = 350.0;
        }
    }
}
