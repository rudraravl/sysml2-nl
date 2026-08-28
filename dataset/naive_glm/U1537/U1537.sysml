package WindTurbineSystem {
    import ScalarValues::*;

    // ===== Value Types =====
    value def Length :> Real { unit = "m"; }
    value def Diameter :> Real { unit = "m"; }
    value def RotationalSpeed :> Real { unit = "rpm"; }
    value def Torque :> Real { unit = "N*m"; }
    value def Power :> Real { unit = "W"; }
    value def Voltage :> Real { unit = "V"; }
    value def Frequency :> Real { unit = "Hz"; }
    value def WindSpeed :> Real { unit = "m/s"; }
    value def Angle :> Real { unit = "deg"; }
    value def GearRatio :> Real { unit = "1"; }
    value def Mass :> Real { unit = "kg"; }

    // ===== Item Types =====
    item def WindFlow {
        attribute windSpeed : WindSpeed;
        attribute windDirection : Angle;
    }

    item def MechanicalRotation {
        attribute speed : RotationalSpeed;
        attribute torque : Torque;
    }

    item def ElectricalPower {
        attribute power : Power;
        attribute voltage : Voltage;
        attribute frequency : Frequency;
    }

    item def PitchCommand {
        attribute targetAngle : Angle;
    }

    item def YawCommand {
        attribute targetAngle : Angle;
    }

    item def BrakeCommand {
        attribute engaged : Boolean;
    }

    // ===== Port Definitions =====
    port def WindPort {
        inout wind : WindFlow;
    }

    port def MechanicalPort {
        inout rotation : MechanicalRotation;
    }

    port def ElectricalPort {
        inout power : ElectricalPower;
    }

    port def PitchControlPort {
        inout cmd : PitchCommand;
    }

    port def YawControlPort {
        inout cmd : YawCommand;
    }

    port def BrakeControlPort {
        inout cmd : BrakeCommand;
    }

    // ===== Part Definitions =====

    part def Tower {
        attribute height : Length = 85 [m];
        attribute material : String = "steel";
        attribute baseDiameter : Diameter = 6 [m];
        attribute topDiameter : Diameter = 4 [m];
    }

    part def Blade {
        attribute length : Length = 45 [m];
        attribute currentPitchAngle : Angle = 0 [deg];
        attribute featheredAngle : Angle = 90 [deg];

        port pitchInput : PitchControlPort;

        action adjustPitch {
            in cmd : PitchCommand;
            then action rotateBlade {
                in targetAngle : Angle;
            }
        }

        action feather {
            then action adjustPitch {
                in cmd : PitchCommand;
            }
        }
    }

    part def Hub {
        attribute diameter : Diameter = 3 [m];
        port mechanicalOutput : MechanicalPort;

        action transferRotation {
            in bladeTorque : Torque;
            out rotation : MechanicalRotation;
        }
    }

    part def Rotor {
        attribute bladeCount : Integer = 3;
        attribute rotorDiameter : Diameter = 90 [m];

        part hub : Hub;
        part blade1 : Blade;
        part blade2 : Blade;
        part blade3 : Blade;

        port windInput : WindPort;
        port mechanicalOutput : MechanicalPort;
        port pitchControlInput : PitchControlPort;

        connection pitchToBlade1 connect pitchControlInput to blade1.pitchInput;
        connection pitchToBlade2 connect pitchControlInput to blade2.pitchInput;
        connection pitchToBlade3 connect pitchControlInput to blade3.pitchInput;
        connection hubToOutput connect hub.mechanicalOutput to mechanicalOutput;

        action captureWindEnergy {
            in wind : WindFlow;
            out rotation : MechanicalRotation;
        }
    }

    part def Gearbox {
        attribute gearRatio : GearRatio = 95 [1];
        port inputPort : MechanicalPort;
        port outputPort : MechanicalPort;

        action increaseSpeed {
            in lowSpeedRotation : MechanicalRotation;
            out highSpeedRotation : MechanicalRotation;
        }
    }

    part def Generator {
        attribute ratedPower : Power = 2500000 [W];
        port mechanicalInput : MechanicalPort;
        port electricalOutput : ElectricalPort;

        action generateElectricity {
            in rotation : MechanicalRotation;
            out power : ElectricalPower;
        }
    }

    part def PowerConverter {
        attribute outputVoltage : Voltage = 35000 [V];
        attribute outputFrequency : Frequency = 60 [Hz];
        port electricalInput : ElectricalPort;
        port electricalOutput : ElectricalPort;

        action convertPower {
            in rawPower : ElectricalPower;
            out gridPower : ElectricalPower;
        }

        action stabilizeFrequency {
            in inputFrequency : Frequency;
            out outputFrequency : Frequency;
        }

        action stepUpVoltage {
            in inputVoltage : Voltage;
            out outputVoltage : Voltage;
        }
    }

    part def YawSystem {
        attribute currentYawAngle : Angle = 0 [deg];
        port yawInput : YawControlPort;

        action rotateNacelle {
            in cmd : YawCommand;
            then action alignToWind {
                in targetAngle : Angle;
            }
        }
    }

    part def PitchSystem {
        port pitchInput : PitchControlPort;
        port pitchOutput : PitchControlPort;

        action adjustBladePitch {
            in cmd : PitchCommand;
        }

        action featherBlades {
            out cmd : PitchCommand;
        }
    }

    part def BrakeSystem {
        attribute isEngaged : Boolean = false;
        port brakeInput : BrakeControlPort;

        action engage {
            in cmd : BrakeCommand;
            then action applyBrakeForce;
        }

        action disengage {
            in cmd : BrakeCommand;
            then action releaseBrakeForce;
        }
    }

    part def ControlSystem {
        attribute cutInSpeed : WindSpeed = 3.5 [m/s];
        attribute cutOutSpeed : WindSpeed = 25 [m/s];
        attribute ratedPower : Power = 2500000 [W];
        attribute maintenanceRequested : Boolean = false;

        port windSensorInput : WindPort;
        port yawOutput : YawControlPort;
        port pitchOutput : PitchControlPort;
        port brakeOutput : BrakeControlPort;

        action monitorWind {
            in wind : WindFlow;
        }

        action computeYaw {
            in wind : WindFlow;
            out cmd : YawCommand;
        }

        action computePitch {
            in wind : WindFlow;
            out cmd : PitchCommand;
        }

        action regulatePower {
            in wind : WindFlow;
            out pitchCmd : PitchCommand;
        }

        action emergencyShutdown {
            then action featherBlades;
            then action engageBrake;
        }

        state def ControlStates {
            entry action initialize;

            state Idle {
                entry action stopGeneration;
            }

            state Starting {
                entry action startSequence;
                do action monitorWind;
            }

            state Generating {
                entry action beginGeneration;
                do action regulatePower;
            }

            state ShuttingDown {
                entry action featherBladesAndBrake;
            }

            state Maintenance {
                entry action haltForMaintenance;
            }

            transition idleToStarting
                from Idle to Starting
                when windSensorInput.wind.windSpeed >= cutInSpeed;

            transition startingToGenerating
                from Starting to Generating
                when windSensorInput.wind.windSpeed >= cutInSpeed
                    and windSensorInput.wind.windSpeed < cutOutSpeed;

            transition generatingToShuttingDown
                from Generating to ShuttingDown
                when windSensorInput.wind.windSpeed >= cutOutSpeed;

            transition shuttingDownToIdle
                from ShuttingDown to Idle
                when windSensorInput.wind.windSpeed < cutOutSpeed;

            transition generatingToMaintenance
                from Generating to Maintenance
                when maintenanceRequested;

            transition maintenanceToIdle
                from Maintenance to Idle
                when not maintenanceRequested;
        }

        exhibit state ControlStates;
    }

    part def Nacelle {
        part gearbox : Gearbox;
        part generator : Generator;
        part powerConverter : PowerConverter;
        part yawSystem : YawSystem;
        part pitchSystem : PitchSystem;
        part brakeSystem : BrakeSystem;
        part controlSystem : ControlSystem;

        port rotorInput : MechanicalPort;
        port gridOutput : ElectricalPort;
        port windSensor : WindPort;
        port pitchToRotor : PitchControlPort;

        connection rotorToGearbox connect rotorInput to gearbox.inputPort;
        connection gearboxToGenerator connect gearbox.outputPort to generator.mechanicalInput;
        connection generatorToConverter connect generator.electricalOutput to powerConverter.electricalInput;
        connection converterToGrid connect powerConverter.electricalOutput to gridOutput;
        connection windToControl connect windSensor to controlSystem.windSensorInput;
        connection controlToYaw connect controlSystem.yawOutput to yawSystem.yawInput;
        connection controlToPitch connect controlSystem.pitchOutput to pitchSystem.pitchInput;
        connection pitchToRotorOut connect pitchSystem.pitchOutput to pitchToRotor;
        connection controlToBrake connect controlSystem.brakeOutput to brakeSystem.brakeInput;
    }

    part def WindTurbine {
        attribute ratedPower : Power = 2500000 [W];
        attribute towerHeight : Length = 85 [m];
        attribute rotorDiameter : Diameter = 90 [m];
        attribute bladeLength : Length = 45 [m];
        attribute gearRatio : GearRatio = 95 [1];
        attribute cutInSpeed : WindSpeed = 3.5 [m/s];
        attribute cutOutSpeed : WindSpeed = 25 [m/s];

        part tower : Tower;
        part nacelle : Nacelle;
        part rotor : Rotor;

        port windInput : WindPort;
        port gridOutput : ElectricalPort;

        connection windToRotor connect windInput to rotor.windInput;
        connection rotorToNacelle connect rotor.mechanicalOutput to nacelle.rotorInput;
        connection nacelleToGrid connect nacelle.gridOutput to gridOutput;
        connection pitchToRotor connect nacelle.pitchToRotor to rotor.pitchControlInput;
        connection windToNacelleSensor connect windInput to nacelle.windSensor;

        action operateTurbine {
            in wind : WindFlow;
            out gridPower : ElectricalPower;
        }
    }

    // ===== Requirements =====

    requirement def PowerGenerationRequirement {
        doc "The wind turbine shall generate 2.5 megawatts of electrical power.";
        attribute requiredPower : Power = 2500000 [W];
        subject turbine : WindTurbine;
        require turbine.ratedPower == requiredPower;
    }

    requirement def TowerHeightRequirement {
        doc "The tower shall be 85 meters tall and constructed of steel.";
        attribute requiredHeight : Length = 85 [m];
        attribute requiredMaterial : String = "steel";
        subject tower : Tower;
        require tower.height == requiredHeight;
        require tower.material == requiredMaterial;
    }

    requirement def RotorDiameterRequirement {
        doc "The rotor shall have a total diameter of 90 meters with three 45-meter blades.";
        attribute requiredDiameter : Diameter = 90 [m];
        attribute requiredBladeCount : Integer = 3;
        subject rotor : Rotor;
        require rotor.rotorDiameter == requiredDiameter;
        require rotor.bladeCount == requiredBladeCount;
    }

    requirement def BladeLengthRequirement {
        doc "Each blade shall be 45 meters long.";
        attribute requiredLength : Length = 45 [m];
        subject blade : Blade;
        require blade.length == requiredLength;
    }

    requirement def GearboxRatioRequirement {
        doc "The gearbox shall increase rotational speed by a factor of 95.";
        attribute requiredRatio : GearRatio = 95 [1];
        subject gearbox : Gearbox;
        require gearbox.gearRatio == requiredRatio;
    }

    requirement def CutInSpeedRequirement {
        doc "The turbine shall begin generating power at a cut-in wind speed of 3.5 m/s.";
        attribute requiredCutInSpeed : WindSpeed = 3.5 [m/s];
        subject control : ControlSystem;
        require control.cutInSpeed == requiredCutInSpeed;
    }

    requirement def CutOutSpeedRequirement {
        doc "The turbine shall shut down when wind speed exceeds 25 m/s.";
        attribute requiredCutOutSpeed : WindSpeed = 25 [m/s];
        subject control : ControlSystem;
        require control.cutOutSpeed == requiredCutOutSpeed;
    }

    requirement def EmergencyShutdownRequirement {
        doc "During emergency shutdown at cut-out speed, the brake shall be engaged and blades shall be feathered to prevent damage.";
        subject control : ControlSystem;
        subject brake : BrakeSystem;
        subject blade : Blade;
        require control.cutOutSpeed == 25 [m/s];
    }

    requirement def YawControlRequirement {
        doc "The yaw system shall rotate the nacelle to keep the rotor facing directly into the wind.";
        subject yaw : YawSystem;
    }

    requirement def PitchControlRequirement {
        doc "The pitch system shall adjust blade angles to control rotational speed, optimize power capture, and feather blades to stop rotation.";
        subject pitch : PitchSystem;
    }

    requirement def PowerConversionRequirement {
        doc "The power converter shall stabilize power and step up voltage to match grid requirements.";
        subject converter : PowerConverter;
    }

    // ===== Requirement Usages =====

    requirement powerGenReq : PowerGenerationRequirement;
    requirement towerHeightReq : TowerHeightRequirement;
    requirement rotorDiameterReq : RotorDiameterRequirement;
    requirement bladeLengthReq : BladeLengthRequirement;
    requirement gearboxRatioReq : GearboxRatioRequirement;
    requirement cutInReq : CutInSpeedRequirement;
    requirement cutOutReq : CutOutSpeedRequirement;
    requirement emergencyShutdownReq : EmergencyShutdownRequirement;
    requirement yawControlReq : YawControlRequirement;
    requirement pitchControlReq : PitchControlRequirement;
    requirement powerConversionReq : PowerConversionRequirement;
}
