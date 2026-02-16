package BackIlluminatedSensingUnit {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import ISQBase::*;
    private import Quantities::*;
    private import MeasurementReferences::*;
    private import UnitsAndScales::*;
    
    attribute def IrradianceValue :> ScalarQuantityValue {
        attribute :>> num : Real;
        attribute :>> mRef : IrradianceUnit;
    }
    
    attribute def IrradianceUnit :> DerivedUnit {
        attribute :>> unitPowerFactor : UnitPowerFactor[2] ordered;
    }
    
    attribute def QuantumEfficiencyValue :> ScalarQuantityValue {
        attribute :>> num : Real;
        attribute :>> mRef : QuantumEfficiencyUnit;
    }
    
    attribute def QuantumEfficiencyUnit :> SimpleUnit;
    
    attribute def PixelCountValue :> ScalarQuantityValue {
        attribute :>> num : Integer;
        attribute :>> mRef : PixelCountUnit;
    }
    
    attribute def PixelCountUnit :> SimpleUnit;
    
    attribute def WavelengthRangeValue {
        attribute minWavelength : LengthValue;
        attribute maxWavelength : LengthValue;
    }
    
    enum def SensorStateKind {
        enum idle;
        enum exposing;
        enum readout;
        enum processing;
        enum complete;
    }
    
    enum def IlluminationTypeKind {
        enum frontIlluminated;
        enum backIlluminated;
    }
    
    item def PhotonSignal {
        attribute irradiance : IrradianceValue;
        attribute wavelength : LengthValue;
        attribute intensity : PowerValue;
    }
    
    item def RawImageData {
        attribute pixelValues : Integer[*] ordered;
        attribute exposureTime : TimeValue;
        attribute timestamp : TimeValue;
    }
    
    item def ProcessedImageData {
        attribute calibratedPixels : Real[*] ordered;
        attribute measuredIrradiance : IrradianceValue;
        attribute signalToNoise : Real;
    }
    
    port def PhotonInputPort {
        in item photonSignal : PhotonSignal;
    }
    
    port def RawDataPort {
        out item rawData : RawImageData;
    }
    
    port def ProcessedDataPort {
        out item processedData : ProcessedImageData;
    }
    
    port def ControlPort {
        in attribute exposureCommand : TimeValue;
        in attribute gainSetting : Real;
        out attribute status : SensorStateKind;
    }
    
    port def PowerPort {
        in attribute voltage : ElectricPotentialValue;
        in attribute current : ElectricCurrentValue;
    }
    
    action def CapturePhotons {
        in item incomingPhotons : PhotonSignal;
        out attribute chargeAccumulated : Real;
        
        first start;
        then action absorbPhotons {
            in photons : PhotonSignal;
            out photoelectrons : Real;
        }
        then action accumulateCharge {
            in electrons : Real;
            out totalCharge : Real;
        }
        then done;
        
        flow from absorbPhotons.photoelectrons to accumulateCharge.electrons;
        bind chargeAccumulated = accumulateCharge.totalCharge;
    }
    
    action def ReadoutCharge {
        in attribute chargePattern : Real;
        out item digitalData : RawImageData;
        
        first start;
        then action amplifySignal {
            in inputCharge : Real;
            out amplifiedVoltage : ElectricPotentialValue;
        }
        then action digitizeSignal {
            in analogVoltage : ElectricPotentialValue;
            out digitalValue : Integer;
        }
        then action assembleData {
            in pixelData : Integer;
            out imageData : RawImageData;
        }
        then done;
        
        flow from amplifySignal.amplifiedVoltage to digitizeSignal.analogVoltage;
        flow from digitizeSignal.digitalValue to assembleData.pixelData;
        bind digitalData = assembleData.imageData;
    }
    
    action def ProcessImageData {
        in item rawInput : RawImageData;
        out item processedOutput : ProcessedImageData;
        
        first start;
        then fork;
            then action darkFrameCorrection {
                in raw : RawImageData;
                out corrected : Integer[*];
            }
            then joinNode;
            then action flatFieldCorrection {
                in pixels : Integer[*];
                out normalized : Real[*];
            }
            then joinNode;
            then action calculateIrradiance {
                in calibratedPixels : Real[*];
                out irradiance : IrradianceValue;
            }
            then joinNode;
        join joinNode;
        then action assembleResult {
            in finalPixels : Real[*];
            in measuredValue : IrradianceValue;
            out result : ProcessedImageData;
        }
        then done;
        
        flow from darkFrameCorrection.corrected to flatFieldCorrection.pixels;
        flow from flatFieldCorrection.normalized to calculateIrradiance.calibratedPixels;
        flow from flatFieldCorrection.normalized to assembleResult.finalPixels;
        flow from calculateIrradiance.irradiance to assembleResult.measuredValue;
        bind processedOutput = assembleResult.result;
    }
    
    part def BackIlluminatedSensor {
        attribute illuminationType : IlluminationTypeKind default IlluminationTypeKind::backIlluminated;
        attribute quantumEfficiency : QuantumEfficiencyValue;
        attribute spectralRange : WavelengthRangeValue;
        attribute pixelResolution : PixelCountValue;
        attribute darkCurrent : ElectricCurrentValue;
        attribute readNoise : Real;
        
        port photonInput : PhotonInputPort;
        port dataOutput : RawDataPort;
        
        part siliconSubstrate {
            attribute thickness : LengthValue;
            attribute dopingConcentration : Real;
        }
        
        part photodiodeArray {
            attribute pixelSize : LengthValue;
            attribute fillFactor : Real;
            attribute chargeCapacity : Real;
        }
        
        part antireflectiveCoating {
            attribute coatingThickness : LengthValue;
            attribute refractiveIndex : Real;
        }
        
        part microlensArray {
            attribute lensRadius : LengthValue;
            attribute focalLength : LengthValue;
        }
        
        perform action captureImage : CapturePhotons {
            in incomingPhotons = photonInput.photonSignal;
            out chargeAccumulated;
        }
        
        state sensorOperation {
            entry; then idle;
            
            state idle;
            transition idleToExposing
                first idle
                accept at startExposureTime
                then exposing;
            
            state exposing {
                do captureImage;
            }
            transition exposingToReadout
                first exposing
                accept at exposureCompleteTime
                then readout;
            
            state readout;
            transition readoutToIdle
                first readout
                accept at readoutCompleteTime
                then idle;
        }
    }
    
    part def ReadoutCircuitry {
        attribute amplifierGain : Real;
        attribute adcBitDepth : Integer;
        attribute samplingRate : FrequencyValue;
        
        port chargeInput;
        port digitalOutput : RawDataPort;
        
        part columnAmplifiers {
            attribute gain : Real;
            attribute bandwidth : FrequencyValue;
        }
        
        part analogToDigitalConverter {
            attribute bitDepth : Integer;
            attribute conversionRate : FrequencyValue;
            attribute referenceVoltage : ElectricPotentialValue;
        }
        
        part correlatedDoubleSampler {
            attribute samplingCapacitance : Real;
            attribute noiseReduction : Real;
        }
        
        perform action readoutData : ReadoutCharge {
            in chargePattern;
            out digitalData = digitalOutput.rawData;
        }
    }
    
    part def SignalProcessingUnit {
        attribute processingAlgorithm : String;
        attribute calibrationData : Real[*];
        
        port rawDataInput;
        port processedDataOutput : ProcessedDataPort;
        
        part noiseFilter {
            attribute filterType : String;
            attribute filterStrength : Real;
        }
        
        part calibrationModule {
            attribute darkFrameData : Integer[*];
            attribute flatFieldData : Real[*];
        }
        
        part irradianceCalculator {
            attribute conversionFactor : Real;
            attribute integrationTime : TimeValue;
        }
        
        perform action processData : ProcessImageData {
            in rawInput;
            out processedOutput = processedDataOutput.processedData;
        }
    }
    
    part def ThermalController {
        attribute targetTemperature : TemperatureValue;
        attribute coolingPower : PowerValue;
        
        port temperatureSensorPort;
        port coolerControlPort;
        
        part thermoelectricCooler {
            attribute maxCoolingCapacity : PowerValue;
            attribute efficiency : Real;
            attribute operatingVoltage : ElectricPotentialValue;
        }
        
        part temperatureSensor {
            attribute accuracy : TemperatureValue;
            attribute responseTime : TimeValue;
        }
        
        state thermalControl {
            entry; then cooling;
            
            state cooling;
            transition coolingToStabilized
                first cooling
                accept at targetReachedTime
                if targetTemperature.num <= 258.15
                then stabilized;
            
            state stabilized;
            transition stabilizedToCooling
                first stabilized
                accept at temperatureRiseTime
                if targetTemperature.num > 260.15
                then cooling;
        }
    }
    
    part sensingUnit {
        doc /* 
            Back-illuminated sensing unit for high-sensitivity irradiance measurement.
            The back-illuminated architecture allows photons to enter from the substrate
            side, avoiding obstruction by metal interconnects and achieving superior
            quantum efficiency across a broad spectral range.
        */
        
        attribute operatingTemperature : TemperatureValue default 258.15[K];
        attribute measurementRange : IrradianceValue;
        attribute measurementAccuracy : Real;
        
        port opticalInput : PhotonInputPort;
        port measurementOutput : ProcessedDataPort;
        port controlInterface : ControlPort;
        port powerInput : PowerPort;
        
        part sensor : BackIlluminatedSensor {
            attribute :>> quantumEfficiency {
                attribute :>> num = 0.92;
            }
            attribute :>> spectralRange {
                attribute :>> minWavelength = 3.0e-7[m];
                attribute :>> maxWavelength = 1.0e-6[m];
            }
            attribute :>> pixelResolution {
                attribute :>> num = 4096;
            }
            attribute :>> darkCurrent = 0.002[A];
            attribute :>> readNoise = 2.0;
            
            part :>> siliconSubstrate {
                attribute :>> thickness = 1.2e-5[m];
                attribute :>> dopingConcentration = 1.0e15;
            }
            
            part :>> photodiodeArray {
                attribute :>> pixelSize = 5.0e-6[m];
                attribute :>> fillFactor = 0.90;
                attribute :>> chargeCapacity = 50000.0;
            }
            
            part :>> antireflectiveCoating {
                attribute :>> coatingThickness = 9.0e-8[m];
                attribute :>> refractiveIndex = 1.40;
            }
            
            part :>> microlensArray {
                attribute :>> lensRadius = 2.0e-6[m];
                attribute :>> focalLength = 4.5e-6[m];
            }
        }
        
        part readout : ReadoutCircuitry {
            attribute :>> amplifierGain = 3.0;
            attribute :>> adcBitDepth = 14;
            attribute :>> samplingRate = 5.0e7[Hz];
            
            part :>> analogToDigitalConverter {
                attribute :>> bitDepth = 14;
                attribute :>> conversionRate = 5.0e7[Hz];
                attribute :>> referenceVoltage = 3.3[V];
            }
        }
        
        part processor : SignalProcessingUnit {
            attribute :>> processingAlgorithm = "adaptive_calibration";
            
            part :>> noiseFilter {
                attribute :>> filterType = "median";
                attribute :>> filterStrength = 0.5;
            }
            
            part :>> irradianceCalculator {
                attribute :>> conversionFactor = 0.85;
                attribute :>> integrationTime = 0.1[s];
            }
        }
        
        part thermalManagement : ThermalController {
            attribute :>> targetTemperature = 258.15[K];
            attribute :>> coolingPower = 4.0[W];
            
            part :>> thermoelectricCooler {
                attribute :>> maxCoolingCapacity = 6.0[W];
                attribute :>> efficiency = 0.65;
                attribute :>> operatingVoltage = 12.0[V];
            }
        }
        
        part powerRegulator {
            attribute inputVoltage : ElectricPotentialValue;
            attribute outputVoltage : ElectricPotentialValue;
            attribute efficiency : Real default 0.90;
        }
        
        connect opticalInput to sensor.photonInput;
        connect sensor.dataOutput to readout.chargeInput;
        connect readout.digitalOutput to processor.rawDataInput;
        connect processor.processedDataOutput to measurementOutput;
        connect powerInput to powerRegulator;
        
        perform action measureIrradiance {
            in scene : PhotonSignal;
            out measurement : ProcessedImageData;
            
            first start;
            then fork;
                then action initializeSystem {
                    out systemReady : Boolean;
                }
                then joinNode;
                then action stabilizeTemperature {
                    out temperatureStable : Boolean;
                }
                then joinNode;
            join joinNode;
            then action captureSequence {
                in photons : PhotonSignal;
                out result : ProcessedImageData;
                
                first start;
                then action exposureAction {
                    in incomingPhotons : PhotonSignal;
                    out chargeData : Real;
                }
                then action readoutAction {
                    in chargePattern : Real;
                    out digitalData : RawImageData;
                }
                then action processingAction {
                    in rawInput : RawImageData;
                    out processedOutput : ProcessedImageData;
                }
                then done;
                
                flow from exposureAction.chargeData to readoutAction.chargePattern;
                flow from readoutAction.digitalData to processingAction.rawInput;
                bind result = processingAction.processedOutput;
            }
            then done;
            
            bind measurement = captureSequence.result;
        }
        
        state operationalStates {
            entry; then idle;
            
            state idle {
                entry assign controlInterface.status = SensorStateKind::idle;
            }
            transition idleToExposing
                first idle
                accept at startMeasurementTime
                then exposing;
            
            state exposing {
                entry assign controlInterface.status = SensorStateKind::exposing;
            }
            transition exposingToReadout
                first exposing
                accept at exposureCompleteTime
                then readout;
            
            state readout {
                entry assign controlInterface.status = SensorStateKind::readout;
            }
            transition readoutToProcessing
                first readout
                accept at readoutCompleteTime
                then processing;
            
            state processing {
                entry assign controlInterface.status = SensorStateKind::processing;
            }
            transition processingToComplete
                first processing
                accept at processingCompleteTime
                then complete;
            
            state complete {
                entry assign controlInterface.status = SensorStateKind::complete;
            }
            transition completeToIdle
                first complete
                accept at measurementRetrievedTime
                then idle;
        }
    }
    
    requirement def QuantumEfficiencyRequirement {
        doc /* The back-illuminated sensor shall achieve quantum efficiency exceeding 90% */
        subject sensor : BackIlluminatedSensor;
        require constraint {
            sensor.quantumEfficiency.num >= 0.90
        }
    }
    
    requirement def SpectralRangeRequirement {
        doc /* The sensor shall operate across visible to near-infrared spectrum */
        subject sensor : BackIlluminatedSensor;
        require constraint {
            sensor.spectralRange.minWavelength.num <= 4.0e-7 and
            sensor.spectralRange.maxWavelength.num >= 9.0e-7
        }
    }
    
    requirement def DarkCurrentRequirement {
        doc /* Dark current shall be minimized through active cooling */
        subject unit : sensingUnit;
        require constraint {
            unit.sensor.darkCurrent.num < 0.005 and
            unit.operatingTemperature.num <= 263.15
        }
    }
    
    requirement def MeasurementAccuracyRequirement {
        doc /* The sensing unit shall maintain measurement accuracy within 2% */
        subject unit : sensingUnit;
        require constraint {
            unit.measurementAccuracy <= 0.02
        }
    }
    
    requirement def BackIlluminationRequirement {
        doc /* The sensing unit must utilize back-illuminated sensor architecture */
        subject unit : sensingUnit;
        require constraint {
            unit.sensor.illuminationType == IlluminationTypeKind::backIlluminated
        }
    }
}
