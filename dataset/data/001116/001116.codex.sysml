package LaserRangefinderSystemModel {
    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Wavelength :> ScalarValues::Real;
    attribute def OpticalPower :> ScalarValues::Real;
    attribute def Range :> ScalarValues::Real;
    attribute def TimeDuration :> ScalarValues::Real;
    attribute def Angle :> ScalarValues::Real;
    attribute def Confidence :> ScalarValues::Real;
    attribute def Temperature :> ScalarValues::Real;
    attribute def Voltage :> ScalarValues::Real;
    attribute def Current :> ScalarValues::Real;
    attribute def Energy :> ScalarValues::Real;

    item def LaserPulse {
        attribute wavelength : Wavelength = 905.0 [nm];
        attribute peakPower : OpticalPower = 12.0 [W];
        attribute pulseWidth : TimeDuration = 8.0 [ns];
        attribute emissionTime : TimeDuration;
        attribute beamDivergence : Angle = 1.5 [mrad];
    }

    item def ReflectedPulse {
        attribute wavelength : Wavelength = 905.0 [nm];
        attribute receivedPower : OpticalPower;
        attribute arrivalTime : TimeDuration;
        attribute signalToNoiseRatio : ScalarValues::Real;
    }

    item def RangeMeasurement {
        attribute measuredRange : Range;
        attribute confidence : Confidence;
        attribute acquisitionTime : TimeDuration;
        attribute targetReflectivity : ScalarValues::Real;
        attribute valid : Boolean;
    }

    item def Command {
        attribute commandId : Integer;
        attribute triggerMeasurement : Boolean;
        attribute continuousMode : Boolean;
    }

    item def Status {
        attribute ready : Boolean;
        attribute faultActive : Boolean;
        attribute measuredTemperature : Temperature;
        attribute supplyVoltage : Voltage;
        attribute lastRange : Range;
    }

    port def OpticalTransmitPort {
        out item pulse : LaserPulse;
    }

    port def OpticalReceivePort {
        in item reflection : ReflectedPulse;
    }

    port def ElectricalPowerPort {
        in attribute voltage : Voltage;
        in attribute current : Current;
    }

    port def ControlPort {
        in item command : Command;
        out item status : Status;
    }

    port def DataPort {
        out item rangeMeasurement : RangeMeasurement;
    }

    part def LaserRangefinder {
        attribute maximumRange : Range = 1200.0 [m];
        attribute minimumRange : Range = 0.5 [m];
        attribute rangeResolution : Range = 0.05 [m];
        attribute measurementRate : ScalarValues::Real = 10.0 [Hz];
        attribute nominalWavelength : Wavelength = 905.0 [nm];
        attribute operatingTemperatureMin : Temperature = -20.0 [degC];
        attribute operatingTemperatureMax : Temperature = 55.0 [degC];

        port power : ElectricalPowerPort;
        port control : ControlPort;
        port data : DataPort;
        port opticalTx : OpticalTransmitPort;
        port opticalRx : OpticalReceivePort;

        part laserEmitter : LaserEmitter;
        part receiver : OpticalReceiver;
        part timingUnit : TimingUnit;
        part processor : MeasurementProcessor;
        part controller : RangefinderController;
        part powerConditioner : PowerConditioner;
        part enclosure : ProtectiveEnclosure;

        connect power to powerConditioner.inputPower;
        connect powerConditioner.logicPower to controller.power;
        connect powerConditioner.emitterPower to laserEmitter.power;
        connect powerConditioner.receiverPower to receiver.power;

        connect controller.fireCommand to laserEmitter.fireControl;
        connect controller.processingCommand to processor.processingControl;
        connect laserEmitter.opticalOutput to opticalTx;
        connect opticalRx to receiver.opticalInput;
        connect laserEmitter.pulseTiming to timingUnit.startTiming;
        connect receiver.detectedPulseTiming to timingUnit.stopTiming;
        connect timingUnit.timeOfFlightOutput to processor.timeOfFlightInput;
        connect receiver.signalQualityOutput to processor.signalQualityInput;
        connect processor.rangeOutput to data;
        connect control to controller.externalControl;
        connect controller.statusOutput to control;

        perform action MeasureDistance;
        exhibit state RangefinderOperatingStates;
    }

    part def LaserEmitter {
        attribute wavelength : Wavelength = 905.0 [nm];
        attribute pulseEnergy : Energy = 0.000096 [J];
        attribute pulseWidth : TimeDuration = 8.0 [ns];

        port power : ElectricalPowerPort;
        port fireControl {
            in attribute fire : Boolean;
        }
        port opticalOutput : OpticalTransmitPort;
        port pulseTiming {
            out attribute emissionTime : TimeDuration;
        }

        action emitPulse {
            in attribute fireRequest : Boolean;
            out item emittedPulse : LaserPulse;
            out attribute emissionTimestamp : TimeDuration;

            first start;
            then decide;
            if fireRequest then sendPulse;
            then recordTime;
            then done;

            action sendPulse {
                emittedPulse.wavelength = wavelength;
                emittedPulse.peakPower = 12.0 [W];
                emittedPulse.pulseWidth = pulseWidth;
                emittedPulse.beamDivergence = 1.5 [mrad];
            }

            action recordTime {
                emissionTimestamp = emittedPulse.emissionTime;
            }
        }
    }

    part def OpticalReceiver {
        attribute detectorGain : ScalarValues::Real = 18.0;
        attribute noiseFloor : OpticalPower = 0.000000002 [W];
        attribute receiverApertureDiameter : LengthValue = 25.0 [mm];

        port power : ElectricalPowerPort;
        port opticalInput : OpticalReceivePort;
        port detectedPulseTiming {
            out attribute arrivalTime : TimeDuration;
        }
        port signalQualityOutput {
            out attribute signalToNoiseRatio : ScalarValues::Real;
            out attribute receivedPower : OpticalPower;
        }

        action detectReflection {
            in item reflectedPulse : ReflectedPulse;
            out attribute detectionValid : Boolean;
            out attribute detectedArrivalTime : TimeDuration;
            out attribute signalToNoiseRatio : ScalarValues::Real;

            first evaluateSignal;
            then decide;
            if reflectedPulse.receivedPower > noiseFloor then acceptReflection;
            else rejectReflection;
            then done;

            action evaluateSignal {
                signalToNoiseRatio = reflectedPulse.signalToNoiseRatio;
            }

            action acceptReflection {
                detectionValid = true;
                detectedArrivalTime = reflectedPulse.arrivalTime;
            }

            action rejectReflection {
                detectionValid = false;
            }
        }
    }

    part def TimingUnit {
        attribute timingResolution : TimeDuration = 150.0 [ps];
        attribute clockFrequency : ScalarValues::Real = 1000000000.0 [Hz];

        port startTiming {
            in attribute emissionTime : TimeDuration;
        }

        port stopTiming {
            in attribute arrivalTime : TimeDuration;
        }

        port timeOfFlightOutput {
            out attribute timeOfFlight : TimeDuration;
        }

        action computeTimeOfFlight {
            in attribute emissionTime : TimeDuration;
            in attribute arrivalTime : TimeDuration;
            out attribute timeOfFlight : TimeDuration;

            first subtractTimes;
            then validatePositive;
            then done;

            action subtractTimes {
                timeOfFlight = arrivalTime - emissionTime;
            }

            action validatePositive {
                assert timeOfFlight > 0.0 [s];
            }
        }
    }

    part def MeasurementProcessor {
        attribute speedOfLight : ScalarValues::Real = 299792458.0 [m/s];
        attribute minimumValidSignalToNoiseRatio : ScalarValues::Real = 8.0;

        port processingControl {
            in attribute enabled : Boolean;
        }

        port timeOfFlightInput {
            in attribute timeOfFlight : TimeDuration;
        }

        port signalQualityInput {
            in attribute signalToNoiseRatio : ScalarValues::Real;
            in attribute receivedPower : OpticalPower;
        }

        port rangeOutput : DataPort;

        action calculateRange {
            in attribute timeOfFlight : TimeDuration;
            in attribute signalToNoiseRatio : ScalarValues::Real;
            out item measurement : RangeMeasurement;

            first validateSignal;
            then computeDistance;
            then assignConfidence;
            then publishMeasurement;
            then done;

            action validateSignal {
                measurement.valid = signalToNoiseRatio >= minimumValidSignalToNoiseRatio;
            }

            action computeDistance {
                measurement.measuredRange = speedOfLight * timeOfFlight / 2.0;
            }

            action assignConfidence {
                measurement.confidence =
                    if signalToNoiseRatio >= 20.0 then 0.98
                    else if signalToNoiseRatio >= 12.0 then 0.90
                    else if signalToNoiseRatio >= 8.0 then 0.75
                    else 0.0;
            }

            action publishMeasurement {
                measurement.acquisitionTime = timeOfFlight;
            }
        }
    }

    part def RangefinderController {
        attribute measurementRequested : Boolean = false;
        attribute continuousModeActive : Boolean = false;
        attribute faultDetected : Boolean = false;

        port power : ElectricalPowerPort;
        port externalControl : ControlPort;
        port fireCommand {
            out attribute fire : Boolean;
        }
        port processingCommand {
            out attribute enabled : Boolean;
        }
        port statusOutput {
            out item status : Status;
        }

        action manageMeasurementCycle {
            in item command : Command;
            out attribute fireLaser : Boolean;
            out attribute enableProcessing : Boolean;

            first readCommand;
            then armMeasurement;
            then triggerEmitter;
            then enableProcessor;
            then reportStatus;
            then done;

            action readCommand {
                measurementRequested = command.triggerMeasurement;
                continuousModeActive = command.continuousMode;
            }

            action armMeasurement {
                assert faultDetected == false;
            }

            action triggerEmitter {
                fireLaser = measurementRequested or continuousModeActive;
            }

            action enableProcessor {
                enableProcessing = fireLaser;
            }

            action reportStatus {
                statusOutput.status.ready = true;
                statusOutput.status.faultActive = faultDetected;
            }
        }
    }

    part def PowerConditioner {
        attribute inputVoltageMin : Voltage = 9.0 [V];
        attribute inputVoltageMax : Voltage = 32.0 [V];
        attribute logicVoltage : Voltage = 3.3 [V];
        attribute emitterVoltage : Voltage = 12.0 [V];

        port inputPower : ElectricalPowerPort;
        port logicPower : ElectricalPowerPort;
        port emitterPower : ElectricalPowerPort;
        port receiverPower : ElectricalPowerPort;
    }

    part def ProtectiveEnclosure {
        attribute ingressProtectionRating : String = "IP54";
        attribute windowTransmission : ScalarValues::Real = 0.92;
        attribute mass : MassValue = 0.42 [kg];
    }

    action def MeasureDistance {
        in item command : Command;
        in item reflectedPulse : ReflectedPulse;
        out item result : RangeMeasurement;

        first receiveCommand;
        then emitLaserPulse;
        then receiveReflection;
        then measureElapsedTime;
        then computeTargetRange;
        then outputResult;
        then done;

        action receiveCommand {
            assert command.triggerMeasurement or command.continuousMode;
        }

        action emitLaserPulse {
            send LaserPulse() via LaserRangefinder::opticalTx;
        }

        action receiveReflection {
            accept reflectedPulse via LaserRangefinder::opticalRx;
        }

        action measureElapsedTime {
            result.acquisitionTime = reflectedPulse.arrivalTime;
        }

        action computeTargetRange {
            result.measuredRange = 299792458.0 [m/s] * result.acquisitionTime / 2.0;
            result.valid = result.measuredRange >= 0.5 [m] and result.measuredRange <= 1200.0 [m];
        }

        action outputResult {
            send result via LaserRangefinder::data;
        }
    }

    state def RangefinderOperatingStates {
        entry action initialize {
            status.ready = false;
            status.faultActive = false;
        }

        state Off;
        state SelfTest;
        state Ready;
        state Measuring;
        state Processing;
        state Reporting;
        state Fault;

        transition initial then Off;
        transition Off_to_SelfTest
            first Off
            accept Command
            if command.triggerMeasurement
            then SelfTest;

        transition SelfTest_to_Ready
            first SelfTest
            if power.voltage >= 9.0 [V] and power.voltage <= 32.0 [V]
            then Ready;

        transition SelfTest_to_Fault
            first SelfTest
            if power.voltage < 9.0 [V] or power.voltage > 32.0 [V]
            then Fault;

        transition Ready_to_Measuring
            first Ready
            accept Command
            if command.triggerMeasurement or command.continuousMode
            then Measuring;

        transition Measuring_to_Processing
            first Measuring
            accept ReflectedPulse
            then Processing;

        transition Processing_to_Reporting
            first Processing
            if RangeMeasurement::valid
            then Reporting;

        transition Processing_to_Fault
            first Processing
            if not RangeMeasurement::valid
            then Fault;

        transition Reporting_to_Ready
            first Reporting
            then Ready;

        transition Fault_to_SelfTest
            first Fault
            accept Command
            if command.triggerMeasurement
            then SelfTest;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The laser rangefinder system shall determine the distance to a target by emitting a laser pulse, detecting the reflected pulse, measuring time of flight, and converting that time into a range measurement. */
        subject rangefinder : LaserRangefinder;

        require constraint {
            rangefinder.minimumRange <= RangeMeasurement::measuredRange and
            RangeMeasurement::measuredRange <= rangefinder.maximumRange
        }
    }

    requirement def RangeAccuracyRequirement {
        doc /* The system shall provide range measurements from 0.5 m to 1200 m with resolution no worse than 0.05 m under valid signal conditions. */
        subject rangefinder : LaserRangefinder;

        require constraint {
            rangefinder.rangeResolution <= 0.05 [m]
        }
    }

    requirement def MeasurementRateRequirement {
        doc /* The system shall support at least ten range measurements per second in continuous measurement mode. */
        subject rangefinder : LaserRangefinder;

        require constraint {
            rangefinder.measurementRate >= 10.0 [Hz]
        }
    }

    requirement def EyeSafeEmissionRequirement {
        doc /* The emitter wavelength and pulse energy shall remain within the configured design limits for a pulsed near-infrared ranging device. */
        subject emitter : LaserEmitter;

        require constraint {
            emitter.wavelength == 905.0 [nm] and
            emitter.pulseEnergy <= 0.0001 [J]
        }
    }

    requirement def EnvironmentalOperationRequirement {
        doc /* The system shall operate across the specified field temperature range. */
        subject rangefinder : LaserRangefinder;

        require constraint {
            rangefinder.operatingTemperatureMin <= -20.0 [degC] and
            rangefinder.operatingTemperatureMax >= 55.0 [degC]
        }
    }

    satisfy PrimaryFunctionRequirement by LaserRangefinder;
    satisfy RangeAccuracyRequirement by MeasurementProcessor;
    satisfy MeasurementRateRequirement by RangefinderController;
    satisfy EyeSafeEmissionRequirement by LaserEmitter;
    satisfy EnvironmentalOperationRequirement by ProtectiveEnclosure;
}