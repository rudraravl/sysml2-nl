package 'Bhangmeter System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def LightIntensityValue :> Real;
    attribute def LatitudeValue :> Real;
    attribute def LongitudeValue :> Real;
    attribute def AltitudeValue :> Real;
    attribute def YieldValue :> Real;

    item def FlashDetected;
    item def NuclearConfirmed;
    item def NotNuclear;
    item def TransmissionComplete;

    item def LightSample {
        attribute intensity : LightIntensityValue;
        attribute timestamp : ISQ::TimeValue;
    }

    item def LightCurve {
        attribute samples : LightSample[0..*];
    }

    item def FlashEvent {
        attribute firstPeakTime : ISQ::TimeValue;
        attribute firstPeakIntensity : LightIntensityValue;
        attribute secondPeakTime : ISQ::TimeValue;
        attribute secondPeakIntensity : LightIntensityValue;
        attribute isNuclear : Boolean;
    }

    item def EventReport {
        attribute latitude : LatitudeValue;
        attribute longitude : LongitudeValue;
        attribute altitude : AltitudeValue;
        attribute explosiveYield : YieldValue;
        attribute flash : FlashEvent;
    }

    item def EncryptedReport {
        attribute payload : String;
    }

    port def LightOutPort {
        out lightCurve : LightCurve;
    }

    port def LightInPort {
        in lightCurve : LightCurve;
    }

    port def ReportOutPort {
        out report : EventReport;
    }

    port def ReportInPort {
        in report : EventReport;
    }

    port def EncryptedOutPort {
        out encrypted : EncryptedReport;
    }

    port def EncryptedInPort {
        in encrypted : EncryptedReport;
    }

    action def ScanAtmosphere {
        out lightCurve : LightCurve;
    }

    action def AnalyzeLightCurve {
        in lightCurve : LightCurve;
        out flash : FlashEvent;
    }

    action def EstimateYield {
        in flash : FlashEvent;
        out explosiveYield : YieldValue;
    }

    action def CalculateLocation {
        in flash : FlashEvent;
        out latitude : LatitudeValue;
        out longitude : LongitudeValue;
        out altitude : AltitudeValue;
    }

    action def GenerateReport {
        in flash : FlashEvent;
        in explosiveYield : YieldValue;
        in latitude : LatitudeValue;
        in longitude : LongitudeValue;
        in altitude : AltitudeValue;
        out report : EventReport;
    }

    action def EncryptReport {
        in report : EventReport;
        out encrypted : EncryptedReport;
    }

    action def TransmitReport {
        in encrypted : EncryptedReport;
    }

    action def ReceiveReport {
        in encrypted : EncryptedReport;
    }

    part def OpticalSensor {
        port lightOut : LightOutPort;
        perform action scanAtmosphere : ScanAtmosphere;
        connect scanAtmosphere.lightCurve to lightOut.lightCurve;
    }

    part def SignalProcessor {
        port lightIn : LightInPort;
        port eventOut : ReportOutPort;
        perform action analyzeLightCurve : AnalyzeLightCurve;
        perform action estimateYield : EstimateYield;
        perform action calculateLocation : CalculateLocation;
        perform action generateReport : GenerateReport;
        connect lightIn.lightCurve to analyzeLightCurve.lightCurve;
        connect analyzeLightCurve.flash to estimateYield.flash;
        connect analyzeLightCurve.flash to calculateLocation.flash;
        connect analyzeLightCurve.flash to generateReport.flash;
        connect estimateYield.explosiveYield to generateReport.explosiveYield;
        connect calculateLocation.latitude to generateReport.latitude;
        connect calculateLocation.longitude to generateReport.longitude;
        connect calculateLocation.altitude to generateReport.altitude;
        connect generateReport.report to eventOut.report;
    }

    part def CommModule {
        port reportIn : ReportInPort;
        port groundLink : EncryptedOutPort;
        perform action encryptReport : EncryptReport;
        perform action transmitReport : TransmitReport;
        connect reportIn.report to encryptReport.report;
        connect encryptReport.encrypted to transmitReport.encrypted;
        connect encryptReport.encrypted to groundLink.encrypted;
    }

    part def GroundStation {
        port dataIn : EncryptedInPort;
        perform action receiveReport : ReceiveReport;
        connect dataIn.encrypted to receiveReport.encrypted;
    }

    part def Bhangmeter {
        part opticalSensor : OpticalSensor;
        part signalProcessor : SignalProcessor;
        part commModule : CommModule;
        connect opticalSensor.lightOut to signalProcessor.lightIn;
        connect signalProcessor.eventOut to commModule.reportIn;
        exhibit state bhangmeterStates {
            entry; then activeMonitoring;
            state activeMonitoring {
                do opticalSensor.scanAtmosphere;
                do signalProcessor.analyzeLightCurve;
            }
            transition to_analyzing
                first activeMonitoring
                accept FlashDetected
                then analyzing;
            state analyzing {
                do signalProcessor.estimateYield;
                do signalProcessor.calculateLocation;
                do signalProcessor.generateReport;
            }
            transition to_transmitting
                first analyzing
                accept NuclearConfirmed
                then transmitting;
            transition to_monitoring_from_analyzing
                first analyzing
                accept NotNuclear
                then activeMonitoring;
            state transmitting {
                do commModule.encryptReport;
                do commModule.transmitReport;
            }
            transition to_monitoring_from_transmitting
                first transmitting
                accept TransmissionComplete
                then activeMonitoring;
        }
    }

    part def BhangmeterSystem {
        part bhangmeter : Bhangmeter;
        part groundStation : GroundStation;
        connect bhangmeter.commModule.groundLink to groundStation.dataIn;
    }

    requirement def NuclearDetectionRequirement {
        text "The Bhangmeter system shall autonomously detect nuclear detonations from orbit and transmit event reports to the ground station.";
    }

    requirement def DoubleFlashDetectionRequirement {
        text "The system shall detect a short, intense first peak followed by a broader, more intense second peak.";
    }

    requirement def YieldEstimationRequirement {
        text "The system shall estimate explosive yield based on peak timing and intensities.";
    }

    requirement def LocationCalculationRequirement {
        text "The system shall calculate latitude, longitude, and altitude of the event.";
    }

    requirement def SecureTransmissionRequirement {
        text "The system shall encrypt the event report and transmit it to a ground station.";
    }

    part bhangmeterSystem : BhangmeterSystem;
}
