package DigitalPillSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Mass :> ISQ::mass {
        unit = SI::gram;
    }

    attribute def Length :> ISQ::length {
        unit = SI::millimetre;
    }

    attribute def TimeDuration :> ISQ::duration {
        unit = SI::second;
    }

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        unit = SI::degreeCelsius;
    }

    attribute def Voltage :> ISQ::electricPotential {
        unit = SI::volt;
    }

    attribute def Energy :> ISQ::energy {
        unit = SI::joule;
    }

    attribute def Frequency :> ISQ::frequency {
        unit = SI::hertz;
    }

    attribute def SignalStrength {
        value : Real;
        unit = "dBm";
    }

    attribute def pHValue {
        value : Real;
        unit = "pH";
    }

    attribute def Percentage {
        value : Real;
        unit = "%";
    }

    item def ActivationSignal {
        attribute timestamp : TimeDuration;
        attribute gastricFluidDetected : Boolean;
        attribute measuredPH : pHValue;
    }

    item def IngestionEvent {
        attribute patientIdentifier : String;
        attribute pillIdentifier : String;
        attribute eventTime : TimeDuration;
        attribute confidence : Percentage;
    }

    item def SensorTelemetry {
        attribute pillIdentifier : String;
        attribute batteryVoltage : Voltage;
        attribute internalTemperature : Temperature;
        attribute signalStrength : SignalStrength;
        attribute statusCode : String;
    }

    item def MedicationPayload {
        attribute activeIngredient : String;
        attribute doseMass : Mass;
        attribute releaseProfile : String;
    }

    item def RadioPacket {
        attribute sourceIdentifier : String;
        attribute destinationIdentifier : String;
        attribute packetSequence : Integer;
        attribute payloadBytes : Integer;
        attribute checksumValid : Boolean;
    }

    item def Acknowledgement {
        attribute packetSequence : Integer;
        attribute accepted : Boolean;
        attribute reasonCode : String;
    }

    port def FluidExposurePort {
        in item gastricFluid : ActivationSignal;
    }

    port def MedicationReleasePort {
        out item medication : MedicationPayload;
    }

    port def WirelessTransmitPort {
        out item packet : RadioPacket;
        in item acknowledgement : Acknowledgement;
    }

    port def BodySignalPort {
        in item packet : RadioPacket;
        out item acknowledgement : Acknowledgement;
    }

    port def MobileDataPort {
        in item ingestionEvent : IngestionEvent;
        in item telemetry : SensorTelemetry;
        out item acknowledgement : Acknowledgement;
    }

    port def CloudDataPort {
        out item ingestionEvent : IngestionEvent;
        out item telemetry : SensorTelemetry;
        in item acknowledgement : Acknowledgement;
    }

    part def DigitalPill {
        attribute pillIdentifier : String;
        attribute diameter : Length = 8 [SI::millimetre];
        attribute length : Length = 18 [SI::millimetre];
        attribute totalMass : Mass = 1.2 [SI::gram];
        attribute operatingLifetime : TimeDuration = 900 [SI::second];

        port fluidPort : FluidExposurePort;
        port releasePort : MedicationReleasePort;
        port radioPort : WirelessTransmitPort;

        part medicationReservoir : MedicationReservoir;
        part ingestibleSensor : IngestibleSensor;
        part microBattery : MicroBattery;
        part controller : PillController;
        part antenna : MiniatureAntenna;
        part biocompatibleShell : BiocompatibleShell;

        connect medicationReservoir.releasePort to releasePort;
        connect ingestibleSensor.activationPort to fluidPort;
        connect controller.sensorInput to ingestibleSensor.sensorOutput;
        connect controller.powerInput to microBattery.powerOutput;
        connect controller.radioCommand to antenna.radioInput;
        connect antenna.radioPort to radioPort;

        action transmitIngestionConfirmation {
            in activation : ActivationSignal;
            out event : IngestionEvent;

            first start;
            then validateActivation;
            then encodeEvent;
            then sendPacket;
            then awaitAcknowledgement;
            then complete;

            action validateActivation {
                in activation : ActivationSignal;
                out valid : Boolean;
            }

            action encodeEvent {
                in valid : Boolean;
                out event : IngestionEvent;
            }

            action sendPacket {
                in event : IngestionEvent;
                out packet : RadioPacket;
            }

            action awaitAcknowledgement {
                in acknowledgement : Acknowledgement;
                out confirmed : Boolean;
            }
        }

        state def PillOperationalState {
            entry action initializeElectronics;

            state dormant;
            state activated;
            state transmitting;
            state acknowledged;
            state exhausted;
            state inactive;

            transition first dormant;

            transition dormant_to_activated
                first dormant
                then activated
                accept ActivationSignal
                if activation.gastricFluidDetected == true and activation.measuredPH.value < 5.0;

            transition activated_to_transmitting
                first activated
                then transmitting
                do transmitIngestionConfirmation;

            transition transmitting_to_acknowledged
                first transmitting
                then acknowledged
                accept Acknowledgement
                if acknowledgement.accepted == true;

            transition transmitting_to_exhausted
                first transmitting
                then exhausted
                if microBattery.remainingEnergy.value <= 0.5;

            transition acknowledged_to_inactive
                first acknowledged
                then inactive;

            transition exhausted_to_inactive
                first exhausted
                then inactive;
        }
    }

    part def MedicationReservoir {
        attribute containedDose : Mass = 500 [SI::milligram];
        attribute activeIngredient : String = "prescribed oral medication";
        attribute releaseDelay : TimeDuration = 60 [SI::second];

        port releasePort : MedicationReleasePort;

        action releaseMedication {
            out medication : MedicationPayload;
        }
    }

    part def IngestibleSensor {
        attribute activationPHThreshold : pHValue = 5.0;
        attribute temperatureAccuracy : Temperature = 0.5 [SI::degreeCelsius];

        port activationPort : FluidExposurePort;
        port sensorOutput : WirelessTransmitPort;

        action detectGastricFluid {
            in signal : ActivationSignal;
            out detected : Boolean;
        }
    }

    part def MicroBattery {
        attribute nominalVoltage : Voltage = 1.5 [SI::volt];
        attribute storedEnergy : Energy = 12 [SI::joule];
        attribute remainingEnergy : Energy = 12 [SI::joule];

        port powerOutput {
            out attribute supplyVoltage : Voltage;
            out attribute availableEnergy : Energy;
        }
    }

    part def PillController {
        attribute clockFrequency : Frequency = 32000 [SI::hertz];
        attribute eventMemoryCapacity : Integer = 8;

        port sensorInput : WirelessTransmitPort;
        port powerInput {
            in attribute supplyVoltage : Voltage;
            in attribute availableEnergy : Energy;
        }
        port radioCommand {
            out item packet : RadioPacket;
            in item acknowledgement : Acknowledgement;
        }

        action classifyIngestion {
            in activation : ActivationSignal;
            out ingestionConfirmed : Boolean;
        }

        action createTelemetry {
            out telemetry : SensorTelemetry;
        }
    }

    part def MiniatureAntenna {
        attribute carrierFrequency : Frequency = 402000000 [SI::hertz];
        attribute maximumTransmitPower : SignalStrength = -16;

        port radioInput {
            in item packet : RadioPacket;
            out item acknowledgement : Acknowledgement;
        }

        port radioPort : WirelessTransmitPort;
    }

    part def BiocompatibleShell {
        attribute shellMaterial : String = "medical grade ingestible polymer";
        attribute wallThickness : Length = 0.4 [SI::millimetre];
        attribute dissolvable : Boolean = true;
        attribute dissolutionTime : TimeDuration = 1800 [SI::second];
    }

    part def WearableReceiverPatch {
        attribute receiverIdentifier : String;
        attribute skinContactRequired : Boolean = true;
        attribute minimumSignalStrength : SignalStrength = -95;

        port bodyPort : BodySignalPort;
        port mobilePort : MobileDataPort;

        part bodyAreaReceiver : BodyAreaReceiver;
        part localProcessor : PatchProcessor;
        part bluetoothModule : BluetoothModule;
        part patchBattery : PatchBattery;

        connect bodyPort to bodyAreaReceiver.bodySignalPort;
        connect bodyAreaReceiver.decodedOutput to localProcessor.ingestionInput;
        connect localProcessor.mobileOutput to bluetoothModule.appOutput;
        connect bluetoothModule.mobilePort to mobilePort;

        action relayIngestionEvent {
            in packet : RadioPacket;
            out event : IngestionEvent;
        }

        state def PatchState {
            state unattached;
            state monitoring;
            state eventReceived;
            state forwarding;
            state lowBattery;

            transition first unattached;

            transition unattached_to_monitoring
                first unattached
                then monitoring
                if skinContactRequired == true;

            transition monitoring_to_eventReceived
                first monitoring
                then eventReceived
                accept RadioPacket
                if packet.checksumValid == true;

            transition eventReceived_to_forwarding
                first eventReceived
                then forwarding
                do relayIngestionEvent;

            transition forwarding_to_monitoring
                first forwarding
                then monitoring;

            transition monitoring_to_lowBattery
                first monitoring
                then lowBattery
                if patchBattery.remainingCharge.value < 10;
        }
    }

    part def BodyAreaReceiver {
        port bodySignalPort : BodySignalPort;
        port decodedOutput {
            out item ingestionEvent : IngestionEvent;
            out item telemetry : SensorTelemetry;
        }

        action decodePillPacket {
            in packet : RadioPacket;
            out event : IngestionEvent;
        }
    }

    part def PatchProcessor {
        port ingestionInput {
            in item ingestionEvent : IngestionEvent;
            in item telemetry : SensorTelemetry;
        }

        port mobileOutput : MobileDataPort;

        action verifyEventIntegrity {
            in event : IngestionEvent;
            out accepted : Boolean;
        }
    }

    part def BluetoothModule {
        attribute carrierFrequency : Frequency = 2400000000 [SI::hertz];

        port appOutput : MobileDataPort;
        port mobilePort : MobileDataPort;
    }

    part def PatchBattery {
        attribute nominalVoltage : Voltage = 3.7 [SI::volt];
        attribute remainingCharge : Percentage = 100;
    }

    part def PatientMobileApplication {
        attribute applicationIdentifier : String;
        attribute encryptedStorageEnabled : Boolean = true;

        port patchPort : MobileDataPort;
        port cloudPort : CloudDataPort;

        part eventLogger : IngestionEventLogger;
        part notificationService : NotificationService;
        part cloudSynchronizer : CloudSynchronizer;

        connect patchPort to eventLogger.eventInput;
        connect eventLogger.eventOutput to notificationService.notificationInput;
        connect eventLogger.eventOutput to cloudSynchronizer.syncInput;
        connect cloudSynchronizer.cloudPort to cloudPort;

        action recordMedicationTaken {
            in event : IngestionEvent;
        }

        action notifyPatient {
            in event : IngestionEvent;
        }
    }

    part def IngestionEventLogger {
        port eventInput : MobileDataPort;
        port eventOutput {
            out item ingestionEvent : IngestionEvent;
            out item telemetry : SensorTelemetry;
        }

        action storeEvent {
            in event : IngestionEvent;
        }
    }

    part def NotificationService {
        port notificationInput {
            in item ingestionEvent : IngestionEvent;
        }

        action displayConfirmation {
            in event : IngestionEvent;
        }
    }

    part def CloudSynchronizer {
        port syncInput {
            in item ingestionEvent : IngestionEvent;
            in item telemetry : SensorTelemetry;
        }

        port cloudPort : CloudDataPort;

        action uploadAdherenceRecord {
            in event : IngestionEvent;
            out acknowledgement : Acknowledgement;
        }
    }

    part def ClinicalCloudService {
        attribute serviceIdentifier : String;
        attribute auditLoggingEnabled : Boolean = true;
        attribute retentionPeriod : TimeDuration = 189216000 [SI::second];

        port applicationPort : CloudDataPort;

        part adherenceDatabase : AdherenceDatabase;
        part clinicianDashboard : ClinicianDashboard;
        part accessControl : AccessControlService;

        connect applicationPort to adherenceDatabase.ingestionRecordPort;
        connect adherenceDatabase.dashboardOutput to clinicianDashboard.recordInput;
        connect accessControl.authorizationOutput to clinicianDashboard.authorizationInput;

        action evaluateAdherence {
            in event : IngestionEvent;
            out adherenceStatus : String;
        }
    }

    part def AdherenceDatabase {
        port ingestionRecordPort : CloudDataPort;

        port dashboardOutput {
            out item ingestionEvent : IngestionEvent;
        }

        action persistRecord {
            in event : IngestionEvent;
        }
    }

    part def ClinicianDashboard {
        port recordInput {
            in item ingestionEvent : IngestionEvent;
        }

        port authorizationInput {
            in attribute accessGranted : Boolean;
        }

        action presentAdherenceTimeline {
            in event : IngestionEvent;
        }
    }

    part def AccessControlService {
        port authorizationOutput {
            out attribute accessGranted : Boolean;
        }

        action authorizeClinician {
            in clinicianIdentifier : String;
            out accessGranted : Boolean;
        }
    }

    part def DigitalPillAdherenceSystem {
        attribute systemPurpose : String = "Detect ingestion of a prescribed oral medication and communicate a time-stamped ingestion event to authorized care systems.";
        attribute patientIdentifier : String;
        attribute nominalEndToEndLatency : TimeDuration = 120 [SI::second];

        part digitalPill : DigitalPill;
        part receiverPatch : WearableReceiverPatch;
        part mobileApplication : PatientMobileApplication;
        part cloudService : ClinicalCloudService;

        connect digitalPill.radioPort to receiverPatch.bodyPort;
        connect receiverPatch.mobilePort to mobileApplication.patchPort;
        connect mobileApplication.cloudPort to cloudService.applicationPort;

        action performPrimaryFunction {
            objective doc
            /*
             * The system's primary high-level function is to confirm that the patient has ingested
             * the digital pill, then securely relay the ingestion event from the pill through the
             * wearable receiver and mobile application to the clinical cloud service for adherence tracking.
             */

            first detectPillActivation;
            then transmitBodySignal;
            then receiveAndVerifyEvent;
            then logOnMobileDevice;
            then synchronizeWithCloud;
            then makeRecordAvailableToClinician;

            action detectPillActivation {
                out activation : ActivationSignal;
            }

            action transmitBodySignal {
                in activation : ActivationSignal;
                out packet : RadioPacket;
            }

            action receiveAndVerifyEvent {
                in packet : RadioPacket;
                out event : IngestionEvent;
            }

            action logOnMobileDevice {
                in event : IngestionEvent;
            }

            action synchronizeWithCloud {
                in event : IngestionEvent;
                out acknowledgement : Acknowledgement;
            }

            action makeRecordAvailableToClinician {
                in event : IngestionEvent;
            }
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject system : DigitalPillAdherenceSystem;

        doc
        /*
         * The system shall detect ingestion of a digital pill and produce a verified,
         * time-stamped medication ingestion record available to authorized clinical users.
         */
    }

    requirement def ActivationRequirement {
        subject pill : DigitalPill;

        require constraint {
            pill.ingestibleSensor.activationPHThreshold.value <= 5.0
        }

        doc
        /*
         * The pill shall activate when exposed to gastric-fluid conditions consistent with ingestion.
         */
    }

    requirement def TransmissionLatencyRequirement {
        subject system : DigitalPillAdherenceSystem;

        require constraint {
            system.nominalEndToEndLatency <= 120 [SI::second]
        }

        doc
        /*
         * The system shall relay a confirmed ingestion event to the cloud service within two minutes
         * under nominal operating conditions.
         */
    }

    requirement def PillBiocompatibilityRequirement {
        subject shell : BiocompatibleShell;

        require constraint {
            shell.shellMaterial == "medical grade ingestible polymer" and shell.dissolvable == true
        }

        doc
        /*
         * The ingestible pill shell shall be biocompatible and designed to dissolve or pass safely
         * after completion of its sensing and communication function.
         */
    }

    requirement def DataIntegrityRequirement {
        subject packet : RadioPacket;

        require constraint {
            packet.checksumValid == true
        }

        doc
        /*
         * The system shall accept ingestion records only from packets that pass integrity validation.
         */
    }

    requirement def PrivacyRequirement {
        subject app : PatientMobileApplication;

        require constraint {
            app.encryptedStorageEnabled == true
        }

        doc
        /*
         * The mobile application shall store ingestion records using encrypted local storage before
         * synchronization with the clinical cloud service.
         */
    }

    requirement def PowerRequirement {
        subject pill : DigitalPill;

        require constraint {
            pill.microBattery.storedEnergy >= 12 [SI::joule] and
            pill.operatingLifetime >= 900 [SI::second]
        }

        doc
        /*
         * The digital pill shall contain sufficient energy to detect activation, generate telemetry,
         * and transmit ingestion confirmation during its intended operating lifetime.
         */
    }

    satisfy PrimaryFunctionRequirement by DigitalPillAdherenceSystem::performPrimaryFunction;
    satisfy ActivationRequirement by DigitalPill::ingestibleSensor;
    satisfy TransmissionLatencyRequirement by DigitalPillAdherenceSystem;
    satisfy PillBiocompatibilityRequirement by DigitalPill::biocompatibleShell;
    satisfy DataIntegrityRequirement by WearableReceiverPatch::localProcessor;
    satisfy PrivacyRequirement by PatientMobileApplication;
    satisfy PowerRequirement by DigitalPill::microBattery;
}