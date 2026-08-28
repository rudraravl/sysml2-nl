package HeatPenModel {

    import ScalarValues::*;
    import ISQ::*;

    // ---- Value types with units ----
    value def Voltage :> Real { unit 'V'; }
    value def Current :> Real { unit 'A'; }
    value def Power :> Real { unit 'W'; }
    value def Temperature :> Real { unit 'degC'; }
    value def Pressure :> Real { unit 'N'; }
    value def TemperatureSetpoint :> Temperature;
    value def PressureThreshold :> Pressure;

    // ---- Item definitions ----
    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
    }
    item def ThermalEnergy;
    item def MainsPower :> ElectricalPower {
        attribute voltage : Voltage = 230 [V];
    }
    item def LowVoltagePower :> ElectricalPower {
        attribute voltage : Voltage = 24 [V];
    }
    item def ControlSignal;
    item def PressureReading {
        attribute value : Pressure;
    }
    item def TemperatureReading {
        attribute value : Temperature;
    }
    item def UserCommand {
        attribute targetTemp : TemperatureSetpoint;
        attribute mode : String;
    }
    item def DisplayInfo {
        attribute currentTemp : Temperature;
        attribute state : String;
    }

    // ---- Enumerations ----
    enum def OperationalState {
        standby;
        preheating;
        operational;
        cooldown;
        fault;
    }

    enum def FaultType {
        none;
        overTemperature;
        sensorFailure;
        powerFault;
    }

    // ---- Port definitions ----
    port def PowerPort {
        out power : ElectricalPower;
    }
    port def MainsPort :> PowerPort {
        out power : MainsPower;
    }
    port def LowVoltagePort :> PowerPort {
        out power : LowVoltagePower;
    }
    port def ControlPort {
        in signal : ControlSignal;
        out signal : ControlSignal;
    }
    port def PressurePort {
        out reading : PressureReading;
    }
    port def TemperaturePort {
        out reading : TemperatureReading;
    }
    port def ThermalPort {
        out heat : ThermalEnergy;
    }
    port def UIPort {
        in command : UserCommand;
        out display : DisplayInfo;
    }

    // ---- Component definitions ----

    part def PowerSupplyUnit {
        attribute ratedInputVoltage : Voltage = 230 [V];
        attribute ratedOutputVoltage : Voltage = 24 [V];
        attribute maxOutputPower : Power = 60 [W];

        port mainsIn : MainsPort;
        port powerOut : LowVoltagePort;

        action def convertPower {
            in mains : MainsPower;
            out low : LowVoltagePower;
        }

        perform convertPower {
            in mains = mainsIn.power;
            out low = powerOut.power;
        }
    }

    part def HeatingElement {
        attribute maxTemperature : Temperature = 450 [degC];
        attribute resistance : Real = 8.0; // ohms

        port powerIn : LowVoltagePort;
        port tempOut : TemperaturePort;
        port heatOut : ThermalPort;

        attribute currentTemp : Temperature = 25 [degC];

        action def generateHeat {
            in power : LowVoltagePower;
            out heat : ThermalEnergy;
            out temp : TemperatureReading;
        }

        perform generateHeat {
            in power = powerIn.power;
            out heat = heatOut.heat;
            out temp = tempOut.reading;
        }
    }

    part def TipModule {
        attribute material : String = "Copper-Iron Alloy";
        attribute thermalConductivity : Real = 385; // W/(m·K)
        attribute shape : String = "Precision Conical";
        attribute maxTemp : Temperature = 450 [degC];

        port heatIn : ThermalPort;
        port contactPort : PressurePort;

        attribute appliedPressure : Pressure = 0 [N];

        action def conductHeat {
            in heat : ThermalEnergy;
            in pressure : Pressure;
        }

        perform conductHeat {
            in heat = heatIn.heat;
            in pressure = appliedPressure;
        }
    }

    part def PressureSensor {
        attribute threshold : PressureThreshold = 1.5 [N];

        port pressureOut : PressurePort;

        attribute detectedPressure : Pressure = 0 [N];

        action def sensePressure {
            in physicalPressure : Pressure;
            out reading : PressureReading;
        }

        perform sensePressure {
            in physicalPressure = detectedPressure;
            out reading = pressureOut.reading;
        }
    }

    part def TemperatureSensor {
        attribute accuracy : Real = 0.5; // degC tolerance

        port tempOut : TemperaturePort;

        attribute measuredTemp : Temperature = 25 [degC];

        action def measureTemperature {
            in actualTemp : Temperature;
            out reading : TemperatureReading;
        }

        perform measureTemperature {
            in actualTemp = measuredTemp;
            out reading = tempOut.reading;
        }
    }

    part def UserInterfacePanel {
        attribute supportedModes : String[*] = ["soldering", "crafting", "thermalBonding"];
        attribute defaultTemp : TemperatureSetpoint = 320 [degC];

        port uiPort : UIPort;

        action def acceptUserInput {
            out command : UserCommand;
        }

        action def updateDisplay {
            in info : DisplayInfo;
        }

        perform acceptUserInput {
            out command = uiPort.command;
        }

        perform updateDisplay {
            in info = uiPort.display;
        }
    }

    part def ControllerModule {
        attribute targetTemperature : TemperatureSetpoint = 320 [degC];
        attribute currentMode : String = "soldering";
        attribute overTempLimit : Temperature = 460 [degC];
        attribute currentFault : FaultType = FaultType::none;

        port powerIn : LowVoltagePort;
        port pressureIn : PressurePort;
        port tempIn : TemperaturePort;
        port controlOut : ControlPort;
        port uiPort : UIPort;

        attribute currentState : OperationalState = OperationalState::standby;

        // Closed-loop control action
        action def regulateTemperature {
            in target : TemperatureSetpoint;
            in measured : TemperatureReading;
            out control : ControlSignal;
        }

        perform regulateTemperature {
            in target = targetTemperature;
            in measured = tempIn.reading;
            out control = controlOut.signal;
        }

        // State machine for operational behavior
        state def ControllerStateMachine {
            entry; then standby;

            state standby {
                entry {
                    currentState = OperationalState::standby;
                }
            }

            state preheating {
                entry {
                    currentState = OperationalState::preheating;
                }
                do regulateTemperature;
            }

            state operational {
                entry {
                    currentState = OperationalState::operational;
                }
                do regulateTemperature;
            }

            state cooldown {
                entry {
                    currentState = OperationalState::cooldown;
                }
            }

            state fault {
                entry {
                    currentState = OperationalState::fault;
                    currentFault = FaultType::overTemperature;
                }
            }

            transition standby_to_preheating
                first standby then preheating
                if pressureIn.reading.value > 1.5 [N];

            transition preheating_to_operational
                first preheating then operational
                if tempIn.reading.value >= targetTemperature;

            transition operational_to_cooldown
                first operational then cooldown
                if pressureIn.reading.value < 1.5 [N];

            transition preheating_to_cooldown
                first preheating then cooldown
                if pressureIn.reading.value < 1.5 [N];

            transition cooldown_to_standby
                first cooldown then standby
                if tempIn.reading.value <= 40 [degC];

            transition any_to_fault
                first standby, preheating, operational, cooldown then fault
                if tempIn.reading.value > overTempLimit;

            transition fault_to_standby
                first fault then standby
                if tempIn.reading.value <= 40 [degC] and currentFault == FaultType::none;
        }

        exhibit ControllerStateMachine;
    }

    // ---- Top-level Heat Pen assembly ----
    part def HeatPen {
        attribute deviceName : String = "Precision Heat Pen";
        attribute serialNumber : String;

        part controller : ControllerModule;
        part powerSupply : PowerSupplyUnit;
        part heatingElement : HeatingElement;
        part tip : TipModule;
        part pressureSensor : PressureSensor;
        part temperatureSensor : TemperatureSensor;
        part uiPanel : UserInterfacePanel;

        // External interface ports
        port mainsInput : MainsPort;
        port workSurfaceContact : PressurePort;

        // Connections
        connection mainsPowerFlow connect mainsInput to powerSupply.mainsIn;
        connection lowVoltageToController connect powerSupply.powerOut to controller.powerIn;
        connection lowVoltageToHeater connect powerSupply.powerOut to heatingElement.powerIn;
        connection controlToHeater connect controller.controlOut to heatingElement.powerIn {
            // Control signal modulates heater power
        }
        connection thermalFlow connect heatingElement.heatOut to tip.heatIn;
        connection pressureFromTip connect tip.contactPort to pressureSensor.pressureOut {
            // Tip pressure sensed by sensor
        }
        connection pressureToController connect pressureSensor.pressureOut to controller.pressureIn;
        connection tempFromHeater connect heatingElement.tempOut to controller.tempIn;
        connection tempFromSensor connect temperatureSensor.tempOut to controller.tempIn;
        connection uiToController connect uiPanel.uiPort to controller.uiPort;
        connection workSurfacePressure connect workSurfaceContact to tip.contactPort;
    }

    // ---- Requirements ----
    package Requirements {

        requirement def SafetyRequirement {
            doc /*
                The Heat Pen shall only generate heat when the tip is pressed
                against a work surface, ensuring safe operation during idle periods.
            */
            attribute pressureThreshold : PressureThreshold = 1.5 [N];
            subject heatPen : HeatPen;
            predicate {
                heatPen.controller.currentState == OperationalState::operational
                implies heatPen.controller.pressureIn.reading.value > pressureThreshold
            }
        }

        requirement def TemperatureControlRequirement {
            doc /*
                The Controller shall maintain tip temperature within ±2 degC of
                the user-selected setpoint during operational state.
            */
            attribute tolerance : Real = 2.0;
            subject heatPen : HeatPen;
            predicate {
                heatPen.controller.currentState == OperationalState::operational
                implies abs(heatPen.controller.tempIn.reading.value
                    - heatPen.controller.targetTemperature) <= tolerance
            }
        }

        requirement def OverTemperatureProtectionRequirement {
            doc /*
                The Heat Pen shall enter the fault state if the heating element
                temperature exceeds 460 degC, ceasing heat generation.
            */
            attribute limit : Temperature = 460 [degC];
            subject heatPen : HeatPen;
            predicate {
                heatPen.heatingElement.tempOut.reading.value > limit
                implies heatPen.controller.currentState == OperationalState::fault
            }
        }

        requirement def PowerConversionRequirement {
            doc /*
                The Power Supply Unit shall convert 230V mains input to a safe
                24V low operating voltage for all internal components.
            */
            subject psu : PowerSupplyUnit;
            predicate {
                psu.mainsIn.power.voltage == 230 [V]
                and psu.powerOut.power.voltage == 24 [V]
            }
        }

        requirement def CooldownRequirement {
            doc /*
                Upon release of tip pressure, the Heat Pen shall cease active
                heating and enter cooldown, returning to standby when the
                temperature falls below 40 degC.
            */
            subject heatPen : HeatPen;
            predicate {
                heatPen.controller.pressureIn.reading.value < 1.5 [N]
                implies heatPen.controller.currentState == OperationalState::cooldown
            }
        }

        requirement def UserInterfaceRequirement {
            doc /*
                The User Interface Panel shall allow the operator to select
                operating mode and adjust target temperature, and shall display
                current temperature and operational state.
            */
            subject ui : UserInterfacePanel;
            predicate {
                ui.uiPort.command.targetTemp > 50 [degC]
                and ui.uiPort.command.targetTemp < 450 [degC]
            }
        }

        requirement def TipMaterialRequirement {
            doc /*
                The Tip Module shall be constructed from a thermally conductive
                copper-iron alloy shaped for precision work.
            */
            subject tip : TipModule;
            predicate {
                tip.material == "Copper-Iron Alloy"
                and tip.thermalConductivity >= 300
            }
        }

        // Requirement satisfaction
        satisfaction safetySatisfies by HeatPen satisfy SafetyRequirement;
        satisfaction tempControlSatisfies by HeatPen satisfy TemperatureControlRequirement;
        satisfaction overTempSatisfies by HeatPen satisfy OverTemperatureProtectionRequirement;
        satisfaction powerConvSatisfies by HeatPen.powerSupply satisfy PowerConversionRequirement;
        satisfaction cooldownSatisfies by HeatPen satisfy CooldownRequirement;
        satisfaction uiSatisfies by HeatPen.uiPanel satisfy UserInterfaceRequirement;
        satisfaction tipMatSatisfies by HeatPen.tip satisfy TipMaterialRequirement;
    }
}
