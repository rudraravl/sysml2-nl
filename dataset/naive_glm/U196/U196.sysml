package Cryolathe {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====
    def TemperatureValue :> Real { unit 'K'; }
    def PressureValue :> Real { unit 'Pa'; }
    def FlowRateValue :> Real { unit 'L/min'; }
    def RotationalSpeedValue :> Real { unit 'rpm'; }
    def LinearPositionValue :> Real { unit 'mm'; }
    def LinearVelocityValue :> Real { unit 'mm/s'; }
    def TorqueValue :> Real { unit 'N*m'; }
    def PowerValue :> Real { unit 'W'; }
    def MassValue :> Real { unit 'kg'; }
    def DurationValue :> Real { unit 's'; }
    def PercentageValue :> Real { unit '%'; }

    // ===== Item Types =====
    item def CryogenicFluid {
        attribute currentTemperature : TemperatureValue;
        attribute currentPressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }

    item def LiquidNitrogen :> CryogenicFluid;

    item def Workpiece {
        attribute material : String;
        attribute initialMass : MassValue;
        attribute currentMass : MassValue;
        attribute targetDiameter : LinearPositionValue;
        attribute currentDiameter : LinearPositionValue;
        attribute currentTemperature : TemperatureValue;
    }

    item def CuttingTool {
        attribute toolId : String;
        attribute toolType : String; // e.g., "roughing", "finishing"
        attribute stationIndex : Integer;
        attribute wearLevel : PercentageValue;
        attribute maxWear : PercentageValue = 100;
    }

    item def MachiningProgram {
        attribute programId : String;
        attribute toolSequence : String;
        attribute feedRate : LinearVelocityValue;
        attribute spindleSpeed : RotationalSpeedValue;
        attribute targetTemperature : TemperatureValue;
    }

    item def SensorReading {
        attribute temperature : TemperatureValue;
        attribute pressure : PressureValue;
        attribute timestamp : DurationValue;
    }

    item def ControlCommand {
        attribute commandType : String;
        attribute targetValue : Real;
        attribute timestamp : DurationValue;
    }

    item def SafetyAlert {
        attribute alertType : String;
        attribute severity : String;
        attribute timestamp : DurationValue;
    }

    // ===== Port Definitions =====
    port def CryogenFlowPort {
        out item cryogen : CryogenicFluid;
    }

    port def CryogenInPort {
        in item cryogen : CryogenicFluid;
    }

    port def SensorDataPort {
        out item reading : SensorReading;
    }

    port def CommandPort {
        in item command : ControlCommand;
    }

    port def StatusPort {
        out item status : SensorReading;
    }

    port def SafetySignalPort {
        out item alert : SafetyAlert;
    }

    port def MechanicalDrivePort {
        out attribute torque : TorqueValue;
        out attribute speed : RotationalSpeedValue;
    }

    port def MechanicalLoadPort {
        in attribute torque : TorqueValue;
        in attribute speed : RotationalSpeedValue;
    }

    port def LinearMotionPort {
        out attribute position : LinearPositionValue;
        out attribute velocity : LinearVelocityValue;
    }

    // ===== Requirements =====
    requirement def CryolathePerformanceRequirement {
        doc "The Cryolathe shall achieve superior dimensional accuracy and surface finish at cryogenic temperatures."
        requirement dimensionalAccuracy {
            subject CryolatheSystem;
            objective :>> CryolatheSystem shall achieve dimensional tolerance of less than 0.001 mm;
        }
        requirement surfaceFinish {
            subject CryolatheSystem;
            objective :>> CryolatheSystem shall achieve surface roughness of less than 0.05 micrometer;
        }
        requirement cryogenicOperation {
            subject CryolatheSystem;
            objective :>> CryolatheSystem shall operate at temperatures below 120 K;
        }
    }

    requirement def CryogenicDeliveryRequirement {
        doc "The cryogenic delivery system shall safely manage cryogenic fluid flow and pressure."
        requirement flowControl {
            subject CryogenicDeliverySystem;
            objective :>> CryogenicDeliverySystem shall regulate flow rate between 0 and 50 L/min;
        }
        requirement pressureSafety {
            subject CryogenicDeliverySystem;
            objective :>> CryogenicDeliverySystem shall maintain pressure below 500000 Pa;
        }
        requirement leakPrevention {
            subject CryogenicDeliverySystem;
            objective :>> CryogenicDeliverySystem shall prevent cryogenic fluid leakage;
        }
    }

    requirement def SafetyRequirement {
        doc "The safety system shall protect personnel and equipment during cryogenic machining."
        requirement emergencyStop {
            subject SafetySystem;
            objective :>> SafetySystem shall halt all motion within 0.5 s of emergency stop activation;
        }
        requirement doorInterlock {
            subject SafetySystem;
            objective :>> SafetySystem shall prevent spindle operation when chamber door is open;
        }
        requirement leakDetection {
            subject SafetySystem;
            objective :>> SafetySystem shall detect cryogenic leaks within 2 s;
        }
    }

    requirement def OperationalCycleRequirement {
        doc "The Cryolathe shall execute a complete operational cycle from loading to unloading."
        requirement precoolingPhase {
            subject CryolatheSystem;
            objective :>> CryolatheSystem shall cool chamber to target temperature before machining;
        }
        requirement machiningPhase {
            subject CryolatheSystem;
            objective :>> CryolatheSystem shall perform cutting operations while maintaining thermal stability;
        }
        requirement warmupPhase {
            subject CryolatheSystem;
            objective :>> CryolatheSystem shall warm workpiece to safe handling temperature before unloading;
        }
    }

    // ===== Part Definitions =====

    part def CryolatheSystem {
        doc "An advanced ultra-precision manufacturing system for cryogenic machining.";

        attribute systemId : String;
        attribute targetCryoTemperature : TemperatureValue = 80[K];
        attribute safeHandlingTemperature : TemperatureValue = 250[K];
        attribute maxSpindleSpeed : RotationalSpeedValue = 10000[rpm];

        port cryogenSupply : CryogenFlowPort;
        port systemStatus : StatusPort;
        port safetyOutput : SafetySignalPort;

        part cryogenicChamber : CryogenicChamber {
            port chamberCryogenIn : CryogenInPort;
            port spindleCryogenOut : CryogenFlowPort;
            port toolCryogenOut : CryogenFlowPort;
            port chamberSensorData : SensorDataPort;
        }

        part cryogenicDeliverySystem : CryogenicDeliverySystem {
            port reservoirOut : CryogenFlowPort;
            port deliveryCommand : CommandPort;
            port deliveryStatus : StatusPort;
        }

        part spindleAssembly : SpindleAssembly {
            port spindleCryogenIn : CryogenInPort;
            port spindleDrive : MechanicalDrivePort;
            port spindleSensorData : SensorDataPort;
            port spindleCommand : CommandPort;
        }

        part toolTurret : ToolTurret {
            port turretDrive : MechanicalDrivePort;
            port turretCommand : CommandPort;
            port turretSensorData : SensorDataPort;
        }

        part cuttingToolAssembly : CuttingToolAssembly {
            port toolCryogenIn : CryogenInPort;
            port xAxisMotion : LinearMotionPort;
            port yAxisMotion : LinearMotionPort;
            port zAxisMotion : LinearMotionPort;
            port toolAssemblyCommand : CommandPort;
            port toolAssemblySensorData : SensorDataPort;
        }

        part controlSystem : ControlSystem {
            port programInput :>> CommandPort;
            port chamberFeedback : SensorDataPort;
            port spindleFeedback : SensorDataPort;
            port turretFeedback : SensorDataPort;
            port toolAssemblyFeedback : SensorDataPort;
            port deliveryFeedback : SensorDataPort;
            port safetyFeedback : SensorDataPort;

            port chamberCommandOut : CommandPort;
            port spindleCommandOut : CommandPort;
            port turretCommandOut : CommandPort;
            port toolAssemblyCommandOut : CommandPort;
            port deliveryCommandOut : CommandPort;
        }

        part safetySystem : SafetySystem {
            port emergencyStopIn : CommandPort;
            port doorInterlockSignal : SensorDataPort;
            port leakDetectorSignal : SensorDataPort;
            port safetyAlertOut : SafetySignalPort;
            port safetyCommandOut : CommandPort;
        }

        // Connections
        connection cryogenToChamber connect cryogenicDeliverySystem.reservoirOut to cryogenicChamber.chamberCryogenIn;
        connection chamberToSpindle connect cryogenicChamber.spindleCryogenOut to spindleAssembly.spindleCryogenIn;
        connection chamberToTool connect cryogenicChamber.toolCryogenOut to cuttingToolAssembly.toolCryogenIn;
        connection spindleDriveLink connect spindleAssembly.spindleDrive to toolTurret.turretDrive;
        connection chamberSensorLink connect cryogenicChamber.chamberSensorData to controlSystem.chamberFeedback;
        connection spindleSensorLink connect spindleAssembly.spindleSensorData to controlSystem.spindleFeedback;
        connection turretSensorLink connect toolTurret.turretSensorData to controlSystem.turretFeedback;
        connection toolSensorLink connect cuttingToolAssembly.toolAssemblySensorData to controlSystem.toolAssemblyFeedback;
        connection deliverySensorLink connect cryogenicDeliverySystem.deliveryStatus to controlSystem.deliveryFeedback;
        connection safetySensorLink connect safetySystem.safetyAlertOut to controlSystem.safetyFeedback;
        connection spindleCommandLink connect controlSystem.spindleCommandOut to spindleAssembly.spindleCommand;
        connection turretCommandLink connect controlSystem.turretCommandOut to toolTurret.turretCommand;
        connection toolCommandLink connect controlSystem.toolAssemblyCommandOut to cuttingToolAssembly.toolAssemblyCommand;
        connection deliveryCommandLink connect controlSystem.deliveryCommandOut to cryogenicDeliverySystem.deliveryCommand;
        connection safetyCommandLink connect safetySystem.safetyCommandOut to controlSystem.programInput;
        connection safetyAlertLink connect safetySystem.safetyAlertOut to safetyOutput;

        // Operational state machine
        attribute currentWorkpiece : Workpiece;
        attribute currentProgram : MachiningProgram;

        state machine OperationalCycle {
            entry action { send ControlCommand(commandType := "initialize", targetValue := 0, timestamp := 0); }

            state Idle {
                entry action { send ControlCommand(commandType := "idle", targetValue := 0, timestamp := 0); }
                transition idle_to_Loading trigger currentWorkpiece.loaded;
            }

            state Loading {
                entry action {
                    // Load raw workpiece into chuck
                    currentWorkpiece.currentTemperature := 293[K];
                }
                transition Loading_to_Sealing trigger currentWorkpiece.chucked;
            }

            state Sealing {
                entry action {
                    send ControlCommand(commandType := "seal_chamber", targetValue := 1, timestamp := 0);
                }
                transition Sealing_to_Precooling trigger cryogenicChamber.sealed;
            }

            state Precooling {
                entry action {
                    send ControlCommand(commandType := "start_cryogen_flow", targetValue := 30, timestamp := 0);
                    send ControlCommand(commandType := "set_target_temp", targetValue := 80, timestamp := 0);
                }
                do action {
                    // Monitor temperature until target reached
                    if cryogenicChamber.currentTemperature <= targetCryoTemperature then {
                        send ControlCommand(commandType := "precooling_complete", targetValue := 0, timestamp := 0);
                    }
                }
                transition Precooling_to_Machining trigger cryogenicChamber.temperatureStable;
            }

            state Machining {
                entry action {
                    send ControlCommand(commandType := "start_spindle", targetValue := 5000, timestamp := 0);
                    send ControlCommand(commandType := "select_tool", targetValue := 1, timestamp := 0);
                    send ControlCommand(commandType := "start_cutting", targetValue := 0, timestamp := 0);
                }
                do action {
                    // Execute machining program steps
                    // Monitor spindle speed, tool position, and temperature
                    if currentWorkpiece.currentDiameter <= currentWorkpiece.targetDiameter then {
                        send ControlCommand(commandType := "machining_complete", targetValue := 0, timestamp := 0);
                    }
                }
                transition Machining_to_PostWarmup trigger currentWorkpiece.machiningComplete;
            }

            state PostWarmup {
                entry action {
                    send ControlCommand(commandType := "stop_cryogen_flow", targetValue := 0, timestamp := 0);
                    send ControlCommand(commandType := "stop_spindle", targetValue := 0, timestamp := 0);
                }
                do action {
                    // Allow workpiece to warm to safe handling temperature
                    if currentWorkpiece.currentTemperature >= safeHandlingTemperature then {
                        send ControlCommand(commandType := "warmup_complete", targetValue := 0, timestamp := 0);
                    }
                }
                transition PostWarmup_to_Unloading trigger currentWorkpiece.temperatureSafe;
            }

            state Unloading {
                entry action {
                    send ControlCommand(commandType := "open_chamber", targetValue := 0, timestamp := 0);
                }
                transition Unloading_to_Idle trigger currentWorkpiece.unloaded;
            }

            transition Idle_to_Loading from Idle to Loading;
            transition Loading_to_Sealing from Loading to Sealing;
            transition Sealing_to_Precooling from Sealing to Precooling;
            transition Precooling_to_Machining from Precooling to Machining;
            transition Machining_to_PostWarmup from Machining to PostWarmup;
            transition PostWarmup_to_Unloading from PostWarmup to Unloading;
            transition Unloading_to_Idle from Unloading to Idle;
        }

        satisfy CryolathePerformanceRequirement;
        satisfy OperationalCycleRequirement;
    }

    part def CryogenicChamber {
        doc "Enclosed, thermally insulated chamber where cryogenic machining takes place.";

        attribute chamberVolume : Real = 0.5; // m^3
        attribute currentTemperature : TemperatureValue = 293[K];
        attribute currentPressure : PressureValue = 101325[Pa];
        attribute targetTemperature : TemperatureValue = 80[K];
        attribute sealed : Boolean = false;
        attribute temperatureStable : Boolean = false;

        part insulation : ThermalInsulation;
        part door : ChamberDoor {
            attribute locked : Boolean;
        }

        part temperatureSensors[4] : TemperatureSensor;
        part pressureSensors[2] : PressureSensor;

        port chamberCryogenIn : CryogenInPort;
        port spindleCryogenOut : CryogenFlowPort;
        port toolCryogenOut : CryogenFlowPort;
        port chamberSensorData : SensorDataPort;

        action def CoolDown {
            in targetTemp : TemperatureValue;
            out achieved : Boolean;
            // Reduce chamber temperature to target
        }

        action def WarmUp {
            out achieved : Boolean;
            // Allow chamber to return to ambient temperature
        }
    }

    part def ThermalInsulation {
        attribute insulationThickness : Real = 0.1; // m
        attribute thermalConductivity : Real = 0.02; // W/(m*K)
    }

    part def ChamberDoor {
        attribute locked : Boolean = false;
        attribute sealed : Boolean = false;

        action def Lock { out success : Boolean; }
        action def Unlock { out success : Boolean; }
    }

    part def TemperatureSensor {
        attribute sensorId : String;
        attribute measuredValue : TemperatureValue;
        attribute accuracy : TemperatureValue = 0.1[K];
        attribute rangeMin : TemperatureValue = 50[K];
        attribute rangeMax : TemperatureValue = 350[K];

        port sensorOutput : SensorDataPort;

        action def Read {
            out reading : SensorReading;
        }
    }

    part def PressureSensor {
        attribute sensorId : String;
        attribute measuredValue : PressureValue;
        attribute accuracy : PressureValue = 100[Pa];
        attribute rangeMin : PressureValue = 0[Pa];
        attribute rangeMax : PressureValue = 1000000[Pa];

        port sensorOutput : SensorDataPort;

        action def Read {
            out reading : SensorReading;
        }
    }

    part def CryogenicDeliverySystem {
        doc "System that pumps super-cooled fluid from reservoir into the chamber.";

        attribute maxFlowRate : FlowRateValue = 50[L/min];
        attribute maxPressure : PressureValue = 500000[Pa];
        attribute currentFlowRate : FlowRateValue = 0[L/min];
        attribute currentPressure : PressureValue = 101325[Pa];

        part reservoir : CryogenReservoir {
            attribute capacity : Real = 200; // liters
            attribute fillLevel : PercentageValue;
            attribute fluidTemperature : TemperatureValue = 77[K];
        }

        part pump : CryogenPump {
            attribute pumpPower : PowerValue = 500[W];
            attribute pumpSpeed : RotationalSpeedValue;
            attribute active : Boolean = false;

            port pumpCommand : CommandPort;

            action def Pump {
                in flowCommand : FlowRateValue;
                out deliveredFlow : FlowRateValue;
            }
        }

        part regulator : PressureRegulator {
            attribute setPressure : PressureValue;
            attribute currentPressure : PressureValue;

            action def Regulate {
                in inputPressure : PressureValue;
                out outputPressure : PressureValue;
            }
        }

        part safetyValve : SafetyValve {
            attribute thresholdPressure : PressureValue = 600000[Pa];
            attribute open : Boolean = false;

            action def Check {
                in pressure : PressureValue;
                out valveOpen : Boolean;
            }
        }

        port reservoirOut : CryogenFlowPort;
        port deliveryCommand : CommandPort;
        port deliveryStatus : StatusPort;

        satisfy CryogenicDeliveryRequirement;
    }

    part def CryogenReservoir {
        attribute capacity : Real = 200; // liters
        attribute fillLevel : PercentageValue = 100[%];
        attribute fluidTemperature : TemperatureValue = 77[K];
        attribute fluid : LiquidNitrogen;
    }

    part def CryogenPump {
        attribute pumpPower : PowerValue = 500[W];
        attribute pumpSpeed : RotationalSpeedValue = 0[rpm];
        attribute active : Boolean = false;
        attribute maxFlowRate : FlowRateValue = 50[L/min];

        port pumpCommand : CommandPort;

        action def Start {
            in targetFlow : FlowRateValue;
        }
        action def Stop {}
    }

    part def PressureRegulator {
        attribute setPressure : PressureValue = 200000[Pa];
        attribute currentPressure : PressureValue;
        attribute tolerance : PressureValue = 5000[Pa];

        action def Regulate {
            in inputPressure : PressureValue;
            out outputPressure : PressureValue;
        }
    }

    part def SafetyValve {
        attribute thresholdPressure : PressureValue = 600000[Pa];
        attribute open : Boolean = false;
        attribute venting : Boolean = false;

        action def Check {
            in pressure : PressureValue;
            out valveOpen : Boolean;
        }
        action def Vent {
            out vented : Boolean;
        }
    }

    part def SpindleAssembly {
        doc "High-speed spindle assembly that holds and rotates the workpiece.";

        attribute maxSpeed : RotationalSpeedValue = 10000[rpm];
        attribute currentSpeed : RotationalSpeedValue = 0[rpm];
        attribute currentTemperature : TemperatureValue = 293[K];
        attribute thermalStable : Boolean = false;

        part spindle : Spindle {
            attribute bearingType : String = "ceramic_hybrid";
            attribute runout : Real = 0.0001; // mm
        }

        part chuck : Chuck {
            attribute maxGripDiameter : LinearPositionValue = 200[mm];
            attribute minGripDiameter : LinearPositionValue = 5[mm];
            attribute gripForce : Real = 5000; // N
            attribute workpieceLoaded : Boolean = false;
        }

        part spindleMotor : SpindleMotor {
            attribute ratedPower : PowerValue = 15000[W];
            attribute currentSpeed : RotationalSpeedValue;
            attribute active : Boolean = false;
        }

        port spindleCryogenIn : CryogenInPort;
        port spindleDrive : MechanicalDrivePort;
        port spindleSensorData : SensorDataPort;
        port spindleCommand : CommandPort;

        action def Rotate {
            in targetSpeed : RotationalSpeedValue;
            out achievedSpeed : RotationalSpeedValue;
        }
        action def StopRotation {
            out stopped : Boolean;
        }
        action def CoolSpindle {
            in cryogen : CryogenicFluid;
            out cooled : Boolean;
        }
    }

    part def Spindle {
        attribute bearingType : String = "ceramic_hybrid";
        attribute runout : Real = 0.0001; // mm
        attribute currentTemperature : TemperatureValue;
    }

    part def Chuck {
        attribute maxGripDiameter : LinearPositionValue = 200[mm];
        attribute minGripDiameter : LinearPositionValue = 5[mm];
        attribute gripForce : Real = 5000; // N
        attribute workpieceLoaded : Boolean = false;

        action def Grip {
            in workpiece : Workpiece;
            out secured : Boolean;
        }
        action def Release {
            out released : Boolean;
        }
    }

    part def SpindleMotor {
        attribute ratedPower : PowerValue = 15000[W];
        attribute currentSpeed : RotationalSpeedValue = 0[rpm];
        attribute active : Boolean = false;

        action def Accelerate {
            in targetSpeed : RotationalSpeedValue;
            out achieved : Boolean;
        }
        action def Decelerate {
            out achieved : Boolean;
        }
    }

    part def ToolTurret {
        doc "Multi-station tool turret holding up to eight cutting tools.";

        attribute stationCount : Integer = 8;
        attribute currentStation : Integer = 1;
        attribute indexing : Boolean = false;

        part tools[8] : CuttingTool {
            attribute toolId : String;
            attribute toolType : String;
            attribute stationIndex : Integer;
            attribute wearLevel : PercentageValue = 0[%];
        }

        part indexingMotor : IndexingMotor {
            attribute ratedPower : PowerValue = 1000[W];
            attribute currentSpeed : RotationalSpeedValue;
            attribute active : Boolean = false;
        }

        port turretDrive : MechanicalDrivePort;
        port turretCommand : CommandPort;
        port turretSensorData : SensorDataPort;

        action def Index {
            in targetStation : Integer;
            out indexed : Boolean;
        }
        action def SelectTool {
            in station : Integer;
            out selectedTool : CuttingTool;
        }
    }

    part def IndexingMotor {
        attribute ratedPower : PowerValue = 1000[W];
        attribute currentSpeed : RotationalSpeedValue = 0[rpm];
        attribute active : Boolean = false;

        action def Rotate {
            in targetAngle : Real;
            out achieved : Boolean;
        }
    }

    part def CuttingToolAssembly {
        doc "Assembly that moves the cutting tool along three axes with high-precision actuators.";

        attribute xPosition : LinearPositionValue = 0[mm];
        attribute yPosition : LinearPositionValue = 0[mm];
        attribute zPosition : LinearPositionValue = 0[mm];
        attribute xVelocity : LinearVelocityValue = 0[mm/s];
        attribute yVelocity : LinearVelocityValue = 0[mm/s];
        attribute zVelocity : LinearVelocityValue = 0[mm/s];
        attribute positioningAccuracy : LinearPositionValue = 0.0001[mm];

        part xAxisActuator : LinearActuator {
            attribute stroke : LinearPositionValue = 300[mm];
            attribute maxVelocity : LinearVelocityValue = 500[mm/s];
            attribute currentPosition : LinearPositionValue;
        }

        part yAxisActuator : LinearActuator {
            attribute stroke : LinearPositionValue = 200[mm];
            attribute maxVelocity : LinearVelocityValue = 500[mm/s];
            attribute currentPosition : LinearPositionValue;
        }

        part zAxisActuator : LinearActuator {
            attribute stroke : LinearPositionValue = 150[mm];
            attribute maxVelocity : LinearVelocityValue = 500[mm/s];
            attribute currentPosition : LinearPositionValue;
        }

        part cuttingInsert : CuttingInsert {
            attribute insertMaterial : String = "diamond";
            attribute currentTemperature : TemperatureValue;
            attribute maxOperatingTemperature : TemperatureValue = 700[K];
            attribute wearLevel : PercentageValue = 0[%];
        }

        port toolCryogenIn : CryogenInPort;
        port xAxisMotion : LinearMotionPort;
        port yAxisMotion : LinearMotionPort;
        port zAxisMotion : LinearMotionPort;
        port toolAssemblyCommand : CommandPort;
        port toolAssemblySensorData : SensorDataPort;

        action def MoveTo {
            in x : LinearPositionValue;
            in y : LinearPositionValue;
            in z : LinearPositionValue;
            out positioned : Boolean;
        }
        action def Cut {
            in feedRate : LinearVelocityValue;
            in depth : LinearPositionValue;
            out cutting : Boolean;
        }
        action def CoolInsert {
            in cryogen : CryogenicFluid;
            out cooled : Boolean;
        }
    }

    part def LinearActuator {
        attribute stroke : LinearPositionValue;
        attribute maxVelocity : LinearVelocityValue;
        attribute currentPosition : LinearPositionValue = 0[mm];
        attribute currentVelocity : LinearVelocityValue = 0[mm/s];
        attribute active : Boolean = false;

        action def Move {
            in targetPosition : LinearPositionValue;
            in velocity : LinearVelocityValue;
            out reached : Boolean;
        }
        action def Hold {
            out holding : Boolean;
        }
    }

    part def CuttingInsert {
        attribute insertMaterial : String = "diamond";
        attribute currentTemperature : TemperatureValue = 293[K];
        attribute maxOperatingTemperature : TemperatureValue = 700[K];
        attribute wearLevel : PercentageValue = 0[%];
        attribute maxWear : PercentageValue = 100[%];
    }

    part def ControlSystem {
        doc "Central control system that orchestrates the entire Cryolathe operation.";

        attribute systemState : String = "idle";
        attribute currentProgram : MachiningProgram;
        attribute samplingRate : Real = 1000; // Hz

        part motionController : MotionController {
            attribute controlLoopRate : Real = 5000; // Hz
            attribute xSetpoint : LinearPositionValue;
            attribute ySetpoint : LinearPositionValue;
            attribute zSetpoint : LinearPositionValue;
        }

        part thermalController : ThermalController {
            attribute targetTemperature : TemperatureValue = 80[K];
            attribute controlLoopRate : Real = 100; // Hz
            attribute currentTemperature : TemperatureValue;
        }

        part programInterpreter : ProgramInterpreter {
            attribute currentLine : Integer = 0;
            attribute totalLines : Integer;
            attribute active : Boolean = false;

            action def Parse {
                in program : MachiningProgram;
                out commands : ControlCommand[*];
            }
            action def Execute {
                in command : ControlCommand;
                out completed : Boolean;
            }
        }

        port programInput : CommandPort;
        port chamberFeedback : SensorDataPort;
        port spindleFeedback : SensorDataPort;
        port turretFeedback : SensorDataPort;
        port toolAssemblyFeedback : SensorDataPort;
        port deliveryFeedback : SensorDataPort;
        port safetyFeedback : SensorDataPort;

        port chamberCommandOut : CommandPort;
        port spindleCommandOut : CommandPort;
        port turretCommandOut : CommandPort;
        port toolAssemblyCommandOut : CommandPort;
        port deliveryCommandOut : CommandPort;

        action def LoadProgram {
            in program : MachiningProgram;
            out loaded : Boolean;
        }
        action def MonitorSensors {
            in readings : SensorReading[*];
            out status : SensorReading;
        }
        action def IssueCommand {
            in command : ControlCommand;
            out issued : Boolean;
        }
        action def EmergencyResponse {
            in alert : SafetyAlert;
            out haltCommand : ControlCommand;
        }
    }

    part def MotionController {
        attribute controlLoopRate : Real = 5000; // Hz
        attribute xSetpoint : LinearPositionValue = 0[mm];
        attribute ySetpoint : LinearPositionValue = 0[mm];
        attribute zSetpoint : LinearPositionValue = 0[mm];
        attribute xActual : LinearPositionValue = 0[mm];
        attribute yActual : LinearPositionValue = 0[mm];
        attribute zActual : LinearPositionValue = 0[mm];

        action def UpdateSetpoints {
            in x : LinearPositionValue;
            in y : LinearPositionValue;
            in z : LinearPositionValue;
        }
        action def ComputeCorrection {
            out xCorrection : LinearPositionValue;
            out yCorrection : LinearPositionValue;
            out zCorrection : LinearPositionValue;
        }
    }

    part def ThermalController {
        attribute targetTemperature : TemperatureValue = 80[K];
        attribute controlLoopRate : Real = 100; // Hz
        attribute currentTemperature : TemperatureValue = 293[K];
        attribute tolerance : TemperatureValue = 2[K];

        action def UpdateTarget {
            in target : TemperatureValue;
        }
        action def ComputeFlowCommand {
            out flowRate : FlowRateValue;
        }
    }

    part def ProgramInterpreter {
        attribute currentLine : Integer = 0;
        attribute totalLines : Integer = 0;
        attribute active : Boolean = false;

        action def Parse {
            in program : MachiningProgram;
            out commands : ControlCommand[*];
        }
        action def ExecuteLine {
            in command : ControlCommand;
            out completed : Boolean;
        }
        action def Abort {
            out aborted : Boolean;
        }
    }

    part def SafetySystem {
        doc "Integrated safety system providing emergency stop, door interlocks, and leak detection.";

        attribute systemActive : Boolean = true;
        attribute emergencyStopEngaged : Boolean = false;

        part emergencyStopButtons[3] : EmergencyStopButton {
            attribute engaged : Boolean = false;
            attribute location : String;
        }

        part doorInterlock : DoorInterlock {
            attribute doorClosed : Boolean = true;
            attribute locked : Boolean = false;

            action def Check {
                out safe : Boolean;
            }
        }

        part leakDetector : LeakDetector {
            attribute threshold : Real = 100; // ppm
            attribute detected : Boolean = false;
            attribute location : String;

            action def Sample {
                out concentration : Real;
                out leakDetected : Boolean;
            }
        }

        part safetyController : SafetyController {
            attribute allClear : Boolean = true;
            attribute activeAlerts : SafetyAlert[*];

            action def Evaluate {
                in inputs : SensorReading[*];
                out alerts : SafetyAlert[*];
                out safe : Boolean;
            }
            action def TriggerEmergencyStop {
                out haltCommand : ControlCommand;
            }
        }

        port emergencyStopIn : CommandPort;
        port doorInterlockSignal : SensorDataPort;
        port leakDetectorSignal : SensorDataPort;
        port safetyAlertOut : SafetySignalPort;
        port safetyCommandOut : CommandPort;

        satisfy SafetyRequirement;
    }

    part def EmergencyStopButton {
        attribute engaged : Boolean = false;
        attribute location : String;

        action def Press {
            out engaged : Boolean = true;
        }
        action def Reset {
            out engaged : Boolean = false;
        }
    }

    part def DoorInterlock {
        attribute doorClosed : Boolean = true;
        attribute locked : Boolean = false;

        action def Check {
            out safe : Boolean;
        }
        action def Lock {
            out locked : Boolean;
        }
        action def Unlock {
            out locked : Boolean;
        }
    }

    part def LeakDetector {
        attribute threshold : Real = 100; // ppm
        attribute detected : Boolean = false;
        attribute location : String;
        attribute sensorType : String = "oxygen_displacement";

        action def Sample {
            out concentration : Real;
            out leakDetected : Boolean;
        }
        action def Calibrate {
            out calibrated : Boolean;
        }
    }

    part def SafetyController {
        attribute allClear : Boolean = true;
        attribute activeAlerts : SafetyAlert[*];
        attribute responseTime : DurationValue = 0.5[s];

        action def Evaluate {
            in inputs : SensorReading[*];
            out alerts : SafetyAlert[*];
            out safe : Boolean;
        }
        action def TriggerEmergencyStop {
            out haltCommand : ControlCommand;
        }
        action def ClearAlert {
            in alert : SafetyAlert;
            out cleared : Boolean;
        }
    }

    // ===== Top-level satisfaction =====
    satisfaction CryolathePerformanceRequirement by CryolatheSystem;
    satisfaction CryogenicDeliveryRequirement by CryolatheSystem.cryogenicDeliverySystem;
    satisfaction SafetyRequirement by CryolatheSystem.safetySystem;
    satisfaction OperationalCycleRequirement by CryolatheSystem;
}
