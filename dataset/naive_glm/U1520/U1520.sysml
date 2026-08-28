package VaporLockPreventionSystem {

    // ---- Value Types with Units ----
    package ValueTypes {
        attribute def TemperatureValue :> Real { unit 'K'; }
        attribute def PressureValue :> Real { unit 'Pa'; }
        attribute def FlowRateValue :> Real { unit 'L/min'; }
        attribute def PowerValue :> Real {> Real { unit 'W'; }
        attribute def Dimensionless :> Real;
    }

    // ---- Item Definitions ----
    package Items {
        item def LiquidFuel;
        item def FuelVapor;
        item def CoolantFluid;
        item def ElectricalSignal {
            attribute value : ValueTypes::Dimensionless;
        }
        item def ControlCommand {
            attribute commandKind : String;
            attribute magnitude : ValueTypes::Dimensionless;
        }
    }

    // ---- Port Definitions ----
    package Ports {
        port def FuelFlowPort {
            in item fuelIn : Items::LiquidFuel;
            out item fuelOut : Items::LiquidFuel;
        }
        port def VaporPort {
            out item vaporOut : Items::FuelVapor;
        }
        port def CoolantPort {
            in item coolantIn : Items::CoolantFluid;
            out item coolantOut : Items::CoolantFluid;
        }
        port def SignalPort {
            in item signalIn : Items::ElectricalSignal;
            out item signalOut : Items::ElectricalSignal;
        }
        port def CommandPort {
            in item commandIn : Items::ControlCommand;
            out item commandOut : Items::ControlCommand;
        }
    }

    // ---- Requirements ----
    package Requirements {
        requirement def PreventVaporLock {
            doc /* The system shall maintain liquid fuel supply to the engine under high-temperature conditions. */
            subject system : VaporLockPreventionSystem::System;
            objective {
                system.fuelLine.temperature < system.fuelLine.vaporizationThresholdTemp and
                system.fuelLine.pressure > system.fuelLine.vaporizationThresholdPressure
            }
        }

        requirement def MonitorFuelState {
            doc /* The system shall continuously monitor fuel temperature and pressure near the engine intake. */
            subject sensors : VaporLockPreventionSystem::SensorSuite;
            objective {
                sensors.temperatureSensor.measurementRate >= 10 [1/s] and
                sensors.pressureSensor.measurementRate >= 10 [1/s]
            }
        }

        requirement def ActivateCountermeasures {
            doc /* Upon detecting vapor lock risk, the system shall activate cooling, increase pump pressure, and open vent valve simultaneously. */
            subject controller : VaporLockPreventionSystem::Controller;
            objective {
                controller.coolingActivationLatency <= 0.5 [s] and
                controller.pumpCommandLatency <= 0.5 [s] and
                controller.ventCommandLatency <= 0.5 [s]
            }
        }

        requirement def VentAccumulatedVapor {
            doc /* The system shall vent any accumulated fuel vapor from the fuel line. */
            subject ventValve : VaporLockPreventionSystem::VentValve;
            objective {
                ventValve.maxVentFlowRate >= 2.0 [L/min]
            }
        }

        requirement def ContinuousFuelSupply {
            doc /* The system shall guarantee uninterrupted liquid fuel flow to the engine. */
            subject engine : VaporLockPreventionSystem::Engine;
            objective {
                engine.requiredFlowRate <= system.fuelPump.maxOutputFlowRate
            }
        }

        requirement PreventVaporLockReq :> PreventVaporLock;
        requirement MonitorFuelStateReq :> MonitorFuelState;
        requirement ActivateCountermeasuresReq :> ActivateCountermeasures;
        requirement VentAccumulatedVaporReq :> VentAccumulatedVapor;
        requirement ContinuousFuelSupplyReq :> ContinuousFuelSupply;
    }

    // ---- Component Definitions ----
    package Components {

        part def FuelTank {
            attribute capacity : ValueTypes::FlowRateValue = 80 [L/min];
            port fuelOutlet : Ports::FuelFlowPort;
            attribute currentFuelLevel : ValueTypes::Dimensionless = 0.8;
        }

        part def FuelPump {
            attribute nominalPressure : ValueTypes::PressureValue = 300000 [Pa];
            attribute maxOutputPressure : ValueTypes::PressureValue = 500000 [Pa];
            attribute maxOutputFlowRate : ValueTypes::FlowRateValue = 60 [L/min];
            attribute currentPressure : ValueTypes::PressureValue = nominalPressure;
            port fuelInlet : Ports::FuelFlowPort;
            port fuelOutlet : Ports::FuelFlowPort;
            port commandIn : Ports::CommandPort;

            action def IncreasePressure {
                in targetPressure : ValueTypes::PressureValue;
                then UpdateOutput;
            }
            action def UpdateOutput {
                then Done;
            }
            action def Done;

            exhibit state PumpBehavior {
                entry; then Normal;
                state Normal {
                    entry { currentPressure = nominalPressure; }
                }
                state Boosted {
                    entry { currentPressure = maxOutputPressure; }
                }
                transition from Normal to Boosted
                    when commandIn.commandIn.magnitude > 0.0;
                transition from Boosted to Normal
                    when commandIn.commandIn.magnitude == 0.0;
            }
        }

        part def FuelLine {
            attribute length : ValueTypes::Dimensionless = 1.5;
            attribute temperature : ValueTypes::TemperatureValue = 300 [K];
            attribute pressure : ValueTypes::PressureValue = 300000 [Pa];
            attribute vaporizationThresholdTemp : ValueTypes::TemperatureValue = 350 [K];
            attribute vaporizationThresholdPressure : ValueTypes::PressureValue = 60000 [Pa];
            attribute vaporContent : ValueTypes::Dimensionless = 0.0;
            port fuelInlet : Ports::FuelFlowPort;
            port fuelOutlet : Ports::FuelFlowPort;
            port vaporOutlet : Ports::VaporPort;
            port coolantJacket : Ports::CoolantPort;
        }

        part def Engine {
            attribute requiredFlowRate : ValueTypes::FlowRateValue = 30 [L/min];
            attribute operatingTemperature : ValueTypes::TemperatureValue = 360 [K];
            port fuelIntake : Ports::FuelFlowPort;
            port exhaustOut : Ports::FuelFlowPort;
        }

        part def TemperatureSensor {
            attribute measurementRate : ValueTypes::Dimensionless = 20;
            attribute threshold : ValueTypes::TemperatureValue = 340 [K];
            attribute currentReading : ValueTypes::TemperatureValue = 300 [K];
            port signalOut : Ports::SignalPort;

            action def SampleTemperature {
                out reading : ValueTypes::TemperatureValue;
                then EvaluateRisk;
            }
            action def EvaluateRisk {
                in reading : ValueTypes::TemperatureValue;
                out riskFlag : ValueTypes::Dimensionless;
                then Transmit;
            }
            action def Transmit {
                in riskFlag : ValueTypes::Dimensionless;
            }
        }

        part def PressureSensor {
            attribute measurementRate : ValueTypes::Dimensionless = 20;
            attribute threshold : ValueTypes::PressureValue = 80000 [Pa];
            attribute currentReading : ValueTypes::PressureValue = 300000 [Pa];
            port signalOut : Ports::SignalPort;

            action def SamplePressure {
                out reading : ValueTypes::PressureValue;
                then EvaluateRisk;
            }
            action def EvaluateRisk {
                in reading : ValueTypes::PressureValue;
                out riskFlag : ValueTypes::Dimensionless;
                then Transmit;
            }
            action def Transmit {
                in riskFlag : ValueTypes::Dimensionless;
            }
        }

        part def SensorSuite {
            part temperatureSensor : TemperatureSensor;
            part pressureSensor : PressureSensor;
            port tempSignalOut : Ports::SignalPort;
            port pressSignalOut : Ports::SignalPort;
        }

        part def CoolingSystem {
            attribute coolingCapacity : ValueTypes::PowerValue = 200 [W];
            attribute active : ValueTypes::Dimensionless = 0.0;
            port coolantIn : Ports::CoolantPort;
            port coolantOut : Ports::CoolantPort;
            port commandIn : Ports::CommandPort;

            exhibit state CoolingBehavior {
                entry; then Idle;
                state Idle {
                    entry { active = 0.0; }
                }
                state Active {
                    entry { active = 1.0; }
                }
                transition from Idle to Active
                    when commandIn.commandIn.magnitude > 0.0;
                transition from Active to Idle
                    when commandIn.commandIn.magnitude == 0.0;
            }
        }

        part def VentValve {
            attribute maxVentFlowRate : ValueTypes::FlowRateValue = 3.0 [L/min];
            attribute openState : ValueTypes::Dimensionless = 0.0;
            port vaporOutlet : Ports::VaporPort;
            port commandIn : Ports::CommandPort;

            exhibit state ValveBehavior {
                entry; then Closed;
                state Closed {
                    entry { openState = 0.0; }
                }
                state Open {
                    entry { openState = 1.0; }
                }
                transition from Closed to Open
                    when commandIn.commandIn.magnitude > 0.0;
                transition from Open to Closed
                    when commandIn.commandIn.magnitude == 0.0;
            }
        }

        part def Controller {
            attribute tempRiskThreshold : ValueTypes::TemperatureValue = 340 [K];
            attribute pressRiskThreshold : ValueTypes::PressureValue = 80000 [Pa];
            attribute coolingActivationLatency : ValueTypes::Dimensionless = 0.2;
            attribute pumpCommandLatency : ValueTypes::Dimensionless = 0.2;
            attribute ventCommandLatency : ValueTypes::Dimensionless = 0.2;
            attribute riskDetected : ValueTypes::Dimensionless = 0.0;

            port tempSignalIn : Ports::SignalPort;
            port pressSignalIn : Ports::SignalPort;
            port coolingCommandOut : Ports::CommandPort;
            port pumpCommandOut : Ports::CommandPort;
            port ventCommandOut : Ports::CommandPort;

            action def AnalyzeReadings {
                in tempReading : ValueTypes::TemperatureValue;
                in pressReading : ValueTypes::PressureValue;
                out riskLevel : ValueTypes::Dimensionless;
                then DecideCountermeasures;
            }
            action def DecideCountermeasures {
                in riskLevel : ValueTypes::Dimensionless;
                out coolingCmd : Items::ControlCommand;
                out pumpCmd : Items::ControlCommand;
                out ventCmd : Items::ControlCommand;
                then Dispatch;
            }
            action def Dispatch {
                in coolingCmd : Items::ControlCommand;
                in pumpCmd : Items::ControlCommand;
                in ventCmd : Items::ControlCommand;
            }

            exhibit state ControlLogic {
                entry; then Monitoring;
                state Monitoring {
                    entry { riskDetected = 0.0; }
                }
                state RiskDetected {
                    entry { riskDetected = 1.0; }
                }
                transition from Monitoring to RiskDetected
                    when tempSignalIn.signalIn.value > tempRiskThreshold or
                         pressSignalIn.signalIn.value < pressRiskThreshold;
                transition from RiskDetected to Monitoring
                    when tempSignalIn.signalIn.value <= tempRiskThreshold and
                         pressSignalIn.signalIn.value >= pressRiskThreshold;
            }
        }
    }

    // ---- System Assembly ----
    part def System {
        part fuelTank : Components::FuelTank;
        part fuelPump : Components::FuelPump;
        part fuelLine : Components::FuelLine;
        part engine : Components::Engine;
        part sensorSuite : Components::SensorSuite;
        part coolingSystem : Components::CoolingSystem;
        part ventValve : Components::VentValve;
        part controller : Components::Controller;

        // Fuel flow connections
        connect fuelTank.fuelOutlet to fuelPump.fuelInlet;
        connect fuelPump.fuelOutlet to fuelLine.fuelInlet;
        connect fuelLine.fuelOutlet to engine.fuelIntake;

        // Sensor signal connections
        connect sensorSuite.temperatureSensor.signalOut to controller.tempSignalIn;
        connect sensorSuite.pressureSensor.signalOut to controller.pressSignalIn;

        // Controller command connections
        connect controller.coolingCommandOut to coolingSystem.commandIn;
        connect controller.pumpCommandOut to fuelPump.commandIn;
        connect controller.ventCommandOut to ventValve.commandIn;

        // Coolant loop
        connect coolingSystem.coolantOut to fuelLine.coolantJacket;
        connect fuelLine.coolantJacket to coolingSystem.coolantIn;

        // Vapor venting
        connect fuelLine.vaporOutlet to ventValve.vaporOutlet;

        // Requirement satisfaction
        satisfy Requirements::PreventVaporLockReq by system;
        satisfy Requirements::MonitorFuelStateReq by sensorSuite;
        satisfy Requirements::ActivateCountermeasuresReq by controller;
        satisfy Requirements::VentAccumulatedVaporReq by ventValve;
        satisfy Requirements::ContinuousFuelSupplyReq by engine;
    }

}
