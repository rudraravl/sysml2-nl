package BhangmeterSystem {

    import ScalarValues::*;
    import ISQ::*;
    import ISQSpace::*;
    import ISQTime::*;
    import ISQEnergy::*;
    import ISQPower::*;
    import ISQRadiometry::*;

    // ---------- Value Types ----------

    value type IrradianceValue :> Irradiance {
        :> unit = W/m^2;
    }

    value type PhotonFluxValue :> Real {
        :> unit = 1/(m^2 * s);
        attribute redefinition : Real;
    }

    value type SamplingRateValue :> Real {
        :> unit = 1/s;
    }

    value type YieldValue :> Energy {
        :> unit = kt; // kilotons TNT equivalent
    }

    value type LatitudeValue :> Real {
        :> unit = "deg";
        constraint { 0 <= self and self <= 90; }
    }

    value type LongitudeValue :> Real {
        :> unit = "deg";
        constraint { 0 <= self and self <= 180; }
    }

    value type AltitudeValue :> Length {
        :> unit = m;
    }

    value type FlashIntensityValue :> Irradiance {
        :> unit = W/m^2;
    }

    value type PeakTimeIntervalValue :> Time {
        :> unit = ms;
    }

    value type SignalStrengthValue :> Real {
        :> unit = dBm;
    }

    // ---------- Item Definitions ----------

    item def LightSample {
        attribute timestamp : TimeValue;
        attribute irradiance : IrradianceValue;
        attribute sampleIndex : Positive;
    }

    item def LightCurve {
        attribute samples : LightSample[0..*];
        attribute duration : TimeValue;
    }

    item def FlashPeak {
        attribute peakTime : TimeValue;
        attribute peakIntensity : FlashIntensityValue;
        attribute peakWidth : TimeValue;
    }

    item def DoubleFlashSignature {
        attribute firstPeak : FlashPeak;
        attribute secondPeak : FlashPeak;
        attribute peakInterval : PeakTimeIntervalValue;
        attribute intensityRatio : Real;
    }

    item def Geolocation {
        attribute latitude : LatitudeValue;
        attribute longitude : LongitudeValue;
        attribute altitude : AltitudeValue;
    }

    item def EventCharacterization {
        attribute signature : DoubleFlashSignature;
        attribute estimatedYield : YieldValue;
        attribute location : Geolocation;
        attribute eventTime : TimeValue;
        attribute confidence : Real;
    }

    item def EventSignatureReport {
        attribute reportId : String;
        attribute characterization : EventCharacterization;
        attribute sensorId : String;
        attribute generatedAt : TimeValue;
    }

    item def EncryptedReport {
        attribute ciphertext : String;
        attribute integrityHash : String;
        attribute encryptionAlgorithm : String;
    }

    item def TelemetryAcknowledgement {
        attribute ackId : String;
        attribute receivedAt : TimeValue;
        attribute status : String;
    }

    // ---------- Port Definitions ----------

    port def OpticalDataPort {
        out lightSamples : LightSample;
    }

    port def LightCurvePort {
        out lightCurve : LightCurve;
    }

    port def ReportPort {
        in eventReport : EventSignatureReport;
    }

    port def SecureLinkPort {
        out encryptedReport : EncryptedReport;
        in acknowledgement : TelemetryAcknowledgement;
    }

    port def CommandPort {
        in configuration : String;
    }

    // ---------- Component Part Definitions ----------

    part def HighSensitivityOpticalSensor {

        attribute fieldOfView : Real = 120.0; // degrees
        attribute spectralRangeMin : Real = 400.0; // nm
        attribute spectralRangeMax : Real = 700.0; // nm
        attribute samplingRate : SamplingRateValue = 1.0e6; // 1 MHz
        attribute detectionThreshold : IrradianceValue = 1.0e-6;

        port opticalOut : OpticalDataPort;
        port configIn : CommandPort;

        attribute currentSample : LightSample;

        action def SampleLight {
            in sensor : HighSensitivityOpticalSensor;
            out sample : LightSample;
        }

        perform action sampleLight : SampleLight {
            // Continuously samples light intensity at high rate
        }

        // Continuous sampling behavior
        state samplingBehavior {
            entry; then sampling;
            state sampling {
                // Emit light samples at samplingRate
            }
        }
    }

    part def HighSpeedSignalProcessor {

        attribute processingLatency : TimeValue = 0.5 [ms];
        attribute doubleFlashWindowMin : PeakTimeIntervalValue = 0.1 [ms];
        attribute doubleFlashWindowMax : PeakTimeIntervalValue = 10.0 [ms];
        attribute minIntensityRatio : Real = 1.2;

        port opticalIn : OpticalDataPort;
        port reportOut : ReportPort;
        port configIn : CommandPort;

        attribute accumulatedCurve : LightCurve;
        attribute detectedSignature : DoubleFlashSignature;
        attribute characterization : EventCharacterization;

        action def AccumulateSamples {
            in sample : LightSample;
            inout curve : LightCurve;
        }

        action def DetectFlash {
            in curve : LightCurve;
            out flashDetected : Boolean;
        }

        action def AnalyzeLightCurve {
            in curve : LightCurve;
            out signature : DoubleFlashSignature;
            out isNuclear : Boolean;
        }

        action def EstimateYield {
            in signature : DoubleFlashSignature;
            out yield : YieldValue;
        }

        action def CalculateGeolocation {
            in signature : DoubleFlashSignature;
            in sensorOrientation : Real;
            out location : Geolocation;
        }

        action def GenerateReport {
            in characterization : EventCharacterization;
            out report : EventSignatureReport;
        }

        perform action processPipeline {
            action accumulate : AccumulateSamples;
            action detect : DetectFlash;
            action analyze : AnalyzeLightCurve;
            action estimateYield : EstimateYield;
            action calculateLocation : CalculateGeolocation;
            action generate : GenerateReport;

            flow accumulate.curve -> detect.curve;
            flow detect.flashDetected -> analyze.flashDetected;
            flow accumulate.curve -> analyze.curve;
            flow analyze.signature -> estimateYield.signature;
            flow analyze.signature -> calculateLocation.signature;
            flow estimateYield.yield -> generate.yield;
            flow calculateLocation.location -> generate.location;
        }
    }

    part def CommunicationModule {

        attribute transmitPower : Real = 20.0; // W
        attribute carrierFrequency : Real = 2.2e9; // Hz
        attribute encryptionKey : String;
        attribute maxRetries : Positive = 3;

        port reportIn : ReportPort;
        port linkOut : SecureLinkPort;
        port configIn : CommandPort;

        action def EncryptReport {
            in report : EventSignatureReport;
            out encrypted : EncryptedReport;
        }

        action def TransmitReport {
            in encrypted : EncryptedReport;
            out acknowledgement : TelemetryAcknowledgement;
        }

        perform action commsSequence {
            action encrypt : EncryptReport;
            action transmit : TransmitReport;

            flow encrypt.encrypted -> transmit.encrypted;
        }

        state commsState {
            entry; then idle;
            state idle;
            state encrypting;
            state transmitting;
            state awaitingAck;
            state retrying;
        }
    }

    part def GroundStation {

        attribute stationId : String = "GS-PRIMARY";
        attribute location : Geolocation;

        port linkIn : SecureLinkPort;

        action def ReceiveReport {
            in encrypted : EncryptedReport;
            out acknowledgement : TelemetryAcknowledgement;
        }

        perform action receive : ReceiveReport;
    }

    // ---------- System-Level Part ----------

    part def Bhangmeter {

        attribute systemId : String = "BHM-001";
        attribute orbitAltitude : AltitudeValue = 600.0 [km];
        attribute missionStatus : String;

        port configPort : CommandPort;
        port downlink : SecureLinkPort;

        part opticalSensor : HighSensitivityOpticalSensor {
            redefinition fieldOfView = 140.0;
            redefinition samplingRate = 2.0e6;
        }

        part signalProcessor : HighSpeedSignalProcessor {
            redefinition processingLatency = 0.2 [ms];
        }

        part commsModule : CommunicationModule {
            redefinition transmitPower = 30.0;
        }

        // Internal connections
        connection opticalDataLink connect opticalSensor.opticalOut to signalProcessor.opticalIn {
            :> kind = physical;
        }

        connection reportLink connect signalProcessor.reportOut to commsModule.reportIn {
            :> kind = logical;
        }

        // External interface
        connection downlinkConnection connect commsModule.linkOut to downlink;

        // ---------- System State Machine ----------

        state systemStateMachine {

            entry; then activeMonitoring;

            state activeMonitoring {
                // Optical sensor continuously scans field of view
                // Signal processor accumulates light samples
                entry;
                do {
                    // Continuously sample and monitor for bright flashes
                }
            }

            state analyzing {
                // Processor analyzes light curve for double-flash signature
                entry;
                do {
                    // Detect flash, analyze curve, estimate yield, calculate geolocation
                }
            }

            state transmitting {
                // Encrypt and transmit event signature report to ground station
                entry;
                do {
                    // Encrypt report and transmit via communication module
                }
            }

            transition activeMonitoring_to_analyzing
                first activeMonitoring then analyzing
                when signalProcessor.detectFlash.flashDetected == true
                ;

            transition analyzing_to_transmitting
                first analyzing then transmitting
                when signalProcessor.analyze.isNuclear == true
                ;

            transition analyzing_to_activeMonitoring
                first analyzing then activeMonitoring
                when signalProcessor.analyze.isNuclear == false
                ;

            transition transmitting_to_activeMonitoring
                first transmitting then activeMonitoring
                when commsModule.transmit.acknowledgement.status == "ACK"
                ;

            transition transmitting_retry
                first transmitting then transmitting
                when commsModule.transmit.acknowledgement.status == "NACK"
                ;
        }

        perform state behavior : systemStateMachine;
    }

    // ---------- Requirements ----------

    requirement def NuclearDetectionRequirement {

        subject : Bhangmeter;

        requirement ContinuousMonitoring {
            subject :>> subject;
            doc /*
                The system shall continuously monitor the Earth's atmosphere
                for optical signatures indicative of nuclear detonations while
                in the active monitoring state.
            */
            require subject.systemStateMachine.activeMonitoring.isActive;
        }

        requirement DoubleFlashDetection {
            subject :>> subject;
            doc /*
                The system shall identify a nuclear event only when the light
                curve exhibits a double-flash signature: a short intense first
                peak followed by a second broader and more intense peak.
            */
            require subject.signalProcessor.analyze.isNuclear == true
                implies subject.signalProcessor.detectedSignature.firstPeak.peakIntensity
                    < subject.signalProcessor.detectedSignature.secondPeak.peakIntensity;
        }

        requirement PeakIntervalConstraint {
            subject :>> subject;
            doc /*
                The interval between the first and second peaks of a confirmed
                double-flash signature shall fall within the physically valid
                range for nuclear detonations.
            */
            require subject.signalProcessor.detectedSignature.peakInterval
                >= subject.signalProcessor.doubleFlashWindowMin
                and subject.signalProcessor.detectedSignature.peakInterval
                <= subject.signalProcessor.doubleFlashWindowMax;
        }

        requirement YieldEstimation {
            subject :>> subject;
            doc /*
                Upon confirmation of a nuclear event, the system shall estimate
                the explosive yield using the timing between peaks and their
                intensities.
            */
            require subject.signalProcessor.estimateYield.yield.unit == kt;
        }

        requirement GeolocationCalculation {
            subject :>> subject;
            doc /*
                The system shall calculate the latitude, longitude, and altitude
                of the confirmed nuclear event.
            */
            require subject.signalProcessor.calculateLocation.location.latitude.unit == "deg"
                and subject.signalProcessor.calculateLocation.location.longitude.unit == "deg"
                and subject.signalProcessor.calculateLocation.location.altitude.unit == m;
        }

        requirement SecureTransmission {
            subject :>> subject;
            doc /*
                The system shall securely encrypt the event signature report
                and transmit it to the ground station before returning to
                active monitoring.
            */
            require subject.commsModule.encrypt.encrypted.encryptionAlgorithm != "";
        }

        requirement StateTransitionCompleteness {
            subject :>> subject;
            doc /*
                The system shall transition through active monitoring,
                analyzing, and transmitting states autonomously.
            */
            require subject.systemStateMachine.activeMonitoring.isDefined
                and subject.systemStateMachine.analyzing.isDefined
                and subject.systemStateMachine.transmitting.isDefined;
        }

        requirement HighRateSampling {
            subject :>> subject;
            doc /*
                The optical sensor shall sample light intensity at a rate
                sufficient to capture extremely fast transient events.
            */
            require subject.opticalSensor.samplingRate >= 1.0e6;
        }
    }

    // ---------- Verification ----------

    verification def VerifyDoubleFlashDetection {
        subject : Bhangmeter;
        objective {
            doc /* Confirm the processor correctly classifies a synthetic
                   double-flash light curve as a nuclear event. */
        }
        method {
            // Inject synthetic light curve with known double-flash signature
            // and assert isNuclear == true
        }
    }

    verification def VerifyYieldEstimation {
        subject : Bhangmeter;
        objective {
            doc /* Confirm estimated yield falls within expected bounds for
                   a reference detonation signature. */
        }
    }

    verification def VerifySecureTransmission {
        subject : Bhangmeter;
        objective {
            doc /* Confirm the report is encrypted and acknowledged by the
                   ground station. */
        }
    }

    // ---------- Instantiation ----------

    part bhangmeterInstance : Bhangmeter {
        redefinition systemId = "BHM-ORBIT-01";
        redefinition orbitAltitude = 550.0 [km];
    }

    part groundStationInstance : GroundStation {
        redefinition stationId = "GS-CENTRAL";
        redefinition location.latitude = 38.0 ["deg"];
        redefinition location.longitude = 77.0 ["deg"];
        redefinition location.altitude = 0.0 [m];
    }

    connection operationalDownlink connect bhangmeterInstance.downlink to groundStationInstance.linkIn;

    requirement satisfaction {
        satisfy NuclearDetectionRequirement by bhangmeterInstance;
    }

}
