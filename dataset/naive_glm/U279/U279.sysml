package LaserScalpelSystem {
    import ScalarValues::*;
    import ISQ::*;

    // Value Types
    type PowerUnit = Real { unit "W"; }
    type TemperatureUnit = Real { unit "K"; }
    type FlowRateUnit = Real { unit "L/min"; }
    type DistanceUnit = Real { unit "mm"; }

    // Item Types
    item def LaserBeam {
        attr power: PowerUnit;
        attr wavelength: Real { unit "nm"; }
    }
    item def Coolant {
        attr temperature: TemperatureUnit;
        attr flowRate: FlowRateUnit;
    }
    item def ControlSignal {
        attr command: String;
        attr value: Real;
    }
    item def SafetyStatus {
        attr doorClosed: Boolean;
        attr keyOn: Boolean;
        attr estopNotPressed: Boolean;
        attr externalInterlocksOk: Boolean;
        derived attr allOk: Boolean = doorClosed and keyOn and estopNotPressed and externalInterlocksOk;
    }

    // Ports
    port def LaserPort {
        out beam: LaserBeam;
    }
    port def CoolantPort {
        out supply: Coolant;
        in return: Coolant;
    }
    port def ControlPort {
        out signal: ControlSignal;
        in feedback: ControlSignal;
    }
    port def SafetyPort {
        out status: SafetyStatus;
    }

    // Requirements
    requirement def SystemRequirements {
        subject system: LaserScalpelSystem;
        requirement SafetyReq {
            doc "The system shall prevent laser activation if any safety interlock is open."
        }
        requirement ThermalReq {
            doc "The system shall maintain operating temperatures within safe limits."
        }
        requirement PrecisionReq {
            doc "The system shall deliver a focused laser spot for precise incisions."
        }
    }

    // Sub-components
    part def LaserDiodeArray {
        port beamOut: LaserPort;
    }
    part def OpticalCavity {
        port beamIn: LaserPort;
        port beamOut: LaserPort;
    }
    part def BeamShapingOptics {
        port beamIn: LaserPort;
        port beamOut: LaserPort;
    }

    part def TouchscreenDisplay {
        port cmdOut: ControlPort;
        port feedbackIn: ControlPort;
    }
    part def FootPedal {
        out activated: Boolean;
    }

    part def ArticulatedArm {
        port beamIn: LaserPort;
        port beamOut: LaserPort;
    }
    part def FiberOpticCable {
        port beamIn: LaserPort;
        port beamOut: LaserPort;
    }

    part def FocusingOptics {
        port beamIn: LaserPort;
        port beamOut: LaserPort;
    }
    part def AimingBeam {
        port beamOut: LaserPort;
    }
    part def ContactSensor {
        port cmdOut: ControlPort;
    }

    part def Pump {
        port coolantIn: CoolantPort;
        port coolantOut: CoolantPort;
    }
    part def Reservoir {
        port coolantOut: CoolantPort;
        port coolantIn: CoolantPort;
    }
    part def HeatExchanger {
        port coolantIn: CoolantPort;
        port coolantOut: CoolantPort;
    }

    part def DoorSensor {
        out status: Boolean;
    }
    part def KeySwitch {
        out status: Boolean;
    }
    part def EmergencyStop {
        out status: Boolean;
    }
    part def ExternalInterlock {
        out status: Boolean;
    }

    // Main Components
    part def LaserGenerator {
        part diodeArray: LaserDiodeArray;
        part cavity: OpticalCavity;
        part shapingOptics: BeamShapingOptics;

        port laserOut: LaserPort;
        port controlIn: ControlPort;
        port coolantIn: CoolantPort;

        connect diodeArray.beamOut to cavity.beamIn;
        connect cavity.beamOut to shapingOptics.beamIn;
        connect shapingOptics.beamOut to laserOut;
    }

    part def ControlConsole {
        part display: TouchscreenDisplay;
        part pedal: FootPedal;

        port controlOut: ControlPort;
        port controlIn: ControlPort;
        port safetyIn: SafetyPort;

        connect display.cmdOut to controlOut;
        connect controlIn to display.feedbackIn;
    }

    part def OpticalDeliverySystem {
        part arm: ArticulatedArm;
        part fiber: FiberOpticCable;

        port laserIn: LaserPort;
        port laserOut: LaserPort;

        connect laserIn to arm.beamIn;
        connect arm.beamOut to fiber.beamIn;
        connect fiber.beamOut to laserOut;
    }

    part def SurgicalHandpiece {
        part focusing: FocusingOptics;
        part aiming: AimingBeam;
        part sensor: ContactSensor;

        port laserIn: LaserPort;
        port controlOut: ControlPort;
        port coolantIn: CoolantPort;

        connect laserIn to focusing.beamIn;
        connect sensor.cmdOut to controlOut;
    }

    part def ThermalManagementSystem {
        part pump: Pump;
        part reservoir: Reservoir;
        part heatExchanger: HeatExchanger;

        port coolantOut: CoolantPort;
        port coolantIn: CoolantPort;

        connect reservoir.coolantOut to pump.coolantIn;
        connect pump.coolantOut to heatExchanger.coolantIn;
        connect heatExchanger.coolantOut to coolantOut;
        connect coolantIn to reservoir.coolantIn;
    }

    part def SafetyInterlockSystem {
        part door: DoorSensor;
        part key: KeySwitch;
        part estop: EmergencyStop;
        part external: ExternalInterlock;

        port safetyOut: SafetyPort;

        action def AggregateStatus {
            in doorStatus: Boolean;
            in keyStatus: Boolean;
            in estopStatus: Boolean;
            in externalStatus: Boolean;
            out aggregatedStatus: SafetyStatus;
        }
    }

    // Top-level System
    part def LaserScalpelSystem {
        part generator: LaserGenerator;
        part console: ControlConsole;
        part delivery: OpticalDeliverySystem;
        part handpiece: SurgicalHandpiece;
        part thermal: ThermalManagementSystem;
        part safety: SafetyInterlockSystem;

        connect generator.laserOut to delivery.laserIn;
        connect delivery.laserOut to handpiece.laserIn;

        connect console.controlOut to generator.controlIn;
        connect handpiece.controlOut to console.controlIn;

        connect thermal.coolantOut to generator.coolantIn;
        connect thermal.coolantOut to handpiece.coolantIn;

        connect safety.safetyOut to console.safetyIn;

        state def SystemStates {
            state Off;
            state Initializing {
                entry action initialize;
                do action selfTest;
                transition to Standby when selfTest == true;
                transition to Fault when selfTest == false;
            }
            state Standby {
                transition to Ready when safety.safetyOut.status.allOk == true;
            }
            state Ready {
                transition to Active when console.pedal.activated == true;
                transition to Fault when thermal.temp > maxTemp;
            }
            state Active {
                entry action activateLaser;
                transition to Ready when console.pedal.activated == false;
                transition to Fault when safety.safetyOut.status.allOk == false;
            }
            state Fault {
                entry action shutdownLaser;
                transition to Off when reset == true;
            }
        }

        attribute stateMachine: SystemStates;
    }
}
