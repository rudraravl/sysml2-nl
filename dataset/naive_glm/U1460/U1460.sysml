package CoastalOilTerminal {
    import ScalarValues::*;
    import ISQ::*;
    import ISQVolume::*;
    import ISQPressure::*;
    import ISQThermodynamicTemperature::*;
    import ISQFlowRate::*;

    // ===== Value Types =====
    value type VolumeFlowRate :> Real { unit 'm3/s'; }
    value type TankLevel :> Real { unit 'm3'; }
    value type PercentFull :> Real { unit '%'; }
    value type TankPressure :> Real { unit 'bar'; }
    value type TankTemperature :> Real { unit 'degC'; }
    value type PipeDiameter :> Real { unit 'mm'; }
    value type PipeLength :> Real { unit 'm'; }
    value type PowerRating :> Real { unit 'kW'; }
    value type TankCapacity :> Real { unit 'm3'; }

    // ===== Item Types =====
    item def PetroleumProduct {
        attribute grade : String;
        attribute density : Real { unit 'kg/m3'; }
        attribute flashPoint : Real { unit 'degC'; }
    }
    item def CrudeOil :> PetroleumProduct {
        attribute grade = 'crude';
        attribute density = 870.0;
        attribute flashPoint = 60.0;
    }
    item def Diesel :> PetroleumProduct {
        attribute grade = 'diesel';
        attribute density = 832.0;
        attribute flashPoint = 52.0;
    }
    item def Gasoline :> PetroleumProduct {
        attribute grade = 'gasoline';
        attribute density = 740.0;
        attribute flashPoint = -43.0;
    }

    // ===== Port Definitions =====
    port def FluidPort {
        attribute flowRate : VolumeFlowRate;
        item petroleumProduct : PetroleumProduct;
    }
    port def ControlPort {
        attribute signalActive : Boolean;
    }
    port def SensorDataPort {
        attribute pressure : TankPressure;
        attribute temperature : TankTemperature;
        attribute level : TankLevel;
    }

    // ===== Interfaces =====
    interface def FluidConnection {
        end supplier : FluidPort;
        end consumer : FluidPort;
        flow of petroleumProduct from supplier to consumer;
    }
    interface def ControlConnection {
        end controller : ControlPort;
        end controlled : ControlPort;
    }
    interface def SensorDataConnection {
        end sensor : SensorDataPort;
        end monitor : SensorDataPort;
    }

    // ===== Loading Arm =====
    part def LoadingArm {
        attribute maxFlowRate : VolumeFlowRate = 0.5;
        attribute armLength : Real { unit 'm'; } = 30.0;
        attribute articulated : Boolean = true;
        port vesselConnection : FluidPort;
        port terminalConnection : FluidPort;
        port controlInput : ControlPort;

        state def OperationalState {
            entry; then Retracted;
            state Retracted;
            state Extending;
            state Connected;
            state Retracting;
            transition first Extending then Connected
                when controlInput.signalActive == true;
            transition first Retracted then Extending
                when controlInput.signalActive == true;
            transition Connected then Retracting
                when controlInput.signalActive == false;
            transition Retracting then Retracted
                when controlInput.signalActive == false;
        }
    }

    // ===== Pumping Station =====
    part def PumpingStation {
        attribute pumpPower : PowerRating = 500.0;
        attribute maxFlowRate : VolumeFlowRate = 0.8;
        attribute isRunning : Boolean = false;
        port inlet : FluidPort;
        port outlet : FluidPort;
        port controlInput : ControlPort;

        action def PumpOperation {
            in product : PetroleumProduct;
            in flowCmd : VolumeFlowRate;
            out actualFlow : VolumeFlowRate;
        }
        perform action pumpOperation : PumpOperation;

        state def PumpState {
            entry; then Idle;
            state Idle;
            state Running;
            state Faulted;
            transition Idle then Running
                when controlInput.signalActive == true;
            transition Running then Idle
                when controlInput.signalActive == false;
            transition Running then Faulted
                when outlet.pressure > 15.0;
            transition Faulted then Idle
                when controlInput.signalActive == false;
        }
    }

    // ===== Pipeline =====
    part def Pipeline {
        attribute diameter : PipeDiameter = 600.0;
        attribute length : PipeLength = 500.0;
        attribute maxPressure : TankPressure = 16.0;
        attribute currentPressure : TankPressure = 0.0;
        port inlet : FluidPort;
        port outlet : FluidPort;
        port sensorOutput : SensorDataPort;

        action def FlowMonitoring {
            in currentFlow : VolumeFlowRate;
            out measuredPressure : TankPressure;
        }
        perform action flowMonitoring : FlowMonitoring;
    }

    // ===== Metering System =====
    part def MeteringSystem {
        attribute accuracyClass : Real = 0.1;
        attribute cumulativeVolume : Real { unit 'm3'; } = 0.0;
        port inlet : FluidPort;
        port outlet : FluidPort;
        port dataOutput : SensorDataPort;

        action def Metering {
            in product : PetroleumProduct;
            in flowRate : VolumeFlowRate;
            out measuredVolume : Real { unit 'm3'; };
        }
        perform action metering : Metering;
    }

    // ===== Manifold System =====
    part def ManifoldSystem {
        attribute valveCount : Integer = 12;
        attribute activeRoute : String = 'none';
        port inlet1 : FluidPort;
        port inlet2 : FluidPort;
        port outlet1 : FluidPort;
        port outlet2 : FluidPort;
        port outlet3 : FluidPort;
        port controlInput : ControlPort;

        action def RouteSelection {
            in sourceId : String;
            in destinationId : String;
            out routeConfigured : Boolean;
        }
        perform action routeSelection : RouteSelection;
    }

    // ===== Storage Tank =====
    part def StorageTank {
        attribute tankId : String;
        attribute capacity : TankCapacity = 50000.0;
        attribute currentLevel : TankLevel = 0.0;
        attribute currentPressure : TankPressure = 1.0;
        attribute currentTemperature : TankTemperature = 25.0;
        attribute maxLevel : TankLevel = 48000.0;
        attribute minLevel : TankLevel = 1000.0;
        attribute maxPressure : TankPressure = 2.0;
        attribute maxTemperature : TankTemperature = 55.0;
        port inlet : FluidPort;
        port outlet : FluidPort;
        port sensorOutput : SensorDataPort;
        port controlInput : ControlPort;

        action def FillTank {
            in product : PetroleumProduct;
            in flowRate : VolumeFlowRate;
            out newLevel : TankLevel;
        }
        action def DischargeTank {
            in flowRate : VolumeFlowRate;
            out newLevel : TankLevel;
        }
        action def MonitorTankConditions {
            out level : TankLevel;
            out pressure : TankPressure;
            out temperature : TankTemperature;
        }

        perform action fillTank : FillTank;
        perform action dischargeTank : DischargeTank;
        perform action monitorTankConditions : MonitorTankConditions;

        state def TankOperationalCycle {
            entry; then Empty;
            state Empty;
            state Filling;
            state Full;
            state Discharging;
            state Maintenance;
            transition Empty then Filling
                when inlet.flowRate > 0.0;
            transition Filling then Full
                when currentLevel >= maxLevel;
            transition Filling then Full
                when inlet.flowRate == 0.0 and currentLevel > minLevel;
            transition Full then Discharging
                when outlet.flowRate > 0.0;
            transition Discharging then Empty
                when currentLevel <= minLevel;
            transition Discharging then Filling
                when inlet.flowRate > 0.0 and outlet.flowRate == 0.0;
            transition any then Maintenance
                when controlInput.signalActive == false;
            transition Maintenance then Empty
                when controlInput.signalActive == true and currentLevel <= minLevel;
        }
    }

    // ===== Dispatch Pump =====
    part def DispatchPump {
        attribute pumpPower : PowerRating = 750.0;
        attribute maxFlowRate : VolumeFlowRate = 1.2;
        attribute isRunning : Boolean = false;
        port inlet : FluidPort;
        port outlet : FluidPort;
        port controlInput : ControlPort;

        action def DispatchOperation {
            in product : PetroleumProduct;
            in flowCmd : VolumeFlowRate;
            out actualFlow : VolumeFlowRate;
        }
        perform action dispatchOperation : DispatchOperation;

        state def DispatchPumpState {
            entry; then Standby;
            state Standby;
            state Active;
            state Faulted;
            transition Standby then Active
                when controlInput.signalActive == true;
            transition Active then Standby
                when controlInput.signalActive == false;
            transition Active then Faulted
                when outlet.pressure > 20.0;
        }
    }

    // ===== Safety Monitoring System =====
    part def SafetyMonitoringSystem {
        attribute systemActive : Boolean = true;
        attribute alarmThresholdPressure : TankPressure = 18.0;
        attribute alarmThresholdTemperature : TankTemperature = 60.0;
        attribute leakDetectionEnabled : Boolean = true;
        port tankSensorInput1 : SensorDataPort;
        port tankSensorInput2 : SensorDataPort;
        port tankSensorInput3 : SensorDataPort;
        port pumpSensorInput1 : SensorDataPort;
        port pumpSensorInput2 : SensorDataPort;
        port pipelineSensorInput1 : SensorDataPort;
        port pipelineSensorInput2 : SensorDataPort;
        port emergencyShutdownOutput : ControlPort;

        action def ContinuousMonitoring {
            in tankPressure : TankPressure;
            in tankTemperature : TankTemperature;
            in tankLevel : TankLevel;
            in pumpPressure : TankPressure;
            in pipelinePressure : TankPressure;
            out emergencyTrigger : Boolean;
        }

        perform action continuousMonitoring : ContinuousMonitoring;

        state def SafetySystemState {
            entry; then Normal;
            state Normal;
            state Alert;
            state EmergencyShutdown;
            transition Normal then Alert
                when tankSensorInput1.pressure > 18.0
                or tankSensorInput2.pressure > 18.0
                or tankSensorInput3.pressure > 18.0
                or pumpSensorInput1.pressure > 18.0
                or pumpSensorInput2.pressure > 18.0
                or pipelineSensorInput1.pressure > 18.0
                or pipelineSensorInput2.pressure > 18.0;
            transition Alert then EmergencyShutdown
                when tankSensorInput1.pressure > 25.0
                or tankSensorInput2.pressure > 25.0
                or tankSensorInput3.pressure > 25.0;
            transition Alert then Normal
                when tankSensorInput1.pressure <= 18.0
                and tankSensorInput2.pressure <= 18.0
                and tankSensorInput3.pressure <= 18.0
                and pumpSensorInput1.pressure <= 18.0
                and pumpSensorInput2.pressure <= 18.0
                and pipelineSensorInput1.pressure <= 18.0
                and pipelineSensorInput2.pressure <= 18.0;
            transition EmergencyShutdown then Normal
                when emergencyShutdownOutput.signalActive == false;
        }
    }

    // ===== Tank Farm =====
    part def TankFarm {
        part crudeOilTank : StorageTank {
            attribute tankId = 'T-CR-001';
            attribute capacity = 50000.0;
            attribute maxLevel = 48000.0;
        }
        part dieselTank : StorageTank {
            attribute tankId = 'T-DS-001';
            attribute capacity = 40000.0;
            attribute maxLevel = 38000.0;
        }
        part gasolineTank : StorageTank {
            attribute tankId = 'T-GS-001';
            attribute capacity = 35000.0;
            attribute maxLevel = 33000.0;
        }

        action def InternalTransfer {
            in sourceTank : StorageTank;
            in destinationTank : StorageTank;
            in transferVolume : Real { unit 'm3'; };
            out transferComplete : Boolean;
        }
        action def BlendingOperation {
            in productA : PetroleumProduct;
            in productB : PetroleumProduct;
            in ratioA : Real;
            in ratioB : Real;
            out blendedProduct : PetroleumProduct;
        }

        perform action internalTransfer : InternalTransfer;
        perform action blendingOperation : BlendingOperation;
    }

    // ===== Vessel =====
    part def TankerVessel {
        attribute vesselName : String;
        attribute cargoCapacity : TankCapacity = 100000.0;
        attribute currentCargo : TankLevel = 80000.0;
        port manifoldConnection : FluidPort;
    }

    // ===== External Pipeline Network =====
    part def ExternalPipelineNetwork {
        attribute networkId : String = 'PLN-001';
        attribute destination : String = 'Refinery';
        port receivingPort : FluidPort;
    }

    // ===== Coastal Oil Terminal (Top-Level) =====
    part def CoastalOilTerminalFacility {
        // Vessel interface
        part tankerVessel : TankerVessel {
            attribute vesselName = 'MT Ocean Carrier';
        }

        // Loading arms
        part loadingArm1 : LoadingArm;
        part loadingArm2 : LoadingArm;

        // Receiving pumping stations
        part receivingPumpStation1 : PumpingStation {
            attribute pumpPower = 500.0;
        }
        part receivingPumpStation2 : PumpingStation {
            attribute pumpPower = 500.0;
        }

        // Receiving pipelines
        part receivingPipeline1 : Pipeline {
            attribute diameter = 600.0;
            attribute length = 200.0;
        }
        part receivingPipeline2 : Pipeline {
            attribute diameter = 600.0;
            attribute length = 200.0;
        }

        // Receiving metering systems
        part receivingMeter1 : MeteringSystem;
        part receivingMeter2 : MeteringSystem;

        // Receiving manifold
        part receivingManifold : ManifoldSystem {
            attribute valveCount = 12;
        }

        // Tank farm
        part tankFarm : TankFarm;

        // Dispatch manifold
        part dispatchManifold : ManifoldSystem {
            attribute valveCount = 8;
        }

        // Dispatch metering
        part dispatchMeter1 : MeteringSystem;
        part dispatchMeter2 : MeteringSystem;

        // Dispatch pumps
        part dispatchPump1 : DispatchPump {
            attribute pumpPower = 750.0;
        }
        part dispatchPump2 : DispatchPump {
            attribute pumpPower = 750.0;
        }

        // Dispatch pipelines
        part dispatchPipeline1 : Pipeline {
            attribute diameter = 500.0;
            attribute length = 300.0;
        }
        part dispatchPipeline2 : Pipeline {
            attribute diameter = 500.0;
            attribute length = 300.0;
        }

        // External network
        part externalNetwork : ExternalPipelineNetwork;

        // Safety monitoring system
        part safetySystem : SafetyMonitoringSystem;

        // ===== Connections =====
        // Vessel to loading arms
        interface vesselToArm1 : FluidConnection
            connect tankerVessel.manifoldConnection to loadingArm1.vesselConnection;
        interface vesselToArm2 : FluidConnection
            connect tankerVessel.manifoldConnection to loadingArm2.vesselConnection;

        // Loading arms to receiving pumps
        interface arm1ToPump1 : FluidConnection
            connect loadingArm1.terminalConnection to receivingPumpStation1.inlet;
        interface arm2ToPump2 : FluidConnection
            connect loadingArm2.terminalConnection to receivingPumpStation2.inlet;

        // Pumps to receiving pipelines
        interface pump1ToPipeline1 : FluidConnection
            connect receivingPumpStation1.outlet to receivingPipeline1.inlet;
        interface pump2ToPipeline2 : FluidConnection
            connect receivingPumpStation2.outlet to receivingPipeline2.inlet;

        // Pipelines to metering systems
        interface pipeline1ToMeter1 : FluidConnection
            connect receivingPipeline1.outlet to receivingMeter1.inlet;
        interface pipeline2ToMeter2 : FluidConnection
            connect receivingPipeline2.outlet to receivingMeter2.inlet;

        // Metering to receiving manifold
        interface meter1ToManifold : FluidConnection
            connect receivingMeter1.outlet to receivingManifold.inlet1;
        interface meter2ToManifold : FluidConnection
            connect receivingMeter2.outlet to receivingManifold.inlet2;

        // Receiving manifold to tank farm
        interface manifoldToCrudeTank : FluidConnection
            connect receivingManifold.outlet1 to tankFarm.crudeOilTank.inlet;
        interface manifoldToDieselTank : FluidConnection
            connect receivingManifold.outlet2 to tankFarm.dieselTank.inlet;
        interface manifoldToGasolineTank : FluidConnection
            connect receivingManifold.outlet3 to tankFarm.gasolineTank.inlet;

        // Tank farm to dispatch manifold
        interface crudeTankToDispatchManifold : FluidConnection
            connect tankFarm.crudeOilTank.outlet to dispatchManifold.inlet1;
        interface dieselTankToDispatchManifold : FluidConnection
            connect tankFarm.dieselTank.outlet to dispatchManifold.inlet2;
        interface gasolineTankToDispatchManifold : FluidConnection
            connect tankFarm.gasolineTank.outlet to dispatchManifold.inlet2;

        // Dispatch manifold to dispatch metering
        interface dispatchManifoldToMeter1 : FluidConnection
            connect dispatchManifold.outlet1 to dispatchMeter1.inlet;
        interface dispatchManifoldToMeter2 : FluidConnection
            connect dispatchManifold.outlet2 to dispatchMeter2.inlet;

        // Dispatch metering to dispatch pumps
        interface dispatchMeter1ToPump1 : FluidConnection
            connect dispatchMeter1.outlet to dispatchPump1.inlet;
        interface dispatchMeter2ToPump2 : FluidConnection
            connect dispatchMeter2.outlet to dispatchPump2.inlet;

        // Dispatch pumps to dispatch pipelines
        interface dispatchPump1ToPipeline1 : FluidConnection
            connect dispatchPump1.outlet to dispatchPipeline1.inlet;
        interface dispatchPump2ToPipeline2 : FluidConnection
            connect dispatchPump2.outlet to dispatchPipeline2.inlet;

        // Dispatch pipelines to external network
        interface dispatchPipeline1ToExternal : FluidConnection
            connect dispatchPipeline1.outlet to externalNetwork.receivingPort;
        interface dispatchPipeline2ToExternal : FluidConnection
            connect dispatchPipeline2.outlet to externalNetwork.receivingPort;

        // Safety system sensor connections
        interface safetyTank1 : SensorDataConnection
            connect tankFarm.crudeOilTank.sensorOutput to safetySystem.tankSensorInput1;
        interface safetyTank2 : SensorDataConnection
            connect tankFarm.dieselTank.sensorOutput to safetySystem.tankSensorInput2;
        interface safetyTank3 : SensorDataConnection
            connect tankFarm.gasolineTank.sensorOutput to safetySystem.tankSensorInput3;
        interface safetyPump1 : SensorDataConnection
            connect receivingPumpStation1.outlet to safetySystem.pumpSensorInput1;
        interface safetyPump2 : SensorDataConnection
            connect receivingPumpStation2.outlet to safetySystem.pumpSensorInput2;
        interface safetyPipeline1 : SensorDataConnection
            connect receivingPipeline1.sensorOutput to safetySystem.pipelineSensorInput1;
        interface safetyPipeline2 : SensorDataConnection
            connect receivingPipeline2.sensorOutput to safetySystem.pipelineSensorInput2;

        // Safety system emergency shutdown control connections
        interface eshutdownPump1 : ControlConnection
            connect safetySystem.emergencyShutdownOutput to receivingPumpStation1.controlInput;
        interface eshutdownPump2 : ControlConnection
            connect safetySystem.emergencyShutdownOutput to receivingPumpStation2.controlInput;
        interface eshutdownDispatchPump1 : ControlConnection
            connect safetySystem.emergencyShutdownOutput to dispatchPump1.controlInput;
        interface eshutdownDispatchPump2 : ControlConnection
            connect safetySystem.emergencyShutdownOutput to dispatchPump2.controlInput;
        interface eshutdownTank1 : ControlConnection
            connect safetySystem.emergencyShutdownOutput to tankFarm.crudeOilTank.controlInput;
        interface eshutdownTank2 : ControlConnection
            connect safetySystem.emergencyShutdownOutput to tankFarm.dieselTank.controlInput;
        interface eshutdownTank3 : ControlConnection
            connect safetySystem.emergencyShutdownOutput to tankFarm.gasolineTank.controlInput;
        interface eshutdownLoadingArm1 : ControlConnection
            connect safetySystem.emergencyShutdownOutput to loadingArm1.controlInput;
        interface eshutdownLoadingArm2 : ControlConnection
            connect safetySystem.emergencyShutdownOutput to loadingArm2.controlInput;
    }

    // ===== Requirements =====
    requirement def TerminalReceptionRequirement {
        subject facility : CoastalOilTerminalFacility;
        objective {
            doc /* The terminal shall receive petroleum products from marine tanker vessels via loading arms and pumping stations. */
        }
        require facility.loadingArm1.articulated == true
            and facility.loadingArm2.articulated == true;
        require facility.receivingPumpStation1.maxFlowRate >= 0.5
            and facility.receivingPumpStation2.maxFlowRate >= 0.5;
    }

    requirement def MeteringAccuracyRequirement {
        subject meteringSystem : MeteringSystem;
        objective {
            doc /* All metering systems shall measure transferred volume with accuracy of 0.1% or better. */
        }
        require meteringSystem.accuracyClass <= 0.1;
    }

    requirement def StorageSegregationRequirement {
        subject tankFarm : TankFarm;
        objective {
            doc /* Storage tanks shall be segregated by product type to prevent contamination. */
        }
        require tankFarm.crudeOilTank.tankId != tankFarm.dieselTank.tankId
            and tankFarm.dieselTank.tankId != tankFarm.gasolineTank.tankId
            and tankFarm.crudeOilTank.tankId != tankFarm.gasolineTank.tankId;
    }

    requirement def TankSafetyLimitsRequirement {
        subject storageTank : StorageTank;
        objective {
            doc /* Each storage tank shall operate within safe pressure, temperature, and level limits. */
        }
        require storageTank.currentPressure <= storageTank.maxPressure;
        require storageTank.currentTemperature <= storageTank.maxTemperature;
        require storageTank.currentLevel <= storageTank.maxLevel;
        require storageTank.currentLevel >= storageTank.minLevel;
    }

    requirement def EmergencyShutdownRequirement {
        subject safetySystem : SafetyMonitoringSystem;
        objective {
            doc /* The safety monitoring system shall automatically trigger emergency shutdown upon detecting critical pressure abnormalities or leaks. */
        }
        require safetySystem.systemActive == true;
        require safetySystem.leakDetectionEnabled == true;
        require safetySystem.alarmThresholdPressure <= 18.0;
    }

    requirement def DispatchCapabilityRequirement {
        subject facility : CoastalOilTerminalFacility;
        objective {
            doc /* The terminal shall dispatch finished products through dispatch pumps, manifold, metering, and pipelines to the external network. */
        }
        require facility.dispatchPump1.maxFlowRate >= 1.0
            and facility.dispatchPump2.maxFlowRate >= 1.0;
        require facility.dispatchManifold.valveCount >= 4;
    }

    requirement def InternalTransferRequirement {
        subject tankFarm : TankFarm;
        objective {
            doc /* The terminal shall support internal transfers between tanks and blending of products. */
        }
        require tankFarm.internalTransfer.transferComplete == true;
        require tankFarm.blendingOperation.blendedProduct != null;
    }

    requirement TerminalReception : TerminalReceptionRequirement {
        subject :>> facility = CoastalOilTerminalFacility;
    }
    requirement MeteringAccuracy : MeteringAccuracyRequirement {
        subject :>> meteringSystem = CoastalOilTerminalFacility.receivingMeter1;
    }
    requirement StorageSegregation : StorageSegregationRequirement {
        subject :>> tankFarm = CoastalOilTerminalFacility.tankFarm;
    }
    requirement TankSafetyLimits : TankSafetyLimitsRequirement {
        subject :>> storageTank = CoastalOilTerminalFacility.tankFarm.crudeOilTank;
    }
    requirement EmergencyShutdown : EmergencyShutdownRequirement {
        subject :>> safetySystem = CoastalOilTerminalFacility.safetySystem;
    }
    requirement DispatchCapability : DispatchCapabilityRequirement {
        subject :>> facility = CoastalOilTerminalFacility;
    }
    requirement InternalTransfer : InternalTransferRequirement {
        subject :>> tankFarm = CoastalOilTerminalFacility.tankFarm;
    }

    requirement TerminalSystemRequirements {
        subject terminal : CoastalOilTerminalFacility;
        satisfy TerminalReception;
        satisfy MeteringAccuracy;
        satisfy StorageSegregation;
        satisfy TankSafetyLimits;
        satisfy EmergencyShutdown;
        satisfy DispatchCapability;
        satisfy InternalTransfer;
    }
}
