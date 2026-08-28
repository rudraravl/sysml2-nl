package DigitalPillAdherenceSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQDateTime::*;
    import ISQSpace::*;
    
    // ===== Value Types with Units =====
    
    value def Temperature :> Real {
        :>> unit = '°C';
    }
    
    value def pHLevel :> Real {
        :>> unit = 'pH';
    }
    
    value def SignalStrength :> Real {
        :>> unit = 'dBm';
    }
    
    value def ElectricCharge :> Real {
        :>> unit = 'µC';
    }
    
    value def Frequency :> Real {
        :>> unit = 'MHz';
    }
    
    value def PillID :> String;
    value def PatientID :> String;
    value def ProviderID :> String;
    
    value def Timestamp :> DateTime;
    
    // ===== Item Definitions =====
    
    item def StomachFluid {
        attribute pH : pHLevel;
        attribute temp : Temperature;
    }
    
    item def TelemetryPacket {
        attribute pillId : PillID;
        attribute patientId : PatientID;
        attribute timestamp : Timestamp;
        attribute bodyTemp : Temperature;
        attribute ambientpH : pHLevel;
        attribute signalRSSI : SignalStrength;
    }
    
    item def AdherenceRecord {
        attribute pillId : PillID;
        attribute patientId : PatientID;
        attribute timestamp : Timestamp;
        attribute confirmed : Boolean;
        attribute bodyTemp : Temperature;
        attribute ambientpH : pHLevel;
    }
    
    item def SecureMessage {
        attribute payload : String;
        attribute encrypted : Boolean;
        attribute timestamp : Timestamp;
    }
    
    // ===== Port Definitions =====
    
    port def StomachFluidPort {
        out fluid : StomachFluid;
    }
    
    port def TelemetrySendPort {
        out packet : TelemetryPacket;
    }
    
    port def TelemetryReceivePort {
        in packet : TelemetryPacket;
    }
    
    port def RelaySendPort {
        out message : SecureMessage;
    }
    
    port def RelayReceivePort {
        in message : SecureMessage;
    }
    
    port def CloudAccessPort {
        in record : AdherenceRecord;
    }
    
    // ===== Requirements =====
    
    requirement def IngestionDetectionRequirement {
        doc /* The system shall reliably detect and record medication ingestion. */
        subject system : DigitalPillAdherenceSystem;
        requirement {
            subject system;
            // The system shall detect ingestion within 60 seconds of stomach fluid contact.
        }
    }
    
    requirement def BiocompatibilityRequirement {
        doc /* The digital pill shall be made from biocompatible materials. */
        subject pill : DigitalPill;
        requirement {
            subject pill;
            // The pill shall pass safely through the digestive tract.
        }
        requirement {
            subject pill;
            // The pill shall be naturally expelled after power depletion.
        }
    }
    
    requirement def PowerRequirement {
        doc /* The pill shall power itself using a galvanic cell activated by stomach fluids. */
        subject pill : DigitalPill;
        requirement {
            subject pill;
            // No pre-charged battery shall be required.
        }
    }
    
    requirement def TelemetryRequirement {
        doc /* The pill shall transmit sensor data, pill ID, patient ID, and timestamp. */
        subject pill : DigitalPill;
    }
    
    requirement def PatchRelayRequirement {
        doc /* The patch shall receive telemetry and forward to the mobile app. */
        subject patch : WearablePatch;
    }
    
    requirement def AppConfirmationRequirement {
        doc /* The mobile app shall confirm medication ingestion and log the event. */
        subject app : MobileApp;
    }
    
    requirement def CloudUploadRequirement {
        doc /* The app shall securely upload adherence data to the cloud. */
        subject app : MobileApp;
    }
    
    requirement def RemoteAccessRequirement {
        doc /* Healthcare providers shall access adherence history remotely. */
        subject platform : CloudPlatform;
    }
    
    // ===== Parts =====
    
    part def DigitalPillAdherenceSystem {
        part digitalPill : DigitalPill;
        part patch : WearablePatch;
        part smartphone : Smartphone {
            part mobileApp : MobileApp;
        }
        part cloud : CloudPlatform;
        
        connection fluidContact connect digitalPill.stomachPort to digitalPill.activationPort;
        connection telemetryLink connect digitalPill.txPort to patch.rxPort;
        connection relayLink connect patch.txPort to smartphone.appRxPort;
        connection uploadLink connect smartphone.appTxPort to cloud.cloudPort;
        
        satisfy IngestionDetectionRequirement by system;
    }
    
    part def DigitalPill {
        doc /* Ingestible capsule containing medication and miniature electronics. */
        
        attribute pillId : PillID;
        attribute patientId : PatientID;
        attribute medicationDose : String = "500mg Amoxicillin";
        attribute biocompatible : Boolean = true;
        
        port stomachPort : StomachFluidPort;
        port activationPort : StomachFluidPort;
        port txPort : TelemetrySendPort;
        
        part medication : MedicationCore;
        part galvanicCell : GalvanicCell;
        part sensor : PhysiologicalSensor;
        part transmitter : RadioTransmitter;
        part microcontroller : PillController;
        part capsuleShell : BiocompatibleShell;
        
        connection powerFlow connect galvanicCell.powerOut to microcontroller.powerIn;
        connection powerFlow2 connect galvanicCell.powerOut to sensor.powerIn;
        connection powerFlow3 connect galvanicCell.powerOut to transmitter.powerIn;
        connection sensorData connect sensor.dataOut to microcontroller.sensorIn;
        connection txCommand connect microcontroller.txOut to transmitter.cmdIn;
        connection packetOut connect transmitter.packetOut to txPort;
        
        satisfy BiocompatibilityRequirement by capsuleShell;
        satisfy PowerRequirement by galvanicCell;
        satisfy TelemetryRequirement by transmitter;
        
        exhibit stateMachine IngestionLifecycle {
            entry; then Inactive;
            
            state Inactive;
            
            transition from Inactive to Activating
                when stomachPort.fluid.pH > 1.0 and stomachPort.fluid.pH < 5.0;
            
            state Activating {
                entry action {
                    galvanicCell.activate(stomachPort.fluid);
                }
                do action {
                    sensor.initialize();
                    microcontroller.boot();
                }
            }
            
            transition from Activating to Measuring
                when galvanicCell.chargeLevel > ElectricCharge(50);
            
            state Measuring {
                do action {
                    sensor.measureBodyTemp();
                    sensor.measurepH();
                    microcontroller.assemblePacket(pillId, patientId, now);
                }
            }
            
            transition from Measuring to Transmitting
                when microcontroller.packetReady;
            
            state Transmitting {
                do action {
                    transmitter.send(microcontroller.currentPacket);
                }
            }
            
            transition from Transmitting to Depleted
                when galvanicCell.chargeLevel < ElectricCharge(5);
            
            state Depleted {
                entry action {
                    transmitter.shutdown();
                    sensor.shutdown();
                }
            }
            
            transition from Depleted to Expelled
                after Duration(72, 'h');
            
            state Expelled;
        }
    }
    
    part def MedicationCore {
        attribute activeIngredient : String;
        attribute dosage : String;
    }
    
    part def GalvanicCell {
        doc /* Generates electric charge from digestive system environment. */
        
        attribute chargeLevel : ElectricCharge = 0;
        attribute activated : Boolean = false;
        
        port powerOut : PowerPort;
        
        action def Activate {
            in fluid : StomachFluid;
            // Generate charge from electrolytic environment
        }
        
        action def GeneratePower {
            out charge : ElectricCharge;
        }
        
        perform Activate;
        perform GeneratePower;
    }
    
    port def PowerPort {
        out charge : ElectricCharge;
    }
    
    port def SensorDataPort {
        out temp : Temperature;
        out pH : pHLevel;
    }
    
    port def CommandPort {
        in cmd : String;
    }
    
    port def PacketPort {
        out packet : TelemetryPacket;
    }
    
    part def PhysiologicalSensor {
        doc /* Measures body temperature and pH level. */
        
        port powerIn : PowerPort;
        port dataOut : SensorDataPort;
        
        attribute measuredTemp : Temperature;
        attribute measuredpH : pHLevel;
        
        action def MeasureBodyTemp {
            out temp : Temperature;
        }
        
        action def MeasurepH {
            out pH : pHLevel;
        }
        
        action def Initialize {
            // Calibrate sensors
        }
        
        action def Shutdown {
            // Power down
        }
        
        perform MeasureBodyTemp;
        perform MeasurepH;
        perform Initialize;
        perform Shutdown;
    }
    
    part def RadioTransmitter {
        doc /* Low-power radio transmitter for telemetry. */
        
        attribute carrierFreq : Frequency = Frequency(433, 'MHz');
        attribute txPower : SignalStrength = SignalStrength(-20, 'dBm');
        
        port powerIn : PowerPort;
        port cmdIn : CommandPort;
        port packetOut : PacketPort;
        
        action def Send {
            in packet : TelemetryPacket;
            // Transmit telemetry packet over low-power radio
        }
        
        action def Shutdown {
            // Power down transmitter
        }
        
        perform Send;
        perform Shutdown;
    }
    
    part def PillController {
        doc /* Microcontroller that assembles telemetry packets. */
        
        port powerIn : PowerPort;
        port sensorIn : SensorDataPort;
        port txOut : CommandPort;
        
        attribute packetReady : Boolean = false;
        attribute currentPacket : TelemetryPacket;
        
        action def Boot {
            // Initialize firmware
        }
        
        action def AssemblePacket {
            in id : PillID;
            in patient : PatientID;
            in time : Timestamp;
            // Assemble telemetry packet from sensor data
        }
        
        perform Boot;
        perform AssemblePacket;
    }
    
    part def BiocompatibleShell {
        doc /* Biocompatible capsule shell that safely passes through digestive tract. */
        attribute material : String = "FDA-grade biocompatible polymer";
        attribute dissolvable : Boolean = true;
    }
    
    part def WearablePatch {
        doc /* Skin-worn patch that receives telemetry and relays to smartphone. */
        
        attribute patchId : String;
        attribute wornLocation : String = "torso";
        
        port rxPort : TelemetryReceivePort;
        port txPort : RelaySendPort;
        
        part receiver : PatchReceiver;
        part relay : PatchRelay;
        part patchController : PatchController;
        
        connection receiveFlow connect rxPort to receiver.input;
        connection internalRelay connect receiver.output to patchController.input;
        connection relayOut connect patchController.output to relay.input;
        connection transmitFlow connect relay.output to txPort;
        
        satisfy PatchRelayRequirement by relay;
        
        exhibit stateMachine PatchOperation {
            entry; then Listening;
            
            state Listening {
                do action {
                    receiver.scan();
                }
            }
            
            transition from Listening to Receiving
                when receiver.packetReceived;
            
            state Receiving {
                entry action {
                    patchController.validate();
                }
            }
            
            transition from Receiving to Relaying
                when patchController.validated;
            
            state Relaying {
                do action {
                    relay.forward();
                }
            }
            
            transition from Relaying to Listening
                when relay.forwarded;
        }
    }
    
    part def PatchReceiver {
        port input : TelemetryReceivePort;
        port output : PacketPort;
        attribute packetReceived : Boolean = false;
        
        action def Scan {
            // Listen for telemetry signals
        }
    }
    
    part def PatchRelay {
        port input : PacketPort;
        port output : RelaySendPort;
        attribute forwarded : Boolean = false;
        
        action def Forward {
            // Forward data to smartphone via Bluetooth
        }
    }
    
    part def PatchController {
        port input : PacketPort;
        port output : RelaySendPort;
        attribute validated : Boolean = false;
        
        action def Validate {
            // Validate packet integrity
        }
    }
    
    part def Smartphone {
        port appRxPort : RelayReceivePort;
        port appTxPort : RelaySendPort;
        
        part mobileApp : MobileApp;
    }
    
    part def MobileApp {
        doc /* Patient mobile application for processing and logging adherence. */
        
        attribute appVersion : String = "2.1.0";
        attribute patientId : PatientID;
        
        port appRxPort : RelayReceivePort;
        port appTxPort : RelaySendPort;
        
        part dataProcessor : AppDataProcessor;
        part adherenceLog : AdherenceLog;
        part secureUploader : SecureUploader;
        
        connection processFlow connect appRxPort to dataProcessor.input;
        connection logFlow connect dataProcessor.logOut to adherenceLog.recordIn;
        connection uploadFlow connect adherenceLog.uploadOut to secureUploader.recordIn;
        connection transmitFlow connect secureUploader.output to appTxPort;
        
        satisfy AppConfirmationRequirement by dataProcessor;
        satisfy CloudUploadRequirement by secureUploader;
        
        exhibit stateMachine AppOperation {
            entry; then Idle;
            
            state Idle;
            
            transition from Idle to Processing
                when appRxPort.message != null;
            
            state Processing {
                entry action {
                    dataProcessor.parseMessage();
                    dataProcessor.confirmIngestion();
                }
            }
            
            transition from Processing to Logging
                when dataProcessor.confirmed;
            
            state Logging {
                entry action {
                    adherenceLog.createRecord();
                }
            }
            
            transition from Logging to Uploading
                when adherenceLog.recordCreated;
            
            state Uploading {
                do action {
                    secureUploader.encrypt();
                    secureUploader.upload();
                }
            }
            
            transition from Uploading to Idle
                when secureUploader.uploadComplete;
        }
    }
    
    part def AppDataProcessor {
        port input : RelayReceivePort;
        port logOut : PacketPort;
        attribute confirmed : Boolean = false;
        
        action def ParseMessage {
            // Parse incoming secure message
        }
        
        action def ConfirmIngestion {
            // Cross-check sensor data against expected ranges
        }
    }
    
    part def AdherenceLog {
        port recordIn : PacketPort;
        port uploadOut : PacketPort;
        attribute recordCreated : Boolean = false;
        attribute records : AdherenceRecord[0..*];
        
        action def CreateRecord {
            // Create adherence record
        }
    }
    
    part def SecureUploader {
        port recordIn : PacketPort;
        port output : RelaySendPort;
        attribute uploadComplete : Boolean = false;
        
        action def Encrypt {
            // Encrypt adherence data
        }
        
        action def Upload {
            // Upload to cloud platform
        }
    }
    
    part def CloudPlatform {
        doc /* Cloud platform for remote access by healthcare providers. */
        
        attribute platformUrl : String = "https://adherence.cloud.med";
        
        port cloudPort : CloudAccessPort;
        
        part dataStore : CloudDataStore;
        part accessService : ProviderAccessService;
        
        connection storeFlow connect cloudPort to dataStore.input;
        connection accessFlow connect dataStore.queryOut to accessService.queryIn;
        
        satisfy RemoteAccessRequirement by accessService;
        
        exhibit stateMachine CloudOperation {
            entry; then Available;
            
            state Available {
                do action {
                    accessService.serveRequests();
                }
            }
            
            transition from Available to Storing
                when cloudPort.record != null;
            
            state Storing {
                entry action {
                    dataStore.persist();
                }
            }
            
            transition from Storing to Available
                when dataStore.persisted;
        }
    }
    
    part def CloudDataStore {
        port input : CloudAccessPort;
        port queryOut : CloudAccessPort;
        attribute persisted : Boolean = false;
        attribute adherenceHistory : AdherenceRecord[0..*];
        
        action def Persist {
            // Store adherence record in database
        }
    }
    
    part def ProviderAccessService {
        port queryIn : CloudAccessPort;
        attribute authorizedProviders : ProviderID[0..*];
        
        action def ServeRequests {
            // Serve remote access requests from doctors/caregivers
        }
    }
    
    // ===== Top-level configuration =====
    
    part def SystemConfiguration :> DigitalPillAdherenceSystem {
        attribute systemId : String = "DPAS-001";
        attribute deploymentDate : Timestamp;
        
        override part digitalPill {
            :>> pillId = "PILL-A7B3-2024";
            :>> patientId = "PAT-58291";
        }
        
        override part patch {
            :>> patchId = "PATCH-Torso-001";
        }
        
        override part smartphone {
            :>> mobileApp {
                :>> patientId = "PAT-58291";
            }
        }
    }
}
