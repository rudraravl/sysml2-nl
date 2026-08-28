package WindTurbineSystem {
    import ISQ::*;
    import ScalarValues::*;
    import SI::*;

    // ---- Value types with units ----
    value def WindSpeed :> Speed { }
    value def WindDir :> Angle { }
    value def RotorSpeed :> AngularVelocity { }
    value def MechTorque :> Torque { }
    value def ElecPower :> Power { }
    value def ElecVoltage :> ElectricPotential { }
    value def ElecCurrent :> ElectricCurrent { }
    value def Frequency :> Frequency { }
    value def PitchAngleValue :> Angle { }
    value def YawAngleValue :> Angle { }
    value def Temperature :> Temperature { }
    value def BrakePressure :> Pressure { }

    // ---- Item definitions ----
    item def WindFlow {
        attribute speed : WindSpeed;
        attribute direction : WindDir;
    }

    item def MechanicalDrive {
        attribute torque : MechTorque;
        attribute rotSpeed : RotorSpeed;
    }

    item def ElectricalOutput {
        attribute voltage : ElecVoltage;
        attribute current : ElecCurrent;
        attribute frequency : Frequency;
        attribute power : ElecPower;
    }

    item def SensorReading {
        attribute windSpeed : WindSpeed;
        attribute windDirection : WindDir;
        attribute rotorSpeed : RotorSpeed;
        attribute generatorSpeed : RotorSpeed;
        attribute powerOutput : ElecPower;
        attribute nacelleTemperature : Temperature;
    }

    item def PitchCommand {
        attribute angle : PitchAngleValue;
    }

    item def YawCommand {
        attribute angle : YawAngleValue;
    }

    item def BrakeCommand {
        attribute engage : Boolean;
        attribute pressure : BrakePressure;
    }

    item def GeneratorCommand {
        attribute excitation : Real;
    }

    // ---- Port definitions ----
    port def WindInPort {
        in item wind : WindFlow;
    }

    port def MechLinkPort {
        in item driveIn : MechanicalDrive;
        out item driveOut : MechanicalDrive;
    }

    port def ElecOutPort {
        out item power : ElectricalOutput;
    }

    port def GridConnPort {
        in item gridPower : ElectricalOutput;
    }

    port def SensorDataPort {
        out item reading : SensorReading;
    }

    port def PitchCtrlPort {
        in item cmd : PitchCommand;
    }

    port def YawCtrlPort {
        in item cmd : YawCommand;
    }

    port def BrakeCtrlPort {
        in item cmd : BrakeCommand;
    }

    port def GenCtrlPort {
        in item cmd : GeneratorCommand;
    }

    // ---- Requirements ----
    requirement def PowerGenerationRequirement {
        doc /* The wind turbine shall convert wind kinetic energy into electrical power for the grid. */
        subject turbine : WindTurbine;
        requirement {
            subject = turbine;
            constraint { turbine.ratedPower >= 5.0e6 }
        }
    }

    requirement def CutInSpeedRequirement {
        doc /* The turbine shall start generating only above cut-in wind speed. */
        subject turbine : WindTurbine;
        attribute cutInSpeed : WindSpeed = 3.0 [m/s];
        requirement {
            subject = turbine;
            constraint { turbine.windSpeed >= cutInSpeed }
        }
    }

    requirement def CutOutSpeedRequirement {
        doc /* The turbine shall shut down above cut-out wind speed to prevent damage. */
        subject turbine : WindTurbine;
        attribute cutOutSpeed : WindSpeed = 25.0 [m/s];
        requirement {
            subject = turbine;
            constraint { turbine.windSpeed <= cutOutSpeed }
        }
    }

    requirement def YawAlignmentRequirement {
        doc /* The yaw system shall keep the rotor facing into the wind within 5 degrees. */
        subject yaw : YawSystem;
        attribute tolerance : Angle = 0.0873 [rad];
        requirement {
            subject = yaw;
            constraint { abs(yaw.alignmentError) <= tolerance }
        }
    }

    requirement def EmergencyStopRequirement {
        doc /* The brake system shall bring the rotor to a full stop within 10 seconds during emergency shutdown. */
        subject brake : BrakeSystem;
        attribute maxStopTime : Time = 10.0 [s];
        requirement {
            subject = brake;
            constraint { brake.stopTime <= maxStopTime }
        }
    }

    // ---- Part definitions ----
    part def RotorBlade {
        attribute length : Length = 60.0 [m];
        attribute pitchAngle : PitchAngleValue;
        port pitchIn : PitchCtrlPort;
        exhibit state pitchBehavior {
            entry; then adjusting;
            state adjusting;
            transition adjusting to adjusting when pitchIn.cmd.angle <> pitchAngle;
        }
        action adjustPitch(in target : PitchAngleValue) {
            assign pitchAngle = target;
        }
    }

    part def RotorHub {
        attribute bladeCount : Integer = 3;
        port mechOut : MechLinkPort;
        part blades : RotorBlade[3];
    }

    part def RotorAssembly {
        attribute rotorDiameter : Length = 120.0 [m];
        attribute rotorSpeed : RotorSpeed;
        port windIn : WindInPort;
        port mechOut : MechLinkPort;
        part hub : RotorHub;
        connection windToBlades : WindFlow = windIn.wind;
        connection hubToMech : MechanicalDrive = hub.mechOut.driveOut to mechOut.driveOut;
    }

    part def Gearbox {
        attribute gearRatio : Real = 100.0;
        attribute efficiency : Real = 0.97;
        port lowSpeedIn : MechLinkPort;
        port highSpeedOut : MechLinkPort;
        action stepUp(in low : MechanicalDrive, out high : MechanicalDrive) {
            assign high.rotSpeed = low.rotSpeed * gearRatio;
            assign high.torque = low.torque / gearRatio * efficiency;
        }
    }

    part def Generator {
        attribute ratedPower : ElecPower = 5.0e6 [W];
        attribute ratedVoltage : ElecVoltage = 690.0 [V];
        attribute ratedFrequency : Frequency = 50.0 [Hz];
        port mechIn : MechLinkPort;
        port elecOut : ElecOutPort;
        port genCtrl : GenCtrlPort;
        action generate(in drive : MechanicalDrive, out power : ElectricalOutput) {
            assign power.power = drive.torque * drive.rotSpeed;
            assign power.voltage = ratedVoltage;
            assign power.frequency = ratedFrequency;
        }
    }

    part def Drivetrain {
        port mechIn : MechLinkPort;
        port elecOut : ElecOutPort;
        port genCtrl : GenCtrlPort;
        part gearbox : Gearbox;
        part generator : Generator;
        connection rotorToGearbox : MechanicalDrive = mechIn.driveOut to gearbox.lowSpeedIn.driveIn;
        connection gearboxToGenerator : MechanicalDrive = gearbox.highSpeedOut.driveOut to generator.mechIn.driveIn;
        connection generatorToElec : ElectricalOutput = generator.elecOut.power to elecOut.power;
    }

    part def YawSystem {
        attribute yawAngle : YawAngleValue;
        attribute alignmentError : Angle;
        port yawCtrl : YawCtrlPort;
        action rotate(in target : YawAngleValue) {
            assign yawAngle = target;
            assign alignmentError = 0.0 [rad];
        }
    }

    part def BrakeSystem {
        attribute engaged : Boolean = false;
        attribute stopTime : Time;
        attribute maxPressure : BrakePressure = 1.0e7 [Pa];
        port brakeCtrl : BrakeCtrlPort;
        exhibit state brakeState {
            entry; then released;
            state released {
                entry { assign engaged = false; }
            }
            state applied {
                entry { assign engaged = true; }
            }
            transition released to applied when brakeCtrl.cmd.engage == true;
            transition applied to released when brakeCtrl.cmd.engage == false;
        }
        action applyBrake(in pressure : BrakePressure) {
            assign engaged = true;
        }
        action releaseBrake {
            assign engaged = false;
        }
    }

    part def Nacelle {
        port windIn : WindInPort;
        port mechOut : MechLinkPort;
        port elecOut : ElecOutPort;
        port genCtrl : GenCtrlPort;
        port yawCtrl : YawCtrlPort;
        port brakeCtrl : BrakeCtrlPort;
        part rotor : RotorAssembly;
        part drivetrain : Drivetrain;
        part yaw : YawSystem;
        part brake : BrakeSystem;
        connection windToRotor : WindFlow = windIn.wind to rotor.windIn.wind;
        connection rotorToDrivetrain : MechanicalDrive = rotor.mechOut.driveOut to drivetrain.mechIn.driveIn;
        connection drivetrainToElec : ElectricalOutput = drivetrain.elecOut.power to elecOut.power;
        connection yawControl : YawCommand = yawCtrl.cmd to yaw.yawCtrl.cmd;
        connection brakeControl : BrakeCommand = brakeCtrl.cmd to brake.brakeCtrl.cmd;
        connection genControl : GeneratorCommand = genCtrl.cmd to drivetrain.genCtrl.cmd;
    }

    part def Tower {
        attribute height : Length = 90.0 [m];
        attribute baseDiameter : Length = 6.0 [m];
        part foundation {
            attribute depth : Length = 20.0 [m];
        }
    }

    part def Anemometer {
        port sensorOut : SensorDataPort;
        action measure(out reading : SensorReading) {
            assign reading.windSpeed = 0.0 [m/s];
            assign reading.windDirection = 0.0 [rad];
        }
    }

    part def ControlSystem {
        attribute cutInSpeed : WindSpeed = 3.0 [m/s];
        attribute cutOutSpeed : WindSpeed = 25.0 [m/s];
        attribute ratedWindSpeed : WindSpeed = 12.0 [m/s];
        attribute windSpeed : WindSpeed;
        attribute powerOutput : ElecPower;
        port sensorIn : SensorDataPort;
        port pitchOut : PitchCtrlPort;
        port yawOut : YawCtrlPort;
        port brakeOut : BrakeCtrlPort;
        port genOut : GenCtrlPort;

        exhibit state machine TurbineMode {
            entry; then Idle;
            state Idle {
                entry {
                    assign brakeOut.cmd.engage = true;
                    assign brakeOut.cmd.pressure = 5.0e6 [Pa];
                }
            }
            state StartUp {
                entry {
                    assign brakeOut.cmd.engage = false;
                    assign genOut.cmd.excitation = 0.5;
                }
                do action rampUp {
                    assign pitchOut.cmd.angle = 0.0 [rad];
                }
            }
            state Generating {
                entry {
                    assign genOut.cmd.excitation = 1.0;
                }
                do action optimizePitch {
                    if windSpeed > ratedWindSpeed {
                        assign pitchOut.cmd.angle = 0.262 [rad];
                    } else {
                        assign pitchOut.cmd.angle = 0.0 [rad];
                    }
                }
            }
            state NormalStop {
                entry {
                    assign pitchOut.cmd.angle = 1.571 [rad];
                    assign genOut.cmd.excitation = 0.0;
                }
                do action gradualBrake {
                    assign brakeOut.cmd.engage = true;
                    assign brakeOut.cmd.pressure = 3.0e6 [Pa];
                }
            }
            state EmergencyStop {
                entry {
                    assign pitchOut.cmd.angle = 1.571 [rad];
                    assign brakeOut.cmd.engage = true;
                    assign brakeOut.cmd.pressure = 1.0e7 [Pa];
                    assign genOut.cmd.excitation = 0.0;
                }
            }
            transition Idle to StartUp when sensorIn.reading.windSpeed >= cutInSpeed;
            transition StartUp to Generating when sensorIn.reading.rotorSpeed > 1.0 [rad/s];
            transition Generating to NormalStop when sensorIn.reading.windSpeed >= cutOutSpeed;
            transition Generating to NormalStop when sensorIn.reading.powerOutput >= 5.0e6 [W];
            transition NormalStop to Idle when sensorIn.reading.rotorSpeed == 0.0 [rad/s];
            transition first to EmergencyStop when sensorIn.reading.nacelleTemperature > 350.0 [K];
            transition Generating to EmergencyStop when sensorIn.reading.windSpeed > 30.0 [m/s];
            transition StartUp to EmergencyStop when sensorIn.reading.windSpeed > 30.0 [m/s];
        }

        action computeYaw(in windDir : WindDir, out target : YawAngleValue) {
            assign target = windDir;
        }
    }

    part def GridInterface {
        attribute gridVoltage : ElecVoltage = 690.0 [V];
        attribute gridFrequency : Frequency = 50.0 [Hz];
        port gridIn : ElecOutPort;
        port gridOut : GridConnPort;
        action synchronize(in power : ElectricalOutput, out gridPower : ElectricalOutput) {
            assign gridPower.voltage = gridVoltage;
            assign gridPower.frequency = gridFrequency;
            assign gridPower.power = power.power;
        }
    }

    part def WindTurbine {
        attribute ratedPower : ElecPower = 5.0e6 [W];
        attribute cutInSpeed : WindSpeed = 3.0 [m/s];
        attribute cutOutSpeed : WindSpeed = 25.0 [m/s];
        attribute windSpeed : WindSpeed;
        attribute towerHeight : Length = 90.0 [m];

        port windIn : WindInPort;
        port gridOut : GridConnPort;

        part tower : Tower;
        part nacelle : Nacelle;
        part anemometer : Anemometer;
        part controller : ControlSystem;
        part gridInterface : GridInterface;

        connection windToNacelle : WindFlow = windIn.wind to nacelle.windIn.wind;
        connection sensorToController : SensorReading = anemometer.sensorOut.reading to controller.sensorIn.reading;
        connection controllerPitch : PitchCommand = controller.pitchOut.cmd to nacelle.rotor.hub.blades[1].pitchIn.cmd;
        connection controllerYaw : YawCommand = controller.yawOut.cmd to nacelle.yawCtrl.cmd;
        connection controllerBrake : BrakeCommand = controller.brakeOut.cmd to nacelle.brakeCtrl.cmd;
        connection controllerGen : GeneratorCommand = controller.genOut.cmd to nacelle.genCtrl.cmd;
        connection nacelleToGrid : ElectricalOutput = nacelle.elecOut.power to gridInterface.gridIn.power;
        connection gridToOutput : ElectricalOutput = gridInterface.gridOut.gridPower to gridOut.gridPower;

        satisfy PowerGenerationRequirement by windTurbine;
        satisfy CutInSpeedRequirement by windTurbine;
        satisfy CutOutSpeedRequirement by windTurbine;
        satisfy YawAlignmentRequirement by nacelle.yaw;
        satisfy EmergencyStopRequirement by nacelle.brake;
    }

    part windTurbine : WindTurbine;
}
