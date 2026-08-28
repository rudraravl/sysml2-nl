package LiquidRingPumpingSystem {

    // ---- Value Types with Units ----
    package Units {
        attribute def PressureUnit :> SI::Pascal;
        attribute def TemperatureUnit :> SI::Kelvin;
        attribute def FlowRateUnit :> SI::CubicMeterPerSecond;
        attribute def LevelUnit :> SI::Meter;
        attribute def PowerUnit :> SI::Watt;
        attribute def RotationalSpeedUnit :> SI::RadianPerSecond;
        attribute def VolumeUnit :> SI::CubicMeter;
    }

    attribute def PressureValue :> Real {
        unit Units::PressureUnit;
    }
    attribute def TemperatureValue :> Real {
        unit Units::TemperatureUnit;
    }
    attribute def FlowRateValue :> Real {
        unit Units::FlowRateUnit;
    }
    attribute def LevelValue :> Real {
        unit Units::LevelUnit;
    }
    attribute def PowerValue :> Real {
        unit Units::PowerUnit;
    }
    attribute def RotationalSpeedValue :> Real {
        unit Units::RotationalSpeedUnit;
    }
    attribute def VolumeValue :> Real {
        unit Units::VolumeUnit;
    }

    // ---- Item Types ----
    item def ProcessGas;
    item def SealingLiquid;
    item def GasLiquidMixture {
        ref part gas : ProcessGas[0..*];
        ref part liquid : SealingLiquid[0..*];
    }
    item def CoolingMedium;

    // ---- Port Definitions ----
    port def GasInPort {
        in item gas : ProcessGas;
    }
    port def GasOutPort {
        out item gas : ProcessGas;
    }
    port def LiquidInPort {
        in item liquid : SealingLiquid;
    }
    port def LiquidOutPort {
        out item liquid : SealingLiquid;
    }
    port def MixtureInPort {
        in item mixture : GasLiquidMixture;
    }
    port def MixtureOutPort {
        out item mixture : GasLiquidMixture;
    }
    port def CoolingInPort {
        in item coolant : CoolingMedium;
    }
    port def CoolingOutPort {
        out item coolant : CoolingMedium;
    }
    port def ElectricalPowerPort {
        in attribute power : PowerValue;
    }
    port def SignalPort {
        in attribute measuredValue : Real;
        out attribute command : Real;
    }

    // ---- Sensor Definitions ----
    part def PressureTransmitter {
        port out signal : SignalPort;
        attribute measuredPressure : PressureValue;
    }
    part def TemperatureTransmitter {
        port out signal : SignalPort;
        attribute measuredTemperature : TemperatureValue;
    }
    part def FlowTransmitter {
        port out signal : SignalPort;
        attribute measuredFlow : FlowRateValue;
    }
    part def LevelTransmitter {
        port out signal : SignalPort;
        attribute measuredLevel : LevelValue;
    }

    // ---- Source and Discharge ----
    part def SourceVessel {
        port out gasOut : GasOutPort;
        attribute internalPressure : PressureValue = 101325 [Pa];
        attribute volume : VolumeValue = 5.0 [m^3];
    }
    part def DischargeReceiver {
        port in gasIn : GasInPort;
        attribute internalPressure : PressureValue = 300000 [Pa];
        attribute volume : VolumeValue = 10.0 [m^3];
    }

    // ---- Liquid Ring Pump ----
    part def LiquidRingPump {
        port in gasInlet : GasInPort;
        port in liquidInlet : LiquidInPort;
        port out mixtureOutlet : MixtureOutPort;
        port in powerIn : ElectricalPowerPort;
        port out speedSignal : SignalPort;

        attribute nominalSpeed : RotationalSpeedValue = 150.0 [rad/s];
        attribute ratedPower : PowerValue = 15000.0 [W];
        attribute currentSpeed : RotationalSpeedValue;
        attribute inletPressure : PressureValue;
        attribute outletPressure : PressureValue;
        attribute casingTemperature : TemperatureValue;

        part impeller {
            attribute speed : RotationalSpeedValue;
        }
        part sealingLiquidChamber {
            ref item liquid : SealingLiquid;
        }

        state def PumpOperatingStates {
            entry; then Stopped;
            state Stopped {
                entry action { currentSpeed = 0.0 [rad/s]; }
            }
            state Starting {
                entry action { currentSpeed = 0.1 * nominalSpeed; }
                do action { currentSpeed = currentSpeed + 5.0 [rad/s]; }
            }
            state Priming {
                entry action { sealingLiquidChamber.liquid.supply(); }
            }
            state Running {
                entry action { currentSpeed = nominalSpeed; }
            }
            state HighTemperatureProtection {
                entry action { currentSpeed = 0.5 * nominalSpeed; }
            }
            state CavitationProtection {
                entry action { currentSpeed = 0.3 * nominalSpeed; }
            }
            state EmergencyShutdown {
                entry action { currentSpeed = 0.0 [rad/s]; }
            }
            transition from Stopped to Starting when powerIn.power > 0.0 [W];
            transition from Starting to Priming when currentSpeed >= 0.5 * nominalSpeed;
            transition from Priming to Running when sealingLiquidChamber.liquid.isAvailable;
            transition from Running to HighTemperatureProtection when casingTemperature > 350.0 [K];
            transition from HighTemperatureProtection to Running when casingTemperature < 330.0 [K];
            transition from Running to CavitationProtection when inletPressure < 80000.0 [Pa];
            transition from CavitationProtection to Running when inletPressure > 90000.0 [Pa];
            transition from any to EmergencyShutdown when emergencyStopTriggered;
            transition from EmergencyShutdown to Stopped when resetCommanded;
        }
        attribute emergencyStopTriggered : Boolean = false;
        attribute resetCommanded : Boolean = false;
        exhibit PumpOperatingStates;
    }

    // ---- Separator ----
    part def Separator {
        port in mixtureIn : MixtureInPort;
        port out gasOut : GasOutPort;
        port out liquidOut : LiquidOutPort;
        attribute separationEfficiency : Real = 0.98;
        attribute internalLevel : LevelValue;
        attribute operatingPressure : PressureValue;
    }

    // ---- Heat Exchanger ----
    part def HeatExchanger {
        port in liquidIn : LiquidInPort;
        port out liquidOut : LiquidOutPort;
        port in coolantIn : CoolingInPort;
        port out coolantOut : CoolingOutPort;
        attribute heatTransferRate : PowerValue = 5000.0 [W];
        attribute inletTemperature : TemperatureValue;
        attribute outletTemperature : TemperatureValue;
        attribute coolingEfficiency : Real = 0.85;
    }

    // ---- Sealing Liquid Storage Tank ----
    part def SealingLiquidTank {
        port in liquidIn : LiquidInPort;
        port out liquidOut : LiquidOutPort;
        attribute capacity : VolumeValue = 2.0 [m^3];
        attribute currentLevel : LevelValue = 1.5 [m];
        attribute liquidTemperature : TemperatureValue;
    }

    // ---- Electric Motor ----
    part def ElectricMotor {
        port in powerIn : ElectricalPowerPort;
        port out powerOut : ElectricalPowerPort;
        port out speedSignal : SignalPort;
        attribute ratedPower : PowerValue = 18000.0 [W];
        attribute supplyVoltage : Real = 400.0;
        attribute supplyFrequency : Real = 50.0;
        attribute outputSpeed : RotationalSpeedValue;
    }

    // ---- Cooling Water Supply ----
    part def CoolingWaterSupply {
        port out coolantOut : CoolingOutPort;
        port in coolantReturn : CoolingInPort;
        attribute supplyTemperature : TemperatureValue = 290.0 [K];
        attribute flowRate : FlowRateValue = 0.002 [m^3/s];
    }

    // ---- Controller ----
    part def PumpController {
        port in pressureSignal : SignalPort;
        port in temperatureSignal : SignalPort;
        port in flowSignal : SignalPort;
        port in levelSignal : SignalPort;
        port out motorCommand : SignalPort;
        port out emergencyStop : SignalPort;
        attribute setpointPressure : PressureValue = 300000.0 [Pa];
        attribute maxTemperature : TemperatureValue = 350.0 [K];
        attribute minFlow : FlowRateValue = 0.001 [m^3/s];
        attribute minLevel : LevelValue = 0.3 [m];
        attribute controlMode : String = "automatic";
    }

    // ---- Main System ----
    part def LiquidRingPumpingSystem {
        // Main process equipment
        part sourceVessel : SourceVessel;
        part dischargeReceiver : DischargeReceiver;
        part pump : LiquidRingPump;
        part motor : ElectricMotor;
        part separator : Separator;
        part heatExchanger : HeatExchanger;
        part sealingLiquidTank : SealingLiquidTank;
        part coolingWaterSupply : CoolingWaterSupply;
        part controller : PumpController;

        // Sensors
        part pumpInletPressureSensor : PressureTransmitter;
        part pumpOutletPressureSensor : PressureTransmitter;
        part pumpCasingTempSensor : TemperatureTransmitter;
        part separatorLevelSensor : LevelTransmitter;
        part separatorPressureSensor : PressureTransmitter;
        part gasFlowSensor : FlowTransmitter;
        part sealingLiquidFlowSensor : FlowTransmitter;
        part tankLevelSensor : LevelTransmitter;
        part tankTempSensor : TemperatureTransmitter;
        part heatExchangerOutletTempSensor : TemperatureTransmitter;

        // Connections - Gas Process Flow
        connect sourceVessel.gasOut to pump.gasInlet;
        connect separator.gasOut to dischargeReceiver.gasIn;

        // Connections - Mixture from Pump to Separator
        connect pump.mixtureOutlet to separator.mixtureIn;

        // Connections - Sealing Liquid Loop
        connect separator.liquidOut to heatExchanger.liquidIn;
        connect heatExchanger.liquidOut to sealingLiquidTank.liquidIn;
        connect sealingLiquidTank.liquidOut to pump.liquidInlet;

        // Connections - Cooling Water
        connect coolingWaterSupply.coolantOut to heatExchanger.coolantIn;
        connect heatExchanger.coolantOut to coolingWaterSupply.coolantReturn;

        // Connections - Electrical Power
        connect motor.powerOut to pump.powerIn;

        // Connections - Sensor Signals to Controller
        connect pumpInletPressureSensor.signal to controller.pressureSignal;
        connect pumpCasingTempSensor.signal to controller.temperatureSignal;
        connect gasFlowSensor.signal to controller.flowSignal;
        connect tankLevelSensor.signal to controller.levelSignal;

        // Connections - Controller to Motor
        connect controller.motorCommand to motor.powerIn;
        connect controller.emergencyStop to pump.speedSignal;

        // Internal assignments
        attribute systemStatus : String = "operational";
        attribute designPressure : PressureValue = 300000.0 [Pa];
        attribute designTemperature : TemperatureValue = 340.0 [K];
    }

    // ---- Requirements ----
    requirement def PumpingSystemRequirements {
        requirement GasTransferRequirement {
            doc "The system shall transfer process gas from the source vessel to the discharge receiver at a minimum flow rate of 0.05 m³/s."
            attribute minFlowRate : FlowRateValue = 0.05 [m^3/s];
        }
        requirement SealingLiquidCirculationRequirement {
            doc "The system shall continuously circulate sealing liquid through the pump, separator, heat exchanger, and storage tank."
            attribute minSealingFlow : FlowRateValue = 0.001 [m^3/s];
        }
        requirement CoolingRequirement {
            doc "The heat exchanger shall cool the sealing liquid to below 310 K before returning it to the storage tank."
            attribute maxReturnTemperature : TemperatureValue = 310.0 [K];
        }
        requirement SeparationRequirement {
            doc "The separator shall separate gas from the gas-liquid mixture with at least 98% efficiency."
            attribute minSeparationEfficiency : Real = 0.98;
        }
        requirement EmergencyShutdownRequirement {
            doc "The system shall provide an emergency shutdown capability that stops the pump within 2 seconds of activation."
            attribute maxShutdownTime : Real = 2.0;
        }
        requirement ProtectiveStatesRequirement {
            doc "The pump shall enter protective states for high temperature above 350 K and cavitation conditions."
            attribute highTempThreshold : TemperatureValue = 350.0 [K];
            attribute cavitationPressureThreshold : PressureValue = 80000.0 [Pa];
        }
        requirement InstrumentationRequirement {
            doc "The system shall include pressure, temperature, flow, and level transmitters to monitor all critical process parameters."
        }
        requirement PumpStateRequirement {
            doc "The pump shall operate through stopped, starting, priming, and running states."
        }
    }

    // ---- Verification ----
    verification def VerifyGasTransfer {
        subject : LiquidRingPumpingSystem;
        objective {
            doc "Verify that the system meets the minimum gas transfer flow rate."
        }
    }
    verification def VerifySealingLiquidCirculation {
        subject : LiquidRingPumpingSystem;
        objective {
            doc "Verify continuous sealing liquid circulation."
        }
    }
    verification def VerifyCooling {
        subject : LiquidRingPumpingSystem;
        objective {
            doc "Verify sealing liquid return temperature is below threshold."
        }
    }
    verification def VerifyEmergencyShutdown {
        subject : LiquidRingPumpingSystem;
        objective {
            doc "Verify emergency shutdown stops pump within required time."
        }
    }

    // ---- Satisfy relationships ----
    satisfy PumpingSystemRequirements::GasTransferRequirement by LiquidRingPumpingSystem;
    satisfy PumpingSystemRequirements::SealingLiquidCirculationRequirement by LiquidRingPumpingSystem;
    satisfy PumpingSystemRequirements::CoolingRequirement by LiquidRingPumpingSystem;
    satisfy PumpingSystemRequirements::SeparationRequirement by LiquidRingPumpingSystem;
    satisfy PumpingSystemRequirements::EmergencyShutdownRequirement by LiquidRingPumpingSystem;
    satisfy PumpingSystemRequirements::ProtectiveStatesRequirement by LiquidRingPumpingSystem;
    satisfy PumpingSystemRequirements::InstrumentationRequirement by LiquidRingPumpingSystem;
    satisfy PumpingSystemRequirements::PumpStateRequirement by LiquidRingPumpingSystem;

}
