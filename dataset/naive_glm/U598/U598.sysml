package AnemometerSystem {

    package ValueTypes {
        value def SpeedUnit :> ISQ::VelocityUnit;
        value def AngularSpeedUnit :> ISQ::AngularVelocityUnit;
        value def AngleUnit :> ISQ::PlaneAngleUnit;
        value def VoltageUnit :> ISQ::ElectricPotentialUnit;
        value def TemperatureUnit :> ISQ::ThermodynamicTemperatureUnit;
        value def TimeUnit :> ISQ::TimeUnit;

        value def WindSpeed :> Real { unit 'm/s'; }
        value def CupRotationRate :> Real { unit 'rev/s'; }
        value def WindDirection :> Real { unit 'deg'; }
        value def VaneAngle :> Real { unit 'deg'; }
        value def Voltage :> Real { unit 'V'; }
        value def Temperature :> Real { unit 'degC'; }
        value def TimeStamp :> Real { unit 's'; }
        value def SpeedCalibrationFactor :> Real { unit '(m/s)/V'; }
        value def DirectionOffset :> Real { unit 'deg'; }
        value def SpeedTolerance :> Real { unit 'm/s'; }
        value def DirectionTolerance :> Real { unit 'deg'; }
    }

    package Items {
        item def RawVoltageSignal {
            attribute magnitude : ValueTypes::Voltage;
            attribute sampledAt : ValueTypes::TimeStamp;
        }

        item def WindMeasurementPackage {
            attribute speed : ValueTypes::WindSpeed;
            attribute direction : ValueTypes::WindDirection;
            attribute timestamp : ValueTypes::TimeStamp;
            attribute ambientTemperature : ValueTypes::Temperature;
        }

        item def CalibrationParameters {
            attribute speedFactor : ValueTypes::SpeedCalibrationFactor;
            attribute directionOffset : ValueTypes::DirectionOffset;
            attribute speedOffset : ValueTypes::Voltage;
        }

        item def WindEnvironment {
            attribute speed : ValueTypes::WindSpeed;
            attribute direction : ValueTypes::WindDirection;
            attribute temperature : ValueTypes::Temperature;
        }
    }

    package Ports {
        port def VoltageOutput {
            out signal : Items::RawVoltageSignal;
        }

        port def MeasurementOutput {
            out measurement : Items::WindMeasurementPackage;
        }

        port def WindInput {
            in wind : Items::WindEnvironment;
        }

        port def CalibrationInput {
            in params : Items::CalibrationParameters;
        }
    }

    package Components {

        part def CupAssembly {
            attribute numberOfCups : Integer = 3;
            attribute cupRadius : ValueTypes::WindSpeed; // effective arm radius in m equivalent
            port windIn : Ports::WindInput;
            attribute rotationRate : ValueTypes::CupRotationRate;

            action def RespondToWind {
                in wind : Items::WindEnvironment;
                out rotation : ValueTypes::CupRotationRate;
            }

            perform respond : RespondToWind {
                in wind = windIn.wind;
                out rotation = rotationRate;
            }
        }

        part def DirectionVane {
            attribute vaneLength : Real = 0.30 [m];
            port windIn : Ports::WindInput;
            attribute vaneAngle : ValueTypes::VaneAngle;

            action def AlignWithWind {
                in wind : Items::WindEnvironment;
                out angle : ValueTypes::VaneAngle;
            }

            perform align : AlignWithWind {
                in wind = windIn.wind;
                out angle = vaneAngle;
            }
        }

        part def RotationSensor {
            attribute supplyVoltage : ValueTypes::Voltage = 5.0 [V];
            attribute sensitivity : Real = 1.0 [V/(rev/s)];
            port mechanicalIn {
                in rotation : ValueTypes::CupRotationRate;
            }
            port voltageOut : Ports::VoltageOutput;

            action def TransduceRotation {
                in rotation : ValueTypes::CupRotationRate;
                out signal : Items::RawVoltageSignal;
            }

            perform transduce : TransduceRotation {
                in rotation = mechanicalIn.rotation;
                out signal = voltageOut.signal;
            }
        }

        part def AngleSensor {
            attribute supplyVoltage : ValueTypes::Voltage = 5.0 [V];
            attribute sensitivity : Real = 0.01389 [V/deg];
            port mechanicalIn {
                in angle : ValueTypes::VaneAngle;
            }
            port voltageOut : Ports::VoltageOutput;

            action def TransduceAngle {
                in angle : ValueTypes::VaneAngle;
                out signal : Items::RawVoltageSignal;
            }

            perform transduce : TransduceAngle {
                in angle = mechanicalIn.angle;
                out signal = voltageOut.signal;
            }
        }

        part def DataProcessor {
            attribute operatingTemperatureMin : ValueTypes::Temperature = -40.0 [degC];
            attribute operatingTemperatureMax : ValueTypes::Temperature = 60.0 [degC];
            attribute cyclePeriod : ValueTypes::TimeStamp = 1.0 [s];
            attribute calibration : Items::CalibrationParameters;

            port speedSignalIn : Ports::VoltageOutput;
            port directionSignalIn : Ports::VoltageOutput;
            port calibrationIn : Ports::CalibrationInput;
            port measurementOut : Ports::MeasurementOutput;

            action def AcquireSensorData {
                in speedSignal : Items::RawVoltageSignal;
                in directionSignal : Items::RawVoltageSignal;
                out speedVoltage : ValueTypes::Voltage;
                out directionVoltage : ValueTypes::Voltage;
                out timestamp : ValueTypes::TimeStamp;

                perform {
                    speedVoltage = speedSignal.magnitude;
                    directionVoltage = directionSignal.magnitude;
                    timestamp = speedSignal.sampledAt;
                }
            }

            action def ComputeMeasurements {
                in speedVoltage : ValueTypes::Voltage;
                in directionVoltage : ValueTypes::Voltage;
                in timestamp : ValueTypes::TimeStamp;
                in params : Items::CalibrationParameters;
                out measurement : Items::WindMeasurementPackage;

                perform {
                    var computedSpeed : ValueTypes::WindSpeed =
                        (speedVoltage - params.speedOffset) * params.speedFactor;
                    var computedDirection : ValueTypes::WindDirection =
                        directionVoltage / (0.01389 [V/deg]) + params.directionOffset;
                    measurement.speed = computedSpeed;
                    measurement.direction = computedDirection;
                    measurement.timestamp = timestamp;
                    measurement.ambientTemperature = 20.0 [degC];
                }
            }

            action def OutputMeasurement {
                in measurement : Items::WindMeasurementPackage;
                out outMeasurement : Items::WindMeasurementPackage;

                perform {
                    outMeasurement = measurement;
                }
            }

            state def ProcessingCycle {
                entry;
                then Acquiring;

                state Acquiring {
                    entry perform acquire : AcquireSensorData {
                        in speedSignal = speedSignalIn.signal;
                        in directionSignal = directionSignalIn.signal;
                    }
                    do send AcquireSensorData;
                    then Computing;
                }

                state Computing {
                    entry perform compute : ComputeMeasurements {
                        in params = calibration;
                    }
                    then Outputting;
                }

                state Outputting {
                    entry perform output : OutputMeasurement {
                        out outMeasurement = measurementOut.measurement;
                    }
                    then Acquiring;
                }
            }

            perform processing : ProcessingCycle;
        }
    }

    package System {

        part def AnemometerSystem {
            attribute systemId : String;
            attribute manufacturer : String = "Meteorological Instruments Inc.";
            attribute model : String = "CupVane-A100";

            port windInput : Ports::WindInput;
            port calibrationPort : Ports::CalibrationInput;
            port dataOutput : Ports::MeasurementOutput;

            part cupAssembly : Components::CupAssembly;
            part directionVane : Components::DirectionVane;
            part rotationSensor : Components::RotationSensor;
            part angleSensor : Components::AngleSensor;
            part processor : Components::DataProcessor;

            connection windToCups connect windInput.wind to cupAssembly.windIn.wind;
            connection windToVane connect windInput.wind to directionVane.windIn.wind;

            connection cupRotation connect cupAssembly.rotationRate to rotationSensor.mechanicalIn.rotation;
            connection vaneAngle connect directionVane.vaneAngle to angleSensor.mechanicalIn.angle;

            connection speedVoltage connect rotationSensor.voltageOut.signal to processor.speedSignalIn.signal;
            connection directionVoltage connect angleSensor.voltageOut.signal to processor.directionSignalIn.signal;

            connection calibrationFlow connect calibrationPort.params to processor.calibrationIn.params;
            connection outputFlow connect processor.measurementOut.measurement to dataOutput.measurement;
        }
    }

    package Requirements {

        requirement def SpeedAccuracyRequirement {
            attribute tolerance : ValueTypes::SpeedTolerance = 0.5 [m/s];
            subject measurement : Items::WindMeasurementPackage;
            objective {
                require |measurement.speed - trueSpeed| <= tolerance
            }
        }

        requirement def DirectionAccuracyRequirement {
            attribute tolerance : ValueTypes::DirectionTolerance = 5.0 [deg];
            subject measurement : Items::WindMeasurementPackage;
            objective {
                require |measurement.direction - trueDirection| <= tolerance
            }
        }

        requirement def OperatingTemperatureRequirement {
            attribute minTemp : ValueTypes::Temperature = -40.0 [degC];
            attribute maxTemp : ValueTypes::Temperature = 60.0 [degC];
            subject system : System::AnemometerSystem;
            objective {
                require system.processor.operatingTemperatureMin <= minTemp
                    and system.processor.operatingTemperatureMax >= maxTemp
            }
        }

        requirement def ContinuousOperationRequirement {
            subject processor : Components::DataProcessor;
            objective {
                require processor.cyclePeriod <= 1.0 [s]
            }
        }

        requirement def WindSpeedRangeRequirement {
            attribute minSpeed : ValueTypes::WindSpeed = 0.0 [m/s];
            attribute maxSpeed : ValueTypes::WindSpeed = 75.0 [m/s];
            subject system : System::AnemometerSystem;
            objective {
                require trueSpeed >= minSpeed and trueSpeed <= maxSpeed
            }
        }

        requirement def AnemometerSystemRequirements {
            requirement speedAccuracy : SpeedAccuracyRequirement;
            requirement directionAccuracy : DirectionAccuracyRequirement;
            requirement operatingTemp : OperatingTemperatureRequirement;
            requirement continuousOp : ContinuousOperationRequirement;
            requirement speedRange : WindSpeedRangeRequirement;
        }

        verification def VerifySpeedAccuracy {
            subject system : System::AnemometerSystem;
            objective {
                verify speedAccuracy;
            }
        }

        verification def VerifyDirectionAccuracy {
            subject system : System::AnemometerSystem;
            objective {
                verify directionAccuracy;
            }
        }
    }

    package Instances {
        part def CalibrationDefault :> Items::CalibrationParameters {
            attribute speedFactor = 12.5 [(m/s)/V];
            attribute directionOffset = 0.0 [deg];
            attribute speedOffset = 0.0 [V];
        }

        instance defaultCalibration : CalibrationDefault;

        part systemUnderTest : System::AnemometerSystem {
            attribute systemId = "ANEMO-001";
            ref calibration : CalibrationDefault = defaultCalibration;
        }
    }

}
