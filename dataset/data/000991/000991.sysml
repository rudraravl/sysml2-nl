package BiosensorSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ConcentrationValue :> Real {
        attribute :>> mRef : Real;
        attribute unit : ConcentrationUnit;
    }
    
    attribute def ConcentrationUnit;
    
    item def BiologicalSample {
        attribute sampleType : SampleType;
        attribute volume : VolumeValue;
        attribute temperature : ThermodynamicTemperatureValue;
        attribute targetAnalyteConcentration : ConcentrationValue;
    }
    
    item def ProcessedSample :> BiologicalSample {
        attribute prepared : Boolean;
    }
    
    item def ElectricalSignal {
        attribute voltage : ElectricPotentialValue;
        attribute current : ElectricCurrentValue;
        attribute timestamp : TimeValue;
    }
    
    item def MeasurementData {
        attribute concentration : ConcentrationValue;
        attribute confidence : Real;
        attribute timestamp : TimeValue;
        attribute valid : Boolean;
    }
    
    attribute def SampleType;
    attribute def BloodSample :> SampleType;
    attribute def UrineSample :> SampleType;
    attribute def SalivaSample :> SampleType;
    
    attribute def CalibrationParameters {
        attribute slope : Real;
        attribute intercept : Real;
        attribute lastCalibrationTime : TimeValue;
        attribute calibrationValid : Boolean;
    }
    
    port def SampleInputPort {
        in item sample : BiologicalSample;
    }
    
    port def SampleOutputPort {
        out item processedSample : ProcessedSample;
    }
    
    port def SignalPort {
        out item signal : ElectricalSignal;
    }
    
    port def DataPort {
        out item data : MeasurementData;
    }
    
    port def PowerSupplyPort {
        in attribute voltage : ElectricPotentialValue;
        in attribute current : ElectricCurrentValue;
    }
    
    part def SamplePreparationUnit {
        attribute preparationTime : TimeValue;
        
        port sampleIn : SampleInputPort;
        port sampleOut : SampleOutputPort;
        port power : PowerSupplyPort;
        
        perform action prepareSample {
            in rawSample : BiologicalSample;
            out preparedSample : ProcessedSample;
        }
    }
    
    part def BiorecognitionLayer {
        attribute sensitivity : Real;
        attribute selectivity : Real;
        attribute bindingSites : Integer;
        attribute surfaceArea : AreaValue;
        attribute responseTime : TimeValue;
        
        port sampleIn : SampleInputPort;
        port signalOut : SignalPort;
        port power : PowerSupplyPort;
        
        perform action recognizeAnalyte {
            in sample : ProcessedSample;
            out bindingResponse : Real;
        }
    }
    
    part def Transducer {
        attribute transducerType : String;
        attribute operatingRange : ConcentrationValue[2];
        attribute responseTime : TimeValue;
        
        port signalIn : SignalPort;
        port signalOut : SignalPort;
        port power : PowerSupplyPort;
        
        perform action convertToElectrical {
            in biochemicalSignal : Real;
            out electricalSignal : ElectricalSignal;
        }
    }
    
    part def SignalAmplifier {
        attribute gain : Real;
        attribute bandwidth : FrequencyValue;
        attribute noiseLevel : ElectricPotentialValue;
        
        port signalIn : SignalPort;
        port signalOut : SignalPort;
        port power : PowerSupplyPort;
        
        perform action amplifySignal {
            in inputSignal : ElectricalSignal;
            out amplifiedSignal : ElectricalSignal;
        }
    }
    
    part def AnalogToDigitalConverter {
        attribute resolution : Integer;
        attribute samplingRate : FrequencyValue;
        
        port analogIn : SignalPort;
        port digitalOut : DataPort;
        port power : PowerSupplyPort;
        
        perform action digitizeSignal {
            in analogSignal : ElectricalSignal;
            out digitalValue : Real;
        }
    }
    
    part def DataProcessor {
        attribute calibration : CalibrationParameters;
        attribute algorithmVersion : String;
        
        port dataIn : DataPort;
        port dataOut : DataPort;
        port power : PowerSupplyPort;
        
        perform action processData {
            in rawData : Real;
            in calibrationParams : CalibrationParameters;
            out measurement : MeasurementData;
        }
    }
    
    part def DisplayInterface {
        attribute displayType : String;
        attribute resolution : Integer[2];
        
        port dataIn : DataPort;
        port power : PowerSupplyPort;
        
        perform action displayResult {
            in measurement : MeasurementData;
        }
    }
    
    part def PowerManagementUnit {
        attribute batteryCapacity : ElectricChargeValue;
        attribute currentBatteryLevel : Real;
        attribute powerConsumption : PowerValue;
        
        port powerIn : PowerSupplyPort;
        port powerOut : PowerSupplyPort[7];
        
        perform action distributePower {
            in inputPower : PowerValue;
            out outputPower : PowerValue[7];
        }
    }
    
    action def InitializeBiosensor {
        out initialized : Boolean;
        
        first start;
        then action performSelfTest {
            out testResult : Boolean;
        }
        then action loadCalibration {
            out calibrationData : CalibrationParameters;
        }
        then action warmUp {
            in warmUpTime : TimeValue;
        }
        then decide;
            if performSelfTest.testResult && loadCalibration.calibrationData.calibrationValid then setInitialized;
        action setInitialized {
            assign initialized := true;
        }
        then done;
    }
    
    action def PerformBiosensorMeasurement {
        in inputSample : BiologicalSample;
        out finalMeasurement : MeasurementData;
        
        first start;
        then action prepare : PrepareSample {
            in rawSample = inputSample;
            out preparedSample : ProcessedSample;
        }
        then action recognize : RecognizeAnalyte {
            in sample = prepare.preparedSample;
            out bindingSignal : Real;
        }
        then action transduce : ConvertBiochemicalSignal {
            in biochemicalResponse = recognize.bindingSignal;
            out electricalOutput : ElectricalSignal;
        }
        then action amplify : AmplifySignal {
            in rawSignal = transduce.electricalOutput;
            out amplifiedSignal : ElectricalSignal;
        }
        then action digitize : ConvertAnalogToDigital {
            in analogSignal = amplify.amplifiedSignal;
            out digitalData : Real;
        }
        then action process : CalculateConcentration {
            in digitalValue = digitize.digitalData;
            out result : MeasurementData;
        }
        then action display : ShowMeasurement {
            in measurement = process.result;
        }
        then assign finalMeasurement := process.result;
        then done;
    }
    
    action def PrepareSample {
        in rawSample : BiologicalSample;
        out preparedSample : ProcessedSample;
    }
    
    action def RecognizeAnalyte {
        in sample : ProcessedSample;
        out bindingSignal : Real;
    }
    
    action def ConvertBiochemicalSignal {
        in biochemicalResponse : Real;
        out electricalOutput : ElectricalSignal;
    }
    
    action def AmplifySignal {
        in rawSignal : ElectricalSignal;
        out amplifiedSignal : ElectricalSignal;
    }
    
    action def ConvertAnalogToDigital {
        in analogSignal : ElectricalSignal;
        out digitalData : Real;
    }
    
    action def CalculateConcentration {
        in digitalValue : Real;
        out result : MeasurementData;
    }
    
    action def ShowMeasurement {
        in measurement : MeasurementData;
    }
    
    action def ContinuousBiosensorMonitoring {
        in monitoringInterval : TimeValue;
        in sampleSource : BiologicalSample;
        out measurementHistory : MeasurementData[*];
        
        loop {
            accept startMonitoring;
            then action {
                action measure : PerformBiosensorMeasurement {
                    in inputSample = sampleSource;
                    out finalMeasurement : MeasurementData;
                }
                then action storeMeasurement {
                    in measurement = measure.finalMeasurement;
                }
                then action waitForNextInterval {
                    in interval = monitoringInterval;
                }
            }
            then accept stopMonitoring;
        }
    }
    
    state def BiosensorOperationalStates {
        entry; then idle;
        
        state idle {
            entry assign status := "Ready";
        }
        
        transition idle_to_initializing
            first idle
            accept initializeCommand
            then initializing;
        
        state initializing {
            entry assign status := "Initializing";
            do action initAction : InitializeBiosensor;
        }
        
        transition initializing_to_ready
            first initializing
            if initAction.initialized
            then ready;
        
        transition initializing_to_error
            first initializing
            if !initAction.initialized
            then error;
        
        state ready {
            entry assign status := "Ready for Measurement";
        }
        
        transition ready_to_measuring
            first ready
            accept measurementRequest
            then measuring;
        
        state measuring {
            entry assign status := "Measuring";
            do action measureAction : PerformBiosensorMeasurement;
        }
        
        transition measuring_to_processing
            first measuring
            then processing;
        
        state processing {
            entry assign status := "Processing Data";
            do action analyzeData {
                out valid : Boolean;
            }
        }
        
        transition processing_to_ready
            first processing
            if analyzeData.valid
            then ready;
        
        transition processing_to_error
            first processing
            if !analyzeData.valid
            then error;
        
        state error {
            entry assign status := "Error State";
            do action runDiagnostics;
        }
        
        transition error_to_idle
            first error
            accept errorCleared
            then idle;
        
        attribute status : String;
        action runDiagnostics;
    }
    
    part biosensorDevice : BiosensorDevice {
        attribute deviceId : String;
        attribute targetAnalyte : String;
        attribute measurementRange : ConcentrationValue[2];
        attribute accuracy : Real;
        attribute precision : Real;
        
        port sampleInput : SampleInputPort;
        port measurementOutput : DataPort;
        port powerInput : PowerSupplyPort;
        
        part preparationUnit : SamplePreparationUnit {
            attribute :>> preparationTime = 5.0 [SI::s];
            perform biosensorDevice.performMeasurement.prepare;
        }
        
        part recognitionLayer : BiorecognitionLayer {
            attribute :>> sensitivity = 0.98;
            attribute :>> selectivity = 0.95;
            attribute :>> bindingSites = 1000000;
            attribute :>> surfaceArea = 2.0 [SI::mm^2];
            attribute :>> responseTime = 3.0 [SI::s];
            perform biosensorDevice.performMeasurement.recognize;
        }
        
        part transducer : Transducer {
            attribute :>> transducerType = "Electrochemical";
            attribute :>> responseTime = 2.0 [SI::s];
            perform biosensorDevice.performMeasurement.transduce;
        }
        
        part amplifier : SignalAmplifier {
            attribute :>> gain = 1000.0;
            attribute :>> bandwidth = 1000.0 [SI::Hz];
            attribute :>> noiseLevel = 0.001 [SI::V];
            perform biosensorDevice.performMeasurement.amplify;
        }
        
        part adc : AnalogToDigitalConverter {
            attribute :>> resolution = 16;
            attribute :>> samplingRate = 10000.0 [SI::Hz];
            perform biosensorDevice.performMeasurement.digitize;
        }
        
        part processor : DataProcessor {
            attribute :>> algorithmVersion = "v2.1.0";
            perform biosensorDevice.performMeasurement.process;
        }
        
        part display : DisplayInterface {
            attribute :>> displayType = "LCD";
            perform biosensorDevice.performMeasurement.display;
        }
        
        part powerMgmt : PowerManagementUnit {
            attribute :>> batteryCapacity = 5000.0 [SI::C];
            attribute :>> currentBatteryLevel = 0.85;
            attribute :>> powerConsumption = 1.5 [SI::W];
        }
        
        connection sampleFlow connect sampleInput to preparationUnit.sampleIn;
        connection preparedSampleFlow connect preparationUnit.sampleOut to recognitionLayer.sampleIn;
        connection recognitionSignalFlow connect recognitionLayer.signalOut to transducer.signalIn;
        connection transducedSignalFlow connect transducer.signalOut to amplifier.signalIn;
        connection amplifiedSignalFlow connect amplifier.signalOut to adc.analogIn;
        connection digitalDataFlow connect adc.digitalOut to processor.dataIn;
        connection processedDataFlow connect processor.dataOut to display.dataIn;
        connection measurementDataFlow connect processor.dataOut to measurementOutput;
        
        connection powerDistribution1 connect powerMgmt.powerOut[1] to preparationUnit.power;
        connection powerDistribution2 connect powerMgmt.powerOut[2] to recognitionLayer.power;
        connection powerDistribution3 connect powerMgmt.powerOut[3] to transducer.power;
        connection powerDistribution4 connect powerMgmt.powerOut[4] to amplifier.power;
        connection powerDistribution5 connect powerMgmt.powerOut[5] to adc.power;
        connection powerDistribution6 connect powerMgmt.powerOut[6] to processor.power;
        connection powerDistribution7 connect powerMgmt.powerOut[7] to display.power;
        
        perform action performMeasurement : PerformBiosensorMeasurement {
            in inputSample;
            out finalMeasurement;
            
            action prepare references preparationUnit.prepareSample;
            action recognize references recognitionLayer.recognizeAnalyte;
            action transduce references transducer.convertToElectrical;
            action amplify references amplifier.amplifySignal;
            action digitize references adc.digitizeSignal;
            action process references processor.processData;
            action display references display.displayResult;
        }
        
        perform action continuousMonitoring : ContinuousBiosensorMonitoring {
            in monitoringInterval = 60.0 [SI::s];
            in sampleSource;
            out measurementHistory;
        }
        
        exhibit state operationalState : BiosensorOperationalStates;
    }
    
    part def BiosensorDevice {
        doc /*
            A biosensor device is an integrated analytical system that detects and quantifies 
            specific biological or chemical analytes in a sample. The primary function of this 
            biosensor system is to perform real-time, continuous measurement of target analyte 
            concentrations in biological samples through an integrated process of sample 
            preparation, biorecognition, signal transduction, amplification, digitization, 
            and data processing, ultimately providing accurate quantitative measurements for 
            diagnostic, monitoring, or research applications.
            
            The system operates by accepting a biological sample, preparing it for analysis, 
            exposing it to a biorecognition layer that selectively binds to the target analyte, 
            converting the biochemical binding event into an electrical signal via a transducer, 
            amplifying and digitizing that signal, processing the data using calibration 
            parameters, and displaying the final concentration measurement to the user.
        */
    }
    
    requirement <'BSR-001'> primaryFunctionalRequirement {
        doc /*
            The biosensor system shall detect and quantify target analytes in biological 
            samples with a measurement accuracy of at least 95% and precision of at least 
            90% within the specified concentration range.
        */
        
        subject device : BiosensorDevice;
        
        require constraint accuracyConstraint {
            device.accuracy >= 0.95
        }
        
        require constraint precisionConstraint {
            device.precision >= 0.90
        }
    }
    
    requirement <'BSR-002'> measurementRangeRequirement {
        doc /*
            The biosensor shall operate effectively across the specified measurement range 
            for the target analyte with consistent performance characteristics.
        */
        
        subject device : BiosensorDevice;
        
        require constraint rangeDefinition {
            device.measurementRange[1].mRef < device.measurementRange[2].mRef
        }
    }
    
    requirement <'BSR-003'> responseTimeRequirement {
        doc /*
            The biosensor shall complete a full measurement cycle from sample introduction 
            to result display within 30 seconds under normal operating conditions.
        */
        
        subject device : BiosensorDevice;
        
        require constraint totalResponseTime {
            device.preparationUnit.preparationTime.mRef + 
            device.recognitionLayer.responseTime.mRef + 
            device.transducer.responseTime.mRef <= 30.0
        }
    }
    
    requirement <'BSR-004'> powerManagementRequirement {
        doc /*
            The biosensor shall operate continuously for at least 8 hours on a single 
            battery charge under typical usage conditions.
        */
        
        subject device : BiosensorDevice;
        
        assume constraint batteryCharged {
            device.powerMgmt.currentBatteryLevel >= 0.80
        }
        
        require constraint operatingDuration {
            device.powerMgmt.batteryCapacity.mRef / device.powerMgmt.powerConsumption.mRef >= 28800.0
        }
    }
    
    requirement <'BSR-005'> dataValidityRequirement {
        doc /*
            The biosensor shall validate all measurements and only report results that 
            meet quality criteria, flagging invalid measurements for user review.
        */
        
        subject device : BiosensorDevice;
        
        require constraint validationCheck {
            device.performMeasurement.finalMeasurement.valid implies 
            device.performMeasurement.finalMeasurement.confidence >= 0.85
        }
    }
}
