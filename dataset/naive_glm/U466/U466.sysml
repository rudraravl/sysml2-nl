package MechanicalProductDispenser {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    // ===== VALUE TYPES =====

    value def LengthValue :> Length {
        :>> unit = m;
    }

    value def AreaValue :> Area {
        :>> unit = m2;
    }

    value def VolumeValue :> Volume {
        :>> unit = m3;
    }

    value def TimeValue :> Time {
        :>> unit = s;
    }

    value def ForceValue :> Force {
        :>> unit = N;
    }

    value def PressureValue :> Pressure {
        :>> unit = Pa;
    }

    value def AngleValue :> PlaneAngle {
        :>> unit = rad;
    }

    value def VelocityValue :> Real {
        :>> unit = m / s;
    }

    value def DensityValue :> Real {
        :>> unit = kg / m3;
    }

    value def DynamicViscosityValue :> Real {
        :>> unit = Pa * s;
    }

    value def FlowRateValue :> Real {
        :>> unit = m3 / s;
    }

    value def DropletDiameter :> LengthValue;
    value def OrificeDiameter :> LengthValue;
    value def SprayAngleValue :> AngleValue;
    value def StrokeCountValue :> Integer;

    // ===== ENUMERATIONS =====

    enumeration ReservoirLevel {
        EMPTY;
        LOW;
        NORMAL;
        FULL;
    }

    enumeration PumpPhase {
        IDLE;
        INTAKE;
        COMPRESSION;
        DISCHARGE;
    }

    enumeration ValveState {
        CLOSED;
        OPEN;
    }

    enumeration ActuatorState {
        REST;
        DEPRESSED;
    }

    enumeration DispenserMode {
        SYSTEM_IDLE;
        PRIMING;
        DISPENSING;
        DRAINED;
    }

    // ===== ITEM TYPES =====

    item def LiquidProduct {
        attribute density : DensityValue;
        attribute viscosity : DynamicViscosityValue;
        attribute volume : VolumeValue;
    }

    item def PressurizedProduct :> LiquidProduct {
        attribute pressure : PressureValue;
    }

    item def AtomizedDroplet {
        attribute diameter : DropletDiameter;
        attribute velocity : VelocityValue;
    }

    item def SprayMist {
        attribute droplets : AtomizedDroplet[0..*];
        attribute meanDropletDiameter : DropletDiameter;
        attribute sprayAngle : SprayAngleValue;
        attribute dropletCount : Integer;
        attribute coverageVolume : VolumeValue;
    }

    // ===== PORT DEFINITIONS =====

    port def FluidPort {
        in item product : LiquidProduct;
        attribute flowRate : FlowRateValue;
        attribute pressure : PressureValue;
    }

    port def PressurizedFluidPort {
        in item product : PressurizedProduct;
        attribute flowRate : FlowRateValue;
        attribute pressure : PressureValue;
    }

    port def MechanicalActuationPort {
        in actuationForce : ForceValue;
        in actuationDisplacement : LengthValue;
    }

    port def UserInputPort {
        in appliedForce : ForceValue;
        in appliedDisplacement : LengthValue;
    }

    port def SprayOutputPort {
        out item dispensedSpray : SprayMist;
    }

    // ===== INTERFACE DEFINITIONS =====

    interface def FluidConnection {
        end source : FluidPort;
        end target : FluidPort;
    }

    interface def PressurizedFluidConnection {
        end source : PressurizedFluidPort;
        end target : PressurizedFluidPort;
    }

    interface def MechanicalDriveConnection {
        end source : MechanicalActuationPort;
        end target : MechanicalActuationPort;
    }

    // ===== PART DEFINITIONS =====

    part def ProductReservoir {
        port fluidOut : ~FluidPort;

        attribute capacity : VolumeValue;
        attribute currentVolume : VolumeValue;
        attribute level : ReservoirLevel;
        attribute lowThreshold : VolumeValue;
        attribute normalThreshold : VolumeValue;

        state reservoirStates {
            state EMPTY;
            state LOW;
            state NORMAL;
            state FULL;

            transition empty_to_low
                from EMPTY to LOW
                when currentVolume > 0;
            transition low_to_normal
                from LOW to NORMAL
                when currentVolume > lowThreshold;
            transition normal_to_full
                from NORMAL to FULL
                when currentVolume >= capacity;
            transition full_to_normal
                from FULL to NORMAL
                when currentVolume < capacity;
            transition normal_to_low
                from NORMAL to LOW
                when currentVolume < normalThreshold;
            transition low_to_empty
                from LOW to EMPTY
                when currentVolume <= 0;
        }

        action updateLevel {
            in measuredVolume : VolumeValue;
            return levelState : ReservoirLevel;
        }

        action dispenseVolume {
            in requestedVolume : VolumeValue;
            return dispensedVolume : VolumeValue;
        }

        action fillReservoir {
            in fillVolume : VolumeValue;
            return newVolume : VolumeValue;
        }
    }

    part def ActuatorMechanism {
        port userInput : UserInputPort;
        port mechanicalOut : ~MechanicalActuationPort;

        attribute actuationState : ActuatorState;
        attribute maxActuationForce : ForceValue;
        attribute maxDisplacement : LengthValue;
        attribute forceAmplification : Real;
        attribute returnSpringForce : ForceValue;
        attribute currentAppliedForce : ForceValue;
        attribute currentOutputForce : ForceValue;

        state actuatorStates {
            state REST;
            state DEPRESSED;

            transition rest_to_depressed
                from REST to DEPRESSED
                when currentAppliedForce > 0;
            transition depressed_to_rest
                from DEPRESSED to REST
                when currentAppliedForce == 0;
        }

        action applyUserForce {
            in userForce : ForceValue;
            in userDisplacement : LengthValue;
            out outputForce : ForceValue;
            out outputDisplacement : LengthValue;
        }

        action resetActuator {
            out springForce : ForceValue;
        }
    }

    part def PumpAssembly {
        port mechanicalIn : MechanicalActuationPort;
        port fluidIn : FluidPort;
        port fluidOut : ~PressurizedFluidPort;

        attribute chamberVolume : VolumeValue;
        attribute currentChamberPressure : PressureValue;
        attribute dischargePressure : PressureValue;
        attribute pumpPhase : PumpPhase;
        attribute strokeCount : StrokeCountValue;
        attribute primingStrokesRequired : StrokeCountValue;
        attribute primingStrokesCompleted : StrokeCountValue;
        attribute isPrimed : Boolean;
        attribute pumpEfficiency : Real;
        attribute boreDiameter : LengthValue;
        attribute strokeLength : LengthValue;
        attribute currentActuationForce : ForceValue;
        attribute currentDrawnVolume : VolumeValue;

        state pumpStates {
            state IDLE;
            state INTAKE;
            state COMPRESSION;
            state DISCHARGE;

            transition idle_to_intake
                from IDLE to INTAKE
                when currentActuationForce > 0;
            transition intake_to_compression
                from INTAKE to COMPRESSION
                when currentActuationForce > 0;
            transition compression_to_discharge
                from COMPRESSION to DISCHARGE
                when currentChamberPressure >= dischargePressure;
            transition discharge_to_idle
                from DISCHARGE to IDLE
                when currentActuationForce == 0;
        }

        action performStroke {
            in inputProduct : LiquidProduct;
            in actuationForce : ForceValue;
            out dispensedProduct : PressurizedProduct;
        }

        action primePump {
            out primingComplete : Boolean;
        }

        action drawProduct {
            in sourceProduct : LiquidProduct;
            return drawnVolume : VolumeValue;
        }

        action compressChamber {
            in actuationForce : ForceValue;
            return chamberPressure : PressureValue;
        }

        action dischargeProduct {
            in chamberPressure : PressureValue;
            return dispensed : PressurizedProduct;
        }
    }

    part def ValveSystem {
        port fluidIn : PressurizedFluidPort;
        port fluidOut : ~PressurizedFluidPort;

        attribute crackingPressure : PressureValue;
        attribute valveState : ValveState;
        attribute sealIntegrity : Real;
        attribute backflowPrevention : Boolean;
        attribute currentInputPressure : PressureValue;
        attribute maxOperatingPressure : PressureValue;

        state valveStates {
            state CLOSED;
            state OPEN;

            transition closed_to_open
                from CLOSED to OPEN
                when currentInputPressure >= crackingPressure;
            transition open_to_closed
                from OPEN to CLOSED
                when currentInputPressure < crackingPressure;
        }

        action regulateFlow {
            in inputProduct : PressurizedProduct;
            return outputProduct : PressurizedProduct;
        }

        action sealValve {
            out sealIntegrityValue : Real;
        }
    }

    part def NozzleAssembly {
        port fluidIn : PressurizedFluidPort;
        port sprayOut : SprayOutputPort;

        attribute orificeDiameter : OrificeDiameter;
        attribute nominalSprayAngle : SprayAngleValue;
        attribute targetDropletDiameter : DropletDiameter;
        attribute swirlMechanism : Boolean;
        attribute orificeArea : AreaValue;

        action atomize {
            in inputProduct : PressurizedProduct;
            return outputSpray : SprayMist;
        }

        action formDroplets {
            in pressurizedStream : PressurizedProduct;
            return droplets : AtomizedDroplet[0..*];
        }

        action shapeSpray {
            in droplets : AtomizedDroplet[0..*];
            in targetAngle : SprayAngleValue;
            return spray : SprayMist;
        }
    }

    // ===== TOP-LEVEL SYSTEM =====

    part def DispenserSystem {
        part reservoir : ProductReservoir;
        part actuator : ActuatorMechanism;
        part pump : PumpAssembly;
        part valve : ValveSystem;
        part nozzle : NozzleAssembly;

        attribute dispenserMode : DispenserMode;
        attribute totalStrokes : StrokeCountValue;
        attribute dispensedVolume : VolumeValue;

        state systemStates {
            state SYSTEM_IDLE;
            state PRIMING;
            state DISPENSING;
            state DRAINED;

            transition idle_to_priming
                from SYSTEM_IDLE to PRIMING
                when pump.isPrimed == false;
            transition priming_to_dispensing
                from PRIMING to DISPENSING
                when pump.isPrimed == true;
            transition dispensing_to_idle
                from DISPENSING to SYSTEM_IDLE
                when actuator.actuationState == ActuatorState::REST;
            transition dispensing_to_drained
                from DISPENSING to DRAINED
                when reservoir.level == ReservoirLevel::EMPTY;
            transition drained_to_idle
                from DRAINED to SYSTEM_IDLE
                when reservoir.currentVolume > 0;
        }

        action dispenseDose {
            in requestedDose : VolumeValue;
            out dispensedSpray : SprayMist;
        }

        action primeSystem {
            out primingComplete : Boolean;
        }

        action resetSystem {
            out systemReset : Boolean;
        }

        connect reservoir.fluidOut to pump.fluidIn;
        connect actuator.mechanicalOut to pump.mechanicalIn;
        connect pump.fluidOut to valve.fluidIn;
        connect valve.fluidOut to nozzle.fluidIn;
    }

    // ===== REQUIREMENT DEFINITIONS =====

    requirement def DispensingSystemRequirement {
        subject dispenser : DispenserSystem;
    }

    requirement def PreciseDoseRequirement :> DispensingSystemRequirement {
        attribute targetDoseVolume : VolumeValue;
        attribute doseTolerancePercent : Real;
        doc {
            "The dispenser shall dispense a dose of targetDoseVolume with a tolerance of doseTolerancePercent percent."
        }
        require {
            dispenser.dispensedVolume >= targetDoseVolume * (1.0 - doseTolerancePercent / 100.0) and
            dispenser.dispensedVolume <= targetDoseVolume * (1.0 + doseTolerancePercent / 100.0);
        }
    }

    requirement def ReservoirLevelAwarenessRequirement :> DispensingSystemRequirement {
        doc {
            "The reservoir shall indicate product level as EMPTY, LOW, NORMAL, or FULL."
        }
        require {
            dispenser.reservoir.level == ReservoirLevel::EMPTY or
            dispenser.reservoir.level == ReservoirLevel::LOW or
            dispenser.reservoir.level == ReservoirLevel::NORMAL or
            dispenser.reservoir.level == ReservoirLevel::FULL;
        }
    }

    requirement def ActuatorForceRequirement :> DispensingSystemRequirement {
        attribute maxActuationForce : ForceValue;
        doc {
            "The actuator shall accept user-applied force up to maxActuationForce without failure."
        }
        require {
            dispenser.actuator.maxActuationForce >= maxActuationForce;
        }
    }

    requirement def PumpCycleRequirement :> DispensingSystemRequirement {
        attribute maxPrimingStrokes : StrokeCountValue;
        doc {
            "The pump shall complete priming within maxPrimingStrokes actuation cycles."
        }
        require {
            dispenser.pump.primingStrokesRequired <= maxPrimingStrokes;
        }
    }

    requirement def PumpPhaseRequirement :> DispensingSystemRequirement {
        doc {
            "The pump shall cycle through INTAKE, COMPRESSION, and DISCHARGE phases per stroke."
        }
        require {
            dispenser.pump.pumpPhase == PumpPhase::INTAKE or
            dispenser.pump.pumpPhase == PumpPhase::COMPRESSION or
            dispenser.pump.pumpPhase == PumpPhase::DISCHARGE or
            dispenser.pump.pumpPhase == PumpPhase::IDLE;
        }
    }

    requirement def ValveOperationRequirement :> DispensingSystemRequirement {
        attribute crackingPressure : PressureValue;
        doc {
            "The valve shall open at crackingPressure and reseat when pressure drops below crackingPressure."
        }
        require {
            dispenser.valve.crackingPressure == crackingPressure;
        }
    }

    requirement def BackflowPreventionRequirement :> DispensingSystemRequirement {
        doc {
            "The valve shall prevent product backflow when the pump is not dispensing."
        }
        require {
            dispenser.valve.backflowPrevention == true;
        }
    }

    requirement def LeakagePreventionRequirement :> DispensingSystemRequirement {
        doc {
            "The system shall not leak between dispensing cycles."
        }
        require {
            dispenser.valve.sealIntegrity >= 0.95;
        }
    }

    requirement def AtomizationRequirement :> DispensingSystemRequirement {
        attribute targetSprayAngle : SprayAngleValue;
        attribute targetMeanDropletDiameter : DropletDiameter;
        doc {
            "The nozzle shall produce a spray with angle targetSprayAngle and mean droplet diameter targetMeanDropletDiameter."
        }
        require {
            dispenser.nozzle.nominalSprayAngle == targetSprayAngle and
            dispenser.nozzle.targetDropletDiameter == targetMeanDropletDiameter;
        }
    }

    requirement def MechanicalEnergyTransferRequirement :> DispensingSystemRequirement {
        doc {
            "The actuator shall translate user-applied mechanical input into pump-driving mechanical output."
        }
        require {
            dispenser.actuator.forceAmplification > 0.0;
        }
    }

    requirement def ReservoirCapacityRequirement :> DispensingSystemRequirement {
        attribute minCapacity : VolumeValue;
        doc {
            "The reservoir shall hold a minimum product volume of minCapacity."
        }
        require {
            dispenser.reservoir.capacity >= minCapacity;
        }
    }

    // ===== REQUIREMENT INSTANCES =====

    requirement PreciseDose : PreciseDoseRequirement {
        :>> targetDoseVolume = 0.000001 [m3];
        :>> doseTolerancePercent = 5.0;
    }

    requirement ReservoirAwareness : ReservoirLevelAwarenessRequirement;

    requirement UserActuation : ActuatorForceRequirement {
        :>> maxActuationForce = 30.0 [N];
    }

    requirement PumpPriming : PumpCycleRequirement {
        :>> maxPrimingStrokes = 5;
    }

    requirement PumpPhasing : PumpPhaseRequirement;

    requirement ValveCracking : ValveOperationRequirement {
        :>> crackingPressure = 200000.0 [Pa];
    }

    requirement NoBackflow : BackflowPreventionRequirement;

    requirement NoLeakage : LeakagePreventionRequirement;

    requirement SprayQuality : AtomizationRequirement {
        :>> targetSprayAngle = 0.524 [rad];
        :>> targetMeanDropletDiameter = 0.000100 [m];
    }

    requirement EnergyTransfer : MechanicalEnergyTransferRequirement;

    requirement ReservoirSize : ReservoirCapacityRequirement {
        :>> minCapacity = 0.000500 [m3];
    }

    // ===== SATISFACTION LINKS =====

    part def DispenserSystem {
        satisfy PreciseDose;
        satisfy ReservoirAwareness by reservoir;
        satisfy UserActuation by actuator;
        satisfy PumpPriming by pump;
        satisfy PumpPhasing by pump;
        satisfy ValveCracking by valve;
        satisfy NoBackflow by valve;
        satisfy NoLeakage by valve;
        satisfy SprayQuality by nozzle;
        satisfy EnergyTransfer by actuator;
        satisfy ReservoirSize by reservoir;
    }
}
