package Surgibox {
    import ScalarValues::*;
    import ISQ::*;
    import ISQSpaceTime::*;
    import ISQElectromagnetism::*;

    // ===== Value Types =====
    attribute def Pressure :> Real { unit = "Pa"; }
    attribute def PressureDiff :> Real { unit = "Pa"; }
    attribute def FlowRate :> Real { unit = "m^3/s"; }
    attribute def FanSpeed :> Real { unit = "1/s"; }
    attribute def BatteryCharge :> Real { unit = "C"; }
    attribute def BatterySOC :> Real { unit = "%"; }
    attribute def Temperature :> Real { unit = "K"; }
    attribute def Humidity :> Real { unit = "%"; }
    attribute def ParticleCount :> Real { unit = "1/m^3"; }
    attribute def Power :> Real { unit = "W"; }
    attribute def Voltage :> Real { unit = "V"; }
    attribute def Current :> Real { unit = "A"; }
    attribute def Duration :> Real { unit = "s"; }
    attribute def Mass :> Real { unit = "kg"; }

    // ===== Item Types =====
    item def AmbientAir {
        attribute temperature : Temperature;
        attribute humidity : Humidity;
        attribute particleCount : ParticleCount;
    }

    item def FilteredAir {
        attribute pressure : Pressure;
        attribute flowRate : FlowRate;
        attribute particleCount : ParticleCount;
    }

    item def ContaminatedAir :> AmbientAir;

    // ===== Interfaces =====
    interface def AirFlow {
        end air : FilteredAir;
    }

    interface def AmbientAirFlow {
        end air : AmbientAir;
    }

    interface def PressureReading {
        end reading : Pressure;
    }

    interface def FanControlSignal {
        end speedCmd : FanSpeed;
    }

    interface def PowerSupply {
        end voltage : Voltage;
        end current : Current;
    }

    interface def BatteryStatus {
        end soc : BatterySOC;
        end voltage : Voltage;
    }

    interface def SystemCommand {
        attribute command : String;
    }

    interface def AlarmSignal {
        attribute alarmType : String;
        attribute severity : Integer;
    }

    // ===== Port Definitions =====
    port def AirInPort {
        out air : AmbientAir;
    }

    port def AirOutPort {
        in air : FilteredAir;
    }

    port def FilteredInPort {
        in air : AmbientAir;
    }

    port def FilteredOutPort {
        out air : FilteredAir;
    }

    port def FanOutPort {
        out air : FilteredAir;
    }

    port def PressureSensorPort {
        out reading : Pressure;
    }

    port def ControllerCmdPort {
        out speedCmd : FanSpeed;
    }

    port def PowerOutPort {
        out voltage : Voltage;
        out current : Current;
    }

    port def PowerInPort {
        in voltage : Voltage;
        in current : Current;
    }

    port def BatteryStatusPort {
        out soc : BatterySOC;
        out voltage : Voltage;
    }

    port def AlarmPort {
        out alarm : AlarmSignal;
    }

    // ===== Requirements =====
    requirement def SterilityRequirement {
        doc /* The system must maintain a sterile environment inside the workspace. */
        constraint { self.workspacePressure > self.ambientPressure + 10.0 }
        constraint { self.particleCountInside < 100.0 }
    }

    requirement def PositivePressureRequirement {
        doc /* Internal pressure must exceed ambient by at least 10 Pa. */
        constraint { self.pressureDiff >= 10.0 [Pa] }
    }

    requirement def HEPAFiltrationRequirement {
        doc /* HEPA filter must remove 99.97% of particles >= 0.3 micrometers. */
        constraint { self.filterEfficiency >= 0.9997 }
    }

    requirement def BatteryLifeRequirement {
        doc /* System must operate for at least 4 hours on battery. */
        constraint { self.operatingTime >= 14400.0 [s] }
    }

    requirement def PortabilityRequirement {
        doc /* Total system mass must not exceed 15 kg. */
        constraint { self.totalMass <= 15.0 [kg] }
    }

    requirement def ResponseTimeRequirement {
        doc /* Controller must adjust fan speed within 2 seconds of pressure deviation. */
        constraint { self.responseTime <= 2.0 [s] }
    }

    // ===== Component Parts =====
    part def FanAssembly {
        attribute nominalSpeed : FanSpeed = 50.0;
        attribute maxSpeed : FanSpeed = 80.0;
        attribute minSpeed : FanSpeed = 0.0;
        attribute currentSpeed : FanSpeed = 0.0;
        attribute powerDraw : Power = 15.0 [W];

        port inAir : AirInPort;
        port outAir : FanOutPort;
        port powerIn : PowerInPort;
        port cmdIn : PowerInPort {
            in speedCmd : FanSpeed;
        }

        action def OperateFan {
            in cmd : FanSpeed;
            out flow : FlowRate;
            action Accelerate {
                in targetSpeed : FanSpeed;
            }
            action Decelerate {
                in targetSpeed : FanSpeed;
            }
        }

        action def DrawAir :> OperateFan {
            doc /* Draws ambient air through the inlet. */
        }
    }

    part def HEPAFilterUnit {
        attribute efficiency : Real = 0.9997;
        attribute maxParticleSize : Real = 0.3e-6;
        attribute serviceLife : Duration = 18000000.0 [s];
        attribute usageTime : Duration = 0.0 [s];
        attribute pressureDrop : Pressure = 50.0 [Pa];

        port inAir : FilteredInPort;
        port outAir : FilteredOutPort;

        action def FilterAir {
            in incoming : AmbientAir;
            out filtered : FilteredAir;
            action CaptureParticles {
                in air : AmbientAir;
            }
            action ReleaseCleanAir {
                out air : FilteredAir;
            }
        }
    }

    part def PressureRegulationSystem {
        attribute targetPressureDiff : PressureDiff = 25.0 [Pa];
        attribute valvePosition : Real = 0.5;
        attribute maxFlowRate : FlowRate = 0.05 [m^3/s];

        port inAir : AirOutPort;
        port outAir : AirOutPort;

        action def RegulatePressure {
            in currentPressure : Pressure;
            in ambientPressure : Pressure;
            out valveCmd : Real;
            action ComparePressure {
                in internal : Pressure;
                in external : Pressure;
                out diff : PressureDiff;
            }
            action AdjustValve {
                in diff : PressureDiff;
                out position : Real;
            }
        }
    }

    part def EnvironmentMonitor {
        attribute internalPressure : Pressure = 101325.0 [Pa];
        attribute ambientPressure : Pressure = 101325.0 [Pa];
        attribute temperature : Temperature = 293.15 [K];
        attribute humidity : Humidity = 50.0 [%];
        attribute particleCount : ParticleCount = 0.0 [1/m^3];
        attribute samplingRate : Real = 1.0 [1/s];

        port pressureOut : PressureSensorPort;

        action def SensePressure {
            out reading : Pressure;
            action SampleSensor {
                out rawValue : Pressure;
            }
            action FilterNoise {
                in raw : Pressure;
                out filtered : Pressure;
            }
        }

        action def SenseEnvironment {
            out temp : Temperature;
            out humid : Humidity;
            out particles : ParticleCount;
        }
    }

    part def SystemController {
        attribute targetPressureDiff : PressureDiff = 25.0 [Pa];
        attribute tolerance : PressureDiff = 5.0 [Pa];
        attribute kp : Real = 0.8;
        attribute ki : Real = 0.2;
        attribute integralError : Real = 0.0;
        attribute responseTime : Duration = 1.0 [s];

        port pressureIn : PressureSensorPort;
        port fanCmdOut : ControllerCmdPort;
        port batteryStatusIn : PowerInPort {
            in soc : BatterySOC;
            in voltage : Voltage;
        }
        port alarmOut : AlarmPort;

        action def ControlLoop {
            in measuredPressure : Pressure;
            in ambientPressure : Pressure;
            out fanCommand : FanSpeed;
            action ComputeError {
                in measured : Pressure;
                in target : Pressure;
                out error : Real;
            }
            action PIDCompute {
                in error : Real;
                out speedCmd : FanSpeed;
            }
            action SendCommand {
                in cmd : FanSpeed;
            }
        }

        action def EvaluateSafety {
            in batterySOC : BatterySOC;
            in pressure : Pressure;
            out alarm : AlarmSignal;
            action CheckBattery {
                in soc : BatterySOC;
                out lowBattery : Boolean;
            }
            action CheckPressure {
                in p : Pressure;
                out pressureFault : Boolean;
            }
        }
    }

    part def BatteryPack {
        attribute capacity : BatteryCharge = 144000.0 [C];
        attribute currentSOC : BatterySOC = 100.0 [%];
        attribute nominalVoltage : Voltage = 12.0 [V];
        attribute maxCurrent : Current = 10.0 [A];
        attribute lowBatteryThreshold : BatterySOC = 20.0 [%];
        attribute criticalBatteryThreshold : BatterySOC = 10.0 [%];
        attribute estimatedRuntime : Duration = 14400.0 [s];

        port powerOut : PowerOutPort;
        port statusOut : BatteryStatusPort;

        action def Discharge {
            in load : Power;
            out remaining : BatterySOC;
            action MonitorCharge {
                out soc : BatterySOC;
            }
        }

        action def Charge {
            in externalPower : Power;
            out charged : BatterySOC;
        }
    }

    part def SterileWorkspace {
        attribute volume : Real = 0.5 [m^3];
        attribute internalPressure : Pressure = 101350.0 [Pa];
        attribute targetPressure : Pressure = 101350.0 [Pa];
        attribute leakageRate : FlowRate = 0.001 [m^3/s];
        attribute internalParticleCount : ParticleCount = 0.0 [1/m^3];

        port airIn : AirOutPort;
        port pressureSensorPort : PressureSensorPort;

        action def MaintainPositivePressure {
            in inflow : FlowRate;
            in leakage : FlowRate;
            out pressure : Pressure;
            action ReceiveFilteredAir {
                in air : FilteredAir;
            }
            action ExpelExcessAir {
                out leaked : FlowRate;
            }
        }
    }

    part def UserInterface {
        attribute displayState : String = "Off";
        attribute alarmActive : Boolean = false;

        port cmdOut : PowerInPort {
            out command : String;
        }
        port alarmIn : AlarmPort;

        action def DisplayStatus {
            in state : String;
            in pressure : Pressure;
            in batterySOC : BatterySOC;
        }

        action def AcceptUserInput {
            out command : String;
        }
    }

    // ===== Top-Level System =====
    part def Surgibox {
        attribute systemMass : Mass = 12.0 [kg];
        attribute ambientPressure : Pressure = 101325.0 [Pa];
        attribute systemState : String = "Off";

        // Sub-components
        part fanAssembly : FanAssembly {
            port inAir : AirInPort;
            port outAir : FanOutPort;
            port powerIn : PowerInPort;
        }

        part hepaFilter : HEPAFilterUnit {
            port inAir : FilteredInPort;
            port outAir : FilteredOutPort;
        }

        part pressureRegulator : PressureRegulationSystem {
            port inAir : AirOutPort;
            port outAir : AirOutPort;
        }

        part environmentMonitor : EnvironmentMonitor {
            port pressureOut : PressureSensorPort;
        }

        part controller : SystemController {
            port pressureIn : PressureSensorPort;
            port fanCmdOut : ControllerCmdPort;
            port batteryStatusIn : PowerInPort;
            port alarmOut : AlarmPort;
        }

        part battery : BatteryPack {
            port powerOut : PowerOutPort;
            port statusOut : BatteryStatusPort;
        }

        part workspace : SterileWorkspace {
            port airIn : AirOutPort;
            port pressureSensorPort : PressureSensorPort;
        }

        part userInterface : UserInterface {
            port cmdOut : PowerInPort;
            port alarmIn : AlarmPort;
        }

        // Connections
        connection ambientAirToFan : AmbientAirFlow connect fanAssembly.inAir to hepaFilter.inAir;
        connection fanToFilter : AirFlow connect fanAssembly.outAir to hepaFilter.inAir;
        connection filterToRegulator : AirFlow connect hepaFilter.outAir to pressureRegulator.inAir;
        connection regulatorToWorkspace : AirFlow connect pressureRegulator.outAir to workspace.airIn;
        connection workspaceToSensor : PressureReading connect workspace.pressureSensorPort to environmentMonitor.pressureOut;
        connection sensorToController : PressureReading connect environmentMonitor.pressureOut to controller.pressureIn;
        connection controllerToFan : FanControlSignal connect controller.fanCmdOut to fanAssembly.cmdIn;
        connection batteryToFan : PowerSupply connect battery.powerOut to fanAssembly.powerIn;
        connection batteryToController : PowerSupply connect battery.powerOut to controller.batteryStatusIn;
        connection batteryStatusToController : BatteryStatus connect battery.statusOut to controller.batteryStatusIn;
        connection controllerAlarmToUI : AlarmSignal connect controller.alarmOut to userInterface.alarmIn;

        // Requirements satisfaction
        satisfy SterilityRequirement {
            attribute workspacePressure : Pressure = workspace.internalPressure;
            attribute ambientPressure : Pressure = self.ambientPressure;
            attribute particleCountInside : ParticleCount = workspace.internalParticleCount;
        }

        satisfy PositivePressureRequirement {
            attribute pressureDiff : PressureDiff = workspace.internalPressure - self.ambientPressure;
        }

        satisfy HEPAFiltrationRequirement {
            attribute filterEfficiency : Real = hepaFilter.efficiency;
        }

        satisfy BatteryLifeRequirement {
            attribute operatingTime : Duration = battery.estimatedRuntime;
        }

        satisfy PortabilityRequirement {
            attribute totalMass : Mass = self.systemMass;
        }

        // ===== State Machine =====
        state def SurgiboxStateMachine {
            attribute currentPressure : Pressure;
            attribute batterySOC : BatterySOC;

            state Initializing {
                entry action {
                    // Power on self-test
                }
                do action SelfTest {
                    out result : Boolean;
                }
                transition to Pressurizing
                    if { self.batterySOC > 10.0 [%] }
                    then { }
            }

            state Pressurizing {
                entry action {
                    // Start fan at high speed
                }
                do action RampUpFan {
                    in targetSpeed : FanSpeed;
                    out currentSpeed : FanSpeed;
                }
                transition to SterileReady
                    if { self.currentPressure > 101335.0 [Pa] }
                    then { }
                transition to LowBatterySafety
                    if { self.batterySOC < 10.0 [%] }
                    then { }
            }

            state SterileReady {
                entry action {
                    // Signal ready
                }
                do action MaintainIdlePressure {
                    in pressure : Pressure;
                    out fanCmd : FanSpeed;
                }
                transition to ActiveOperation
                    if { /* user starts procedure */ }
                    then { }
                transition to LowBatterySafety
                    if { self.batterySOC < 10.0 [%] }
                    then { }
                transition to Shutdown
                    if { /* user powers off */ }
                    then { }
            }

            state ActiveOperation {
                entry action {
                    // Procedure in progress
                }
                do action ContinuousControl {
                    in measuredPressure : Pressure;
                    out fanCommand : FanSpeed;
                }
                transition to SterileReady
                    if { /* procedure ends */ }
                    then { }
                transition to LowBatterySafety
                    if { self.batterySOC < 10.0 [%] }
                    then { }
                transition to Shutdown
                    if { /* user powers off */ }
                    then { }
            }

            state LowBatterySafety {
                entry action {
                    // Trigger alarm
                }
                do action ReduceLoad {
                    out reducedFanSpeed : FanSpeed;
                }
                transition to Shutdown
                    if { self.batterySOC < 5.0 [%] }
                    then { }
                transition to SterileReady
                    if { self.batterySOC > 20.0 [%] }
                    then { }
            }

            state Shutdown {
                entry action {
                    // Begin shutdown sequence
                }
                do action GracefulShutdown {
                    action DecelerateFan {
                        out speed : FanSpeed;
                    }
                    action CloseValves {
                        out valvePosition : Real;
                    }
                    action SaveLogs {
                    }
                }
                transition to Off
                    if { /* shutdown complete */ }
                    then { }
            }

            state Off {
                entry action {
                    // System powered off
                }
                transition to Initializing
                    if { /* power on */ }
                    then { }
            }
        }

        // Main behavior
        behavior stateMachine : SurgiboxStateMachine {
            attribute currentPressure : Pressure = workspace.internalPressure;
            attribute batterySOC : BatterySOC = battery.currentSOC;
        }
    }
}
