package ErYAGLaserSystem {

    // ---- Value Types with Units ----
    value type Length :> Real { unit 'm'; }
    value type Temperature :> Real { unit 'K'; }
    value type Voltage :> Real { unit 'V'; }
    value type Current :> Real { unit 'A'; }
    value type Energy :> Real { unit 'J'; }
    value type Power :> Real { unit 'W'; }
    value type FlowRate :> Real { unit 'm3/s'; }
    value type Time :> Real { unit 's'; }
    value type Frequency :> Real { unit 'Hz'; }
    value type Dimensionless :> Real { }

    // ---- Item Definitions ----
    item def ElectricalPulse {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute duration : Time;
        attribute energy : Energy;
    }
    item def LightPulse {
        attribute wavelength : Length;
        attribute energy : Energy;
        attribute duration : Time;
    }
    item def CoolantFlow {
        attribute flowRate : FlowRate;
        attribute temperature : Temperature;
        attribute pressure : Power;
    }
    item def ControlCommand {
        attribute powerSetting : Power;
        attribute trigger : Boolean;
        attribute enable : Boolean;
    }
    item def StatusReport {
        attribute crystalTemp : Temperature;
        attribute lampTemp : Temperature;
        attribute coolingOK : Boolean;
        attribute interlockOK : Boolean;
        attribute ready : Boolean;
    }
    item def LaserBeam {
        attribute wavelength : Length;
        attribute energy : Energy;
        attribute peakPower : Power;
        attribute pulseDuration : Time;
    }

    // ---- Port Definitions ----
    port def ElectricalPort {
        out pulse : ElectricalPulse;
    }
    port def OpticalPort {
        in input : LightPulse;
        out output : LightPulse;
    }
    port def CoolantSupplyPort {
        out supply : CoolantFlow;
    }
    port def CoolantReturnPort {
        in return : CoolantFlow;
    }
    port def CommandPort {
        in command : ControlCommand;
    }
    port def StatusPort {
        out status : StatusReport;
    }
    port def BeamPort {
        out beam : LaserBeam;
    }
    port def InterlockPort {
        out interlockOK : Boolean;
    }

    // ---- Er:YAG Crystal Rod ----
    part def ErYAGCrystalRod {
        attribute nominalWavelength : Length = 2940e-9 [m];
        attribute maxOperatingTemp : Temperature = 350 [K];
        attribute temperature : Temperature;

        port pumpInput : OpticalPort;
        port laserOutput : OpticalPort;
        port coolantIn : CoolantSupplyPort;
        port coolantOut : CoolantReturnPort;
        port statusOut : StatusPort;

        state def CrystalState {
            entry;
            state Idle;
            state Absorbing;
            state Lasing;
            state Cooling;
            transition Idle to Absorbing
                when pumpInput.input.energy > 0 [J];
            transition Absorbing to Lasing
                when temperature > 300 [K];
            transition Lasing to Cooling
                when laserOutput.output.energy > 0 [J];
            transition Cooling to Idle
                when temperature < 310 [K];
        }

        exhibit CrystalState;

        action def GenerateLaserPulse {
            in pumpLight : LightPulse;
            out laserPulse : LightPulse;
        }
    }

    // ---- Xenon Flash Lamp ----
    part def XenonFlashLamp {
        attribute nominalVoltage : Voltage = 1000 [V];
        attribute pulseEnergy : Energy;
        attribute temperature : Temperature;

        port electricalInput : ElectricalPort;
        port flashOutput : OpticalPort;
        port coolantIn : CoolantSupplyPort;
        port coolantOut : CoolantReturnPort;

        action def FireFlash {
            in electricalPulse : ElectricalPulse;
            out flashLight : LightPulse;
        }

        state def LampState {
            state Standby;
            state Charging;
            state Firing;
            state Cooling;
            transition Standby to Charging
                when electricalInput.pulse.voltage > 0 [V];
            transition Charging to Firing;
            transition Firing to Cooling;
            transition Cooling to Standby
                when temperature < 320 [K];
        }

        exhibit LampState;
    }

    // ---- Optical Resonator ----
    part def OpticalResonator {
        attribute cavityLength : Length;
        attribute rearMirrorReflectivity : Dimensionless = 0.999;
        attribute frontMirrorReflectivity : Dimensionless = 0.85;

        port laserOutput : OpticalPort;
        port coolantIn : CoolantSupplyPort;
        port coolantOut : CoolantReturnPort;
        port statusOut : StatusPort;

        part rearMirror {
            attribute reflectivity : Dimensionless = 0.999;
        }
        part frontMirror {
            attribute reflectivity : Dimensionless = 0.85;
        }
        part crystal : ErYAGCrystalRod;
        part flashLamp : XenonFlashLamp;

        connect flashLamp.flashOutput to crystal.pumpInput;
        connect crystal.laserOutput to laserOutput;
        connect coolantIn to crystal.coolantIn;
        connect coolantIn to flashLamp.coolantIn;
        connect crystal.coolantOut to coolantOut;
        connect flashLamp.coolantOut to coolantOut;
        connect crystal.statusOut to statusOut;

        action def AmplifyLight {
            in seedLight : LightPulse;
            out amplifiedBeam : LightPulse;
        }
    }

    // ---- High-Voltage Power Supply ----
    part def HighVoltagePowerSupply {
        attribute chargeVoltage : Voltage = 1500 [V];
        attribute storedEnergy : Energy;
        attribute maxEnergy : Energy = 500 [J];

        port electricalOutput : ElectricalPort;
        port commandInput : CommandPort;
        port statusOutput : StatusPort;

        state def PowerSupplyState {
            state Off;
            state Charging;
            state Charged;
            state Discharging;
            state Fault;

            transition Off to Charging
                when commandInput.command.enable;
            transition Charging to Charged
                when storedEnergy >= maxEnergy;
            transition Charged to Discharging
                when commandInput.command.trigger;
            transition Discharging to Charging;
            transition Charged to Fault
                when storedEnergy > maxEnergy * 1.1;
            transition any to Off
                when !commandInput.command.enable;
        }

        exhibit PowerSupplyState;

        action def DischargeCapacitors {
            out pulse : ElectricalPulse;
        }
    }

    // ---- Cooling Subsystem ----
    part def CoolingSubsystem {
        attribute coolantFlowRate : FlowRate = 0.001 [m3/s];
        attribute setpointTemp : Temperature = 295 [K];
        attribute maxTemp : Temperature = 330 [K];

        port coolantSupply : CoolantSupplyPort;
        port coolantReturn : CoolantReturnPort;
        port statusOutput : StatusPort;

        part pump {
            attribute flowRate : FlowRate;
            state def PumpState {
                state Off;
                state On;
                transition Off to On when coolantFlowRate > 0 [m3/s];
                transition On to Off when coolantFlowRate == 0 [m3/s];
            }
            exhibit PumpState;
        }
        part heatExchanger {
            attribute heatRemovalCapacity : Power;
        }
        part reservoir {
            attribute capacity : FlowRate;
            attribute coolantLevel : Dimensionless;
        }
        part tempSensor {
            attribute measuredTemp : Temperature;
        }

        connect pump to heatExchanger;
        connect heatExchanger to reservoir;
        connect reservoir to pump;
        connect tempSensor to statusOutput;

        action def CirculateCoolant {
            out coolant : CoolantFlow;
        }
    }

    // ---- Laser Control Unit ----
    part def LaserControlUnit {
        attribute targetPower : Power;
        attribute maxPower : Power = 200 [W];
        attribute sampleRate : Frequency = 100 [Hz];

        port operatorCommand : CommandPort;
        port systemStatus : StatusPort;
        port interlockInput : InterlockPort;
        port hvCommand : CommandPort;
        port statusOutput : StatusPort;

        state def ControlState {
            entry;
            state Initialize;
            state SafetyCheck;
            state Ready;
            state Firing;
            state Cooldown;
            state Fault;

            transition Initialize to SafetyCheck;
            transition SafetyCheck to Ready
                when systemStatus.status.interlockOK and systemStatus.status.coolingOK
                    and systemStatus.status.crystalTemp < 330 [K];
            transition Ready to Firing
                when operatorCommand.command.trigger;
            transition Firing to Cooldown;
            transition Cooldown to SafetyCheck;
            transition any to Fault
                when !systemStatus.status.interlockOK or !systemStatus.status.coolingOK;
            transition Fault to SafetyCheck
                when systemStatus.status.interlockOK and systemStatus.status.coolingOK;
        }

        exhibit ControlState;

        action def OrchestrateFiringSequence {
            in command : ControlCommand;
            in status : StatusReport;
            out hvTrigger : ControlCommand;
        }
    }

    // ---- Safety Interlock System ----
    part def SafetyInterlockSystem {
        attribute doorClosed : Boolean = false;
        attribute keyEnabled : Boolean = false;
        attribute coolingFunctional : Boolean = false;
        attribute emergencyStop : Boolean = false;

        port interlockOutput : InterlockPort;
        port statusOutput : StatusPort;

        action def EvaluateInterlocks {
            out allOK : Boolean;
        }

        state def InterlockState {
            state Unsafe;
            state Safe;
            transition Unsafe to Safe
                when doorClosed and keyEnabled and coolingFunctional and !emergencyStop;
            transition Safe to Unsafe
                when !doorClosed or !keyEnabled or !coolingFunctional or emergencyStop;
        }

        exhibit InterlockState;
    }

    // ---- Beam Delivery Optics ----
    part def BeamDeliveryOptics {
        attribute focalLength : Length = 0.05 [m];
        attribute beamDiameter : Length = 0.003 [m];

        port beamInput : OpticalPort;
        port beamOutput : BeamPort;

        part focusingLens {
            attribute focalLength : Length;
        }
        part steeringMirror {
            attribute reflectivity : Dimensionless = 0.99;
        }
        part collimator {
            attribute aperture : Length;
        }

        connect beamInput to collimator;
        connect collimator to steeringMirror;
        connect steeringMirror to focusingLens;
        connect focusingLens to beamOutput;

        action def ShapeAndFocusBeam {
            in inputBeam : LightPulse;
            out outputBeam : LaserBeam;
        }
    }

    // ---- Top-Level Er:YAG Laser System ----
    part ErYAGLaserSystem {
        attribute systemWavelength : Length = 2940e-9 [m];
        attribute maxPulseEnergy : Energy = 500 [J];
        attribute repRate : Frequency = 10 [Hz];

        port operatorInterface : CommandPort;
        port outputBeam : BeamPort;
        port systemStatus : StatusPort;

        part resonator : OpticalResonator;
        part powerSupply : HighVoltagePowerSupply;
        part cooling : CoolingSubsystem;
        part controlUnit : LaserControlUnit;
        part interlock : SafetyInterlockSystem;
        part beamDelivery : BeamDeliveryOptics;

        connect operatorInterface to controlUnit.operatorCommand;
        connect controlUnit.hvCommand to powerSupply.commandInput;
        connect powerSupply.electricalOutput to resonator.flashLamp.electricalInput;
        connect cooling.coolantSupply to resonator.coolantIn;
        connect resonator.coolantOut to cooling.coolantReturn;
        connect resonator.laserOutput to beamDelivery.beamInput;
        connect beamDelivery.beamOutput to outputBeam;
        connect interlock.interlockOutput to controlUnit.interlockInput;
        connect resonator.statusOut to controlUnit.systemStatus;
        connect cooling.statusOutput to controlUnit.systemStatus;
        connect controlUnit.statusOutput to systemStatus;
        connect interlock.statusOutput to systemStatus;
    }

    // ---- Requirements ----
    requirement def WavelengthRequirement {
        subject laser : ErYAGLaserSystem;
        require laser.systemWavelength == 2940e-9 [m];
    }

    requirement def PulseEnergyRequirement {
        subject laser : ErYAGLaserSystem;
        require laser.maxPulseEnergy >= 100 [J];
        require laser.maxPulseEnergy <= 500 [J];
    }

    requirement def ThermalStabilityRequirement {
        subject crystal : ErYAGCrystalRod;
        require crystal.temperature <= crystal.maxOperatingTemp;
    }

    requirement def SafetyInterlockRequirement {
        subject interlock : SafetyInterlockSystem;
        require interlock.doorClosed == true;
        require interlock.keyEnabled == true;
        require interlock.coolingFunctional == true;
        require interlock.emergencyStop == false;
    }

    requirement def CoolingRequirement {
        subject cooling : CoolingSubsystem;
        require cooling.coolantFlowRate >= 0.0005 [m3/s];
        require cooling.setpointTemp <= 300 [K];
    }

    requirement def BeamPrecisionRequirement {
        subject optics : BeamDeliveryOptics;
        require optics.focalLength >= 0.01 [m];
        require optics.focalLength <= 0.1 [m];
        require optics.beamDiameter <= 0.005 [m];
    }

    requirement def ControlFiringSequenceRequirement {
        subject control : LaserControlUnit;
        require control.targetPower <= control.maxPower;
    }

    requirement package ErYAGLaserRequirements {
        requirement wavelengthReq : WavelengthRequirement;
        requirement pulseEnergyReq : PulseEnergyRequirement;
        requirement thermalReq : ThermalStabilityRequirement;
        requirement safetyReq : SafetyInterlockRequirement;
        requirement coolingReq : CoolingRequirement;
        requirement beamReq : BeamPrecisionRequirement;
        requirement controlReq : ControlFiringSequenceRequirement;
    }

    // ---- System Verification ----
    verification def VerifyWavelength {
        subject laser : ErYAGLaserSystem;
        objective { require laser.systemWavelength == 2940e-9 [m]; }
    }

    verification def VerifySafetyInterlocks {
        subject interlock : SafetyInterlockSystem;
        objective { require interlock.interlockOutput.interlockOK == true; }
    }

    verification def VerifyCoolingPerformance {
        subject cooling : CoolingSubsystem;
        objective { require cooling.coolantFlowRate >= 0.0005 [m3/s]; }
    }

    verification def VerifyFiringSequence {
        subject control : LaserControlUnit;
        objective { require control.targetPower <= control.maxPower; }
    }

}
