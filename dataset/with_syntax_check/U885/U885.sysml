package SoftSensorSensingUnit {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def Temperature :> TemperatureValue;
    attribute def Pressure :> PressureValue;
    attribute def FlowRate :> VolumeFlowRateValue;
    attribute def Concentration :> Real;
    
    item def RawSensorData {
        attribute temperature : Temperature;
        attribute pressure : Pressure;
        attribute flowRate : FlowRate;
        attribute timestamp : String;
    }
    
    item def ProcessedData {
        attribute filteredTemperature : Temperature;
        attribute filteredPressure : Pressure;
        attribute filteredFlowRate : FlowRate;
        attribute timestamp : String;
    }
    
    item def ModelParameters {
        attribute coefficientA : Real;
        attribute coefficientB : Real;
        attribute coefficientC : Real;
        attribute calibrationDate : String;
    }
    
    item def SoftSensorOutput {
        attribute estimatedConcentration : Concentration;
        attribute confidence : Real;
        attribute timestamp : String;
        attribute quality : Real;
    }
    
    port def PhysicalInputPort {
        in item rawData : RawSensorData;
    }
    
    port def ProcessedDataPort {
        out item processedData : ProcessedData;
    }
    
    port def ModelInputPort {
        in item modelParams : ModelParameters;
    }
    
    port def EstimateOutputPort {
        out item estimate : SoftSensorOutput;
    }
    
    action def AcquireRawData {
        in rawInputs : RawSensorData;
        out sensorData : RawSensorData;
    }
    
    action def FilterAndPreprocess {
        in rawData : RawSensorData;
        out processedData : ProcessedData;
    }
    
    action def ApplyModelEstimation {
        in processedData : ProcessedData;
        in modelParameters : ModelParameters;
        out estimate : SoftSensorOutput;
    }
    
    action def ValidateOutput {
        in estimate : SoftSensorOutput;
        out validatedEstimate : SoftSensorOutput;
    }
    
    action def SoftSensorEstimation {
        in item rawInputs : RawSensorData;
        in item modelParameters : ModelParameters;
        out item finalEstimate : SoftSensorOutput;
        
        bind acquire.rawInputs = rawInputs;
        
        action acquire : AcquireRawData {
            in rawInputs;
            out sensorData;
        }
        
        flow from acquire.sensorData to filterAction.rawData;
        
        action filterAction : FilterAndPreprocess {
            in rawData;
            out processedData;
        }
        
        flow from filterAction.processedData to estimate.processedData;
        
        bind estimate.modelParameters = modelParameters;
        
        action estimate : ApplyModelEstimation {
            in processedData;
            in modelParameters;
            out estimate;
        }
        
        flow from estimate.estimate to validate.estimate;
        
        action validate : ValidateOutput {
            in estimate;
            out validatedEstimate;
        }
        
        bind validate.validatedEstimate = finalEstimate;
    }
    
    part def PhysicalSensor {
        attribute sensorId : String;
        attribute measurementRange : Real;
        attribute accuracy : Real;
        port outputPort : ProcessedDataPort;
    }
    
    part def TemperatureSensor :> PhysicalSensor {
        attribute :>> sensorId = "TEMP-001";
        attribute :>> measurementRange = 500.0;
        attribute :>> accuracy = 0.99;
    }
    
    part def PressureSensor :> PhysicalSensor {
        attribute :>> sensorId = "PRES-001";
        attribute :>> measurementRange = 10.0;
        attribute :>> accuracy = 0.98;
    }
    
    part def FlowSensor :> PhysicalSensor {
        attribute :>> sensorId = "FLOW-001";
        attribute :>> measurementRange = 100.0;
        attribute :>> accuracy = 0.97;
    }
    
    part def DataAcquisitionModule {
        attribute samplingFrequency : Real;
        port physicalInput : PhysicalInputPort;
        
        part tempSensor : TemperatureSensor[1];
        part presSensor : PressureSensor[1];
        part flowSensor : FlowSensor[1];
        
        action collectData : AcquireRawData;
    }
    
    part def SignalProcessor {
        attribute filterOrder : Real;
        attribute cutoffFrequency : Real;
        
        port dataInput : PhysicalInputPort;
        port dataOutput : ProcessedDataPort;
        
        action processSignals : FilterAndPreprocess;
    }
    
    part def MathematicalModel {
        attribute modelType : String;
        attribute modelVersion : String;
        
        port modelParamInput : ModelInputPort;
        
        action computeEstimate : ApplyModelEstimation;
    }
    
    part def ValidationModule {
        attribute validationThreshold : Real;
        attribute outlierDetection : Boolean;
        
        action validateEstimate : ValidateOutput;
    }
    
    part def SoftSensor {
        attribute sensorName : String;
        attribute targetVariable : String;
        attribute updateRate : Real;
        
        port rawDataInput : PhysicalInputPort;
        port modelCalibration : ModelInputPort;
        port estimateOutput : EstimateOutputPort;
        
        part dataAcquisition : DataAcquisitionModule[1] {
            attribute :>> samplingFrequency = 10.0;
        }
        
        part signalProcessor : SignalProcessor[1] {
            attribute :>> filterOrder = 3.0;
            attribute :>> cutoffFrequency = 5.0;
        }
        
        part mathModel : MathematicalModel[1] {
            attribute :>> modelType = "MultipleLinearRegression";
            attribute :>> modelVersion = "v3.2.1";
        }
        
        part validator : ValidationModule[1] {
            attribute :>> validationThreshold = 0.85;
            attribute :>> outlierDetection = true;
        }
        
        connect rawDataInput to dataAcquisition.physicalInput;
        connect dataAcquisition.tempSensor.outputPort to signalProcessor.dataInput;
        connect modelCalibration to mathModel.modelParamInput;
        
        perform action estimationCycle : SoftSensorEstimation;
    }
    
    state machine def SoftSensorOperatingStates {
        initial state Initialization;
        state Idle;
        state Acquiring;
        state Processing;
        state Estimating;
        state Validating;
        state OutputReady;
        state Error;
        
        transition first from Initialization to Idle;
        transition startAcquire from Idle to Acquiring;
        transition toProcessing from Acquiring to Processing;
        transition toEstimating from Processing to Estimating;
        transition toValidating from Estimating to Validating;
        transition toReady from Validating to OutputReady;
        transition toIdle from OutputReady to Idle;
        transition errorFromAcquire from Acquiring to Error;
        transition errorFromProcess from Processing to Error;
        transition errorFromEstimate from Estimating to Error;
        transition recoverFromError from Error to Idle;
    }
    
    requirement def SoftSensorAccuracyRequirement {
        doc /* The soft sensor shall estimate the target concentration 
               with accuracy within 3 percent of reference value under 
               normal operating conditions. */
        
        subject sensor : SoftSensor;
        attribute maxEstimationError : Real = 0.03;
        attribute operatingConditionRange : Real = 0.95;
    }
    
    requirement def SoftSensorResponseTimeRequirement {
        doc /* The soft sensor shall produce updated estimates within 
               200 milliseconds of receiving new sensor data. */
        
        subject sensor : SoftSensor;
        attribute maxResponseTime : Real = 0.2;
    }
    
    requirement def SoftSensorReliabilityRequirement {
        doc /* The soft sensor shall maintain continuous operation with 
               availability exceeding 99.9 percent during production cycles. */
        
        subject sensor : SoftSensor;
        attribute minAvailability : Real = 0.999;
        attribute validationRate : Real = 0.98;
    }
    
    requirement def SoftSensorCalibrationRequirement {
        doc /* The soft sensor mathematical model shall be recalibrated 
               at intervals not exceeding 30 days or after significant 
               process changes. */
        
        subject sensor : SoftSensor;
        attribute maxCalibrationInterval : Real = 30.0;
    }
    
    part sensingUnit : SoftSensor {
        attribute :>> sensorName = "ProductConcentrationSoftSensor";
        attribute :>> targetVariable = "ConcentrationInReactor";
        attribute :>> updateRate = 5.0;
        
        part :>> dataAcquisition {
            part :>> tempSensor {
                attribute :>> measurementRange = 600.0;
            }
            part :>> presSensor {
                attribute :>> measurementRange = 15.0;
            }
            part :>> flowSensor {
                attribute :>> measurementRange = 150.0;
            }
        }
        
        part :>> mathModel {
            action :>> computeEstimate {
                in item processedData;
                in item modelParameters {
                    attribute :>> coefficientA = 1.25;
                    attribute :>> coefficientB = 0.85;
                    attribute :>> coefficientC = 0.42;
                    attribute :>> calibrationDate = "2025-01-01T00:00:00Z";
                }
                out item estimate {
                    attribute :>> estimatedConcentration = 0.75;
                    attribute :>> confidence = 0.96;
                    attribute :>> timestamp = "2025-01-15T12:00:00Z";
                    attribute :>> quality = 0.94;
                }
            }
        }
        
        satisfy accuracyReq : SoftSensorAccuracyRequirement {
            subject sensor = sensingUnit;
        }
        
        satisfy responseReq : SoftSensorResponseTimeRequirement {
            subject sensor = sensingUnit;
        }
        
        satisfy reliabilityReq : SoftSensorReliabilityRequirement {
            subject sensor = sensingUnit;
        }
        
        satisfy calibrationReq : SoftSensorCalibrationRequirement {
            subject sensor = sensingUnit;
        }
    }
}
