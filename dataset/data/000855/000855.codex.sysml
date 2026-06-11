package BushPumpPumpingSubsystemModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def FlowRate {
        :>> unit = L / min;
        :>> quantityKind = ISQ::volumeFlowRate;
    }

    attribute def Pressure {
        :>> unit = kPa;
        :>> quantityKind = ISQ::pressure;
    }

    attribute def Volume {
        :>> unit = L;
        :>> quantityKind = ISQ::volume;
    }

    attribute def Length {
        :>> unit = m;
        :>> quantityKind = ISQ::length;
    }

    attribute def Force {
        :>> unit = N;
        :>> quantityKind = ISQ::force;
    }

    attribute def Frequency {
        :>> unit = 1 / min;
        :>> quantityKind = ISQ::frequency;
    }

    attribute def Temperature {
        :>> unit = degC;
        :>> quantityKind = ISQ::thermodynamicTemperature;
    }

    enum def FluidQuality {
        enum potable;
        enum nonPotable;
        enum contaminated;
    }

    enum def PumpOperatingMode {
        enum idle;
        enum priming;
        enum pumping;
        enum shutdown;
        enum faulted;
        enum maintenance;
    }

    enum def FaultCode {
        enum none;
        enum dryStroke;
        enum blockedRiser;
        enum outletBlocked;
        enum sealLeak;
        enum valveFailure;
        enum excessiveHandleForce;
    }

    item def Groundwater {
        attribute temperature : Temperature;
        attribute turbidityNTU : Real;
        attribute quality : FluidQuality;
    }

    item def DeliveredWater :> Groundwater {
        attribute deliveredPressure : Pressure;
        attribute deliveredFlowRate : FlowRate;
    }

    port def FluidPort {
        inout fluid : Groundwater;
        attribute pressure : Pressure;
        attribute flowRate : FlowRate;
    }

    port def MechanicalStrokePort {
        in strokeForce : Force;
        in strokeRate : Frequency;
        out reciprocatingDisplacement : Length;
    }

    port def DrainPort {
        out leakage : Groundwater;
        attribute leakageRate : FlowRate;
    }

    part def BushPumpHandle {
        attribute handleLength : Length = 1.1 [m];
        attribute maximumAppliedForce : Force = 350 [N];
        attribute nominalStrokeRate : Frequency = 35 [1 / min];

        port operatorInput : MechanicalStrokePort;

        action def ConvertOperatorMotion {
            in appliedForce : Force;
            in appliedRate : Frequency;
            out rodForce : Force;
            out rodStrokeRate : Frequency;
        }
    }

    part def PumpHead {
        attribute material : String = "galvanized steel";
        attribute maximumOutletPressure : Pressure = 250 [kPa];

        port inletFromRiser : FluidPort;
        port outletToSpout : FluidPort;
        port leakageDrain : DrainPort;

        action def DirectFlowToOutlet {
            in incomingWater : Groundwater;
            out deliveredWater : DeliveredWater;
        }
    }

    part def PumpRod {
        attribute rodLength : Length;
        attribute rodDiameter : Length = 0.016 [m];
        attribute maximumTensileForce : Force = 2500 [N];

        port handleSide : MechanicalStrokePort;
        port pistonSide : MechanicalStrokePort;
    }

    part def Cylinder {
        attribute boreDiameter : Length = 0.075 [m];
        attribute strokeLength : Length = 0.18 [m];
        attribute sweptVolume : Volume = 0.795 [L];

        port suctionPort : FluidPort;
        port dischargePort : FluidPort;
        port pistonDrive : MechanicalStrokePort;

        action def DisplaceWater {
            in pistonStroke : Length;
            in suctionWater : Groundwater;
            out pressurizedWater : DeliveredWater;
        }
    }

    part def PistonValve {
        attribute crackingPressure : Pressure = 3 [kPa];
        attribute nominalLeakageRate : FlowRate = 0.02 [L / min];

        port lowerSide : FluidPort;
        port upperSide : FluidPort;
    }

    part def FootValve {
        attribute crackingPressure : Pressure = 2 [kPa];
        attribute allowableBackLeakage : FlowRate = 0.05 [L / min];

        port wellSide : FluidPort;
        port cylinderSide : FluidPort;
    }

    part def RiserPipe {
        attribute pipeLength : Length;
        attribute internalDiameter : Length = 0.05 [m];
        attribute maximumStaticHead : Length = 40 [m];

        port lowerEnd : FluidPort;
        port upperEnd : FluidPort;
    }

    part def WellSource {
        attribute staticWaterLevel : Length;
        attribute dynamicWaterLevel : Length;
        attribute availableVolume : Volume;
        attribute sourceQuality : FluidQuality = FluidQuality::potable;

        port abstractionPoint : FluidPort;
    }

    part def DeliverySpout {
        attribute spoutHeight : Length = 1.0 [m];
        attribute nominalOutletPressure : Pressure = 20 [kPa];

        port inlet : FluidPort;
        port outlet : FluidPort;
    }

    part def UserContainer {
        attribute capacity : Volume = 20 [L];
        attribute storedVolume : Volume = 0 [L];

        port fillPort : FluidPort;

        action def ReceiveWater {
            in delivered : DeliveredWater;
            out stored : Volume;
        }
    }

    part def MaintenanceInterface {
        attribute inspectionIntervalDays : Integer = 30;
        attribute lastFault : FaultCode = FaultCode::none;

        action def Inspect {
            out detectedFault : FaultCode;
        }

        action def ReplaceSeal {
            in fault : FaultCode;
            out restored : Boolean;
        }

        action def ClearBlockage {
            in fault : FaultCode;
            out restored : Boolean;
        }
    }

    part def BushPumpSubsystem {
        attribute operatingMode : PumpOperatingMode = PumpOperatingMode::idle;
        attribute currentFault : FaultCode = FaultCode::none;
        attribute nominalFlowRate : FlowRate = 12 [L / min];
        attribute minimumFlowRate : FlowRate = 8 [L / min];
        attribute maximumHandleForce : Force = 300 [N];
        attribute maximumLiftHead : Length = 35 [m];
        attribute deliveredVolumePerStroke : Volume = 0.32 [L];

        part well : WellSource {
            :>> staticWaterLevel = 12 [m];
            :>> dynamicWaterLevel = 18 [m];
            :>> availableVolume = 50000 [L];
        }

        part handle : BushPumpHandle;
        part rod : PumpRod {
            :>> rodLength = 18.5 [m];
        }

        part pumpHead : PumpHead;
        part riser : RiserPipe {
            :>> pipeLength = 18.5 [m];
        }

        part cylinder : Cylinder;
        part footValve : FootValve;
        part pistonValve : PistonValve;
        part spout : DeliverySpout;
        part container : UserContainer;
        part maintenance : MaintenanceInterface;

        port operatorStroke : MechanicalStrokePort;
        port deliveredWaterOutlet : FluidPort;
        port leakageOutlet : DrainPort;

        connection operatorToHandle connect operatorStroke to handle.operatorInput;
        connection handleToRod connect handle.operatorInput to rod.handleSide;
        connection rodToCylinder connect rod.pistonSide to cylinder.pistonDrive;

        connection wellToFootValve connect well.abstractionPoint to footValve.wellSide;
        connection footValveToCylinder connect footValve.cylinderSide to cylinder.suctionPort;
        connection cylinderToPistonValve connect cylinder.dischargePort to pistonValve.lowerSide;
        connection pistonValveToRiser connect pistonValve.upperSide to riser.lowerEnd;
        connection riserToPumpHead connect riser.upperEnd to pumpHead.inletFromRiser;
        connection pumpHeadToSpout connect pumpHead.outletToSpout to spout.inlet;
        connection spoutToOutlet connect spout.outlet to deliveredWaterOutlet;
        connection outletToContainer connect deliveredWaterOutlet to container.fillPort;
        connection headLeakage connect pumpHead.leakageDrain to leakageOutlet;

        action def PrimePump {
            in initialStrokes : Integer;
            out primed : Boolean;
        }

        action def PumpStrokeCycle {
            in operatorForce : Force;
            in strokeRate : Frequency;
            out deliveredFlow : FlowRate;
            out outletPressure : Pressure;
            out fault : FaultCode;
        }

        action def StopPumping {
            out stopped : Boolean;
        }

        action def DiagnoseFault {
            in measuredFlow : FlowRate;
            in measuredForce : Force;
            in leakageRate : FlowRate;
            out fault : FaultCode;
        }

        state def PumpLifecycle {
            entry action Initialize {
                operatingMode = PumpOperatingMode::idle;
                currentFault = FaultCode::none;
            }

            state Idle;
            state Priming;
            state Pumping;
            state Shutdown;
            state Faulted;
            state Maintenance;

            transition startPriming
                first Idle
                accept operatorStroke.strokeForce
                if operatorStroke.strokeForce > 40 [N]
                then Priming;

            transition primed
                first Priming
                if deliveredWaterOutlet.flowRate > 1 [L / min]
                then Pumping;

            transition continuePumping
                first Pumping
                if deliveredWaterOutlet.flowRate >= minimumFlowRate and currentFault == FaultCode::none
                then Pumping;

            transition stopRequested
                first Pumping
                accept StopPumping
                then Shutdown;

            transition shutdownComplete
                first Shutdown
                then Idle;

            transition lowFlowFault
                first Pumping
                if deliveredWaterOutlet.flowRate < minimumFlowRate
                then Faulted;

            transition excessiveForceFault
                first Pumping
                if operatorStroke.strokeForce > maximumHandleForce
                then Faulted;

            transition repairRequested
                first Faulted
                accept maintenance.Inspect
                then Maintenance;

            transition repairComplete
                first Maintenance
                if currentFault == FaultCode::none
                then Idle;
        }

        perform action PumpStrokeCycle {
            in operatorForce = operatorStroke.strokeForce;
            in strokeRate = operatorStroke.strokeRate;
            out deliveredFlow = deliveredWaterOutlet.flowRate;
            out outletPressure = deliveredWaterOutlet.pressure;
            out fault = currentFault;
        }
    }

    requirement def PumpingCapacityRequirement {
        doc "The Bush pump subsystem shall deliver at least 8 liters per minute of potable groundwater at a dynamic water level of 18 meters when operated at 35 strokes per minute.";
        subject subsystem : BushPumpSubsystem;
        require constraint {
            subsystem.deliveredWaterOutlet.flowRate >= 8 [L / min]
        }
    }

    requirement def HandleForceRequirement {
        doc "The Bush pump subsystem shall require no more than 300 newtons of operator handle force during nominal pumping.";
        subject subsystem : BushPumpSubsystem;
        require constraint {
            subsystem.operatorStroke.strokeForce <= 300 [N]
        }
    }

    requirement def LiftRequirement {
        doc "The Bush pump subsystem shall lift water from a dynamic water level of at least 35 meters without exceeding structural limits.";
        subject subsystem : BushPumpSubsystem;
        require constraint {
            subsystem.maximumLiftHead >= 35 [m]
        }
    }

    requirement def PotableWaterIsolationRequirement {
        doc "The pumping path shall preserve potable-water quality by routing abstraction flow only through the foot valve, cylinder, piston valve, riser pipe, pump head, and delivery spout.";
        subject subsystem : BushPumpSubsystem;
        require constraint {
            subsystem.well.sourceQuality == FluidQuality::potable
        }
    }

    requirement def LeakageRequirement {
        doc "The pump head and valve assembly shall limit leakage to no more than 0.1 liters per minute during pumping.";
        subject subsystem : BushPumpSubsystem;
        require constraint {
            subsystem.leakageOutlet.leakageRate <= 0.1 [L / min]
        }
    }

    requirement def FaultDetectionRequirement {
        doc "The subsystem shall enter the faulted operating mode when delivered flow is below minimum flow or handle force exceeds the maximum allowable value.";
        subject subsystem : BushPumpSubsystem;
        require constraint {
            (subsystem.deliveredWaterOutlet.flowRate < subsystem.minimumFlowRate or
             subsystem.operatorStroke.strokeForce > subsystem.maximumHandleForce)
            implies subsystem.operatingMode == PumpOperatingMode::faulted
        }
    }

    requirement def MaintainabilityRequirement {
        doc "The subsystem shall provide inspection and corrective maintenance actions for leakage, blockage, valve failure, and excessive handle force faults.";
        subject subsystem : BushPumpSubsystem;
        require constraint {
            subsystem.maintenance.inspectionIntervalDays <= 30
        }
    }

    satisfy BushPumpPumpingSubsystemModel::PumpingCapacityRequirement by BushPumpSubsystem;
    satisfy BushPumpPumpingSubsystemModel::HandleForceRequirement by BushPumpSubsystem;
    satisfy BushPumpPumpingSubsystemModel::LiftRequirement by BushPumpSubsystem;
    satisfy BushPumpPumpingSubsystemModel::PotableWaterIsolationRequirement by BushPumpSubsystem;
    satisfy BushPumpPumpingSubsystemModel::LeakageRequirement by BushPumpSubsystem;
    satisfy BushPumpPumpingSubsystemModel::FaultDetectionRequirement by BushPumpSubsystem;
    satisfy BushPumpPumpingSubsystemModel::MaintainabilityRequirement by BushPumpSubsystem;

}