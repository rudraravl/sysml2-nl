package PiraniGaugeSystem {
    public import ISQ::*;
    public import ScalarValues::*;

    attribute def Pressure :> Real { unit 'Pa'; }
    attribute def Voltage :> Real { unit 'V'; }
    attribute def Resistance :> Real { unit 'ohm'; }
    attribute def Current :> Real { unit 'A'; }
    attribute def Temperature :> Real { unit 'K'; }
    attribute def Power :> Real { unit 'W'; }
    attribute def Frequency :> Real { unit 'Hz'; }

    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
    }

    item def RawVoltageSignal {
        attribute value : Voltage;
    }

    item def ProcessedPressureSignal {
        attribute pressure : Pressure;
        attribute timestamp : Real;
    }

    item def DisplayData {
        attribute pressure : Pressure;
        attribute unitString : String;
    }

    item def CalibrationData {
        attribute coefficients : Array[0..*] of Real;
        attribute validRangeMin : Pressure;
        attribute validRangeMax : Pressure;
    }

    port def ElectricalPowerPort {
        out item power : ElectricalPower;
    }

    port def RawSignalPort {
        out item signal : RawVoltageSignal;
    }

    port def ProcessedSignalPort {
        out item signal : ProcessedPressureSignal;
    }

    port def DisplayPort {
        out item data : DisplayData;
    }

    port def VacuumInterfacePort {
        attribute flangeType : String;
    }

    part def PowerSupplyUnit {
        attribute outputVoltage : Voltage = 5.0;
        attribute maxCurrent : Current = 2.0;
        attribute regulationTolerance : Voltage = 0.01;

        port powerOut : ElectricalPowerPort;

        attribute suppliedPower : ElectricalPower;

        action def generatePower() {
            out power : ElectricalPower;
        }

        perform generatePower() {
            power := ElectricalPower { voltage = outputVoltage, current = maxCurrent };
        }
    }

    part def SensingFilament {
        attribute nominalResistance : Resistance = 100.0;
        attribute operatingTemperature : Temperature = 400.0;
        attribute temperatureCoefficient : Real = 0.0036;
        attribute currentResistance : Resistance;
        attribute currentTemperature : Temperature;
        attribute isBroken : Boolean = false;

        port powerIn : ElectricalPowerPort;
        port resistanceOut : RawSignalPort;

        action def heatUp() {
            in targetTemp : Temperature;
            out finalResistance : Resistance;
        }

        action def senseHeatLoss() {
            in ambientPressure : Pressure;
            out resistanceChange : Resistance;
        }

        perform heatUp() {
            currentTemperature := operatingTemperature;
            currentResistance := nominalResistance * (1.0 + temperatureCoefficient * (currentTemperature - 293.15));
            finalResistance := currentResistance;
        }

        perform senseHeatLoss() {
            // Higher pressure => more heat loss => lower resistance
            attribute heatLossFactor : Real = 0.001;
            currentResistance := nominalResistance * (1.0 + temperatureCoefficient * (currentTemperature - 293.15)) * (1.0 - heatLossFactor * ambientPressure / 100.0);
            resistanceChange := currentResistance;
        }
    }

    part def BridgeCircuit {
        attribute referenceResistance : Resistance = 100.0;
        attribute bridgeVoltage : Voltage = 5.0;
        attribute outputSignal : Voltage;

        port filamentInput : RawSignalPort;
        port rawOutput : RawSignalPort;

        action def balanceBridge() {
            in measuredResistance : Resistance;
            out outputVoltage : Voltage;
        }

        perform balanceBridge() {
            outputSignal := bridgeVoltage * (measuredResistance - referenceResistance) / (measuredResistance + referenceResistance);
            outputVoltage := outputSignal;
        }
    }

    part def SignalConditioner {
        attribute gain : Real = 100.0;
        attribute offset : Voltage = 0.0;
        attribute calibration : CalibrationData;
        attribute linearizedPressure : Pressure;

        port rawInput : RawSignalPort;
        port processedOutput : ProcessedSignalPort;

        action def amplify() {
            in rawSignal : Voltage;
            out amplified : Voltage;
        }

        action def linearize() {
            in amplified : Voltage;
            out pressure : Pressure;
        }

        perform amplify() {
            amplified := gain * rawSignal + offset;
        }

        perform linearize() {
            // Apply calibration polynomial: p = c0 + c1*v + c2*v^2 + ...
            attribute v : Voltage = amplified;
            attribute result : Pressure = 0.0;
            for i in 0..calibration.coefficients.size {
                result := result + calibration.coefficients[i] * v ^ i;
            }
            linearizedPressure := result;
            pressure := result;
        }
    }

    part def VacuumChamberInterface {
        attribute flangeType : String = "KF25";
        attribute sealIntegrity : Boolean = true;

        port vacuumPort : VacuumInterfacePort {
            attribute flangeType = "KF25";
        }

        action def connectToChamber() {
            out sealed : Boolean;
        }

        perform connectToChamber() {
            sealed := sealIntegrity;
        }
    }

    part def DisplayController {
        attribute updateRate : Frequency = 10.0;
        attribute displayUnit : String = "mbar";
        attribute currentDisplay : DisplayData;

        port signalInput : ProcessedSignalPort;
        port displayOut : DisplayPort;

        action def updateDisplay() {
            in pressure : Pressure;
            out data : DisplayData;
        }

        perform updateDisplay() {
            currentDisplay := DisplayData { pressure = pressure, unitString = displayUnit };
            data := currentDisplay;
        }
    }

    part def PiraniGauge {
        attribute systemStatus : String;
        attribute warmupDuration : Real = 30.0;

        port vacuumConnection : VacuumInterfacePort;
        port displayInterface : DisplayPort;

        part powerSupply : PowerSupplyUnit {
            port powerOut : ElectricalPowerPort;
        }

        part filament : SensingFilament {
            port powerIn : ElectricalPowerPort;
            port resistanceOut : RawSignalPort;
        }

        part bridge : BridgeCircuit {
            port filamentInput : RawSignalPort;
            port rawOutput : RawSignalPort;
        }

        part conditioner : SignalConditioner {
            port rawInput : RawSignalPort;
            port processedOutput : ProcessedSignalPort;
        }

        part vacuumInterface : VacuumChamberInterface {
            port vacuumPort : VacuumInterfacePort;
        }

        part display : DisplayController {
            port signalInput : ProcessedSignalPort;
            port displayOut : DisplayPort;
        }

        connection powerSupplyToFilament connect powerSupply.powerOut to filament.powerIn {
            item power : ElectricalPower;
        }

        connection filamentToBridge connect filament.resistanceOut to bridge.filamentInput {
            item signal : RawVoltageSignal;
        }

        connection bridgeToConditioner connect bridge.rawOutput to conditioner.rawInput {
            item signal : RawVoltageSignal;
        }

        connection conditionerToDisplay connect conditioner.processedOutput to display.signalInput {
            item signal : ProcessedPressureSignal;
        }

        connection vacuumInterfaceToPort connect vacuumInterface.vacuumPort to vacuumConnection;

        connection displayToPort connect display.displayOut to displayInterface;

        state def GaugeStateMachine {
            entry action {
                systemStatus := "initializing";
            }

            state off {
                entry action {
                    systemStatus := "off";
                }
            }

            state warmup {
                entry action {
                    systemStatus := "warmup";
                    filament.perform heatUp(targetTemp = filament.operatingTemperature);
                }
                exit action {
                    systemStatus := "ready";
                }
            }

            state measuring {
                entry action {
                    systemStatus := "measuring";
                }
                do action measureCycle {
                    // Continuous measurement loop
                    filament.perform senseHeatLoss(ambientPressure = 0.0);
                    bridge.perform balanceBridge(measuredResistance = filament.currentResistance);
                    conditioner.perform amplify(rawSignal = bridge.outputSignal);
                    conditioner.perform linearize(amplified = conditioner.gain * bridge.outputSignal);
                    display.perform updateDisplay(pressure = conditioner.linearizedPressure);
                }
            }

            state error {
                entry action {
                    systemStatus := "error";
                }
            }

            transition off_to_warmup
                from off to warmup
                when powerSupply.suppliedPower.voltage > 0.0;

            transition warmup_to_measuring
                from warmup to measuring
                when filament.currentTemperature >= filament.operatingTemperature * 0.95;

            transition measuring_to_error
                from measuring to error
                when filament.isBroken;

            transition warmup_to_error
                from warmup to error
                when filament.isBroken;

            transition error_to_off
                from error to off
                when !powerSupply.suppliedPower.voltage > 0.0;
        }

        exhibit GaugeStateMachine;
    }

    requirement def PressureMeasurementRequirement {
        subject gauge : PiraniGauge;
        attribute measurementRangeMin : Pressure = 1e-4;
        attribute measurementRangeMax : Pressure = 1e5;
        attribute accuracyPercent : Real = 5.0;
        attribute responseTime : Real = 1.0;

        requirement {
            subject gauge;
            doc /* The gauge shall measure pressure within the specified range with stated accuracy. */
            assert gauge.conditioner.linearizedPressure >= measurementRangeMin
                and gauge.conditioner.linearizedPressure <= measurementRangeMax;
        }
    }

    requirement def WarmupRequirement {
        subject gauge : PiraniGauge;
        attribute maxWarmupTime : Real = 60.0;

        requirement {
            subject gauge;
            doc /* The gauge shall complete warmup within the specified time. */
            assert gauge.warmupDuration <= maxWarmupTime;
        }
    }

    requirement def DisplayUpdateRequirement {
        subject gauge : PiraniGauge;
        attribute minUpdateRate : Frequency = 2.0;

        requirement {
            subject gauge;
            doc /* The display shall update at least at the minimum specified rate. */
            assert gauge.display.updateRate >= minUpdateRate;
        }
    }

    requirement def VacuumInterfaceRequirement {
        subject gauge : PiraniGauge;
        attribute requiredFlange : String = "KF25";

        requirement {
            subject gauge;
            doc /* The gauge shall provide a standardized vacuum interface flange. */
            assert gauge.vacuumInterface.flangeType == requiredFlange;
        }
    }

    requirement def FilamentIntegrityRequirement {
        subject gauge : PiraniGauge;

        requirement {
            subject gauge;
            doc /* The system shall detect filament breakage and enter error state. */
            assert gauge.filament.isBroken implies gauge.systemStatus == "error";
        }
    }

    part def PiraniGaugeSystemAssembly {
        part gauge : PiraniGauge;

        satisfy PressureMeasurementRequirement by gauge;
        satisfy WarmupRequirement by gauge;
        satisfy DisplayUpdateRequirement by gauge;
        satisfy VacuumInterfaceRequirement by gauge;
        satisfy FilamentIntegrityRequirement by gauge;
    }
}
