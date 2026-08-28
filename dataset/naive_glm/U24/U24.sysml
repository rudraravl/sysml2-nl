package MineCamSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQSpace::*;
    import ISQTime::*;
    import ISQTemperature::*;
    import ISQVolume::*;
    import ISQElectricity::*;
    import ISQEnergy::*;
    import ISQFrequency::*;
    import ISQDataRate::*;

    // ===== Value Types =====
    value type ResolutionValue > Real { unit "pixel"; }
    value type IPCode > String;
    value type TemperatureRange > Real { unit "K"; }
    value type VibrationTolerance > Real { unit "m/s^2"; }
    value type LuminousIntensityValue > Real { unit "cd"; }
    value type FocalLengthValue > Real { unit "mm"; }
    value type ApertureValue > Real { unit "f"; }
    value type StorageCapacityValue > Real { unit "GB"; }
    value type DataRateValue > Real { unit "Mb/s"; }
    value type VoltageValue > Real { unit "V"; }
    value type PowerValue > Real { unit "W"; }
    value type CurrentValue > Real { unit "A"; }
    value type FrequencyValue > Real { unit "Hz"; }
    value type DurationValue > Real { unit "s"; }
    value type MassValue > Real { unit "kg"; }
    value type DimensionValue > Real { unit "mm"; }

    // ===== Item Types =====
    item def RawImage {
        attribute resolution : ResolutionValue;
        attribute bitDepth : Integer;
        attribute timestamp : String;
    }

    item def ProcessedImage {
        attribute resolution : ResolutionValue;
        attribute format : String;
        attribute brightnessAdjusted : Boolean;
        attribute contrastAdjusted : Boolean;
        attribute compressed : Boolean;
        attribute timestamp : String;
    }

    item def VideoFile {
        attribute duration : DurationValue;
        attribute frameRate : FrequencyValue;
        attribute codec : String;
        attribute size : StorageCapacityValue;
    }

    item def CaptureCommand {
        attribute commandType : String; // "photo" or "video"
        attribute duration : DurationValue; // for video
        attribute targetFocus : FocalLengthValue;
    }

    item def DiagnosticResult {
        attribute sensorOK : Boolean;
        attribute illuminationOK : Boolean;
        attribute processorOK : Boolean;
        attribute storageOK : Boolean;
        attribute commOK : Boolean;
        attribute powerOK : Boolean;
        attribute overallStatus : String;
    }

    item def PowerRail {
        attribute voltage : VoltageValue;
        attribute maxCurrent : CurrentValue;
    }

    item def EthernetFrame {
        attribute payloadSize : Integer;
        attribute destinationIP : String;
        attribute sourceIP : String;
    }

    // ===== Port Definitions =====
    port def OpticalPort {
        attribute focalLength : FocalLengthValue;
        attribute aperture : ApertureValue;
    }

    port def IlluminationPort {
        attribute maxIntensity : LuminousIntensityValue;
    }

    port def RawImagePort {
        out item rawImage : RawImage;
    }

    port def ProcessedImagePort {
        in item processedImage : ProcessedImage;
        out item processedImageOut : ProcessedImage;
    }

    port def StoragePort {
        in item dataToStore : ProcessedImage;
        out item dataRetrieved : ProcessedImage;
    }

    port def EthernetPort {
        in item frameIn : EthernetFrame;
        out item frameOut : EthernetFrame;
    }

    port def PowerPort {
        out item rail : PowerRail;
    }

    port def CommandPort {
        in item command : CaptureCommand;
        out item status : String;
    }

    port def DiagnosticPort {
        out item result : DiagnosticResult;
    }

    // ===== Requirements =====
    requirement def EnclosureRequirement {
        subject enclosure : Enclosure;
        objective {
            doc /* The enclosure must be IP68 rated and withstand harsh mining conditions. */
        }
        require enclosure.ipRating == "IP68";
        require enclosure.operatingTempRange.min >= 243.15; // -30 C
        require enclosure.operatingTempRange.max <= 333.15; // 60 C
        require enclosure.vibrationTolerance >= 50;
    }

    requirement def ImageQualityRequirement {
        subject sensor : ImageSensor;
        objective {
            doc /* The image sensor must capture high-resolution images. */
        }
        require sensor.resolution >= 12000000; // 12 MP
        require sensor.dynamicRange >= 60;
    }

    requirement def IlluminationRequirement {
        subject illumination : IlluminationModule;
        objective {
            doc /* The illumination module must provide sufficient light for complete darkness. */
        }
        require illumination.maxIntensity >= 1000;
    }

    requirement def ProcessingRequirement {
        subject processor : ImageProcessor;
        objective {
            doc /* The processor must enhance and compress images. */
        }
        require processor.supportsBrightnessAdjustment == true;
        require processor.supportsContrastAdjustment == true;
        require processor.supportsVideoCompression == true;
    }

    requirement def StorageRequirement {
        subject storage : StorageUnit;
        objective {
            doc /* The storage unit must have sufficient capacity for local storage. */
        }
        require storage.capacity >= 256;
    }

    requirement def CommunicationRequirement {
        subject eth : EthernetInterface;
        objective {
            doc /* The Ethernet interface must support high-bandwidth data transmission. */
        }
        require eth.dataRate >= 1000;
    }

    requirement def PowerRequirement {
        subject power : PowerSupply;
        objective {
            doc /* The power supply must distribute power to all components. */
        }
        require power.outputVoltage >= 12;
        require power.maxPower >= 50;
    }

    requirement def OperationalRequirement {
        subject cam : MineCam;
        objective {
            doc /* The MineCam must support remote-controlled photo and video capture. */
        }
        require cam.supportsRemoteControl == true;
        require cam.supportsPhotoCapture == true;
        require cam.supportsVideoRecording == true;
    }

    // ===== Part Definitions =====
    part def Enclosure {
        attribute ipRating : IPCode = "IP68";
        attribute operatingTempRange : TemperatureRange[2] = (243.15, 333.15);
        attribute vibrationTolerance : VibrationTolerance = 50;
        attribute mass : MassValue = 2.5;
        attribute dimensions : DimensionValue[3] = (150, 100, 80);
        attribute material : String = "Anodized Aluminum";
        attribute sealType : String = "Silicone Gasket";
    }

    part def ImageSensor {
        attribute resolution : ResolutionValue = 24000000; // 24 MP
        attribute sensorType : String = "CMOS";
        attribute dynamicRange : Integer = 72;
        attribute pixelSize : DimensionValue = 0.0014;
        attribute maxFrameRate : FrequencyValue = 60;
        port rawOut : RawImagePort;
    }

    part def OpticalSystem {
        attribute focalLengthRange : FocalLengthValue[2] = (8, 50);
        attribute maxAperture : ApertureValue = 1.8;
        attribute minAperture : ApertureValue = 16;
        attribute lensType : String = "Aspherical";
        attribute coating : String = "Anti-Reflective";
        attribute focusType : String = "Auto";
        port opticalIn : OpticalPort;
        port opticalOut : OpticalPort;
    }

    part def IlluminationModule {
        attribute maxIntensity : LuminousIntensityValue = 1500;
        attribute ledCount : Integer = 8;
        attribute beamPattern : String = "Flood";
        attribute adjustable : Boolean = true;
        attribute powerConsumption : PowerValue = 12;
        port lightOut : IlluminationPort;
        port powerIn : PowerPort;
    }

    part def ImageProcessor {
        attribute clockSpeed : FrequencyValue = 1.8e9;
        attribute supportsBrightnessAdjustment : Boolean = true;
        attribute supportsContrastAdjustment : Boolean = true;
        attribute supportsVideoCompression : Boolean = true;
        attribute videoCodec : String = "H.265";
        attribute maxBitrate : DataRateValue = 100;
        attribute bufferSize : StorageCapacityValue = 4;
        port rawIn : RawImagePort;
        port processedOut : ProcessedImagePort;
        port powerIn : PowerPort;
    }

    part def StorageUnit {
        attribute capacity : StorageCapacityValue = 512;
        attribute technology : String = "SSD";
        attribute readSpeed : DataRateValue = 500;
        attribute writeSpeed : DataRateValue = 450;
        attribute interface : String = "SATA III";
        port storagePort : StoragePort;
        port powerIn : PowerPort;
    }

    part def EthernetInterface {
        attribute dataRate : DataRateValue = 1000;
        attribute standard : String = "1000BASE-T";
        attribute connector : String = "IP68 RJ45";
        attribute protocol : String = "TCP/IP";
        attribute ipAddress : String = "192.168.1.100";
        port ethPort : EthernetPort;
        port powerIn : PowerPort;
    }

    part def PowerSupply {
        attribute inputVoltage : VoltageValue = 24;
        attribute outputVoltage : VoltageValue = 12;
        attribute maxPower : PowerValue = 60;
        attribute batteryBackup : StorageCapacityValue = 0; // Wh equivalent
        attribute hasBatteryBackup : Boolean = true;
        attribute batteryCapacity : PowerValue = 20;
        attribute efficiency : Real = 0.92;
        port powerOut : PowerPort;
    }

    // ===== Main MineCam Part =====
    part def MineCam {
        attribute supportsRemoteControl : Boolean = true;
        attribute supportsPhotoCapture : Boolean = true;
        attribute supportsVideoRecording : Boolean = true;
        attribute manufacturer : String = "MineTech Systems";
        attribute modelNumber : String = "MC-2400";
        attribute firmwareVersion : String = "2.1.0";

        // Subcomponents
        part enclosure : Enclosure {
            // satisfies EnclosureRequirement;
        }

        part imageSensor : ImageSensor {
            // satisfies ImageQualityRequirement;
        }

        part opticalSystem : OpticalSystem {
        }

        part illumination : IlluminationModule {
            // satisfies IlluminationRequirement;
        }

        part processor : ImageProcessor {
            // satisfies ProcessingRequirement;
        }

        part storage : StorageUnit {
            // satisfies StorageRequirement;
        }

        part ethernet : EthernetInterface {
            // satisfies CommunicationRequirement;
        }

        part powerSupply : PowerSupply {
            // satisfies PowerRequirement;
        }

        // External ports
        port commandPort : CommandPort;
        port diagnosticPort : DiagnosticPort;
        port externalEthPort : EthernetPort;

        // Connections
        connection opticalPath connect opticalSystem.opticalOut to imageSensor;
        connection rawImageBus connect imageSensor.rawOut to processor.rawIn;
        connection processedImageBus connect processor.processedOut to storage.storagePort;
        connection storageToEth connect storage.storagePort to ethernet.ethPort;
        connection ethToExternal connect ethernet.ethPort to externalEthPort;
        connection commandToProcessor connect commandPort to processor;
        connection diagnosticFromProcessor connect processor to diagnosticPort;

        // Power distribution
        connection powerToSensor connect powerSupply.powerOut to imageSensor;
        connection powerToIllumination connect powerSupply.powerOut to illumination.powerIn;
        connection powerToProcessor connect powerSupply.powerOut to processor.powerIn;
        connection powerToStorage connect powerSupply.powerOut to storage.powerIn;
        connection powerToEthernet connect powerSupply.powerOut to ethernet.powerIn;

        // ===== State Machine Behavior =====
        state def MineCamStateMachine {
            doc /* State machine governing MineCam operational modes. */

            entry; // initial

            state startup {
                entry action {
                    doc /* Initialize all subsystems. */
                    powerSupply.activate();
                    processor.initialize();
                    storage.mount();
                    ethernet.connect();
                    illumination.selfTest();
                    opticalSystem.calibrate();
                    imageSensor.initialize();
                }
                do action {
                    doc /* Perform boot sequence. */
                    send DiagnosticResult() to diagnosticPort;
                }
                transition to selfDiagnostic
                    if true;
            }

            state selfDiagnostic {
                entry action {
                    doc /* Run comprehensive self-test. */
                    var sensorTest : Boolean = imageSensor.test();
                    var illumTest : Boolean = illumination.test();
                    var procTest : Boolean = processor.test();
                    var storageTest : Boolean = storage.test();
                    var commTest : Boolean = ethernet.test();
                    var powerTest : Boolean = powerSupply.test();
                }
                do action {
                    doc /* Evaluate diagnostic results. */
                    if (sensorTest && illumTest && procTest && storageTest && commTest && powerTest) {
                        // All systems nominal
                    } else {
                        // Log fault and attempt recovery
                    }
                }
                transition to standby
                    if sensorTest && illumTest && procTest && storageTest && commTest && powerTest;
                transition to fault
                    if !(sensorTest && illumTest && procTest && storageTest && commTest && powerTest);
            }

            state standby {
                doc /* Awaiting remote commands. */
                entry action {
                    illumination.deactivate();
                    opticalSystem.setStandbyFocus();
                }
                do action {
                    doc /* Listen for commands on Ethernet interface. */
                    listen commandPort for CaptureCommand;
                }
                transition to capturePhoto
                    if commandPort.command.commandType == "photo";
                transition to captureVideo
                    if commandPort.command.commandType == "video";
                transition to shutdown
                    if commandPort.command.commandType == "shutdown";
            }

            state capturePhoto {
                doc /* Capture a single high-quality photograph. */
                entry action {
                    doc /* Activate illumination and focus lens. */
                    illumination.activate();
                    illumination.setIntensity(illumination.maxIntensity * 0.8);
                    opticalSystem.setFocus(commandPort.command.targetFocus);
                    wait(0.5);
                }
                do action {
                    doc /* Capture, process, store, and transmit image. */
                    var raw : RawImage = imageSensor.captureStill();
                    var processed : ProcessedImage = processor.enhance(raw);
                    processor.adjustBrightness(processed);
                    processor.adjustContrast(processed);
                    storage.store(processed);
                    ethernet.transmit(processed);
                }
                transition to standby
                    if true;
            }

            state captureVideo {
                doc /* Record a video sequence. */
                entry action {
                    doc /* Activate illumination and begin recording. */
                    illumination.activate();
                    illumination.setIntensity(illumination.maxIntensity);
                    opticalSystem.setFocus(commandPort.command.targetFocus);
                }
                do action {
                    doc /* Capture frames, process, compress, store, and stream. */
                    var frameCount : Integer = 0;
                    var startTime : Real = now();
                    while (now() - startTime < commandPort.command.duration) {
                        var rawFrame : RawImage = imageSensor.captureFrame();
                        var processedFrame : ProcessedImage = processor.enhance(rawFrame);
                        storage.store(processedFrame);
                        ethernet.transmit(processedFrame);
                        frameCount = frameCount + 1;
                    }
                    var video : VideoFile = processor.compressVideo(frameCount);
                    storage.store(video);
                    ethernet.transmit(video);
                }
                transition to standby
                    if true;
            }

            state fault {
                doc /* Fault state — system requires maintenance. */
                entry action {
                    illumination.blink();
                    ethernet.sendAlert("MineCam fault detected");
                }
                do action {
                    doc /* Await maintenance reset. */
                    listen commandPort for CaptureCommand;
                }
                transition to selfDiagnostic
                    if commandPort.command.commandType == "reset";
            }

            state shutdown {
                doc /* Graceful shutdown sequence. */
                entry action {
                    illumination.deactivate();
                    storage.flush();
                    storage.unmount();
                    ethernet.disconnect();
                    powerSupply.deactivate();
                }
                transition to final
                    if true;
            }

            final;
        }

        // Behavior binding
        behavior : MineCamStateMachine;

        // ===== Action Definitions =====
        action def ActivateIllumination {
            in illumination : IlluminationModule;
            in intensity : LuminousIntensityValue;
            do {
                illumination.activate();
                illumination.setIntensity(intensity);
            }
        }

        action def CaptureAndProcess {
            in sensor : ImageSensor;
            in proc : ImageProcessor;
            out processed : ProcessedImage;
            do {
                var raw : RawImage = sensor.captureStill();
                processed = proc.enhance(raw);
                proc.adjustBrightness(processed);
                proc.adjustContrast(processed);
            }
        }

        action def StoreAndTransmit {
            in storage : StorageUnit;
            in eth : EthernetInterface;
            in data : ProcessedImage;
            do {
                storage.store(data);
                eth.transmit(data);
            }
        }

        // ===== Requirement Satisfaction =====
        satisfy EnclosureRequirement by enclosure;
        satisfy ImageQualityRequirement by imageSensor;
        satisfy IlluminationRequirement by illumination;
        satisfy ProcessingRequirement by processor;
        satisfy StorageRequirement by storage;
        satisfy CommunicationRequirement by ethernet;
        satisfy PowerRequirement by powerSupply;
        satisfy OperationalRequirement by MineCam;
    }

    // ===== Top-level context =====
    part MineCamInstance : MineCam {
        // Concrete instance with specific attribute values
        attribute modelNumber = "MC-2400-A";
        attribute firmwareVersion = "2.1.0";

        part enclosure {
            attribute serialNumber = "ENC-2024-001";
        }
        part imageSensor {
            attribute serialNumber = "IS-2024-001";
        }
        part opticalSystem {
            attribute serialNumber = "OS-2024-001";
        }
        part illumination {
            attribute serialNumber = "IL-2024-001";
        }
        part processor {
            attribute serialNumber = "PR-2024-001";
        }
        part storage {
            attribute serialNumber = "ST-2024-001";
        }
        part ethernet {
            attribute ipAddress = "10.0.1.50";
        }
        part powerSupply {
            attribute serialNumber = "PS-2024-001";
        }
    }

    // ===== Surface Monitoring Station (external context) =====
    part def SurfaceMonitoringStation {
        attribute stationName : String;
        attribute operator : String;
        port ethPort : EthernetPort;
        port commandOut : CommandPort;

        action def ReceiveData {
            in frame : EthernetFrame;
            do {
                // Process received monitoring data
            }
        }

        action def SendCommand {
            out cmd : CaptureCommand;
            do {
                // Issue capture command to MineCam
            }
        }
    }

    // ===== System-of-Systems context =====
    part MineMonitoringSystem {
        part mineCam : MineCam;
        part surfaceStation : SurfaceMonitoringStation;

        connection commandLink connect surfaceStation.commandOut to mineCam.commandPort;
        connection dataLink connect mineCam.externalEthPort to surfaceStation.ethPort;
    }
}
