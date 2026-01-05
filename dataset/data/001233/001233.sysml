package 'Scanning SQUID Microscope System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import SequenceFunctions::*;
    
    attribute def MagneticFluxValue :> ISQ::MagneticFluxValue;
    attribute def MagneticFieldValue :> ISQ::MagneticFluxDensityValue;
    attribute def CryoTemperatureValue :> ISQ::ThermodynamicTemperatureValue;
    attribute def PositionValue :> ISQ::LengthValue;
    attribute def ScanStepValue :> ISQ::LengthValue;
    attribute def SensitivityValue :> ISQ::MagneticFluxValue;
    
    attribute def StartScanCommand;
    attribute def StopScanCommand;
    attribute def CooldownCommand;
    attribute def WarmupCommand;
    
    item def ScanParameters {
        attribute startX : PositionValue;
        attribute startY : PositionValue;
        attribute endX : PositionValue;
        attribute endY : PositionValue;
        attribute stepSize : ScanStepValue;
        attribute dwellTime :> ISQ::time;
    }
    
    item def MagneticDataPoint {
        attribute xPosition : PositionValue;
        attribute yPosition : PositionValue;
        attribute fieldValue : MagneticFieldValue;
        attribute timestamp :> ISQ::time;
    }
    
    item def MagneticFieldImage {
        attribute dataPoints : MagneticDataPoint[*];
        attribute scanParams : ScanParameters;
        attribute acquisitionTime :> ISQ::time;
    }
    
    item def SampleSpecimen {
        attribute sampleID : String;
        attribute thickness :> ISQ::length;
        attribute materialType : String;
    }
    
    port def CryogenicInterfacePort {
        attribute temperature : CryoTemperatureValue;
        attribute coolingPower :> ISQ::power;
    }
    
    port def SensorOutputPort {
        out magneticFlux : MagneticFluxValue;
        out sensorVoltage :> ISQ::voltage;
    }
    
    port def PositionControlPort {
        in commandX : PositionValue;
        in commandY : PositionValue;
        in commandZ : PositionValue;
        out actualX : PositionValue;
        out actualY : PositionValue;
        out actualZ : PositionValue;
    }
    
    port def DataCollectionPort {
        in fluxData : MagneticFluxValue;
        in positionX : PositionValue;
        in positionY : PositionValue;
        out imageData : MagneticFieldImage;
    }
    
    part def SQUIDSensorHead {
        attribute fluxSensitivity : SensitivityValue;
        attribute operatingTemp : CryoTemperatureValue;
        attribute pickupLoopArea :> ISQ::area;
        attribute spatialResolution :> ISQ::length;
        
        port sensorOut : SensorOutputPort;
        port thermalInterface : CryogenicInterfacePort;
        
        perform action detectMagneticFlux {
            in biasVoltage :> ISQ::voltage;
            in temperature : CryoTemperatureValue;
            out fluxOutput : MagneticFluxValue;
        }
    }
    
    part def CryogenicDewar {
        attribute baseTemperature : CryoTemperatureValue;
        attribute holdTime :> ISQ::time;
        attribute liquidHeliumCapacity :> ISQ::volume;
        
        port coldPlate : CryogenicInterfacePort;
        
        perform action maintainCryogenicTemp {
            in targetTemp : CryoTemperatureValue;
            out actualTemp : CryoTemperatureValue;
            out remainingHoldTime :> ISQ::time;
        }
    }
    
    part def PiezoelectricScanner {
        attribute maxRangeX :> ISQ::length;
        attribute maxRangeY :> ISQ::length;
        attribute maxRangeZ :> ISQ::length;
        attribute positionNoise :> ISQ::length;
        attribute bandwidth :> ISQ::frequency;
        
        port positionControl : PositionControlPort;
        
        perform action moveToPosition {
            in targetX : PositionValue;
            in targetY : PositionValue;
            in targetZ : PositionValue;
            out currentX : PositionValue;
            out currentY : PositionValue;
            out currentZ : PositionValue;
        }
    }
    
    part def SampleStage {
        attribute maxSampleDiameter :> ISQ::length;
        attribute stageTemperature : CryoTemperatureValue;
        
        part mountedSample : SampleSpecimen;
    }
    
    part def FeedbackElectronics {
        attribute lockInAmplifierGain : Real;
        attribute modulationFrequency :> ISQ::frequency;
        attribute feedbackBandwidth :> ISQ::frequency;
        
        perform action processSignal {
            in rawVoltage :> ISQ::voltage;
            in referenceSignal :> ISQ::voltage;
            out calibratedFlux : MagneticFluxValue;
        }
    }
    
    part def DataAcquisitionUnit {
        attribute samplingRate :> ISQ::frequency;
        attribute bitResolution : Integer;
        attribute bufferSize : Integer;
        
        port dataPort : DataCollectionPort;
        
        perform action acquireData {
            in fluxMeasurement : MagneticFluxValue;
            in xPosition : PositionValue;
            in yPosition : PositionValue;
            out dataPoint : MagneticDataPoint;
        }
    }
    
    part def VibrationIsolationSystem {
        attribute isolationFrequency :> ISQ::frequency;
        attribute dampingRatio : Real;
        
        perform action isolateVibration {
            in externalVibration :> ISQ::acceleration;
            out transmittedVibration :> ISQ::acceleration;
        }
    }
    
    part def MagneticShieldingEnclosure {
        attribute shieldingFactor : Real;
        attribute numberOfLayers : Integer;
        attribute materialType : String;
        
        perform action attenuateField {
            in externalField : MagneticFieldValue;
            out internalField : MagneticFieldValue;
        }
    }
    
    action def InitializeSystem {
        in targetTemperature : CryoTemperatureValue;
        out systemReady : Boolean;
        out achievedTemp : CryoTemperatureValue;
    }
    
    action def LoadSample {
        in sample : SampleSpecimen;
        in mountingHeight :> ISQ::length;
        out sampleLoaded : Boolean;
    }
    
    action def CalibrateSQUID {
        in calibrationFlux : MagneticFluxValue;
        out calibrationCoefficient : Real;
        out noiseLevel : SensitivityValue;
    }
    
    action def ExecuteRasterScan {
        in scanArea : ScanParameters;
        out fieldMap : MagneticFieldImage;
        
        private attribute currentX := scanArea.startX;
        private attribute currentY := scanArea.startY;
        private attribute collectedData : MagneticDataPoint[*] := ( );
        
        while currentY <= scanArea.endY {
            while currentX <= scanArea.endX {
                perform action moveScanner {
                    in targetX = currentX;
                    in targetY = currentY;
                    out reachedX : PositionValue;
                    out reachedY : PositionValue;
                }
                then perform action measureAtPoint {
                    in dwellTime = scanArea.dwellTime;
                    in posX = moveScanner.reachedX;
                    in posY = moveScanner.reachedY;
                    out measurement : MagneticDataPoint;
                }
                then assign collectedData := collectedData->including(measureAtPoint.measurement);
                then assign currentX := currentX + scanArea.stepSize;
            }
            assign currentX := scanArea.startX;
            assign currentY := currentY + scanArea.stepSize;
        }
        assign fieldMap.dataPoints := collectedData;
        assign fieldMap.scanParams := scanArea;
    }
    
    action def ProcessImageData {
        in rawImage : MagneticFieldImage;
        out processedImage : MagneticFieldImage;
        out meanField : MagneticFieldValue;
        out fieldVariance : Real;
    }
    
    part squidMicroscopeSystem : SQUIDMicroscopeSystem {
        doc /*
            A Scanning SQUID Microscope (SSM) system for high-resolution magnetic field imaging.
            The system maps the spatial distribution of magnetic fields across a sample surface
            by scanning a superconducting quantum interference device (SQUID) sensor in a raster
            pattern while maintaining cryogenic operating temperatures. The primary function is
            to generate detailed magnetic field maps with nanometer-scale spatial resolution and
            femtotesla-level sensitivity for applications in materials science, biology, and
            condensed matter physics.
        */
        
        part squidSensor : SQUIDSensorHead {
            attribute :>> fluxSensitivity = 5.0e-7 [SI::Wb];
            attribute :>> operatingTemp = 4.2 [SI::K];
            attribute :>> pickupLoopArea = 7.85e-11 [SI::m^2];
            attribute :>> spatialResolution = 5.0e-7 [SI::m];
        }
        
        part cryostat : CryogenicDewar {
            attribute :>> baseTemperature = 4.2 [SI::K];
            attribute :>> holdTime = 86400.0 [SI::s];
            attribute :>> liquidHeliumCapacity = 0.01 [SI::m^3];
        }
        
        part scanner : PiezoelectricScanner {
            attribute :>> maxRangeX = 0.01 [SI::m];
            attribute :>> maxRangeY = 0.01 [SI::m];
            attribute :>> maxRangeZ = 0.005 [SI::m];
            attribute :>> positionNoise = 1.0e-10 [SI::m];
            attribute :>> bandwidth = 1000.0 [SI::Hz];
        }
        
        part sampleStage : SampleStage {
            attribute :>> maxSampleDiameter = 0.025 [SI::m];
        }
        
        part electronics : FeedbackElectronics {
            attribute :>> lockInAmplifierGain = 10000.0;
            attribute :>> modulationFrequency = 100000.0 [SI::Hz];
            attribute :>> feedbackBandwidth = 10000.0 [SI::Hz];
        }
        
        part dataAcquisition : DataAcquisitionUnit {
            attribute :>> samplingRate = 100000.0 [SI::Hz];
            attribute :>> bitResolution = 24;
            attribute :>> bufferSize = 1048576;
        }
        
        part vibrationIsolation : VibrationIsolationSystem {
            attribute :>> isolationFrequency = 1.0 [SI::Hz];
            attribute :>> dampingRatio = 0.7;
        }
        
        part magneticShield : MagneticShieldingEnclosure {
            attribute :>> shieldingFactor = 10000.0;
            attribute :>> numberOfLayers = 3;
            attribute :>> materialType = "Mu-metal";
        }
        
        connect cryostat.coldPlate to squidSensor.thermalInterface;
        connect squidSensor.sensorOut to electronics;
        connect scanner.positionControl to dataAcquisition;
        connect electronics to dataAcquisition.dataPort;
        
        perform action operateMicroscope {
            first start;
            then action initialize : InitializeSystem {
                in targetTemperature = 4.2 [SI::K];
                out systemReady;
                out achievedTemp;
            }
            then decide;
                if initialize.systemReady then loadSample;
                if not initialize.systemReady then abortOperation;
            
            action loadSample : LoadSample {
                in sample;
                in mountingHeight = 1.0e-3 [SI::m];
                out sampleLoaded;
            }
            then action calibrate : CalibrateSQUID {
                in calibrationFlux = 2.07e-15 [SI::Wb];
                out calibrationCoefficient;
                out noiseLevel;
            }
            then merge beginScanLoop;
            
            loop {
                action beginScanLoop;
                then action executeScan : ExecuteRasterScan {
                    in scanArea;
                    out fieldMap;
                }
                then action processImage : ProcessImageData {
                    in rawImage = executeScan.fieldMap;
                    out processedImage;
                    out meanField;
                    out fieldVariance;
                }
                then decide;
                    if continueScan then beginScanLoop;
                    if not continueScan then warmupSystem;
            }
            
            action warmupSystem;
            then action abortOperation;
            then done;
        }
    }
    
    part def SQUIDMicroscopeSystem {
        part squidSensor : SQUIDSensorHead;
        part cryostat : CryogenicDewar;
        part scanner : PiezoelectricScanner;
        part sampleStage : SampleStage;
        part electronics : FeedbackElectronics;
        part dataAcquisition : DataAcquisitionUnit;
        part vibrationIsolation : VibrationIsolationSystem;
        part magneticShield : MagneticShieldingEnclosure;
    }
    
    requirement <'SSM-REQ-001'> primaryFunctionRequirement {
        doc /*
            The Scanning SQUID Microscope system shall generate high-resolution spatial maps
            of magnetic field distributions across sample surfaces by scanning a cryogenically
            cooled SQUID sensor in a controlled raster pattern.
        */
        subject squidMicroscopeSystem;
    }
    
    requirement <'SSM-REQ-002'> sensitivityRequirement {
        doc /*
            The SQUID sensor shall achieve magnetic flux sensitivity of 5 femtotesla per
            square root hertz or better at the operating temperature.
        */
        subject squidMicroscopeSystem.squidSensor;
        require constraint {
            squidMicroscopeSystem.squidSensor.fluxSensitivity <= 5.0e-7 [SI::Wb]
        }
    }
    
    requirement <'SSM-REQ-003'> cryogenicOperationRequirement {
        doc /*
            The system shall maintain the SQUID sensor at a temperature of 4.2 Kelvin
            or below during all measurement operations.
        */
        subject squidMicroscopeSystem.cryostat;
        require constraint {
            squidMicroscopeSystem.cryostat.baseTemperature <= 4.2 [SI::K]
        }
    }
    
    requirement <'SSM-REQ-004'> spatialResolutionRequirement {
        doc /*
            The system shall provide spatial resolution of 500 nanometers or better
            in the imaging plane.
        */
        subject squidMicroscopeSystem.squidSensor;
        require constraint {
            squidMicroscopeSystem.squidSensor.spatialResolution <= 5.0e-7 [SI::m]
        }
    }
    
    requirement <'SSM-REQ-005'> scanRangeRequirement {
        doc /*
            The scanning stage shall provide a minimum scan range of 10 millimeters
            in both X and Y directions.
        */
        subject squidMicroscopeSystem.scanner;
        require constraint {
            squidMicroscopeSystem.scanner.maxRangeX >= 0.01 [SI::m] and
            squidMicroscopeSystem.scanner.maxRangeY >= 0.01 [SI::m]
        }
    }
    
    requirement <'SSM-REQ-006'> vibrationIsolationRequirement {
        doc /*
            The vibration isolation system shall attenuate external vibrations below
            1 Hz to maintain positioning stability during scanning.
        */
        subject squidMicroscopeSystem.vibrationIsolation;
        require constraint {
            squidMicroscopeSystem.vibrationIsolation.isolationFrequency <= 1.0 [SI::Hz]
        }
    }
    
    requirement <'SSM-REQ-007'> magneticShieldingRequirement {
        doc /*
            The magnetic shielding enclosure shall provide a shielding factor of at least
            10,000 to attenuate external magnetic field interference.
        */
        subject squidMicroscopeSystem.magneticShield;
        require constraint {
            squidMicroscopeSystem.magneticShield.shieldingFactor >= 10000.0
        }
    }
    
    requirement <'SSM-REQ-008'> systemIntegrationRequirement {
        doc /*
            The complete Scanning SQUID Microscope system shall integrate all subsystems
            to achieve the primary function of high-resolution magnetic field imaging.
        */
        require primaryFunctionRequirement;
        require sensitivityRequirement;
        require cryogenicOperationRequirement;
        require spatialResolutionRequirement;
        require scanRangeRequirement;
        require vibrationIsolationRequirement;
        require magneticShieldingRequirement;
    }
}
