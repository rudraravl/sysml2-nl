package HengsteyseeHydropowerSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQVolume::*;
    import ISQEnergy::*;
    import ISQElectricity::*;

    // ===== Value Types =====
    value type LengthUnit = Length;
    value type VolumeUnit = Volume;
    value type FlowRateUnit = VolumeFlowRate;
    value type PowerUnit = Power;
    value type EnergyUnit = Energy;
    value type PressureUnit = Pressure;
    value type FrequencyUnit = Frequency;
    value type AngleUnit = PlaneAngle;
    value type PercentUnit = Real;

    value type WaterLevel :> LengthUnit { }
    value type WaterVolume :> VolumeUnit { }
    value type DischargeRate :> FlowRateUnit { }
    value type ElectricPower :> PowerUnit { }
    value type GateOpening :> AngleUnit { }

    // ===== Item Types =====
    item def Water;
    item def ElectricalEnergy;
    item def ControlSignal;
    item def SensorData;

    // ===== Enumerations =====
    enum def TurbineState {
        enum stopped;
        enum starting;
        enum running;
        enum stopping;
        enum faulted;
    }

    enum def SystemMode {
        enum normal;
        enum floodControl;
        enum lowWater;
    }

    enum def GateCommand {
        enum open;
        enum close;
        enum hold;
    }

    // ===== Port Definitions =====
    port def WaterPort {
        out flow : DischargeRate;
    }

    port def ElectricalPort {
        out power : ElectricPower;
    }

    port def ControlPort {
        out command : ControlSignal;
        in feedback : SensorData;
    }

    port def SensorPort {
        out reading : SensorData;
    }

    // ===== Requirements =====
    requirement def PowerGenerationRequirement {
        doc /* The system shall generate renewable hydroelectric power. */
        subject powerPlant : HengsteyseeHydropowerSystem;
        objective {
            assert powerPlant.totalGeneratedPower >= 3000.0 [kW]
        }
    }

    requirement def FloodControlRequirement {
        doc /* The system shall prevent dam overtopping and downstream flooding. */
        subject powerPlant : HengsteyseeHydropowerSystem;
        objective {
            assert powerPlant.reservoir.currentLevel <= powerPlant.reservoir.criticalLevel
        }
    }

    requirement def EnvironmentalFlowRequirement {
        doc /* The system shall maintain minimum environmental downstream flow. */
        subject powerPlant : HengsteyseeHydropowerSystem;
        objective {
            assert powerPlant.downstreamFlow >= 5.0 [m3/s]
        }
    }

    requirement def WaterLevelManagementRequirement {
        doc /* The system shall maintain reservoir water level within operational bounds. */
        subject powerPlant : HengsteyseeHydropowerSystem;
        objective {
            assert powerPlant.reservoir.currentLevel >= powerPlant.reservoir.minLevel
            and powerPlant.reservoir.currentLevel <= powerPlant.reservoir.maxLevel
        }
    }

    // ===== Parts =====
    part def HengsteyseeHydropowerSystem {
        requirement powerReq : PowerGenerationRequirement;
        requirement floodReq : FloodControlRequirement;
        requirement envFlowReq : EnvironmentalFlowRequirement;
        requirement levelReq : WaterLevelManagementRequirement;

        attribute mode : SystemMode = SystemMode::normal;
        attribute totalGeneratedPower : ElectricPower = 0.0 [kW];
        attribute downstreamFlow : DischargeRate = 0.0 [m3/s];

        flow throughWater : FlowRateUnit = 0.0 [m3/s];

        part dam : Dam {
            attribute height : LengthUnit = 8.5 [m];
            attribute crestElevation : LengthUnit = 112.0 [m];
        }

        part reservoir : Reservoir {
            attribute capacity : WaterVolume = 3900000.0 [m3];
            attribute minLevel : WaterLevel = 104.0 [m];
            attribute maxLevel : WaterLevel = 110.0 [m];
            attribute targetLevel : WaterLevel = 108.0 [m];
            attribute criticalLevel : WaterLevel = 111.0 [m];
            attribute currentLevel : WaterLevel = 108.0 [m];

            port inflowPort : WaterPort;
            port outflowPort : WaterPort;

            action updateLevel {
                in delta : DischargeRate;
                write currentLevel;
            }
        }

        part mainTurbine : HydroTurbine {
            attribute ratedPower : ElectricPower = 3000.0 [kW];
            attribute ratedFlow : DischargeRate = 40.0 [m3/s];
            attribute state : TurbineState = TurbineState::stopped;
            attribute currentPower : ElectricPower = 0.0 [kW];
            attribute currentFlow : DischargeRate = 0.0 [m3/s];

            port waterIn : WaterPort;
            port waterOut : WaterPort;
            port electricalOut : ElectricalPort;
            port controlIn : ControlPort;

            state machine TurbineStateMachine {
                entry; then stopped;

                state stopped {
                    entry {
                        currentPower = 0.0 [kW];
                        currentFlow = 0.0 [m3/s];
                    }
                    transition start for command.command == ControlSignal::start
                        if controlIn.feedback.reading.mode == SystemMode::normal
                        then starting;
                }

                state starting {
                    entry {
                        state = TurbineState::starting;
                    }
                    do {
                        currentPower = ratedPower * 0.5;
                        currentFlow = ratedFlow * 0.5;
                    }
                    transition reachedRunning
                        then running;
                }

                state running {
                    entry {
                        state = TurbineState::running;
                    }
                    do {
                        currentPower = ratedPower;
                        currentFlow = ratedFlow;
                    }
                    transition stop for command.command == ControlSignal::stop
                        then stopping;
                    transition fault for command.command == ControlSignal::fault
                        then faulted;
                }

                state stopping {
                    entry {
                        state = TurbineState::stopping;
                    }
                    do {
                        currentPower = currentPower * 0.5;
                        currentFlow = currentFlow * 0.5;
                    }
                    transition reachedStopped
                        then stopped;
                }

                state faulted {
                    entry {
                        state = TurbineState::faulted;
                        currentPower = 0.0 [kW];
                        currentFlow = 0.0 [m3/s];
                    }
                    transition reset for command.command == ControlSignal::reset
                        then stopped;
                }
            }
        }

        part auxiliaryTurbine : HydroTurbine {
            attribute ratedPower : ElectricPower = 1000.0 [kW];
            attribute ratedFlow : DischargeRate = 15.0 [m3/s];
            attribute state : TurbineState = TurbineState::stopped;
            attribute currentPower : ElectricPower = 0.0 [kW];
            attribute currentFlow : DischargeRate = 0.0 [m3/s];

            port waterIn : WaterPort;
            port waterOut : WaterPort;
            port electricalOut : ElectricalPort;
            port controlIn : ControlPort;

            state machine AuxTurbineStateMachine {
                entry; then stopped;

                state stopped {
                    entry {
                        currentPower = 0.0 [kW];
                        currentFlow = 0.0 [m3/s];
                    }
                    transition start for command.command == ControlSignal::start
                        then starting;
                }

                state starting {
                    entry {
                        state = TurbineState::starting;
                    }
                    do {
                        currentPower = ratedPower * 0.5;
                        currentFlow = ratedFlow * 0.5;
                    }
                    transition reachedRunning
                        then running;
                }

                state running {
                    entry {
                        state = TurbineState::running;
                    }
                    do {
                        currentPower = ratedPower;
                        currentFlow = ratedFlow;
                    }
                    transition stop for command.command == ControlSignal::stop
                        then stopping;
                }

                state stopping {
                    entry {
                        state = TurbineState::stopping;
                    }
                    do {
                        currentPower = currentPower * 0.5;
                        currentFlow = currentFlow * 0.5;
                    }
                    transition reachedStopped
                        then stopped;
                }
            }
        }

        part primarySluiceGate : ControllableSluiceGate {
            attribute maxDischarge : DischargeRate = 120.0 [m3/s];
            attribute opening : GateOpening = 0.0 [deg];
            attribute currentDischarge : DischargeRate = 0.0 [m3/s];

            port waterIn : WaterPort;
            port waterOut : WaterPort;
            port controlIn : ControlPort;

            action adjustOpening {
                in cmd : GateCommand;
                write opening;
                write currentDischarge;
            }
        }

        part emergencySluiceGate : ControllableSluiceGate {
            attribute maxDischarge : DischargeRate = 100.0 [m3/s];
            attribute opening : GateOpening = 0.0 [deg];
            attribute currentDischarge : DischargeRate = 0.0 [m3/s];

            port waterIn : WaterPort;
            port waterOut : WaterPort;
            port controlIn : ControlPort;

            action adjustOpening {
                in cmd : GateCommand;
                write opening;
                write currentDischarge;
            }
        }

        part spillway : Spillway {
            attribute crestLevel : WaterLevel = 111.0 [m];
            attribute maxDischarge : DischargeRate = 250.0 [m3/s];
            attribute currentDischarge : DischargeRate = 0.0 [m3/s];

            port waterIn : WaterPort;
            port waterOut : WaterPort;

            action autoRelease {
                in level : WaterLevel;
                write currentDischarge;
            }
        }

        part controlCenter : ControlCenter {
            attribute mode : SystemMode = SystemMode::normal;
            attribute targetLevel : WaterLevel = 108.0 [m];
            attribute minEnvironmentalFlow : DischargeRate = 5.0 [m3/s];

            port sensorIn : SensorPort;
            port mainTurbineControl : ControlPort;
            port auxTurbineControl : ControlPort;
            port primaryGateControl : ControlPort;
            port emergencyGateControl : ControlPort;

            action monitor {
                in data : SensorData;
                write mode;
            }

            action decideMode {
                in upstreamLevel : WaterLevel;
                in rainfallRate : DischargeRate;
                write mode;
            }

            action dispatchCommands {
                in currentMode : SystemMode;
                out mainCmd : ControlSignal;
                out auxCmd : ControlSignal;
                out primaryGateCmd : ControlSignal;
                out emergencyGateCmd : ControlSignal;
            }

            state machine ControlStateMachine {
                entry; then normal;

                state normal {
                    entry {
                        mode = SystemMode::normal;
                    }
                    transition toFlood for sensorIn.reading.upstreamLevel > 109.5 [m]
                        then floodControl;
                    transition toLowWater for sensorIn.reading.upstreamLevel < 105.0 [m]
                        then lowWater;
                }

                state floodControl {
                    entry {
                        mode = SystemMode::floodControl;
                    }
                    do {
                        dispatchCommands(SystemMode::floodControl);
                    }
                    transition toNormal for sensorIn.reading.upstreamLevel < 108.5 [m]
                        then normal;
                }

                state lowWater {
                    entry {
                        mode = SystemMode::lowWater;
                    }
                    do {
                        dispatchCommands(SystemMode::lowWater);
                    }
                    transition toNormal for sensorIn.reading.upstreamLevel > 107.0 [m]
                        then normal;
                }
            }
        }

        part sensorSuite : SensorSuite {
            part upstreamLevelSensor : WaterLevelSensor {
                attribute location : String = "upstream";
                attribute measuredLevel : WaterLevel = 108.0 [m];
                port readingOut : SensorPort;
            }

            part downstreamLevelSensor : WaterLevelSensor {
                attribute location : String = "downstream";
                attribute measuredLevel : WaterLevel = 100.0 [m];
                port readingOut : SensorPort;
            }

            part inflowMeter : FlowMeter {
                attribute location : String = "inflow";
                attribute measuredFlow : DischargeRate = 30.0 [m3/s];
                port readingOut : SensorPort;
            }

            part outflowMeter : FlowMeter {
                attribute location : String = "outflow";
                attribute measuredFlow : DischargeRate = 30.0 [m3/s];
                port readingOut : SensorPort;
            }

            part rainfallSensor : RainfallSensor {
                attribute measuredRate : DischargeRate = 0.0 [mm/h];
                port readingOut : SensorPort;
            }
        }

        part powerGrid : PowerGrid {
            attribute gridFrequency : FrequencyUnit = 50.0 [Hz];
            attribute voltage : ElectricPotential = 20000.0 [V];
            port gridConnection : ElectricalPort;
        }

        // ===== Connections =====
        connection reservoirToMainTurbine : FlowConnection
            connect reservoir.outflowPort::flow to mainTurbine.waterIn::flow;

        connection mainTurbineToDownstream : FlowConnection
            connect mainTurbine.waterOut::flow to reservoir.outflowPort::flow;

        connection reservoirToAuxTurbine : FlowConnection
            connect reservoir.outflowPort::flow to auxiliaryTurbine.waterIn::flow;

        connection auxTurbineToDownstream : FlowConnection
            connect auxiliaryTurbine.waterOut::flow to reservoir.outflowPort::flow;

        connection reservoirToPrimaryGate : FlowConnection
            connect reservoir.outflowPort::flow to primarySluiceGate.waterIn::flow;

        connection primaryGateToDownstream : FlowConnection
            connect primarySluiceGate.waterOut::flow to reservoir.outflowPort::flow;

        connection reservoirToEmergencyGate : FlowConnection
            connect reservoir.outflowPort::flow to emergencySluiceGate.waterIn::flow;

        connection emergencyGateToDownstream : FlowConnection
            connect emergencySluiceGate.waterOut::flow to reservoir.outflowPort::flow;

        connection reservoirToSpillway : FlowConnection
            connect reservoir.outflowPort::flow to spillway.waterIn::flow;

        connection spillwayToDownstream : FlowConnection
            connect spillway.waterOut::flow to reservoir.outflowPort::flow;

        connection mainTurbineToGrid : ElectricalConnection
            connect mainTurbine.electricalOut::power to powerGrid.gridConnection::power;

        connection auxTurbineToGrid : ElectricalConnection
            connect auxiliaryTurbine.electricalOut::power to powerGrid.gridConnection::power;

        connection controlToMainTurbine : ControlConnection
            connect controlCenter.mainTurbineControl::command to mainTurbine.controlIn::command;

        connection controlToAuxTurbine : ControlConnection
            connect controlCenter.auxTurbineControl::command to auxiliaryTurbine.controlIn::command;

        connection controlToPrimaryGate : ControlConnection
            connect controlCenter.primaryGateControl::command to primarySluiceGate.controlIn::command;

        connection controlToEmergencyGate : ControlConnection
            connect controlCenter.emergencyGateControl::command to emergencySluiceGate.controlIn::command;

        connection upstreamSensorToControl : DataConnection
            connect sensorSuite.upstreamLevelSensor.readingOut::reading to controlCenter.sensorIn::reading;

        connection downstreamSensorToControl : DataConnection
            connect sensorSuite.downstreamLevelSensor.readingOut::reading to controlCenter.sensorIn::reading;

        connection inflowMeterToControl : DataConnection
            connect sensorSuite.inflowMeter.readingOut::reading to controlCenter.sensorIn::reading;

        connection outflowMeterToControl : DataConnection
            connect sensorSuite.outflowMeter.readingOut::reading to controlCenter.sensorIn::reading;

        connection rainfallSensorToControl : DataConnection
            connect sensorSuite.rainfallSensor.readingOut::reading to controlCenter.sensorIn::reading;
    }

    part def Dam {
        attribute height : LengthUnit;
        attribute crestElevation : LengthUnit;
        attribute constructionMaterial : String = "reinforced concrete";
    }

    part def Reservoir {
        attribute capacity : WaterVolume;
        attribute minLevel : WaterLevel;
        attribute maxLevel : WaterLevel;
        attribute targetLevel : WaterLevel;
        attribute criticalLevel : WaterLevel;
        attribute currentLevel : WaterLevel;

        port inflowPort : WaterPort;
        port outflowPort : WaterPort;
    }

    part def HydroTurbine {
        attribute ratedPower : ElectricPower;
        attribute ratedFlow : DischargeRate;
        attribute state : TurbineState;
        attribute currentPower : ElectricPower;
        attribute currentFlow : DischargeRate;

        port waterIn : WaterPort;
        port waterOut : WaterPort;
        port electricalOut : ElectricalPort;
        port controlIn : ControlPort;
    }

    part def ControllableSluiceGate {
        attribute maxDischarge : DischargeRate;
        attribute opening : GateOpening;
        attribute currentDischarge : DischargeRate;

        port waterIn : WaterPort;
        port waterOut : WaterPort;
        port controlIn : ControlPort;
    }

    part def Spillway {
        attribute crestLevel : WaterLevel;
        attribute maxDischarge : DischargeRate;
        attribute currentDischarge : DischargeRate;

        port waterIn : WaterPort;
        port waterOut : WaterPort;
    }

    part def ControlCenter {
        attribute mode : SystemMode;
        attribute targetLevel : WaterLevel;
        attribute minEnvironmentalFlow : DischargeRate;

        port sensorIn : SensorPort;
        port mainTurbineControl : ControlPort;
        port auxTurbineControl : ControlPort;
        port primaryGateControl : ControlPort;
        port emergencyGateControl : ControlPort;
    }

    part def SensorSuite {
        part upstreamLevelSensor : WaterLevelSensor;
        part downstreamLevelSensor : WaterLevelSensor;
        part inflowMeter : FlowMeter;
        part outflowMeter : FlowMeter;
        part rainfallSensor : RainfallSensor;
    }

    part def WaterLevelSensor {
        attribute location : String;
        attribute measuredLevel : WaterLevel;
        port readingOut : SensorPort;
    }

    part def FlowMeter {
        attribute location : String;
        attribute measuredFlow : DischargeRate;
        port readingOut : SensorPort;
    }

    part def RainfallSensor {
        attribute measuredRate : DischargeRate;
        port readingOut : SensorPort;
    }

    part def PowerGrid {
        attribute gridFrequency : FrequencyUnit;
        attribute voltage : ElectricPotential;
        port gridConnection : ElectricalPort;
    }

    // ===== Connection Definitions =====
    connection def FlowConnection {
        end sourceFlow : DischargeRate;
        end targetFlow : DischargeRate;
    }

    connection def ElectricalConnection {
        end sourcePower : ElectricPower;
        end targetPower : ElectricPower;
    }

    connection def ControlConnection {
        end sourceCommand : ControlSignal;
        end targetCommand : ControlSignal;
    }

    connection def DataConnection {
        end sourceData : SensorData;
        end targetData : SensorData;
    }
}
