package ChemicalReactorAutomation {
    import ScalarValues::*;

    package Units {
        unit def Celsius;
        unit def Bar;
        unit def Percent;
        unit def LitersPerMinute;
        unit def Kilowatt;
        unit def RPM;
    }

    package ValueTypes {
        import Units::*;
        value def TemperatureValue :> Real { doc "Temperature measured in degrees Celsius."; }
        value def PressureValue :> Real { doc "Pressure measured in bar."; }
        value def LevelValue :> Real { doc "Fill level measured in percent."; }
        value def FlowValue :> Real { doc "Volumetric flow rate measured in liters per minute."; }
        value def PowerValue :> Real { doc "Electrical power measured in kilowatts."; }
        value def SpeedValue :> Real { doc "Rotational speed measured in revolutions per minute."; }
        value def PositionValue :> Real { doc "Valve position measured in percent open."; }
        value def SetpointValue :> Real { doc "Desired process value for a control loop."; }
        value def ErrorValue :> Real { doc "Difference between setpoint and measured value."; }
        value def GainValue :> Real { doc "PID controller gain coefficient."; }
    }

    package Items {
        import ValueTypes::*;
        item def TemperatureReading { value temp : TemperatureValue; }
        item def PressureReading { value pres : PressureValue; }
        item def LevelReading { value lvl : LevelValue; }
        item def FlowReading { value flow : FlowValue; }
        item def HeaterCommand { value power : PowerValue; }
        item def ValveCommand { value position : PositionValue; }
        item def DriveCommand { value speed : SpeedValue; }
        item def AlarmSignal { attribute severity : Integer; attribute message : String; }
        item def SetpointUpdate { value sp : SetpointValue; }
        item def ModeCommand { attribute mode : String; }
    }

    package Ports {
        import Items::*;

        port def TempReadingPort { out reading : TemperatureReading; }
        port def PressureReadingPort { out reading : PressureReading; }
        port def LevelReadingPort { out reading : LevelReading; }
        port def FlowReadingPort { out reading : FlowReading; }

        port def HeaterCmdPort { out cmd : HeaterCommand; }
        port def ValveCmdPort { out cmd : ValveCommand; }
        port def DriveCmdPort { out cmd : DriveCommand; }

        port def AlarmPort { out alarm : AlarmSignal; }
        port def ModePort { out mode : ModeCommand; }
        port def SetpointPort { out sp : SetpointUpdate; }

        port def PowerOutputPort { out power : PowerValue; }
        port def FlowOutputPort { out rate : FlowValue; }
        port def SpeedOutputPort { out speed : SpeedValue; }
    }

    package Sensors {
        import ValueTypes::*;
        import Items::*;
        import Ports::*;

        part def TemperatureSensor {
            attribute currentValue : TemperatureValue;
            attribute calibrationOffset : TemperatureValue;
            port readingPort : TempReadingPort;
            action sense {
                in physicalTemp : TemperatureValue;
                out reading : TemperatureReading;
            }
        }

        part def PressureSensor {
            attribute currentValue : PressureValue;
            attribute calibrationOffset : PressureValue;
            port readingPort : PressureReadingPort;
            action sense {
                in physicalPres : PressureValue;
                out reading : PressureReading;
            }
        }

        part def LevelSensor {
            attribute currentValue : LevelValue;
            attribute calibrationOffset : LevelValue;
            port readingPort : LevelReadingPort;
            action sense {
                in physicalLevel : LevelValue;
                out reading : LevelReading;
            }
        }

        part def FlowMeter {
            attribute currentValue : FlowValue;
            attribute calibrationFactor : Real;
            port readingPort : FlowReadingPort;
            action sense {
                in physicalFlow : FlowValue;
                out reading : FlowReading;
            }
        }
    }

    package Actuators {
        import ValueTypes::*;
        import Items::*;
        import Ports::*;

        part def HeatingElement {
            attribute powerOutput : PowerValue;
            attribute maxPower : PowerValue;
            port cmdPort : ~HeaterCmdPort;
            port powerPort : PowerOutputPort;
            action applyPower {
                in cmd : HeaterCommand;
                out appliedPower : PowerValue;
            }
        }

        part def ControlValve {
            attribute currentPosition : PositionValue;
            attribute failSafePosition : PositionValue;
            port cmdPort : ~ValveCmdPort;
            port flowPort : FlowOutputPort;
            action setPosition {
                in cmd : ValveCommand;
                out position : PositionValue;
            }
        }

        part def VariableSpeedDrive {
            attribute currentSpeed : SpeedValue;
            attribute maxSpeed : SpeedValue;
            attribute minSpeed : SpeedValue;
            port cmdPort : ~DriveCmdPort;
            port speedPort : SpeedOutputPort;
            action setSpeed {
                in cmd : DriveCommand;
                out speed : SpeedValue;
            }
        }

        part def Agitator {
            attribute rotationSpeed : SpeedValue;
            attribute bladeCount : Integer;
            port speedIn : ~SpeedOutputPort;
            port agitationOut : SpeedOutputPort;
            action agitate {
                in driveSpeed : SpeedValue;
                out agitationSpeed : SpeedValue;
            }
        }
    }

    package Reactor {
        import ValueTypes::*;
        import Items::*;
        import Ports::*;

        part def ProcessReactor {
            attribute internalTemp : TemperatureValue;
            attribute internalPressure : PressureValue;
            attribute fillLevel : LevelValue;
            attribute inflowRate : FlowValue;
            attribute outflowRate : FlowValue;
            attribute volume : Real;
            attribute designPressure : PressureValue;
            attribute designTemperature : TemperatureValue;

            port heatPort : ~PowerOutputPort;
            port inflowPort : ~FlowOutputPort;
            port outflowPort : ~FlowOutputPort;
            port agitationPort : ~SpeedOutputPort;

            action react {
                in heat : PowerValue;
                in inflow : FlowValue;
                in outflow : FlowValue;
                in agitation : SpeedValue;
                out temp : TemperatureValue;
                out pres : PressureValue;
                out lvl : LevelValue;
            }

            action def EmergencyVent {
                in trigger : Boolean;
                out ventedPressure : PressureValue;
            }
        }
    }

    package Controllers {
        import ValueTypes::*;
        import Items::*;
        import Ports::*;

        part def PIDController {
            attribute setpoint : SetpointValue;
            attribute kp : GainValue;
            attribute ki : GainValue;
            attribute kd : GainValue;
            attribute integralTerm : Real;
            attribute previousError : ErrorValue;
            attribute outputMin : Real;
            attribute outputMax : Real;
            attribute enabled : Boolean;

            port setpointPort : ~SetpointPort;

            action computePID {
                in measured : Real;
                in sp : SetpointValue;
                in kp : GainValue;
                in ki : GainValue;
                in kd : GainValue;
                out command : Real;
            }

            action def Initialize {
                in initialSetpoint : SetpointValue;
                out status : Boolean;
            }
        }

        part def TemperatureController :> PIDController {
            port feedbackPort : ~TempReadingPort;
            port commandPort : HeaterCmdPort;
        }

        part def PressureController :> PIDController {
            port feedbackPort : ~PressureReadingPort;
            port commandPort : SetpointPort;
        }

        part def LevelController :> PIDController {
            port feedbackPort : ~LevelReadingPort;
            port commandPort : SetpointPort;
        }

        part def FlowController :> PIDController {
            port feedbackPort : ~FlowReadingPort;
            port commandPort : ValveCmdPort;
        }

        part def SupervisoryController {
            attribute operatingMode : String;
            attribute alarmActive : Boolean;
            attribute emergencyShutdown : Boolean;

            attribute tempHighLimit : TemperatureValue;
            attribute tempLowLimit : TemperatureValue;
            attribute pressureHighLimit : PressureValue;
            attribute pressureCriticalLimit : PressureValue;
            attribute levelHighLimit : LevelValue;
            attribute levelLowLimit : LevelValue;
            attribute flowHighLimit : FlowValue;
            attribute flowLowLimit : FlowValue;

            port alarmPort : AlarmPort;
            port modePort : ~ModePort;
            port tempSetpointPort : SetpointPort;
            port pressureSetpointPort : SetpointPort;
            port levelSetpointPort : SetpointPort;
            port driveCommandPort : DriveCmdPort;

            action optimizeSetpoints {
                in processTemp : TemperatureValue;
                in processPres : PressureValue;
                in processLvl : LevelValue;
                in inflowRate : FlowValue;
                in outflowRate : FlowValue;
                out tempSP : SetpointUpdate;
                out presSP : SetpointUpdate;
                out lvlSP : SetpointUpdate;
                out driveCmd : DriveCommand;
            }

            action checkAlarms {
                in temp : TemperatureReading;
                in pres : PressureReading;
                in lvl : LevelReading;
                in inflow : FlowReading;
                in outflow : FlowReading;
                out alarm : AlarmSignal;
            }

            action def CoordinateLoops {
                in tempError : ErrorValue;
                in presError : ErrorValue;
                in lvlError : ErrorValue;
                out coordinationAction : String;
            }
        }
    }

    package DCS {
        import Controllers::*;
        import Items::*;
        import Ports::*;

        part def DistributedControlSystem {
            part tempController : TemperatureController;
            part pressureController : PressureController;
            part levelController : LevelController;
            part inflowController : FlowController;
            part outflowController : FlowController;
            part supervisory : SupervisoryController;

            port tempInput : ~TempReadingPort;
            port pressureInput : ~PressureReadingPort;
            port levelInput : ~LevelReadingPort;
            port inflowInput : ~FlowReadingPort;
            port outflowInput : ~FlowReadingPort;

            port heatOutput : HeaterCmdPort;
            port inflowOutput : ValveCmdPort;
            port outflowOutput : ValveCmdPort;
            port driveOutput : DriveCmdPort;

            port alarmOutput : AlarmPort;
            port modeInput : ~ModePort;

            connection connect tempInput to tempController.feedbackPort;
            connection connect pressureInput to pressureController.feedbackPort;
            connection connect levelInput to levelController.feedbackPort;
            connection connect inflowInput to inflowController.feedbackPort;
            connection connect outflowInput to outflowController.feedbackPort;

            connection connect supervisory.tempSetpointPort to tempController.setpointPort;
            connection connect supervisory.levelSetpointPort to levelController.setpointPort;
            connection connect supervisory.pressureSetpointPort to pressureController.setpointPort;

            connection connect levelController.commandPort to inflowController.setpointPort;
            connection connect pressureController.commandPort to outflowController.setpointPort;

            connection connect tempController.commandPort to heatOutput;
            connection connect inflowController.commandPort to inflowOutput;
            connection connect outflowController.commandPort to outflowOutput;
            connection connect supervisory.driveCommandPort to driveOutput;

            connection connect supervisory.alarmPort to alarmOutput;
        }
    }

    package Behaviors {
        import Items::*;

        state def ControlSystemStates {
            transition initial then Automatic;

            state Automatic {
                doc "Fully automatic operation with all PID control loops active and supervisory optimization enabled.";
            }

            state Manual {
                doc "Operator intervention mode allowing direct actuator control with PID loops in standby.";
            }

            state Maintenance {
                doc "Maintenance mode with all control loops disabled and actuators placed in safe positions.";
            }

            state EmergencyShutdown {
                doc "Emergency state triggered by critical alarm conditions. All actuators move to fail-safe positions.";
            }

            transition automatic_to_manual
                first Automatic
                accept mc : ModeCommand
                if mc.mode == "Manual"
                then Manual;

            transition manual_to_automatic
                first Manual
                accept mc : ModeCommand
                if mc.mode == "Automatic"
                then Automatic;

            transition automatic_to_maintenance
                first Automatic
                accept mc : ModeCommand
                if mc.mode == "Maintenance"
                then Maintenance;

            transition manual_to_maintenance
                first Manual
                accept mc : ModeCommand
                if mc.mode == "Maintenance"
                then Maintenance;

            transition maintenance_to_automatic
                first Maintenance
                accept mc : ModeCommand
                if mc.mode == "Automatic"
                then Automatic;

            transition maintenance_to_manual
                first Maintenance
                accept mc : ModeCommand
                if mc.mode == "Manual"
                then Manual;

            transition automatic_to_emergency
                first Automatic
                accept a : AlarmSignal
                if a.severity >= 3
                then EmergencyShutdown;

            transition manual_to_emergency
                first Manual
                accept a : AlarmSignal
                if a.severity >= 3
                then EmergencyShutdown;

            transition emergency_to_maintenance
                first EmergencyShutdown
                accept mc : ModeCommand
                if mc.mode == "Maintenance"
                then Maintenance;
        }
    }

    package Requirements {
        import ValueTypes::*;

        requirement def ProcessControlRequirement {
            doc "The system shall maintain process variables within specified setpoints using closed-loop PID control.";
        }

        requirement def TemperatureControlRequirement :> ProcessControlRequirement {
            doc "The system shall maintain reactor temperature within plus or minus 2 degrees Celsius of the setpoint of 85 degrees Celsius.";
            attribute setpoint : TemperatureValue = 85;
            attribute tolerance : TemperatureValue = 2;
            subject reactorTemp : TemperatureValue;
            predicate { reactorTemp >= setpoint - tolerance and reactorTemp <= setpoint + tolerance }
        }

        requirement def PressureControlRequirement :> ProcessControlRequirement {
            doc "The system shall maintain reactor pressure below the maximum operating pressure of 10 bar.";
            attribute maxPressure : PressureValue = 10;
            subject reactorPres : PressureValue;
            predicate { reactorPres <= maxPressure }
        }

        requirement def LevelControlRequirement :> ProcessControlRequirement {
            doc "The system shall maintain reactor fill level between 20 percent and 90 percent.";
            attribute minLevel : LevelValue = 20;
            attribute maxLevel : LevelValue = 90;
            subject reactorLvl : LevelValue;
            predicate { reactorLvl >= minLevel and reactorLvl <= maxLevel }
        }

        requirement def FlowControlRequirement :> ProcessControlRequirement {
            doc "The system shall regulate inflow and outflow rates to maintain stable operation near the nominal flow of 50 liters per minute.";
            attribute nominalFlow : FlowValue = 50;
            subject flowRate : FlowValue;
            predicate { flowRate >= nominalFlow * 0.8 and flowRate <= nominalFlow * 1.2 }
        }

        requirement def AlarmRequirement {
            doc "The system shall generate an alarm when any sensor reading exceeds safe operating limits.";
            subject outOfLimits : Boolean;
            subject alarmGenerated : Boolean;
            predicate { outOfLimits implies alarmGenerated }
        }

        requirement def ModeRequirement {
            doc "The system shall support Automatic, Manual, and Maintenance operating modes with defined transitions between them.";
            attribute supportedModes : String = "Automatic, Manual, Maintenance";
        }

        requirement def SafetyShutdownRequirement {
            doc "If reactor pressure exceeds 12 bar, the system shall initiate emergency shutdown and transition to the EmergencyShutdown state.";
            attribute criticalPressure : PressureValue = 12;
            subject reactorPres : PressureValue;
            subject shutdownInitiated : Boolean;
            predicate { reactorPres > criticalPressure implies shutdownInitiated }
        }

        requirement def AgitationRequirement {
            doc "The system shall maintain agitation speed within the range of 60 to 120 revolutions per minute during automatic operation.";
            attribute minSpeed : SpeedValue = 60;
            attribute maxSpeed : SpeedValue = 120;
            subject agitationSpeed : SpeedValue;
            predicate { agitationSpeed >= minSpeed and agitationSpeed <= maxSpeed }
        }

        requirement def SupervisoryOptimizationRequirement {
            doc "The supervisory controller shall continuously optimize setpoints for individual control loops to improve process efficiency.";
            subject optimizationActive : Boolean;
            predicate { optimizationActive == true }
        }

        requirement def CascadeControlRequirement {
            doc "The level controller shall provide cascade setpoint updates to the inflow flow controller, and the pressure controller shall provide cascade setpoint updates to the outflow flow controller.";
            subject cascadeActive : Boolean;
            predicate { cascadeActive == true }
        }

        requirement def SensorMonitoringRequirement {
            doc "The system shall continuously monitor temperature, pressure, level, and flow using dedicated sensors and provide readings to the distributed control system.";
            subject monitoringActive : Boolean;
            predicate { monitoringActive == true }
        }
    }

    package System {
        import Sensors::*;
        import Actuators::*;
        import Reactor::*;
        import DCS::*;
        import Behaviors::*;
        import Requirements::*;

        part def ChemicalReactorAutomationSystem {
            part reactor : ProcessReactor;
            part tempSensor : TemperatureSensor;
            part pressureSensor : PressureSensor;
            part levelSensor : LevelSensor;
            part inflowMeter : FlowMeter;
            part outflowMeter : FlowMeter;
            part heater : HeatingElement;
            part inflowValve : ControlValve;
            part outflowValve : ControlValve;
            part drive : VariableSpeedDrive;
            part agitator : Agitator;
            part dcs : DistributedControlSystem;

            connection connect tempSensor.readingPort to dcs.tempInput;
            connection connect pressureSensor.readingPort to dcs.pressureInput;
            connection connect levelSensor.readingPort to dcs.levelInput;
            connection connect inflowMeter.readingPort to dcs.inflowInput;
            connection connect outflowMeter.readingPort to dcs.outflowInput;

            connection connect dcs.heatOutput to heater.cmdPort;
            connection connect dcs.inflowOutput to inflowValve.cmdPort;
            connection connect dcs.outflowOutput to outflowValve.cmdPort;
            connection connect dcs.driveOutput to drive.cmdPort;

            connection connect heater.powerPort to reactor.heatPort;
            connection connect inflowValve.flowPort to reactor.inflowPort;
            connection connect outflowValve.flowPort to reactor.outflowPort;

            connection connect drive.speedPort to agitator.speedIn;
            connection connect agitator.agitationOut to reactor.agitationPort;

            state operatingState : ControlSystemStates;
        }
    }
}
