package AutomatedFluidTransferSystem {

    package ValueTypes {
        value type Volume :> Real { unit 'm^3'; }
        value type Level :> Real { unit '%'; }
        value type FlowRate :> Real { unit 'm^3/s'; }
        value type Pressure :> Real { unit 'Pa'; }
        value type Power :> Real { unit 'W'; }
        value type Length :> Real { unit 'm'; }
        value type Diameter :> Real { unit 'm'; }
        value type ValvePosition :> Real { unit '%'; }
        value type MotorSpeed :> Real { unit 'rpm'; }
        value type Temperature :> Real { unit 'K'; }
        value type Duration :> Real { unit 's'; }
        value type Density :> Real { unit 'kg/m^3'; }
        value type Viscosity :> Real { unit 'Pa.s'; }
        value type Frequency :> Real { unit 'Hz'; }
        value type Voltage :> Real { unit 'V'; }
    }

    package Items {
        import ValueTypes::*;

        item def Liquid {
            attribute density : Density = 1000;
            attribute viscosity : Viscosity = 0.001;
            attribute temperature : Temperature = 293.15;
        }

        item def ElectricalPower {
            attribute voltage : Voltage = 400;
            attribute frequency : Frequency = 50;
        }

        item def ControlCommand {
            attribute commandType : String;
            attribute targetValue : Real;
            attribute timestamp : Duration;
        }

        item def SensorReading {
            attribute sensorType : String;
            attribute measuredValue : Real;
            attribute unit : String;
            attribute timestamp : Duration;
            attribute status : String = "OK";
        }
    }

    package Ports {
        import Items::*;

        port def FluidPort {
            attribute pressure : Pressure;
            attribute flowRate : FlowRate;
            inout item liquid : Liquid;
        }

        port def ElectricalPort {
            attribute power : Power;
            in item supply : ElectricalPower;
        }

        port def CommandOut {
            out item command : ControlCommand;
        }

        port def CommandIn {
            in item command : ControlCommand;
        }

        port def ReadingOut {
            out item reading : SensorReading;
        }

        port def ReadingIn {
            in item reading : SensorReading;
        }
    }

    package Interfaces {
        import Ports::*;
        import Items::*;

        interface def FluidConnection {
            end supplier : FluidPort;
            end consumer : FluidPort;
            attribute pressure : Pressure;
            attribute flowRate : FlowRate;
            flow liquid : Liquid from supplier to consumer;
        }

        interface def CommandConnection {
            end sender : CommandOut;
            end receiver : CommandIn;
            flow command : ControlCommand from sender to receiver;
        }

        interface def SensorConnection {
            end sensor : ReadingOut;
            end controller : ReadingIn;
            flow reading : SensorReading from sensor to controller;
        }

        interface def PowerConnection {
            end source : ElectricalPort;
            end load : ElectricalPort;
            flow supply : ElectricalPower from source to load;
        }
    }

    package Components {
        import ValueTypes::*;
        import Items::*;
        import Ports::*;
        import Interfaces::*;

        part def Tank {
            port fluidPort : FluidPort;
            attribute capacity : Volume;
            attribute currentVolume : Volume;
            attribute levelPercent : Level = (currentVolume / capacity) * 100;
            attribute lowLevelThreshold : Level = 10;
            attribute highLevelThreshold : Level = 90;
            attribute isLowLevel : Boolean = levelPercent < lowLevelThreshold;
            attribute isHighLevel : Boolean = levelPercent > highLevelThreshold;

            action def UpdateLevel {
                in deltaVolume : Volume;
                in current : Volume;
                in cap : Volume;
                out newVolume : Volume;
                out newLevel : Level;
            }
        }

        part def SourceTank :> Tank {
            attribute capacity : Volume = 5.0;
            attribute currentVolume : Volume = 4.0;
        }

        part def DestinationTank :> Tank {
            attribute capacity : Volume = 5.0;
            attribute currentVolume : Volume = 1.0;
        }

        part def Impeller {
            attribute diameter : Diameter = 0.15;
            attribute bladeCount : Integer = 7;
            attribute speed : MotorSpeed = 0;
            attribute maxSpeed : MotorSpeed = 2900;

            action def Rotate {
                in rotationalSpeed : MotorSpeed;
                in inletPressure : Pressure;
                out dischargePressure : Pressure;
                out generatedFlow : FlowRate;
            }
        }

        part def ElectricMotor {
            port electricalIn : ElectricalPort;
            attribute ratedPower : Power = 7500;
            attribute currentSpeed : MotorSpeed = 0;
            attribute maxSpeed : MotorSpeed = 2900;
            attribute efficiency : Real = 0.92;
            attribute isRunning : Boolean = false;

            action def Start {
                in targetSpeed : MotorSpeed;
                out actualSpeed : MotorSpeed;
            }

            action def Stop {
                out actualSpeed : MotorSpeed = 0;
            }

            action def Drive {
                in supply : ElectricalPower;
                in targetSpeed : MotorSpeed;
                out outputSpeed : MotorSpeed;
                out powerConsumed : Power;
            }
        }

        part def Pump {
            port inlet : FluidPort;
            port discharge : FluidPort;
            port electricalInput : ElectricalPort;
            port commandInput : CommandIn;

            part motor : ElectricMotor {
                attribute ratedPower : Power = 7500;
            }
            part impeller : Impeller;

            attribute ratedPower : Power = 7500;
            attribute currentSpeed : MotorSpeed = 0;
            attribute dischargePressure : Pressure = 0;
            attribute flowRate : FlowRate = 0;
            attribute isRunning : Boolean = false;
            attribute targetSpeed : MotorSpeed = 0;

            action def PumpLiquid {
                in liquid : Liquid;
                in speed : MotorSpeed;
                out pressurizedLiquid : Liquid;
                out dischargePressure : Pressure;
                out flowRate : FlowRate;
            }

            action def Start {
                in commandSpeed : MotorSpeed;
                out actualSpeed : MotorSpeed;
            }

            action def Stop {
                out actualSpeed : MotorSpeed = 0;
            }

            action def AdjustSpeed {
                in targetSpeed : MotorSpeed;
                out actualSpeed : MotorSpeed;
            }
        }

        part def Valve {
            port inlet : FluidPort;
            port outlet : FluidPort;
            port commandInput : CommandIn;
            attribute position : ValvePosition = 100;
            attribute isOpen : Boolean = true;
            attribute flowCoefficient : Real = 0.8;

            action def AdjustPosition {
                in targetPosition : ValvePosition;
                out actualPosition : ValvePosition;
            }

            action def Open {
                out position : ValvePosition = 100;
            }

            action def Close {
                out position : ValvePosition = 0;
            }
        }

        part def InletValve :> Valve {
            attribute position : ValvePosition = 100;
        }

        part def DischargeValve :> Valve {
            attribute position : ValvePosition = 50;
        }

        part def CheckValve :> Valve {
            attribute position : ValvePosition = 100;
            attribute allowsBackflow : Boolean = false;
            attribute crackingPressure : Pressure = 5000;

            action def PreventBackflow {
                in forwardPressure : Pressure;
                in reversePressure : Pressure;
                out position : ValvePosition;
                out isOpen : Boolean;
            }
        }

        part def Pipeline {
            port inlet : FluidPort;
            port outlet : FluidPort;
            attribute length : Length = 10.0;
            attribute diameter : Diameter = 0.05;
            attribute material : String = "Stainless Steel 316L";
            attribute roughness : Real = 0.000045;
        }

        part def Sensor {
            port output : ReadingOut;
            attribute samplingRate : Frequency = 10;
            attribute isCalibrated : Boolean = true;
            attribute isOnline : Boolean = true;

            action def Measure {
                out reading : SensorReading;
            }

            action def Calibrate {
                out isCalibrated : Boolean = true;
            }
        }

        part def LevelSensor :> Sensor {
            attribute measuredLevel : Level = 0;
            attribute lowThreshold : Level = 10;
            attribute highThreshold : Level = 90;

            action def MeasureLevel {
                in tankLevel : Level;
                out reading : SensorReading;
            }
        }

        part def FlowMeter :> Sensor {
            attribute measuredFlowRate : FlowRate = 0;
            attribute accuracy : Real = 0.01;

            action def MeasureFlow {
                in flowRate : FlowRate;
                out reading : SensorReading;
            }
        }

        part def PressureSensor :> Sensor {
            attribute measuredPressure : Pressure = 0;
            attribute range : Pressure = 1000000;
            attribute accuracy : Real = 0.005;

            action def MeasurePressure {
                in pressure : Pressure;
                out reading : SensorReading;
            }
        }

        part def PowerSupply {
            port output : ElectricalPort;
            attribute ratedPower : Power = 10000;
            attribute outputVoltage : Voltage = 400;
            attribute outputFrequency : Frequency = 50;
            attribute isOnline : Boolean = true;
        }

        part def Controller {
            port pumpCommandOut : CommandOut;
            port valveCommandOut : CommandOut;
            port sourceLevelIn : ReadingIn;
            port destLevelIn : ReadingIn;
            port flowRateIn : ReadingIn;
            port pressureIn : ReadingIn;

            attribute targetFlowRate : FlowRate = 0.01;
            attribute targetPressure : Pressure = 200000;
            attribute sourceLowThreshold : Level = 10;
            attribute destinationHighThreshold : Level = 90;
            attribute isRunning : Boolean = false;
            attribute emergencyShutdown : Boolean = false;

            attribute sourceLevel : Level = 80;
            attribute destinationLevel : Level = 20;
            attribute measuredFlowRate : FlowRate = 0;
            attribute measuredPressure : Pressure = 0;

            attribute initializationComplete : Boolean = false;
            attribute startCommandReceived : Boolean = false;
            attribute pumpAtOperatingSpeed : Boolean = false;
            attribute sourceLevelBelow10 : Boolean = false;
            attribute destinationLevelAbove90 : Boolean = false;
            attribute pumpStopped : Boolean = false;
            attribute resetCommandReceived : Boolean = false;

            action def MonitorSensors {
                in sourceLevelReading : SensorReading;
                in destLevelReading : SensorReading;
                in flowReading : SensorReading;
                in pressureReading : SensorReading;
                out sourceLevel : Level;
                out destinationLevel : Level;
                out flowRate : FlowRate;
                out pressure : Pressure;
            }

            action def RegulateFlow {
                in targetFlow : FlowRate;
                in targetPress : Pressure;
                in measuredFlow : FlowRate;
                in measuredPress : Pressure;
                out pumpSpeedCommand : MotorSpeed;
                out valvePositionCommand : ValvePosition;
            }

            action def SafetyCheck {
                in sourceLvl : Level;
                in destLvl : Level;
                in srcLowThreshold : Level;
                in destHighThreshold : Level;
                out shutdown : Boolean;
            }

            action def EmergencyShutdownAction {
                out pumpStopCommand : ControlCommand;
                out valveCloseCommand : ControlCommand;
            }

            exhibit state def ControlBehavior {
                entry; then Initializing;

                state Initializing {
                    entry action {
                        /* Initialize all subsystems and verify sensor calibration */
                    }
                    do action {
                        initializationComplete = true;
                    }
                }

                state Idle {
                    entry action {
                        isRunning = false;
                    }
                    do action {
                        /* Wait for operator start command */
                    }
                }

                state Starting {
                    entry action {
                        /* Send start command to pump motor */
                    }
                    do action {
                        /* Ramp up pump to operating speed */
                        pumpAtOperatingSpeed = true;
                    }
                }

                state Running {
                    entry action {
                        isRunning = true;
                    }
                    do action {
                        /* Continuously monitor sensors and regulate flow and pressure */
                        sourceLevelBelow10 = sourceLevel < sourceLowThreshold;
                        destinationLevelAbove90 = destinationLevel > destinationHighThreshold;
                    }
                }

                state SafetyShutdown {
                    entry action {
                        emergencyShutdown = true;
                    }
                    do action {
                        /* Execute emergency shutdown: stop pump and close discharge valve */
                        pumpStopped = true;
                    }
                }

                state Stopped {
                    entry action {
                        isRunning = false;
                        emergencyShutdown = false;
                    }
                    do action {
                        /* System stopped, awaiting manual reset */
                    }
                }

                transition from Initializing to Idle
                    when initializationComplete;

                transition from Idle to Starting
                    when startCommandReceived;

                transition from Starting to Running
                    when pumpAtOperatingSpeed;

                transition from Running to SafetyShutdown
                    when sourceLevelBelow10 || destinationLevelAbove90;

                transition from SafetyShutdown to Stopped
                    when pumpStopped;

                transition from Stopped to Idle
                    when resetCommandReceived;
            }
        }
    }

    package Requirements {
        import ValueTypes::*;

        requirement def TransferRequirement {
            doc /* Requirement for transferring liquid between reservoirs. */
        }

        requirement def FlowControlRequirement {
            doc /* Requirement for maintaining target flow rate and pressure. */
            attribute targetFlowRate : FlowRate = 0.01;
            attribute targetPressure : Pressure = 200000;
        }

        requirement def SafetyRequirement {
            doc /* Requirement for safety shutdown logic. */
            attribute sourceLowThreshold : Level = 10;
            attribute destinationHighThreshold : Level = 90;
        }

        requirement def MotorPowerRequirement {
            doc /* Requirement for motor power rating. */
            attribute ratedPower : Power = 7500;
        }

        requirement def ContinuousOperationRequirement {
            doc /* Requirement for continuous controlled operation. */
        }

        requirement def BackflowPreventionRequirement {
            doc /* Requirement for preventing backflow. */
        }

        requirement TransferLiquid :> TransferRequirement {
            subject system;
            doc /* The system shall pump liquid from the source reservoir to the destination reservoir via the main pipeline. */
        }

        requirement MaintainFlowAndPressure :> FlowControlRequirement {
            subject controller;
            doc /* The controller shall maintain the target flow rate and pressure by sending commands to the pump and adjusting the discharge valve position. */
        }

        requirement PreventDryRun :> SafetyRequirement {
            subject controller;
            doc /* The controller shall automatically shut down the pump if the source tank level falls below 10 percent to prevent the pump from running dry. */
        }

        requirement PreventOverflow :> SafetyRequirement {
            subject controller;
            doc /* The controller shall automatically shut down the pump if the destination tank level exceeds 90 percent to prevent overflow. */
        }

        requirement MotorPowerSpec :> MotorPowerRequirement {
            subject motor;
            doc /* The electric motor driving the pump shall have a rated power of 7.5 kW. */
        }

        requirement PreventBackflow :> BackflowPreventionRequirement {
            subject checkValve;
            doc /* A check valve shall be installed on the discharge line to prevent any backflow of liquid. */
        }

        requirement SupportContinuousOperation :> ContinuousOperationRequirement {
            subject system;
            doc /* The system shall support continuous, controlled, unattended operation with built-in safety mechanisms. */
        }
    }

    package SystemAssembly {
        import Components::*;
        import Interfaces::*;
        import Requirements::*;

        part FluidTransferSystem {
            part sourceTank : SourceTank;
            part destinationTank : DestinationTank;
            part inletValve : InletValve;
            part pump : Pump;
            part dischargeValve : DischargeValve;
            part checkValve : CheckValve;
            part mainPipeline : Pipeline;
            part dischargePipe : Pipeline;
            part controller : Controller;
            part sourceLevelSensor : LevelSensor;
            part destinationLevelSensor : LevelSensor;
            part flowMeter : FlowMeter;
            part pressureSensor : PressureSensor;
            part powerSupply : PowerSupply;

            connection sourceToInlet : FluidConnection
                connect sourceTank.fluidPort to inletValve.inlet;

            connection inletToPump : FluidConnection
                connect inletValve.outlet to pump.inlet;

            connection pumpToDischargePipe : FluidConnection
                connect pump.discharge to dischargePipe.inlet;

            connection dischargePipeToValve : FluidConnection
                connect dischargePipe.outlet to dischargeValve.inlet;

            connection dischargeToCheckValve : FluidConnection
                connect dischargeValve.outlet to checkValve.inlet;

            connection checkValveToPipeline : FluidConnection
                connect checkValve.outlet to mainPipeline.inlet;

            connection pipelineToDestination : FluidConnection
                connect mainPipeline.outlet to destinationTank.fluidPort;

            connection powerToPump : PowerConnection
                connect powerSupply.output to pump.electricalInput;

            connection pumpControlLink : CommandConnection
                connect controller.pumpCommandOut to pump.commandInput;

            connection valveControlLink : CommandConnection
                connect controller.valveCommandOut to dischargeValve.commandInput;

            connection sourceLevelLink : SensorConnection
                connect sourceLevelSensor.output to controller.sourceLevelIn;

            connection destLevelLink : SensorConnection
                connect destinationLevelSensor.output to controller.destLevelIn;

            connection flowMeterLink : SensorConnection
                connect flowMeter.output to controller.flowRateIn;

            connection pressureSensorLink : SensorConnection
                connect pressureSensor.output to controller.pressureIn;
        }

        satisfy TransferLiquid by FluidTransferSystem;
        satisfy MaintainFlowAndPressure by FluidTransferSystem.controller;
        satisfy PreventDryRun by FluidTransferSystem.controller;
        satisfy PreventOverflow by FluidTransferSystem.controller;
        satisfy MotorPowerSpec by FluidTransferSystem.pump.motor;
        satisfy PreventBackflow by FluidTransferSystem.checkValve;
        satisfy SupportContinuousOperation by FluidTransferSystem;
    }
}
