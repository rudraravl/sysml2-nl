package ContinuousGlucoseMonitorSpecification {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;
    import Time::*;

    attribute def MilligramPerDeciliter :> Real {
        doc /* Blood glucose concentration unit: mg/dL. */
    }

    attribute def Minute :> Real {
        doc /* Time unit: minute. */
    }

    attribute def Percent :> Real {
        doc /* Percentage unit. */
    }

    attribute def Microampere :> Real {
        doc /* Electrical current unit: microampere. */
    }

    attribute def Millivolt :> Real {
        doc /* Electrical voltage unit: millivolt. */
    }

    attribute def Celsius :> Real {
        doc /* Temperature unit: degree Celsius. */
    }

    attribute def Joule :> Real {
        doc /* Energy unit: joule. */
    }

    enum def TrendDirection {
        enum stable;
        enum risingSlowly;
        enum risingRapidly;
        enum fallingSlowly;
        enum fallingRapidly;
        enum unknown;
    }

    enum def SensorStatus {
        enum initializing;
        enum active;
        enum needsCalibration;
        enum signalInvalid;
        enum expired;
        enum failed;
    }

    enum def AlertSeverity {
        enum advisory;
        enum warning;
        enum urgent;
    }

    item def InterstitialFluidSample {
        attribute timestamp : TimeInstant;
        attribute rawSensorCurrent : Microampere;
        attribute localTemperature : Celsius;
        attribute sensorImpedance : Real;
    }

    item def GlucoseEstimate {
        attribute timestamp : TimeInstant;
        attribute glucose : MilligramPerDeciliter;
        attribute rateOfChange : MilligramPerDeciliter;
        attribute trend : TrendDirection;
        attribute confidence : Percent;
        attribute status : SensorStatus;
    }

    item def CalibrationEntry {
        attribute timestamp : TimeInstant;
        attribute referenceGlucose : MilligramPerDeciliter;
        attribute accepted : Boolean;
    }

    item def GlucoseAlert {
        attribute timestamp : TimeInstant;
        attribute severity : AlertSeverity;
        attribute measuredGlucose : MilligramPerDeciliter;
        attribute messageCode : String;
        attribute acknowledged : Boolean;
    }

    item def BatteryEnergy {
        attribute availableEnergy : Joule;
        attribute stateOfCharge : Percent;
    }

    item def WirelessPacket {
        attribute timestamp : TimeInstant;
        attribute payloadBytes : Integer;
        attribute encrypted : Boolean;
        attribute sequenceNumber : Integer;
    }

    port def SamplePort {
        out sample : InterstitialFluidSample;
    }

    port def EstimatePort {
        out estimate : GlucoseEstimate;
    }

    port def CalibrationPort {
        in calibration : CalibrationEntry;
    }

    port def AlertPort {
        out alert : GlucoseAlert;
    }

    port def EnergyPort {
        out energy : BatteryEnergy;
    }

    port def WirelessPort {
        out packet : WirelessPacket;
        in acknowledgement : Boolean;
    }

    port def DisplayPort {
        in estimate : GlucoseEstimate;
        in alert : GlucoseAlert;
    }

    part def ElectrochemicalGlucoseSensor {
        attribute sensorLifeRemaining : Minute;
        attribute measurementInterval : Minute = 5.0;
        attribute minimumOperatingTemperature : Celsius = 5.0;
        attribute maximumOperatingTemperature : Celsius = 45.0;
        attribute currentNoiseLimit : Microampere = 0.03;
        attribute insertionWarmupTime : Minute = 120.0;
        attribute status : SensorStatus = SensorStatus::initializing;

        port sampleOut : SamplePort;

        action senseInterstitialGlucose {
            in localTemperature : Celsius;
            out rawSample : InterstitialFluidSample;

            first start;
            then validateTemperature;
            then measureElectrochemicalCurrent;
            then estimateSensorImpedance;
            then publishSample;
            then done;

            flow localTemperature to validateTemperature.temperature;
            flow measureElectrochemicalCurrent.current to rawSample.rawSensorCurrent;
            flow estimateSensorImpedance.impedance to rawSample.sensorImpedance;
            flow rawSample to sampleOut.sample;
        }

        state def SensorLifecycle {
            state initializing;
            state active;
            state signalInvalid;
            state expired;
            state failed;

            initial then initializing;

            transition initializing_to_active
                first initializing
                accept after insertionWarmupTime
                then active;

            transition active_to_signalInvalid
                first active
                accept when status == SensorStatus::signalInvalid
                then signalInvalid;

            transition signalInvalid_to_active
                first signalInvalid
                accept when status == SensorStatus::active
                then active;

            transition active_to_expired
                first active
                accept when sensorLifeRemaining <= 0.0
                then expired;

            transition any_to_failed
                first active
                accept when status == SensorStatus::failed
                then failed;
        }
    }

    part def GlucoseSignalProcessor {
        attribute lowGlucoseThreshold : MilligramPerDeciliter = 70.0;
        attribute highGlucoseThreshold : MilligramPerDeciliter = 180.0;
        attribute urgentLowThreshold : MilligramPerDeciliter = 55.0;
        attribute rapidRiseThreshold : MilligramPerDeciliter = 3.0;
        attribute rapidFallThreshold : MilligramPerDeciliter = -3.0;
        attribute minimumConfidenceForDisplay : Percent = 80.0;
        attribute calibrationAgeLimit : Minute = 720.0;

        port sampleIn : SamplePort;
        port calibrationIn : CalibrationPort;
        port estimateOut : EstimatePort;
        port alertOut : AlertPort;

        item recentSamples : InterstitialFluidSample[0..12];
        item latestEstimate : GlucoseEstimate;
        item activeCalibration : CalibrationEntry;

        action filterAndEstimateGlucose {
            in sample : InterstitialFluidSample;
            in calibration : CalibrationEntry;
            out estimate : GlucoseEstimate;

            first receiveSample;
            then rejectOutliers;
            then compensateTemperature;
            then convertCurrentToGlucose;
            then computeRateOfChange;
            then classifyTrend;
            then computeConfidence;
            then publishEstimate;
            then done;

            flow sample to rejectOutliers.inputSample;
            flow calibration to convertCurrentToGlucose.calibration;
            flow estimate to estimateOut.estimate;
        }

        action evaluateAlerts {
            in estimate : GlucoseEstimate;
            out alert : GlucoseAlert;

            first receiveEstimate;
            then compareAgainstThresholds;
            then classifySeverity;
            then publishAlert;
            then done;

            flow estimate to compareAgainstThresholds.estimate;
            flow alert to alertOut.alert;
        }

        state def ProcessingMode {
            state awaitingWarmup;
            state estimating;
            state requestingCalibration;
            state degraded;
            state unavailable;

            initial then awaitingWarmup;

            transition warmup_complete
                first awaitingWarmup
                accept when sampleIn.sample.status == SensorStatus::active
                then estimating;

            transition calibration_required
                first estimating
                accept when activeCalibration.accepted == false
                then requestingCalibration;

            transition calibration_accepted
                first requestingCalibration
                accept calibrationIn.calibration
                then estimating;

            transition confidence_degraded
                first estimating
                accept when latestEstimate.confidence < minimumConfidenceForDisplay
                then degraded;

            transition recovered
                first degraded
                accept when latestEstimate.confidence >= minimumConfidenceForDisplay
                then estimating;

            transition unavailable_signal
                first estimating
                accept when latestEstimate.status == SensorStatus::failed or latestEstimate.status == SensorStatus::expired
                then unavailable;
        }
    }

    part def Transmitter {
        attribute transmitInterval : Minute = 5.0;
        attribute packetRetryLimit : Integer = 3;
        attribute encryptionEnabled : Boolean = true;
        attribute radioOutputPowerMilliwatt : Real = 1.0;

        port estimateIn : EstimatePort;
        port alertIn : AlertPort;
        port wirelessOut : WirelessPort;
        port energyIn : EnergyPort;

        action buildAndTransmitPacket {
            in estimate : GlucoseEstimate;
            in alert : GlucoseAlert;
            out packet : WirelessPacket;

            first collectData;
            then encodePayload;
            then encryptPayload;
            then assignSequenceNumber;
            then transmit;
            then waitForAcknowledgement;
            then done;

            flow estimate to encodePayload.estimate;
            flow alert to encodePayload.alert;
            flow packet to wirelessOut.packet;
        }

        state def TransmissionState {
            state idle;
            state preparingPacket;
            state transmitting;
            state waitingForAck;
            state retrying;
            state radioSuspended;

            initial then idle;

            transition periodic_send
                first idle
                accept after transmitInterval
                then preparingPacket;

            transition packet_ready
                first preparingPacket
                then transmitting;

            transition sent
                first transmitting
                then waitingForAck;

            transition acknowledged
                first waitingForAck
                accept wirelessOut.acknowledgement
                then idle;

            transition missed_ack
                first waitingForAck
                accept when wirelessOut.acknowledgement == false
                then retrying;

            transition retry_limit_reached
                first retrying
                accept when packetRetryLimit <= 0
                then radioSuspended;

            transition energy_low
                first idle
                accept when energyIn.energy.stateOfCharge < 5.0
                then radioSuspended;
        }
    }

    part def ReceiverApplication {
        attribute displayedGlucose : MilligramPerDeciliter;
        attribute displayedTrend : TrendDirection;
        attribute lastUpdateAge : Minute;
        attribute audibleAlertsEnabled : Boolean = true;
        attribute vibrationAlertsEnabled : Boolean = true;

        port wirelessIn : WirelessPort;
        port displayIn : DisplayPort;

        action receiveAndDisplay {
            in packet : WirelessPacket;
            out estimate : GlucoseEstimate;
            out alert : GlucoseAlert;

            first receivePacket;
            then authenticatePacket;
            then decodePayload;
            then updateGlucoseDisplay;
            then notifyUserIfAlerted;
            then done;

            flow packet to receivePacket.packet;
            flow estimate to displayIn.estimate;
            flow alert to displayIn.alert;
        }

        state def UserInterfaceState {
            state monitoring;
            state showingAlert;
            state signalLost;
            state sensorSetup;
            state batteryWarning;

            initial then sensorSetup;

            transition setup_complete
                first sensorSetup
                accept when displayIn.estimate.status == SensorStatus::active
                then monitoring;

            transition alert_received
                first monitoring
                accept displayIn.alert
                then showingAlert;

            transition alert_acknowledged
                first showingAlert
                accept when displayIn.alert.acknowledged
                then monitoring;

            transition signal_timeout
                first monitoring
                accept when lastUpdateAge > 15.0
                then signalLost;

            transition signal_restored
                first signalLost
                accept displayIn.estimate
                then monitoring;
        }
    }

    part def PowerSubsystem {
        attribute nominalBatteryCapacity : Joule = 18000.0;
        attribute lowBatteryThreshold : Percent = 15.0;
        attribute criticalBatteryThreshold : Percent = 5.0;
        attribute currentStateOfCharge : Percent = 100.0;

        port energyOut : EnergyPort;

        action monitorBattery {
            out energy : BatteryEnergy;

            first measureBatteryVoltage;
            then estimateStateOfCharge;
            then publishEnergyAvailability;
            then done;

            flow energy to energyOut.energy;
        }
    }

    part def ContinuousGlucoseMonitor {
        doc /* A wearable medical monitoring system whose primary function is to periodically estimate glucose concentration from interstitial fluid, convert sensor measurements into clinically meaningful glucose trends, and deliver current glucose status and alerts to a user-facing receiver. */

        attribute nominalMeasurementPeriod : Minute = 5.0;
        attribute supportedGlucoseRangeLow : MilligramPerDeciliter = 40.0;
        attribute supportedGlucoseRangeHigh : MilligramPerDeciliter = 400.0;
        attribute expectedSensorWearDuration : Minute = 14400.0;
        attribute maximumDisplayLatency : Minute = 1.0;

        part sensor : ElectrochemicalGlucoseSensor;
        part processor : GlucoseSignalProcessor;
        part transmitter : Transmitter;
        part receiver : ReceiverApplication;
        part power : PowerSubsystem;

        port calibrationInput : CalibrationPort;
        port userDisplay : DisplayPort;
        port wirelessLink : WirelessPort;

        connection sensor_to_processor
            connect sensor.sampleOut to processor.sampleIn;

        connection calibration_to_processor
            connect calibrationInput to processor.calibrationIn;

        connection processor_estimate_to_transmitter
            connect processor.estimateOut to transmitter.estimateIn;

        connection processor_alert_to_transmitter
            connect processor.alertOut to transmitter.alertIn;

        connection power_to_transmitter
            connect power.energyOut to transmitter.energyIn;

        connection transmitter_to_receiver
            connect transmitter.wirelessOut to receiver.wirelessIn;

        connection receiver_to_display
            connect receiver.displayIn to userDisplay;

        perform action monitorGlucoseContinuously {
            first initializeSensor;
            then acquireInterstitialFluidSample;
            then estimateCurrentGlucose;
            then evaluateGlucoseTrend;
            then determineAlertCondition;
            then transmitStatusToReceiver;
            then updateUserDisplay;
            then repeatMonitoringCycle;

            flow sensor.sampleOut.sample to processor.sampleIn.sample;
            flow processor.estimateOut.estimate to transmitter.estimateIn.estimate;
            flow processor.alertOut.alert to transmitter.alertIn.alert;
            flow transmitter.wirelessOut.packet to receiver.wirelessIn.packet;
            flow receiver.displayIn.estimate to userDisplay.estimate;
            flow receiver.displayIn.alert to userDisplay.alert;
        }

        state def SystemOperationalState {
            state off;
            state starting;
            state warmingUpSensor;
            state monitoring;
            state alerting;
            state degradedMonitoring;
            state serviceRequired;
            state shutDown;

            initial then off;

            transition power_on
                first off
                then starting;

            transition start_warmup
                first starting
                then warmingUpSensor;

            transition warmup_complete
                first warmingUpSensor
                accept when sensor.status == SensorStatus::active
                then monitoring;

            transition alert_condition
                first monitoring
                accept processor.alertOut.alert
                then alerting;

            transition alert_cleared
                first alerting
                accept when processor.latestEstimate.glucose >= processor.lowGlucoseThreshold and processor.latestEstimate.glucose <= processor.highGlucoseThreshold
                then monitoring;

            transition degraded_signal
                first monitoring
                accept when processor.latestEstimate.confidence < processor.minimumConfidenceForDisplay
                then degradedMonitoring;

            transition restored_signal
                first degradedMonitoring
                accept when processor.latestEstimate.confidence >= processor.minimumConfidenceForDisplay
                then monitoring;

            transition sensor_failed
                first monitoring
                accept when sensor.status == SensorStatus::failed or sensor.status == SensorStatus::expired
                then serviceRequired;

            transition battery_critical
                first monitoring
                accept when power.currentStateOfCharge <= power.criticalBatteryThreshold
                then shutDown;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The CGM shall periodically estimate glucose concentration from interstitial fluid and provide the user with current glucose value, trend direction, and clinically relevant alerts. */

        subject monitor : ContinuousGlucoseMonitor;

        require constraint {
            monitor.nominalMeasurementPeriod <= 5.0
        }

        require constraint {
            monitor.supportedGlucoseRangeLow <= 40.0 and monitor.supportedGlucoseRangeHigh >= 400.0
        }

        require constraint {
            monitor.maximumDisplayLatency <= 1.0
        }
    }

    requirement def GlucoseEstimationRequirement {
        doc /* The signal processor shall convert electrochemical sensor samples into glucose estimates with a confidence value and trend direction. */

        subject processor : GlucoseSignalProcessor;

        require constraint {
            processor.minimumConfidenceForDisplay >= 80.0
        }
    }

    requirement def HypoglycemiaAlertRequirement {
        doc /* The CGM shall issue an urgent alert when estimated glucose is below the urgent low glucose threshold. */

        subject processor : GlucoseSignalProcessor;

        require constraint {
            processor.urgentLowThreshold <= 55.0
        }
    }

    requirement def HyperglycemiaAlertRequirement {
        doc /* The CGM shall issue a warning alert when estimated glucose is above the high glucose threshold. */

        subject processor : GlucoseSignalProcessor;

        require constraint {
            processor.highGlucoseThreshold <= 180.0
        }
    }

    requirement def WirelessReportingRequirement {
        doc /* The transmitter shall send glucose estimates and alerts to the receiver application using encrypted packets at the monitoring interval. */

        subject transmitter : Transmitter;

        require constraint {
            transmitter.encryptionEnabled == true
        }

        require constraint {
            transmitter.transmitInterval <= 5.0
        }
    }

    requirement def WearDurationRequirement {
        doc /* The sensor shall support continuous monitoring across the expected wear duration before expiration. */

        subject monitor : ContinuousGlucoseMonitor;

        require constraint {
            monitor.expectedSensorWearDuration >= 14400.0
        }
    }

    satisfy PrimaryFunctionRequirement by ContinuousGlucoseMonitor::monitorGlucoseContinuously;
    satisfy GlucoseEstimationRequirement by GlucoseSignalProcessor::filterAndEstimateGlucose;
    satisfy HypoglycemiaAlertRequirement by GlucoseSignalProcessor::evaluateAlerts;
    satisfy HyperglycemiaAlertRequirement by GlucoseSignalProcessor::evaluateAlerts;
    satisfy WirelessReportingRequirement by Transmitter::buildAndTransmitPacket;
    satisfy WearDurationRequirement by ElectrochemicalGlucoseSensor::SensorLifecycle;

    part cgmSystem : ContinuousGlucoseMonitor;
}