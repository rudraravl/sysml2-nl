package HighTemperatureSuperconductivitySystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Temperature {
        :> scalarValue;
        unit = K;
    }

    attribute def ElectricCurrent {
        :> scalarValue;
        unit = A;
    }

    attribute def Voltage {
        :> scalarValue;
        unit = V;
    }

    attribute def MagneticFluxDensity {
        :> scalarValue;
        unit = T;
    }

    attribute def HeatFlowRate {
        :> scalarValue;
        unit = W;
    }

    attribute def Pressure {
        :> scalarValue;
        unit = Pa;
    }

    attribute def Length {
        :> scalarValue;
        unit = m;
    }

    attribute def Power {
        :> scalarValue;
        unit = W;
    }

    attribute def Resistance {
        :> scalarValue;
        unit = Ohm;
    }

    attribute def Ratio {
        :> scalarValue;
    }

    item def CryogenicCoolant {
        attribute temperature : Temperature;
        attribute pressure : Pressure;
        attribute massFlowRate : Real;
        attribute phase : CoolantPhase;
    }

    enum def CoolantPhase {
        enum liquid;
        enum twoPhase;
        enum gas;
    }

    item def ElectricalEnergy {
        attribute current : ElectricCurrent;
        attribute voltage : Voltage;
        attribute power : Power;
        attribute frequency : Real;
    }

    item def MagneticField {
        attribute fluxDensity : MagneticFluxDensity;
        attribute fieldUniformity : Ratio;
    }

    item def ThermalLoad {
        attribute heatFlow : HeatFlowRate;
        attribute sourceTemperature : Temperature;
    }

    item def StatusMessage {
        attribute code : Integer;
        attribute severity : SeverityLevel;
        attribute description : String;
    }

    enum def SeverityLevel {
        enum nominal;
        enum caution;
        enum warning;
        enum fault;
    }

    port def ElectricalPowerPort {
        inout item energy : ElectricalEnergy;
    }

    port def CryogenicFluidPort {
        inout item coolant : CryogenicCoolant;
    }

    port def ThermalPort {
        inout item load : ThermalLoad;
    }

    port def MagneticFieldPort {
        out item field : MagneticField;
    }

    port def ControlPort {
        in item command : ControlCommand;
        out item status : StatusMessage;
    }

    item def ControlCommand {
        attribute targetCurrent : ElectricCurrent;
        attribute targetTemperature : Temperature;
        attribute energizeRequested : Boolean;
        attribute shutdownRequested : Boolean;
    }

    part def SuperconductingTape {
        attribute criticalTemperature : Temperature = 92 [K];
        attribute operatingTemperature : Temperature;
        attribute criticalCurrent : ElectricCurrent = 240 [A];
        attribute transportCurrent : ElectricCurrent;
        attribute residualResistance : Resistance = 0.0 [Ohm];
        attribute tapeLength : Length;
        attribute material : String = "REBCO high-temperature superconducting ceramic";

        port electrical : ElectricalPowerPort;
        port thermal : ThermalPort;

        constraint superconductingCondition {
            operatingTemperature < criticalTemperature;
            transportCurrent <= criticalCurrent;
        }

        constraint zeroResistanceCondition {
            if operatingTemperature < criticalTemperature and transportCurrent <= criticalCurrent then
                residualResistance == 0.0 [Ohm]
            else
                residualResistance > 0.0 [Ohm]
            end
        }
    }

    part def SuperconductingCoil {
        attribute turnCount : Integer;
        attribute boreDiameter : Length;
        attribute targetField : MagneticFluxDensity;
        attribute measuredField : MagneticFluxDensity;
        attribute coilCurrent : ElectricCurrent;
        attribute storedMagneticEnergy : Power;

        port electrical : ElectricalPowerPort;
        port thermal : ThermalPort;
        port magnetic : MagneticFieldPort;

        part tape[1..*] : SuperconductingTape;

        bind coilCurrent = tape.transportCurrent;

        action generateMagneticField {
            in current : ElectricCurrent;
            out field : MagneticField;

            first start;
            then computeFluxDensity;
            then publishField;
            then done;

            action computeFluxDensity {
                field.fluxDensity = targetField;
                field.fieldUniformity = 0.98;
            }

            action publishField;
        }
    }

    part def Cryocooler {
        attribute coolingCapacityAt77K : HeatFlowRate = 150 [W];
        attribute coldHeadTemperature : Temperature;
        attribute compressorPower : Power;
        attribute availability : Ratio;

        port supply : CryogenicFluidPort;
        port return : CryogenicFluidPort;
        port heatLift : ThermalPort;
        port control : ControlPort;

        action removeHeat {
            in thermalLoad : ThermalLoad;
            out coolantOut : CryogenicCoolant;

            first receiveLoad;
            then compressWorkingFluid;
            then expandAtColdHead;
            then absorbHeat;
            then deliverCoolant;
            then done;

            action absorbHeat {
                coolantOut.temperature = coldHeadTemperature;
                coolantOut.phase = CoolantPhase::liquid;
            }
        }
    }

    part def Cryostat {
        attribute vacuumPressure : Pressure = 0.001 [Pa];
        attribute innerShieldTemperature : Temperature = 77 [K];
        attribute heatLeak : HeatFlowRate = 18 [W];
        attribute insulationEfficiency : Ratio = 0.96;

        port coolantIn : CryogenicFluidPort;
        port coolantOut : CryogenicFluidPort;
        port externalThermalBoundary : ThermalPort;
        port protectedThermalBoundary : ThermalPort;

        part radiationShield {
            attribute temperature : Temperature = 77 [K];
            attribute emissivity : Ratio = 0.04;
        }

        part multilayerInsulation {
            attribute layerCount : Integer = 40;
            attribute effectiveConductance : Real = 0.02;
        }

        action isolateColdMass {
            in externalLoad : ThermalLoad;
            out internalLoad : ThermalLoad;

            first interceptRadiation;
            then reduceConduction;
            then transferResidualLoad;
            then done;

            action transferResidualLoad {
                internalLoad.heatFlow = heatLeak;
            }
        }
    }

    part def CurrentLead {
        attribute warmEndTemperature : Temperature = 300 [K];
        attribute coldEndTemperature : Temperature = 77 [K];
        attribute ratedCurrent : ElectricCurrent = 300 [A];
        attribute parasiticHeatLoad : HeatFlowRate = 12 [W];

        port warmElectrical : ElectricalPowerPort;
        port coldElectrical : ElectricalPowerPort;
        port thermal : ThermalPort;
    }

    part def PowerConditioner {
        attribute maximumOutputCurrent : ElectricCurrent = 250 [A];
        attribute outputVoltageLimit : Voltage = 15 [V];
        attribute rampRate : Real = 2.0;
        attribute efficiency : Ratio = 0.94;

        port gridInput : ElectricalPowerPort;
        port coilOutput : ElectricalPowerPort;
        port control : ControlPort;

        action rampCurrent {
            in targetCurrent : ElectricCurrent;
            out deliveredEnergy : ElectricalEnergy;

            first validateTarget;
            then increaseCurrentGradually;
            then regulateVoltage;
            then holdCurrent;
            then done;

            action validateTarget {
                assert targetCurrent <= maximumOutputCurrent;
            }

            action holdCurrent {
                deliveredEnergy.current = targetCurrent;
            }
        }
    }

    part def QuenchProtectionUnit {
        attribute voltageThreshold : Voltage = 0.05 [V];
        attribute temperatureThreshold : Temperature = 88 [K];
        attribute dumpResistance : Resistance = 0.5 [Ohm];
        attribute detectionLatency : Real = 0.010;

        port monitoredElectrical : ElectricalPowerPort;
        port monitoredThermal : ThermalPort;
        port control : ControlPort;

        action detectQuench {
            in sensedVoltage : Voltage;
            in sensedTemperature : Temperature;
            out quenchDetected : Boolean;

            first sampleSensors;
            then evaluateCriteria;
            then reportResult;
            then done;

            action evaluateCriteria {
                quenchDetected =
                    sensedVoltage > voltageThreshold or
                    sensedTemperature > temperatureThreshold;
            }
        }

        action dischargeCoil {
            in coilEnergy : ElectricalEnergy;
            out dissipatedHeat : ThermalLoad;

            first openPersistentSwitch;
            then routeCurrentToDumpResistor;
            then dissipateStoredEnergy;
            then done;

            action dissipateStoredEnergy {
                dissipatedHeat.heatFlow = coilEnergy.power;
            }
        }
    }

    part def ThermalSensor {
        attribute measuredTemperature : Temperature;
        attribute accuracy : Temperature = 0.1 [K];
        attribute samplePeriod : Real = 0.1;

        port thermalContact : ThermalPort;
        port signal : ControlPort;
    }

    part def HallSensor {
        attribute measuredFluxDensity : MagneticFluxDensity;
        attribute accuracy : MagneticFluxDensity = 0.002 [T];

        port fieldInput : MagneticFieldPort;
        port signal : ControlPort;
    }

    part def SupervisoryController {
        attribute targetOperatingTemperature : Temperature = 77 [K];
        attribute targetOperatingCurrent : ElectricCurrent = 200 [A];
        attribute targetMagneticField : MagneticFluxDensity = 3.0 [T];
        attribute systemReady : Boolean;
        attribute quenchAlarm : Boolean;

        port operatorInterface : ControlPort;
        port powerControl : ControlPort;
        port cryogenicControl : ControlPort;
        port protectionControl : ControlPort;
        port sensorInput : ControlPort;

        state machine operatingState {
            state Off;
            state PreCooling;
            state SuperconductingReady;
            state Energizing;
            state FieldStable;
            state QuenchDetected;
            state ProtectedDischarge;
            state WarmShutdown;

            initial then Off;

            transition Off_to_PreCooling
                first Off
                accept ControlCommand
                if command.energizeRequested
                then PreCooling;

            transition PreCooling_to_Ready
                first PreCooling
                if targetOperatingTemperature <= 80 [K]
                then SuperconductingReady;

            transition Ready_to_Energizing
                first SuperconductingReady
                accept ControlCommand
                if command.targetCurrent > 0 [A]
                then Energizing;

            transition Energizing_to_FieldStable
                first Energizing
                if targetOperatingCurrent == command.targetCurrent
                then FieldStable;

            transition Any_to_QuenchDetected
                first FieldStable
                if quenchAlarm
                then QuenchDetected;

            transition QuenchDetected_to_ProtectedDischarge
                first QuenchDetected
                then ProtectedDischarge;

            transition ProtectedDischarge_to_WarmShutdown
                first ProtectedDischarge
                if targetOperatingCurrent == 0 [A]
                then WarmShutdown;

            transition WarmShutdown_to_Off
                first WarmShutdown
                accept ControlCommand
                if command.shutdownRequested
                then Off;
        }

        action coordinateOperation {
            in operatorCommand : ControlCommand;
            out powerCommand : ControlCommand;
            out cryogenicCommand : ControlCommand;
            out protectionCommand : ControlCommand;

            first readOperatorCommand;
            then requestCooling;
            then verifySuperconductingMargin;
            then requestPowerRamp;
            then monitorProtection;
            then done;

            action verifySuperconductingMargin {
                assert targetOperatingTemperature < 92 [K];
                assert targetOperatingCurrent <= 240 [A];
            }

            action requestPowerRamp {
                powerCommand.targetCurrent = operatorCommand.targetCurrent;
                powerCommand.energizeRequested = operatorCommand.energizeRequested;
            }
        }
    }

    part def HighTemperatureSuperconductingMagnetSystem {
        attribute primaryFunction : String =
            "Provide a stable, high magnetic field with near-zero resistive electrical loss by maintaining high-temperature superconducting coils below their critical temperature.";
        attribute nominalOperatingTemperature : Temperature = 77 [K];
        attribute nominalCurrent : ElectricCurrent = 200 [A];
        attribute nominalField : MagneticFluxDensity = 3.0 [T];
        attribute maximumAllowedTemperature : Temperature = 88 [K];
        attribute fieldAvailability : Ratio = 0.995;

        port utilityPower : ElectricalPowerPort;
        port operatorControl : ControlPort;
        port magneticFieldOutput : MagneticFieldPort;
        port ambientThermalInterface : ThermalPort;

        part controller : SupervisoryController;
        part powerConditioner : PowerConditioner;
        part warmCurrentLeadA : CurrentLead;
        part warmCurrentLeadB : CurrentLead;
        part cryocooler : Cryocooler;
        part cryostat : Cryostat;
        part coil : SuperconductingCoil {
            attribute turnCount = 420;
            attribute boreDiameter = 0.25 [m];
            attribute targetField = 3.0 [T];
            attribute coilCurrent = 200 [A];
        }
        part quenchProtection : QuenchProtectionUnit;
        part coilTemperatureSensor : ThermalSensor;
        part coldHeadTemperatureSensor : ThermalSensor;
        part fieldSensor : HallSensor;

        connection utilityToPower
            connect utilityPower to powerConditioner.gridInput;

        connection powerToLeadA
            connect powerConditioner.coilOutput to warmCurrentLeadA.warmElectrical;

        connection leadAToCoil
            connect warmCurrentLeadA.coldElectrical to coil.electrical;

        connection coilToLeadB
            connect coil.electrical to warmCurrentLeadB.coldElectrical;

        connection coilThermalToCryostat
            connect coil.thermal to cryostat.protectedThermalBoundary;

        connection cryostatToCryocoolerSupply
            connect cryocooler.supply to cryostat.coolantIn;

        connection cryostatToCryocoolerReturn
            connect cryostat.coolantOut to cryocooler.return;

        connection ambientToCryostat
            connect ambientThermalInterface to cryostat.externalThermalBoundary;

        connection cryocoolerHeatLift
            connect cryocooler.heatLift to cryostat.protectedThermalBoundary;

        connection coilToProtectionElectrical
            connect coil.electrical to quenchProtection.monitoredElectrical;

        connection coilToProtectionThermal
            connect coil.thermal to quenchProtection.monitoredThermal;

        connection coilToTemperatureSensor
            connect coil.thermal to coilTemperatureSensor.thermalContact;

        connection cryocoolerToTemperatureSensor
            connect cryocooler.heatLift to coldHeadTemperatureSensor.thermalContact;

        connection coilFieldToOutput
            connect coil.magnetic to magneticFieldOutput;

        connection coilFieldToSensor
            connect coil.magnetic to fieldSensor.fieldInput;

        connection operatorToController
            connect operatorControl to controller.operatorInterface;

        connection controllerToPower
            connect controller.powerControl to powerConditioner.control;

        connection controllerToCryogenic
            connect controller.cryogenicControl to cryocooler.control;

        connection controllerToProtection
            connect controller.protectionControl to quenchProtection.control;

        connection sensorsToController
            connect coilTemperatureSensor.signal to controller.sensorInput;

        requirement def PrimaryFunctionRequirement {
            doc /* The system shall generate and maintain a stable high magnetic field using high-temperature superconductivity as the enabling physical phenomenon. */
            subject system : HighTemperatureSuperconductingMagnetSystem;

            require constraint {
                system.nominalOperatingTemperature < 92 [K] and
                system.nominalCurrent <= 240 [A] and
                system.nominalField >= 3.0 [T]
            }
        }

        requirement def CryogenicOperatingRequirement {
            doc /* The cryogenic subsystem shall maintain the superconducting coil below the maximum allowed temperature during steady field operation. */
            subject system : HighTemperatureSuperconductingMagnetSystem;

            require constraint {
                system.nominalOperatingTemperature <= system.maximumAllowedTemperature
            }
        }

        requirement def LowLossTransmissionRequirement {
            doc /* The superconducting coil shall carry nominal operating current with zero modeled residual resistance while below critical temperature. */
            subject tape : SuperconductingTape;

            require constraint {
                tape.operatingTemperature < tape.criticalTemperature and
                tape.transportCurrent <= tape.criticalCurrent and
                tape.residualResistance == 0.0 [Ohm]
            }
        }

        requirement def QuenchProtectionRequirement {
            doc /* The protection subsystem shall detect loss of superconductivity and command protected discharge before thermal damage occurs. */
            subject protection : QuenchProtectionUnit;

            require constraint {
                protection.detectionLatency <= 0.020
            }
        }

        satisfy PrimaryFunctionRequirement by coil;
        satisfy CryogenicOperatingRequirement by cryocooler;
        satisfy LowLossTransmissionRequirement by coil.tape;
        satisfy QuenchProtectionRequirement by quenchProtection;

        action performPrimaryFunction {
            in command : ControlCommand;
            out deliveredField : MagneticField;
            out status : StatusMessage;

            first acceptCommand;
            then coolSuperconductingCoil;
            then verifyCriticalMargin;
            then rampCoilCurrent;
            then generateStableMagneticField;
            then monitorForQuench;
            then maintainField;
            then done;

            action coolSuperconductingCoil {
                assert nominalOperatingTemperature < 92 [K];
            }

            action verifyCriticalMargin {
                assert nominalOperatingTemperature <= maximumAllowedTemperature;
                assert nominalCurrent <= 240 [A];
            }

            action rampCoilCurrent {
                nominalCurrent = command.targetCurrent;
            }

            action generateStableMagneticField {
                deliveredField.fluxDensity = nominalField;
                deliveredField.fieldUniformity = 0.98;
            }

            action monitorForQuench {
                status.severity = SeverityLevel::nominal;
                status.code = 0;
                status.description = "Superconducting field generation stable";
            }
        }
    }

    part htsMagnetSystem : HighTemperatureSuperconductingMagnetSystem;

}