package VisualProsthesisSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ImageResolution {
        attribute width : Integer;
        attribute height : Integer;
    }
    
    attribute def StimulationParameters {
        attribute electrodeCount : Integer;
        attribute currentAmplitude : ISQ::ElectricCurrentValue;
        attribute pulseWidth : ISQ::TimeValue;
        attribute frequency : ISQ::FrequencyValue;
    }
    
    attribute def VisualFieldSpec {
        attribute horizontalDegrees : Real;
        attribute verticalDegrees : Real;
    }
    
    item def OpticalInput {
        attribute lightIntensity : Real;
        attribute wavelength : ISQ::LengthValue;
    }
    
    item def CapturedImage {
        attribute resolution : ImageResolution;
        attribute pixelData : Real[*];
        attribute timestamp : ISQ::TimeValue;
    }
    
    item def ProcessedImage {
        attribute resolution : ImageResolution;
        attribute enhancedData : Real[*];
    }
    
    item def StimulationPattern {
        attribute parameters : StimulationParameters;
        attribute electrodeMapping : Integer[*];
    }
    
    port def OpticalPort {
        in item light : OpticalInput;
    }
    
    port def ImageDataPort {
        out item image : CapturedImage;
    }
    
    port def ProcessedImagePort {
        in item rawImage : CapturedImage;
        out item processedImage : ProcessedImage;
    }
    
    port def StimulationPort {
        in item pattern : StimulationPattern;
    }
    
    port def PowerSupplyPort {
        in attribute voltage : ISQ::ElectricPotentialValue;
        in attribute current : ISQ::ElectricCurrentValue;
    }
    
    part def ExternalCamera {
        attribute fieldOfView : VisualFieldSpec {
            horizontalDegrees = 60.0;
            verticalDegrees = 45.0;
        }
        attribute frameRate : ISQ::FrequencyValue;
        
        port opticalInput : OpticalPort;
        port imageOutput : ImageDataPort;
        port power : PowerSupplyPort;
        
        action captureScene {
            in lightInput : OpticalInput;
            out capturedFrame : CapturedImage;
        }
    }
    
    part def ImageProcessingUnit {
        attribute processingLatency : ISQ::TimeValue;
        attribute algorithmVersion : String;
        
        port imageInput : ProcessedImagePort;
        port imageOutput : ProcessedImagePort;
        port power : PowerSupplyPort;
        
        action processImage {
            in rawImage : CapturedImage;
            out enhancedImage : ProcessedImage;
            
            first start;
            then action detectEdges {
                in image : CapturedImage = rawImage;
                out edges : ProcessedImage;
            }
            then action enhanceContrast {
                in image : ProcessedImage = detectEdges.edges;
                out enhanced : ProcessedImage;
            }
            then action mapToElectrodes {
                in image : ProcessedImage = enhanceContrast.enhanced;
                out mapped : ProcessedImage;
            }
            then assign enhancedImage := mapToElectrodes.mapped;
            then done;
        }
    }
    
    part def StimulusGenerator {
        attribute maxCurrent : ISQ::ElectricCurrentValue;
        attribute electrodeArraySize : Integer;
        
        port processedImageInput : ProcessedImagePort;
        port stimulationOutput : StimulationPort;
        port power : PowerSupplyPort;
        
        action generateStimulation {
            in processedImage : ProcessedImage;
            out stimPattern : StimulationPattern;
            
            first start;
            then action mapPixelsToElectrodes {
                in image : ProcessedImage = processedImage;
                out electrodeMap : Integer[*];
            }
            then action calculateCurrentLevels {
                in electrodeMap : Integer[*] = mapPixelsToElectrodes.electrodeMap;
                out currentLevels : ISQ::ElectricCurrentValue[*];
            }
            then action createStimulationPattern {
                in currentLevels : ISQ::ElectricCurrentValue[*] = calculateCurrentLevels.currentLevels;
                out pattern : StimulationPattern;
            }
            then assign stimPattern := createStimulationPattern.pattern;
            then done;
        }
    }
    
    part def RetinalElectrodeArray {
        attribute numberOfElectrodes : Integer;
        attribute electrodeSpacing : ISQ::LengthValue;
        attribute implantLocation : String;
        
        port stimulationInput : StimulationPort;
        port power : PowerSupplyPort;
        
        action activateElectrodes {
            in stimulus : StimulationPattern;
        }
        
        action deliverStimulation {
            in current : ISQ::ElectricCurrentValue;
            in duration : ISQ::TimeValue;
        }
        
        action monitorTissueResponse {
            out impedance : Real;
            out temperature : ISQ::ThermodynamicTemperatureValue;
        }
    }
    
    part def BatteryPowerUnit {
        attribute capacity : ISQ::EnergyValue;
        attribute outputVoltage : ISQ::ElectricPotentialValue;
        attribute chargeLevel : Real;
        
        port powerOutput : PowerSupplyPort[*];
        
        action managePower {
            in powerDemand : ISQ::PowerValue;
            out suppliedPower : ISQ::PowerValue;
            
            first start;
            then merge monitorLoop;
            then action checkBatteryLevel {
                out batteryLevel : Real;
            }
            then decide;
                if checkBatteryLevel.batteryLevel > 15.0 then supplyNormalPower;
                if checkBatteryLevel.batteryLevel <= 15.0 then reducePower;
            
            action supplyNormalPower {
                in demand : ISQ::PowerValue = powerDemand;
                out power : ISQ::PowerValue;
            }
            then monitorLoop;
            
            action reducePower {
                out reducedPower : ISQ::PowerValue;
            }
            then done;
        }
    }
    
    part def WirelessTransceiver {
        attribute transmissionFrequency : ISQ::FrequencyValue;
        attribute dataRate : Real;
        attribute range : ISQ::LengthValue;
        
        port power : PowerSupplyPort;
        
        action transmitImageData {
            in imageData : CapturedImage;
            out transmittedData : CapturedImage;
        }
        
        action receiveControlCommands {
            out command : String;
        }
    }
    
    part def VisualProsthesis {
        part camera : ExternalCamera {
            :>> frameRate = 30.0 [Hz];
        }
        
        part imageProcessor : ImageProcessingUnit {
            :>> processingLatency = 15.0 [ms];
            :>> algorithmVersion = "v2.3";
        }
        
        part stimulusGenerator : StimulusGenerator {
            :>> maxCurrent = 1.5 [mA];
            :>> electrodeArraySize = 60;
        }
        
        part electrodeArray : RetinalElectrodeArray {
            :>> numberOfElectrodes = 60;
            :>> electrodeSpacing = 0.5 [mm];
            :>> implantLocation = "epiretinal";
        }
        
        part battery : BatteryPowerUnit {
            :>> capacity = 600.0 [mJ];
            :>> outputVoltage = 3.7 [V];
            :>> chargeLevel = 100.0;
        }
        
        part wireless : WirelessTransceiver {
            :>> transmissionFrequency = 2.4 [GHz];
            :>> dataRate = 1000000.0;
            :>> range = 10.0 [m];
        }
        
        connect camera.imageOutput to imageProcessor.imageInput;
        connect imageProcessor.imageOutput to stimulusGenerator.processedImageInput;
        connect stimulusGenerator.stimulationOutput to electrodeArray.stimulationInput;
        connect battery.powerOutput to camera.power;
        connect battery.powerOutput to imageProcessor.power;
        connect battery.powerOutput to stimulusGenerator.power;
        connect battery.powerOutput to electrodeArray.power;
        connect battery.powerOutput to wireless.power;
        
        perform action restoreVision {
            first start;
            then action captureVisualScene {
                perform camera.captureScene;
                out sceneImage : CapturedImage;
            }
            flow captureVisualScene.sceneImage to processVisualData.rawImage;
            
            then action processVisualData {
                in rawImage : CapturedImage;
                perform imageProcessor.processImage;
                out processedImage : ProcessedImage;
            }
            flow processVisualData.processedImage to generateStimulus.processedImage;
            
            then action generateStimulus {
                in processedImage : ProcessedImage;
                perform stimulusGenerator.generateStimulation;
                out stimPattern : StimulationPattern;
            }
            flow generateStimulus.stimPattern to deliverStimulation.pattern;
            
            then action deliverStimulation {
                in pattern : StimulationPattern;
                perform electrodeArray.activateElectrodes;
            }
            then done;
        }
    }
    
    requirement <'VP-REQ-001'> primaryFunctionRequirement {
        doc /* The visual prosthesis system shall restore functional vision to individuals 
             with retinal degenerative diseases by capturing visual scenes, processing them 
             into optimized images, and converting them into electrical stimulation patterns 
             that are delivered to the retina to elicit visual perception. */
        
        subject prosthesisSystem;
        
        require spatialResolutionRequirement;
        require temporalResponseRequirement;
        require biocompatibilitySafetyRequirement;
    }
    
    requirement <'VP-REQ-002'> spatialResolutionRequirement {
        doc /* The system shall provide a minimum spatial resolution of 60 electrodes 
             arranged in an array to enable basic object recognition and navigation tasks. */
        
        assume constraint {
            prosthesisSystem.electrodeArray.numberOfElectrodes >= 60
        }
    }
    
    requirement <'VP-REQ-003'> temporalResponseRequirement {
        doc /* The system shall process and deliver visual information at a minimum rate 
             of 30 frames per second to support perception of dynamic scenes and movement. */
        
        assume constraint {
            prosthesisSystem.camera.frameRate >= 30.0 [Hz]
        }
    }
    
    requirement <'VP-REQ-004'> biocompatibilitySafetyRequirement {
        doc /* The electrical stimulation delivered to retinal tissue shall remain within 
             safe charge density limits to prevent tissue damage, with maximum current 
             amplitude not exceeding 1.5 mA and pulse width not exceeding 1.0 ms. */
        
        assume constraint {
            prosthesisSystem.stimulusGenerator.maxCurrent <= 1.5 [mA]
        }
    }
    
    requirement <'VP-REQ-005'> operationalDurationRequirement {
        doc /* The system shall operate continuously for a minimum of 8 hours on a single 
             battery charge to support typical daily usage patterns. */
        
        assume constraint {
            prosthesisSystem.battery.capacity >= 600.0 [mJ]
        }
    }
    
    requirement <'VP-REQ-006'> processingLatencyRequirement {
        doc /* The end-to-end latency from image capture to retinal stimulation shall not 
             exceed 50 milliseconds to maintain real-time visual perception. */
        
        assume constraint {
            prosthesisSystem.imageProcessor.processingLatency <= 50.0 [ms]
        }
    }
    
    part prosthesisSystem : VisualProsthesis {
        satisfy primaryFunctionRequirement;
    }
}
