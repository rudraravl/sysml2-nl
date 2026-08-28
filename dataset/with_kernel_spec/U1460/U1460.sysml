package CoastalOilTerminalFacility {
    private import ScalarValues::Real;
    private import ScalarValues::Boolean;

    unit def cubicMeter;
    unit def pascal;
    unit def kelvin;
    unit def cubicMeterPerSecond;

    value type Volume :> Real { unit cubicMeter; }
    value type Pressure :> Real { unit pascal; }
    value type Temperature :> Real { unit kelvin; }
    value type FlowRate :> Real { unit cubicMeterPerSecond; }

    item def PetroleumProduct;
    item def CrudeOil :> PetroleumProduct;
    item def Diesel :> PetroleumProduct;
    item def Gasoline :> PetroleumProduct;
    item def BlendedProduct :> PetroleumProduct;

    item def SensorData {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        attribute level : Volume;
        attribute flowRate : FlowRate;
    }

    item def ShutdownCommand {
        attribute emergencyActive : Boolean;
    }

    port def ProductPort {
        out item product : PetroleumProduct;
    }

    port def SensorDataPort {
        out item data : SensorData;
    }

    port def ShutdownCommandPort {
        out item command : ShutdownCommand;
    }

    action def ExtendAndConnect {
        out connected : Boolean;
    }

    action def PumpFluid {
        in fluidIn : PetroleumProduct;
        out fluidOut : PetroleumProduct;
    }

    action def MeasureFlow {
        in productIn : PetroleumProduct;
        out productOut : PetroleumProduct;
        out measuredVolume : Volume;
    }

    action def DirectFlow {
        in productIn : PetroleumProduct;
        out productOut : PetroleumProduct;
    }

    action def BlendProducts {
        in productA : PetroleumProduct;
        in productB : PetroleumProduct;
        out blendedProduct : PetroleumProduct;
    }

    action def MonitorConditions {
        in sensorData : SensorData;
        out hazardDetected : Boolean;
    }

    action def TriggerEmergencyShutdown {
        in hazardDetected : Boolean;
        out command : ShutdownCommand;
    }

    action def ReceiveOil {
        action extendArms : ExtendAndConnect;
        action pump : PumpFluid;
        action meter : MeasureFlow;
        action direct : DirectFlow;
        first start;
        then extendArms;
        then pump;
        then meter;
        then direct;
        then done;
    }

    action def DispatchOil {
        action direct : DirectFlow;
        action pump : PumpFluid;
        action meter : MeasureFlow;
        first start;
        then direct;
        then pump;
        then meter;
        then done;
    }

    action def InternalTransfer {
        action pump : PumpFluid;
        action direct : DirectFlow;
        first start;
        then pump;
        then direct;
        then done;
    }

    part def TankerVessel {
        port oilPort : ProductPort;
        item cargo : PetroleumProduct;
    }

    part def LoadingArm {
        port vesselPort : ~ProductPort;
        port terminalPort : ProductPort;
        perform action extendAndConnect : ExtendAndConnect;
    }

    part def ShutoffValve {
        port inlet : ~ProductPort;
        port outlet : ProductPort;
        port commandIn : ~ShutdownCommandPort;
    }

    part def PumpingStation {
        port suctionPort : ~ProductPort;
        port dischargePort : ProductPort;
        port sensorData : SensorDataPort;
        perform action pump : PumpFluid {
            in fluidIn = suctionPort.product;
            out fluidOut = dischargePort.product;
        }
    }

    part def Pipeline {
        port inlet : ~ProductPort;
        port outlet : ProductPort;
        port sensorData : SensorDataPort;
        flow of product : PetroleumProduct from inlet.product to outlet.product;
    }

    part def MeteringSystem {
        port inlet : ~ProductPort;
        port outlet : ProductPort;
        port sensorData : SensorDataPort;
        attribute cumulativeVolume : Volume;
        perform action meter : MeasureFlow {
            in productIn = inlet.product;
            out productOut = outlet.product;
            out measuredVolume = cumulativeVolume;
        }
    }

    part def ManifoldSystem {
        port inlet1 : ~ProductPort;
        port inlet2 : ~ProductPort;
        port outlet1 : ProductPort;
        port outlet2 : ProductPort;
        port outlet3 : ProductPort;
        perform action directFlow : DirectFlow;
    }

    part def StorageTank {
        port inlet : ~ProductPort;
        port outlet : ProductPort;
        port sensorData : SensorDataPort;
        item storedProduct : PetroleumProduct;
        attribute capacity : Volume;
        attribute currentLevel : Volume;
        attribute currentPressure : Pressure;
        attribute currentTemperature : Temperature;
        attribute startFilling : Boolean;
        attribute tankFull : Boolean;
        attribute startDischarge : Boolean;
        attribute tankEmpty : Boolean;
        state machine tankState {
            state empty;
            state filling;
            state full;
            state discharging;
            transition from empty to filling when startFilling;
            transition from filling to full when tankFull;
            transition from full to discharging when startDischarge;
            transition from discharging to empty when tankEmpty;
        }
    }

    part def CrudeOilTank :> StorageTank;
    part def DieselTank :> StorageTank;
    part def GasolineTank :> StorageTank;

    part def BlendingUnit {
        port inletA : ~ProductPort;
        port inletB : ~ProductPort;
        port outlet : ProductPort;
        perform action blend : BlendProducts {
            in productA = inletA.product;
            in productB = inletB.product;
            out blendedProduct = outlet.product;
        }
    }

    part def SafetyMonitoringSystem {
        port sensorInput : ~SensorDataPort;
        port shutdownOutput : ShutdownCommandPort;
        attribute abnormalReading : Boolean;
        attribute criticalIssue : Boolean;
        attribute reset : Boolean;
        state machine monitoringState {
            state normal;
            state alert;
            state emergency;
            transition from normal to alert when abnormalReading;
            transition from alert to emergency when criticalIssue;
            transition from emergency to normal when reset;
        }
        perform action monitor : MonitorConditions {
            in sensorData = sensorInput.data;
        }
        perform action shutdown : TriggerEmergencyShutdown {
            in hazardDetected = monitor.hazardDetected;
            out command = shutdownOutput.command;
        }
    }

    part def ExternalPipelineNetwork {
        port inlet : ~ProductPort;
    }

    part def Terminal {
        part loadingArm : LoadingArm;
        part receptionValve : ShutoffValve;
        part receptionPump : PumpingStation;
        part receptionPipeline : Pipeline;
        part receptionMeter : MeteringSystem;
        part receptionManifold : ManifoldSystem;

        part crudeTank : CrudeOilTank;
        part dieselTank : DieselTank;
        part gasolineTank : GasolineTank;

        part transferPump : PumpingStation;
        part transferPipeline : Pipeline;
        part transferManifold : ManifoldSystem;

        part blendingUnit : BlendingUnit;

        part dispatchManifold : ManifoldSystem;
        part dispatchValve : ShutoffValve;
        part dispatchPump : PumpingStation;
        part dispatchPipeline : Pipeline;
        part dispatchMeter : MeteringSystem;

        part safetySystem : SafetyMonitoringSystem;

        port externalConnection : ProductPort;

        flow of product : PetroleumProduct
            from loadingArm.terminalPort.product to receptionValve.inlet.product;
        flow of product : PetroleumProduct
            from receptionValve.outlet.product to receptionPump.suctionPort.product;
        flow of product : PetroleumProduct
            from receptionPump.dischargePort.product to receptionPipeline.inlet.product;
        flow of product : PetroleumProduct
            from receptionPipeline.outlet.product to receptionMeter.inlet.product;
        flow of product : PetroleumProduct
            from receptionMeter.outlet.product to receptionManifold.inlet1.product;

        connect receptionManifold.outlet1 to crudeTank.inlet;
        connect receptionManifold.outlet2 to dieselTank.inlet;
        connect receptionManifold.outlet3 to gasolineTank.inlet;

        flow of product : PetroleumProduct
            from crudeTank.outlet.product to transferPump.suctionPort.product;
        flow of product : PetroleumProduct
            from transferPump.dischargePort.product to transferPipeline.inlet.product;
        flow of product : PetroleumProduct
            from transferPipeline.outlet.product to transferManifold.inlet1.product;

        connect transferManifold.outlet1 to crudeTank.inlet;
        connect transferManifold.outlet2 to dieselTank.inlet;
        connect transferManifold.outlet3 to gasolineTank.inlet;

        flow of product : PetroleumProduct
            from dieselTank.outlet.product to blendingUnit.inletA.product;
        flow of product : PetroleumProduct
            from gasolineTank.outlet.product to blendingUnit.inletB.product;
        connect blendingUnit.outlet to dispatchManifold.inlet2;

        connect crudeTank.outlet to dispatchManifold.inlet1;
        flow of product : PetroleumProduct
            from dispatchManifold.outlet1.product to dispatchValve.inlet.product;
        flow of product : PetroleumProduct
            from dispatchValve.outlet.product to dispatchPump.suctionPort.product;
        flow of product : PetroleumProduct
            from dispatchPump.dischargePort.product to dispatchPipeline.inlet.product;
        flow of product : PetroleumProduct
            from dispatchPipeline.outlet.product to dispatchMeter.inlet.product;
        flow of product : PetroleumProduct
            from dispatchMeter.outlet.product to externalConnection.product;

        connect crudeTank.sensorData to safetySystem.sensorInput;
        connect dieselTank.sensorData to safetySystem.sensorInput;
        connect gasolineTank.sensorData to safetySystem.sensorInput;
        connect receptionPump.sensorData to safetySystem.sensorInput;
        connect transferPump.sensorData to safetySystem.sensorInput;
        connect dispatchPump.sensorData to safetySystem.sensorInput;
        connect receptionPipeline.sensorData to safetySystem.sensorInput;
        connect dispatchPipeline.sensorData to safetySystem.sensorInput;

        connect safetySystem.shutdownOutput to receptionValve.commandIn;
        connect safetySystem.shutdownOutput to dispatchValve.commandIn;

        perform action receiveOil : ReceiveOil;
        perform action dispatchOil : DispatchOil;
        perform action internalTransfer : InternalTransfer;
    }

    requirement def SafeOperation {
        doc /* The terminal shall continuously monitor pressure, temperature, and flow and automatically trigger emergency shutdown when critical thresholds are exceeded. */
    }

    requirement def AccurateMetering {
        doc /* The receiving and dispatch metering systems shall measure transferred oil volume for commercial and inventory control. */
    }

    requirement def ProductSegregation {
        doc /* Crude oil, diesel, and gasoline shall be stored in dedicated tanks to prevent contamination. */
    }

    requirement def ReceptionCapability {
        doc /* The terminal shall receive petroleum products from tanker vessels via loading arms and pumping stations. */
    }

    requirement def DistributionCapability {
        doc /* The terminal shall dispatch finished products through dispatch pumps, manifolds, and metering systems into external pipeline networks. */
    }

    part terminal : Terminal {
        part tankerVessel : TankerVessel;
        part externalPipeline : ExternalPipelineNetwork;

        connect tankerVessel.oilPort to loadingArm.vesselPort;
        connect externalConnection to externalPipeline.inlet;
    }

    requirement safeOp : SafeOperation;
    requirement accurateMetering : AccurateMetering;
    requirement productSegregation : ProductSegregation;
    requirement receptionCapability : ReceptionCapability;
    requirement distributionCapability : DistributionCapability;
}
