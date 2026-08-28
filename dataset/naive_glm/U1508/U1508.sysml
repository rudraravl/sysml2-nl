package SteamPumpSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQEnergy::*;
    import ISQMass::*;
    import ISQPressure::*;
    import ISQVolume::*;
    import ISQTemperature::*;
    import ISQFlowRate::*;
    import ISQFrequency::*;

    // ===== Item and Value Types =====

    item def Steam {
        attribute pressure : PressureValue;
        attribute temperature : ThermodynamicTemperatureValue;
        attribute massFlowRate : MassFlowRateValue;
        attribute quality : Real; // 0 = liquid, 1 = dry saturated vapor
    }

    item def Water {
        attribute pressure : PressureValue;
        attribute temperature : ThermodynamicTemperatureValue;
        attribute volumetricFlowRate : VolumetricFlowRateValue;
    }

    item def ExhaustSteam :> Steam;

    item def Condensate :> Water;

    value def PressureValue :> Real { unit "Pa"; }
    value def TemperatureValue :> Real { unit "K"; }
    value def MassFlowValue :> Real { unit "kg/s"; }
    value def VolFlowValue :> Real { unit "m3/s"; }
    value def PowerValue :> Real { unit "W"; }
    value def EnergyValue :> Real { unit "J"; }
    value def SpeedValue :> Real { unit "rev/min"; }
    value def StrokeLengthValue :> Real { unit "m"; }
    value def AreaValue :> Real { unit "m2"; }
    value def ForceValue :> Real { unit "N"; }

    // ===== Port Definitions =====

    port def SteamPort {
        out item steam : Steam;
    }

    port def SteamInPort {
        in item steam : Steam;
    }

    port def SteamOutPort {
        out item steam : Steam;
    }

    port def ExhaustPort {
        out item exhaust : ExhaustSteam;
    }

    port def ExhaustInPort {
        in item exhaust : ExhaustSteam;
    }

    port def WaterInPort {
        in item water : Water;
    }

    port def WaterOutPort {
        out item water : Water;
    }

    port def CondensatePort {
        out item condensate : Condensate;
    }

    port def MechanicalPowerPort {
        out attribute torque : Real;
        out attribute speed : SpeedValue;
        out attribute power : PowerValue;
    }

    port def MechanicalLoadPort {
        in attribute torque : Real;
        in attribute speed : SpeedValue;
        in attribute power : PowerValue;
    }

    port def ControlPort {
        in attribute startCmd : Boolean;
        in attribute stopCmd : Boolean;
        in attribute emergencyCmd : Boolean;
        in attribute demandLevel : DemandLevel;
    }

    port def MonitoringPort {
        out attribute steamPressure : PressureValue;
        out attribute dischargePressure : PressureValue;
        out attribute waterFlowRate : VolFlowValue;
        out attribute systemState : PumpState;
    }

    enum def DemandLevel { LOW; NORMAL; HIGH; }
    enum def PumpState { STOPPED; STARTING; OPERATING; STOPPING; EMERGENCY; }

    // ===== Part Definitions =====

    part def SteamBoiler {
        port steamOut : SteamOutPort;
        port controlIn : ControlPort;
        port monitoringOut : MonitoringPort;

        attribute maxPressure : PressureValue = 2.0e6 [Pa];
        attribute nominalPressure : PressureValue = 1.5e6 [Pa];
        attribute steamTemp : TemperatureValue = 500 [K];
        attribute fuelInput : PowerValue = 500000 [W];
        attribute efficiency : Real = 0.85;

        attribute currentPressure : PressureValue;

        state def BoilerStates {
            entry; then Idle;
            state Idle;
            state Firing;
            transition Idle -> Firing
                when controlIn.startCmd;
            transition Firing -> Idle
                when controlIn.stopCmd;
        }

        state machine : BoilerStates;

        action def GenerateSteam {
            in attribute fuel : PowerValue;
            out item steam : Steam;
        }
    }

    part def SteamCylinder {
        port steamIn : SteamInPort;
        port exhaustOut : ExhaustPort;
        port mechPowerOut : MechanicalPowerPort;
        port controlIn : ControlPort;

        attribute boreDiameter : Real = 0.15 [m];
        attribute strokeLength : StrokeLengthValue = 0.30 [m];
        attribute pistonArea : AreaValue = 0.0177 [m2];
        attribute maxForce : ForceValue = 26550 [N];
        attribute nominalSpeed : SpeedValue = 120 [rev/min];
        attribute mechanicalEfficiency : Real = 0.90;

        attribute currentForce : ForceValue;
        attribute currentPower : PowerValue;

        state def CylinderStates {
            entry; then Cold;
            state Cold;
            state Warming;
            state Running;
            transition Cold -> Warming
                when controlIn.startCmd;
            transition Warming -> Running
                when currentForce > 5000 [N];
            transition Running -> Cold
                when controlIn.stopCmd or controlIn.emergencyCmd;
        }

        state machine : CylinderStates;

        action def ExpandSteam {
            in item steam : Steam;
            out item exhaust : ExhaustSteam;
            out attribute mechanicalPower : PowerValue;
        }
    }

    part def ReciprocatingPump {
        port waterIn : WaterInPort;
        port waterOut : WaterOutPort;
        port mechPowerIn : MechanicalLoadPort;
        port controlIn : ControlPort;

        attribute pistonDiameter : Real = 0.10 [m];
        attribute pumpStroke : StrokeLengthValue = 0.30 [m];
        attribute pumpArea : AreaValue = 0.00785 [m2];
        attribute displacementPerStroke : VolumeValue = 0.00236 [m3];
        attribute nominalFlowRate : VolFlowValue = 0.00472 [m3/s];
        attribute maxDischargePressure : PressureValue = 8.0e5 [Pa];
        attribute volumetricEfficiency : Real = 0.92;

        attribute currentFlowRate : VolFlowValue;
        attribute currentDischargePressure : PressureValue;

        state def PumpStates {
            entry; then Idle;
            state Idle;
            state Priming;
            state Pumping;
            transition Idle -> Priming
                when controlIn.startCmd;
            transition Priming -> Pumping
                when mechPowerIn.power > 1000 [W];
            transition Pumping -> Idle
                when controlIn.stopCmd or controlIn.emergencyCmd;
        }

        state machine : PumpStates;

        action def PumpWater {
            in item water : Water;
            in attribute mechanicalPower : PowerValue;
            out item pressurizedWater : Water;
        }
    }

    part def CheckValve {
        port inlet : WaterInPort;
        port outlet : WaterOutPort;

        attribute crackingPressure : PressureValue = 5.0e3 [Pa];
        attribute maxPressure : PressureValue = 1.0e6 [Pa];
        attribute flowDirection : Boolean = true; // true = forward

        state def CheckValveStates {
            entry; then Closed;
            state Closed;
            state Open;
            transition Closed -> Open
                when inlet.water.pressure > crackingPressure;
            transition Open -> Closed
                when outlet.water.pressure >= inlet.water.pressure;
        }

        state machine : CheckValveStates;

        action def AllowFlow {
            in item water : Water;
            out item water : Water;
        }
    }

    part def SuctionCheckValve :> CheckValve {
        attribute crackingPressure : PressureValue = 2.0e3 [Pa] = 2.0e3 [Pa];
    }

    part def DischargeCheckValve :> CheckValve {
        attribute crackingPressure : PressureValue = 1.0e4 [Pa] = 1.0e4 [Pa];
    }

    part def Condenser {
        port exhaustIn : ExhaustInPort;
        port condensateOut : CondensatePort;

        attribute coolingWaterFlow : VolFlowValue = 0.01 [m3/s];
        attribute coolingTemp : TemperatureValue = 290 [K];
        attribute condensateTemp : TemperatureValue = 320 [K];
        attribute condensatePressure : PressureValue = 1.0e5 [Pa];
        attribute heatTransferRate : PowerValue = 200000 [W];

        state def CondenserStates {
            entry; then Standby;
            state Standby;
            state Condensing;
            transition Standby -> Condensing
                when exhaustIn.exhaust.massFlowRate > 0 [kg/s];
            transition Condensing -> Standby
                when exhaustIn.exhaust.massFlowRate == 0 [kg/s];
        }

        state machine : CondenserStates;

        action def CondenseSteam {
            in item exhaust : ExhaustSteam;
            out item condensate : Condensate;
        }
    }

    part def SafetyValve {
        port steamIn : SteamInPort;
        port ventOut : SteamOutPort;

        attribute setPressure : PressureValue = 2.2e6 [Pa];
        attribute reseatingPressure : PressureValue = 1.8e6 [Pa];
        attribute ventCapacity : MassFlowValue = 0.5 [kg/s];

        attribute isVenting : Boolean;

        state def SafetyValveStates {
            entry; then Sealed;
            state Sealed;
            state Venting;
            transition Sealed -> Venting
                when steamIn.steam.pressure > setPressure;
            transition Venting -> Sealed
                when steamIn.steam.pressure < reseatingPressure;
        }

        state machine : SafetyValveStates;

        action def VentExcess {
            in item steam : Steam;
            out item ventedSteam : Steam;
        }
    }

    part def PressureGauge {
        port measurementIn : SteamInPort;
        port readingOut : MonitoringPort;

        attribute measuredPressure : PressureValue;
        attribute maxRange : PressureValue = 3.0e6 [Pa];
        attribute accuracy : Real = 0.01;

        action def MeasurePressure {
            in item steam : Steam;
            out attribute pressure : PressureValue;
        }
    }

    part def FlowMeter {
        port measurementIn : WaterInPort;
        port readingOut : MonitoringPort;

        attribute measuredFlowRate : VolFlowValue;
        attribute maxRange : VolFlowValue = 0.01 [m3/s];
        attribute accuracy : Real = 0.02;

        action def MeasureFlow {
            in item water : Water;
            out attribute flowRate : VolFlowValue;
        }
    }

    // ===== Top-Level System =====

    part def SteamPumpSystem {
        // Control interface
        port controlIn : ControlPort;
        port monitoringOut : MonitoringPort;

        // Subcomponents
        part boiler : SteamBoiler {
            attribute maxPressure : PressureValue = 2.0e6 [Pa];
            attribute nominalPressure : PressureValue = 1.5e6 [Pa];
        }

        part cylinder : SteamCylinder;
        part pump : ReciprocatingPump;
        part suctionValve : SuctionCheckValve;
        part dischargeValve : DischargeCheckValve;
        part condenser : Condenser;
        part safetyValve : SafetyValve {
            attribute setPressure : PressureValue = 2.2e6 [Pa];
        }
        part steamPressureGauge : PressureGauge;
        part dischargePressureGauge : PressureGauge;
        part flowMeter : FlowMeter;

        // External interfaces
        port waterSource : WaterInPort;
        port waterDestination : WaterOutPort;
        port condensateDrain : CondensatePort;

        // Connections - Steam side
        connection steamSupply connect boiler.steamOut to cylinder.steamIn;
        connection steamToSafetyValve connect boiler.steamOut to safetyValve.steamIn;
        connection safetyVent connect safetyValve.ventOut to cylinder.steamIn;
        connection exhaustToCondenser connect cylinder.exhaustOut to condenser.exhaustIn;
        connection condensateDrainage connect condenser.condensateOut to condensateDrain;

        // Connections - Mechanical side
        connection mechanicalDrive connect cylinder.mechPowerOut to pump.mechPowerIn;

        // Connections - Water side
        connection sourceToSuction connect waterSource to suctionValve.inlet;
        connection suctionToPump connect suctionValve.outlet to pump.waterIn;
        connection pumpToDischarge connect pump.waterOut to dischargeValve.inlet;
        connection dischargeToDestination connect dischargeValve.outlet to waterDestination;

        // Connections - Monitoring
        connection steamPressureSense connect boiler.steamOut to steamPressureGauge.measurementIn;
        connection dischargePressureSense connect dischargeValve.outlet to dischargePressureGauge.measurementIn;
        connection flowSense connect dischargeValve.outlet to flowMeter.measurementIn;

        // Control distribution
        connection controlToBoiler connect controlIn to boiler.controlIn;
        connection controlToCylinder connect controlIn to cylinder.controlIn;
        connection controlToPump connect controlIn to pump.controlIn;

        // System state machine
        attribute currentDemand : DemandLevel = DemandLevel::NORMAL;
        attribute systemState : PumpState = PumpState::STOPPED;
        attribute steamCutoff : Boolean = false;

        state def SystemStates {
            entry; then Stopped;

            state Stopped {
                entry action {
                    boiler.controlIn.startCmd = false;
                    pump.controlIn.startCmd = false;
                }
            }

            state Starting {
                entry action {
                    boiler.controlIn.startCmd = true;
                    cylinder.controlIn.startCmd = true;
                    pump.controlIn.startCmd = true;
                }
                // Warm-up and priming period
                do action {
                    // Wait for cylinder to warm and pump to prime
                }
            }

            state Operating {
                // Sub-states for demand levels
                parallel {
                    state HighDemand {
                        entry action {
                            currentDemand = DemandLevel::HIGH;
                            boiler.fuelInput = 600000 [W];
                        }
                    }
                    state NormalDemand {
                        entry action {
                            currentDemand = DemandLevel::NORMAL;
                            boiler.fuelInput = 500000 [W];
                        }
                    }
                    state LowDemand {
                        entry action {
                            currentDemand = DemandLevel::LOW;
                            boiler.fuelInput = 300000 [W];
                        }
                    }
                    transition HighDemand -> NormalDemand
                        when controlIn.demandLevel == DemandLevel::NORMAL;
                    transition NormalDemand -> HighDemand
                        when controlIn.demandLevel == DemandLevel::HIGH;
                    transition NormalDemand -> LowDemand
                        when controlIn.demandLevel == DemandLevel::LOW;
                    transition LowDemand -> NormalDemand
                        when controlIn.demandLevel == DemandLevel::NORMAL;
                }
            }

            state Stopping {
                entry action {
                    boiler.controlIn.startCmd = false;
                    cylinder.controlIn.stopCmd = true;
                    pump.controlIn.stopCmd = true;
                }
                do action {
                    // Graceful shutdown: reduce steam, let cylinder coast down
                }
            }

            state Emergency {
                entry action {
                    steamCutoff = true;
                    boiler.controlIn.emergencyCmd = true;
                    cylinder.controlIn.emergencyCmd = true;
                    pump.controlIn.emergencyCmd = true;
                }
            }

            transition Stopped -> Starting
                when controlIn.startCmd == true;
            transition Starting -> Operating
                when cylinder.mechPowerOut.power > 1000 [W]
                   and pump.waterOut.water.volumetricFlowRate > 0 [m3/s];
            transition Operating -> Stopping
                when controlIn.stopCmd == true;
            transition Stopping -> Stopped
                when cylinder.mechPowerOut.power == 0 [W];
            transition Operating -> Emergency
                when controlIn.emergencyCmd == true
                   or boiler.steamOut.steam.pressure > safetyValve.setPressure;
            transition Starting -> Emergency
                when controlIn.emergencyCmd == true;
            transition Stopping -> Emergency
                when controlIn.emergencyCmd == true;
            transition Emergency -> Stopped
                when controlIn.startCmd == false
                   and controlIn.stopCmd == false
                   and controlIn.emergencyCmd == false;
        }

        state machine : SystemStates;

        // System-level actions
        action def StartSequence {
            in attribute cmd : Boolean;
            out attribute status : PumpState;
        }

        action def StopSequence {
            in attribute cmd : Boolean;
            out attribute status : PumpState;
        }

        action def EmergencyShutdown {
            in attribute trigger : Boolean;
            out attribute steamCutoff : Boolean;
            out attribute status : PumpState;
        }

        action def RegulateDemand {
            in attribute demand : DemandLevel;
            out attribute fuelAdjustment : PowerValue;
        }
    }

    // ===== Requirements =====

    package Requirements {

        requirement def PumpSystemRequirement {
            subject pumpSystem : SteamPumpSystem;
            objective {
                doc "The steam pump system shall convert thermal energy of high-pressure steam into mechanical work to move water from a low-pressure source to a high-pressure destination.";
            }
        }

        requirement def ContinuousOperationRequirement {
            subject pumpSystem : SteamPumpSystem;
            objective {
                doc "The system shall operate continuously and reliably in a closed-loop manner.";
            }
        }

        requirement def SteamGenerationRequirement {
            subject boiler : SteamBoiler;
            attribute minSteamPressure : PressureValue = 1.5e6 [Pa];
            attribute minSteamTemp : TemperatureValue = 450 [K];
            objective {
                doc "The steam boiler shall generate high-pressure steam at minimum 1.5 MPa and 450 K.";
            }
            require boiler.nominalPressure >= minSteamPressure;
        }

        requirement def MechanicalConversionRequirement {
            subject cylinder : SteamCylinder;
            attribute minEfficiency : Real = 0.85;
            objective {
                doc "The steam cylinder shall convert steam thermal energy into mechanical power with at least 85% mechanical efficiency.";
            }
            require cylinder.mechanicalEfficiency >= minEfficiency;
        }

        requirement def PumpingRequirement {
            subject pump : ReciprocatingPump;
            attribute minFlowRate : VolFlowValue = 0.003 [m3/s];
            attribute minDischargePressure : PressureValue = 5.0e5 [Pa];
            objective {
                doc "The reciprocating pump shall deliver at least 0.003 m3/s of water at a minimum discharge pressure of 0.5 MPa.";
            }
            require pump.nominalFlowRate >= minFlowRate;
            require pump.maxDischargePressure >= minDischargePressure;
        }

        requirement def CheckValveRequirement {
            subject valve : CheckValve;
            objective {
                doc "Check valves shall ensure unidirectional water flow, preventing backflow.";
            }
            require valve.flowDirection == true;
        }

        requirement def CondenserRequirement {
            subject condenser : Condenser;
            attribute maxCondensateTemp : TemperatureValue = 330 [K];
            objective {
                doc "The condenser shall cool exhaust steam to liquid condensate at or below 330 K.";
            }
            require condenser.condensateTemp <= maxCondensateTemp;
        }

        requirement def SafetyValveRequirement {
            subject safetyValve : SafetyValve;
            attribute maxSystemPressure : PressureValue = 2.5e6 [Pa];
            objective {
                doc "The safety valve shall automatically release pressure before the system exceeds 2.5 MPa to prevent catastrophic failure.";
            }
            require safetyValve.setPressure <= maxSystemPressure;
        }

        requirement def MonitoringRequirement {
            subject pumpSystem : SteamPumpSystem;
            objective {
                doc "The system shall monitor steam pressure, water discharge pressure, and water flow rate.";
            }
        }

        requirement def StateMachineRequirement {
            subject pumpSystem : SteamPumpSystem;
            objective {
                doc "The pump shall operate through states: stopped, starting, operating (with high, normal, and low demand sub-states), stopping, and emergency.";
            }
        }

        requirement def EmergencyResponseRequirement {
            subject pumpSystem : SteamPumpSystem;
            attribute maxResponseTime : Real = 1.0; // seconds
            objective {
                doc "Upon a critical failure, the system shall enter the emergency state and immediately cut off steam within 1 second.";
            }
        }

        requirement def DemandRegulationRequirement {
            subject pumpSystem : SteamPumpSystem;
            objective {
                doc "During the operating state, the system shall regulate steam flow to handle high, normal, or low demand.";
            }
        }

        // Requirement satisfaction
        satisfaction pumpSystemReq by pumpSystem : SteamPumpSystem;
        satisfaction continuousOpReq by pumpSystem : SteamPumpSystem;
        satisfaction steamGenReq by pumpSystem.boiler : SteamBoiler;
        satisfaction mechConvReq by pumpSystem.cylinder : SteamCylinder;
        satisfaction pumpingReq by pumpSystem.pump : ReciprocatingPump;
        satisfaction suctionValveReq by pumpSystem.suctionValve : SuctionCheckValve;
        satisfaction dischargeValveReq by pumpSystem.dischargeValve : DischargeCheckValve;
        satisfaction condenserReq by pumpSystem.condenser : Condenser;
        satisfaction safetyValveReq by pumpSystem.safetyValve : SafetyValve;
        satisfaction monitoringReq by pumpSystem : SteamPumpSystem;
        satisfaction stateMachineReq by pumpSystem : SteamPumpSystem;
        satisfaction emergencyResponseReq by pumpSystem : SteamPumpSystem;
        satisfaction demandRegulationReq by pumpSystem : SteamPumpSystem;
    }
}
