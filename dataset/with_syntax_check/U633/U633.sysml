package ChargeCoupledDeviceSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def PixelCount :> Integer;
    attribute def ElectronCount :> Integer;
    attribute def QuantumEfficiency :> Real;
    
    attribute def PhotonFlux {
        attribute intensity : Real;
        attribute wavelengthNm : Real;
    }
    
    attribute def ChargePacket {
        attribute electrons : ElectronCount;
        attribute pixelRow : Integer;
        attribute pixelColumn : Integer;
    }
    
    item def OpticalSignal {
        attribute photonFlux : PhotonFlux;
        attribute exposureDuration : Real;
    }
    
    item def AnalogVoltage {
        attribute voltage : Real;
        attribute pixelAddress : Integer;
    }
    
    item def DigitalImageData {
        attribute pixelValues : Integer;
        attribute bitDepth : Integer;
        attribute imageWidth : PixelCount;
        attribute imageHeight : PixelCount;
    }
    
    port def OpticalPort {
        in item light : OpticalSignal;
    }
    
    port def AnalogOutputPort {
        out item signal : AnalogVoltage;
    }
    
    port def DigitalDataPort {
        out item imageData : DigitalImageData;
    }
    
    port def ClockPort {
        in attribute clockFrequency : Real;
        in attribute gateVoltage : Real;
    }
    
    part def PhotosensitiveArea {
        attribute rows : PixelCount;
        attribute columns : PixelCount;
        attribute quantumEfficiency : QuantumEfficiency;
        attribute totalPixels : Integer;
        
        port opticalInput : OpticalPort;
        
        part photosite {
            attribute chargeCapacity : ElectronCount;
            attribute accumulatedCharge : ElectronCount;
        }
        
        action def AccumulateCharge {
            in photons : OpticalSignal;
            out chargeArray : ChargePacket;
        }
    }
    
    part def VerticalShiftRegister {
        attribute numberOfStages : Integer;
        
        port clockInput : ClockPort;
        
        action def TransferChargeVertically {
            in chargeIn : ChargePacket;
            in clockPulse : Real;
            out chargeOut : ChargePacket;
        }
    }
    
    part def HorizontalShiftRegister {
        attribute numberOfStages : Integer;
        
        port clockInput : ClockPort;
        
        action def TransferChargeHorizontally {
            in chargeIn : ChargePacket;
            in clockPulse : Real;
            out serialCharge : ChargePacket;
        }
    }
    
    part def ChargeAmplifier {
        attribute gainFactor : Real;
        attribute readNoise : Real;
        
        port analogOutput : AnalogOutputPort;
        
        action def ConvertChargeToVoltage {
            in charge : ChargePacket;
            out voltage : AnalogVoltage;
        }
    }
    
    part def AnalogDigitalConverter {
        attribute resolutionBits : Integer;
        attribute conversionRate : Real;
        
        port digitalOutput : DigitalDataPort;
        
        action def DigitizeSignal {
            in analogSignal : AnalogVoltage;
            out digitalValue : Integer;
        }
    }
    
    part def CoolingSystem {
        attribute targetTemperature : Real;
        attribute coolingCapacity : Real;
        
        action def MaintainTemperature {
            in currentTemperature : Real;
            out coolingPower : Real;
        }
    }
    
    part def TimingGenerator {
        attribute masterClockFrequency : Real;
        
        action def GenerateClockSignals {
            out verticalClock : Real;
            out horizontalClock : Real;
            out adcClock : Real;
        }
    }
    
    part def ChargeCoupledDevice {
        attribute operatingTemperature : Real = 233.15;
        attribute integrationTime : Real;
        attribute readoutRate : Real;
        
        port opticalInterface : OpticalPort;
        port imageDataOutput : DigitalDataPort;
        port timingControl : ClockPort;
        
        part imagingSensor : PhotosensitiveArea {
            attribute rows = 2048;
            attribute columns = 2048;
            attribute quantumEfficiency = 0.90;
            attribute totalPixels = 4194304;
        }
        
        part verticalRegister : VerticalShiftRegister {
            attribute numberOfStages = 2048;
        }
        
        part horizontalRegister : HorizontalShiftRegister {
            attribute numberOfStages = 2048;
        }
        
        part outputAmplifier : ChargeAmplifier {
            attribute gainFactor = 3.0;
            attribute readNoise = 0.003;
        }
        
        part adc : AnalogDigitalConverter {
            attribute resolutionBits = 16;
            attribute conversionRate = 1000000.0;
        }
        
        part thermalManagement : CoolingSystem {
            attribute targetTemperature = 233.15;
            attribute coolingCapacity = 10.0;
        }
        
        part clockGenerator : TimingGenerator {
            attribute masterClockFrequency = 10000000.0;
        }
        
        connection opticalPath connect opticalInterface to imagingSensor.opticalInput;
        connection verticalTransferPath connect imagingSensor to verticalRegister;
        connection horizontalTransferPath connect verticalRegister to horizontalRegister;
        connection amplifierPath connect horizontalRegister to outputAmplifier;
        connection conversionPath connect outputAmplifier.analogOutput to adc;
        connection dataPath connect adc.digitalOutput to imageDataOutput;
        connection verticalClockPath connect timingControl to verticalRegister.clockInput;
        connection horizontalClockPath connect timingControl to horizontalRegister.clockInput;
        
        state machine def OperatingMode {
            state Idle;
            state Integration {
                entry action integrate : imagingSensor.AccumulateCharge;
            }
            state VerticalTransfer {
                entry action transferVertical : verticalRegister.TransferChargeVertically;
            }
            state HorizontalReadout {
                entry action transferHorizontal : horizontalRegister.TransferChargeHorizontally;
                do action amplify : outputAmplifier.ConvertChargeToVoltage;
                do action digitize : adc.DigitizeSignal;
            }
            state TemperatureControl {
                do action regulate : thermalManagement.MaintainTemperature;
            }
            
            transition idleToIntegration from Idle to Integration;
            transition integrationToTransfer from Integration to VerticalTransfer;
            transition verticalToHorizontal from VerticalTransfer to HorizontalReadout;
            transition horizontalToIdle from HorizontalReadout to Idle;
        }
        
        perform action imageAcquisition {
            first start;
            then action expose {
                action capturePhotons : imagingSensor.AccumulateCharge {
                    in photons;
                }
            }
            then action readoutVertical {
                action shiftVertical : verticalRegister.TransferChargeVertically {
                    in chargeIn;
                    in clockPulse;
                }
            }
            then action readoutHorizontal {
                action shiftHorizontal : horizontalRegister.TransferChargeHorizontally {
                    in chargeIn;
                    in clockPulse;
                }
            }
            then action amplifyAndConvert {
                action amplifyCharge : outputAmplifier.ConvertChargeToVoltage {
                    in charge;
                }
                then action convertToDigital : adc.DigitizeSignal {
                    in analogSignal;
                }
            }
            then action maintainCooling : thermalManagement.MaintainTemperature;
            then done;
        }
    }
    
    part ccdImager : ChargeCoupledDevice {
        attribute operatingTemperature = 233.15;
        attribute integrationTime = 0.05;
        attribute readoutRate = 50000.0;
        
        perform action continuousImaging[*] ordered references imageAcquisition;
    }
    
    requirement <'REQ-CCD-FUNC-001'> primaryImagingFunction {
        doc /* The Charge-Coupled Device system shall convert incident optical 
             * photons into a digital image by accumulating photoelectrons in 
             * a photosensitive array, transferring the charge packets through 
             * shift registers, amplifying the charge signal, and digitizing 
             * the resulting voltage to produce structured image data.
            */
        subject device : ChargeCoupledDevice;
    }
    
    requirement <'REQ-CCD-PERF-001'> quantumEfficiencyRequirement {
        doc /* The photosensitive area shall achieve a quantum efficiency 
             * of at least 85% to ensure high sensitivity to incident light.
            */
        subject sensor :>> ccdImager.imagingSensor;
        
        require constraint {
            sensor.quantumEfficiency >= 0.85
        }
    }
    
    requirement <'REQ-CCD-PERF-002'> thermalNoiseControl {
        doc /* The CCD system shall maintain operating temperature at or 
             * below 233.15 K to minimize thermally generated dark current.
            */
        subject device :>> ccdImager;
        
        require constraint {
            device.operatingTemperature <= 233.15
        }
    }
    
    requirement <'REQ-CCD-PERF-003'> readNoiseSpecification {
        doc /* The charge amplifier shall maintain read noise below 5 mV 
             * to preserve signal quality during charge-to-voltage conversion.
            */
        subject amplifier :>> ccdImager.outputAmplifier;
        
        require constraint {
            amplifier.readNoise < 0.005
        }
    }
    
    requirement <'REQ-CCD-PERF-004'> digitizationResolution {
        doc /* The analog-to-digital converter shall provide a minimum 
             * resolution of 14 bits to accurately represent signal levels.
            */
        subject converter :>> ccdImager.adc;
        
        require constraint {
            converter.resolutionBits >= 14
        }
    }
    
    satisfy primaryImagingFunction by ccdImager;
    satisfy quantumEfficiencyRequirement by ccdImager.imagingSensor;
    satisfy thermalNoiseControl by ccdImager;
    satisfy readNoiseSpecification by ccdImager.outputAmplifier;
    satisfy digitizationResolution by ccdImager.adc;
}
