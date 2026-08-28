package BEAM_Photovore_Robot {
    import ScalarValues::*;
    import ISQ::*;

    value type Illuminance :> Real { unit "lx"; }
    value type Voltage :> Real { unit "V"; }
    value type Capacitance :> Real { unit "F"; }
    value type ElectricCharge :> Real { unit "C"; }
    value type Resistance :> Real { unit "ohm"; }
    value type ElectricCurrent :> Real { unit "A"; }
    value type Torque :> Real { unit "N*m"; }
    value type AngularVelocity :> Real { unit "rad/s"; }
    value type Duration :> Real { unit "s"; }
    value type Energy :> Real { unit "J"; }
    value type Length :> Real { unit "m"; }
    value type Mass :> Real { unit "kg"; }

    item def LightFlux {
        attribute illuminance : Illuminance;
    }

    item def ElectricEnergy {
        attribute energy : Energy;
        attribute potential : Voltage;
    }

    item def ChargePacket {
        attribute charge : ElectricCharge;
        attribute potential : Voltage;
    }

    port def LightPort {
        in item flux : LightFlux;
        attribute illuminance : Illuminance;
    }

    port def PowerPort {
        in item power : ElectricEnergy;
        attribute voltage : Voltage;
        attribute current : ElectricCurrent;
    }

    port def ChargeFlowPort {
        in item chargePacket : ChargePacket;
        attribute charge : ElectricCharge;
        attribute voltage : Voltage;
    }

    port def DrivePulsePort {
        in item pulse : ElectricEnergy;
        attribute voltage : Voltage;
        attribute energy : Energy;
    }

    port def MechanicalPort {
        attribute torque : Torque;
        attribute speed : AngularVelocity;
    }

    port def SensorPort {
        attribute resistance : Resistance;
        attribute illuminance : Illuminance;
    }

    part def Photoresistor {
        attribute darkResistance : Resistance = 1000000 [ohm];
        attribute lightResistance : Resistance = 5000 [ohm];
        attribute currentResistance : Resistance = 1000000 [ohm];
        attribute sensedIlluminance : Illuminance = 0.0 [lx];

        port lightIn : LightPort;
        port sensorOut : SensorPort;

        action def SenseLight {
            in incidentIlluminance : Illuminance;
            out measuredResistance : Resistance;
            out measuredIlluminance : Illuminance;
        }

        action sense : SenseLight {
            in incidentIlluminance = lightIn.illuminance;
            out measuredResistance = currentResistance;
            out measuredIlluminance = sensedIlluminance;
        }
    }

    part def SolarCell {
        attribute openCircuitVoltage : Voltage = 3.0 [V];
        attribute shortCircuitCurrent : ElectricCurrent = 0.02 [A];
        attribute efficiency : Real = 0.15;
        attribute activeArea : Real = 0.001 [m**2];

        port lightIn : LightPort;
        port powerOut : PowerPort;

        action def Harvest {
            in incidentIlluminance : Illuminance;
            in dt : Duration;
            out harvestedEnergy : ElectricEnergy;
        }

        action harvest : Harvest {
            in incidentIlluminance = lightIn.illuminance;
            out harvestedEnergy = powerOut.power;
        }
    }

    part def Capacitor {
        attribute capacitance : Capacitance = 0.047 [F];
        attribute maxVoltage : Voltage = 5.5 [V];
        attribute thresholdVoltage : Voltage = 2.4 [V];
        attribute storedCharge : ElectricCharge = 0.0 [C];
        attribute storedVoltage : Voltage = 0.0 [V];
        attribute storedEnergy : Energy = 0.0 [J];

        port chargeIn : ChargeFlowPort;
        port dischargeOut : ChargeFlowPort;

        action def Charge {
            in incoming : ElectricEnergy;
            in dt : Duration;
            out newCharge : ElectricCharge;
            out newVoltage : Voltage;
            out newEnergy : Energy;
        }

        action def Discharge {
            out releasedEnergy : ElectricEnergy;
            out releasedCharge : ChargePacket;
        }

        state def ChargeCycle {
            entry; then Charging;

            state Charging {
                doc /* Capacitor passively accumulates charge from solar cell output. */
                entry {
                    storedCharge = 0.0 [C];
                    storedVoltage = 0.0 [V];
                    storedEnergy = 0.0 [J];
                }
                transition Charging -> Discharging
                    when storedVoltage >= thresholdVoltage;
            }

            state Discharging {
                doc /* Capacitor releases all stored energy in a single pulse to the motor. */
                entry {
                    storedCharge = 0.0 [C];
                    storedVoltage = 0.0 [V];
                    storedEnergy = 0.0 [J];
                }
                transition Discharging -> Charging
                    when storedCharge == 0.0 [C];
            }
        }
    }

    part def TriggerCircuit {
        attribute triggerThreshold : Voltage = 2.4 [V];
        attribute isTriggered : Boolean = false;
        attribute hysteresis : Voltage = 0.2 [V];

        port chargeMonitor : ChargeFlowPort;
        port sensorIn : SensorPort;
        port driveOutput : DrivePulsePort;

        action def Monitor {
            in chargeLevel : ElectricCharge;
            in voltageLevel : Voltage;
            in sensorResistance : Resistance;
            out trigger : Boolean;
        }

        action def Fire {
            in trigger : Boolean;
            in availableCharge : ElectricCharge;
            in availableVoltage : Voltage;
            out drivePulse : ElectricEnergy;
        }

        state def TriggerState {
            entry; then Monitoring;

            state Monitoring {
                doc /* Continuously monitors capacitor charge level against threshold. */
                transition Monitoring -> Firing
                    when chargeMonitor.voltage >= triggerThreshold;
            }

            state Firing {
                doc /* Activates and routes capacitor discharge energy to the motor. */
                entry {
                    isTriggered = true;
                }
                transition Firing -> Monitoring
                    when chargeMonitor.charge == 0.0 [C];
            }
        }
    }

    part def DCMotor {
        attribute ratedVoltage : Voltage = 3.0 [V];
        attribute stallTorque : Torque = 0.003 [N*m];
        attribute noLoadSpeed : AngularVelocity = 300.0 [rad/s];
        attribute outputTorque : Torque = 0.0 [N*m];
        attribute outputSpeed : AngularVelocity = 0.0 [rad/s];
        attribute isRunning : Boolean = false;

        port driveIn : DrivePulsePort;
        port mechOut : MechanicalPort;

        action def Drive {
            in pulse : ElectricEnergy;
            out torque : Torque;
            out speed : AngularVelocity;
        }

        action drive : Drive {
            in pulse = driveIn.pulse;
            out torque = mechOut.torque;
            out speed = mechOut.speed;
        }
    }

    part def Wheel {
        attribute radius : Length = 0.015 [m];
        attribute angularVelocity : AngularVelocity = 0.0 [rad/s];
        attribute linearVelocity : Real = 0.0 [m/s];

        port mechIn : MechanicalPort;
    }

    part def Chassis {
        attribute mass : Mass = 0.05 [kg];
        attribute length : Length = 0.08 [m];
        attribute width : Length = 0.06 [m];
        attribute wheelbase : Length = 0.06 [m];
    }

    part def RobotSide {
        attribute sideName : String;

        port lightInput : LightPort;

        part photoresistor : Photoresistor;
        part solarCell : SolarCell;
        part capacitor : Capacitor;
        part trigger : TriggerCircuit;
        part motor : DCMotor;
        part wheel : Wheel;

        connection lightToPhotoresistor : LightPort
            connect lightInput to photoresistor.lightIn;

        connection lightToSolarCell : LightPort
            connect lightInput to solarCell.lightIn;

        connection solarToCapacitor : PowerPort
            connect solarCell.powerOut to capacitor.chargeIn;

        connection capacitorToTrigger : ChargeFlowPort
            connect capacitor.dischargeOut to trigger.chargeMonitor;

        connection photoresistorToTrigger : SensorPort
            connect photoresistor.sensorOut to trigger.sensorIn;

        connection triggerToMotor : DrivePulsePort
            connect trigger.driveOutput to motor.driveIn;

        connection motorToWheel : MechanicalPort
            connect motor.mechOut to wheel.mechIn;
    }

    part def BEAMPhotovoreRobot {
        port leftLightInput : LightPort;
        port rightLightInput : LightPort;

        part leftSide : RobotSide {
            attribute sideName = "left";
        }

        part rightSide : RobotSide {
            attribute sideName = "right";
        }

        part chassis : Chassis;

        connection leftLight : LightPort
            connect leftLightInput to leftSide.lightInput;

        connection rightLight : LightPort
            connect rightLightInput to rightSide.lightInput;

        state def PhotovoreBehavior {
            entry; then Resting;

            state Resting {
                doc /* Robot is still, passively collecting light energy in both capacitors. */
                transition Resting -> Lurching
                    when leftSide.capacitor.storedVoltage >= leftSide.capacitor.thresholdVoltage
                        or rightSide.capacitor.storedVoltage >= rightSide.capacitor.thresholdVoltage;
            }

            state Lurching {
                doc /* One or both motors fire as capacitors discharge, causing brief forward or turning motion. */
                transition Lurching -> Resting
                    when leftSide.capacitor.storedCharge == 0.0 [C]
                        and rightSide.capacitor.storedCharge == 0.0 [C];
            }
        }

        state photovoreBehavior : PhotovoreBehavior;

        action def SeekLight {
            doc /* The robot continuously orients toward the brightest light source by virtue of differential charging rates on left and right sides. */
            in leftIlluminance : Illuminance;
            in rightIlluminance : Illuminance;
            out headingChange : Real;
        }

        action seekLight : SeekLight {
            in leftIlluminance = leftLightInput.illuminance;
            in rightIlluminance = rightLightInput.illuminance;
        }
    }

    requirement def PhotovoreBehaviorReq {
        doc /* The robot shall exhibit photovore behavior by moving toward the brightest light source. */
        subject robot : BEAMPhotovoreRobot;
        attribute maxResponseTime : Duration = 30.0 [s];
        objective {
            The robot turns toward and moves toward the brightest light source in its environment.
        }
    }

    requirement def EnergyHarvestingReq {
        doc /* The robot shall harvest light energy using solar cells and store it in capacitors. */
        subject robot : BEAMPhotovoreRobot;
        attribute minSolarCellArea : Real = 0.0005 [m**2];
        objective {
            Each side solar cell converts incident light into electrical energy stored in its respective capacitor.
        }
    }

    requirement def ChargeDischargeCycleReq {
        doc /* The robot shall operate in a charge-discharge cycle, collecting energy until a threshold is reached, then discharging through motors. */
        subject robot : BEAMPhotovoreRobot;
        attribute thresholdVoltage : Voltage = 2.4 [V];
        attribute capacitorValue : Capacitance = 0.047 [F];
        objective {
            Each capacitor accumulates charge until reaching thresholdVoltage, then discharges completely through its associated motor in a single pulse.
        }
    }

    requirement def AnalogOnlyReq {
        doc /* The robot shall operate entirely on analog electronics without any digital processor or programming. */
        subject robot : BEAMPhotovoreRobot;
        objective {
            All sensing, trigger, and motor drive functions are implemented using analog circuitry including voltage comparators, transistors, resistors, and capacitors.
        }
    }

    requirement def DifferentialSteeringReq {
        doc /* The robot shall steer toward light by having independent left and right light sensing and motor drive. */
        subject robot : BEAMPhotovoreRobot;
        objective {
            The side receiving more light charges its capacitor faster and fires its motor sooner, causing the robot to turn toward the brighter light source and maximize energy collection.
        }
    }

    requirement def AutonomousOperationReq {
        doc /* The robot shall operate autonomously without external control or power once initialized. */
        subject robot : BEAMPhotovoreRobot;
        objective {
            The robot operates using only onboard solar energy harvesting and analog control circuitry with no external power or control signals required.
        }
    }

    requirement def JerkyMovementReq {
        doc /* The robot shall exhibit characteristic jerky, step-by-step movement due to the charge-and-discharge cycle. */
        subject robot : BEAMPhotovoreRobot;
        attribute maxLurchDuration : Duration = 0.5 [s];
        attribute minRechargeDuration : Duration = 2.0 [s];
        objective {
            The robot moves in brief lurches separated by still recharging periods, producing a discontinuous but purposeful trajectory toward light.
        }
    }

    requirement def BilateralSymmetryReq {
        doc /* The robot shall have symmetric left and right sides, each with its own light sensor, solar cell, capacitor, trigger, motor, and wheel. */
        subject robot : BEAMPhotovoreRobot;
        objective {
            Left and right sides are functionally independent and mirror each other, enabling differential photovore steering.
        }
    }

    requirement photovoreBehaviorRequirement : PhotovoreBehaviorReq {
        subject robot = BEAMPhotovoreRobot;
    }

    requirement energyHarvestingRequirement : EnergyHarvestingReq {
        subject robot = BEAMPhotovoreRobot;
    }

    requirement chargeDischargeCycleRequirement : ChargeDischargeCycleReq {
        subject robot = BEAMPhotovoreRobot;
    }

    requirement analogOnlyRequirement : AnalogOnlyReq {
        subject robot = BEAMPhotovoreRobot;
    }

    requirement differentialSteeringRequirement : DifferentialSteeringReq {
        subject robot = BEAMPhotovoreRobot;
    }

    requirement autonomousOperationRequirement : AutonomousOperationReq {
        subject robot = BEAMPhotovoreRobot;
    }

    requirement jerkyMovementRequirement : JerkyMovementReq {
        subject robot = BEAMPhotovoreRobot;
    }

    requirement bilateralSymmetryRequirement : BilateralSymmetryReq {
        subject robot = BEAMPhotovoreRobot;
    }
}
