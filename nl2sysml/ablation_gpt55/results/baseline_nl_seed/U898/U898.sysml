package StudFinderSystemModel {
    import ScalarValues::*;

    attribute def Length_mm {
        attribute value : Real;
        attribute unitSymbol : String = "mm";
    }

    attribute def Distance_mm {
        attribute value : Real;
        attribute unitSymbol : String = "mm";
    }

    attribute def Voltage_V {
        attribute value : Real;
        attribute unitSymbol : String = "V";
    }

    attribute def Current_mA {
        attribute value : Real;
        attribute unitSymbol : String = "mA";
    }

    attribute def Power_mW {
        attribute value : Real;
        attribute unitSymbol : String = "mW";
    }

    attribute def Frequency_kHz {
        attribute value : Real;
        attribute unitSymbol : String = "kHz";
    }

    attribute def Capacitance_pF {
        attribute value : Real;
        attribute unitSymbol : String = "pF";
    }

    attribute def Time_ms {
        attribute value : Real;
        attribute unitSymbol : String = "ms";
    }

    attribute def Percentage {
        attribute value : Real;
        attribute unitSymbol : String = "%";
    }

    item def ElectricalEnergy {
        attribute voltage : Voltage_V;
        attribute current : Current_mA;
        attribute power : Power_mW;
    }

    item def WallMaterialSample {
        attribute dielectricEstimate : Real;
        attribute surfacePosition : Distance_mm;
        attribute contactPressurePercent : Percentage;
    }

    item def SensorExcitation {
        attribute excitationVoltage : Voltage_V;
        attribute excitationFrequency : Frequency_kHz;
    }

    item def SensorResponse {
        attribute channel1Capacitance : Capacitance_pF;
        attribute channel2Capacitance : Capacitance_pF;
        attribute channel3Capacitance : Capacitance_pF;
        attribute sampleAge : Time_ms;
    }

    item def StudDetectionEstimate {
        attribute studPresent : Boolean;
        attribute estimatedCenterOffset : Distance_mm;
        attribute estimatedEdgeLeft : Distance_mm;
        attribute estimatedEdgeRight : Distance_mm;
        attribute confidence : Percentage;
    }

    item def UserCommand {
        attribute powerButtonPressed : Boolean;
        attribute scanButtonHeld : Boolean;
        attribute calibrationRequested : Boolean;
    }

    item def UserIndication {
        attribute studDetected : Boolean;
        attribute centerlineIndicated : Boolean;
        attribute confidence : Percentage;
        attribute displayText : String;
        attribute audibleToneEnabled : Boolean;
    }

    item def DiagnosticData {
        attribute batteryCharge : Percentage;
        attribute sensorHealthy : Boolean;
        attribute calibrationValid : Boolean;
        attribute faultText : String;
    }

    port def ElectricalPowerPort {
        in item suppliedEnergy : ElectricalEnergy;
        out item powerStatus : DiagnosticData;
    }

    port def RegulatedPowerPort {
        out item regulatedEnergy : ElectricalEnergy;
        in item loadStatus : DiagnosticData;
    }

    port def SensorExcitationPort {
        out item excitation : SensorExcitation;
        in item response : SensorResponse;
    }

    port def WallSensingPort {
        in item wallSample : WallMaterialSample;
        out item estimate : StudDetectionEstimate;
    }

    port def ProcessingPort {
        in item rawResponse : SensorResponse;
        out item detectionEstimate : StudDetectionEstimate;
    }

    port def UserInteractionPort {
        in item command : UserCommand;
        out item indication : UserIndication;
    }

    port def ServicePort {
        out item diagnosticData : DiagnosticData;
    }

    part def Battery {
        attribute nominalVoltage_V : Real = 9.0;
        attribute usableCapacity_mAh : Real = 550.0;
        attribute lowChargeThreshold_percent : Real = 15.0;
        port powerOut : ElectricalPowerPort;
    }

    part def PowerRegulator {
        attribute inputVoltageMin_V : Real = 6.2;
        attribute outputVoltage_V : Real = 3.3;
        attribute maximumOutputCurrent_mA : Real = 180.0;
        port powerIn : ElectricalPowerPort;
        port regulatedOut : RegulatedPowerPort;
    }

    part def CapacitiveSensorArray {
        attribute channelCount : Integer = 3;
        attribute electrodeSpacing_mm : Real = 12.0;
        attribute excitationFrequency_kHz : Real = 125.0;
        attribute nominalFreeSpaceCapacitance_pF : Real = 2.5;
        port excitation : SensorExcitationPort;
        port wallCoupling : WallSensingPort;
    }

    part def WallContactPad {
        attribute padWidth_mm : Real = 70.0;
        attribute padHeight_mm : Real = 35.0;
        attribute acceptableContactPressureMin_percent : Real = 20.0;
        attribute acceptableContactPressureMax_percent : Real = 85.0;
        port wallInterface : WallSensingPort;
    }

    part def Microcontroller {
        attribute clockFrequency_MHz : Real = 48.0;
        attribute adcResolution_bits : Integer = 12;
        attribute samplePeriod_ms : Real = 8.0;
        port regulatedPower : RegulatedPowerPort;
        port sensorInterface : SensorExcitationPort;
        port processing : ProcessingPort;
        port userInterface : UserInteractionPort;
        port service : ServicePort;
    }

    part def SignalProcessor {
        attribute baselineWindow_mm : Real = 120.0;
        attribute edgeGradientThreshold : Real = 0.18;
        attribute centerConfidenceThreshold_percent : Real = 75.0;
        port processingInOut : ProcessingPort;
    }

    part def LEDBarGraph {
        attribute segmentCount : Integer = 7;
        attribute centerSegmentIndex : Integer = 4;
        port userDisplay : UserInteractionPort;
    }

    part def Buzzer {
        attribute centerToneFrequency_Hz : Real = 2400.0;
        attribute edgeToneFrequency_Hz : Real = 1200.0;
        attribute pulsePeriod_ms : Real = 180.0;
        port userAudio : UserInteractionPort;
    }

    part def Display {
        attribute characterCount : Integer = 12;
        attribute refreshPeriod_ms : Real = 100.0;
        port displayInput : UserInteractionPort;
    }

    part def UserButtons {
        attribute buttonCount : Integer = 2;
        attribute debounceTime_ms : Real = 20.0;
        port commandOutput : UserInteractionPort;
    }

    part def UserInterface {
        attribute indicationLatencyMax_ms : Real = 150.0;
        part buttons : UserButtons;
        part ledBar : LEDBarGraph;
        part buzzer : Buzzer;
        part display : Display;
        port externalUser : UserInteractionPort;
        port controllerSide : UserInteractionPort;

        connection buttonsToController connect buttons.commandOutput to controllerSide;
        connection ledToController connect ledBar.userDisplay to controllerSide;
        connection buzzerToController connect buzzer.userAudio to controllerSide;
        connection displayToController connect display.displayInput to controllerSide;
        connection externalToController connect externalUser to controllerSide;
    }

    part def Housing {
        attribute length_mm : Real = 160.0;
        attribute width_mm : Real = 75.0;
        attribute height_mm : Real = 35.0;
        attribute wallFaceFlatness_mm : Real = 0.4;
    }

    part def SensingHead {
        attribute maximumWallThickness_mm : Real = 19.0;
        attribute nominalDetectionDepth_mm : Real = 38.0;
        part sensorArray : CapacitiveSensorArray;
        part contactPad : WallContactPad;
        port controllerInterface : SensorExcitationPort;
        port wallInterface : WallSensingPort;

        connection controllerToSensorArray connect controllerInterface to sensorArray.excitation;
        connection sensorArrayToPad connect sensorArray.wallCoupling to contactPad.wallInterface;
        connection padToWall connect contactPad.wallInterface to wallInterface;
    }

    action def CalibrateToWallSurface {
        in item command : UserCommand;
        in item wallSample : WallMaterialSample;
        out item diagnostic : DiagnosticData;
    }

    action def SweepSensorAcrossWall {
        in item excitation : SensorExcitation;
        in item wallSample : WallMaterialSample;
        out item response : SensorResponse;
    }

    action def EstimateStudCenter {
        in item response : SensorResponse;
        out item estimate : StudDetectionEstimate;
    }

    action def AnnunciateStudCenter {
        in item estimate : StudDetectionEstimate;
        out item indication : UserIndication;
    }

    action def LocateStudCenter {
        in item command : UserCommand;
        in item wallSample : WallMaterialSample;
        out item indication : UserIndication;
        action calibrate : CalibrateToWallSurface;
        action sweep : SweepSensorAcrossWall;
        action estimate : EstimateStudCenter;
        action annunciate : AnnunciateStudCenter;
        succession calibrateBeforeSweep first calibrate then sweep;
        succession sweepBeforeEstimate first sweep then estimate;
        succession estimateBeforeAnnunciate first estimate then annunciate;
    }

    state def StudFinderOperatingState {
        entry; then Off;

        state Off;
        state SelfTest;
        state Ready;
        state Calibrating;
        state Scanning;
        state CenterDetected;
        state Fault;
        state LowBattery;

        transition powerOn first Off then SelfTest;
        transition selfTestPassed first SelfTest then Ready;
        transition selfTestFailed first SelfTest then Fault;
        transition calibrationStarted first Ready then Calibrating;
        transition calibrationComplete first Calibrating then Ready;
        transition scanStarted first Ready then Scanning;
        transition centerFound first Scanning then CenterDetected;
        transition scanReleased first CenterDetected then Ready;
        transition scanCancelled first Scanning then Ready;
        transition batteryLowFromReady first Ready then LowBattery;
        transition batteryLowFromScanning first Scanning then LowBattery;
        transition powerOffFromReady first Ready then Off;
        transition powerOffFromFault first Fault then Off;
        transition powerOffFromLowBattery first LowBattery then Off;
    }

    part def StudFinderSystem {
        attribute primaryFunctionDescription : String = "Locate the centerline of concealed framing studs behind a wall surface and indicate the location to the user.";
        attribute maximumDetectionDepth_mm : Real = 38.0;
        attribute maximumCenterError_mm : Real = 6.0;
        attribute minimumCenterConfidence_percent : Real = 75.0;
        attribute maximumIndicationLatency_ms : Real = 150.0;
        attribute nominalOperatingVoltage_V : Real = 3.3;

        part housing : Housing;
        part battery : Battery;
        part powerRegulator : PowerRegulator;
        part controller : Microcontroller;
        part signalProcessor : SignalProcessor;
        part sensingHead : SensingHead;
        part userInterface : UserInterface;

        port user : UserInteractionPort;
        port wall : WallSensingPort;
        port service : ServicePort;

        connection userToInterface connect user to userInterface.externalUser;
        connection interfaceToController connect userInterface.controllerSide to controller.userInterface;
        connection batteryToRegulator connect battery.powerOut to powerRegulator.powerIn;
        connection regulatorToController connect powerRegulator.regulatedOut to controller.regulatedPower;
        connection controllerToSensingHead connect controller.sensorInterface to sensingHead.controllerInterface;
        connection sensingHeadToWall connect sensingHead.wallInterface to wall;
        connection controllerToProcessor connect controller.processing to signalProcessor.processingInOut;
        connection controllerToService connect controller.service to service;

        perform action locateHiddenStud : LocateStudCenter;
        exhibit state operatingState : StudFinderOperatingState;
    }

    requirement def PrimaryFunctionRequirement {
        subject finder : StudFinderSystem;
        require constraint primaryFunctionStatement {
            finder.primaryFunctionDescription == "Locate the centerline of concealed framing studs behind a wall surface and indicate the location to the user."
        }
    }

    requirement def DetectionDepthRequirement {
        subject finder : StudFinderSystem;
        require constraint depthCapability {
            finder.maximumDetectionDepth_mm >= 38.0
        }
    }

    requirement def CenterAccuracyRequirement {
        subject finder : StudFinderSystem;
        require constraint centerAccuracy {
            finder.maximumCenterError_mm <= 6.0
        }
    }

    requirement def UserIndicationLatencyRequirement {
        subject finder : StudFinderSystem;
        require constraint indicationLatency {
            finder.maximumIndicationLatency_ms <= 150.0
        }
    }

    requirement def DetectionConfidenceRequirement {
        subject finder : StudFinderSystem;
        require constraint confidenceThreshold {
            finder.minimumCenterConfidence_percent >= 75.0
        }
    }

    part studFinder : StudFinderSystem;

    requirement primaryFunction : PrimaryFunctionRequirement {
        subject finder = studFinder;
    }

    requirement detectionDepth : DetectionDepthRequirement {
        subject finder = studFinder;
    }

    requirement centerAccuracy : CenterAccuracyRequirement {
        subject finder = studFinder;
    }

    requirement indicationLatency : UserIndicationLatencyRequirement {
        subject finder = studFinder;
    }

    requirement detectionConfidence : DetectionConfidenceRequirement {
        subject finder = studFinder;
    }
}
