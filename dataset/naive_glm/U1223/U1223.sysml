package DiamondLaserSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types with Units =====
    value def PowerUnit :> Real;
    unit kW : PowerUnit;
    unit W : PowerUnit;

    value def VoltageUnit :> Real;
    unit V : VoltageUnit;

    value def CurrentUnit :> Real;
    unit A : CurrentUnit;

    value def TemperatureUnit :> Real;
    unit degC : TemperatureUnit;

    value def FlowRateUnit :> Real;
    unit L_per_min : FlowRateUnit;

    value def WavelengthUnit :> Real;
    unit nm : WavelengthUnit;

    value def ReflectivityUnit :> Real;
    unit percent : ReflectivityUnit;

    value def LengthUnit :> Real;
    unit mm : LengthUnit;

    // ===== Item Types =====
    item def ElectricalPower {
        attribute voltage : VoltageUnit;
        attribute current : CurrentUnit;
    }

    item def OpticalBeam {
        attribute power : PowerUnit;
        attribute wavelength : WavelengthUnit;
        attribute coherent : Boolean;
    }

    item def CoolantFluid {
        attribute temperature : TemperatureUnit;
        attribute flowRate : FlowRateUnit;
    }

    item def ControlCommand {
        attribute command : String;
    }

    item def SensorReading {
        attribute temperature : TemperatureUnit;
        attribute timestamp : Real;
    }

    // ===== Port Definitions =====
    port def ElectricalPort {
        attribute voltage : VoltageUnit;
        attribute current : CurrentUnit;
        out item : ElectricalPower;
    }

    port def OpticalPort {
        attribute wavelength : WavelengthUnit;
        in item : OpticalBeam;
        out item : OpticalBeam;
    }

    port def CoolantPort {
        in item : CoolantFluid;
        out item : CoolantFluid;
    }

    port def ControlPort {
        in item : ControlCommand;
        out item : SensorReading;
    }

    // ===== Requirements =====
    requirement def OutputPowerRequirement {
        doc { The system shall produce a continuous-wave laser beam with output power of 10 kW at 1064 nm. }
        attribute requiredPower : PowerUnit = 10 [kW];
        attribute requiredWavelength : WavelengthUnit = 1064 [nm];
        subject outputBeam : OpticalBeam;
        constraint { outputBeam.power == requiredPower }
        constraint { outputBeam.wavelength == requiredWavelength }
    }

    requirement def ThermalStabilityRequirement {
        doc { The diamond gain medium operating temperature shall not exceed 80 degC during active lasing. }
        attribute maxTemp : TemperatureUnit = 80 [degC];
        subject diamondTemp : TemperatureUnit;
        constraint { diamondTemp <= maxTemp }
    }

    requirement def EmergencyShutdownRequirement {
        doc { The controller shall trigger emergency shutdown if diamond temperature exceeds 90 degC. }
        attribute emergencyTemp : TemperatureUnit = 90 [degC];
        subject measuredTemp : TemperatureUnit;
        constraint { measuredTemp >= emergencyTemp implies shutdownTriggered }
        attribute shutdownTriggered : Boolean;
    }

    requirement def PowerConversionRequirement {
        doc { The power supply shall convert main AC power into high-current DC electricity for the diode pump array. }
        subject psu : PowerSupplyUnit;
    }

    requirement def PumpArrayRequirement {
        doc { The diode pump array shall consist of 24 laser diodes whose combined output energizes the diamond gain medium. }
        attribute diodeCount : Integer = 24;
        subject pumpArray : DiodePumpArray;
        constraint { pumpArray.diodeCount == diodeCount }
    }

    // ===== Parts =====
    part def PowerSupplyUnit {
        port in mainPower : ElectricalPort;
        port out hvOutput : ElectricalPort;
        attribute inputVoltage : VoltageUnit = 480 [V];
        attribute outputCurrent : CurrentUnit = 200 [A];
        attribute efficiency : Real = 0.92;

        action def ConvertPower {
            in main : ElectricalPower;
            out hv : ElectricalPower;
        }

        perform action convertPower : ConvertPower {
            in main = mainPower.item;
            out hv = hvOutput.item;
        }
    }

    part def LaserDiode {
        port in diodePower : ElectricalPort;
        port out pumpBeam : OpticalPort;
        attribute ratedPower : PowerUnit = 50 [W];
        attribute pumpWavelength : WavelengthUnit = 808 [nm];

        action def EmitPumpLight {
            in power : ElectricalPower;
            out beam : OpticalBeam;
        }

        perform action emitPumpLight : EmitPumpLight {
            in power = diodePower.item;
            out beam = pumpBeam.item;
        }
    }

    part def DiodePumpArray {
        port in arrayPower : ElectricalPort;
        port out combinedPumpBeam : OpticalPort;
        attribute diodeCount : Integer = 24;
        attribute totalPumpPower : PowerUnit = 1200 [W];

        part diodes : LaserDiode[24];

        action def CombinePumpBeams {
            in beams : OpticalBeam[24];
            out combined : OpticalBeam;
        }

        perform action combinePumpBeams : CombinePumpBeams {
            in beams = diodes.pumpBeam.item;
            out combined = combinedPumpBeam.item;
        }
    }

    part def SyntheticDiamondGainMedium {
        port in pumpInput : OpticalPort;
        port in coolantIn : CoolantPort;
        port out coolantOut : CoolantPort;
        port out amplifiedBeam : OpticalPort;
        port out tempSensorOut : ControlPort;

        attribute length : LengthUnit = 10 [mm];
        attribute doping : String = "nitrogen";
        attribute thermalConductivity : Real = 2000;
        attribute operatingTemp : TemperatureUnit = 25 [degC];
        attribute outputWavelength : WavelengthUnit = 1064 [nm];
        attribute maxSafeTemp : TemperatureUnit = 80 [degC];

        action def AmplifyBeam {
            in pump : OpticalBeam;
            in coolant : CoolantFluid;
            out amplified : OpticalBeam;
            out heatedCoolant : CoolantFluid;
            out tempReading : SensorReading;
        }

        perform action amplifyBeam : AmplifyBeam {
            in pump = pumpInput.item;
            in coolant = coolantIn.item;
            out amplified = amplifiedBeam.item;
            out heatedCoolant = coolantOut.item;
            out tempReading = tempSensorOut.item;
        }
    }

    part def ResonatorMirror {
        port in incomingBeam : OpticalPort;
        port out reflectedBeam : OpticalPort;
        attribute reflectivity : ReflectivityUnit;
        attribute position : String;
    }

    part def HighReflectorMirror :> ResonatorMirror {
        attribute reflectivity : ReflectivityUnit = 99.9 [percent];
        attribute position : String = "rear";
    }

    part def OutputCouplerMirror :> ResonatorMirror {
        attribute reflectivity : ReflectivityUnit = 70 [percent];
        attribute position : String = "front";
    }

    part def OpticalCavity {
        port in pumpBeam : OpticalPort;
        port out outputBeam : OpticalPort;

        part highReflector : HighReflectorMirror;
        part outputCoupler : OutputCouplerMirror;
        part diamond : SyntheticDiamondGainMedium;

        connection beamPath1 connect highReflector.reflectedBeam to diamond.pumpInput;
        connection beamPath2 connect diamond.amplifiedBeam to outputCoupler.incomingBeam;
        connection beamPath3 connect outputCoupler.reflectedBeam to highReflector.incomingBeam;
        connection finalOutput connect outputCoupler.reflectedBeam to outputBeam;
    }

    part def CoolantPump {
        port in coolantReturn : CoolantPort;
        port out coolantSupply : CoolantPort;
        attribute flowRate : FlowRateUnit = 15 [L_per_min];
        attribute coolantType : String = "deionized_water";

        action def CirculateCoolant {
            in returnFluid : CoolantFluid;
            out supplyFluid : CoolantFluid;
        }

        perform action circulateCoolant : CirculateCoolant {
            in returnFluid = coolantReturn.item;
            out supplyFluid = coolantSupply.item;
        }
    }

    part def HeatExchanger {
        port in heatedCoolant : CoolantPort;
        port out cooledCoolant : CoolantPort;
        attribute coolingCapacity : PowerUnit = 5 [kW];

        action def DissipateHeat {
            in hot : CoolantFluid;
            out cold : CoolantFluid;
        }

        perform action dissipateHeat : DissipateHeat {
            in hot = heatedCoolant.item;
            out cold = cooledCoolant.item;
        }
    }

    part def ThermalManagementSystem {
        port in coolantFromDiamond : CoolantPort;
        port out coolantToDiamond : CoolantPort;
        port in controllerCommand : ControlPort;

        part pump : CoolantPump;
        part heatExchanger : HeatExchanger;

        connection returnPath connect coolantFromDiamond to heatExchanger.heatedCoolant;
        connection toPump connect heatExchanger.cooledCoolant to pump.coolantReturn;
        connection supplyPath connect pump.coolantSupply to coolantToDiamond;
    }

    part def TemperatureSensor {
        port out reading : ControlPort;
        attribute range : TemperatureUnit = 150 [degC];
        attribute accuracy : Real = 0.1;

        action def MeasureTemperature {
            out tempReading : SensorReading;
        }

        perform action measureTemperature : MeasureTemperature {
            out tempReading = reading.item;
        }
    }

    part def LaserController {
        port in sensorInput : ControlPort;
        port in userCommand : ControlPort;
        port out psuControl : ControlPort;
        port out pumpControl : ControlPort;
        port out coolantControl : ControlPort;
        port out emergencySignal : ControlPort;

        attribute maxOperatingTemp : TemperatureUnit = 80 [degC];
        attribute emergencyTemp : TemperatureUnit = 90 [degC];
        attribute currentTemp : TemperatureUnit = 25 [degC];
        attribute enabled : Boolean = false;

        action def MonitorAndRegulate {
            in tempReading : SensorReading;
            in command : ControlCommand;
            out psuCmd : ControlCommand;
            out pumpCmd : ControlCommand;
            out coolantCmd : ControlCommand;
            out emergency : ControlCommand;
        }

        perform action monitorAndRegulate : MonitorAndRegulate {
            in tempReading = sensorInput.item;
            in command = userCommand.item;
            out psuCmd = psuControl.item;
            out pumpCmd = pumpControl.item;
            out coolantCmd = coolantControl.item;
            out emergency = emergencySignal.item;
        }

        state machine def ControllerStateMachine {
            entry;
            then standby;

            state standby {
                entry { enabled = false; }
            }

            state warmup {
                entry { enabled = true; }
            }

            state activeLasing {
                entry { enabled = true; }
                do monitorAndRegulate;
            }

            state cooldown {
                entry { enabled = false; }
            }

            state emergencyShutdown {
                entry { enabled = false; }
            }

            transition standby_to_warmup
                from standby to warmup
                when userCommand.item.command == "ENABLE";

            transition warmup_to_active
                from warmup to activeLasing
                when currentTemp >= 25 [degC];

            transition active_to_cooldown
                from activeLasing to cooldown
                when userCommand.item.command == "DISABLE";

            transition cooldown_to_standby
                from cooldown to standby
                when currentTemp <= 30 [degC];

            transition any_to_emergency
                from activeLasing to emergencyShutdown
                when currentTemp >= 90 [degC];

            transition emergency_to_cooldown
                from emergencyShutdown to cooldown
                when currentTemp < 90 [degC];
        }

        exhibit state machine : ControllerStateMachine;
    }

    // ===== Top-Level System =====
    part def DiamondLaserSystem {
        port in mainPowerInput : ElectricalPort;
        port in userCommands : ControlPort;
        port out laserOutput : OpticalPort;
        port out systemStatus : ControlPort;

        attribute systemOutputPower : PowerUnit = 10 [kW];
        attribute outputWavelength : WavelengthUnit = 1064 [nm];

        part powerSupply : PowerSupplyUnit;
        part pumpArray : DiodePumpArray;
        part opticalCavity : OpticalCavity;
        part thermalManagement : ThermalManagementSystem;
        part controller : LaserController;
        part tempSensor : TemperatureSensor;

        connection mainPowerConnect connect mainPowerInput to powerSupply.mainPower;
        connection hvPowerConnect connect powerSupply.hvOutput to pumpArray.arrayPower;
        connection pumpBeamConnect connect pumpArray.combinedPumpBeam to opticalCavity.pumpBeam;
        connection outputBeamConnect connect opticalCavity.outputBeam to laserOutput;

        connection coolantToDiamond connect thermalManagement.coolantToDiamond to opticalCavity.diamond.coolantIn;
        connection coolantFromDiamond connect opticalCavity.diamond.coolantOut to thermalManagement.coolantFromDiamond;

        connection sensorToController connect opticalCavity.diamond.tempSensorOut to controller.sensorInput;
        connection userToController connect userCommands to controller.userCommand;
        connection controllerToPSU connect controller.psuControl to powerSupply.mainPower;
        connection controllerToCoolant connect controller.coolantControl to thermalManagement.controllerCommand;
        connection statusOut connect controller.emergencySignal to systemStatus;

        // System-level state machine
        state machine def SystemOperationStateMachine {
            entry;
            then standby;

            state standby {
                doc { System is powered off and not producing laser output. }
            }

            state warmup {
                doc { System is initializing; coolant circulation starts and diodes ramp up. }
            }

            state activeLasing {
                doc { System is producing 10 kW continuous-wave laser output at 1064 nm. }
                do { controller.monitorAndRegulate; }
            }

            state cooldown {
                doc { Laser disabled; coolant continues circulating to bring diamond to safe temperature. }
            }

            state emergencyShutdown {
                doc { Emergency condition detected; all power cut immediately. }
            }

            transition t1 from standby to warmup
                when userCommands.item.command == "ENABLE";

            transition t2 from warmup to activeLasing
                when tempSensor.reading.item.temperature >= 25 [degC];

            transition t3 from activeLasing to cooldown
                when userCommands.item.command == "DISABLE";

            transition t4 from cooldown to standby
                when tempSensor.reading.item.temperature <= 30 [degC];

            transition t5 from activeLasing to emergencyShutdown
                when tempSensor.reading.item.temperature >= 90 [degC];

            transition t6 from emergencyShutdown to cooldown
                when tempSensor.reading.item.temperature < 90 [degC];
        }

        exhibit state machine : SystemOperationStateMachine;

        // Requirement satisfaction
        satisfy outputPowerRequirement by laserOutput;
        satisfy thermalStabilityRequirement by opticalCavity.diamond.operatingTemp;
        satisfy emergencyShutdownRequirement by tempSensor.reading.item.temperature;
        satisfy powerConversionRequirement by powerSupply;
        satisfy pumpArrayRequirement by pumpArray;
    }

    // ===== Requirement Instances =====
    requirement outputPowerRequirement : OutputPowerRequirement;
    requirement thermalStabilityRequirement : ThermalStabilityRequirement;
    requirement emergencyShutdownRequirement : EmergencyShutdownRequirement;
    requirement powerConversionRequirement : PowerConversionRequirement;
    requirement pumpArrayRequirement : PumpArrayRequirement;
}
