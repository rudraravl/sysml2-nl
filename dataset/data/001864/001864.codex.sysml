package SlurryProcessingSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def MassDensity {
        :> ISQ::massDensity;
        unit = SI::kilogramPerCubicMetre;
    }

    attribute def DynamicViscosity {
        :> ISQ::dynamicViscosity;
        unit = SI::pascalSecond;
    }

    attribute def VolumetricFlowRate {
        :> ISQ::volumeFlowRate;
        unit = SI::cubicMetrePerSecond;
    }

    attribute def Pressure {
        :> ISQ::pressure;
        unit = SI::pascal;
    }

    attribute def Temperature {
        :> ISQ::thermodynamicTemperature;
        unit = SI::kelvin;
    }

    attribute def Volume {
        :> ISQ::volume;
        unit = SI::cubicMetre;
    }

    attribute def MassFraction {
        :> ScalarValues::Real;
    }

    attribute def ParticleDiameter {
        :> ISQ::length;
        unit = SI::micrometre;
    }

    attribute def RotationalSpeed {
        :> ISQ::angularVelocity;
        unit = SI::revolutionPerMinute;
    }

    attribute def Power {
        :> ISQ::power;
        unit = SI::kilowatt;
    }

    item def LiquidCarrier {
        attribute density : MassDensity;
        attribute temperature : Temperature;
    }

    item def SolidParticles {
        attribute materialName : String;
        attribute meanParticleDiameter : ParticleDiameter;
        attribute density : MassDensity;
    }

    item def Slurry {
        attribute liquidDensity : MassDensity = 998 [SI::kilogramPerCubicMetre];
        attribute solidsDensity : MassDensity = 2650 [SI::kilogramPerCubicMetre];
        attribute solidsMassFraction : MassFraction;
        attribute apparentViscosity : DynamicViscosity;
        attribute temperature : Temperature;
        attribute meanParticleDiameter : ParticleDiameter;
    }

    item def ClarifiedLiquid {
        attribute residualSolidsMassFraction : MassFraction;
        attribute temperature : Temperature;
    }

    item def ConcentratedSlurry {
        attribute solidsMassFraction : MassFraction;
        attribute apparentViscosity : DynamicViscosity;
    }

    item def ControlSignal {
        attribute commandName : String;
        attribute normalizedValue : Real;
    }

    item def SensorSignal {
        attribute measuredName : String;
        attribute measuredValue : Real;
        attribute valid : Boolean;
    }

    port def SlurryPort {
        inout item slurry : Slurry;
        attribute pressure : Pressure;
        attribute flowRate : VolumetricFlowRate;
    }

    port def LiquidPort {
        inout item liquid : ClarifiedLiquid;
        attribute pressure : Pressure;
        attribute flowRate : VolumetricFlowRate;
    }

    port def ConcentratePort {
        inout item concentrate : ConcentratedSlurry;
        attribute pressure : Pressure;
        attribute flowRate : VolumetricFlowRate;
    }

    port def SignalPort {
        inout item signal : ControlSignal;
    }

    port def MeasurementPort {
        out item signal : SensorSignal;
    }

    part def SlurryProcessingSystem {
        attribute designThroughput : VolumetricFlowRate = 0.025 [SI::cubicMetrePerSecond];
        attribute maximumOperatingPressure : Pressure = 800000 [SI::pascal];
        attribute nominalSolidsFeedFraction : MassFraction = 0.35;
        attribute targetProductSolidsFraction : MassFraction = 0.55;

        port feedIn : SlurryPort;
        port clarifiedLiquidOut : LiquidPort;
        port concentratedSlurryOut : ConcentratePort;
        port operatorCommand : SignalPort;
        port statusOut : MeasurementPort;

        part feedTank : AgitatedSlurryTank {
            attribute workingVolume = 12 [SI::cubicMetre];
        }

        part transferPump : SlurryPump {
            attribute ratedFlow = 0.03 [SI::cubicMetrePerSecond];
            attribute ratedDifferentialPressure = 650000 [SI::pascal];
        }

        part densityMeter : DensitySensor;
        part flowMeter : FlowSensor;
        part pressureSensor : PressureSensor;
        part hydrocyclone : HydrocycloneSeparator;
        part thickener : GravityThickener;
        part controlUnit : SlurryControlUnit;
        part reliefValve : PressureReliefValve;

        connect feedIn to feedTank.inlet;
        connect feedTank.outlet to transferPump.suction;
        connect transferPump.discharge to densityMeter.processPort;
        connect densityMeter.processPort to flowMeter.processPort;
        connect flowMeter.processPort to pressureSensor.processPort;
        connect pressureSensor.processPort to hydrocyclone.feed;
        connect hydrocyclone.overflow to clarifiedLiquidOut;
        connect hydrocyclone.underflow to thickener.feed;
        connect thickener.overflow to clarifiedLiquidOut;
        connect thickener.underflow to concentratedSlurryOut;
        connect pressureSensor.processPort to reliefValve.protectedPort;
        connect operatorCommand to controlUnit.commandIn;
        connect densityMeter.measurementOut to controlUnit.densityIn;
        connect flowMeter.measurementOut to controlUnit.flowIn;
        connect pressureSensor.measurementOut to controlUnit.pressureIn;
        connect controlUnit.pumpCommand to transferPump.speedCommand;
        connect controlUnit.mixerCommand to feedTank.mixerCommand;
        connect controlUnit.statusOut to statusOut;

        perform action processSlurry;
        exhibit state operatingState;
    }

    part def AgitatedSlurryTank {
        attribute workingVolume : Volume;
        attribute mixerSpeed : RotationalSpeed;
        attribute minimumLevelFraction : Real = 0.15;
        attribute maximumLevelFraction : Real = 0.90;

        port inlet : SlurryPort;
        port outlet : SlurryPort;
        port mixerCommand : SignalPort;
        port levelOut : MeasurementPort;

        part impeller : MixerImpeller {
            attribute diameter = 0.9 [SI::metre];
            attribute ratedPower = 18 [SI::kilowatt];
        }

        action maintainSuspension {
            in item storedSlurry : Slurry;
            in attribute requestedSpeed : RotationalSpeed;
            out item homogenizedSlurry : Slurry;

            first startMixer;
            then blendUntilUniform;
            then releaseHomogenizedSlurry;

            action startMixer;
            action blendUntilUniform;
            action releaseHomogenizedSlurry;
        }
    }

    part def MixerImpeller {
        attribute diameter : ISQ::length;
        attribute ratedPower : Power;
        attribute currentSpeed : RotationalSpeed;
    }

    part def SlurryPump {
        attribute ratedFlow : VolumetricFlowRate;
        attribute ratedDifferentialPressure : Pressure;
        attribute speed : RotationalSpeed;
        attribute motorPower : Power = 30 [SI::kilowatt];

        port suction : SlurryPort;
        port discharge : SlurryPort;
        port speedCommand : SignalPort;

        action increasePressure {
            in item lowPressureSlurry : Slurry;
            in attribute suctionPressure : Pressure;
            out item pressurizedSlurry : Slurry;
            out attribute dischargePressure : Pressure;
        }
    }

    part def HydrocycloneSeparator {
        attribute cutSize : ParticleDiameter = 45 [SI::micrometre];
        attribute nominalPressureDrop : Pressure = 180000 [SI::pascal];
        attribute overflowSplitFraction : Real = 0.62;

        port feed : SlurryPort;
        port overflow : LiquidPort;
        port underflow : ConcentratePort;

        action classifyParticles {
            in item incomingSlurry : Slurry;
            out item fineOverflow : ClarifiedLiquid;
            out item coarseUnderflow : ConcentratedSlurry;
        }
    }

    part def GravityThickener {
        attribute tankVolume : Volume = 30 [SI::cubicMetre];
        attribute targetUnderflowSolidsFraction : MassFraction = 0.55;
        attribute maximumOverflowResidualSolidsFraction : MassFraction = 0.02;

        port feed : ConcentratePort;
        port overflow : LiquidPort;
        port underflow : ConcentratePort;

        action settleAndCompact {
            in item diluteConcentrate : ConcentratedSlurry;
            out item clarifiedOverflow : ClarifiedLiquid;
            out item compactedUnderflow : ConcentratedSlurry;
        }
    }

    part def DensitySensor {
        attribute rangeMinimum : MassDensity = 900 [SI::kilogramPerCubicMetre];
        attribute rangeMaximum : MassDensity = 1800 [SI::kilogramPerCubicMetre];
        attribute accuracyFraction : Real = 0.005;

        port processPort : SlurryPort;
        port measurementOut : MeasurementPort;
    }

    part def FlowSensor {
        attribute rangeMaximum : VolumetricFlowRate = 0.05 [SI::cubicMetrePerSecond];
        attribute accuracyFraction : Real = 0.01;

        port processPort : SlurryPort;
        port measurementOut : MeasurementPort;
    }

    part def PressureSensor {
        attribute rangeMaximum : Pressure = 1000000 [SI::pascal];
        attribute accuracyFraction : Real = 0.005;

        port processPort : SlurryPort;
        port measurementOut : MeasurementPort;
    }

    part def PressureReliefValve {
        attribute setPressure : Pressure = 850000 [SI::pascal];
        attribute reseatPressure : Pressure = 760000 [SI::pascal];

        port protectedPort : SlurryPort;
        port dischargePort : SlurryPort;

        state valveState {
            entry; then closed;

            state closed;
            state open;

            transition closed_to_open
                first closed
                accept PressureHigh
                then open;

            transition open_to_closed
                first open
                accept PressureNormal
                then closed;
        }
    }

    part def SlurryControlUnit {
        attribute commandedThroughput : VolumetricFlowRate = 0.025 [SI::cubicMetrePerSecond];
        attribute highPressureLimit : Pressure = 800000 [SI::pascal];
        attribute lowFlowAlarmLimit : VolumetricFlowRate = 0.010 [SI::cubicMetrePerSecond];

        port commandIn : SignalPort;
        port densityIn : MeasurementPort;
        port flowIn : MeasurementPort;
        port pressureIn : MeasurementPort;
        port pumpCommand : SignalPort;
        port mixerCommand : SignalPort;
        port statusOut : MeasurementPort;

        action regulateSlurryProcessing {
            in item operatorRequest : ControlSignal;
            in item densityMeasurement : SensorSignal;
            in item flowMeasurement : SensorSignal;
            in item pressureMeasurement : SensorSignal;
            out item pumpSpeedCommand : ControlSignal;
            out item mixerSpeedCommand : ControlSignal;
            out item systemStatus : SensorSignal;
        }
    }

    action def ProcessSlurry {
        in item rawSlurry : Slurry;
        out item clarifiedLiquid : ClarifiedLiquid;
        out item concentratedProduct : ConcentratedSlurry;

        first receiveFeed;
        then homogenizeFeed;
        then pumpToSeparationPressure;
        then measureFeedCondition;
        then classifySolids;
        then thickenUnderflow;
        then dischargeProducts;

        action receiveFeed {
            out item acceptedSlurry : Slurry;
        }

        action homogenizeFeed {
            in item acceptedSlurry : Slurry;
            out item uniformSlurry : Slurry;
        }

        action pumpToSeparationPressure {
            in item uniformSlurry : Slurry;
            out item pressurizedSlurry : Slurry;
        }

        action measureFeedCondition {
            in item pressurizedSlurry : Slurry;
            out item measuredSlurry : Slurry;
        }

        action classifySolids {
            in item measuredSlurry : Slurry;
            out item preliminaryLiquid : ClarifiedLiquid;
            out item preliminaryConcentrate : ConcentratedSlurry;
        }

        action thickenUnderflow {
            in item preliminaryConcentrate : ConcentratedSlurry;
            out item thickenedProduct : ConcentratedSlurry;
            out item recoveredLiquid : ClarifiedLiquid;
        }

        action dischargeProducts {
            in item preliminaryLiquid : ClarifiedLiquid;
            in item recoveredLiquid : ClarifiedLiquid;
            in item thickenedProduct : ConcentratedSlurry;
        }
    }

    state def SlurrySystemOperatingState {
        entry; then idle;

        state idle;
        state filling;
        state mixing;
        state pumping;
        state separating;
        state productDischarge;
        state cleanInPlace;
        state faulted;
        state emergencyShutdown;

        transition idle_to_filling
            first idle
            accept StartCommand
            then filling;

        transition filling_to_mixing
            first filling
            accept MinimumTankLevelReached
            then mixing;

        transition mixing_to_pumping
            first mixing
            accept SlurryHomogeneous
            then pumping;

        transition pumping_to_separating
            first pumping
            accept StableFlowEstablished
            then separating;

        transition separating_to_productDischarge
            first separating
            accept ProductQualityWithinLimits
            then productDischarge;

        transition productDischarge_to_mixing
            first productDischarge
            accept ContinueCommand
            then mixing;

        transition productDischarge_to_cleanInPlace
            first productDischarge
            accept StopCommand
            then cleanInPlace;

        transition cleanInPlace_to_idle
            first cleanInPlace
            accept CleaningComplete
            then idle;

        transition any_to_faulted
            first idle
            accept SensorInvalid
            then faulted;

        transition separating_to_faulted
            first separating
            accept ProductQualityOutOfLimits
            then faulted;

        transition pumping_to_emergencyShutdown
            first pumping
            accept OverPressure
            then emergencyShutdown;

        transition faulted_to_idle
            first faulted
            accept ResetCommand
            then idle;
    }

    requirement def PrimaryFunctionRequirement {
        subject system : SlurryProcessingSystem;

        doc /* The system shall receive an incoming slurry, maintain the solids in suspension, transport the slurry at controlled flow and pressure, separate liquid from suspended solids, and discharge clarified liquid and concentrated slurry product streams. */
    }

    requirement def ThroughputRequirement {
        subject system : SlurryProcessingSystem;

        require constraint {
            system.designThroughput >= 0.020 [SI::cubicMetrePerSecond] and
            system.designThroughput <= 0.030 [SI::cubicMetrePerSecond]
        }

        doc /* The system shall process slurry continuously within the specified design throughput range. */
    }

    requirement def PressureProtectionRequirement {
        subject system : SlurryProcessingSystem;

        require constraint {
            system.maximumOperatingPressure <= 800000 [SI::pascal]
        }

        doc /* The system shall prevent normal operating pressure from exceeding the maximum operating pressure. */
    }

    requirement def ProductConcentrationRequirement {
        subject system : SlurryProcessingSystem;

        require constraint {
            system.targetProductSolidsFraction >= 0.50 and
            system.targetProductSolidsFraction <= 0.60
        }

        doc /* The concentrated slurry product shall be discharged with a controlled solids mass fraction suitable for downstream handling. */
    }

    requirement def FeedSuspensionRequirement {
        subject tank : AgitatedSlurryTank;

        require constraint {
            tank.minimumLevelFraction >= 0.10 and
            tank.maximumLevelFraction <= 0.95
        }

        doc /* The feed tank shall operate within controlled level limits while agitating the slurry to reduce settling before pumping. */
    }

    requirement def MeasurementRequirement {
        subject controller : SlurryControlUnit;

        require constraint {
            controller.highPressureLimit <= 800000 [SI::pascal] and
            controller.lowFlowAlarmLimit >= 0.005 [SI::cubicMetrePerSecond]
        }

        doc /* The control unit shall use density, pressure, and flow measurements to regulate pump and mixer commands and report abnormal conditions. */
    }

    part slurryProcessingSystem : SlurryProcessingSystem {
        attribute designThroughput = 0.025 [SI::cubicMetrePerSecond];
        attribute maximumOperatingPressure = 800000 [SI::pascal];
        attribute nominalSolidsFeedFraction = 0.35;
        attribute targetProductSolidsFraction = 0.55;

        perform action processSlurry : ProcessSlurry;
        exhibit state operatingState : SlurrySystemOperatingState;
    }

    satisfy PrimaryFunctionRequirement by slurryProcessingSystem;
    satisfy ThroughputRequirement by slurryProcessingSystem;
    satisfy PressureProtectionRequirement by slurryProcessingSystem;
    satisfy ProductConcentrationRequirement by slurryProcessingSystem;
    satisfy FeedSuspensionRequirement by slurryProcessingSystem.feedTank;
    satisfy MeasurementRequirement by slurryProcessingSystem.controlUnit;
}