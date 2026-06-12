package VibratingStructureGyroscopeModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def AngularRate {
        attribute value : Real;
        attribute unit : Unit = 'rad/s';
    }

    attribute def Angle {
        attribute value : Real;
        attribute unit : Unit = 'rad';
    }

    attribute def Frequency {
        attribute value : Real;
        attribute unit : Unit = 'Hz';
    }

    attribute def Voltage {
        attribute value : Real;
        attribute unit : Unit = 'V';
    }

    attribute def Current {
        attribute value : Real;
        attribute unit : Unit = 'A';
    }

    attribute def Acceleration {
        attribute value : Real;
        attribute unit : Unit = 'm/s^2';
    }

    attribute def Temperature {
        attribute value : Real;
        attribute unit : Unit = 'K';
    }

    attribute def TimeDuration {
        attribute value : Real;
        attribute unit : Unit = 's';
    }

    attribute def DimensionlessGain {
        attribute value : Real;
    }

    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
    }

    item def DriveSignal {
        attribute amplitude : Voltage;
        attribute frequency : Frequency;
        attribute phase : Angle;
    }

    item def SenseSignal {
        attribute amplitude : Voltage;
        attribute phase : Angle;
        attribute noiseDensity : Real;
    }

    item def AngularRateMeasurement {
        attribute rateX : AngularRate;
        attribute rateY : AngularRate;
        attribute rateZ : AngularRate;
        attribute temperature : Temperature;
        attribute timestamp : TimeDuration;
        attribute valid : Boolean;
    }

    item def DiagnosticStatus {
        attribute driveLocked : Boolean;
        attribute sensePathHealthy : Boolean;
        attribute temperatureInRange : Boolean;
        attribute selfTestPassed : Boolean;
        attribute faultCode : Integer;
    }

    port def PowerInputPort {
        in item power : ElectricalPower;
    }

    port def DriveActuationPort {
        out item signal : DriveSignal;
    }

    port def SensePickupPort {
        in item signal : SenseSignal;
    }

    port def DigitalMeasurementPort {
        out item measurement : AngularRateMeasurement;
        out item status : DiagnosticStatus;
    }

    port def MechanicalRotationPort {
        in item appliedRate : AngularRateMeasurement;
    }

    part def VibratingStructureGyroscope {

        attribute scaleFactor : DimensionlessGain;
        attribute biasStability : AngularRate;
        attribute driveResonantFrequency : Frequency;
        attribute operatingTemperature : Temperature;
        attribute startupTime : TimeDuration;
        attribute fullScaleRate : AngularRate;

        port powerPort : PowerInputPort;
        port rotationInput : MechanicalRotationPort;
        port measurementOutput : DigitalMeasurementPort;

        part resonator : VibratingResonator;
        part driveLoop : DriveControlLoop;
        part senseLoop : SenseDetectionLoop;
        part signalProcessor : RateSignalProcessor;
        part temperatureSensor : TemperatureSensor;
        part selfTestController : SelfTestController;

        connect powerPort.power to driveLoop.powerPort.power;
        connect powerPort.power to senseLoop.powerPort.power;
        connect powerPort.power to signalProcessor.powerPort.power;
        connect powerPort.power to temperatureSensor.powerPort.power;
        connect powerPort.power to selfTestController.powerPort.power;

        connect driveLoop.driveCommand.signal to resonator.driveInput.signal;
        connect resonator.senseOutput.signal to senseLoop.senseInput.signal;
        connect senseLoop.demodulatedOutput.signal to signalProcessor.senseInput.signal;
        connect temperatureSensor.temperatureOutput.measurement to signalProcessor.temperatureInput.measurement;
        connect rotationInput.appliedRate to resonator.rotationInput.appliedRate;
        connect selfTestController.testStimulus.signal to resonator.driveInput.signal;
        connect signalProcessor.measurementOutput.measurement to measurementOutput.measurement;
        connect signalProcessor.measurementOutput.status to measurementOutput.status;

        perform action initialize;
        perform action measureAngularRate;

        state operationalState {
            entry action initialize;

            state Off;
            state Starting;
            state DriveResonanceAcquisition;
            state RateMeasurement;
            state SelfTest;
            state Fault;

            transition first Off;
            transition Off_to_Starting
                first Off then Starting
                accept PowerApplied;

            transition Starting_to_Lock
                first Starting then DriveResonanceAcquisition
                if powerPort.power.voltage.value >= 3.0;

            transition Lock_to_Measure
                first DriveResonanceAcquisition then RateMeasurement
                if driveLoop.locked == true;

            transition Measure_to_SelfTest
                first RateMeasurement then SelfTest
                accept SelfTestRequested;

            transition SelfTest_to_Measure
                first SelfTest then RateMeasurement
                if selfTestController.lastResult.selfTestPassed == true;

            transition Any_to_Fault
                first RateMeasurement then Fault
                if signalProcessor.currentStatus.faultCode != 0;

            transition Fault_to_Starting
                first Fault then Starting
                accept ResetRequested;
        }
    }

    part def VibratingResonator {

        attribute proofMassEquivalent : Real;
        attribute qualityFactor : Real;
        attribute naturalFrequency : Frequency;
        attribute driveAxisAmplitude : Real;
        attribute senseAxisDisplacement : Real;
        attribute coriolisCouplingGain : DimensionlessGain;

        port driveInput : DriveActuationPort;
        port senseOutput : SensePickupPort;
        port rotationInput : MechanicalRotationPort;

        action sustainPrimaryVibration {
            in drive : DriveSignal;
            out displacementAmplitude : Real;
        }

        action generateCoriolisResponse {
            in rate : AngularRateMeasurement;
            in driveAmplitude : Real;
            out senseSignal : SenseSignal;
        }
    }

    part def DriveControlLoop {

        attribute targetAmplitude : Voltage;
        attribute targetFrequency : Frequency;
        attribute phaseError : Angle;
        attribute locked : Boolean;

        port powerPort : PowerInputPort;
        port driveCommand : DriveActuationPort;

        action findResonance {
            out command : DriveSignal;
        }

        action regulateDriveMode {
            in measuredPhase : Angle;
            out command : DriveSignal;
        }
    }

    part def SenseDetectionLoop {

        attribute senseGain : DimensionlessGain;
        attribute quadratureError : Voltage;
        attribute demodulationPhase : Angle;
        attribute noiseFloor : Voltage;

        port powerPort : PowerInputPort;
        port senseInput : SensePickupPort;
        port demodulatedOutput : SensePickupPort;

        action demodulateCoriolisSignal {
            in rawSignal : SenseSignal;
            out rateProportionalSignal : SenseSignal;
        }

        action rejectQuadratureComponent {
            in rawSignal : SenseSignal;
            out correctedSignal : SenseSignal;
        }
    }

    part def RateSignalProcessor {

        attribute calibrationScaleFactor : DimensionlessGain;
        attribute biasEstimate : AngularRate;
        attribute digitalFilterBandwidth : Frequency;
        attribute currentStatus : DiagnosticStatus;

        port powerPort : PowerInputPort;
        port senseInput : SensePickupPort;
        port temperatureInput : DigitalMeasurementPort;
        port measurementOutput : DigitalMeasurementPort;

        action compensateTemperature {
            in uncompensatedRate : AngularRateMeasurement;
            in temperature : Temperature;
            out compensatedRate : AngularRateMeasurement;
        }

        action filterAndValidateRate {
            in compensatedRate : AngularRateMeasurement;
            out validatedRate : AngularRateMeasurement;
            out status : DiagnosticStatus;
        }
    }

    part def TemperatureSensor {

        attribute accuracy : Temperature;
        attribute samplePeriod : TimeDuration;

        port powerPort : PowerInputPort;
        port temperatureOutput : DigitalMeasurementPort;

        action measureTemperature {
            out measuredTemperature : Temperature;
        }
    }

    part def SelfTestController {

        attribute injectedTestAmplitude : Voltage;
        attribute expectedResponseMinimum : Voltage;
        attribute expectedResponseMaximum : Voltage;
        attribute lastResult : DiagnosticStatus;

        port powerPort : PowerInputPort;
        port testStimulus : DriveActuationPort;

        action injectElectrostaticStimulus {
            out stimulus : DriveSignal;
        }

        action evaluateSenseResponse {
            in response : SenseSignal;
            out result : DiagnosticStatus;
        }
    }

    action def initialize {
        out ready : Boolean;
    }

    action def measureAngularRate {
        in actualRotation : AngularRateMeasurement;
        out measuredRotation : AngularRateMeasurement;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The vibrating structure gyroscope shall measure angular rate by sustaining a resonant vibration in a mechanical structure and detecting Coriolis-induced motion caused by rotation. */
        subject gyro : VibratingStructureGyroscope;

        require constraint {
            gyro.measurementOutput.measurement.valid == true
        }
    }

    requirement def DriveResonanceRequirement {
        subject gyro : VibratingStructureGyroscope;

        require constraint {
            gyro.driveLoop.locked == true
        }
    }

    requirement def RateOutputRequirement {
        subject gyro : VibratingStructureGyroscope;

        require constraint {
            gyro.measurementOutput.measurement.rateZ.value <= gyro.fullScaleRate.value and
            gyro.measurementOutput.measurement.rateZ.value >= -gyro.fullScaleRate.value
        }
    }

    requirement def StartupRequirement {
        subject gyro : VibratingStructureGyroscope;

        require constraint {
            gyro.startupTime.value <= 1.0
        }
    }

    requirement def FaultReportingRequirement {
        subject gyro : VibratingStructureGyroscope;

        require constraint {
            gyro.measurementOutput.status.driveLocked == gyro.driveLoop.locked
        }
    }

    part vibratingStructureGyroscopeSystem : VibratingStructureGyroscope {
        attribute scaleFactor = DimensionlessGain { value = 1.0; }
        attribute biasStability = AngularRate { value = 0.00017; unit = 'rad/s'; }
        attribute driveResonantFrequency = Frequency { value = 18000.0; unit = 'Hz'; }
        attribute operatingTemperature = Temperature { value = 298.15; unit = 'K'; }
        attribute startupTime = TimeDuration { value = 0.5; unit = 's'; }
        attribute fullScaleRate = AngularRate { value = 8.73; unit = 'rad/s'; }

        part resonator {
            attribute qualityFactor = 12000.0;
            attribute naturalFrequency = Frequency { value = 18000.0; unit = 'Hz'; }
            attribute driveAxisAmplitude = 1.0;
            attribute senseAxisDisplacement = 0.0;
            attribute coriolisCouplingGain = DimensionlessGain { value = 0.92; }
        }

        part driveLoop {
            attribute targetAmplitude = Voltage { value = 1.8; unit = 'V'; }
            attribute targetFrequency = Frequency { value = 18000.0; unit = 'Hz'; }
            attribute phaseError = Angle { value = 0.0; unit = 'rad'; }
            attribute locked = false;
        }

        part senseLoop {
            attribute senseGain = DimensionlessGain { value = 240.0; }
            attribute quadratureError = Voltage { value = 0.002; unit = 'V'; }
            attribute demodulationPhase = Angle { value = 1.5708; unit = 'rad'; }
            attribute noiseFloor = Voltage { value = 0.00001; unit = 'V'; }
        }

        part signalProcessor {
            attribute calibrationScaleFactor = DimensionlessGain { value = 1.0; }
            attribute biasEstimate = AngularRate { value = 0.0; unit = 'rad/s'; }
            attribute digitalFilterBandwidth = Frequency { value = 100.0; unit = 'Hz'; }
        }

        part temperatureSensor {
            attribute accuracy = Temperature { value = 0.5; unit = 'K'; }
            attribute samplePeriod = TimeDuration { value = 0.01; unit = 's'; }
        }

        part selfTestController {
            attribute injectedTestAmplitude = Voltage { value = 0.25; unit = 'V'; }
            attribute expectedResponseMinimum = Voltage { value = 0.01; unit = 'V'; }
            attribute expectedResponseMaximum = Voltage { value = 0.15; unit = 'V'; }
        }
    }

    satisfy PrimaryFunctionRequirement by vibratingStructureGyroscopeSystem;
    satisfy DriveResonanceRequirement by vibratingStructureGyroscopeSystem;
    satisfy RateOutputRequirement by vibratingStructureGyroscopeSystem;
    satisfy StartupRequirement by vibratingStructureGyroscopeSystem;
    satisfy FaultReportingRequirement by vibratingStructureGyroscopeSystem;
}