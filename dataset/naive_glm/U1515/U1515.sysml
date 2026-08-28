package ThunderboltSirenSystem {
    import ScalarValues::*;
    
    // ===== Value Types (with implicit units) =====
    
    value type VoltageValue :> Real;            // Volts (V)
    value type CurrentValue :> Real;            // Amperes (A)
    value type FrequencyValue :> Real;          // Hertz (Hz)
    value type RotationalSpeedValue :> Real;    // revolutions per minute (rpm)
    value type SoundPressureLevelValue :> Real; // decibels (dB SPL)
    value type DurationValue :> Real;           // seconds (s)
    value type PowerValue :> Real;              // Watts (W)
    value type TorqueValue :> Real;             // Newton-meters (N·m)
    value type MassValue :> Real;               // kilograms (kg)
    value type PressureValue :> Real;           // Pascals (Pa)
    value type EfficiencyValue :> Real;        // ratio (0 to 1)
    
    // ===== Item Definitions =====
    
    item def UtilityPower {
        doc /* Standard utility electrical power input */
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
        attribute frequency : FrequencyValue;
    }
    
    item def DrivePower {
        doc /* High-current electricity for motor operation */
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }
    
    item def AirFlow {
        doc /* Ambient air drawn into the chopper */
        attribute volumeFlowRate : Real; // cubic meters per second
    }
    
    item def ModulatedAir {
        doc /* Airflow modulated by the chopper to create warning tone */
        attribute modulationFrequency : FrequencyValue;
        attribute pressurePulse : PressureValue;
    }
    
    item def AcousticWarning {
        doc /* Projected omnidirectional warning sound */
        attribute soundPressureLevel : SoundPressureLevelValue;
        attribute frequency : FrequencyValue;
        attribute directivityPattern : String = "omnidirectional";
    }
    
    item def ControlCommand {
        doc /* External command for siren operation */
        attribute commandType : String; // "activate", "test", or "deactivate"
        attribute priority : Integer;
    }
    
    item def MotorControlSignal {
        doc /* Control signal from control unit to motor */
        attribute energized : Boolean;
        attribute targetSpeed : RotationalSpeedValue;
        attribute testMode : Boolean = false;
    }
    
    // ===== Port Definitions =====
    
    port def UtilityPowerPort {
        attribute power : UtilityPower;
    }
    
    port def DrivePowerPort {
        attribute power : DrivePower;
    }
    
    port def CommandPort {
        attribute command : ControlCommand;
    }
    
    port def ControlSignalPort {
        attribute signal : MotorControlSignal;
    }
    
    port def MechanicalDrivePort {
        attribute speed : RotationalSpeedValue;
        attribute torque : TorqueValue;
    }
    
    port def AirPort {
        attribute flow : AirFlow;
    }
    
    port def ModulatedAirPort {
        attribute modulatedAir : ModulatedAir;
    }
    
    port def AcousticPort {
        attribute warning : AcousticWarning;
    }
    
    // ===== Part Definitions =====
    
    part def PowerSupply {
        doc /* Converts standard utility power into high-current electricity for the motor */
        
        port utilityIn : UtilityPowerPort;
        port driveOut : DrivePowerPort;
        
        attribute inputVoltage : VoltageValue = 240;
        attribute inputFrequency : FrequencyValue = 60;
        attribute outputVoltage : VoltageValue = 480;
        attribute maxOutputCurrent : CurrentValue = 250;
        attribute conversionEfficiency : EfficiencyValue = 0.92;
        attribute thermalProtection : Boolean = true;
        
        action convertPower {
            doc /* Converts utility AC power to high-current drive power */
            in inputPower : UtilityPower;
            out outputPower : DrivePower;
        }
    }
    
    part def ControlUnit {
        doc /* Processes external commands and manages siren operation */
        
        port commandIn : CommandPort;
        port controlOut : ControlSignalPort;
        
        attribute currentCommand : String = "none";
        attribute systemState : String = "standby";
        attribute lastTestResult : String;
        attribute responseTime : DurationValue = 0.1;
        
        action processCommand {
            doc /* Interprets external commands and generates motor control signals */
            in cmd : ControlCommand;
            out signal : MotorControlSignal;
        }
        
        action executeTest {
            doc /* Performs a brief test cycle of the siren system */
            out signal : MotorControlSignal;
        }
    }
    
    part def ElectricMotor {
        doc /* Core electric motor providing rotational power to rotor and chopper */
        
        port drivePowerIn : DrivePowerPort;
        port controlIn : ControlSignalPort;
        port rotorDrive : MechanicalDrivePort;
        port chopperDrive : MechanicalDrivePort;
        
        attribute ratedSpeed : RotationalSpeedValue = 1800;
        attribute ratedTorque : TorqueValue = 300;
        attribute powerRating : PowerValue = 75000;
        attribute startupTime : DurationValue = 8;
        attribute operatingTemperature : Real; // degrees Celsius
        
        action generateRotation {
            doc /* Converts electrical energy into mechanical rotation for rotor and chopper */
            in power : DrivePower;
            in control : MotorControlSignal;
            out rotorDrive : MechanicalDrivePort;
            out chopperDrive : MechanicalDrivePort;
        }
        
        action spinUp {
            doc /* Accelerates motor from rest to full operating speed */
            in targetSpeed : RotationalSpeedValue;
            out achievedSpeed : RotationalSpeedValue;
        }
    }
    
    part def RotorHorn {
        doc /* Single projecting horn on the rotor assembly */
        attribute length : Real;     // meters
        attribute diameter : Real;    // meters
        attribute flareAngle : Real;  // degrees
        attribute acousticGain : SoundPressureLevelValue;
    }
    
    part def RotorAssembly {
        doc /* Rotating structure with five projecting horns distributing sound omnidirectionally */
        
        port driveIn : MechanicalDrivePort;
        port modulatedAirIn : ModulatedAirPort;
        port acousticOut : AcousticPort;
        
        attribute rotationalSpeed : RotationalSpeedValue;
        attribute mass : MassValue = 250;
        attribute fullOperatingSpeed : RotationalSpeedValue = 1800;
        attribute hornCount : Integer = 5;
        attribute momentOfInertia : Real; // kg·m²
        
        part horn1 : RotorHorn;
        part horn2 : RotorHorn;
        part horn3 : RotorHorn;
        part horn4 : RotorHorn;
        part horn5 : RotorHorn;
        
        action projectSound {
            doc /* Projects modulated air as omnidirectional acoustic warning through horns */
            in modulatedAir : ModulatedAir;
            in rotation : MechanicalDrivePort;
            out warning : AcousticWarning;
        }
        
        action distributeSound {
            doc /* Rotates horns to distribute sound evenly across 360 degrees */
            in rotation : RotationalSpeedValue;
            out directivity : String;
        }
    }
    
    part def Chopper {
        doc /* Mechanical chopper that modulates airflow to create distinctive warning tone */
        
        port driveIn : MechanicalDrivePort;
        port airIn : AirPort;
        port modulatedAirOut : ModulatedAirPort;
        
        attribute bladeCount : Integer = 6;
        attribute toneFrequency : FrequencyValue = 460;
        attribute rotationalSpeed : RotationalSpeedValue;
        attribute portCount : Integer = 5;
        
        action modulateAir {
            doc /* Interrupts airflow through rotating ports to create the characteristic siren tone */
            in airflow : AirFlow;
            in rotation : MechanicalDrivePort;
            out modulatedAir : ModulatedAir;
        }
    }
    
    // ===== State Machine =====
    
    state def SirenOperation {
        doc /* Operational state machine for the Thunderbolt siren */
        
        attribute fullSpeed : RotationalSpeedValue = 1800;
        attribute maxStartupDuration : DurationValue = 10;
        attribute currentSpeed : RotationalSpeedValue;
        attribute currentCommand : String;
        attribute elapsedTime : DurationValue;
        
        entry;
        
        state standby {
            doc /* Siren idle, motor power cut, ready for next activation */
            entry action enterStandby {
                doc /* Motor de-energized, rotor at rest, system awaiting command */
            }
        }
        
        state startup {
            doc /* Motor spins up the heavy rotor assembly to full operating speed */
            entry action beginStartup {
                doc /* Energize motor; begin acceleration of rotor and chopper assemblies */
            }
            do action accelerateRotor {
                doc /* Continuously drive rotor and chopper toward full operating speed */
            }
        }
        
        state active {
            doc /* Full-intensity warning sound emitted continuously */
            entry action reachFullSpeed {
                doc /* Rotor at full speed; chopper modulating; horns projecting sound */
            }
            do action emitWarning {
                doc /* Sustain full-intensity omnidirectional warning output */
            }
        }
        
        state coasting {
            doc /* Motor de-energized; rotor assembly coasts down to stop */
            entry action cutPower {
                doc /* Power to motor cut; rotor decelerating under its own inertia */
            }
            do action decelerate {
                doc /* Rotor coasts down freely until rotational speed reaches zero */
            }
        }
        
        transition from standby to startup 
            when currentCommand == "activate";
        
        transition from startup to active 
            when currentSpeed >= fullSpeed;
        
        transition from active to coasting 
            when currentCommand == "deactivate";
        
        transition from coasting to standby 
            when currentSpeed == 0;
    }
    
    // ===== Requirements =====
    
    requirement def ThunderboltSirenRequirements {
        doc /* Top-level requirements for the Thunderbolt siren system */
        
        requirement omnidirectionalWarning {
            doc /* The siren shall generate an extremely loud, omnidirectional warning sound covering a wide area */
            attribute minSoundPressureLevel : SoundPressureLevelValue = 130;
        }
        
        requirement powerConversion {
            doc /* The power supply shall convert standard utility power into high-current electricity for the motor */
        }
        
        requirement commandProcessing {
            doc /* The control unit shall process external commands to activate, test, or deactivate the siren */
        }
        
        requirement motorEnergization {
            doc /* Upon activation, the control unit shall energize the motor */
        }
        
        requirement rotorSpinUp {
            doc /* The motor shall spin up the heavy rotor assembly to full operating speed in less than 10 seconds */
            attribute maxStartupTime : DurationValue = 10;
        }
        
        requirement dualDrive {
            doc /* The motor shall simultaneously drive the rotor assembly and the mechanical chopper */
        }
        
        requirement chopperModulation {
            doc /* The chopper shall modulate the airflow to create the siren's distinctive warning tone at a specific frequency */
            attribute targetToneFrequency : FrequencyValue = 460;
        }
        
        requirement soundProjection {
            doc /* The spinning horns of the rotor assembly shall channel and project the modulated sound powerfully in all directions */
        }
        
        requirement continuousFullIntensity {
            doc /* The siren shall produce its full-intensity warning sound continuously until a deactivation command is received */
        }
        
        requirement safeDeactivation {
            doc /* Upon deactivation, motor power shall be cut and the assembly shall coast down to a stop */
        }
        
        requirement readyForReactivation {
            doc /* After coasting to a stop, the siren shall return to standby ready for the next activation */
        }
    }
    
    // ===== Top-level System Definition =====
    
    part def ThunderboltSiren {
        doc /* Complete Thunderbolt siren electromechanical outdoor warning system */
        
        port utilityPowerIn : UtilityPowerPort;
        port commandInput : CommandPort;
        port airIntake : AirPort;
        port soundOutput : AcousticPort;
        
        attribute systemName : String = "Thunderbolt";
        attribute installationType : String = "outdoor";
        attribute coverageRadius : Real; // meters
        
        part powerSupply : PowerSupply;
        part controlUnit : ControlUnit;
        part motor : ElectricMotor;
        part rotor : RotorAssembly;
        part chopper : Chopper;
        
        // Connections
        connection from utilityPowerIn to powerSupply.utilityIn;
        connection from powerSupply.driveOut to motor.drivePowerIn;
        connection from commandInput to controlUnit.commandIn;
        connection from controlUnit.controlOut to motor.controlIn;
        connection from motor.rotorDrive to rotor.driveIn;
        connection from motor.chopperDrive to chopper.driveIn;
        connection from airIntake to chopper.airIn;
        connection from chopper.modulatedAirOut to rotor.modulatedAirIn;
        connection from rotor.acousticOut to soundOutput;
        
        // Behavior
        exhibit state operation : SirenOperation;
        
        // Requirements
        satisfy ThunderboltSirenRequirements;
    }
}
