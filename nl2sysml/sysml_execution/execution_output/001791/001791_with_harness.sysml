package HengsteyseeHydropowerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    private import NumericalFunctions::*;

    attribute def WaterLevelValue :> LengthValue;
    attribute def FlowRateValue :> VolumeFlowRateValue;
    attribute def PowerOutputValue :> PowerValue;
    attribute def GateOpeningValue :> Real;
    attribute def TemperatureValue :> ThermodynamicTemperatureValue;
    attribute def PressureValueDef :> PressureValue;

    enum def SystemMode {
        normal;
        floodControl;
        lowWater;
        maintenance;
        emergency;
    }

    enum def TurbineState {
        stopped;
        starting;
        running;
        stopping;
    }

    item def Water {
        attribute temperature : TemperatureValue;
        attribute flowRate : FlowRateValue;
        attribute pressure : PressureValueDef;
    }

    item def Electricity {
        attribute voltage : ElectricPotentialValue;
        attribute current : ElectricCurrentValue;
        attribute power : PowerOutputValue;
        attribute frequency : FrequencyValue;
    }

    port def WaterFlowPort {
        inout item waterFlow : Water;
    }

    port def ElectricalPort {
        out item electricalOutput : Electricity;
    }

    port def ControlSignalPort {
        in controlCommand : Real;
        out statusFeedback : Real;
    }

    part def WaterLevelSensor {
        out port levelReading {
            out measuredLevel : WaterLevelValue;
        }
        attribute accuracy : Real = 0.01;
    }

    part def FlowMeter {
        out port flowReading {
            out measuredFlow : FlowRateValue;
        }
        attribute accuracy : Real = 0.02;
    }

    part def ReservoirBasin {
        attribute capacity : VolumeValue = 3500000.0 [m^3];
        attribute currentVolume : VolumeValue;
        attribute surfaceArea : AreaValue = 1.38 [km^2];
        attribute normalLevel : WaterLevelValue = 96.0 [m];
        attribute maxLevel : WaterLevelValue = 98.5 [m];
        attribute minLevel : WaterLevelValue = 92.0 [m];
        
        port inflowPort : WaterFlowPort;
        port outflowPort : WaterFlowPort;
        
        assert constraint volumeConstraint {
            currentVolume >= 0.0 [m^3] and currentVolume <= capacity
        }
    }

    part def Dam {
        attribute height : LengthValue = 35.0 [m];
        attribute length : LengthValue = 206.0 [m];
        attribute crestElevation : LengthValue = 99.0 [m];
        
        part structure {
            attribute concreteVolume : VolumeValue = 85000.0 [m^3];
            attribute structuralIntegrity : Real = 0.98;
        }
    }

    part def SluiceGate {
        attribute maxOpening : LengthValue = 8.0 [m];
        attribute currentOpening : GateOpeningValue = 0.0;
        attribute dischargeCoefficient : Real = 0.85;
        
        port controlPort : ControlSignalPort;
        port waterInlet : WaterFlowPort;
        port waterOutlet : WaterFlowPort;
        
        assert constraint openingLimit {
            currentOpening >= 0.0 and currentOpening <= 100.0
        }
    }

    part def HydroelectricTurbine {
        attribute ratedPower : PowerOutputValue = 2500.0 [kW];
        attribute efficiency : Real = 0.91;
        attribute ratedHead : LengthValue = 12.0 [m];
        attribute ratedFlow : FlowRateValue = 25.0 [m^3/s];
        attribute currentState : TurbineState = TurbineState::stopped;
        
        port waterInlet : WaterFlowPort;
        port waterOutlet : WaterFlowPort;
        port powerOutput : ElectricalPort;
        port controlPort : ControlSignalPort;
        
        assert constraint powerGeneration {
            powerOutput.electricalOutput.power == 
                efficiency * 9.81 [m/s^2] * waterInlet.waterFlow.flowRate * ratedHead * 1000.0 [kg/m^3]
        }
    }

    part def Spillway {
        attribute width : LengthValue = 45.0 [m];
        attribute crestLevel : LengthValue = 96.5 [m];
        attribute dischargeCoefficient : Real = 0.75;
        
        port waterInlet : WaterFlowPort;
        port waterOutlet : WaterFlowPort;
    }

    part def PowerGrid {
        attribute nominalVoltage : ElectricPotentialValue = 110000.0 [V];
        attribute nominalFrequency : FrequencyValue = 50.0 [Hz];
        
        port gridConnection : ElectricalPort;
    }

    part def ControlCenter {
        attribute operatingMode : SystemMode = SystemMode::normal;
        attribute targetReservoirLevel : WaterLevelValue = 96.0 [m];
        
        part levelSensor : WaterLevelSensor;
        part inflowMeter : FlowMeter;
        part outflowMeter : FlowMeter;
        
        port sensorInputs {
            in reservoirLevel : WaterLevelValue;
            in inflowRate : FlowRateValue;
            in outflowRate : FlowRateValue;
        }
        
        port controlOutputs {
            out gateCommand : GateOpeningValue;
            out turbineCommand : Real;
        }
    }

    action def MonitorReservoir {
        in currentLevel : WaterLevelValue;
        in targetLevel : WaterLevelValue;
        in inflowRate : FlowRateValue;
        out levelDeviation : Real;
        out requiredAction : SystemMode;
    }

    action def AdjustGateOpening {
        in levelDeviation : Real;
        in currentOpening : GateOpeningValue;
        in inflowRate : FlowRateValue;
        out newOpening : GateOpeningValue;
    }

    action def ControlTurbine {
        in waterFlow : FlowRateValue;
        in targetPower : PowerOutputValue;
        out turbineSetpoint : Real;
    }

    action def ManageWaterLevel {
        first start;
        then merge continuousMonitoring;
        
        then action monitor : MonitorReservoir {
            in currentLevel : WaterLevelValue;
            in targetLevel : WaterLevelValue;
            in inflowRate : FlowRateValue;
            out deviation : Real;
            out mode : SystemMode;
        }
        
        then decide;
            if monitor.deviation > 1.0 then increaseDischarge;
            if monitor.deviation < -1.0 then decreaseDischarge;
            if abs(monitor.deviation) <= 1.0 then maintainCurrent;
        
        action increaseDischarge : AdjustGateOpening {
            in levelDeviation = monitor.deviation;
            in currentOpening : GateOpeningValue;
            in inflowRate : FlowRateValue;
            out newOpening : GateOpeningValue;
        }
        then continuousMonitoring;
        
        action decreaseDischarge : AdjustGateOpening {
            in levelDeviation = monitor.deviation;
            in currentOpening : GateOpeningValue;
            in inflowRate : FlowRateValue;
            out newOpening : GateOpeningValue;
        }
        then continuousMonitoring;
        
        action maintainCurrent;
        then continuousMonitoring;
    }

    state def ReservoirOperationStates {
        in waterLevel : WaterLevelValue;
        in maxLevel : WaterLevelValue;
        in minLevel : WaterLevelValue;
        in normalLevel : WaterLevelValue;
        
        entry; then normalOperation;
        
        state normalOperation {
            entry action maintainLevel;
        }
        
        transition normalToFlood
            first normalOperation
            if waterLevel > normalLevel + 1.5 [m]
            then floodControl;
        
        state floodControl {
            entry action maximizeDischarge;
        }
        
        transition floodToNormal
            first floodControl
            if waterLevel <= normalLevel + 0.5 [m]
            then normalOperation;
        
        transition normalToLow
            first normalOperation
            if waterLevel < normalLevel - 2.0 [m]
            then lowWaterOperation;
        
        state lowWaterOperation {
            entry action minimizeDischarge;
        }
        
        transition lowToNormal
            first lowWaterOperation
            if waterLevel >= normalLevel - 0.5 [m]
            then normalOperation;
    }

    part def HengsteyseeHydropowerSystem {
        doc /* 
         * Hengsteysee Hydropower System on the Ruhr River in Germany.
         * Primary function: Regulate river flow, control flooding, and generate
         * renewable hydroelectric power while maintaining ecological balance.
         * The system manages water levels through coordinated operation of turbines,
         * sluice gates, and spillways to optimize power generation and flood protection.
         */
        
        attribute systemMode : SystemMode = SystemMode::normal;
        
        part reservoir : ReservoirBasin;
        part dam : Dam;
        part mainTurbine : HydroelectricTurbine;
        part auxiliaryTurbine : HydroelectricTurbine;
        part primarySluiceGate : SluiceGate;
        part emergencySluiceGate : SluiceGate;
        part spillway : Spillway;
        part grid : PowerGrid;
        part controlCenter : ControlCenter;
        part upstreamLevelSensor : WaterLevelSensor;
        part downstreamLevelSensor : WaterLevelSensor;
        part inflowMeter : FlowMeter;
        part outflowMeter : FlowMeter;
    }

    requirement def WaterLevelRegulationReq {
        doc /* The system shall maintain reservoir water level within operational bounds. */
        subject reservoir : ReservoirBasin;
        require constraint {
            reservoir.currentVolume >= 0.25 * reservoir.capacity and
            reservoir.currentVolume <= 0.95 * reservoir.capacity
        }
    }

    requirement def FloodProtectionReq {
        doc /* The system shall prevent downstream flooding by controlling discharge. */
        subject system : HengsteyseeHydropowerSystem;
        require constraint {
            system.outflowMeter.flowReading.measuredFlow <= 300.0 [m^3/s]
        }
    }

    requirement def PowerGenerationReq {
        doc /* The system shall generate hydroelectric power efficiently. */
        subject turbine : HydroelectricTurbine;
        require constraint {
            turbine.efficiency >= 0.85 and
            turbine.powerOutput.electricalOutput.power >= 1000.0 [kW]
        }
    }

    requirement def StructuralSafetyReq {
        doc /* The dam structure shall maintain integrity under all conditions. */
        subject dam : Dam;
        require constraint {
            dam.structure.structuralIntegrity >= 0.95
        }
    }

    requirement def EnvironmentalFlowReq {
        doc /* The system shall maintain minimum environmental flow downstream. */
        subject system : HengsteyseeHydropowerSystem;
        require constraint {
            system.outflowMeter.flowReading.measuredFlow >= 8.0 [m^3/s]
        }
    }

    part hengsteyseeSystem : HengsteyseeHydropowerSystem {
        attribute :>> systemMode = SystemMode::normal;
        
        part :>> reservoir {
            attribute :>> currentVolume = 2800000.0 [m^3];
        }
        
        part :>> dam;
        
        part :>> mainTurbine {
            attribute :>> currentState = TurbineState::running;
        }
        
        part :>> auxiliaryTurbine {
            attribute :>> ratedPower = 1500.0 [kW];
        }
        
        part :>> primarySluiceGate {
            attribute :>> currentOpening = 35.0;
        }
        
        part :>> emergencySluiceGate {
            attribute :>> currentOpening = 0.0;
        }
        
        part :>> spillway;
        
        part :>> grid;
        
        part :>> controlCenter {
            attribute :>> targetReservoirLevel = 96.0 [m];
        }
        
        part :>> upstreamLevelSensor;
        part :>> downstreamLevelSensor;
        part :>> inflowMeter;
        part :>> outflowMeter;
        
        connection reservoirToTurbine connect 
            reservoir.outflowPort to mainTurbine.waterInlet;
        
        connection turbineToDownstream connect 
            mainTurbine.waterOutlet to reservoir.outflowPort;
        
        connection reservoirToSluice connect 
            reservoir.outflowPort to primarySluiceGate.waterInlet;
        
        connection sluiceToDownstream connect 
            primarySluiceGate.waterOutlet to reservoir.outflowPort;
        
        connection turbineToGrid connect 
            mainTurbine.powerOutput to grid.gridConnection;
        
        connection auxTurbineToGrid connect 
            auxiliaryTurbine.powerOutput to grid.gridConnection;
        
        connection controlToGate connect 
            controlCenter.controlOutputs.gateCommand to 
            primarySluiceGate.controlPort.controlCommand;
        
        connection controlToTurbine connect 
            controlCenter.controlOutputs.turbineCommand to 
            mainTurbine.controlPort.controlCommand;
        
        connection levelSensorToControl connect 
            upstreamLevelSensor.levelReading.measuredLevel to 
            controlCenter.sensorInputs.reservoirLevel;
        
        connection inflowToControl connect 
            inflowMeter.flowReading.measuredFlow to 
            controlCenter.sensorInputs.inflowRate;
        
        connection outflowToControl connect 
            outflowMeter.flowReading.measuredFlow to 
            controlCenter.sensorInputs.outflowRate;
        
        perform action waterLevelManagement : ManageWaterLevel;
        
        exhibit state reservoirOperation : ReservoirOperationStates {
            in waterLevel = reservoir.normalLevel;
            in maxLevel = reservoir.maxLevel;
            in minLevel = reservoir.minLevel;
            in normalLevel = reservoir.normalLevel;
        }
    }

    satisfy WaterLevelRegulationReq by hengsteyseeSystem.reservoir;
    satisfy FloodProtectionReq by hengsteyseeSystem;
    satisfy PowerGenerationReq by hengsteyseeSystem.mainTurbine;
    satisfy StructuralSafetyReq by hengsteyseeSystem.dam;
    satisfy EnvironmentalFlowReq by hengsteyseeSystem;
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    private import NumericalFunctions::*;
    private import HengsteyseeHydropowerSystem::*;

    part hengsteyseeSystem : WaterLevelSensor {
        exhibit state sm : ReservoirOperationStates;
    }

    action orchestrator {
        attribute testCurrentOpening : GateOpeningValue = 0.0;
        attribute testInflowRate : FlowRateValue;
        action increaseDischargeProbe : AdjustGateOpening {
            in levelDeviation = 0.0;
            in currentOpening = testCurrentOpening;
            in inflowRate = testInflowRate;
        }
        first increaseDischargeProbe;
    }
}
