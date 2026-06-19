package FluxgateCompassCompassSystem {
    import ScalarValues::*;

    attribute def AngleValue {
        attribute value : Real;
        attribute unitSymbol : String = "deg";
    }

    attribute def MagneticFluxDensityValue {
        attribute value : Real;
        attribute unitSymbol : String = "uT";
    }

    attribute def FrequencyValue {
        attribute value : Real;
        attribute unitSymbol : String = "Hz";
    }

    attribute def VoltageValue {
        attribute value : Real;
        attribute unitSymbol : String = "V";
    }

    attribute def CurrentValue {
        attribute value : Real;
        attribute unitSymbol : String = "mA";
    }

    attribute def PowerValue {
        attribute value : Real;
        attribute unitSymbol : String = "W";
    }

    attribute def TemperatureValue {
        attribute value : Real;
        attribute unitSymbol : String = "degC";
    }

    attribute def TimeValue {
        attribute value : Real;
        attribute unitSymbol : String = "ms";
    }

    attribute def DataRateValue {
        attribute value : Real;
        attribute unitSymbol : String = "bit/s";
    }

    attribute def DimensionlessValue {
        attribute value : Real;
        attribute unitSymbol : String = "1";
    }

    item def ElectricalPower {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
        attribute power : PowerValue;
    }

    item def SensorExcitation {
        attribute excitationFrequency : FrequencyValue;
        attribute driveCurrent : CurrentValue;
        attribute driveVoltage : VoltageValue;
    }

    item def MagneticFieldVector {
        attribute xAxisField : MagneticFluxDensityValue;
        attribute yAxisField : MagneticFluxDensityValue;
        attribute zAxisField : MagneticFluxDensityValue;
    }

    item def RawFluxgateSample {
        attribute positiveHalfCycleX : MagneticFluxDensityValue;
        attribute negativeHalfCycleX : MagneticFluxDensityValue;
        attribute positiveHalfCycleY : MagneticFluxDensityValue;
        attribute negativeHalfCycleY : MagneticFluxDensityValue;
        attribute positiveHalfCycleZ : MagneticFluxDensityValue;
        attribute negativeHalfCycleZ : MagneticFluxDensityValue;
        attribute samplePeriod : TimeValue;
    }

    item def PlatformAttitude {
        attribute roll : AngleValue;
        attribute pitch : AngleValue;
        attribute yawEstimate : AngleValue;
    }

    item def CalibrationData {
        attribute xAxisOffset : MagneticFluxDensityValue;
        attribute yAxisOffset : MagneticFluxDensityValue;
        attribute zAxisOffset : MagneticFluxDensityValue;
        attribute xAxisScaleFactor : DimensionlessValue;
        attribute yAxisScaleFactor : DimensionlessValue;
        attribute zAxisScaleFactor : DimensionlessValue;
        attribute nonOrthogonalityCorrection : AngleValue;
        attribute calibrationTemperature : TemperatureValue;
    }

    item def CompassHeadingReport {
        attribute magneticHeading : AngleValue;
        attribute compensatedFieldStrength : MagneticFluxDensityValue;
        attribute updateRate : FrequencyValue;
        attribute headingUncertainty : AngleValue;
        attribute valid : Boolean;
    }

    item def CompassHealthStatus {
        attribute sensorSaturated : Boolean;
        attribute excitationPresent : Boolean;
        attribute calibrationValid : Boolean;
        attribute processorHealthy : Boolean;
        attribute operatingTemperature : TemperatureValue;
        attribute faultCode : String;
    }

    enum def CompassCommandKind {
        enum powerOn;
        enum powerOff;
        enum startCalibration;
        enum stopCalibration;
        enum requestHeading;
        enum resetFault;
    }

    item def CompassCommand {
        attribute kind : CompassCommandKind;
    }

    item def PowerApplied;
    item def PowerRemoved;
    item def SelfTestPassed;
    item def SelfTestFailed;
    item def CalibrationCompleted;
    item def HeadingRequested;
    item def FaultDetected;
    item def FaultReset;

    port def PowerInputPort {
        in item power : ElectricalPower;
    }

    port def PowerOutputPort {
        out item power : ElectricalPower;
    }

    port def ExcitationInputPort {
        in item excitation : SensorExcitation;
    }

    port def ExcitationOutputPort {
        out item excitation : SensorExcitation;
    }

    port def RawMeasurementOutputPort {
        out item sample : RawFluxgateSample;
    }

    port def RawMeasurementInputPort {
        in item sample : RawFluxgateSample;
    }

    port def CalibrationOutputPort {
        out item calibration : CalibrationData;
    }

    port def CalibrationInputPort {
        in item calibration : CalibrationData;
    }

    port def AttitudeInputPort {
        in item attitude : PlatformAttitude;
    }

    port def HeadingOutputPort {
        out item heading : CompassHeadingReport;
    }

    port def HeadingInputPort {
        in item heading : CompassHeadingReport;
    }

    port def HealthStatusOutputPort {
        out item status : CompassHealthStatus;
    }

    port def HealthStatusInputPort {
        in item status : CompassHealthStatus;
    }

    port def CommandInputPort {
        in item command : CompassCommand;
    }

    port def CommandOutputPort {
        out item command : CompassCommand;
    }

    port def ExternalCompassDataPort {
        in item command : CompassCommand;
        out item heading : CompassHeadingReport;
        out item status : CompassHealthStatus;
    }

    action def GenerateFluxgateExcitation {
        in item inputPower : ElectricalPower;
        out item excitation : SensorExcitation;
    }

    action def SampleFluxgateAxes {
        in item excitation : SensorExcitation;
        out item rawSample : RawFluxgateSample;
    }

    action def ApplyCalibration {
        in item rawSample : RawFluxgateSample;
        in item calibration : CalibrationData;
        out item compensatedField : MagneticFieldVector;
    }

    action def ComputeMagneticHeading {
        in item compensatedField : MagneticFieldVector;
        in item attitude : PlatformAttitude;
        out item heading : CompassHeadingReport;
    }

    action def MonitorCompassHealth {
        in item sensorStatus : CompassHealthStatus;
        in item processorStatus : CompassHealthStatus;
        out item combinedStatus : CompassHealthStatus;
    }

    action def FluxgateCompassPrimaryFunction {
        doc /* Primary high-level function: measure the local magnetic field with fluxgate sensing axes, compensate the measured field with stored calibration and attitude data, and output a valid magnetic heading relative to magnetic north. */
        in item inputPower : ElectricalPower;
        in item attitude : PlatformAttitude;
        in item calibration : CalibrationData;
        out item heading : CompassHeadingReport;
        out item status : CompassHealthStatus;
    }

    state def CompassOperatingStates {
        state off;
        state initializing;
        state selfTesting;
        state calibrating;
        state measuring;
        state reporting;
        state faulted;

        transition powerApplied first off accept PowerApplied then initializing;
        transition beginSelfTest first initializing then selfTesting;
        transition selfTestOk first selfTesting accept SelfTestPassed then measuring;
        transition selfTestNotOk first selfTesting accept SelfTestFailed then faulted;
        transition startCalibration first measuring accept CompassCommand then calibrating;
        transition calibrationDone first calibrating accept CalibrationCompleted then measuring;
        transition headingRequest first measuring accept HeadingRequested then reporting;
        transition reportComplete first reporting then measuring;
        transition detectedFaultFromMeasuring first measuring accept FaultDetected then faulted;
        transition detectedFaultFromCalibration first calibrating accept FaultDetected then faulted;
        transition resetFromFault first faulted accept FaultReset then initializing;
        transition removePowerFromInitializing first initializing accept PowerRemoved then off;
        transition removePowerFromMeasuring first measuring accept PowerRemoved then off;
        transition removePowerFromFault first faulted accept PowerRemoved then off;
    }

    part def FluxgateSensorHead {
        attribute axisCount : DimensionlessValue;
        attribute coreSaturationFluxDensity : MagneticFluxDensityValue;
        attribute sensorNoiseDensity : MagneticFluxDensityValue;

        port excitationInput : ExcitationInputPort;
        port magneticMeasurementOutput : RawMeasurementOutputPort;
        port healthOutput : HealthStatusOutputPort;

        action sampleAxes : SampleFluxgateAxes;
    }

    part def ExcitationDriver {
        attribute nominalExcitationFrequency : FrequencyValue;
        attribute maximumDriveCurrent : CurrentValue;

        port powerInput : PowerInputPort;
        port commandInput : CommandInputPort;
        port excitationOutput : ExcitationOutputPort;
        port healthOutput : HealthStatusOutputPort;

        action generateExcitation : GenerateFluxgateExcitation;
    }

    part def CalibrationMemory {
        attribute retainedCalibrationAgeLimit : TimeValue;
        attribute checksumValid : Boolean;

        port commandInput : CommandInputPort;
        port calibrationOutput : CalibrationOutputPort;
        port healthOutput : HealthStatusOutputPort;
    }

    part def SignalProcessor {
        attribute computationRate : FrequencyValue;
        attribute maximumHeadingUncertainty : AngleValue;

        port rawMeasurementInput : RawMeasurementInputPort;
        port calibrationInput : CalibrationInputPort;
        port attitudeInput : AttitudeInputPort;
        port commandInput : CommandInputPort;
        port headingOutput : HeadingOutputPort;
        port healthOutput : HealthStatusOutputPort;

        action applyCalibration : ApplyCalibration;
        action computeHeading : ComputeMagneticHeading;
    }

    part def HealthMonitor {
        attribute faultDetectionLatency : TimeValue;

        port sensorStatusInput : HealthStatusInputPort;
        port driverStatusInput : HealthStatusInputPort;
        port processorStatusInput : HealthStatusInputPort;
        port calibrationStatusInput : HealthStatusInputPort;
        port combinedStatusOutput : HealthStatusOutputPort;

        action monitorHealth : MonitorCompassHealth;
    }

    part def CommunicationInterface {
        attribute maximumDataRate : DataRateValue;

        port externalData : ExternalCompassDataPort;
        port headingInput : HeadingInputPort;
        port statusInput : HealthStatusInputPort;
        port commandOutput : CommandOutputPort;
    }

    part def FluxgateCompass {
        doc /* Fluxgate compass system that provides magnetic heading by exciting ferromagnetic cores, sensing field-dependent response on orthogonal axes, applying calibration compensation, and reporting heading and health to a navigation host. */

        attribute headingAccuracy : AngleValue;
        attribute nominalUpdateRate : FrequencyValue;
        attribute allowableMagneticFieldRange : MagneticFluxDensityValue;
        attribute startupTime : TimeValue;
        attribute operatingTemperatureLow : TemperatureValue;
        attribute operatingTemperatureHigh : TemperatureValue;

        port powerInput : PowerInputPort;
        port attitudeInput : AttitudeInputPort;
        port dataPort : ExternalCompassDataPort;

        part excitationDriver : ExcitationDriver;
        part sensorHead : FluxgateSensorHead;
        part calibrationMemory : CalibrationMemory;
        part signalProcessor : SignalProcessor;
        part healthMonitor : HealthMonitor;
        part communicationInterface : CommunicationInterface;

        state operatingStates : CompassOperatingStates;
        action primaryFunction : FluxgateCompassPrimaryFunction;

        connect powerInput to excitationDriver.powerInput;
        connect excitationDriver.excitationOutput to sensorHead.excitationInput;
        connect sensorHead.magneticMeasurementOutput to signalProcessor.rawMeasurementInput;
        connect calibrationMemory.calibrationOutput to signalProcessor.calibrationInput;
        connect attitudeInput to signalProcessor.attitudeInput;
        connect signalProcessor.headingOutput to communicationInterface.headingInput;
        connect sensorHead.healthOutput to healthMonitor.sensorStatusInput;
        connect excitationDriver.healthOutput to healthMonitor.driverStatusInput;
        connect signalProcessor.healthOutput to healthMonitor.processorStatusInput;
        connect calibrationMemory.healthOutput to healthMonitor.calibrationStatusInput;
        connect healthMonitor.combinedStatusOutput to communicationInterface.statusInput;
        connect communicationInterface.commandOutput to excitationDriver.commandInput;
        connect communicationInterface.commandOutput to calibrationMemory.commandInput;
        connect communicationInterface.commandOutput to signalProcessor.commandInput;
        connect dataPort to communicationInterface.externalData;
    }

    part def RegulatedCompassPowerSupply {
        attribute nominalVoltage : VoltageValue;
        attribute maximumOutputCurrent : CurrentValue;
        attribute rippleVoltage : VoltageValue;

        port powerOutput : PowerOutputPort;
    }

    part def NavigationHost {
        attribute requiredHeadingUpdateRate : FrequencyValue;

        port compassData : ExternalCompassDataPort;
        port attitudeOutput : AttitudeInputPort;
    }

    part def FluxgateCompassInstallation {
        part supply : RegulatedCompassPowerSupply;
        part compass : FluxgateCompass;
        part host : NavigationHost;

        connect supply.powerOutput to compass.powerInput;
        connect host.compassData to compass.dataPort;
        connect host.attitudeOutput to compass.attitudeInput;
    }

    requirement def PrimaryFluxgateCompassFunctionRequirement {
        doc /* The system shall use a fluxgate compass to measure the local magnetic field and provide a compensated magnetic heading relative to magnetic north at a high level suitable for navigation use. */
        subject compass : FluxgateCompass;

        require constraint {
            compass.headingAccuracy.value <= 2.0
        }

        require constraint {
            compass.nominalUpdateRate.value >= 10.0
        }

        require constraint {
            compass.startupTime.value <= 1000.0
        }
    }

    requirement def MagneticFieldMeasurementRequirement {
        doc /* The compass shall measure magnetic flux density on three orthogonal axes so that horizontal heading can be computed after calibration and attitude compensation. */
        subject sensor : FluxgateSensorHead;

        require constraint {
            sensor.axisCount.value == 3.0
        }
    }

    requirement def HealthReportingRequirement {
        doc /* The compass shall report whether heading output is valid and shall provide health status for sensor saturation, excitation, calibration, and processor operation. */
        subject compass : FluxgateCompass;

        require constraint {
            compass.nominalUpdateRate.value >= 1.0
        }
    }

    requirement primaryFunctionRequirement : PrimaryFluxgateCompassFunctionRequirement;
    requirement magneticMeasurementRequirement : MagneticFieldMeasurementRequirement;
    requirement healthReportingRequirement : HealthReportingRequirement;

    part installedFluxgateCompassSystem : FluxgateCompassInstallation;
}
